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

    local resp = {
        error_resp = {
            code = "SUCCESS",
            message = "Login successful"
        },
        userid = 10086
    }

    return "game.LoginResp", resp
end

-- 获取玩家信息请求处理
handler["game.GetPlayerInfoReq"] = function(ws, msg)
    log.info("Client %s get player info request: userid=%d",
        tostring(ws.id),
        tonumber(msg.userid))

    -- 模拟从数据库获取玩家信息
    local resp = {
        error_resp = {
            code = "SUCCESS",
            message = "Get player info successful"
        },
        player = {
            userid = msg.userid,
            nickname = "测试玩家",
            level = 10,
            exp = 1000,
            vip_level = 1
        }
    }

    return "game.GetPlayerInfoResp", resp
end

return handler
