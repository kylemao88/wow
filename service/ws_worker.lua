local skynet = require "skynet"
local socket = require "socket"
local string = require "string"
local websocket = require "websocket"
local httpd = require "http.httpd"
local urllib = require "http.url"
local sockethelper = require "http.sockethelper"
local log = require "log"
local ws_client = require "ws_client"

-- 确保log模块包含所有需要的方法
if not log.error then
    log.error = skynet.error
end
if not log.info then
    log.info = skynet.error
end

-- 获取消息处理器
local handler = ws_client.handler()

-- 注册登录处理器
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

-- 注册获取玩家信息处理器
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


-- WebSocket事件处理器
local ws_handler = {}

function ws_handler.on_open(ws)
    log.info("Client %s connected", tostring(ws.id))
end

function ws_handler.on_close(ws, code, reason)
    log.info("Client %s disconnected: code=%s, reason=%s",
        tostring(ws.id),
        tostring(code or "nil"),
        tostring(reason or "normal close"))
end

function ws_handler.on_message(ws, message)
    -- 记录收到的消息
    log.info("Received message: total_length=%d", #message)

    -- 使用ws_client模块处理消息
    ws_client.dispatch(ws, message)
end

local function handle_socket(id)
    log.info("New socket connection: %s", tostring(id))

    local ok, code, url, method, header, body = pcall(httpd.read_request, sockethelper.readfunc(id), 8192)
    if not ok then
        log.error("Failed to read HTTP request: %d, error: %s", id, code)
        return
    end

    log.info("HTTP request: code=%s, url=%s, method=%s", code, url, method)
    if header then
        local headers = {}
        for k, v in pairs(header) do
            table.insert(headers, k .. "=" .. tostring(v))
        end
        log.info("HTTP headers: %s", table.concat(headers, ", "))
    end

    if code then
        if header and header.upgrade and header.upgrade:lower() == "websocket" then
            log.info("Upgrading to WebSocket: %s", tostring(id))
            -- websocket request
            local ws = websocket.new(id, header, ws_handler)
            if ws then
                log.info("WebSocket created successfully: %s", tostring(id))
                ws:start()
            else
                log.error("Failed to create WebSocket: %s", tostring(id))
            end
        end
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(_, _, id)
        socket.start(id)
        local ok, err = pcall(handle_socket, id)
        if not ok then
            if not string.match(err or "", "socket.lua:.*assertion failed") then
                log.error("Handle socket error: %s", err)
            end
            socket.close(id)
        end
    end)
end)

skynet.init(ws_client.init())

return ws_handler
