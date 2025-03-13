local skynet = require "skynet"
local log = require "log"

--print("log module:", log)
--print("LOG_LEVEL:", log.LOG_LEVEL)

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

    -- 启动WebSocket代理管理服务
    local proxyd = skynet.uniqueservice("ws_proxyd")
    -- skynet.register('.ws_proxyd') -- 旧版api，新版本不推荐使用
    -- skynet.name(".ws_proxyd", proxyd) -- 使用新版推荐的 name API
    log.info("WebSocket代理管理服务已启动，地址: %s", skynet.address(proxyd))

    -- 启动ws_master服务
    local masterd = skynet.uniqueservice("ws_master")
    --skynet.name(".ws_master", masterd)
    log.info("WebSocket Master服务已启动，地址: %s", skynet.address(masterd))

    log.info("系统初始化完成")
    skynet.exit()
end)
