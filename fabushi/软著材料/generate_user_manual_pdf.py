#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
用户手册 PDF 生成脚本
生成软著申请所需的文档鉴别材料：前30页 + 后30页
"""

import subprocess
import sys
import os

def check_and_install_reportlab():
    """检查并安装 ReportLab"""
    try:
        from reportlab.lib.pagesizes import A4
        from reportlab.pdfgen import canvas
        from reportlab.pdfbase import pdfmetrics
        from reportlab.pdfbase.ttfonts import TTFont
        from reportlab.lib.units import cm
        return True
    except ImportError:
        print("📦 正在安装 ReportLab...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "reportlab", "-q"])
        return True

def generate_pdf():
    """生成用户手册 PDF"""
    from reportlab.lib.pagesizes import A4
    from reportlab.pdfgen import canvas
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    from reportlab.lib.units import cm
    
    # 获取脚本所在目录
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)
    
    # 尝试注册中文字体
    font_paths = [
        os.path.join(project_dir, "fonts", "MiSans-Regular.ttf"),
        "/System/Library/Fonts/STHeiti Light.ttc",
        "/System/Library/Fonts/PingFang.ttc",
        "/System/Library/Fonts/Hiragino Sans GB.ttc",
    ]
    
    font_name = "Helvetica"  # 默认字体
    for font_path in font_paths:
        if os.path.exists(font_path):
            try:
                pdfmetrics.registerFont(TTFont('ChineseFont', font_path))
                font_name = "ChineseFont"
                print(f"✅ 已注册字体: {font_path}")
                break
            except Exception as e:
                print(f"⚠️ 无法注册字体 {font_path}: {e}")
    
    # 读取用户手册内容
    manual_path = os.path.join(script_dir, "用户手册.md")
    if not os.path.exists(manual_path):
        print("❌ 用户手册.md 文件不存在")
        return
    
    with open(manual_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 按行分割
    lines = content.split('\n')
    
    # PDF 参数
    page_width, page_height = A4
    margin_left = 2.5 * cm
    margin_right = 2 * cm
    margin_top = 2.5 * cm
    margin_bottom = 2.5 * cm
    line_height = 0.6 * cm
    font_size = 10.5
    title_font_size = 16
    h1_font_size = 14
    h2_font_size = 12
    
    # 计算每页能容纳的行数
    usable_height = page_height - margin_top - margin_bottom
    lines_per_page = int(usable_height / line_height) - 2  # 预留页眉页脚空间
    
    # 分页处理
    pages = []
    current_page = []
    
    for line in lines:
        # 长行需要换行
        max_chars = 50  # 中文字符约50个
        if len(line) > max_chars:
            # 分割长行
            for i in range(0, len(line), max_chars):
                current_page.append(line[i:i+max_chars])
                if len(current_page) >= lines_per_page:
                    pages.append(current_page)
                    current_page = []
        else:
            current_page.append(line)
            if len(current_page) >= lines_per_page:
                pages.append(current_page)
                current_page = []
    
    if current_page:
        pages.append(current_page)
    
    total_pages = len(pages)
    print(f"📄 总页数: {total_pages}")
    
    def create_pdf(output_path, page_range, title_suffix):
        """创建PDF文件"""
        c = canvas.Canvas(output_path, pagesize=A4)
        
        for page_idx in page_range:
            if page_idx >= len(pages):
                break
            
            page_lines = pages[page_idx]
            y = page_height - margin_top
            
            # 页眉
            c.setFont(font_name, 9)
            c.drawString(margin_left, page_height - 1 * cm, "大乘软件 用户手册")
            c.drawRightString(page_width - margin_right, page_height - 1 * cm, f"第 {page_idx + 1} 页")
            
            # 分隔线
            c.line(margin_left, page_height - 1.3 * cm, page_width - margin_right, page_height - 1.3 * cm)
            
            y = page_height - margin_top
            
            for line in page_lines:
                # 判断标题级别
                if line.startswith('# '):
                    c.setFont(font_name, title_font_size)
                    c.drawString(margin_left, y, line[2:])
                    y -= line_height * 1.5
                elif line.startswith('## '):
                    c.setFont(font_name, h1_font_size)
                    c.drawString(margin_left, y, line[3:])
                    y -= line_height * 1.3
                elif line.startswith('### '):
                    c.setFont(font_name, h2_font_size)
                    c.drawString(margin_left, y, line[4:])
                    y -= line_height * 1.2
                elif line.startswith('#### '):
                    c.setFont(font_name, font_size + 1)
                    c.drawString(margin_left, y, line[5:])
                    y -= line_height * 1.1
                elif line.startswith('---'):
                    # 分隔线
                    c.line(margin_left, y + 0.2 * cm, page_width - margin_right, y + 0.2 * cm)
                    y -= line_height * 0.5
                elif line.startswith('| '):
                    # 表格行
                    c.setFont(font_name, font_size)
                    c.drawString(margin_left, y, line)
                    y -= line_height
                elif line.startswith('- ') or line.startswith('* '):
                    # 列表项
                    c.setFont(font_name, font_size)
                    c.drawString(margin_left + 0.5 * cm, y, "• " + line[2:])
                    y -= line_height
                elif line.strip().startswith(('1.', '2.', '3.', '4.', '5.', '6.', '7.', '8.', '9.')):
                    # 有序列表
                    c.setFont(font_name, font_size)
                    c.drawString(margin_left + 0.5 * cm, y, line.strip())
                    y -= line_height
                elif line.startswith('**') and line.endswith('**'):
                    # 粗体
                    c.setFont(font_name, font_size)
                    c.drawString(margin_left, y, line.replace('**', ''))
                    y -= line_height
                else:
                    # 普通文本
                    c.setFont(font_name, font_size)
                    text = line.replace('**', '').replace('`', '').replace('*', '')
                    c.drawString(margin_left, y, text)
                    y -= line_height
            
            # 页脚
            c.setFont(font_name, 9)
            c.line(margin_left, margin_bottom + 0.5 * cm, page_width - margin_right, margin_bottom + 0.5 * cm)
            c.drawCentredString(page_width / 2, margin_bottom, f"- {page_idx + 1} -")
            
            c.showPage()
        
        c.save()
        print(f"✅ 已生成: {output_path}")
    
    # 生成前30页
    first_30_path = os.path.join(script_dir, "用户手册_前30页.pdf")
    if total_pages <= 30:
        # 如果总页数不足30页，全部输出
        create_pdf(first_30_path, range(0, total_pages), "前30页")
    else:
        create_pdf(first_30_path, range(0, 30), "前30页")
    
    # 生成后30页
    last_30_path = os.path.join(script_dir, "用户手册_后30页.pdf")
    if total_pages <= 30:
        print("📝 总页数不足30页，只生成一个完整PDF")
    else:
        start_page = max(0, total_pages - 30)
        create_pdf(last_30_path, range(start_page, total_pages), "后30页")
    
    # 生成完整版
    full_path = os.path.join(script_dir, "用户手册_完整版.pdf")
    create_pdf(full_path, range(0, total_pages), "完整版")
    
    print(f"\n📊 生成统计:")
    print(f"   总页数: {total_pages}")
    print(f"   前30页: {min(30, total_pages)} 页")
    if total_pages > 30:
        print(f"   后30页: {min(30, total_pages - max(0, total_pages - 30))} 页")

if __name__ == "__main__":
    check_and_install_reportlab()
    generate_pdf()
