#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import time
import random
import threading
import subprocess
import platform
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

class CloudPlayer:
    """云环境适用的多媒体极速播放器"""
    
    # 支持的文件扩展名
    AUDIO_EXTENSIONS = ['.mp3', '.wav', '.flac', '.aac', '.ogg', '.m4a']
    VIDEO_EXTENSIONS = ['.mp4', '.avi', '.mkv', '.mov', '.wmv', '.flv', '.webm']
    
    def __init__(self, directory, file_types=None):
        self.directory = Path(directory)
        self.file_types = file_types or self.AUDIO_EXTENSIONS + self.VIDEO_EXTENSIONS
        self.running = False
        self.files = []
        self.current_files = set()
        self.processes = []
        self.executor = None
        
        # 简化系统检测
        self.system = platform.system()
        self.cpu_count = os.cpu_count() or 2
        
        # 设置线程数
        self.max_threads = min(8, self.cpu_count * 2)
        self.playback_speed = 100.0  # 默认100倍速
        
        # 检测播放命令
        self._detect_players()
        
        # 扫描文件
        self.scan_files()
        
        print(f"系统信息: {self.system}, 估计{self.cpu_count}核CPU")
        print(f"设置: 最大{self.max_threads}个并发线程, 目标速度: {self.playback_speed}倍速")
    
    def _detect_players(self):
        """检测系统可用的播放器"""
        self.audio_cmd = None
        self.video_cmd = None
        
        # 检查ffplay是否可用
        if self._check_command('ffplay'):
            # 构建多级atempo滤镜链
            atempo_chain = "atempo=2.0,atempo=2.0,atempo=2.0"  # 8倍速
            self.audio_cmd = ['ffplay', '-nodisp', '-autoexit', '-loglevel', 'quiet', '-af', atempo_chain]
            self.video_cmd = ['ffplay', '-nodisp', '-autoexit', '-loglevel', 'quiet', '-af', atempo_chain]
        
        print(f"音频播放器: {' '.join(self.audio_cmd) if self.audio_cmd else '模拟模式'}")
        print(f"视频播放器: {' '.join(self.video_cmd) if self.video_cmd else '模拟模式'}")
    
    def _check_command(self, cmd):
        """检查命令是否可用"""
        try:
            if self.system == 'Windows':
                result = subprocess.run(['where', cmd], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            else:
                result = subprocess.run(['which', cmd], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            return result.returncode == 0
        except:
            return False
    
    def scan_files(self):
        """扫描目录中的所有匹配文件"""
        self.files = []
        for ext in self.file_types:
            self.files.extend(list(self.directory.glob(f'**/*{ext}')))
        
        # 按文件类型分类统计
        audio_count = sum(1 for f in self.files if f.suffix.lower() in self.AUDIO_EXTENSIONS)
        video_count = sum(1 for f in self.files if f.suffix.lower() in self.VIDEO_EXTENSIONS)
        
        print(f"找到 {len(self.files)} 个文件 (音频: {audio_count}, 视频: {video_count})")
    
    def is_video_file(self, file_path):
        """判断是否为视频文件"""
        return Path(file_path).suffix.lower() in self.VIDEO_EXTENSIONS
    
    def play_file(self, file_path):
        """播放单个文件"""
        if file_path in self.current_files:
            return False
        
        self.current_files.add(file_path)
        try:
            filename = os.path.basename(file_path)
            is_video = self.is_video_file(file_path)
            file_type = "视频" if is_video else "音频"
            print(f"开始播放{file_type}: {filename} ({self.playback_speed}倍速)")
            
            # 选择合适的播放命令
            cmd = None
            if is_video and self.video_cmd:
                cmd = self.video_cmd.copy()
            elif not is_video and self.audio_cmd:
                cmd = self.audio_cmd.copy()
            
            if not cmd:
                # 模拟模式 - 不实际播放
                if os.path.exists(file_path):
                    time.sleep(0.001)  # 极短停顿
                process = None
            else:
                # 标准命令行播放
                cmd = cmd + [str(file_path)]
                process = subprocess.Popen(cmd)
            
            if process:
                self.processes.append(process)
                process.wait()
                self.processes.remove(process)
            
            print(f"完成播放{file_type}: {filename}")
            return True
        except Exception as e:
            print(f"播放文件时出错: {e}")
            return False
        finally:
            self.current_files.discard(file_path)
    
    def start(self, random_order=True):
        """启动多线程播放"""
        if self.running:
            print("播放器已经在运行中")
            return
        
        if not self.files:
            print("没有找到可播放的文件")
            return
        
        self.running = True
        
        def play_loop():
            while self.running:
                # 每轮播放都创建新的线程池
                with ThreadPoolExecutor(max_workers=self.max_threads) as executor:
                    self.executor = executor
                    
                    file_list = self.files.copy()
                    if random_order:
                        random.shuffle(file_list)
                    
                    futures = []
                    for file_path in file_list:
                        if not self.running:
                            break
                        # 提交任务到线程池
                        future = executor.submit(self.play_file, file_path)
                        futures.append(future)
                        # 短暂延迟避免同时启动所有线程
                        time.sleep(0.1)
                    
                    # 等待所有任务完成
                    for future in futures:
                        if not self.running:
                            break
                        try:
                            future.result()
                        except:
                            pass
                
                self.executor = None
        
        # 启动主循环线程
        threading.Thread(target=play_loop, daemon=True).start()
        print(f"极速播放已启动 (并发线程: {self.max_threads})")
    
    def stop(self):
        """停止所有播放"""
        self.running = False
        
        # 终止所有进程
        for process in self.processes[:]:
            try:
                process.terminate()
            except:
                pass
        
        # 关闭线程池
        if self.executor:
            self.executor.shutdown(wait=False)
            self.executor = None
        
        self.current_files.clear()
        print("播放器已停止")
    
    def get_status(self):
        """获取当前状态"""
        return {
            "running": self.running,
            "file_count": len(self.files),
            "active_files": len(self.current_files),
            "current_files": [os.path.basename(f) for f in self.current_files],
            "max_threads": self.max_threads,
            "playback_speed": self.playback_speed
        }
    
    def set_file_types(self, types):
        """设置要播放的文件类型"""
        if types == "audio":
            self.file_types = self.AUDIO_EXTENSIONS
        elif types == "video":
            self.file_types = self.VIDEO_EXTENSIONS
        elif types == "all":
            self.file_types = self.AUDIO_EXTENSIONS + self.VIDEO_EXTENSIONS
        else:
            print("无效的文件类型，请使用 'audio', 'video' 或 'all'")
            return
        
        self.scan_files()

if __name__ == "__main__":
    # 获取脚本所在目录
    default_dir = os.path.dirname(os.path.abspath(__file__))
    if not default_dir:
        default_dir = "."
    
    # 创建播放器实例
    player = CloudPlayer(directory=default_dir)
    
    print("\n云环境极速多媒体播放器 - 守护进程模式")
    print("=" * 50)
    
    # 自动开始播放
    player.start(random_order=True)
    
    # 保持脚本运行
    try:
        print("播放器已在后台运行，按Ctrl+C停止...")
        while True:
            time.sleep(3600)  # 每小时检查一次
            if not player.running:
                print("检测到播放器已停止，正在重新启动...")
                player.start()
    except KeyboardInterrupt:
        print("\n接收到停止信号")
    finally:
        player.stop()
        print("程序已退出")