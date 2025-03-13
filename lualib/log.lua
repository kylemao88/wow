local skynet = require "skynet"

-- 日志级别常量
local LOG_LEVEL = {
	TRACE = 1,
	DEBUG = 2,
	INFO = 3,
	WARN = 4,
	ERROR = 5,
	FATAL = 6
}

-- 默认配置
local config = {
	level = LOG_LEVEL.INFO,
	timestamp = true,
	color = true,
	output = skynet.error, -- 默认使用skynet的日志输出
	format = "[$level] $time $msg",
	colors = {
		[LOG_LEVEL.TRACE] = "\27[36m", -- 青色
		[LOG_LEVEL.DEBUG] = "\27[34m", -- 蓝色
		[LOG_LEVEL.INFO] = "\27[32m", -- 绿色
		[LOG_LEVEL.WARN] = "\27[33m", -- 黄色
		[LOG_LEVEL.ERROR] = "\27[31m", -- 红色
		[LOG_LEVEL.FATAL] = "\27[35m" -- 紫色
	}
}

-- 日志级别名称
local level_names = {
	[LOG_LEVEL.TRACE] = "TRACE",
	[LOG_LEVEL.DEBUG] = "DEBUG",
	[LOG_LEVEL.INFO] = "INFO",
	[LOG_LEVEL.WARN] = "WARN",
	[LOG_LEVEL.ERROR] = "ERROR",
	[LOG_LEVEL.FATAL] = "FATAL"
}

local function format_message(level, ...)
	local args = { ... }
	local msg

	-- 尝试使用string.format进行格式化
	if #args > 0 then
		if #args == 1 then
			-- 单个参数，不需要格式化
			msg = tostring(args[1])
		else
			-- 直接使用string.format，第一个参数是格式字符串
			local success, result = pcall(string.format, ...)

			if success then
				msg = result
			else
				-- 格式化失败，回退到简单连接
				local parts = {}
				for i = 1, #args do
					table.insert(parts, tostring(args[i]))
				end
				msg = table.concat(parts, " ")
			end
		end
	else
		msg = ""
	end

	local time = os.date("%Y-%m-%d %H:%M:%S")

	-- 直接构建格式化字符串，不使用gsub
	local formatted = "[" .. level_names[level] .. "] " .. time .. " " .. msg

	if config.color then
		formatted = config.colors[level] .. formatted .. "\27[0m"
	end

	return formatted
end

local function log(level, ...)
	if level < config.level then return end
	local msg = format_message(level, ...)
	config.output(msg)
end

-- 公共接口
local M = {
	LOG_LEVEL = LOG_LEVEL -- 将LOG_LEVEL常量添加到模块返回表中
}

function M.set_level(level)
	config.level = level
end

function M.set_output(output)
	config.output = output
end

function M.set_format(format)
	config.format = format
end

function M.enable_color(enable)
	config.color = enable
end

function M.trace(...)
	log(LOG_LEVEL.TRACE, ...)
end

function M.debug(...)
	log(LOG_LEVEL.DEBUG, ...)
end

function M.info(...)
	log(LOG_LEVEL.INFO, ...)
end

function M.warn(...)
	log(LOG_LEVEL.WARN, ...)
end

function M.error(...)
	log(LOG_LEVEL.ERROR, ...)
end

function M.fatal(...)
	log(LOG_LEVEL.FATAL, ...)
end

return M
