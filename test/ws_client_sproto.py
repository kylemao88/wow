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

async def test_get_player_member():
    """测试获取玩家成员信息"""
    client = SprotoClient()
    if await client.connect():
        try:
            print("\n开始发送get_player_member请求...")
            # 修改这里：将字符串参数改为不带引号的形式
            response = await client.request_with_response("get_player_member", {"player_id": "player_101"})
            
            if response:
                print("\n获取玩家成员信息成功:")
                print(f"会话ID: {response.get('session')}")
                
                # 打印成员信息
                members = response.get('response', {}).get('members', [])
                if members:
                    print(f"共获取到 {len(members)} 个成员信息:")
                    for i, member in enumerate(members, 1):
                        print(f"\n成员 {i}:")
                        print(f"  ID: {member.get('member_id')}")
                        print(f"  昵称: {member.get('nickname')}")
                        print(f"  性别: {member.get('gender')}")
                        print(f"  职业: {member.get('profession_name')} (ID: {member.get('profession_id')})")
                        print(f"  种族: {member.get('race_name')} (ID: {member.get('race_id')})")
                        print(f"  天赋: {member.get('talent_name')} (ID: {member.get('talent_id')})")
                        print(f"  位置: {member.get('position')}")
                        print(f"  装备等级: {member.get('equipment_level')}")
                else:
                    print("未获取到成员信息")
            else:
                print("请求失败或未收到响应")
        except Exception as e:
            print(f"测试过程中出错: {e}")
            import traceback
            traceback.print_exc()
        finally:
            # 关闭连接
            await client.close()
    else:
        print("连接服务器失败")

async def test_get_boss_info():
    """测试获取Boss信息"""
    client = SprotoClient()
    if await client.connect():
        try:
            print("\n开始发送get_boss_info请求...")
            response = await client.request_with_response("get_boss_info", {"boss_id": "boss_001"})
            
            if response:
                print("\n获取Boss信息成功:")
                print(f"会话ID: {response.get('session')}")
                
                # 检查响应状态
                resp_data = response.get('response', {})
                ok = resp_data.get('ok', False)
                
                if ok:
                    # 打印Boss信息
                    boss = resp_data.get('boss', {})
                    if boss:
                        print("\nBoss信息:")
                        print(f"  ID: {boss.get('boss_id')}")
                        print(f"  名称: {boss.get('boss_name')}")
                        print(f"  等级: {boss.get('boss_level')}")
                        print(f"  最低要求等级: {boss.get('min_required_level')}")
                        print(f"  需要坦克数量: {boss.get('tank_required')}")
                        print(f"  需要治疗数量: {boss.get('healer_required')}")
                        print(f"  需要输出数量: {boss.get('dps_required')}")
                        print(f"  战斗时长限制: {boss.get('battle_time_limit')}秒")
                        print(f"  备注: {boss.get('remarks')}")
                    else:
                        print("响应中没有Boss信息")
                else:
                    # 打印错误信息
                    error = resp_data.get('error', {})
                    print(f"请求失败: {error.get('code')} - {error.get('message')}")
            else:
                print("请求失败或未收到响应")
        except Exception as e:
            print(f"测试过程中出错: {e}")
            import traceback
            traceback.print_exc()
        finally:
            # 关闭连接
            await client.close()
    else:
        print("连接服务器失败")

async def test_pve_prepare_battle():
    """测试PVE玩家选择会员备战接口"""
    client = SprotoClient()
    if await client.connect():
        try:
            print("\n开始发送pve_prepare_battle请求...")
            
            # 准备请求参数
            request_data = {
                "player_id": "player_101",
                "boss_id": "boss_001",
                "member_ids": [
                    "member_001",  # 坦克
                    "member_002",  # 坦克
                    "member_003",  # 治疗
                    "member_004",  # 治疗
                    "member_005",  # 治疗
                    "member_006",  # 治疗
                    "member_007",  # 输出
                    "member_008",  # 输出
                    "member_009",  # 输出
                    "member_010",  # 输出
                    "member_011",  # 输出
                    "member_012",  # 输出
                    "member_013",  # 输出
                    "member_014",  # 输出
                    "member_015",  # 输出
                    "member_016",  # 输出
                    "member_017",  # 输出
                    "member_018",  # 输出
                    "member_019",  # 输出
                    "member_020",  # 输出
                    "member_021"   # 输出
                ]
            }
            
            response = await client.request_with_response("pve_prepare_battle", request_data)
            
            if response:
                print("\nPVE备战请求结果:")
                print(f"会话ID: {response.get('session')}")
                
                # 检查响应状态
                resp_data = response.get('response', {})
                ok = resp_data.get('ok', False)
                
                if ok:
                    # 打印备战信息
                    print("\n备战成功:")
                    print(f"  战斗ID: {resp_data.get('battle_id')}")
                    print(f"  备战状态: {'就绪' if resp_data.get('ready_status') else '未就绪'}")
                else:
                    # 打印错误信息
                    error = resp_data.get('error', {})
                    print(f"备战失败: {error.get('code')} - {error.get('message')}")
            else:
                print("请求失败或未收到响应")
        except Exception as e:
            print(f"测试过程中出错: {e}")
            import traceback
            traceback.print_exc()
        finally:
            # 关闭连接
            await client.close()
    else:
        print("连接服务器失败")

