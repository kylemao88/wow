import asyncio
import websockets
import os
import sys
from google.protobuf import descriptor_pool
from google.protobuf import message_factory
from google.protobuf.descriptor_pb2 import FileDescriptorSet

# 获取项目根目录
ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

class ProtoClient:
    def __init__(self, uri="ws://localhost:8081"):
        self.uri = uri
        self.proto_pool = None
        
    async def connect(self):
        """连接到WebSocket服务器"""
        self.ws = await websockets.connect(
            self.uri,
            ping_interval=20,
            ping_timeout=10,
            close_timeout=5,
            max_size=2**20
        )
        print(f"已连接到 {self.uri}")
        return self.ws
        
    def load_protos(self):
        """加载proto文件"""
        if self.proto_pool:
            return self.proto_pool
            
        proto_dir = os.path.join(ROOT_DIR, 'proto')
        print(f"从 {proto_dir} 加载proto文件")
        
        # 编译proto文件
        import subprocess
        result = subprocess.run([
            'protoc',
            f'--proto_path={proto_dir}',
            '--descriptor_set_out=protos.pb',
            os.path.join(proto_dir, 'common.proto'),
            os.path.join(proto_dir, 'game.proto')
        ], capture_output=True, text=True)
        
        if result.stderr:
            print(f"Protoc警告/错误: {result.stderr}")

        # 加载编译后的proto文件
        with open('protos.pb', 'rb') as f:
            file_set = FileDescriptorSet()
            file_set.ParseFromString(f.read())
            self.proto_pool = descriptor_pool.Default()
            for file_proto in file_set.file:
                self.proto_pool.Add(file_proto)
        return self.proto_pool
        
    def encode_message(self, msg_type, data):
        """将消息编码为二进制格式"""
        pool = self.load_protos()
        desc = pool.FindMessageTypeByName(msg_type)
        message_class = message_factory.GetMessageClass(desc)
        message = message_class()
        
        for key, value in data.items():
            if isinstance(value, dict):
                # 处理嵌套消息
                field_desc = message.DESCRIPTOR.fields_by_name[key]
                sub_message = message_factory.GetMessageClass(field_desc.message_type)()
                for sub_key, sub_value in value.items():
                    if hasattr(sub_message, sub_key):
                        setattr(sub_message, sub_key, sub_value)
                getattr(message, key).CopyFrom(sub_message)
            else:
                if hasattr(message, key):
                    setattr(message, key, value)
                    
        return message.SerializeToString()
        
    def decode_message(self, msg_type, data):
        """将二进制数据解码为Python字典"""
        pool = self.load_protos()
        desc = pool.FindMessageTypeByName(msg_type)
        message_class = message_factory.GetMessageClass(desc)
        message = message_class()
        message.ParseFromString(data)
        
        # 转换为字典
        result = {}
        for field in message.DESCRIPTOR.fields:
            value = getattr(message, field.name)
            if field.type == field.TYPE_MESSAGE:
                result[field.name] = {
                    sub_field.name: getattr(value, sub_field.name)
                    for sub_field in value.DESCRIPTOR.fields
                }
            else:
                result[field.name] = value
        return result
        
    async def send_request(self, msg_type, data):
        """发送请求并等待响应"""
        # 编码消息
        binary_data = self.encode_message(msg_type, data)
        
        # 添加长度前缀
        length_prefix = len(binary_data).to_bytes(4, byteorder='little')
        message = length_prefix + binary_data
        
        # 发送消息
        await self.ws.send(message)
        print(f"已发送 {msg_type} 请求")
        
        # 接收响应
        try:
            response = await asyncio.wait_for(self.ws.recv(), timeout=5.0)
            # 跳过长度前缀
            msg_data = response[4:]
            # 假设响应类型是请求类型的响应版本
            resp_type = msg_type.replace('Req', 'Resp')
            return self.decode_message(resp_type, msg_data)
        except asyncio.TimeoutError:
            print("等待响应超时")
            return None
            
    async def close(self):
        """关闭连接"""
        if hasattr(self, 'ws'):
            await self.ws.close()
            print("连接已关闭")

async def test_login():
    """测试登录功能"""
    client = ProtoClient()
    try:
        await client.connect()
        
        # 创建登录请求
        login_req = {
            'header': {
                'msg_type': 'game.LoginReq',
                'seq': 1
            },
            'account': 'test_user',
            'password': 'Wow@123456'
        }
        
        # 发送登录请求
        resp = await client.send_request('game.LoginReq', login_req)
        
        # 处理响应
        if resp:
            print("\n登录响应:")
            if resp.get('error_resp') and resp['error_resp'].get('code') != "SUCCESS":
                print(f"错误: {resp['error_resp'].get('code')} - {resp['error_resp'].get('message')}")
            else:
                print(f"登录成功! 用户ID: {resp.get('userid')}")
                return resp.get('userid')  # 返回用户ID供后续使用
                
    except Exception as e:
        print(f"发生错误: {e}")
    finally:
        await client.close()


async def test_get_player_info():
    """测试获取玩家信息功能"""
    client = ProtoClient()
    try:
        await client.connect()
        
        # 先登录获取用户ID
        userid = await test_login()
        if not userid:
            print("登录失败，无法获取玩家信息")
            return
            
        # 创建获取玩家信息请求
        get_player_info_req = {
            'header': {
                'msg_type': 'game.GetPlayerInfoReq',
                'seq': 2
            },
            'userid': userid
        }
        
        # 发送获取玩家信息请求
        resp = await client.send_request('game.GetPlayerInfoReq', get_player_info_req)
        
        # 处理响应
        if resp:
            print("\n获取玩家信息响应:")
            if resp.get('error_resp') and resp['error_resp'].get('code') != "SUCCESS":
                print(f"错误: {resp['error_resp'].get('code')} - {resp['error_resp'].get('message')}")
            else:
                player = resp.get('player', {})
                print("玩家信息:")
                print(f"- 用户ID: {player.get('userid')}")
                print(f"- 昵称: {player.get('nickname')}")
                print(f"- 等级: {player.get('level')}")
                print(f"- 经验值: {player.get('exp')}")
                print(f"- VIP等级: {player.get('vip_level')}")
                
    except Exception as e:
        print(f"发生错误: {e}")
    finally:
        await client.close()

if __name__ == "__main__":
    asyncio.run(test_login())
    #asyncio.run(test_get_player_info())
    