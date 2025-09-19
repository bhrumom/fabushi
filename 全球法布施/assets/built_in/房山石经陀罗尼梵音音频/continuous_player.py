#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import time
import random
import threading
import subprocess
from pathlib import Path

class ContinuousPlayer:
    """
    后台连续播放音频文件的类
    """
    def __init__(self, directory, file_extension='.mp3'):
        """
        初始化连续播放器
        
        参数:
            directory: 包含要播放文件的目录
            file_extension: 要播放的文件扩展名
        """
        self.directory = Path(directory)
        self.file_extension = file_extension
        self.running = False
        self.files = []
        self.current_file = None
        self.thread = None
        self.process = None
        self.scan_files()
        
    def scan_files(self):
        """扫描目录中的所有匹配文件"""
        self.files = list(self.directory.glob(f'**/*{self.file_extension}'))
        print(f"找到 {len(self.files)} 个{self.file_extension}文件")
        
    def play_file(self, file_path):
        """
        播放单个文件
        """
        try:
            print(f"开始播放: {os.path.basename(file_path)}")
            
            # 使用afplay (macOS)播放音频文件
            self.process = subprocess.Popen(['afplay', str(file_path)])
            self.process.wait()
            
            if self.running:
                print(f"完成播放: {os.path.basename(file_path)}")
            return True
        except Exception as e:
            print(f"播放文件时出错: {e}")
            return False
    
    def play_loop(self, random_order=True):
        """
        连续循环播放文件的主循环
        
        参数:
            random_order: 是否随机顺序播放文件
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
                    success = self.play_file(file_path)
                    
                    if not success and self.running:
                        print(f"跳过文件: {file_path}")
                    
                    # 文件之间短暂暂停
                    if self.running:
                        time.sleep(0.5)
        
        except KeyboardInterrupt:
            print("播放过程被用户中断")
        finally:
            self.running = False
            print("播放循环已停止")
    
    def start(self, random_order=True):
        """
        在后台线程中启动播放循环
        
        参数:
            random_order: 是否随机顺序播放文件
        """
        if self.running:
            print("播放器已经在运行中")
            return
        
        if not self.files:
            print("没有找到可播放的文件")
            return
        
        self.thread = threading.Thread(target=self.play_loop, args=(random_order,))
        self.thread.daemon = True
        self.thread.start()
        print("后台播放已启动")
    
    def stop(self):
        """停止播放循环"""
        self.running = False
        if self.process:
            try:
                self.process.terminate()
            except:
                pass
        if self.thread and self.thread.is_alive():
            self.thread.join(timeout=2.0)
        print("播放器已停止")
    
    def get_status(self):
        """获取当前状态信息"""
        status = {
            "running": self.running,
            "file_count": len(self.files),
            "current_file": str(self.current_file) if self.current_file else None
        }
        return status


if __name__ == "__main__":
    # 获取脚本所在目录作为默认目录
    default_dir = os.path.dirname(os.path.abspath(__file__))
    
    # 创建播放器实例
    player = ContinuousPlayer(
        directory=default_dir,
        file_extension='.mp3'
    )
    
    print("连续音频播放器")
    print("=" * 50)
    print("命令:")
    print("  start - 开始播放")
    print("  stop - 停止播放")
    print("  status - 显示当前状态")
    print("  quit/exit - 退出程序")
    print("=" * 50)
    
    try:
        while True:
            cmd = input("> ").strip().lower()
            
            if cmd == "start":
                player.start(random_order=True)
            elif cmd == "stop":
                player.stop()
            elif cmd == "status":
                status = player.get_status()
                print(f"状态: {'运行中' if status['running'] else '已停止'}")
                print(f"文件数量: {status['file_count']}")
                print(f"当前文件: {status['current_file'] or '无'}")
            elif cmd in ["quit", "exit"]:
                player.stop()
                break
            else:
                print("未知命令")
    
    except KeyboardInterrupt:
        print("\n程序被中断")
    finally:
        if player.running:
            player.stop()
        print("程序已退出")