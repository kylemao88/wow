这是一个使用 skynet 搭建服务器的初始框架。

如何编译
========

1. clone 下本仓库。
2. 更新 submodule ，服务器部分需要用到 skynet ；
```
git submodule update --init
```
1. 编译 skynet
```
cd skynet
make linux
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
debug版本
```
python3.8 test/ws_client.py
```
simple版本
```
python3.8 test/ws_client_simple.py
```



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
