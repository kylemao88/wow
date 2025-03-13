local skynet = require "skynet"
local socket = require "socket"
require "skynet.manager"
require "skynet.debug"
local websocket = require "websocket"
local ws_client = require "ws_client"
local log = require "log"


skynet.register_protocol {
    name = "text",
    id = skynet.PTYPE_TEXT,
    unpack = skynet.tostring,
    pack = function(text) return text end,
}

-- 存储WebSocket连接与代理服务的映射关系
local ws_fd_addr = {} -- fd -> 代理服务地址
local ws_addr_fd = {} -- 代理服务地址 -> fd
local ws_init = {}    -- 代理服务初始化状态


-- 关闭代理服务
local function close_agent(addr)
    local fd = assert(ws_addr_fd[addr])
    log.info("关闭WebSocket代理服务: fd=%d, addr=%s", fd, skynet.address(addr))
    ws_fd_addr[fd] = nil
    ws_addr_fd[addr] = nil
end


-- 订阅WebSocket连接
local function subscribe(fd)
    local addr = ws_fd_addr[fd]
    if addr then
        return addr
    end

    -- 启动新的代理服务
    log.info("为WebSocket连接创建代理服务: fd=%d", fd)
    -- local ok, new_addr = pcall(skynet.newservice, "ws_agent", tostring(fd))
    local ok, new_addr = pcall(skynet.newservice, "ws_agent")
    if not ok then
        log("创建代理服务失败: %s", new_addr)
        socket.close(fd)
        return nil
    end
    log.info("创建代理服务成功: %s", new_addr)

    -- 发送明确的START命令和fd参数
    local ok = skynet.call(new_addr, "lua", "START", fd)
    if not ok then
        log.error("启动代理服务失败: addr=%s", skynet.address(new_addr))
        socket.close(fd)
        return nil
    end
    log.info("启动代理服务成功: addr=%s", skynet.address(new_addr))

    addr = new_addr
    ws_fd_addr[fd] = addr
    ws_addr_fd[addr] = fd

    -- 不再存储响应函数，直接返回地址
    -- ws_init[addr] = skynet.response()
    return addr
end

-- 获取代理服务状态
local function get_status(addr)
    local ok, info = pcall(skynet.call, addr, "text", "STATUS")
    if ok then
        return info
    else
        return "EXIT"
    end
end

-- 注册状态查询函数
skynet.info_func(function()
    local tmp = {}
    for fd, addr in pairs(ws_fd_addr) do
        if ws_init[addr] then
            table.insert(tmp, { fd = fd, addr = skynet.address(addr), status = "INITIALIZING" })
        else
            table.insert(tmp, { fd = fd, addr = skynet.address(addr), status = get_status(addr) })
        end
    end
    return tmp
end)

skynet.start(function()
    -- 处理代理服务发来的状态通知
    skynet.dispatch("text", function(session, source, cmd)
        if cmd == "CLOSED" then
            close_agent(source)
        elseif cmd == "READY" then
            -- 不再使用存储的响应函数
            -- if ws_init[source] then
            --     ws_init[source](true, source)
            --     ws_init[source] = nil
            -- end
            log.info("代理服务已就绪: %s", skynet.address(source))
        elseif cmd == "FAIL" then
            -- 不再使用存储的响应函数
            -- if ws_init[source] then
            --     ws_init[source](false)
            --     ws_init[source] = nil
            -- end
            log.error("代理服务初始化失败: %s", skynet.address(source))
        else
            log.error("无效的命令: %s", cmd)
        end
    end)

    -- 处理WebSocket连接订阅请求
    skynet.dispatch("lua", function(session, source, fd)
        if type(fd) ~= "number" then
            log.error("订阅请求的fd不是数字: %s", tostring(fd))
            skynet.ret(skynet.pack(false))
            return
        end

        -- 优化订阅处理，增加日志
        log.info("处理WebSocket连接订阅请求: fd=%d, source=%s", fd, skynet.address(source))
        local addr = subscribe(fd)

        if addr then
            log.info("WebSocket连接订阅成功: fd=%d, agent=%s", fd, skynet.address(addr))
            skynet.ret(skynet.pack(addr))
        else
            log.error("WebSocket连接订阅失败: fd=%d", fd)
            skynet.ret(skynet.pack(false))
        end
    end)

    log.info("ws_proxyd代理服务已启动")
    skynet.register("ws_proxyd")
end)

--skynet.init(ws_client.init())
