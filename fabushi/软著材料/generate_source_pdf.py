#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
源程序鉴别材料PDF生成器
生成符合软著要求的前30页和后30页PDF文件
每页约50行代码，每份材料精确30页
"""

import os
import sys

def check_and_install_deps():
    try:
        from reportlab.lib.pagesizes import A4
        from reportlab.pdfgen import canvas
        from reportlab.pdfbase import pdfmetrics
        from reportlab.pdfbase.ttfonts import TTFont
        from reportlab.lib.units import cm
        return True
    except ImportError:
        import subprocess
        subprocess.check_call([sys.executable, "-m", "pip", "install", "reportlab", "-q"])
        return True

def generate_source_code_pdf():
    from reportlab.lib.pagesizes import A4
    from reportlab.pdfgen import canvas
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    from reportlab.lib.units import cm
    
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # 注册中文字体
    font_paths = [
        "/System/Library/Fonts/STHeiti Light.ttc",
        "/System/Library/Fonts/PingFang.ttc",
        "/System/Library/Fonts/Hiragino Sans GB.ttc",
    ]
    
    font_name = "Courier"
    for font_path in font_paths:
        if os.path.exists(font_path):
            try:
                pdfmetrics.registerFont(TTFont('ChineseFont', font_path))
                font_name = "ChineseFont"
                print(f"✅ 已注册字体: {font_path}")
                break
            except Exception as e:
                pass
    
    # 读取源程序代码
    source_path = os.path.join(script_dir, "源程序代码.txt")
    if not os.path.exists(source_path):
        print("❌ 源程序代码.txt 文件不存在")
        return
    
    with open(source_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    total_lines = len(lines)
    print(f"📄 源代码总行数: {total_lines}")
    
    # PDF参数 - 确保每页至少50行
    page_width, page_height = A4
    margin_left = 1.5 * cm
    margin_right = 1 * cm
    margin_top = 2 * cm
    margin_bottom = 1.5 * cm
    line_height = 0.38 * cm  # 减小行间距
    font_size = 8  # 减小字体
    
    # 计算每页行数
    usable_height = page_height - margin_top - margin_bottom - 1 * cm  # 减去页眉页脚空间
    lines_per_page = int(usable_height / line_height)
    print(f"📐 每页行数: {lines_per_page}")
    
    # 需要30页，计算需要的行数
    lines_needed = lines_per_page * 30
    print(f"📑 30页需要行数: {lines_needed}")
    
    def create_pdf(output_path, code_lines, title_prefix):
        c = canvas.Canvas(output_path, pagesize=A4)
        
        page_num = 0
        line_idx = 0
        
        while line_idx < len(code_lines) and page_num < 30:
            page_num += 1
            y = page_height - margin_top
            
            # 页眉
            c.setFont(font_name, 9)
            c.drawString(margin_left, page_height - 1 * cm, "大乘软件 V3.0 源程序代码")
            c.drawRightString(page_width - margin_right, page_height - 1 * cm, f"第 {page_num} 页")
            c.line(margin_left, page_height - 1.3 * cm, page_width - margin_right, page_height - 1.3 * cm)
            
            y = page_height - margin_top
            
            # 写入代码行
            for _ in range(lines_per_page):
                if line_idx >= len(code_lines):
                    break
                
                line = code_lines[line_idx].rstrip('\n\r')
                # 截断过长的行
                max_chars = 85
                if len(line) > max_chars:
                    line = line[:max_chars] + "..."
                
                c.setFont(font_name, font_size)
                try:
                    c.drawString(margin_left, y, line)
                except:
                    # 如果有无法渲染的字符，用替代字符
                    c.drawString(margin_left, y, line.encode('ascii', 'replace').decode())
                
                y -= line_height
                line_idx += 1
            
            # 页脚
            c.setFont(font_name, 9)
            c.line(margin_left, margin_bottom + 0.3 * cm, page_width - margin_right, margin_bottom + 0.3 * cm)
            c.drawCentredString(page_width / 2, margin_bottom - 0.2 * cm, f"- {page_num} -")
            
            c.showPage()
        
        c.save()
        print(f"✅ 已生成: {output_path} ({page_num} 页)")
        return page_num
    
    # 生成前30页
    front_lines = lines[:lines_needed]
    front_path = os.path.join(script_dir, "源程序_前30页.pdf")
    create_pdf(front_path, front_lines, "前30页")
    
    # 生成后30页
    back_lines = lines[-lines_needed:] if len(lines) > lines_needed else lines
    back_path = os.path.join(script_dir, "源程序_后30页.pdf")
    create_pdf(back_path, back_lines, "后30页")
    
    print(f"\n📊 生成完成!")

if __name__ == "__main__":
    check_and_install_deps()
    generate_source_code_pdf()
