# WebSocket + Protobuf 流程总结

## 框架概述

WFFF 框架支持两种通信协议组合：WebSocket+Protobuf 和 WebSocket+Sproto。本文重点介绍 WebSocket+Protobuf 的工作流程，帮助新人快速理解框架结构和通信机制。

## 核心组件及其职责

### 1. 服务启动与初始化 (main.lua)

`main.lua` 是整个系统的入口点，负责：

- 启动各种核心服务
- 通过 `protocol_selector` 选择使用的协议类型
- 启动 WebSocket 相关服务

```lua
-- 初始化协议
local protocol = protocol_selector.init()
log.info("使用 %s 协议", protocol.type)

-- 启动WebSocket代理管理服务
local proxyd = skynet.uniqueservice("ws_proxyd")
log.info("WebSocket代理管理服务已启动，地址: %s", skynet.address(proxyd))

-- 启动ws_master服务
local masterd = skynet.uniqueservice("ws_master")
log.info("WebSocket Master服务已启动，地址: %s", skynet.address(masterd))
```

### 2. 协议选择器 (protocol_selector.lua)
`protocol_selector.lua` 负责:
- 根据配置选择使用的协议类型，并提供相应的初始化和消息处理函数
  
```lua
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
```

### 3. WebSocket 服务管理 (ws_master.lua)
`ws_master.lua` 负责:
-  监听 WebSocket 连接请求，并为每个连接分配代理服务：
  
```lua
function wsmaster.socket(subcmd, fd, ...)
    if subcmd == "open" then
        -- 使用代理服务处理WebSocket连接
        local ok, agent_addr = pcall(ws_proxy.subscribe, fd)
        if ok and agent_addr then
            log.debug("WebSocket连接已分配代理: fd=%d, agent=%s", fd, skynet.address(agent_addr))
            data.socket[fd] = skynet.address(agent_addr)
            skynet.ret(skynet.pack(agent_addr)) -- 直接返回代理地址
        end
    end
end
```

### 4. WebSocket 代理管理 (ws_proxyd.lua)
`ws_proxyd.lua` 负责:
-  创建和管理 WebSocket 代理服务(即ws_agent服务)
  
```lua
-- 订阅WebSocket连接
local function subscribe(fd)
    -- 启动新的代理服务
    local ok, new_addr = pcall(skynet.newservice, "ws_agent")
    -- 发送明确的START命令和fd参数
    local ok = skynet.call(new_addr, "lua", "START", fd)
    
    addr = new_addr
    ws_fd_addr[fd] = addr
    ws_addr_fd[addr] = fd
    
    return addr
end
```

### 5. WebSocket 代理服务 (ws_agent.lua)
`ws_agent.lua` 负责:
-  处理单个 WebSocket 连接的消息收发
  
```lua
function ws_handler.on_message(ws, message)
    log.info("WebSocket代理服务: 收到消息: total_length=%d", #message)
    -- 使用当前协议处理消息
    protocol.dispatch(ws, message)
end
```


### 6. Protobuf 客户端 (ws_client.lua)
`ws_client.lua` 负责:
-  Protobuf 消息的编码、解码和分发
  
```lua
function ws_client.dispatch(ws, message)
    -- 从消息中读取长度前缀（4字节，小端序）
    local length = string.unpack("<I4", message, 1)
    
    -- 跳过长度前缀，获取实际消息内容
    local msg_data = string.sub(message, 5)
    
    -- 解析第一个字段（应该是header字段）
    -- 在Protobuf编码中，每个字段都以一个tag字节开始，包含字段编号和线路类型
    local first_byte = string.byte(msg_data, 1)
    local field_number = rshift(first_byte, 3)
    local wire_type = band(first_byte, 0x07)
    
    -- 验证第一个字段是否为header字段
    if field_number ~= 1 or wire_type ~= 2 then
        log.error("消息格式错误：第一个字段必须是header")
        ws_client.send_error(ws, nil, "INVALID_MESSAGE", "Invalid message format")
        return
    end
    

    -- 提取header数据并解析
    local header_data = string.sub(msg_data, pos + 1, pos + header_length)
    local ok, header = pcall(proto.unpack, "common.Header", header_data)

    -- 读取header字段的长度和内容
    -- 解析header中的消息类型
    local msg_type = header.msg_type
    
    -- 根据消息类型查找对应的处理函数
    local handler_func = handler[msg_type]
    if not handler_func then
        log.error("未知的消息类型: %s", msg_type)
        ws_client.send_error(ws, header.session_id, "UNKNOWN_MESSAGE_TYPE", "Unknown message type")
        return
    end
    
    -- 解析消息体
    local ok, req = pcall(proto.unpack, msg_type, msg_data)
    
    -- 调用处理函数
    local resp_type, resp_data = handler_func(ws, req)
    
    -- 发送响应
    ws_client.send_response(ws, header.session_id, resp_type, resp_data)
end
```


### 7. Protobuf 消息处理器 (msg_handler.lua)
`msg_handler.lua` 负责:
-  定义了各种 Protobuf 消息的处理函数
  
