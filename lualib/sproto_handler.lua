local skynet = require "skynet"
local log = require "log"
local sproto_client = require "sproto_client"

-- Sproto消息处理器表
local handler = {}

-- 示例：处理ping消息
handler["ping"] = function(ws, args)
    log.info("收到ping请求")
    return {}
end

-- 示例：处理signup消息
handler["signup"] = function(ws, args)
    log.info("收到注册请求: userid=%s", args.userid)
    return { ok = true }
end

-- 示例：处理signin消息
handler["signin"] = function(ws, args)
    log.info("收到登录请求: userid=%s", args.userid)
    return { ok = true }
end

-- 示例：处理login消息
handler["login"] = function(ws, args)
    log.info("收到登录请求")
    -- 发送欢迎推送消息
    sproto_client.push(ws, "push", { text = "欢迎使用Sproto协议!" })
    return { ok = true }
end

-- 将处理器注册到sproto_client
local client_handler = sproto_client.handler()
for name, func in pairs(handler) do
    client_handler[name] = func
end

return handler
