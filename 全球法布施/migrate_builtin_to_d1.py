#!/usr/bin/env python3
"""
内置内容迁移到D1数据库脚本
支持乾隆大藏经GBK编码文件和全文搜索功能
"""

import os
import json
import requests
import chardet
from pathlib import Path
import time
import hashlib

class BuiltinToD1Migrator:
    def __init__(self, backend_url="https://flutter.ombhrum.com"):
        self.backend_url = backend_url
        self.builtin_path = Path("assets/built_in")
        self.batch_size = 10  # 每批处理的文件数
        
    def detect_encoding(self, file_path):
        """检测文件编码"""
        try:
            with open(file_path, 'rb') as f:
                raw_data = f.read(10000)  # 读取前10KB检测编码
                result = chardet.detect(raw_data)
                return result.get('encoding', 'utf-8')
        except Exception as e:
            print(f"❌ 编码检测失败 {file_path}: {e}")
            return 'utf-8'
    
    def read_file_content(self, file_path):
        """读取文件内容，自动处理编码"""
        encoding = self.detect_encoding(file_path)
        
        # 乾隆大藏经通常是GBK编码
        if "乾隆大藏经" in str(file_path):
            encoding = 'gbk'
        
        try:
            with open(file_path, 'r', encoding=encoding, errors='ignore') as f:
                content = f.read()
                # 清理内容
                content = self.clean_content(content)
                return content
        except Exception as e:
            print(f"❌ 读取文件失败 {file_path}: {e}")
            return ""
    
    def clean_content(self, content):
        """清理文件内容"""
        # 移除ChmDecompiler标记
        content = content.replace("This file is decompiled by an unregistered version of ChmDecompiler.Regsitered version does not show this message.You can buy ChmDecompiler at:     http://www.etextwizard.com/", "")
        
        # 移除多余的空行和空格
        lines = [line.strip() for line in content.split('\n') if line.strip()]
        return '\n'.join(lines)
    
    def extract_metadata(self, file_path):
        """提取文件元数据"""
        relative_path = file_path.relative_to(self.builtin_path)
        parts = relative_path.parts
        
        # 确定分类
        category = "其他"
        if len(parts) > 0:
            category = parts[0]
        
        # 提取标题
        title = file_path.stem
        if title.startswith("第") and "部" in title:
            # 处理乾隆大藏经格式：第0017部～般若波罗蜜多心经一卷
            title = title.split("～")[-1] if "～" in title else title
        
        return {
            "title": title,
            "category": category,
            "filePath": str(relative_path),
            "fileName": file_path.name
        }
    
    def scan_builtin_files(self):
        """扫描内置文件"""
        files = []
        
        # 扫描所有txt文件
        for txt_file in self.builtin_path.rglob("*.txt"):
            if txt_file.is_file() and txt_file.stat().st_size > 0:
                files.append(txt_file)
        
        print(f"📁 发现 {len(files)} 个文本文件")
        return files
    
    def process_files_batch(self, files):
        """批量处理文件"""
        texts = []
        
        for file_path in files:
            try:
                print(f"📖 处理文件: {file_path.name}")
                
                # 读取内容
                content = self.read_file_content(file_path)
                if not content or len(content.strip()) < 10:
                    print(f"⚠️  跳过空文件: {file_path.name}")
                    continue
                
                # 提取元数据
                metadata = self.extract_metadata(file_path)
                
                # 计算字数
                word_count = len(content.replace(' ', '').replace('\n', ''))
                
                # 生成唯一ID
                file_id = hashlib.md5(str(file_path).encode()).hexdigest()[:16]
                
                text_data = {
                    "id": file_id,
                    "title": metadata["title"],
                    "content": content,
                    "filePath": metadata["filePath"],
                    "category": metadata["category"],
                    "fileName": metadata["fileName"],
                    "wordCount": word_count,
                    "source": "builtin"
                }
                
                texts.append(text_data)
                print(f"✅ 处理完成: {metadata['title']} ({word_count}字)")
                
            except Exception as e:
                print(f"❌ 处理文件失败 {file_path}: {e}")
                continue
        
        return texts
    
    def upload_to_d1(self, texts):
        """上传到D1数据库"""
        if not texts:
            print("⚠️  没有文本需要上传")
            return False
        
        url = f"{self.backend_url}/migrate-builtin-complete"
        payload = {"texts": texts}
        
        try:
            print(f"🚀 上传 {len(texts)} 个文本到D1数据库...")
            
            response = requests.post(
                url,
                json=payload,
                headers={"Content-Type": "application/json"},
                timeout=60
            )
            
            print(f"📊 HTTP状态码: {response.status_code}")
            
            if response.status_code == 200:
                result = response.json()
                print(f"✅ 上传成功: {result}")
                return True
            else:
                print(f"❌ 上传失败: {response.status_code}")
                print(f"📄 响应内容: {response.text}")
                return False
                
        except Exception as e:
            print(f"💥 上传异常: {e}")
            return False
    
    def migrate_all(self):
        """迁移所有内置内容"""
        print("🎯 开始迁移内置内容到D1数据库")
        print(f"🌐 后端地址: {self.backend_url}")
        print(f"📁 内置内容路径: {self.builtin_path}")
        
        # 扫描文件
        files = self.scan_builtin_files()
        if not files:
            print("❌ 没有找到文件")
            return
        
        # 分批处理
        total_uploaded = 0
        total_batches = (len(files) + self.batch_size - 1) // self.batch_size
        
        for i in range(0, len(files), self.batch_size):
            batch_files = files[i:i + self.batch_size]
            batch_num = i // self.batch_size + 1
            
            print(f"\n📦 处理批次 {batch_num}/{total_batches} ({len(batch_files)} 个文件)")
            
            # 处理文件
            texts = self.process_files_batch(batch_files)
            
            if texts:
                # 上传到D1
                if self.upload_to_d1(texts):
                    total_uploaded += len(texts)
                    print(f"✅ 批次 {batch_num} 上传成功")
                else:
                    print(f"❌ 批次 {batch_num} 上传失败")
            
            # 短暂延迟避免过载
            time.sleep(1)
        
        print(f"\n🎉 迁移完成！")
        print(f"📊 总计上传: {total_uploaded} 个文本")
        print(f"📁 总计文件: {len(files)} 个")

def main():
    """主函数"""
    migrator = BuiltinToD1Migrator()
    migrator.migrate_all()

if __name__ == "__main__":
    main()