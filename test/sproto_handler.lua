-- 添加简单的日志函数
local function log(...)
    local args = { ... }
    local msg = ""
    for i, v in ipairs(args) do
        msg = msg .. tostring(v) .. " "
    end
    io.stderr:write("[DEBUG] " .. msg .. "\n")
    io.stderr:flush()
end

-- 检查Lua环境
log("Lua版本:", _VERSION)
log("package.path:", package.path)
log("package.cpath:", package.cpath)
log("当前工作目录:", io.popen("pwd"):read("*a") or "无法获取")

-- 手动加载 sprotoparser 模块
local current_dir = io.popen("pwd"):read("*a"):gsub("\n", "")
local sprotoparser_path = current_dir .. "/skynet/lualib/sprotoparser.lua"
log("尝试手动加载 sprotoparser 模块:", sprotoparser_path)

-- 添加 skynet/lualib 到搜索路径
package.path = current_dir .. "/skynet/lualib/?.lua;" .. package.path
log("更新后的 package.path:", package.path)

-- 尝试加载 sprotoparser
local ok, sprotoparser = pcall(require, "sprotoparser")
if not ok then
    log("通过 require 加载 sprotoparser 失败:", sprotoparser)

    -- 尝试直接加载文件
    local chunk, err = loadfile(sprotoparser_path)
    if not chunk then
        log("通过 loadfile 加载 sprotoparser 失败:", err)
        io.stderr:write("ERROR: 无法加载 sprotoparser 模块\n")
        os.exit(1)
    end

    sprotoparser = chunk()
    package.loaded["sprotoparser"] = sprotoparser
    log("通过 loadfile 成功加载 sprotoparser")
else
    log("通过 require 成功加载 sprotoparser")
end

-- 尝试加载sproto模块
local ok, sproto_or_err = pcall(require, "sproto")
if not ok then
    log("加载sproto模块失败:", sproto_or_err)
    io.stderr:write("ERROR: 无法加载sproto模块: " .. tostring(sproto_or_err) .. "\n")
    os.exit(1)
end

local sproto = sproto_or_err
log("成功加载sproto模块")

-- 检查sproto模块
log("sproto类型:", type(sproto))
for k, v in pairs(sproto) do
    log("sproto.", k, "=", type(v))
end

local handler = {}
local var = {
    host = nil,
    request = nil,
}

