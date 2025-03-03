local skynet = require "skynet"
local socket = require "socket"
local string = require "string"
local websocket = require "websocket"
local httpd = require "http.httpd"
local urllib = require "http.url"
local sockethelper = require "http.sockethelper"
local log = require "log"
local proto = require "proto_helper"

-- 确保log模块包含所有需要的方法
if not log.error then
    log.error = skynet.error
end
if not log.info then
    log.info = skynet.error
end

local handlers = {}

-- 注册登录处理器（删除重复的定义，只保留这一个）
handlers["game.LoginReq"] = function(ws, msg)
    -- 修改日志格式，统一使用 %s
    log.info("Client %s login request: account=%s",
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

local handler = {}

function handler.on_open(ws)
    log.info("Client %s connected", tostring(ws.id))
end

function handler.on_close(ws, code, reason)
    log.info("Client %s disconnected: code=%s, reason=%s",
        tostring(ws.id),
        tostring(code or "nil"),
        tostring(reason or "normal close"))
end

function handler.on_message(ws, message)
    -- 解析消息类型
    skynet.error(string.format("Received message: total_length=%d, hex=%s",
        #message,
        string.gsub(message:sub(1, math.min(32, #message)), ".",
            function(c) return string.format("%02X ", string.byte(c)) end)
    ))

    -- 从消息中读取长度前缀（4字节，小端序）
    local length = string.unpack("<I4", message:sub(1, 4))
    skynet.error("Length from prefix:", length)

    -- 跳过长度前缀，获取实际消息内容
    local msg_data = string.sub(message, 5)
    skynet.error(string.format("Actual message: length=%d, hex=%s",
        #msg_data,
        string.gsub(msg_data:sub(1, math.min(32, #msg_data)), ".",
            function(c) return string.format("%02X ", string.byte(c)) end)
    ))

    if #msg_data ~= length then
        skynet.error(string.format("Message length mismatch: expected %d, got %d", length, #msg_data))
        -- 构造错误响应
        local resp = {
            error_resp = {
                code = "INVALID_MESSAGE",
                message = "Message length mismatch"
            },
            userid = 0
        }
        send_response(ws, "game.LoginResp", resp)
        return
    end

    -- 解析整个登录请求
    local login_req = proto.unpack("game.LoginReq", msg_data)
    if not login_req then
        skynet.error("Failed to decode login request")
        local resp = {
            error_resp = {
                code = "INVALID_REQUEST",
                message = "Failed to decode login request"
            },
            userid = 0
        }
        send_response(ws, "game.LoginResp", resp)
        return
    end

    -- 处理登录请求
    local handler_fn = handlers[login_req.header.msg_type]
    if not handler_fn then
        skynet.error("Unknown message type:", login_req.header.msg_type)
        local resp = {
            error_resp = {
                code = "UNKNOWN_MESSAGE",
                message = "Unknown message type"
            },
            userid = 0
        }
        send_response(ws, "game.LoginResp", resp)
        return
    end

    -- 调用处理函数
    local resp_type, resp_data = handler_fn(ws, login_req)
    if resp_type and resp_data then
        send_response(ws, resp_type, resp_data)
    end
end

-- 发送响应
function send_response(ws, msg_type, data)
    if not ws then
        skynet.error("Cannot send response: websocket is nil")
        return
    end

    local response_data = proto.pack(msg_type, data)
    if response_data then
        -- 添加长度前缀
        local length_prefix = string.pack("<I4", #response_data)
        local response = length_prefix .. response_data
        ws:send_binary(response)
    else
        skynet.error("Failed to pack response")
    end
end

-- 发送错误响应
function send_error_response(ws, header, code, message)
    if not ws then
        skynet.error("Cannot send error response: websocket is nil")
        return
    end

    -- 修改这里，确保使用正确的消息类型
    local resp_header = {
        msg_type = "common.ErrorResp", -- 使用完整的消息类型名称
        seq = header and header.seq or 0
    }

    local resp_data = {
        code = code or "UNKNOWN_ERROR",
        message = message or "Unknown error occurred"
    }

    -- 修改错误日志输出方式
    skynet.error(string.format("Sending error response: code=%s, message=%s",
        resp_data.code,
        resp_data.message))

    local header_data = proto.pack("common.Header", resp_header)
    local body_data = proto.pack("common.ErrorResp", resp_data)

    if header_data and body_data then
        -- 计算总长度
        local total_length = #header_data + #body_data
        local length_prefix = string.pack("<I4", total_length)
        local response = length_prefix .. header_data .. body_data
        ws:send_binary(response)
    else
        skynet.error("Failed to pack error response")
    end
end

local function handle_socket(id)
    -- 修改数字类型的日志格式
    skynet.error("New socket connection: %s", tostring(id))

    local ok, code, url, method, header, body = pcall(httpd.read_request, sockethelper.readfunc(id), 8192)
    if not ok then
        skynet.error("Failed to read HTTP request: %d, error: %s", id, code)
        return
    end

    skynet.error("HTTP request: code=%s, url=%s, method=%s", code, url, method)
    if header then
        -- 修改header日志输出格式
        local headers = {}
        for k, v in pairs(header) do
            table.insert(headers, k .. "=" .. tostring(v))
        end
        skynet.error("HTTP headers: %s", table.concat(headers, ", "))
    end

    if code then
        if header and header.upgrade and header.upgrade:lower() == "websocket" then
            skynet.error("Upgrading to WebSocket: %s", tostring(id))
            -- websocket request
            local ws = websocket.new(id, header, handler)
            if ws then
                skynet.error("WebSocket created successfully: %s", tostring(id))
                ws:start()
            else
                skynet.error("Failed to create WebSocket: %s", tostring(id))
            end
        end
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(_, _, id)
        socket.start(id)
        local ok, err = pcall(handle_socket, id)
        if not ok then
            -- 只有在不是正常关闭的情况下才记录错误
            if not string.match(err or "", "socket.lua:.*assertion failed") then
                skynet.error("Handle socket error: %s", err)
            end
            socket.close(id)
        end
        -- 注意：不要在这里关闭socket，让websocket处理器来管理连接的生命周期
    end)
end)

skynet.init(function()
    proto.init()
end)

return handler
