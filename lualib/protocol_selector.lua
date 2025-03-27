local skynet = require "skynet"
local log = require "log"

local selector = {}

-- 协议类型常量
selector.PROTOCOL_TYPE = {
    PROTOBUF = "protobuf",
    SPROTO = "sproto"
}

-- 当前使用的协议类型
local current_protocol = nil

-- 初始化协议选择器
function selector.init()
    -- 从环境变量获取协议类型
    local protocol_type = skynet.getenv("protocol_type") or selector.PROTOCOL_TYPE.PROTOBUF
    
    if protocol_type == selector.PROTOCOL_TYPE.PROTOBUF then
        log.info("使用Protobuf协议")
        selector.use_protobuf()
    elseif protocol_type == selector.PROTOCOL_TYPE.SPROTO then
        log.info("使用Sproto协议")
        selector.use_sproto()
    else
        log.error("未知的协议类型: %s，默认使用Protobuf", protocol_type)
        selector.use_protobuf()
    end
    
    return current_protocol
end

-- 使用Protobuf协议
function selector.use_protobuf()
    local ws_client = require "ws_client"
    require "msg_handler"  -- 加载Protobuf消息处理器
    
    current_protocol = {
        type = selector.PROTOCOL_TYPE.PROTOBUF,
        client = ws_client,
        init = ws_client.init(),
        dispatch = ws_client.dispatch
    }
    
    return current_protocol
end

-- 使用Sproto协议
function selector.use_sproto()
    local sproto_client = require "sproto_client"
    require "sproto_handler"  -- 加载Sproto消息处理器
    
    current_protocol = {
        type = selector.PROTOCOL_TYPE.SPROTO,
        client = sproto_client,
        init = sproto_client.init(),
        dispatch = sproto_client.dispatch
    }
    
    return current_protocol
end

-- 获取当前协议
function selector.get_current()
    if not current_protocol then
        return selector.init()
    end
    return current_protocol
end

return selector