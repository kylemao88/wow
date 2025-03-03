local skynet = require "skynet"
local pb = require "pb"

local proto = {}

function proto.init()
    local function load_proto(filename)
        -- 使用 protoc 命令行工具预编译 proto 文件
        local proto_path = skynet.getenv("root") .. "/proto"
        -- 修改 protoc 命令，添加 --include_imports 参数
        local cmd = string.format("protoc --proto_path=%s --include_imports --descriptor_set_out=%s/%s.pb %s/%s",
            proto_path, proto_path, filename:gsub("%.proto$", ""), proto_path, filename)

        local ok = os.execute(cmd)
        if not ok then
            skynet.error("Failed to compile proto file:", filename)
            return false
        end

        -- 读取编译后的 .pb 文件
        local f = assert(io.open(proto_path .. "/" .. filename:gsub("%.proto$", "") .. ".pb", "rb"))
        local content = f:read("*a")
        f:close()

        -- 加载编译后的 protobuf 数据
        local ok, err = pcall(pb.load, content)
        if not ok then
            skynet.error("Failed to load compiled proto:", filename, err)
            return false
        end

        -- 验证类型是否加载成功
        local types = {}
        for name in pb.types() do
            -- 移除类型名称前面的点
            name = name:gsub("^%.", "")
            table.insert(types, name)
        end
        skynet.error("Loaded types for " .. filename .. ":", #types > 0 and table.concat(types, ", ") or "none")
        return true
    end

    -- 清理之前可能存在的类型定义
    pb.clear()

    -- 只加载 game.proto，它会自动包含 common.proto
    if not load_proto("game.proto") then
        return false
    end

    -- 验证所需的消息类型是否存在
    local required_types = { "common.Header", "game.LoginReq", "game.LoginResp", "common.ErrorResp" }
    for _, type_name in ipairs(required_types) do
        -- 检查时添加点前缀
        if not pb.type("." .. type_name) then
            skynet.error("Required message type not found:", type_name)
            -- 打印所有已加载的类型以便调试
            skynet.error("Available types:")
            for name in pb.types() do
                name = name:gsub("^%.", "")
                skynet.error("  -", name)
            end
            return false
        end
    end

    skynet.error("Proto files loaded successfully")
    return true
end

function proto.pack(msg_type, msg_data)
    -- 检查消息类型是否存在，添加点前缀
    if not pb.type("." .. msg_type) then
        skynet.error("Message type not found:", msg_type)
        return nil
    end

    skynet.error("Packing message type:", msg_type)
    if msg_data then
        -- 将 msg_data 转换为字符串表示
        local str = ""
        for k, v in pairs(msg_data) do
            if type(v) == "table" then
                str = str .. k .. "={...}, "
            else
                str = str .. k .. "=" .. tostring(v) .. ", "
            end
        end
        skynet.error("Message data:", str)
    end

    -- 编码时也需要添加点前缀
    local ok, data = pcall(pb.encode, "." .. msg_type, msg_data or {})
    if not ok then
        skynet.error("Failed to encode:", msg_type, data)
        return nil
    end

    -- 添加编码后数据的十六进制输出
    if data then
        skynet.error(string.format("Encoded data (hex): %s",
            string.gsub(data:sub(1, math.min(32, #data)), ".",
                function(c) return string.format("%02X ", string.byte(c)) end)
        ))
    end
    return data
end

function proto.unpack(msg_type, msg_data)
    -- 检查参数
    if not msg_type or not msg_data then
        skynet.error("Invalid parameters: msg_type or msg_data is nil")
        return nil
    end

    -- 检查消息类型是否存在，添加点前缀
    if not pb.type("." .. msg_type) then
        skynet.error("Message type not found:", msg_type)
        return nil
    end

    skynet.error("Unpacking message type:", msg_type)
    -- 添加输入数据的十六进制输出
    skynet.error(string.format("Input data (hex): %s",
        string.gsub(msg_data:sub(1, math.min(32, #msg_data)), ".",
            function(c) return string.format("%02X ", string.byte(c)) end)
    ))

    -- 解码时也需要添加点前缀
    local ok, data = pcall(pb.decode, "." .. msg_type, msg_data)
    if not ok then
        skynet.error("Failed to decode:", msg_type, data)
        skynet.error("Raw message length:", #msg_data)
        return nil
    end

    if data then
        -- 将 data 转换为字符串表示
        local function table_to_string(t, indent)
            indent = indent or ""
            local str = "{"
            for k, v in pairs(t) do
                if type(v) == "table" then
                    str = str .. "\n" .. indent .. "  " .. k .. "=" .. table_to_string(v, indent .. "  ")
                else
                    str = str .. "\n" .. indent .. "  " .. k .. "=" .. tostring(v)
                end
            end
            return str .. "\n" .. indent .. "}"
        end
        skynet.error("Unpacked data:", table_to_string(data))
    end
    return data
end

-- 添加辅助函数来获取消息大小
function proto.size(msg_type, msg_data)
    if not msg_data then return 0 end
    local encoded = proto.pack(msg_type, msg_data)
    return encoded and #encoded or 0
end

return proto
