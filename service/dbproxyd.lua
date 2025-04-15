local skynet = require "skynet"
local mysql = require "mysql"
local log = require "log"
require "skynet.manager"
require "skynet.debug"

local command = {}
local max_conn = 256   -- 最大连接数
local idle_conns = {}  -- 空闲连接队列
local active_conns = 0 -- 使用中的连接计数
local env              -- MySQL环境对象

-- 创建新连接（带重试）
local function create_conn()
    local retry = 3
    while retry > 0 do
        local conn = mysql.connect({
            host = "9.135.71.248",
            port = 3306,
            database = "wow",
            user = "root",
            password = "uSvUQ@9847yaSC",
            max_packet_size = 1024 * 1024
        })
        if conn then
            -- 测试连接有效性
            local ok = pcall(conn.query, conn, "SELECT 1")
            if ok then
                return conn
            end
            conn:disconnect()
        end
        log.error("MySQL连接失败，剩余重试次数:%d", retry - 1)
        retry = retry - 1
        skynet.sleep(100)
    end
    return nil
end

-- 获取MySQL连接
function command.get_conn()
    -- 1. 优先从空闲队列获取
    if #idle_conns > 0 then
        log.info("尝试复用空闲连接，当前空闲:%d 活跃:%d", #idle_conns, active_conns)
        local conn = table.remove(idle_conns, 1)
        active_conns = active_conns + 1
        log.info("成功复用空闲连接，当前活跃:%d", active_conns)
        return conn
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
    log.error("MySQL连接池繁忙，活跃:%d/%d 空闲:%d", active_conns, max_conn, #idle_conns)
    return nil
end

-- 释放MySQL连接
function command.release_conn(conn)
    active_conns = active_conns - 1

    -- 连接健康检查
    local ok = pcall(conn.query, conn, "SELECT 1")
    if ok then
        table.insert(idle_conns, conn)
    else
        conn:disconnect()
        log.warning("连接已失效，直接关闭")
    end
end

-- 执行SQL查询
function command.query(_, args)
    -- 参数结构校验
    if type(args) ~= "table" then
        return nil, "INVALID_ARGS_FORMAT"
    end

    local sql = args.sql
    local params = args.params
    -- 增加日志
    log.info("SQL: %s | type(params): %s", sql, type(params))

    local conn = command.get_conn()
    if not conn then
        return nil, "DB_CONNECTION_FAILED"
    end

    -- 安全参数绑定（带完整校验）
    if params then
        -- 参数类型校验
        if type(params) ~= "table" then
            return nil, "PARAMS_NOT_TABLE"
        end

        -- 统计需要参数数量
        local required = select(2, sql:gsub("%?", "?"))
        if required ~= #params then
            return nil, string.format("PARAM_COUNT_MISMATCH(need:%d got:%d)", required, #params)
        end

        -- 手动参数绑定
        local index = 0
        sql = sql:gsub("%?", function()
            index = index + 1
            local value = params[index]

            -- 处理NULL值
            if value == nil then
                return "NULL"
            end

            -- 根据类型处理
            local vtype = type(value)
            if vtype == "number" then
                return tostring(value)            -- 数字直接使用
            elseif vtype == "string" then
                return mysql.quote_sql_str(value) -- 字符串转义
            elseif vtype == "boolean" then
                return value and "1" or "0"       -- 布尔转数字
            else
                error("不支持的参数类型: " .. vtype)
            end
        end)
    end
    --
    --log.info("SQL: %s", sql)
    local ok, result = pcall(conn.query, conn, sql)
    command.release_conn(conn)

    if not ok then
        log.error("SQL执行失败: %s | SQL: %s", result, sql)
        return nil, result
    end
    log.info("SQL执行成功: %s", sql)

    -- 处理查询结果
    if type(result) == "table" then
        return result
    end
    return { affected = result }
end

-- 事务处理
function command.transaction(_, args)
    local operations = args.operations
    local conn = command.get_conn()
    if not conn then
        return nil, "DB_CONNECTION_FAILED"
    end

    local ok, err = pcall(conn.query, conn, "START TRANSACTION")
    if not ok then
        command.release_conn(conn)
        return nil, "TRANSACTION_START_FAILED"
    end

    local results = {}
    for i, op in ipairs(operations) do
        local sql = op.sql
        if op.params then
            local index = 0
            local index = 0
            sql = sql:gsub("%?", function()
                index = index + 1
                local value = op.params[index]

                if value == nil then
                    return "NULL"
                end

                local vtype = type(value)
                if vtype == "number" then
                    return tostring(value)
                elseif vtype == "string" then
                    return "'" .. mysql.quote_sql_str(value) .. "'"
                elseif vtype == "boolean" then
                    return value and "1" or "0"
                else
                    error("不支持的参数类型: " .. vtype)
                end
            end)
        end

        local ok, res = pcall(conn.query, conn, sql)
        if not ok then
            conn:query("ROLLBACK")
            command.release_conn(conn)
            return nil, "TRANSACTION_FAILED_AT_OP_" .. i
        end
        results[i] = res
    end

    conn:query("COMMIT")
    command.release_conn(conn)
    return results
end

skynet.start(function()
    -- 初始化连接池
    for i = 1, 5 do -- 初始连接数
        local conn = create_conn()
        if conn then
            table.insert(idle_conns, conn)
        end
    end

    skynet.dispatch("lua", function(session, address, cmd, ...)
        local f = command[cmd]
        if f then
            skynet.ret(skynet.pack(f(command, ...)))
        else
            skynet.ret(skynet.pack(nil, "UNSUPPORTED_COMMAND"))
        end
    end)

    log.info("DBproxyd服务已启动，地址: %s", skynet.address(skynet.self()))
    skynet.register(".dbproxyd")
end)
