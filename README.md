这是一个使用 skynet 搭建服务器的初始框架。

如何编译
========

1. clone 下本仓库。
2. 更新 submodule ，服务器部分需要用到 skynet ；
```
git submodule update --init
```
3. 编译 skynet
```
cd skynet
make linux
```
4. 编译 pb.so
```
详见`注意问题记录`第1点；
```


如何运行服务器
==============

以前台模式启动
```
./run.sh
```
用 Ctrl-C 可以退出

以后台模式启动
```
./run.sh -D
```

用下列指令可以杀掉后台进程
```
./run.sh -k
```

后台模式下，log 记录在 `run/skynet.log` 中。

如何运行客户端
==============
【protobuf】debug版本
```
python3.8 test/ws_client.py
```
【protobuf】simple版本
```
python3.8 test/ws_client_simple.py
```
【protobuf】长连接版本
```
python3.8 test/ws_client_longconn.py
```
【sproto】客户端
```
python3.8 test/ws_client_sproto.py
```

配置说明
==============
```
1. 配置文件config
    a. ws_host = "0.0.0.0"  -- 监听ip地址
    b. ws_port = 8081       -- 监听端口（注意端口重复占用问题）
    c. protocol_type = "sproto"  -- 协议类型配置: protobuf 或 sproto
```

协议和实现handler说明
==============
```
1. protobuf协议部分可参考docs/websocket_pb_flow.md
2. sproto协议部分可参考docs/websocket_sproto_flow.md
```


Sproto协议加载过程
==============
 ```
 文本协议文件(.sproto)
       |
       V
 读取文件内容(f:read "a")
       |
       V
 合并多个文件内容,如果有的话(table.concat)
       |
       V
 解析为二进制格式(sprotoparser.parse)
       |
       V
 保存到共享内存(sprotoloader.save)
 ```

Sproto 协议客户端关键代码实现
==============
## 1. 发送 Sproto 协议的关键代码 (Python 客户端)
在 ws_client_sproto.py 中，发送 Sproto 协议的关键代码如下：
```python
# 1. 生成会话ID
session_id = self.next_session()
if session_id == 0:  # 避免使用0作为会话ID
    session_id = self.next_session()

# 2. 使用Lua编码请求
req_data = await self.sproto_handler.encode_request(name, args, session_id)

# 3. 添加长度前缀 - 使用2字节大端序
length_prefix = struct.pack(">H", len(req_data))
message = length_prefix + req_data

# 4. 发送消息
await self.ws.send(message)
```
## 2. Sproto 协议组包的关键代码 (Lua 处理器)
在 sproto_handler.lua 中，Sproto 协议组包的关键代码如下：
```lua
-- 编码请求
function handler.encode_request(name, args, session_id)
    if not var.request then
        return nil, "请先初始化协议"
    end

    -- 使用 sproto 库编码请求
    local ok, data_or_err = pcall(function()
        -- 核心组包代码：调用 var.request 函数:
            -- name : 协议名称（如 "ping", "signin")
            -- args : 请求参数
            -- session_id : 会话ID
        return var.request(name, args, session_id)
    end)

    if not ok then
        return nil, data_or_err
    end

    -- 将二进制数据转换为十六进制字符串
    local hex = ""
    for i = 1, #data_or_err do
        hex = hex .. string.format("%02x", string.byte(data_or_err, i))
    end

    return hex
end
```
而 var.request 函数是在初始化时创建的：
```lua
-- 初始化协议
function handler.init(c2s_path, s2c_path)
    -- 加载协议文件内容
    local f = assert(io.open(c2s_path))
    local c2s_content = f:read "a"
    f:close()
...    
    local f = assert(io.open(s2c_path))
    local s2c_content = f:read "a"
    f:close()

    -- 解析协议
    local s2c_proto = sproto.parse(s2c_content)
    -- 创建 host 对象，指定 "package" 作为消息头
    var.host = s2c_proto:host "package"
...    
    -- 解析 c2s 协议，将其附加到 host 对象，创建 request 函数
    local c2s_proto = sproto.parse(c2s_content)
    var.request = var.host:attach(c2s_proto)
end
```
流程说明：
   - 当调用 var.request(name, args, session_id) 时，Sproto 库会：
     1. 查找名为 name 的协议定义
     2. 自动创建包含 .package 字段的消息头
     3. 将 session_id 设置到 .package.session 字段
     4. 将协议 ID 设置到 .package.type 字段
     5. 将用户参数 args 添加到消息体中
     6. 序列化整个消息（包括头部和消息体）
## 3. 总结
Sproto 协议的发送和组包流程：
1. 客户端发送流程 ：
   - 生成会话ID
   - 调用 Lua 处理器编码请求
   - 添加长度前缀
   - 通过 WebSocket 发送
2. 协议组包流程 ：
   - 初始化时解析协议文件
   - 创建 host 对象，指定 "package" 作为消息头
   - 创建 request 函数
   - 调用 request 函数编码消息，自动处理消息头
   - 将二进制数据转换为十六进制字符串返回给客户端



注意问题记录
==============
```
1. 编译pb.so一定要注意跟skynet的lua版本一致：
cd wfff/3rd/lua-protobuf
gcc -O2 -fPIC --shared \
    -DLUA_USE_LINUX \
    -DLUA_COMPAT_5_2 \
    -I../../skynet/3rd/lua \
    -o pb.so pb.c
cp pb.so ../../skynet/luaclib/
chmod 755 ../../skynet/luaclib/pb.so
```