async def test_pve_battle():
    """测试PVE玩家战斗接口"""
    client = SprotoClient()
    if await client.connect():
        try:
            print("\n开始发送pve_battle请求...")
            
            # 首先需要准备一场战斗，获取battle_id
            print("准备战斗，获取battle_id...")
            prepare_request = {
                "player_id": "player_101",
                "boss_id": "boss_001",
                "member_ids": [
                    "member_001", "member_002",  # 坦克
                    "member_003", "member_004", "member_005", "member_006",  # 治疗
                    "member_007", "member_008", "member_009", "member_010",
                    "member_011", "member_012", "member_013", "member_014",
                    "member_015", "member_016", "member_017", "member_018",
                    "member_019", "member_020", "member_021"  # 输出
                ]
            }
            
            prepare_response = await client.request_with_response("pve_prepare_battle", prepare_request)
            
            if not prepare_response or not prepare_response.get('response', {}).get('ok', False):
                print("备战失败，无法继续测试")
                return
            
            battle_id = prepare_response.get('response', {}).get('battle_id')
            print(f"备战成功，获取到battle_id: {battle_id}")
            
            # 使用获取到的battle_id发送战斗请求
            battle_request = {
                "battle_id": battle_id
            }
            
            # 发送战斗请求
            battle_response = await client.request_with_response("pve_battle", battle_request)
            
            if battle_response:
                print("\nPVE战斗请求结果:")
                print(f"会话ID: {battle_response.get('session')}")
                
                # 检查响应状态
                resp_data = battle_response.get('response', {})
                ok = resp_data.get('ok', False)
                
                if ok:
                    # 打印战斗结果
                    print("\n战斗成功:")
                    print(f"  战斗ID: {resp_data.get('battle_id')}")
                    print(f"  是否胜利: {'是' if resp_data.get('is_win') else '否'}")
                    print(f"  是否可重试: {'是' if resp_data.get('is_retry') else '否'}")
                else:
                    # 打印错误信息
                    error = resp_data.get('error', {})
                    print(f"战斗失败: {error.get('code')} - {error.get('message')}")
            else:
                print("请求失败或未收到响应")
        except Exception as e:
            print(f"测试过程中出错: {e}")
            import traceback
            traceback.print_exc()
        finally:
            # 关闭连接
            await client.close()
    else:
        print("连接服务器失败")


    """测试PVE玩家战斗重试接口，使用指定的battle_id"""
    client = SprotoClient()
    if await client.connect():
        try:
            print("\n开始测试PVE战斗重试功能...")
            
            # 使用指定的battle_id
            battle_id = 'battle_player_101_boss_001_1744715630'
            print(f"使用指定的battle_id: {battle_id}")
            
            # 构建战斗请求
            battle_request = {
                "battle_id": battle_id
            }
            
            # 发送战斗请求
            battle_response = await client.request_with_response("pve_battle", battle_request)
            
            if battle_response:
                print("\nPVE战斗请求结果:")
                print(f"会话ID: {battle_response.get('session')}")
                
                # 检查响应状态
                resp_data = battle_response.get('response', {})
                ok = resp_data.get('ok', False)
                
                if ok:
                    # 打印战斗结果
                    print("\n战斗成功:")
                    print(f"  战斗ID: {resp_data.get('battle_id')}")
                    print(f"  是否胜利: {'是' if resp_data.get('is_win') else '否'}")
                    print(f"  是否可重试: {'是' if resp_data.get('is_retry') else '否'}")
                    print(f"  战斗时长: {resp_data.get('battle_duration')}秒")
                    print(f"  已重开次数: {resp_data.get('retry_count')}")
                    
                    # 如果可以重试，自动进行重试
                    if resp_data.get('is_retry'):
                        print("\n检测到可以重试，自动进行重试...")
                        retry_response = await client.request_with_response("pve_battle", battle_request)
                        
                        if retry_response:
                            retry_data = retry_response.get('response', {})
                            if retry_data.get('ok', False):
                                print("\n重试战斗结果:")
                                print(f"  战斗ID: {retry_data.get('battle_id')}")
                                print(f"  是否胜利: {'是' if retry_data.get('is_win') else '否'}")
                                print(f"  是否可重试: {'是' if retry_data.get('is_retry') else '否'}")
                                print(f"  战斗时长: {retry_data.get('battle_duration')}秒")
                                print(f"  已重开次数: {retry_data.get('retry_count')}")
                            else:
                                error = retry_data.get('error', {})
                                print(f"重试失败: {error.get('code')} - {error.get('message')}")
                        else:
                            print("重试请求失败或未收到响应")
                else:
                    # 打印错误信息
                    error = resp_data.get('error', {})
                    print(f"战斗失败: {error.get('code')} - {error.get('message')}")
                    
                    # 如果是因为战斗已结束，提供更多信息
                    if error.get('code') == "BATTLE_ENDED":
                        print("提示: 该战斗已结束，无法继续进行。您可以准备一场新的战斗或使用其他battle_id。")
                    # 如果是因为达到重试上限
                    elif error.get('code') == "MAX_RETRY_REACHED":
                        print("提示: 该战斗已达到重试上限，无法继续重试。")
            else:
                print("请求失败或未收到响应")
        except Exception as e:
            print(f"测试过程中出错: {e}")
            import traceback
            traceback.print_exc()
        finally:
            # 关闭连接
            await client.close()
    else:
        print("连接服务器失败")

