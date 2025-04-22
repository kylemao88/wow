local skynet = require "skynet"
local redis = require "redis"
local log = require "log"
require "skynet.manager"
require "skynet.debug"

local command = {}
local max_conn = 256   -- 最大连接数
local idle_conns = {}  -- 空闲连接队列
local active_conns = 0 -- 使用中的连接计数

-- 创建新连接（带重试）
local function create_conn()
    local retry = 3
    while retry > 0 do
        local conn, err = redis.connect({
            host = skynet.getenv("redis_host"),
            port = tonumber(skynet.getenv("redis_port")),
            auth = skynet.getenv("redis_password"),
            db = 0,
            socket_timeout = 5000
        })

        if conn and pcall(conn.ping, conn) then
            return conn
        end

        if conn then conn:disconnect() end
        log.error("Redis连接失败，剩余重试次数:%d 错误:%s", retry - 1, err)
        retry = retry - 1
        skynet.sleep(100)
    end
    return nil
end

-- 获取Redis连接
function command.get_conn()
    -- 1. 优先从空闲队列获取
    if #idle_conns > 0 then
        log.info("尝试复用空闲连接，当前空闲:%d 活跃:%d", #idle_conns, active_conns)
        local conn = table.remove(idle_conns, 1)
        if pcall(conn.ping, conn) then
            active_conns = active_conns + 1
            log.info("成功复用空闲连接，当前活跃:%d", active_conns)
            return conn
        end
    end

    -- 2. 创建新连接（不超过最大限制）
    if active_conns < max_conn then
        log.info("创建新连接，当前活跃:%d/%d", active_conns, max_conn)
        local conn = create_conn()
        if conn then
            active_conns = active_conns + 1
            log.info("新连接创建成功，当前活跃:%d", active_conns)
            return conn
        end
    end

    -- 3. 所有连接都在使用中
    log.error("Redis连接池繁忙，活跃:%d/%d 空闲:%d", active_conns, max_conn, #idle_conns)
    return nil
end

-- 释放Redis连接
function command.release_conn(conn)
    active_conns = active_conns - 1

    -- 检查连接有效性后再回收
    if pcall(conn.ping, conn) then
        table.insert(idle_conns, conn)
    else
        pcall(conn.disconnect, conn)
    end
end

-- 通用命令处理
function command.command(_, cmd, ...)
    local conn = command.get_conn()
    if not conn then
        return nil, "REDIS_CONNECTION_FAILED"
    end

    local ok, result = pcall(conn[cmd], conn, ...)
    command.release_conn(conn)

    if not ok then
        log.error("Redis命令执行失败: %s", result)
        return nil, result
    end
    return result
end

-- 生成会话token
function command.generate_session(_, user_id)
    local conn = command.get_conn()
    if not conn then
        return nil, "REDIS_CONNECTION_FAILED"
    end

    -- 生成32字符HEX字符串作为token
    local token = string.format("%08x%08x%08x%08x",
        math.random(0, 0xffffffff),
        math.random(0, 0xffffffff),
        math.random(0, 0xffffffff),
        math.random(0, 0xffffffff)
    )
    local ok = conn:setex("session:" .. token, 3600, user_id)
    command.release_conn(conn)

    return ok and token or nil
end

skynet.start(function()
    math.randomseed(os.time()) -- 初始化随机种子
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = command[cmd] or command.command
        skynet.ret(skynet.pack(f(command, cmd, ...)))
    end)

    -- 启动时测试连接
    local test_conn = command.get_conn()
    if test_conn then
        log.info("Redis连接测试成功")
        command.release_conn(test_conn)
    else
        log.error("Redis连接测试失败")
    end
    log.info("Cacheproxyd服务已启动，地址: %s", skynet.address(skynet.self()))
    skynet.register(".cacheproxyd")
end)