```
2. 解决protobuf解析问题时，发现lua-protobuf不支持解析部分解析; 
在处理解析消息包头（header）时，采用的是自实现的方式，稳定性待测试；
```

```
3. 在启动service服务时， 在skynet.start接口里，不应该执行实际业务代码，通常做法只是注册消息处理器skynet.dispatch等；
   并且在service服务间互相调用时，应该注意服务间的上下文环境，避免在服务间传递资源后失效，比如fd等；
```

```
4. Lua处理器[sproto_handler.lua]是如何处理消息头的 ：
   a. 在`sproto_handler.lua` 中，关键代码是var.request(name, args, session_id),而 var.request 是在初始化时通过以下代码创建的：
        log("开始创建host")
        var.host = s2c_proto:host "package"
        log("成功创建host")
        log("开始解析c2s协议")
        local c2s_proto = sproto.parse(c2s_content)
        log("成功解析c2s协议")
        log("开始attach c2s协议")
        var.request = var.host:attach(c2s_proto)
        log("成功attach c2s协议")

  b. 实际的打包过程：
    当调用 var.request(name, args, session_id) 时，Sproto 库会执行以下操作：
    1. 查找名为 name 的协议定义（例如 "ping"、"signin" 等）
    2. 自动创建一个包含 .package 字段的消息头
    3. 将 session_id 设置到 .package.session 字段
    4. 将协议 ID（例如 ping 的 1、signin 的 3）设置到 .package.type 字段
    5. .package.ud 字段通常不设置，除非显式提供
    这个过程是由 Sproto 库内部处理的，不需要开发者手动构建消息头。

  c. 具体实现细节 :
    在 Sproto 库内部， var.request 函数（由 var.host:attach(c2s_proto) 创建）会：
    1. 根据协议名称查找对应的协议 ID
    2. 创建一个包含 .package 的消息结构
    3. 设置 .package.type 为协议 ID
    4. 设置 .package.session 为传入的 session_id
    5. 将用户参数 args 添加到消息体中
    6. 序列化整个消息（包括头部和消息体）
    这样，客户端不需要显式构建 .package 结构，只需要提供协议名称、参数和会话 ID，Sproto 库会自动处理消息头的构建和序列化。

  d. 总结：
    .package 消息头的三个字段处理方式：
    - type ：由协议名称自动映射到对应的协议 ID
    - session ：直接使用传入的 session_id
    - ud ：通常不设置，除非显式提供
    这种设计使得开发者可以专注于业务逻辑，而不需要关心底层的消息头构建细节。      
```

```
5. 记录一下依赖项（可能有遗漏）：
   a. autoconf 及其相关工具:
        sudo yum update
        sudo yum install autoconf automake libtool
        sudo yum groupinstall "Development Tools"
        make linux
   a. Lua 5.3或者更高版本 、Lua 开发包 、  LuaRocks
        sudo yum install lua-devel
        sudo yum install luarocks ；  luarocks make rockspecs/lua-protobuf-scm-1.rockspec ；  
   b. Python 3.8+  &&  pip（python包管理器）
   c. Lua依赖库： sproto.so 、cjson.so 、 lpeg.so （ 推荐目录 /usr/local/lib/lua/5.3 ）
   d. lua-resty-websocket : OpenResty 的 WebSocket 库 （ 可选 ） 
   e. Python 依赖库 ： websockets 、 protobuf 、 sproto等
```

版本架构演进记录
==============
```
v0.1 :
    1. 实现了一个简单的websocket+protobuf mvp版本服务器，客户端可以和服务端实现ws+pb模式的通信；
    2. ws_master.lua 实现了端口监听，并启动ws_worker服务用于处理连接请求；
    3. ws_worker.lua 处理连接请求，具体实现websocket的握手、启动，并调用ws_client.lua模块处理消息；
    4. ws_client.lua 处理消息，包括协议解析、消息分发； 消息分发会回调业务注册的方法，此设计为方便各业务专注业务逻辑实现；
```

```
v0.2 :
    1. 进一步丰富了服务器框架设计；引入了ws_agent代理服务管理websocket连接，避免单点故障；
    2. ws_master.lua 实现端口监听，并启动相关依赖服务，调用ws_worker服务用于处理连接请求；
    3. ws_worker.lua 处理连接请求，具体只实现websocket的握手，并把握手成功后的fd通过调用ws_proxy管理，这里解耦了处理连接请求和处理消息；
    4. ws_proxy.lua 管理websocket连接，包括消息发送、消息分发等；
    5. ws_client.lua 处理消息，包括协议解析、消息分发； 消息分发会回调业务注册的方法，此设计为方便各业务专注业务逻辑实现；
```

```
v0.3 :
    1. 多通信协议支持，支持protobuf 和 sproto ；
       protocol_selector.lua: 协议选择器，支持动态选择不同协议格式；
    2. websocket.lua: WebSocket通信基础实现，包含连接建立、数据帧处理和消息收发逻辑；
    3. 增加了sproto协议实现； sproto_client.lua: Sproto协议客户端实现，负责编码解码和消息处理
    4. ws_proxy.lua: WebSocket代理服务，用于连接转发和负载均衡
    5. 增加对DB和Redis的操作代理服务；cacheproxyd 和 dbproxyd 负责访问redis和mysql；
    6. 完善config；
```

