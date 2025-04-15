local skynet = require "skynet"
local log = require "log"
local sprotoloader = require "sprotoloader"

local sproto_client = {}
local host
local sender
local handler = {}


function sproto_client.handler()
    return handler
end

function sproto_client.dispatch(ws, message)
    -- 从消息中读取长度前缀（2字节，大端序）
    local length = string.unpack(">H", message, 1)
    log.info("Sproto消息长度: %s", length)

    -- 跳过长度前缀，获取实际消息内容
    local msg_data = string.sub(message, 3)
    log.info("Sproto实际消息: 长度=%d, 十六进制=%s", #msg_data,
        string.format("%s", (string.gsub(msg_data, ".", function(c) return string.format("%02X ", string.byte(c)) end))))

    if #msg_data ~= length then
        log.error("Sproto消息长度不匹配: 期望 %d, 实际 %d", length, #msg_data)
        sproto_client.send_error(ws, nil, "消息长度不匹配")
        return
    end

    -- 解析Sproto消息
    log.info("准备dispatch sproto消息...")

    local msg_type, name, args, response = host:dispatch(msg_data)
    -- 添加详细日志，输出type, name, args, respons
    log.info("Sproto消息类型, type: %s, name: %s", tostring(msg_type), tostring(name))
    log.info("Sproto消息参数, args: %s", tostring(args))
    log.info("Sproto消息响应, response: %s", tostring(response))


    assert(msg_type == "REQUEST")

    local f = handler[name]
    if f then
        -- f可能会阻塞，所以fork一个协程来运行
        skynet.fork(function()
            local ok, result = pcall(f, ws, args)
            if ok then
                -- 发送响应
                local resp_data = response(result)
                local length_prefix = string.pack(">H", #resp_data)
                ws:send_binary(length_prefix .. resp_data)
                -- log.info("Sproto回应消息: 长度=%d, 十六进制=%s", #resp_data,
                --     string.format("%s",
                --         (string.gsub(resp_data, ".", function(c) return string.format("%02X ", string.byte(c)) end))))
                log.info("Sproto回应消息: 长度=%d", #resp_data)


                -- 添加调试日志
                log.info("发送响应: %s", tostring(result))
                if type(result) == "table" then
                    for k, v in pairs(result) do
                        log.info("  %s = %s", tostring(k), tostring(v))
                    end
                end
            else
                log.error("处理Sproto消息错误: %s", result)
                local ERROR = {}
                local resp_data = response(ERROR, result)
                local length_prefix = string.pack(">H", #resp_data)
                ws:send_binary(length_prefix .. resp_data)
            end
        end)
    else
        log.error("未知的Sproto消息: %s", name)
        error("无效的命令 " .. name)
    end
end

function sproto_client.push(ws, t, data)
    if not ws then
        log.error("无法发送推送消息: websocket为空")
        return
    end

    local push_data = sender(t, data)
    if push_data then
        local length_prefix = string.pack(">H", #push_data)
        local message = length_prefix .. push_data
        ws:send_binary(message)
    else
        log.error("打包推送消息失败")
    end
end

function sproto_client.send_error(ws, session, message)
    log.error("发送Sproto错误: %s", message)
    -- 在实际应用中，可以实现一个标准的错误响应
end

function sproto_client.init()
    return function()
        local protoloader = skynet.uniqueservice "sproto_loader"
        skynet.call(protoloader, "lua", "load", {
            "proto.c2s",
            "proto.s2c",
        })

        local slot = skynet.call(protoloader, "lua", "index", "proto.c2s")
        host = sprotoloader.load(slot):host "package"

        local slot2 = skynet.call(protoloader, "lua", "index", "proto.s2c")
        sender = host:attach(sprotoloader.load(slot2))

        log.info("Sproto协议初始化完成")
    end
end

return sproto_client
