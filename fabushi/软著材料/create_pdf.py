#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
软件著作权 - 源程序鉴别材料 PDF 生成器
生成符合要求的前30页和后30页PDF文件
"""

import subprocess
import sys

def create_pdf_with_enscript():
    """使用 enscript 和 ps2pdf 生成 PDF"""
    import os
    os.chdir('/Users/gloriachan/Documents/全球发送/全球法布施/软著材料')
    
    files = [
        ('源程序_前30页.txt', '源程序_前30页.pdf'),
        ('源程序_后30页.txt', '源程序_后30页.pdf')
    ]
    
    for txt_file, pdf_file in files:
        print(f"正在生成: {pdf_file}")
        
        # 使用 textutil 转换为 RTF，然后用 cupsfilter 转 PDF
        # 或者直接使用简单的方法
        try:
            # 方法：使用 cupsfilter
            result = subprocess.run(
                ['cupsfilter', txt_file],
                capture_output=True
            )
            with open(pdf_file, 'wb') as f:
                f.write(result.stdout)
            print(f"  ✓ 已生成: {pdf_file}")
        except Exception as e:
            print(f"  ✗ 生成失败: {e}")
            # 尝试备用方法
            try:
                # 使用 textutil 转 html，再打印为 PDF
                subprocess.run(['textutil', '-convert', 'html', txt_file, '-output', txt_file.replace('.txt', '.html')])
                print(f"  → 已生成 HTML 文件，请手动打开并打印为 PDF")
            except:
                pass

if __name__ == '__main__':
    create_pdf_with_enscript()
