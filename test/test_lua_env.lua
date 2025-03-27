-- 测试Lua环境和依赖库
print("===== Lua环境信息 =====")
print("Lua版本: " .. _VERSION)
print("操作系统: " .. (package.config:sub(1, 1) == "\\" and "Windows" or "Unix-like"))
print("当前工作目录: " .. (io.popen("cd"):read("*l") or "无法获取"))
print("package.path: " .. package.path)
print("package.cpath: " .. package.cpath)

-- 测试基础库
print("\n===== 基础库检测 =====")
local function test_require(module_name, test_func)
    local status, module = pcall(require, module_name)
    if status then
        local version = "未知"
        if module._VERSION then
            version = module._VERSION
        elseif module.version then
            version = module.version
        elseif module._VERSION_ then
            version = module._VERSION_
        end

        print(module_name .. " 已加载，版本: " .. version)

        -- 如果提供了测试函数，执行它
        if test_func then
            local test_status, test_result = pcall(test_func, module)
            if not test_status then
                print("  - 功能测试失败: " .. tostring(test_result))
            end
        end

        return true, module
    else
        print(module_name .. " 加载失败: " .. tostring(module))
        return false, nil
    end
end

-- 测试luasocket
local socket_ok, socket = test_require("socket", function(m)
    local host, port = "www.baidu.com", 80
    local tcp = m.tcp()
    tcp:settimeout(3)
    local ok, err = tcp:connect(host, port)
    if ok then
        print("  - 成功连接到 " .. host .. ":" .. port)
        tcp:close()
    else
        print("  - 连接测试失败: " .. tostring(err))
    end
end)

-- 测试lua-cjson
local cjson_ok, cjson = test_require("cjson", function(m)
    local test_obj = { name = "test", value = 123, array = { 1, 2, 3 } }
    local json_str = m.encode(test_obj)
    local decoded = m.decode(json_str)
    print("  - JSON编解码测试: " .. json_str)
end)

-- 测试sproto
local sproto_ok, sproto = test_require("sproto", function(m)
    local proto_str = [[
.package {
    type 0 : integer
    session 1 : integer
}
ping 1 {}
    ]]
    local proto = m.parse(proto_str)
    if proto then
        print("  - sproto解析测试成功")
    end
end)

-- 测试resty.websocket (如果可用)
local ws_ok, ws = test_require("resty.websocket.client")

-- 测试其他可能用到的库
local lpeg_ok = test_require("lpeg")
local lfs_ok = test_require("lfs", function(m)
    print("  - 当前目录: " .. m.currentdir())
    print("  - 目录内容:")
    for file in m.dir(".") do
        if file ~= "." and file ~= ".." then
            local attr = m.attributes(file)
            print("    - " .. file .. " (" .. attr.mode .. ")")
        end
    end
end)

-- 测试skynet相关库 (如果可用)
local skynet_ok = test_require("skynet")
local sprotoloader_ok = test_require("sprotoloader")

-- 总结
print("\n===== 检测结果汇总 =====")
local required_libs = {
    { "socket", socket_ok, "网络通信" },
    { "cjson", cjson_ok, "JSON编解码" },
    { "sproto", sproto_ok, "协议解析" },
    { "resty.websocket", ws_ok, "WebSocket支持" },
    { "lpeg", lpeg_ok, "模式匹配 (可选)" },
    { "lfs", lfs_ok, "文件系统操作 (可选)" },
    { "skynet", skynet_ok, "Skynet框架 (可选)" },
    { "sprotoloader", sprotoloader_ok, "Sproto加载器 (可选)" }
}

local all_required_ok = true
local all_optional_ok = true

print("必需库:")
for _, lib in ipairs(required_libs) do
    local name, ok, desc = table.unpack(lib)
    local optional = desc:find("可选")

    if not optional then
        print(string.format("  - %s: %s (%s)",
            name,
            ok and "✓" or "✗",
            desc))

        if not ok then
            all_required_ok = false
        end
    end
end

print("可选库:")
for _, lib in ipairs(required_libs) do
    local name, ok, desc = table.unpack(lib)
    local optional = desc:find("可选")

    if optional then
        print(string.format("  - %s: %s (%s)",
            name,
            ok and "✓" or "✗",
            desc))

        if not ok then
            all_optional_ok = false
        end
    end
end

print("\n===== 最终结论 =====")
if all_required_ok then
    print("所有必需依赖库加载成功！")
else
    print("警告: 部分必需依赖库加载失败，请检查上述输出。")
end

if not all_optional_ok then
    print("提示: 部分可选依赖库加载失败，但不影响基本功能。")
end

-- 尝试获取内存使用情况
if collectgarbage then
    collectgarbage("collect")
    local mem_kb = collectgarbage("count")
    print(string.format("当前Lua内存使用: %.2f KB", mem_kb))
end
