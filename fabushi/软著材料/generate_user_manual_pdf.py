#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
用户手册 PDF 生成脚本
生成软著申请所需的文档鉴别材料：前30页 + 后30页
"""

import subprocess
import sys
import os
import re

def check_and_install_dependencies():
    """检查并安装依赖库"""
    dependencies_installed = True
    try:
        import reportlab
    except ImportError:
        dependencies_installed = False
    
    try:
        import pypdf
    except ImportError:
        dependencies_installed = False

    try:
        import PIL
    except ImportError:
        dependencies_installed = False

    if not dependencies_installed:
        print("📦 正在安装依赖项 (reportlab, pypdf, pillow)...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "reportlab", "pypdf", "pillow", "-q"])

def generate_pdf():
    """生成用户手册 PDF"""
    from reportlab.lib.pagesizes import A4
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    from reportlab.lib.units import cm
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Image, PageBreak, HRFlowable
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib import colors
    
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
                
    # Define styles
    styles = getSampleStyleSheet()
    
    # Base styles mapping to ChineseFont
    normal_style = ParagraphStyle(
        'ChineseNormal',
        parent=styles['Normal'],
        fontName=font_name,
        fontSize=10.5,
        leading=16,
        spaceAfter=8,
    )
    
    h1_style = ParagraphStyle(
        'ChineseH1',
        parent=styles['Heading1'],
        fontName=font_name,
        fontSize=16,
        leading=22,
        spaceBefore=16,
        spaceAfter=12,
    )
    
    h2_style = ParagraphStyle(
        'ChineseH2',
        parent=styles['Heading2'],
        fontName=font_name,
        fontSize=14,
        leading=18,
        spaceBefore=12,
        spaceAfter=8,
    )
    
    h3_style = ParagraphStyle(
        'ChineseH3',
        parent=styles['Heading3'],
        fontName=font_name,
        fontSize=12,
        leading=16,
        spaceBefore=10,
        spaceAfter=6,
    )

    h4_style = ParagraphStyle(
        'ChineseH4',
        parent=styles['Heading4'],
        fontName=font_name,
        fontSize=11.5,
        leading=16,
        spaceBefore=8,
        spaceAfter=4,
    )
    
    list_style = ParagraphStyle(
        'ChineseList',
        parent=normal_style,
        leftIndent=20,
        spaceBefore=2,
        spaceAfter=2,
    )

    # 读取用户手册内容
    manual_path = os.path.join(script_dir, "用户手册.md")
    if not os.path.exists(manual_path):
        print("❌ 用户手册.md 文件不存在")
        return
    
    with open(manual_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    lines = content.split('\n')
    story = []
    
    # 匹配 Markdown 图片
    img_re = re.compile(r'!\[.*?\]\((.*?)\)')
    
    # 转换为 platypus Flowables
    for line in lines:
        line = line.strip()
        if not line:
            continue
            
        img_match = img_re.search(line)
        if img_match:
            img_path_rel = img_match.group(1)
            img_path_abs = os.path.join(script_dir, img_path_rel)
            if os.path.exists(img_path_abs):
                # Calculate image size to fit A4 width
                try:
                    from PIL import Image as PILImage
                    with PILImage.open(img_path_abs) as pil_img:
                        w, h = pil_img.size
                except ImportError:
                    # Fallback if PIL not installed
                    w, h = 1080, 2400
                    
                # Max width ~ 14 cm
                max_w = 14 * cm
                if w > max_w:
                    ratio = max_w / w
                    w = max_w
                    h = h * ratio
                
                # Make sure height is not larger than page height
                max_h = 22 * cm
                if h > max_h:
                    ratio = max_h / h
                    h = max_h
                    w = w * ratio
                    
                story.append(Spacer(1, 10))
                story.append(Image(img_path_abs, width=w, height=h))
                story.append(Spacer(1, 10))
            else:
                print(f"⚠️ 图片不存在: {img_path_abs}")
            continue

        # 解析文本和标题
        if line.startswith('# '):
            story.append(Paragraph(line[2:], h1_style))
        elif line.startswith('## '):
            story.append(Paragraph(line[3:], h2_style))
        elif line.startswith('### '):
            story.append(Paragraph(line[4:], h3_style))
        elif line.startswith('#### '):
            story.append(Paragraph(line[5:], h4_style))
        elif line.startswith('---'):
            story.append(HRFlowable(width="100%", thickness=1, spaceBefore=10, spaceAfter=10, color=colors.grey))
        elif line.startswith('- ') or line.startswith('* '):
            item = "• " + line[2:].replace('**', '').replace('`', '')
            story.append(Paragraph(item, list_style))
        elif line.startswith('| ') or re.match(r'^\d+\.\s', line):
            # 表格部分或者有序列表，简单以段落显示
            item = line.replace('**', '').replace('`', '')
            if line.startswith('| '):
                if '|---' in line: continue
            story.append(Paragraph(item, list_style if not line.startswith('|') else normal_style))
        else:
            text = line.replace('**', '').replace('`', '').replace('*', '')
            story.append(Paragraph(text, normal_style))
            
    # 页眉页脚模板
    def header_footer(canvas, doc):
        canvas.saveState()
        canvas.setFont(font_name, 9)
        page_num = canvas.getPageNumber()
        
        page_width, page_height = A4
        margin_left = 2.5 * cm
        margin_right = 2 * cm
        margin_top = 2.5 * cm
        margin_bottom = 2.5 * cm
        
        # Header
        canvas.drawString(margin_left, page_height - 1 * cm, "大乘软件 用户手册")
        canvas.drawRightString(page_width - margin_right, page_height - 1 * cm, f"第 {page_num} 页")
        canvas.line(margin_left, page_height - 1.3 * cm, page_width - margin_right, page_height - 1.3 * cm)
        
        # Footer
        canvas.line(margin_left, margin_bottom + 0.5 * cm, page_width - margin_right, margin_bottom + 0.5 * cm)
        canvas.drawCentredString(page_width / 2, margin_bottom, f"- {page_num} -")
        
        canvas.restoreState()

    def create_pdf(output_path, target_story):
        doc = SimpleDocTemplate(
            output_path,
            pagesize=A4,
            leftMargin=2.5*cm,
            rightMargin=2*cm,
            topMargin=2.5*cm,
            bottomMargin=3.5*cm
        )
        doc.build(target_story, onFirstPage=header_footer, onLaterPages=header_footer)
        print(f"✅ 已生成: {output_path}")

    full_path = os.path.join(script_dir, "用户手册_完整版.pdf")
    create_pdf(full_path, story)

    # 提取前30页和后30页软件著作权材料
    from pypdf import PdfReader, PdfWriter
    
    reader = PdfReader(full_path)
    total_pages = len(reader.pages)
    print(f"📊 完整版总页数: {total_pages}")
    
    # 前30页
    first_30_path = os.path.join(script_dir, "用户手册_前30页.pdf")
    writer1 = PdfWriter()
    for i in range(min(30, total_pages)):
        writer1.add_page(reader.pages[i])
    with open(first_30_path, "wb") as f_out:
        writer1.write(f_out)
    print(f"✅ 已生成: {first_30_path} ({min(30, total_pages)}页)")
    
    # 后30页
    last_30_path = os.path.join(script_dir, "用户手册_后30页.pdf")
    if total_pages > 30:
        writer2 = PdfWriter()
        start_idx = max(0, total_pages - 30)
        for i in range(start_idx, total_pages):
            writer2.add_page(reader.pages[i])
        with open(last_30_path, "wb") as f_out:
            writer2.write(f_out)
        print(f"✅ 已生成: {last_30_path} ({total_pages - start_idx}页)")
    else:
        print("📝 总页数不足30页，不单独生成后30页")

if __name__ == "__main__":
    check_and_install_dependencies()
    generate_pdf()
