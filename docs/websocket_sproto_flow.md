# WebSocket + Sproto 流程总结

## 框架概述

WFFF 框架支持两种通信协议组合：WebSocket+Protobuf 和 WebSocket+Sproto。本文重点介绍 WebSocket+Sproto 的工作流程，帮助新人快速理解框架结构和通信机制。

## 核心组件及其职责

### 1. 服务启动与初始化 (main.lua)

`main.lua` 是整个系统的入口点，负责：

- 启动各种核心服务
- 通过 `protocol_selector` 选择使用的协议类型
- 当选择 Sproto 协议时，初始化 `sproto_loader` 服务

```lua
-- 初始化协议
local protocol = protocol_selector.init()
log.info("使用 %s 协议", protocol.type)

-- 如果使用Sproto协议，初始化Sproto加载器
if protocol.type == protocol_selector.PROTOCOL_TYPE.SPROTO then
    local sproto_loader = skynet.uniqueservice("sproto_loader")
    log.info("Sproto加载器服务已启动，地址: %s", skynet.address(sproto_loader))
end
```

### 2. 协议选择器 (protocol_selector.lua)
`protocol_selector.lua` 负责:
- 根据配置选择使用的协议类型，并提供相应的初始化和消息处理函数
  
```lua
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


### 6. Sproto 协议加载器 (sproto_loader.lua)
`sproto_loader.lua` 负责:
-  加载和解析 Sproto 协议文件：
  
```lua
function loader.load(list)
    for i, name in ipairs(list) do
        local p = load(name)
        log.info("加载Sproto协议 [%s] 到槽位 %d", name, i)
        data[name] = i
        sprotoloader.save(p, i)
    end
end
```


### 7. Sproto 客户端 (sproto_client.lua)
`sproto_client.lua` 负责:
-  Sproto 消息的编码、解码和分发

```lua
function sproto_client.dispatch(ws, message)
    -- 从消息中读取长度前缀（2字节，大端序）
    local length = string.unpack(">H", message, 1)
    -- 跳过长度前缀，获取实际消息内容
    local msg_data = string.sub(message, 3)
    
    -- 解析Sproto消息
    local msg_type, name, args, response = host:dispatch(msg_data)
    
    -- 查找并调用对应的处理函数
    local f = handler[name]
    if f then
        skynet.fork(function()
            local ok, result = pcall(f, ws, args)
            if ok then
                -- 发送响应
                local resp_data = response(result)
                local length_prefix = string.pack(">H", #resp_data)
                ws:send_binary(length_prefix .. resp_data)
            end
        end)
    end
end

```


### 8. Sproto 消息处理器 (sproto_handler.lua)
`sproto_handler.lua` 负责:
-  定义了各种 Sproto 消息的处理函数
  
```lua
-- 示例：处理login消息
handler["login"] = function(ws, args)
    log.info("收到登录请求")
    -- 发送欢迎推送消息
    sproto_client.push(ws, "push", { text = "欢迎使用Sproto协议!" })
    return { ok = true }
end
```



### 9. 协议定义文件 (proto.c2s.sproto 和 proto.s2c.sproto)
`proto.c2s.sproto` 和 `proto.s2c.sproto` 负责:
-  定义了客户端到服务器和服务器到客户端的消息格式
  
```lua
.package {
    type 0 : integer
    session 1 : integer
    ud 2 : string
}

ping 1 {}

signup 2 {
    request {
        userid 0 : string
    }
    response {
        ok 0 : boolean
    }
}

```

## 通信流程

### 1. 服务器启动流程
   - main.lua 启动并初始化各种服务
   - 通过 protocol_selector.init() 选择使用 Sproto 协议
   - 启动 sproto_loader 服务加载协议文件
   - 启动 ws_master 服务监听 WebSocket 连接

### 2. 客户端连接流程
   - 客户端发起 WebSocket 连接请求
   - ws_master 接收连接请求，调用 ws_proxy.subscribe(fd) 分配代理
   - ws_proxyd 创建新的 ws_agent 服务处理该连接
   - ws_agent 完成 WebSocket 握手，建立连接


### 3. 消息处理流程
   - 客户端发送 Sproto 格式的消息
   - ws_agent 的 on_message 回调接收消息
   - 调用 protocol.dispatch(ws, message) 处理消息
   - sproto_client.dispatch 解析消息，提取 type 、 name 和 args
   - 查找并调用 sproto_handler 中对应的处理函数
   - 处理函数返回结果，通过 response(result) 生成响应消息
   - 将响应消息发送回客户端

### 4. 服务器推送流程
   - 服务器需要主动推送消息给客户端
   - 调用 sproto_client.push(ws, t, data) 函数
   - 使用 sender(t, data) 编码消息
   - 添加长度前缀，通过 ws:send_binary(message) 发送给客户端


## 关键点总结
   - 协议选择机制 ：通过 protocol_selector 实现协议的灵活切换
   - 服务分层 ：主服务、代理管理服务、单连接代理服务的清晰分层
   - 消息处理流程 ：从接收原始消息到解析、分发、处理、响应的完整流程
   - Sproto 特性 ：
       - .package 作为消息头，包含 type 、 session 和 ud 字段
       - type 字段用于标识消息类型，对应协议定义中的数字 ID
       - session 字段用于请求-响应匹配
       - 支持请求-响应模式和单向推送模式


## 开发指南

### 1. 添加新的消息处理
- 在 proto.c2s.sproto 中定义新的消息格式：
```lua
  new_message 5 {
    request {
        param1 0 : integer
        param2 1 : string
    }
    response {
        result 0 : boolean
        data 1 : string
    }
}
```
- 在 sproto_handler.lua 中添加对应的处理函数：
```lua
handler["new_message"] = function(ws, args)
    log.info("收到新消息请求: param1=%d, param2=%s", args.param1, args.param2)
    -- 处理业务逻辑
    return {
        result = true,
        data = "处理成功"
    }
end
```

### 2. 服务器主动推送消息(待测试验证)
- 使用 sproto_client.push 函数向客户端推送消息：
```lua
-- 在 proto.s2c.sproto 中定义推送消息格式
-- notification 2 {
--     request {
--         type 0 : integer
--         content 1 : string
--     }
-- }

-- 在业务代码中推送消息
sproto_client.push(ws, "notification", {
    type = 1,
    content = "这是一条服务器推送的通知"
})
```





