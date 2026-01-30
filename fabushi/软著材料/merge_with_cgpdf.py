#!/usr/bin/env python3
"""使用 CoreGraphics 直接合并 PDF"""
import subprocess
import sys

# 使用 cgpdftopdf 或者创建一个简单的合并脚本
script = '''
tell application "System Events"
    set pdf1 to POSIX file "%s/源程序_前30页.pdf"
    set pdf2 to POSIX file "%s/源程序_后30页.pdf"
end tell
''' % (subprocess.run(['pwd'], capture_output=True, text=True).stdout.strip(),
       subprocess.run(['pwd'], capture_output=True, text=True).stdout.strip())

print(script)
