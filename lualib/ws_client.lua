local skynet = require "skynet"
local string = require "string"
local log = require "log"
local proto = require "proto_helper"


local ws_client = {}

-- 消息处理器表，用于存储不同消息类型对应的处理函数，方便业务模块注册消息处理函数
-- 键(key)为消息类型字符串，如"game.LoginReq"
-- 值(value)为处理函数，函数签名为 function(ws, req) -> resp_type, resp_data
-- 其中:
--   ws: WebSocket连接对象
--   req: 解析后的请求消息
--   resp_type: 返回的响应消息类型
--   resp_data: 返回的响应消息数据
-- 使用示例:
-- handler["game.LoginReq"] = function(ws, req)
--     -- 处理登录请求
--     return "game.LoginResp", { userid = "123", token = "xxx" }
-- end
--local handler = {}
local handler = require "msg_handler"

function ws_client.handler()
    return handler
end

-- 消息分发处理
function ws_client.dispatch(ws, message)
    -- 从消息中读取长度前缀（4字节，小端序）
    -- 使用<I4格式，<表示小端序，I4表示4字节无符号整数
    local length = string.unpack("<I4", message, 1)
    log.info("Length from prefix: %s", length)

    -- 跳过长度前缀，获取实际消息内容
    local msg_data = string.sub(message, 5)
    log.info("Actual message: length=%d", #msg_data)

    if #msg_data ~= length then
        log.error("Message length mismatch: expected %d, got %d", length, #msg_data)
        ws_client.send_error(ws, nil, "INVALID_MESSAGE", "Message length mismatch")
        return
    end

    -- 打印原始消息的前32个字节(十六进制)，帮助调试
    local hex_dump = ""
    for i = 1, math.min(32, #msg_data) do
        hex_dump = hex_dump .. string.format("%02X ", string.byte(msg_data, i))
    end
    log.info("消息前32字节: %s", hex_dump)

    -- 纯 Lua 实现的位操作函数
    local function band(a, b)
        local result = 0
        local bitval = 1
        while a > 0 and b > 0 do
            if a % 2 == 1 and b % 2 == 1 then
                result = result + bitval
            end
            bitval = bitval * 2
            a = math.floor(a / 2)
            b = math.floor(b / 2)
        end
        return result
    end

    local function rshift(x, n)
        return math.floor(x / (2 ^ n))
    end

    local function lshift(x, n)
        return x * (2 ^ n)
    end

    local function bor(a, b)
        local result = 0
        local bitval = 1
        while a > 0 or b > 0 do
            if a % 2 == 1 or b % 2 == 1 then
                result = result + bitval
            end
            bitval = bitval * 2
            a = math.floor(a / 2)
            b = math.floor(b / 2)
        end
        return result
    end

    -- 解析第一个字段（应该是header字段）
    -- 在Protobuf编码中，每个字段都以一个tag字节开始，包含字段编号和线路类型
    local first_byte = string.byte(msg_data, 1)
    -- 字段编号(field_number)存储在tag字节的高5位，需要右移3位获取
    local field_number = rshift(first_byte, 3)
    -- 线路类型(wire_type)存储在tag字节的低3位，使用与操作(0x07)提取
    -- wire_type=0: Varint (int32, int64, uint32, uint64, bool, enum)
    -- wire_type=1: 64位 (fixed64, sfixed64, double)
    -- wire_type=2: 长度前缀 (string, bytes, embedded messages)
    -- wire_type=5: 32位 (fixed32, sfixed32, float)
    local wire_type = band(first_byte, 0x07)
    -- 验证第一个字段是否为header字段
    -- 在我们的协议中，header应该是第一个字段(field_number=1)
    -- 且应该是一个嵌入式消息(wire_type=2)
    if field_number ~= 1 or wire_type ~= 2 then
        log.error(string.format("消息格式错误：第一个字段必须是header(field_number=1, wire_type=2), got field_number=%d, wire_type=%d",
            field_number, wire_type))
        ws_client.send_error(ws, nil, "INVALID_MESSAGE", "Invalid message format")
        return
    end

    -- 读取header字段的长度
    -- 对于wire_type=2的字段，tag字节后跟一个varint表示嵌入消息的长度
    local pos = 2           -- 从第2个字节开始读取长度
    local header_length = 0 -- 初始化header长度
    local shift = 0         -- 用于varint解码的位移值
    -- 解析varint编码的长度值
    -- Protobuf的varint编码：每个字节的最高位(MSB)表示是否还有后续字节
    -- 每个字节的低7位用于表示实际值，需要按位或操作组合
    while true do
        local b = string.byte(msg_data, pos)
        -- 取字节的低7位，左移适当位数，与结果进行按位或操作
        header_length = bor(header_length, lshift(band(b, 0x7F), shift))
        -- 如果最高位为0，表示varint编码结束
        if band(b, 0x80) == 0 then break end
        -- 否则继续读取下一个字节，位移增加7位
        shift = shift + 7
        pos = pos + 1
    end

    -- 提取header数据并解析
    local header_data = string.sub(msg_data, pos + 1, pos + header_length)
    local ok, header = pcall(proto.unpack, "common.Header", header_data)

    if not ok then
        log.error("解析消息头部时发生错误: %s", tostring(header))
        ws_client.send_error(ws, nil, "INVALID_HEADER", "解析消息头部时发生错误")
        return
    end

    if not header or not header.msg_type then
        log.error("消息头部缺少msg_type字段")
        ws_client.send_error(ws, nil, "INVALID_HEADER", "消息头部缺少msg_type字段")
        return
    end

    -- 获取消息类型
    local msg_type = header.msg_type
    log.info("检测到消息类型: %s", msg_type)
    local req = proto.unpack(msg_type, msg_data)
    if not req then
        log.error("Failed to decode request of type: %s", msg_type)
        ws_client.send_error(ws, header, "INVALID_REQUEST", "Failed to decode request")
        return
    end

    -- 处理请求
    local f = handler[msg_type]
    if f then
        -- f可能会阻塞，所以fork一个协程来运行
        skynet.fork(function()
            local ok, resp_type, resp_data = pcall(f, ws, req)
            if ok and resp_type and resp_data then
                ws_client.send_response(ws, resp_type, resp_data)
            elseif not ok then
                log.error("Handler error: %s", resp_type) -- 错误信息在resp_type中
                ws_client.send_error(ws, header, "SERVER_ERROR", "Internal server error")
            end
        end)
    else
        log.error("Unknown message type: %s", msg_type)
        ws_client.send_error(ws, header, "UNKNOWN_MESSAGE", "Unknown message type")
    end
end

-- 发送响应
function ws_client.send_response(ws, msg_type, data)
    if not ws then
        log.error("Cannot send response: websocket is nil")
        return
    end

    local response_data = proto.pack(msg_type, data)
    if response_data then
        -- 添加长度前缀
        local length_prefix = string.pack("<I4", #response_data)
        local response = length_prefix .. response_data
        ws:send_binary(response)
    else
        log.error("Failed to pack response")
    end
end

-- 发送错误响应
function ws_client.send_error(ws, header, code, message)
    if not ws then
        log.error("Cannot send error response: websocket is nil")
        return
    end

    local resp_header = {
        msg_type = "common.ErrorResp",
        seq = header and header.seq or 0
    }

    local resp_data = {
        code = code or "UNKNOWN_ERROR",
        message = message or "Unknown error occurred"
    }

    log.error("Sending error response: code=%s, message=%s",
        resp_data.code,
        resp_data.message)

    local header_data = proto.pack("common.Header", resp_header)
    local body_data = proto.pack("common.ErrorResp", resp_data)

    if header_data and body_data then
        local total_length = #header_data + #body_data
        local length_prefix = string.pack("<I4", total_length)
        local response = length_prefix .. header_data .. body_data
        ws:send_binary(response)
    else
        log.error("Failed to pack error response")
    end
end

--- 初始化函数
function ws_client.init()
    return function()
        proto.init()
        log.info("protobuf协议初始化完成")
    end
end

return ws_client
