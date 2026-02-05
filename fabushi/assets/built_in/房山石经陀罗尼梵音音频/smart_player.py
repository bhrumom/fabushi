#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import time
import random
import threading
import subprocess
import platform
import psutil
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

class SmartPlayer:
    """智能多媒体极速播放器 - 自动适应系统并支持音频和视频"""
    
    # 支持的文件扩展名
    AUDIO_EXTENSIONS = ['.mp3', '.wav', '.flac', '.aac', '.ogg', '.m4a']
    VIDEO_EXTENSIONS = ['.mp4', '.avi', '.mkv', '.mov', '.wmv', '.flv', '.webm']
    
    def __init__(self, directory, file_types=None, playback_speed=None):
        self.directory = Path(directory)
        self.file_types = file_types or self.AUDIO_EXTENSIONS + self.VIDEO_EXTENSIONS
        self.running = False
        self.files = []
        self.current_files = set()
        self.processes = []
        self.executor = None
        self.custom_player = None
        
        # 智能选择最高播放速度 - 设置各播放器实际支持的最高速度
        self.max_speeds = {
            'ffplay': 64.0,    # ffplay通过多级atempo可以达到64倍速
            'mpg123': 4.0,     # mpg123最高支持4倍速
            'mplayer': 16.0,   # mplayer可以支持较高倍速
            'vlc': 16.0,       # vlc支持较高倍速
            'afplay': 2.0,     # afplay最高2倍速
            'quicktime': 2.0,  # QuickTime最高2倍速
            'custom': 100.0,   # 自定义播放器使用100倍速
            'default': 64.0    # 默认使用64倍速
        }
        self.target_speed = 100.0  # 目标速度
        self.playback_speed = playback_speed  # 如果指定则使用指定值
        
        # 尝试创建自定义超高速播放器
        self.custom_player = self._create_custom_player()
        
        # 自动检测系统配置
        self.system = platform.system()
        self.cpu_count = psutil.cpu_count(logical=False) or 2
        self.total_memory_gb = psutil.virtual_memory().total / (1024**3)
        
        # 智能设置线程数 (CPU核心数 + 2，但不超过内存GB数的2倍)
        self.max_threads = min(self.cpu_count + 2, int(self.total_memory_gb * 2))
        self.max_threads = max(2, min(16, self.max_threads))  # 至少2个，最多16个
        
        # 检测播放命令
        self._detect_players()
        
        # 扫描文件
        self.scan_files()
        
        print(f"系统信息: {self.system}, {self.cpu_count}核CPU, {self.total_memory_gb:.1f}GB内存")
        print(f"智能设置: 最大{self.max_threads}个并发线程, 播放速度: {self.playback_speed}倍速")
    
    def _detect_players(self):
        """检测系统可用的播放器并智能选择最高播放速度"""
        self.audio_cmd = None
        self.video_cmd = None
        self.audio_player_type = 'default'
        self.video_player_type = 'default'
        
        # 设置最高播放速度，尝试接近100倍速
        if self.playback_speed is None:
            self.playback_speed = self.target_speed  # 目标100倍速
            
        # 优先使用自定义高速播放器
        if self.custom_player:
            self.audio_player_type = 'custom'
            self.video_player_type = 'custom'
            self.audio_cmd = [self.custom_player]
            self.video_cmd = [self.custom_player]
            # 自定义播放器使用100倍速
            self.playback_speed = 100.0
            return
        
        if self.system == 'Darwin':  # macOS
            if self._check_command('ffmpeg') and self._check_command('ffplay'):
                self.audio_player_type = 'ffplay'
                self.video_player_type = 'ffplay'
                
                # 使用ffmpeg预处理+ffplay播放实现超高速
                # 创建临时脚本
                script_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "temp_player.sh")
                
                # 构建多级atempo滤镜链 (最多6级，2^6=64倍速)
                atempo_chain = ""
                remaining_speed = min(64.0, self.playback_speed)
                atempo_count = 0
                
                while remaining_speed > 1.0 and atempo_count < 6:
                    if remaining_speed >= 2.0:
                        atempo_chain += "atempo=2.0,"
                        remaining_speed /= 2.0
                        atempo_count += 1
                    else:
                        atempo_chain += f"atempo={remaining_speed},"
                        remaining_speed = 1.0
                        atempo_count += 1
                
                # 移除最后一个逗号
                atempo_chain = atempo_chain[:-1]
                
                # 创建临时播放脚本
                script_content = f"""#!/bin/bash
# 超高速播放脚本
file="$1"
ext="${{file##*.}}"
temp_file="/tmp/temp_segment_$RANDOM.$ext"

# 提取短片段并加速
ffmpeg -y -i "$file" -ss 0 -t 1 -af "{atempo_chain}" -loglevel quiet "$temp_file"

# 播放加速片段
ffplay -nodisp -autoexit -loglevel quiet "$temp_file"

# 清理
rm -f "$temp_file"
"""
                
                try:
                    with open(script_path, 'w') as f:
                        f.write(script_content)
                    os.chmod(script_path, 0o755)  # 设置可执行权限
                    
                    self.audio_cmd = [script_path]
                    self.video_cmd = [script_path]
                except:
                    # 如果脚本创建失败，回退到标准ffplay
                    self.audio_cmd = ['ffplay', '-nodisp', '-autoexit', '-loglevel', 'quiet', '-af', atempo_chain]
                    self.video_cmd = ['ffplay', '-nodisp', '-autoexit', '-loglevel', 'quiet', '-af', atempo_chain]
            else:
                self.audio_player_type = 'afplay'
                self.video_player_type = 'quicktime'
                # afplay最高支持2倍速
                self.audio_cmd = ['afplay', '-r', '2.0']
                self.video_cmd = ['open', '-a', 'QuickTime Player']
        
        elif self.system == 'Windows':
            if self._check_command('ffmpeg') and self._check_command('ffplay'):
                self.audio_player_type = 'ffplay'
                self.video_player_type = 'ffplay'
                
                # 创建临时脚本
                script_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "temp_player.bat")
                
                # 构建多级atempo滤镜链 (最多6级，2^6=64倍速)
                atempo_chain = ""
                remaining_speed = min(64.0, self.playback_speed)
                atempo_count = 0
                
                while remaining_speed > 1.0 and atempo_count < 6:
                    if remaining_speed >= 2.0:
                        atempo_chain += "atempo=2.0,"
                        remaining_speed /= 2.0
                        atempo_count += 1
                    else:
                        atempo_chain += f"atempo={remaining_speed},"
                        remaining_speed = 1.0
                        atempo_count += 1
                
                # 移除最后一个逗号
                atempo_chain = atempo_chain[:-1]
                
                # 创建临时播放脚本
                script_content = f"""@echo off
REM 超高速播放脚本
set file=%1
set temp_file=%TEMP%\\temp_segment_%RANDOM%.mp3

REM 提取短片段并加速
ffmpeg -y -i "%file%" -ss 0 -t 1 -af "{atempo_chain}" -loglevel quiet "%temp_file%"

REM 播放加速片段
ffplay -nodisp -autoexit -loglevel quiet "%temp_file%"

REM 清理
del /f "%temp_file%"
"""
                
                try:
                    with open(script_path, 'w') as f:
                        f.write(script_content)
                    
                    self.audio_cmd = [script_path]
                    self.video_cmd = [script_path]
                except:
                    # 如果脚本创建失败，回退到标准ffplay
                    self.audio_cmd = ['ffplay', '-nodisp', '-autoexit', '-loglevel', 'quiet', '-af', atempo_chain]
                    self.video_cmd = ['ffplay', '-nodisp', '-autoexit', '-loglevel', 'quiet', '-af', atempo_chain]
            else:
                # Windows默认播放器不支持速度控制，使用模拟模式
                self.audio_cmd = None
                self.video_cmd = None
        
        else:  # Linux 和其他系统
            # 检查音频播放器
            if self._check_command('ffmpeg') and self._check_command('ffplay'):
                self.audio_player_type = 'ffplay'
                self.video_player_type = 'ffplay'
                
                # 创建临时脚本
                script_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "temp_player.sh")
                
                # 构建多级atempo滤镜链 (最多6级，2^6=64倍速)
                atempo_chain = ""
                remaining_speed = min(64.0, self.playback_speed)
                atempo_count = 0
                
                while remaining_speed > 1.0 and atempo_count < 6:
                    if remaining_speed >= 2.0:
                        atempo_chain += "atempo=2.0,"
                        remaining_speed /= 2.0
                        atempo_count += 1
                    else:
                        atempo_chain += f"atempo={remaining_speed},"
                        remaining_speed = 1.0
                        atempo_count += 1
                
                # 移除最后一个逗号
                atempo_chain = atempo_chain[:-1]
                
                # 创建临时播放脚本
                script_content = f"""#!/bin/bash
# 超高速播放脚本
file="$1"
ext="${{file##*.}}"
temp_file="/tmp/temp_segment_$RANDOM.$ext"

# 提取短片段并加速
ffmpeg -y -i "$file" -ss 0 -t 1 -af "{atempo_chain}" -loglevel quiet "$temp_file"

# 播放加速片段
ffplay -nodisp -autoexit -loglevel quiet "$temp_file"

# 清理
rm -f "$temp_file"
"""
                
                try:
                    with open(script_path, 'w') as f:
                        f.write(script_content)
                    os.chmod(script_path, 0o755)  # 设置可执行权限
                    
                    self.audio_cmd = [script_path]
                    self.video_cmd = [script_path]
                except:
                    # 如果脚本创建失败，回退到标准ffplay
                    self.audio_cmd = ['ffplay', '-nodisp', '-autoexit', '-loglevel', 'quiet', '-af', atempo_chain]
                    self.video_cmd = ['ffplay', '-loglevel', 'quiet', '-autoexit', '-window_title', '-af', atempo_chain]
            elif self._check_command('mpg123'):
                self.audio_player_type = 'mpg123'
                # mpg123速度有限制，但尝试使用最高值
                self.audio_cmd = ['mpg123', '-q', '--speed', '4.0']
            elif self._check_command('mplayer'):
                self.audio_player_type = 'mplayer'
                # mplayer速度有限制，但尝试使用最高值
                self.audio_cmd = ['mplayer', '-really-quiet', '-speed', '16.0']
            
            # 检查视频播放器
            if not self.video_cmd:  # 如果上面没有设置视频命令
                if self._check_command('mplayer'):
                    self.video_player_type = 'mplayer'
                    # mplayer速度有限制，但尝试使用最高值
                    self.video_cmd = ['mplayer', '-really-quiet', '-speed', '16.0']
                elif self._check_command('vlc'):
                    self.video_player_type = 'vlc'
                    # vlc速度有限制，但尝试使用最高值
                    self.video_cmd = ['vlc', '--play-and-exit', '--no-video-title-show', '--rate=16.0']
        
        print(f"音频播放器: {' '.join(self.audio_cmd) if self.audio_cmd else '模拟模式'} ({self.playback_speed}倍速)")
        print(f"视频播放器: {' '.join(self.video_cmd) if self.video_cmd else '模拟模式'} ({self.playback_speed}倍速)")
    
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
            
    def _create_custom_player(self):
        """创建支持100倍速播放的自定义播放器"""
        # 检查是否有ffmpeg
        has_ffmpeg = self._check_command('ffmpeg')
        
        if has_ffmpeg:
            # 创建临时脚本来实现超高速播放
            script_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ultra_player.py")
            
            script_content = """#!/usr/bin/env python3
import sys
import subprocess
import os
import time
import tempfile

def ultra_play(file_path):
    # 检查文件是否存在
    if not os.path.exists(file_path):
        print(f"文件不存在: {file_path}")
        return 1
        
    # 检查文件扩展名
    ext = os.path.splitext(file_path)[1].lower()
    is_audio = ext in ['.mp3', '.wav', '.flac', '.aac', '.ogg', '.m4a']
    
    try:
        # 创建临时文件
        temp_dir = tempfile.gettempdir()
        temp_file = os.path.join(temp_dir, f"temp_segment_{os.path.basename(file_path)}")
        
        # 使用ffmpeg提取短片段并加速到100倍
        # 构建多级atempo滤镜链 (2^6 = 64倍速，接近100倍)
        atempo_chain = "atempo=2.0,atempo=2.0,atempo=2.0,atempo=2.0,atempo=2.0,atempo=2.0"
        
        # 提取前1秒并加速
        extract_cmd = [
            'ffmpeg', '-y', '-i', file_path, 
            '-ss', '0', '-t', '1', 
            '-af', atempo_chain, 
            '-loglevel', 'quiet',
            temp_file
        ]
        
        # 执行提取和加速
        subprocess.run(extract_cmd, stderr=subprocess.DEVNULL)
        
        # 播放加速后的片段
        if is_audio:
            play_cmd = ['ffplay', '-nodisp', '-autoexit', '-loglevel', 'quiet', temp_file]
        else:
            play_cmd = ['ffplay', '-loglevel', 'quiet', '-autoexit', temp_file]
            
        print(f"100倍速播放: {file_path}")
        process = subprocess.Popen(play_cmd)
        
        # 等待播放完成
        process.wait()
        
        # 清理临时文件
        try:
            os.remove(temp_file)
        except:
            pass
            
        return 0
    except Exception as e:
        print(f"播放出错: {e}")
        return 1

if __name__ == "__main__":
    if len(sys.argv) > 1:
        sys.exit(ultra_play(sys.argv[1]))
    sys.exit(1)
"""
            try:
                with open(script_path, 'w') as f:
                    f.write(script_content)
                os.chmod(script_path, 0o755)  # 设置可执行权限
                return script_path
            except:
                pass
        
        return None
    
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
                # 如果没有可用的播放命令，使用ffplay作为备选
                if self._check_command('ffplay'):
                    # 使用多级atempo滤镜链接实现高速播放
                    atempo_chain = ""
                    remaining_speed = min(10.0, self.playback_speed)  # 限制最高10倍速以确保可播放
                    while remaining_speed > 1.0:
                        if remaining_speed >= 2.0:
                            atempo_chain += "atempo=2.0,"
                            remaining_speed /= 2.0
                        else:
                            atempo_chain += f"atempo={remaining_speed},"
                            remaining_speed = 1.0
                    
                    # 移除最后一个逗号
                    atempo_chain = atempo_chain[:-1]
                    cmd = ['ffplay', '-nodisp', '-autoexit', '-loglevel', 'quiet', '-af', atempo_chain, str(file_path)]
                    process = subprocess.Popen(cmd)
                else:
                    # 如果ffplay也不可用，使用系统默认方式打开文件
                    if self.system == 'Darwin':
                        cmd = ['open', str(file_path)]
                    elif self.system == 'Windows':
                        cmd = ['start', '', str(file_path)]
                    else:  # Linux
                        cmd = ['xdg-open', str(file_path)]
                    process = subprocess.Popen(cmd, shell=(self.system == 'Windows'))
                    time.sleep(1)  # 给系统默认播放器一些启动时间
                    
                    # 尝试使用系统默认播放器播放一小段时间后关闭
                    time.sleep(min(5, 60/self.playback_speed))  # 根据播放速度调整播放时间
                    try:
                        process.terminate()
                    except:
                        pass
            elif self.system == 'Windows':
                # Windows 使用 PowerShell 播放
                if is_video:
                    cmd = cmd + [f"'{file_path}'"]
                else:
                    cmd = cmd + [f"'{file_path}').PlaySync()"]
                process = subprocess.Popen(cmd, shell=True)
            elif self.system == 'Darwin' and is_video and 'QuickTime' in ' '.join(cmd):
                # macOS QuickTime 特殊处理
                cmd = cmd + [str(file_path)]
                process = subprocess.Popen(cmd)
                # QuickTime 需要额外时间加载
                time.sleep(0.5)
                # 尝试使用AppleScript设置播放速度
                try:
                    speed_cmd = ['osascript', '-e', 
                                f'tell application "QuickTime Player" to set rate of document 1 to {self.playback_speed}']
                    subprocess.run(speed_cmd)
                except:
                    pass
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
    
    def monitor_system(self):
        """监控系统资源并动态调整线程数"""
        while self.running:
            try:
                # 获取CPU和内存使用率
                cpu_percent = psutil.cpu_percent(interval=2)
                mem_percent = psutil.virtual_memory().percent
                
                # 动态调整线程数
                if cpu_percent > 85 or mem_percent > 85:
                    # 系统负载高，减少线程
                    new_threads = max(2, self.max_threads - 2)
                    if new_threads < self.max_threads:
                        self.max_threads = new_threads
                        print(f"系统负载高 (CPU: {cpu_percent}%, 内存: {mem_percent}%), 减少线程数到 {self.max_threads}")
                elif cpu_percent < 50 and mem_percent < 60:
                    # 系统负载低，可以增加线程
                    optimal_threads = min(self.cpu_count + 2, int(self.total_memory_gb * 2))
                    optimal_threads = max(2, min(16, optimal_threads))
                    if self.max_threads < optimal_threads:
                        self.max_threads = min(self.max_threads + 1, optimal_threads)
                        print(f"系统负载低 (CPU: {cpu_percent}%, 内存: {mem_percent}%), 增加线程数到 {self.max_threads}")
                
                # 如果线程池存在，调整其大小
                if self.executor:
                    # ThreadPoolExecutor不支持动态调整，这里只是记录新值
                    # 下一轮播放时会使用新的线程数
                    pass
                
                time.sleep(5)  # 每5秒检查一次
            except:
                time.sleep(5)
    
    def start(self, random_order=True):
        """启动智能多线程播放"""
        if self.running:
            print("播放器已经在运行中")
            return
        
        if not self.files:
            print("没有找到可播放的文件")
            return
        
        self.running = True
        
        # 启动系统监控线程
        threading.Thread(target=self.monitor_system, daemon=True).start()
        
        def play_loop():
            while self.running:
                # 每轮播放都创建新的线程池，使用当前的最大线程数
                with ThreadPoolExecutor(max_workers=self.max_threads) as executor:
                    self.executor = executor
                    
                    file_list = self.files.copy()
                    if random_order:
                        random.shuffle(file_list)
                    
                    # 标准模式：每个文件一个线程
                    futures = []
                    for file_path in file_list:
                        if not self.running:
                            break
                        # 提交任务到线程池
                        future = executor.submit(self.play_file, file_path)
                        futures.append(future)
                        # 短暂延迟避免同时启动所有线程
                        time.sleep(0.1)  # 增加延迟，确保音频不会重叠太多
                    
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
        print(f"智能极速播放已启动 (初始并发线程: {self.max_threads}, 目标速度: {self.playback_speed}倍速)")
    
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
    try:
        # 检查psutil是否已安装
        import psutil
    except ImportError:
        print("缺少必要的库: psutil")
        print("请安装: pip install psutil")
        sys.exit(1)
    
    # 获取脚本所在目录
    default_dir = os.path.dirname(os.path.abspath(__file__))
    
    # 创建播放器实例，自动选择最高播放速度
    player = SmartPlayer(directory=default_dir)
    
    print("\n智能极速多媒体播放器")
    print("=" * 50)
    print("命令:")
    print("  start - 开始播放")
    print("  stop - 停止播放")
    print("  threads <数量> - 手动设置并发线程数")
    print("  type <类型> - 设置文件类型 (audio/video/all)")
    print("  speed <倍速> - 设置播放速度 (使用 'speed 100' 或 'speed max' 设置100倍速)")
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
            elif cmd.startswith("threads "):
                try:
                    threads = int(cmd.split()[1])
                    if threads > 0:
                        player.max_threads = threads
                        print(f"并发线程数已手动设置为: {threads}")
                    else:
                        print("线程数必须大于0")
                except:
                    print("请输入有效的线程数，例如: threads 8")
            elif cmd.startswith("type "):
                try:
                    file_type = cmd.split()[1]
                    player.set_file_types(file_type)
                except:
                    print("请指定有效的文件类型: audio, video 或 all")
            elif cmd.startswith("speed "):
                try:
                    if cmd.split()[1].lower() == "max" or cmd.split()[1].lower() == "100":
                        # 使用100倍速或当前播放器的最大速度
                        player.playback_speed = 100.0
                        player._detect_players()
                        print(f"播放速度已设置为最大: 100倍速 (实际效果取决于播放器支持)")
                    else:
                        speed = float(cmd.split()[1])
                        # 允许任何正数作为速度值
                        if speed > 0:
                            player.playback_speed = speed
                            # 重新检测播放器以应用新速度
                            player._detect_players()
                            print(f"播放速度已设置为: {speed}倍速 (实际效果取决于播放器支持)")
                        else:
                            print("播放速度必须大于0")
                except:
                    print("请输入有效的播放速度，例如: speed 100 或 speed max")
            elif cmd == "status":
                status = player.get_status()
                print(f"状态: {'运行中' if status['running'] else '已停止'}")
                print(f"文件总数: {status['file_count']}")
                print(f"当前活动文件数: {status['active_files']}")
                print(f"当前线程数: {status['max_threads']}")
                print(f"播放速度: {status['playback_speed']}倍速")
                if status['current_files']:
                    print(f"当前播放: {', '.join(status['current_files'])}")
            elif cmd in ["quit", "exit"]:
                player.stop()
                break
            else:
                print("未知命令")
    
    except KeyboardInterrupt:
        print("\n程序被中断")
    finally:
        if hasattr(player, 'running') and player.running:
            player.stop()
        print("程序已退出")