local skynet = require "skynet"
require "skynet.manager"
--require "skynet.debug"
--local string = require "string"
local socket = require "socket"
local websocket = require "websocket"
local ws_client = require "ws_client"
local sockethelper = require "http.sockethelper"
local httpd = require "http.httpd"
--local urllib = require "http.url"
local log = require "log"

-- 注册协议
skynet.register_protocol {
    name = "client",
    id = skynet.PTYPE_CLIENT,
    pack = function(msg) return msg end,
    unpack = skynet.tostring,
}

skynet.register_protocol {
    name = "text",
    id = skynet.PTYPE_TEXT,
    pack = function(text) return text end,
    unpack = skynet.tostring,
}

--local ws_fd = tonumber(...) -- 从启动参数获取WebSocket连接fd
local ws_obj = nil      -- WebSocket对象
local is_closed = false -- 连接是否已关闭

-- WebSocket事件处理器
local ws_handler = {}

function ws_handler.on_open(ws)
    log.info("WebSocket代理服务: 客户端 %s 已连接", tostring(ws.id))
    skynet.send(".ws_proxyd", "text", "READY")
end

function ws_handler.on_close(ws, code, reason)
    log.info("WebSocket代理服务: 客户端 %s 已断开连接: code=%s, reason=%s",
        tostring(ws.id),
        tostring(code or "nil"),
        tostring(reason or "normal close"))

    is_closed = true
    skynet.send(".ws_proxyd", "text", "CLOSED")
end

function ws_handler.on_message(ws, message)
    log.info("WebSocket代理服务: 收到消息: total_length=%d", #message)

    -- 使用ws_client模块处理消息
    ws_client.dispatch(ws, message)
end

-- 初始化并启动WebSocket连接
local function init_and_start_websocket(id)
    log.info("init_and_start_websocket，新的套接字连接: %s", tostring(id))

    local ok, code, url, method, header, body = pcall(httpd.read_request, sockethelper.readfunc(id), 8192)
    if not ok then
        log.error("读取HTTP请求失败: %d, 错误: %s", id, code)
        skynet.send(".ws_proxyd", "text", "FAIL")
        --ws_proxy.close(id)
        return false
    end

    log.info("HTTP请求: code=%s, url=%s, method=%s", code, url, method)
    if header then
        local headers = {}
        for k, v in pairs(header) do
            table.insert(headers, k .. "=" .. tostring(v))
        end
        log.info("HTTP头部: %s", table.concat(headers, ", "))
    end

    if code then
        if header and header.upgrade and header.upgrade:lower() == "websocket" then
            log.info("升级到WebSocket: %s", tostring(id))
            local ws = websocket.new(id, header, ws_handler)
            if not ws then
                log.error("Failed to create WebSocket: %s", tostring(id))
                skynet.send(".ws_proxyd", "text", "FAIL")
                return false
            end

            log.info("WebSocket代理服务: 创建WebSocket对象成功")
            ws_obj = ws
            log.info("正在启动WebSocket消息循环: fd=%d", id)
            -- 启动独立协程处理消息循环
            skynet.fork(function()
                local ok, err = pcall(function()
                    ws_obj:start()
                end)

                if not ok then
                    log.error("WebSocket消息循环异常退出: %s", err)
                    is_closed = true
                    skynet.send(".ws_proxyd", "text", "CLOSED")
                end
            end)
            -- 延时100毫秒，确保WebSocket连接对象已创建
            skynet.sleep(100)
            return true
        else
            -- 处理普通HTTP请求
            log.info("普通HTTP请求，返回404")
            httpd.write_response(sockethelper.writefunc(id), 404, "Not Found")
            skynet.send(".ws_proxyd", "text", "FAIL")
            --ws_proxy.close(id)
            return false
        end
    else
        skynet.send(".ws_proxyd", "text", "FAIL")
        --ws_proxy.close(id)
    end
end

-- 处理来自其他服务的请求
skynet.start(function()
    -- 注册所有消息处理器
    skynet.dispatch("text", function(session, source, cmd)
        if cmd == "CLOSE" then
            if ws_obj and not is_closed then
                ws_obj:close()
                -- 确保关闭socket连接
                socket.close(ws_obj.id)
            end
            skynet.ret(skynet.pack(true))
        elseif cmd == "STATUS" then
            local status = is_closed and "CLOSED" or "CONNECTED"
            skynet.ret(skynet.pack(status))
        else
            log.error("WebSocket代理服务: 未知命令: %s", cmd)
            skynet.ret(skynet.pack(false))
        end
    end)

    -- 处理Lua请求
    skynet.dispatch("lua", function(session, source, cmd, id)
        -- 处理新的连接请求
        if cmd == "START" then
            socket.start(id)
            local ok, err = pcall(init_and_start_websocket, id)
            if ok and ws_obj then
                skynet.ret(skynet.pack(true))
            else
                log.error("WebSocket初始化失败: %s", tostring(err))
                socket.close(id)
                skynet.send(".ws_proxyd", "text", "FAIL")
                skynet.ret(skynet.pack(false))
            end
        else
            log.error("未知的Lua命令: %s", cmd)
            skynet.ret(skynet.pack(false))
        end
    end)

    -- 处理客户端消息
    skynet.dispatch("client", function(session, source, message)
        if ws_obj and not is_closed then
            -- 添加长度前缀
            --local length_prefix = string.pack("<I4", #response_data)
            --local response = length_prefix .. response_data
            if ws_obj.state == "open" then
                ws_obj:send_binary(message)
            else
                log.warn("尝试发送消息到已关闭的连接: fd=%d", ws_obj.id)
            end
        end
    end)

    log.info("ws_agent代理服务已启动")
end)

skynet.init(ws_client.init())