```lua
-- 示例：处理login消息
-- 登录请求处理
handler["game.LoginReq"] = function(ws, msg)
    log.info("Client %s login request: account=%s",
        tostring(ws.id),
        tostring(msg.account))

    -- 1. 检查账号是否存在
    local user_id = skynet.call(".cacheproxyd", "lua", "get", "account:" .. msg.account)

    -- 2. 新用户注册
    if not user_id then
        user_id = tostring(skynet.call(".cacheproxyd", "lua", "incr", "global:userid"))
        skynet.call(".cacheproxyd", "lua", "hmset",
            "user:" .. user_id,
            "account", msg.account,
            "nickname", "Player" .. user_id,
            "level", 1,
            "exp", 0,
            "vip", 0
        )
        skynet.call(".cacheproxyd", "lua", "set", "account:" .. msg.account, user_id)
    end

    -- 3. 生成会话token
    local token = skynet.call(".cacheproxyd", "lua", "generate_session", user_id)

    local resp = {
        error_resp = {
            code = "SUCCESS",
            message = "Login successful"
        },
        userid = tonumber(user_id),
        token = token,
        expires_in = 3600
    }

    return "game.LoginResp", resp
end
```


### 8. Protobuf 协议辅助工具 (proto_helper.lua)
`proto_helper.lua` 负责:
-  提供了 Protobuf 协议的加载、编码和解码功能：
  
```lua
function proto.init()
    local function load_proto(filename)
        -- 使用 protoc 命令行工具预编译 proto 文件
        local proto_path = skynet.getenv("root") .. "/proto"
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

        return true
    end

    -- 清理之前可能存在的类型定义
    pb.clear()

    -- 只加载 game.proto，它会自动包含 common.proto
    if not load_proto("game.proto") then
        return false
    end

    return true
end

```


### 9. 协议定义文件 (common.proto 和 game.proto)
`common.proto` 和 `game.proto` 负责:
-  定义了客户端到服务器和服务器到客户端的消息格式
  
```lua
// common.proto
syntax = "proto3";
package common;

message Header {
    string msg_type = 1;    // 消息类型
    int32 session_id = 2;   // 会话ID
    string token = 3;       // 认证令牌
}

message ErrorResp {
    string code = 1;        // 错误代码
    string message = 2;     // 错误消息
}

// game.proto
syntax = "proto3";
package game;

import "common.proto";

message LoginReq {
    common.Header header = 1;  // 添加消息头
    string account = 2;
    string password = 3;
}

message LoginResp {
    common.ErrorResp error_resp = 1;  // 错误响应
    int64 userid = 2;         // 用户ID
}

```


## 通信流程

### 1. 服务器启动流程
   - main.lua 启动并初始化各种服务
   - 通过 protocol_selector.init() 选择使用 Protobuf 协议
   - 启动 ws_master 服务监听 WebSocket 连接

### 2. 客户端连接流程
   - 客户端发起 WebSocket 连接请求
   - ws_master 接收连接请求，调用 ws_proxy.subscribe(fd) 分配代理
   - ws_proxyd 创建新的 ws_agent 服务处理该连接
   - ws_agent 完成 WebSocket 握手，建立连接


### 3. 消息处理流程
   - 客户端发送 Protobuf 格式的消息
   - ws_agent 的 on_message 回调接收消息
   - 调用 protocol.dispatch(ws, message) 处理消息
   - ws_client.dispatch 解析消息，提取消息头和消息体
   - 根据消息类型查找 msg_handler 中对应的处理函数
   - 处理函数返回响应类型和数据
   - 使用 proto_helper 编码响应消息
   - 将响应消息发送回客户端

### 4. 消息格式
   - Protobuf 消息格式包含以下部分：
     - 长度前缀 ：4字节小端序整数，表示消息体的长度
     - 消息头 ：包含消息类型、会话ID和认证令牌
     - 消息体 ：根据消息类型不同，包含不同的字段


## 关键点总结
   - 协议选择机制 ：通过 protocol_selector 实现协议的灵活切换
   - 服务分层 ：主服务、代理管理服务、单连接代理服务的清晰分层
   - 消息处理流程 ：从接收原始消息到解析、分发、处理、响应的完整流程
   - Protobuf 特性 ：
       - 使用 .proto 文件定义消息结构
       - 支持消息嵌套和导入
       - 二进制编码，高效紧凑
       - 使用 protoc 工具预编译 .proto 文件

## 开发指南

### 1. 添加新的消息处理
- 在 game.proto 中定义新的消息格式：
```lua
    message NewMessageReq {
        common.Header header = 1;
        int32 param1 = 2;
        string param2 = 3;
    }

    message NewMessageResp {
        common.ErrorResp error_resp = 1;
        bool result = 2;
        string data = 3;
    }
```
- 在 msg_handler.lua 中添加对应的处理函数：
```lua
handler["game.NewMessageReq"] = function(ws, msg)
    log.info("收到新消息请求: param1=%d, param2=%s", msg.param1, msg.param2)
    -- 处理业务逻辑
    return "game.NewMessageResp", {
        error_resp = {
            code = "SUCCESS",
            message = "处理成功"
        },
        result = true,
        data = "处理结果"
    }
end
```





