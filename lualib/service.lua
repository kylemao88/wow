local skynet = require "skynet"
local log = require "log"

local service = {}

function service.init(mod)
	local funcs = mod.command
	if mod.info then
		skynet.info_func(function()
			return mod.info
		end)
	end
	skynet.start(function()
		--  启动依赖服务
		if mod.require then
			local s = mod.require
			for _, name in ipairs(s) do
				service[name] = skynet.uniqueservice(name)
			end
		end
		-- 启动初始化服务
		if mod.init then
			mod.init()
		end
		-- 处理命令
		skynet.dispatch("lua", function(_, _, cmd, ...)
			local f = funcs[cmd]
			if f then
				skynet.ret(skynet.pack(f(...)))
			else
				log.error("Unknown command : [%s]", cmd)
				skynet.response()(false)
			end
		end)
		-- 处理最后扫尾工作, 比如关闭数据库连接, 释放资源，打印日志等
		if mod.finalize then
			mod.finalize()
		end
	end)
end

return service
