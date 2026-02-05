#!/usr/bin/env python3
"""使用 macOS 原生框架合并 PDF"""
import os
import subprocess

def merge_pdfs_with_automator(pdf1, pdf2, output):
    """使用 Automator 的 join 工具合并 PDF"""
    join_tool = "/System/Library/Automator/Combine PDF Pages.action/Contents/MacOS/join"
    
    # 先检查源文件
    for f in [pdf1, pdf2]:
        if not os.path.exists(f):
            print(f"错误: 文件不存在 {f}")
            return False
    
    # 删除已存在的输出文件
    if os.path.exists(output):
        os.remove(output)
    
    # 执行合并
    result = subprocess.run([join_tool, "-o", output, pdf1, pdf2], 
                          capture_output=True, text=True)
    
    if result.returncode != 0:
        print(f"合并失败: {result.stderr}")
        return False
    
    return True

# 获取页面数量
def get_page_count(pdf_path):
    result = subprocess.run(
        ["mdls", "-name", "kMDItemNumberOfPages", "-raw", pdf_path],
        capture_output=True, text=True
    )
    try:
        return int(result.stdout.strip())
    except:
        return "未知"

if __name__ == "__main__":
    pdf1 = "源程序_前30页.pdf"
    pdf2 = "源程序_后30页.pdf"
    output = "源程序_完整.pdf"
    
    print(f"正在合并:")
    print(f"  - {pdf1} ({get_page_count(pdf1)} 页)")
    print(f"  - {pdf2} ({get_page_count(pdf2)} 页)")
    
    if merge_pdfs_with_automator(pdf1, pdf2, output):
        print(f"\n✅ 合并成功!")
        print(f"输出文件: {output} ({get_page_count(output)} 页)")
    else:
        print(f"\n❌ 合并失败")
