local skynet = require "skynet"
local log = require "log"
local websocket = require "websocket"
local ws_client = require "ws_client"

-- 确保log模块包含所有需要的方法
if not log.error then log.error = skynet.error end
if not log.info then log.info = skynet.error end

local proxyd
local proxy = {}
local map = {} -- 缓存fd到代理服务地址的映射

-- 初始化时获取代理服务地址
skynet.init(function()
    proxyd = skynet.uniqueservice("ws_proxyd")
    log.info("ws_proxyd代理客户端已初始化, 代理服务地址: %s", skynet.address(proxyd))
end)

-- 注册文本协议
skynet.register_protocol {
    name = "text",
    id = skynet.PTYPE_TEXT,
    pack = function(text) return text end,
    unpack = function(buf, sz) return skynet.tostring(buf, sz) end,
}

-- 注册二进制协议
skynet.register_protocol {
    name = "client",
    id = skynet.PTYPE_CLIENT,
    pack = function(buf, sz) return buf, sz end,
}

-- 获取代理服务地址
local function get_addr(fd)
    local addr = map[fd]
    if not addr then
        log.error("未找到WebSocket连接的代理服务: fd=%d", fd)
        return nil
    end
    return addr
end

-- 订阅WebSocket连接
function proxy.subscribe(fd)
    local addr = map[fd]
    if not addr then
        log.info("订阅WebSocket连接: fd=%d", fd)
        addr = skynet.call(proxyd, "lua", fd)
        map[fd] = addr
    end
    return addr
end

-- 发送消息
function proxy.send(fd, message)
    local addr = get_addr(fd)
    if addr then
        skynet.send(addr, "client", message)
        return true
    end
    return false
end

-- 发送消息并等待响应
function proxy.call(fd, message)
    local addr = get_addr(fd)
    if addr then
        return skynet.call(addr, "lua", "CALL", message)
    end
    return false
end

-- 关闭连接
function proxy.close(fd)
    local addr = get_addr(fd)
    if addr then
        skynet.send(addr, "text", "CLOSE")
    end
    map[fd] = nil
end

-- 获取连接状态
function proxy.status(fd)
    local addr = get_addr(fd)
    if addr then
        return skynet.call(addr, "text", "STATUS")
    end
    return "DISCONNECTED"
end

return proxy