async def test_get_pve_battle_log():
    """测试拉取战斗日志接口"""
    client = SprotoClient()
    if await client.connect():
        try:
            print("\n开始发送get_pve_battle_log请求...")
            
            # 准备请求参数
            request_data = {
                "battle_id": "battle_player_101_boss_001_1745247092",  # 使用一个已存在的战斗ID
                "page": 1,
                "num": 20
            }
            
            response = await client.request_with_response("get_pve_battle_log", request_data)
            
            if response:
                print("\n获取战斗日志结果:")
                print(f"会话ID: {response.get('session')}")
                
                # 检查响应状态
                resp_data = response.get('response', {})
                ok = resp_data.get('ok', False)
                
                if ok:
                    # 打印日志信息
                    total = resp_data.get('total', 0)
                    page = resp_data.get('page', 1)
                    num = resp_data.get('num', 0)
                    logs = resp_data.get('logs', [])
                    
                    print(f"\n战斗日志获取成功:")
                    print(f"  总日志数: {total}")
                    print(f"  当前页码: {page}")
                    print(f"  本页日志数: {num}")
                    
                    if logs:
                        print("\n日志内容:")
                        for i, log_entry in enumerate(logs, 1):
                            timestamp = log_entry.get('timestamp', '')
                            character = log_entry.get('character_name', '')
                            text = log_entry.get('log_text', '')
                            print(f"  {i}. [{timestamp}] {character}: {text}")
                    else:
                        print("\n没有找到战斗日志")
                        
                    # 如果有多页，尝试获取下一页
                    if total > page * num:
                        print("\n尝试获取下一页...")
                        next_page_request = {
                            "battle_id": request_data["battle_id"],
                            "page": page + 1,
                            "num": num
                        }
                        
                        next_page_response = await client.request_with_response("get_pve_battle_log", next_page_request)
                        
                        if next_page_response and next_page_response.get('response', {}).get('ok', False):
                            next_page_logs = next_page_response.get('response', {}).get('logs', [])
                            next_page_num = len(next_page_logs)
                            
                            print(f"\n第 {page + 1} 页日志获取成功，共 {next_page_num} 条:")
                            
                            if next_page_logs:
                                for i, log_entry in enumerate(next_page_logs, 1):
                                    timestamp = log_entry.get('timestamp', '')
                                    character = log_entry.get('character_name', '')
                                    text = log_entry.get('log_text', '')
                                    print(f"  {i}. [{timestamp}] {character}: {text}")
                            else:
                                print("  没有更多日志")
                        else:
                            print("  获取下一页失败")
                else:
                    # 打印错误信息
                    error = resp_data.get('error', {})
                    print(f"获取战斗日志失败: {error.get('code')} - {error.get('message')}")
            else:
                print("请求失败或未收到响应")
        except Exception as e:
            print(f"测试过程中出错: {e}")
            import traceback
            traceback.print_exc()
        finally:
            # 关闭连接
            await client.close()
    else:
        print("连接服务器失败")

if __name__ == "__main__":
    # 可以选择运行main函数或其他测试函数
    # asyncio.run(main())
    # asyncio.run(test_get_player_member())
    # asyncio.run(test_get_boss_info())
    # asyncio.run(test_pve_prepare_battle())
    # asyncio.run(test_pve_battle())
    asyncio.run(test_get_pve_battle_log())
    
