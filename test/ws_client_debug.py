import asyncio
import websockets
import os
from google.protobuf import descriptor_pool
from google.protobuf import message_factory
from google.protobuf.descriptor_pb2 import FileDescriptorSet

# 获取项目根目录的绝对路径
ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

async def test_login():
    uri = "ws://localhost:8081"
    try:
        async with websockets.connect(
            uri,
            ping_interval=20,
            ping_timeout=10,
            close_timeout=5,
            max_size=2**20,  # 1MB max message size
            extra_headers={
                'User-Agent': 'WebSocket Client'
            }
        ) as websocket:
            print(f"Connected to {uri}")
            print(f"Connection details: {websocket.remote_address}")
            print(f"WebSocket state: {websocket.state.name}")
            
            # 创建登录请求
            header = {
                'msg_type': 'game.LoginReq',
                'seq': 1
            }

            login_req = {
                'header': header,  # 添加消息头
                'account': 'test_user',
                'password': '123456'
            }

            try:
                # 直接编码整个登录请求（包含header）
                login_data = encode_message('game.LoginReq', login_req)
                
                # 添加消息长度前缀
                total_length = len(login_data)
                length_prefix = total_length.to_bytes(4, byteorder='little')
                message = length_prefix + login_data
                
                print("\nPreparing to send message:")
                print(f"- Total length prefix: {length_prefix.hex()}")
                print(f"- Total payload length: {total_length}")
                print(f"- Actual message length: {len(login_data)}")
                print(f"- Message hex: {login_data.hex()}")
                print("\nMessage details:")
                print(f"- Login content: {login_req}")
                
                # 发送二进制数据
                await websocket.send(message)
                print("\nSent login request, waiting for response...")
                
                # 设置接收超时
                try:
                    response = await asyncio.wait_for(websocket.recv(), timeout=5.0)
                    print(f"\nReceived response:")
                    print(f"- Raw response length: {len(response)}")
                    print(f"- Raw response hex: {response.hex()}")
                    
                    # 跳过长度前缀（4字节）
                    msg_data = response[4:]
                    # 直接解析 LoginResp
                    resp_data = decode_message('game.LoginResp', msg_data)
                    print("\nLogin response:")
                    if resp_data.get('error_resp') and resp_data['error_resp'].get('code') != "SUCCESS":
                        print("Error occurred:")
                        print(f"- Code: {resp_data['error_resp'].get('code')}")
                        print(f"- Message: {resp_data['error_resp'].get('message')}")
                    else:
                        print("Login successful:")
                        print(f"- User ID: {resp_data.get('userid')}")
                        if resp_data.get('error_resp'):
                            print(f"- Message: {resp_data['error_resp'].get('message')}")
                        else:
                            print(f"Success! User ID: {resp_data.get('userid')}")
                        
                except asyncio.TimeoutError:
                    print("\nTimeout waiting for response after 5 seconds")
                    
            except websockets.exceptions.ConnectionClosed as e:
                print(f"\nConnection closed unexpectedly:")
                print(f"- Code: {e.code}")
                print(f"- Reason: {e.reason}")
                print(f"- Connection state: {websocket.state}")
            except Exception as e:
                print(f"\nError during message exchange: {str(e)}")
                print(f"Exception type: {type(e).__name__}")
                raise
                
    except websockets.exceptions.WebSocketException as e:
        print(f"\nWebSocket connection error:")
        print(f"- Error type: {type(e).__name__}")
        print(f"- Error message: {str(e)}")
    except Exception as e:
        print(f"\nUnexpected error:")
        print(f"- Error type: {type(e).__name__}")
        print(f"- Error message: {str(e)}")
        raise

def load_protos():
    proto_dir = os.path.join(ROOT_DIR, 'proto')
    print(f"Loading protos from: {proto_dir}")
    
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
        print("Protoc warnings/errors:", result.stderr)

    # 加载编译后的proto文件
    with open('protos.pb', 'rb') as f:
        file_set = FileDescriptorSet()
        file_set.ParseFromString(f.read())
        pool = descriptor_pool.Default()
        for file_proto in file_set.file:
            pool.Add(file_proto)
    return pool

def encode_message(msg_type, data):
    try:
        pool = load_protos()
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
                # 使用 CopyFrom 而不是直接赋值
                getattr(message, key).CopyFrom(sub_message)
            else:
                if hasattr(message, key):
                    setattr(message, key, value)
                
        return message.SerializeToString()
    except Exception as e:
        print(f"Error encoding {msg_type}: {e}")
        print(f"Data: {data}")
        raise

def decode_message(msg_type, data):
    try:
        pool = load_protos()
        desc = pool.FindMessageTypeByName(msg_type)
        if not desc:
            raise ValueError(f"Message type {msg_type} not found in proto definitions")
            
        message_class = message_factory.GetMessageClass(desc)
        message = message_class()
        
        try:
            message.ParseFromString(data)
        except Exception as e:
            print(f"Failed to parse message data: {e}")
            print(f"Message type: {msg_type}")
            print(f"Data length: {len(data)}")
            print(f"Data hex: {data.hex()}")
            raise
            
        # 递归处理嵌套消息
        result = {}
        for field in message.DESCRIPTOR.fields:
            value = getattr(message, field.name)
            if field.type == field.TYPE_MESSAGE:
                # 如果是嵌套消息，递归转换为字典
                result[field.name] = {
                    sub_field.name: getattr(value, sub_field.name)
                    for sub_field in value.DESCRIPTOR.fields
                }
            else:
                result[field.name] = value
        return result
            
    except Exception as e:
        print(f"Error decoding {msg_type}: {e}")
        print(f"Raw data length: {len(data)}")
        print(f"Raw data (hex): {data.hex()}")
        raise

if __name__ == "__main__":
    print(f"Project root directory: {ROOT_DIR}")
    asyncio.get_event_loop().run_until_complete(test_login())