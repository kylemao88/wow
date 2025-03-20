local skynet = require "skynet"
local log = require "log"


-- 消息处理器表，用于存储不同消息类型对应的处理函数，方便业务模块注册消息处理函数
-- 键(key)为消息类型字符串，如"game.LoginReq"
-- 值(value)为处理函数，函数签名为 function(ws, req) -> resp_type, resp_data
-- 其中:
--   ws: WebSocket连接对象
--   req: 解析后的请求消息
--   resp_type: 返回的响应消息类型
--   resp_data: 返回的响应消息数据
-- 使用示例:
-- handler["game.LoginReq"] = function(ws, req)
--     -- 处理登录请求
--     return "game.LoginResp", { userid = "123", token = "xxx" }
-- end

local handler = {}

-- 登录请求处理
handler["game.LoginReq"] = function(ws, msg)
    log.info("Client %s AAA login request: account=%s",
        tostring(ws.id),
        tostring(msg.account))

    -- 1. 检查账号是否存在
    local user_id = skynet.call(".cacheproxyd", "lua", "get", "account:" .. msg.account)

    -- 2. 新用户注册
    if not user_id then
        user_id = tostring(skynet.call(".cacheproxyd", "lua", "incr", "global:userid"))
        skynet.call(".cacheproxyd", "lua", "hmset",
            "user:" .. user_id,
            "account", msg.account,
            "nickname", "Player" .. user_id,
            "level", 1,
            "exp", 0,
            "vip", 0
        )
        skynet.call(".cacheproxyd", "lua", "set", "account:" .. msg.account, user_id)
    end

    -- 3. 生成会话token
    local token = skynet.call(".cacheproxyd", "lua", "generate_session", user_id)


    local resp = {
        error_resp = {
            code = "SUCCESS",
            message = "Login successful"
        },
        userid = tonumber(user_id),
        token = token,
        expires_in = 3600
    }

    return "game.LoginResp", resp
end

-- 获取玩家信息请求处理
handler["game.GetPlayerInfoReq"] = function(ws, msg)
    log.info("Client %s get player info request: userid=%d",
        tostring(ws.id),
        tonumber(msg.userid))

    -- -- 模拟从数据库获取玩家信息
    -- local resp = {
    --     error_resp = {
    --         code = "SUCCESS",
    --         message = "Get player info successful"
    --     },
    --     player = {
    --         userid = msg.userid,
    --         nickname = "测试玩家",
    --         level = 10,
    --         exp = 1000,
    --         vip_level = 1
    --     }
    -- }

    -- 从MySQL数据库获取玩家详细信息
    log.info("正在查询数据库获取玩家信息，用户ID:%d", msg.userid)

    -- 调用dbproxyd服务执行查询
    local result, err = skynet.call(".dbproxyd", "lua", "query", {
        sql = "SELECT userid, nickname, level, exp, vip_level FROM users WHERE userid = ?",
        params = { msg.userid }
    })

    -- 处理查询结果
    if not result then
        log.error("数据库查询失败，用户ID:%d 错误:%s", msg.userid, err)
        return "game.GetPlayerInfoResp", {
            error_resp = {
                code = "DB_ERROR",
                message = "数据库查询失败"
            }
        }
    end

    if #result == 0 then
        log.warn("玩家不存在，用户ID:%d", msg.userid)
        return "game.GetPlayerInfoResp", {
            error_resp = {
                code = "USER_NOT_FOUND",
                message = "玩家不存在"
            }
        }
    end

    -- 转换数据类型（数据库返回字段可能为字符串）
    local player_info = result[1]
    local resp = {
        error_resp = {
            code = "SUCCESS",
            message = "获取玩家信息成功"
        },
        player = {
            userid = tonumber(player_info.userid),
            nickname = player_info.nickname or "未知玩家",
            level = tonumber(player_info.level) or 1,
            exp = tonumber(player_info.exp) or 0,
            vip_level = tonumber(player_info.vip_level) or 0
        }
    }

    log.info("成功获取玩家信息，用户ID:%d 昵称:%s", msg.userid, resp.player.nickname)
    return "game.GetPlayerInfoResp", resp
end

return handler
