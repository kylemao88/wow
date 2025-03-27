local skynet = require "skynet"
local log = require "log"
--print("log module:", log)
--print("LOG_LEVEL:", log.LOG_LEVEL)
local protocol_selector = require "protocol_selector" -- 新增：引入协议选择器

-- 设置日志级别
log.set_level(log.LOG_LEVEL.DEBUG)

skynet.start(function()
    log.info("服务器启动中...")

    -- 如果不是守护进程模式，启动控制台服务
    if not skynet.getenv "daemon" then
        local console = skynet.newservice("console")
        log.debug("控制台服务已启动")
    end

    -- 启动调试控制台
    skynet.newservice("debug_console", 8000)
    log.debug("调试控制台已启动，端口: 8000")

    -- 初始化协议
    local protocol = protocol_selector.init()
    log.info("使用 %s 协议", protocol.type)

    -- 如果使用Sproto协议，初始化Sproto加载器
    if protocol.type == protocol_selector.PROTOCOL_TYPE.SPROTO then
        local sproto_loader = skynet.uniqueservice("sproto_loader")
        log.info("Sproto加载器服务已启动，地址: %s", skynet.address(sproto_loader))
    end

    -- 启动WebSocket代理管理服务
    local proxyd = skynet.uniqueservice("ws_proxyd")
    log.info("WebSocket代理管理服务已启动，地址: %s", skynet.address(proxyd))

    -- 启动ws_master服务
    local masterd = skynet.uniqueservice("ws_master")
    log.info("WebSocket Master服务已启动，地址: %s", skynet.address(masterd))

    -- 启动Redis缓存代理服务
    local cacheproxyd = skynet.uniqueservice("cacheproxyd")
    log.info("Redis缓存代理服务已启动，地址: %s", skynet.address(cacheproxyd))

    -- 启动DB缓存代理服务
    local dbproxyd = skynet.uniqueservice("dbproxyd")
    log.info("DB缓存代理服务已启动，地址: %s", skynet.address(dbproxyd))

    log.info("系统初始化完成")
    skynet.exit()
end)
