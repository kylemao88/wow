local skynet = require "skynet"
local redis = require "redis"
local log = require "log"
require "skynet.manager"
require "skynet.debug"

local pool = {}  -- Redis连接池
local max_conn = 10  -- 最大连接数

local command = {}

-- 获取Redis连接
function command.get_conn()
    for i = 1, max_conn do
        if not pool[i] then
            -- 添加重试机制
            local retry = 3
            while retry > 0 do
                pool[i], err = redis.connect({
                    host = "127.0.0.1",
                    port = 6379,
                    auth = "123456",
                    db = 0,
                    socket_timeout = 5000
                })
                if pool[i] then
                    -- 立即验证连接有效性
                    local ok = pcall(pool[i].ping, pool[i])
                    if ok then
                        break
                    else
                        pool[i]:disconnect()
                        pool[i] = nil
                    end
                end
                log.error("Redis连接失败，剩余重试次数:", retry-1, "错误:", err)
                retry = retry - 1
                skynet.sleep(100)  -- 等待100ms重试
            end
            if not pool[i] then
                return nil
            end
            return pool[i]
        end
        -- 使用PING命令检查连接有效性
        local ok, err = pcall(pool[i].ping, pool[i])
        if not ok then
            log.warning("Redis连接异常:", err)
            pool[i]:disconnect()
            pool[i] = nil
        else
            return pool[i]
        end
    end
    log.error("Redis连接池已满")
    return nil
end

-- 释放Redis连接
function command.release_conn(conn)
    -- 保持连接在池中复用
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
        log.error("Redis命令执行失败:", result)
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
    local ok = conn:setex("session:"..token, 3600, user_id)
    command.release_conn(conn)
    
    return ok and token or nil
end

skynet.start(function()
    math.randomseed(os.time())  -- 初始化随机种子
    skynet.dispatch("lua", function(_,_, cmd, ...)
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
    log.info("Cacheproxyd服务已启动")
    skynet.register(".cacheproxyd")
end)