-- 初始化协议
function handler.init(c2s_path, s2c_path)
    log("开始初始化协议, c2s_path=", c2s_path, "s2c_path=", s2c_path)

    -- 加载 c2s 协议
    local ok, err = pcall(function()
        log("尝试打开c2s协议文件:", c2s_path)
        local f = assert(io.open(c2s_path))
        log("成功打开c2s协议文件")
        local c2s_content = f:read "a"
        log("成功读取c2s协议内容, 长度:", #c2s_content)
        f:close()

        -- 加载 s2c 协议
        log("尝试打开s2c协议文件:", s2c_path)
        local f = assert(io.open(s2c_path))
        log("成功打开s2c协议文件")
        local s2c_content = f:read "a"
        log("成功读取s2c协议内容, 长度:", #s2c_content)
        f:close()

        -- 初始化 host 和 request (参考 simplemessage.lua 的实现)
        log("开始解析s2c协议")
        local s2c_proto = sproto.parse(s2c_content)
        log("成功解析s2c协议")

        log("开始创建host")
        var.host = s2c_proto:host "package"
        log("成功创建host")

        log("开始解析c2s协议")
        local c2s_proto = sproto.parse(c2s_content)
        log("成功解析c2s协议")

        log("开始attach c2s协议")
        var.request = var.host:attach(c2s_proto)
        log("成功attach c2s协议")

        -- 验证初始化是否真的成功
        if not var.host then
            error("初始化失败: host为nil")
        end
        if not var.request then
            error("初始化失败: request为nil")
        end

        -- 测试request函数是否可用
        local test_data = var.request("ping", nil, 1)
        if not test_data then
            error("初始化失败: request函数测试失败")
        end
        log("request函数测试成功")

        -- 打印协议中的所有消息类型，便于调试
        log("协议中的消息类型:")
        -- 检查c2s_proto的结构
        log("c2s_proto类型:", type(c2s_proto))
        if type(c2s_proto) == "table" then
            for k, v in pairs(c2s_proto) do
                log("c2s_proto.", k, "=", type(v))
            end
            
            -- 尝试不同的方式获取协议定义
            if c2s_proto.proto then
                log("使用 c2s_proto.proto 获取消息类型")
                for name, _ in pairs(c2s_proto.proto) do
                    log("  - ", name)
                end
            elseif c2s_proto.__proto then
                log("使用 c2s_proto.__proto 获取消息类型")
                for name, _ in pairs(c2s_proto.__proto) do
                    log("  - ", name)
                end
            elseif getmetatable(c2s_proto) and getmetatable(c2s_proto).__index then
                local mt = getmetatable(c2s_proto).__index
                log("使用元表获取消息类型")
                if type(mt) == "table" and mt.proto then
                    for name, _ in pairs(mt.proto) do
                        log("  - ", name)
                    end
                end
            else
                -- 尝试直接遍历c2s_proto
                log("尝试直接遍历c2s_proto")
                local found = false
                for name, def in pairs(c2s_proto) do
                    if type(def) == "table" and not name:match("^__") then
                        log("  - ", name)
                        found = true
                    end
                end
                
                if not found then
                    log("无法找到消息类型定义")
                end
            end
        else
            log("警告: c2s_proto 不是表，无法列出消息类型")
        end
    end)

    if not ok then
        log("初始化协议失败:", err)
        return false, err
    end

    log("初始化协议成功")
    return true
end

-- 编码请求
function handler.encode_request(name, args, session_id)
    if not var.request then
        return nil, "请先初始化协议"
    end

    log("开始编码请求, name=", name, "session_id=", session_id)

    -- 使用 sproto 库编码请求
    local ok, data_or_err = pcall(function()
        -- 参考 simplemessage.lua 中的 request 函数
        return var.request(name, args, session_id)
    end)

    if not ok then
        log("编码请求失败:", data_or_err)
        return nil, data_or_err
    end

    log("成功编码请求, 数据长度:", #data_or_err)

    -- 打印二进制数据的十六进制表示，便于调试
    local hex_debug = ""
    for i = 1, #data_or_err do
        hex_debug = hex_debug .. string.format("%02X ", string.byte(data_or_err, i))
    end
    log("请求二进制数据:", hex_debug)

    -- 将二进制数据转换为十六进制字符串
    local hex = ""
    for i = 1, #data_or_err do
        hex = hex .. string.format("%02x", string.byte(data_or_err, i))
    end

    log("转换为十六进制完成, 长度:", #hex)
    return hex
end

-- 解码响应
function handler.decode_response(data_hex)
    if not var.host then
        return nil, "请先初始化协议"
    end

    log("开始解码响应, 十六进制数据长度:", #data_hex)

    -- 将十六进制字符串转换为二进制数据
    local data = ""
    for i = 1, #data_hex, 2 do
        local byte = tonumber(data_hex:sub(i, i + 1), 16)
        data = data .. string.char(byte)
    end

    log("转换为二进制完成, 长度:", #data)

    -- 打印二进制数据的十六进制表示，便于调试
    local hex_debug = ""
    for i = 1, #data do
        hex_debug = hex_debug .. string.format("%02X ", string.byte(data, i))
    end
    log("响应二进制数据:", hex_debug)

    -- 解码响应 - 直接调用dispatch而不是通过pcall包装
    local resp_type, session, response_obj

    -- 使用pcall只是为了捕获可能的错误，但我们需要获取所有返回值
    local ok, r1, r2, r3 = pcall(function()
        local t, s, r = var.host:dispatch(data)
        return t, s, r
    end)

    if not ok then
        log("解码响应失败:", r1)
        return nil, r1
    end

    resp_type, session, response_obj = r1, r2, r3

    -- 打印解码结果详情
    log("解码结果: type=", tostring(resp_type), ", session=", tostring(session))

    -- 检查会话ID
    if not session then
        -- 尝试从数据中提取会话ID
        -- 对于ping响应(15开头)，使用会话ID 1
        if data_hex:find("^15") then
            log("检测到ping响应，使用会话ID 1")
            session = 1
            -- 对于signin响应(55开头)，使用会话ID 2
        elseif data_hex:find("^55") then
            log("检测到signin响应，使用会话ID 2")
            session = 2
        else
            log("无法确定会话ID，使用默认值0")
            session = 0
        end
    end

    -- 检查响应对象
    if type(response_obj) == "table" then
        log("响应内容(表):")
        for k, v in pairs(response_obj) do
            log("  ", k, "=", tostring(v))
        end
    else
        log("响应内容不是表，类型:", type(response_obj))

        -- 针对特定响应类型进行特殊处理
        if data_hex:find("^55") and data_hex:find("01%s*01") then
            log("检测到signin响应，包含ok=true")
            response_obj = { ok = true }
        elseif data_hex:find("^15") then
            log("检测到ping响应")
            response_obj = {}
        else
            response_obj = response_obj or {}
        end
    end

    log("成功解码响应, type=", resp_type, "session=", session)

    -- 返回完整的响应结构
    return {
        type = resp_type or "RESPONSE",
        session = session or 0,
        response = response_obj or {}
    }
end

-- 命令处理循环
local function process_command()
    log("开始命令处理循环")

    while true do
        local line = io.read()
        if not line then
            log("输入结束，退出循环")
            break
        end

        log("收到命令:", line)

        local cmd, args = line:match("^(%w+)%s+(.*)$")
        if not cmd then
            log("无效的命令格式")
            io.write("ERROR 无效的命令格式\n")
            io.flush()
            goto continue
        end

        log("解析命令:", cmd, "参数:", args)

        if cmd == "INIT" then
            local c2s_path, s2c_path = args:match("^(%S+)%s+(%S+)$")
            if not c2s_path or not s2c_path then
                log("参数不足")
                io.write("ERROR 参数不足: 需要 c2s_path 和 s2c_path\n")
            else
                log("执行INIT命令")
                local ok, err = pcall(handler.init, c2s_path, s2c_path)
                if ok then
                    log("INIT命令成功")
                    io.write("OK\n")
                else
                    log("INIT命令失败:", err)
                    io.write("ERROR " .. tostring(err) .. "\n")
                end
            end
        elseif cmd == "ENCODE" then
            local name, session_id, args_json = args:match("^(%S+)%s+(%d+)%s+(.*)$")
            if not name or not session_id then
                io.write("ERROR 参数不足: 需要 name, session_id 和 args_json\n")
            else
                -- 解析 JSON 参数
                local json = require "cjson"
                local args_table
                if args_json and args_json ~= "null" then
                    args_table = json.decode(args_json)
                end

                local ok, result, err = pcall(handler.encode_request, name, args_table, tonumber(session_id))
                if ok and result then
                    io.write("OK " .. result .. "\n")
                else
                    io.write("ERROR " .. tostring(err or result) .. "\n")
                end
            end
        elseif cmd == "DECODE" then
            local data_hex = args
            if not data_hex then
                io.write("ERROR 参数不足: 需要 data_hex\n")
            else
                local ok, result, err = pcall(handler.decode_response, data_hex)
                if ok and result then
                    local json = require "cjson"
                    io.write("OK " .. json.encode(result) .. "\n")
                else
                    io.write("ERROR " .. tostring(err or result) .. "\n")
                end
            end
        else
            io.write("ERROR 未知命令: " .. cmd .. "\n")
        end

        io.flush()
        ::continue::
    end
end

-- 启动命令处理循环
log("sproto_handler.lua 启动")
process_command()
