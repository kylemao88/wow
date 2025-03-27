import asyncio
import websockets
import os
import sys
import struct
import time
import json
import subprocess

# 获取项目根目录
ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

class SprotoLuaHandler:
    """使用Lua处理Sproto协议"""
    
    def __init__(self):
        self.process = None
        self.initialized = False
    
    async def start(self):
        """启动Lua处理器"""
        # 构建Lua脚本路径
        script_path = os.path.join(ROOT_DIR, 'test', 'sproto_handler.lua')
        
        # 启动Lua进程
        # 注意：需要确保lua命令可用，并且已安装sproto和cjson库
        self.process = await asyncio.create_subprocess_exec(
            'lua', script_path,
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        # 启动一个任务来读取并打印stderr
        asyncio.create_task(self._read_stderr())
        
        print("Lua Sproto处理器已启动")
        return True
    
    async def _read_stderr(self):
        """读取并打印Lua进程的标准错误输出"""
        while self.process:
            try:
                line = await self.process.stderr.readline()
                if not line:
                    break
                print(f"Lua stderr: {line.decode().strip()}")
            except Exception as e:
                print(f"读取Lua stderr时出错: {e}")
                break
    
    async def send_command(self, command):
        """向Lua进程发送命令并获取响应"""
        if not self.process:
            raise RuntimeError("Lua进程未启动")
        
        # 发送命令
        self.process.stdin.write(f"{command}\n".encode())
        await self.process.stdin.drain()
        
        # 读取响应
        response = await self.process.stdout.readline()
        response = response.decode().strip()
        
        # 解析响应
        if response.startswith("OK"):
            return True, response[3:].strip()
        else:
            return False, response[6:].strip() if response.startswith("ERROR") else response
    
    async def init_protocol(self, c2s_path, s2c_path):
        """初始化协议"""
        ok, result = await self.send_command(f"INIT {c2s_path} {s2c_path}")
        if ok:
            self.initialized = True
            print("Sproto协议初始化成功")
        else:
            print(f"Sproto协议初始化失败: {result}")
        return ok
    
    async def encode_request(self, name, args, session_id):
        """编码请求"""
        if not self.initialized:
            raise RuntimeError("协议未初始化")
        
        # 将参数转换为JSON
        args_json = "null" if args is None else json.dumps(args)
        
        # 发送编码命令
        ok, result = await self.send_command(f"ENCODE {name} {session_id} {args_json}")
        if ok:
            # 将十六进制字符串转换为二进制数据
            binary_data = bytes.fromhex(result)
            return binary_data
        else:
            raise RuntimeError(f"编码请求失败: {result}")
    
    async def decode_response(self, data):
        """解码响应"""
        if not self.initialized:
            raise RuntimeError("协议未初始化")
        
        # 将二进制数据转换为十六进制字符串
        hex_data = data.hex()
        
        # 发送解码命令
        ok, result = await self.send_command(f"DECODE {hex_data}")
        if ok:
            # 解析JSON响应
            return json.loads(result)
        else:
            raise RuntimeError(f"解码响应失败: {result}")
    
    async def close(self):
        """关闭Lua进程"""
        if self.process:
            self.process.terminate()
            await self.process.wait()
            self.process = None
            self.initialized = False
            print("Lua Sproto处理器已关闭")

class SprotoClient:
    """WebSocket Sproto客户端"""
    
    def __init__(self, url="ws://localhost:8081"):
        self.url = url
        self.ws = None
        self.sproto_handler = SprotoLuaHandler()
        self.session_counter = 0
        self.sessions = {}
    
    def next_session(self):
        """生成下一个会话ID"""
        self.session_counter += 1
        return self.session_counter
    
    async def connect(self):
        """连接到WebSocket服务器"""
        try:
            self.ws = await websockets.connect(self.url)
            print(f"已连接到 {self.url}")
            
            # 启动Lua Sproto处理器
            await self.sproto_handler.start()
            
            # 初始化协议
            c2s_path = os.path.join(ROOT_DIR, 'proto', 'proto.c2s.sproto')
            s2c_path = os.path.join(ROOT_DIR, 'proto', 'proto.s2c.sproto')
            await self.sproto_handler.init_protocol(c2s_path, s2c_path)
            
            return True
        except Exception as e:
            print(f"连接失败: {e}")
            return False
    
    async def request_with_response(self, name, args=None):
        """发送请求并等待响应"""
        # 生成会话ID
        session_id = self.next_session()
        if session_id == 0:  # 避免使用0作为会话ID
            session_id = self.next_session()
        
        # 记录会话信息
        self.sessions[session_id] = {"name": name, "args": args, "time": time.time()}
        
        try:
            # 使用Lua编码请求
            req_data = await self.sproto_handler.encode_request(name, args, session_id)
            
            # 添加长度前缀 - 使用2字节大端序
            length_prefix = struct.pack(">H", len(req_data))
            message = length_prefix + req_data
            
            # 打印发送的消息内容，帮助调试
            print(f"发送消息: {name}, 会话ID: {session_id}")
            print(f"请求数据(含长度前缀): {message.hex()}")
            print(f"请求数据(不含长度前缀): {req_data.hex()}")
            
            # 发送消息
            await self.ws.send(message)
            print(f"已发送 {name} 请求")
            
            # 等待响应
            try:
                response = await asyncio.wait_for(self.ws.recv(), timeout=10.0)
                print(f"收到响应: 长度={len(response)}")
                
                # 打印原始响应
                print(f"原始响应: {response.hex()}")
                
                # 解析长度前缀（2字节，大端序）
                if len(response) >= 2:
                    msg_len = struct.unpack(">H", response[:2])[0]
                    print(f"响应消息长度: {msg_len}")
                    
                    # 检查长度是否合理
                    if len(response) >= 2 + msg_len:
                        msg_data = response[2:2+msg_len]
                        print(f"响应消息内容: {msg_data.hex()}")
                        
                        # 使用Lua解码响应
                        try:
                            decoded = await self.sproto_handler.decode_response(msg_data)
                            print(f"解码响应: {decoded}")
                            
                            # 修改会话ID匹配逻辑
                            session_id = decoded.get('session', 0)
                            
                            # 如果会话ID为0，尝试通过消息类型匹配
                            if session_id == 0:
                                # 检查是否是ping响应
                                if msg_data.hex().startswith("15"):
                                    # 查找名为ping的最近会话
                                    for sid, info in sorted(self.sessions.items(), 
                                                          key=lambda x: x[1]['time'], 
                                                          reverse=True):
                                        if info['name'] == 'ping':
                                            session_info = self.sessions.pop(sid)
                                            print(f"通过消息类型匹配到ping会话: {sid}")
                                            return {
                                                "type": "ping",
                                                "session": sid,
                                                "request": session_info["args"],
                                                "response": decoded.get('response', {})
                                            }
                                
                                # 检查是否是signin响应
                                elif msg_data.hex().startswith("55"):
                                    # 查找名为signin的最近会话
                                    for sid, info in sorted(self.sessions.items(), 
                                                          key=lambda x: x[1]['time'], 
                                                          reverse=True):
                                        if info['name'] == 'signin':
                                            session_info = self.sessions.pop(sid)
                                            print(f"通过消息类型匹配到signin会话: {sid}")
                                            return {
                                                "type": "signin",
                                                "session": sid,
                                                "request": session_info["args"],
                                                "response": decoded.get('response', {})
                                            }
                                
                                # 如果无法通过类型匹配，尝试使用最近的会话
                                if self.sessions:
                                    recent_sid = max(self.sessions.keys(), 
                                                    key=lambda k: self.sessions[k]["time"])
                                    session_info = self.sessions.pop(recent_sid)
                                    print(f"使用最近的会话: {recent_sid}, 类型: {session_info['name']}")
                                    return {
                                        "type": session_info["name"],
                                        "session": recent_sid,
                                        "request": session_info["args"],
                                        "response": decoded.get('response', {})
                                    }
                            
                            # 正常会话ID匹配
                            for sid, session_info in list(self.sessions.items()):
                                if sid == session_id:
                                    session_info = self.sessions.pop(sid)
                                    return {
                                        "type": session_info["name"],
                                        "session": sid,
                                        "request": session_info["args"],
                                        "response": decoded.get('response', {})
                                    }
                            
                            print(f"警告: 收到未知会话的响应 (session={session_id})")
                            return decoded
                        except Exception as e:
                            print(f"解码响应失败: {e}")
                            return None
                    else:
                        print(f"响应消息不完整: 期望 {msg_len} 字节，实际 {len(response)-2} 字节")
                        return None
                else:
                    print(f"收到的响应太短: {len(response)} 字节")
                    return None
            except asyncio.TimeoutError:
                print("等待响应超时")
                # 清理超时会话
                self.sessions.pop(session_id, None)
                return None
            except Exception as e:
                print(f"接收响应时出错: {e}")
                import traceback
                traceback.print_exc()
                # 清理会话
                self.sessions.pop(session_id, None)
                return None
        except Exception as e:
            print(f"发送请求时出错: {e}")
            import traceback
            traceback.print_exc()
            return None
    
    async def close(self):
        """关闭连接"""
        if self.ws:
            await self.ws.close()
            self.ws = None
        
        # 关闭Lua处理器
        await self.sproto_handler.close()

async def main():
    """主函数"""
    client = SprotoClient()
    if await client.connect():
        print("\n开始发送ping请求...")
        response = await client.request_with_response("ping")
        print(f"ping响应: {response}")
        
        print("\n开始发送signin请求...")
        response = await client.request_with_response("signin", {"userid": "alice"})
        print(f"signin响应: {response}")
        
        # 等待一段时间，以便接收可能的推送消息
        await asyncio.sleep(5)
        
        # 关闭连接
        await client.close()

if __name__ == "__main__":
    asyncio.run(main())