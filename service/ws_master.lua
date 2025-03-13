local skynet = require "skynet"
local socket = require "socket"
local ws_proxy = require "ws_proxy"
local string = require "string"
local log = require "log"
local service = require "service"

-- 设置日志级别
log.set_level(log.LOG_LEVEL.DEBUG)

local wsmaster = {}
local data = { socket = {} }

local function init()
    -- 初始化网关配置
    data.host = skynet.getenv("ws_host") or "0.0.0.0"
    data.ws_port = tonumber(skynet.getenv("ws_port")) or 9555
    data.protocol = "websocket"

    -- 确保gate服务已初始化
    assert(service.gate, "gate service not initialized")
    log.debug("WebSocket服务初始化中... service.gate: %s", skynet.address(service.gate))

    -- 启动网关监听
    local ok, err = pcall(skynet.call, service.gate, "lua", "open", {
        host = data.host,
        port = data.ws_port,
        maxclient = 4096,
        nodelay = true,
        protocol = data.protocol,
        watchdog = skynet.self()
    })

    if not ok then
        log.fatal("无法启动网关监听: %s", err)
        skynet.exit()
    end

    log.info("WebSocket服务已启动，监听地址: %s:%d", data.host, data.ws_port)
end

function wsmaster.socket(subcmd, fd, ...)
    if subcmd == "open" then
        data.fd = fd
        data.addr = ...
        data.socket[fd] = "LISTENING"
        log.info("新连接: fd=%d, addr=%s", fd, data.addr)

        -- 使用代理服务处理WebSocket连接
        local ok, agent_addr = pcall(ws_proxy.subscribe, fd)
        if ok and agent_addr then
            log.debug("WebSocket连接已分配代理: fd=%d, agent=%s", fd, skynet.address(agent_addr))
            data.socket[fd] = skynet.address(agent_addr)
            skynet.ret(skynet.pack(agent_addr)) -- 直接返回代理地址
        else
            log.error("分配代理失败: fd=%d, 错误: %s", fd, agent_addr or "未知错误")
            ws_proxy.close(fd)
            data.socket[fd] = nil
            skynet.ret()
        end
    end
end

function wsmaster.disconnect()
    ws_proxy.close(data.fd)
    log.warn("客户端断开连接: fd=%d", data.fd)
end

local function finalize()
    log.info("WebSocket Master服务已启动，监听端口: %d", data.ws_port)
end

service.init {
    command = wsmaster,
    info = data,
    require = {
        -- 使用gate监听WebSocket
        "gate",
    },
    init = init,
    finalize = finalize,
}
