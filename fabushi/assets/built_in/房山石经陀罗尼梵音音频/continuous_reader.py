#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import time
import random
import threading
from pathlib import Path

class ContinuousFileReader:
    """
    持续循环读取文件的类，模拟播放过程但不实际播放声音
    """
    def __init__(self, directory, file_extension='.mp3', buffer_size=4096, read_speed=1.0):
        """
        初始化连续文件读取器
        
        参数:
            directory: 包含要读取文件的目录
            file_extension: 要读取的文件扩展名
            buffer_size: 每次读取的缓冲区大小
            read_speed: 读取速度倍数 (值越大读取越快)
        """
        self.directory = Path(directory)
        self.file_extension = file_extension
        self.buffer_size = buffer_size
        self.read_speed = read_speed
        self.running = False
        self.files = []
        self.current_file = None
        self.thread = None
        self.scan_files()
        
    def scan_files(self):
        """扫描目录中的所有匹配文件"""
        self.files = list(self.directory.glob(f'**/*{self.file_extension}'))
        print(f"找到 {len(self.files)} 个{self.file_extension}文件")
        
    def read_file(self, file_path):
        """
        读取单个文件内容，模拟播放过程
        """
        try:
            file_size = os.path.getsize(file_path)
            bytes_read = 0
            
            print(f"开始读取: {os.path.basename(file_path)} ({file_size/1024/1024:.2f} MB)")
            start_time = time.time()
            
            with open(file_path, 'rb') as f:
                while self.running and bytes_read < file_size:
                    # 读取数据块但不做任何处理，只是模拟读取过程
                    data = f.read(self.buffer_size)
                    if not data:
                        break
                    
                    bytes_read += len(data)
                    
                    # 计算并显示进度
                    progress = bytes_read / file_size * 100
                    if bytes_read % (self.buffer_size * 100) == 0:  # 每读取100个块显示一次进度
                        print(f"进度: {progress:.1f}% - {os.path.basename(file_path)}")
                    
                    # 控制读取速度，模拟实际播放速度
                    # MP3通常是128-320kbps，我们假设平均是192kbps
                    # 计算这个数据块在正常播放时应该花费的时间
                    time_for_block = len(data) / (192 * 1024 / 8)  # 秒
                    # 根据设定的速度调整实际等待时间
                    time_to_wait = time_for_block / self.read_speed
                    time.sleep(time_to_wait)
            
            end_time = time.time()
            print(f"完成读取: {os.path.basename(file_path)} (耗时: {end_time - start_time:.2f}秒)")
            return True
        except Exception as e:
            print(f"读取文件时出错: {e}")
            return False
    
    def read_loop(self, random_order=True):
        """
        连续循环读取文件的主循环
        
        参数:
            random_order: 是否随机顺序读取文件
        """
        self.running = True
        
        try:
            while self.running and self.files:
                file_list = self.files.copy()
                
                if random_order:
                    random.shuffle(file_list)
                
                for file_path in file_list:
                    if not self.running:
                        break
                    
                    self.current_file = file_path
                    success = self.read_file(file_path)
                    
                    if not success and self.running:
                        print(f"跳过文件: {file_path}")
                    
                    # 文件之间短暂暂停
                    if self.running:
                        time.sleep(0.5)
        
        except KeyboardInterrupt:
            print("读取过程被用户中断")
        finally:
            self.running = False
            print("读取循环已停止")
    
    def start(self, random_order=True):
        """
        在后台线程中启动读取循环
        
        参数:
            random_order: 是否随机顺序读取文件
        """
        if self.running:
            print("读取器已经在运行中")
            return
        
        if not self.files:
            print("没有找到可读取的文件")
            return
        
        self.thread = threading.Thread(target=self.read_loop, args=(random_order,))
        self.thread.daemon = True
        self.thread.start()
        print("后台读取已启动")
    
    def stop(self):
        """停止读取循环"""
        self.running = False
        if self.thread and self.thread.is_alive():
            self.thread.join(timeout=2.0)
        print("读取器已停止")
    
    def set_speed(self, speed):
        """设置读取速度"""
        if speed > 0:
            self.read_speed = speed
            print(f"读取速度已设置为 {speed}x")
        else:
            print("速度必须大于0")
    
    def get_status(self):
        """获取当前状态信息"""
        status = {
            "running": self.running,
            "file_count": len(self.files),
            "current_file": str(self.current_file) if self.current_file else None,
            "read_speed": self.read_speed
        }
        return status


if __name__ == "__main__":
    # 获取脚本所在目录作为默认目录
    default_dir = os.path.dirname(os.path.abspath(__file__))
    
    # 创建读取器实例
    reader = ContinuousFileReader(
        directory=default_dir,
        file_extension='.mp3',
        buffer_size=8192,  # 更大的缓冲区
        read_speed=10.0    # 默认10倍速读取
    )
    
    print("连续文件读取器")
    print("=" * 50)
    print("命令:")
    print("  start - 开始读取")
    print("  stop - 停止读取")
    print("  speed <倍数> - 设置读取速度")
    print("  status - 显示当前状态")
    print("  quit/exit - 退出程序")
    print("=" * 50)
    
    try:
        while True:
            cmd = input("> ").strip().lower()
            
            if cmd == "start":
                reader.start(random_order=True)
            elif cmd == "stop":
                reader.stop()
            elif cmd.startswith("speed "):
                try:
                    speed = float(cmd.split()[1])
                    reader.set_speed(speed)
                except (IndexError, ValueError):
                    print("请输入有效的速度值，例如: speed 5")
            elif cmd == "status":
                status = reader.get_status()
                print(f"状态: {'运行中' if status['running'] else '已停止'}")
                print(f"文件数量: {status['file_count']}")
                print(f"当前文件: {status['current_file'] or '无'}")
                print(f"读取速度: {status['read_speed']}x")
            elif cmd in ["quit", "exit"]:
                reader.stop()
                break
            else:
                print("未知命令")
    
    except KeyboardInterrupt:
        print("\n程序被中断")
    finally:
        if reader.running:
            reader.stop()
        print("程序已退出")