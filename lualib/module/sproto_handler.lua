local skynet = require "skynet"
local log = require "log"
local sproto_client = require "sproto_client"

-- 创建处理器表
local handler = {}

-- 加载各模块处理器
local function load_handlers()
    -- 定义要加载的模块列表
    local modules = {
        "base.base",         -- 基础功能
        "members.member",    -- 会员管理
        "battle.pve_battle", -- 战斗系统
        -- 可以根据需要添加更多模块
    }

    -- 加载每个模块并合并处理器
    for _, module_name in ipairs(modules) do
        local module_path = module_name
        local ok, module_handler = pcall(require, module_path)

        if ok and module_handler then
            log.info("成功加载处理器模块: %s", module_path)

            -- 将模块中的处理器合并到主处理器表中
            for name, func in pairs(module_handler) do
                handler[name] = func
                log.debug("注册处理器: %s 来自模块 %s", name, module_path)
            end
        else
            log.error("加载处理器模块失败: %s 错误: %s", module_path, tostring(module_handler))
        end
    end
end

-- 加载所有处理器
load_handlers()

-- 将处理器注册到sproto_client
local client_handler = sproto_client.handler()
for name, func in pairs(handler) do
    client_handler[name] = func
end

return handler
