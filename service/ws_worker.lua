local skynet = require "skynet"
local socket = require "socket"
local string = require "string"
local websocket = require "websocket"
local httpd = require "http.httpd"
local urllib = require "http.url"
local sockethelper = require "http.sockethelper"
local log = require "log"

local handler = {}

function handler.on_open(ws)
    log("%d::open", ws.id)
end

function handler.on_message(ws, message)
    log("%d receive:%s", ws.id, message)
    ws:send_text(message .. " from server")
    --ws:close()
end

function handler.on_close(ws, code, reason)
    log("%d close:%s  %s", ws.id, code, reason)
end

local function handle_socket(id)
    -- limit request body size to 8192 (you can pass nil to unlimit)
    local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), 8192)
    --LOG_INFO(code, url, method, header, body)
    if code then
        if header.upgrade == "websocket" then
            -- websocket request
            local ws = websocket.new(id, header, handler)
            ws:start()
        end    
    end
end

skynet.start(function()
    skynet.dispatch("lua", function (_,_,id)
        socket.start(id)
        pcall(handle_socket, id)
        socket.close(id)
    end)
end)
