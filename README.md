这是一个使用 skynet 搭建服务器的简单例子。它很简陋，主要想演示一下 https://github.com/cloudwu/skynet_package 以及 sproto 协议封装的用法。

这个例子可以作为构建游戏服务器的参考，但它并不作为 skynet 推荐的服务器框架使用模式。它还很不完整，可能存在许多疏忽的地方，以及需要针对实际需求做进一步优化。

如何编译
========

1. clone 下本仓库。
2. 更新 submodule ，服务器部分需要用到 skynet ；客户端部分需要用到 lsocket 。
```
git submodule update --init
```
3. 编译 skynet
```
cd skynet
make linux
```
4. 编译 lsocket（如果你需要客户端）
```
make socket
```
5. 编译 skynet package 模块
```
make
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




