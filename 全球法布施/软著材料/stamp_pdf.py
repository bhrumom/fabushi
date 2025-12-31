import sys
import subprocess
import os

def install_and_import():
    try:
        import fitz
        from PIL import Image
    except ImportError:
        print("Installing dependencies...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "pymupdf", "Pillow"])
    import fitz
    from PIL import Image
    return fitz, Image

def make_transparent(image_path, output_png_path, Image):
    """Converts a white background image to transparent PNG."""
    img = Image.open(image_path).convert("RGBA")
    data = img.getdata()
    
    new_data = []
    for item in data:
        # If the pixel is close to white, make it transparent
        if item[0] > 220 and item[1] > 220 and item[2] > 220:
            new_data.append((255, 255, 255, 0))
        else:
            new_data.append(item)
    
    img.putdata(new_data)
    img.save(output_png_path, "PNG")
    return output_png_path

def main():
    fitz, Image = install_and_import()
    
    pdf_path = "/Users/gloriachan/Documents/全球发送/全球法布施/软著材料/用户中心.pdf"
    image_path = "/Users/gloriachan/Documents/全球发送/全球法布施/软著材料/公司电子印章.jpg"
    temp_image_path = "/Users/gloriachan/Documents/全球发送/全球法布施/软著材料/公司电子印章_transparent.png"
    output_path = "/Users/gloriachan/Documents/全球发送/全球法布施/软著材料/用户中心_已盖章_v2.pdf"
    
    if not os.path.exists(pdf_path):
        print(f"Error: {pdf_path} not found")
        return
    if not os.path.exists(image_path):
        print(f"Error: {image_path} not found")
        return

    # Make image transparent
    make_transparent(image_path, temp_image_path, Image)

    doc = fitz.open(pdf_path)
    found = False
    
    # Search for "申请人签章：" or similar on all pages
    search_queries = ["申请人签章：", "申请人签章", "盖章"]
    
    for page_num in range(len(doc)):
        page = doc[page_num]
        
        for query in search_queries:
            text_instances = page.search_for(query)
            if text_instances:
                print(f"Found '{query}' on page {page_num + 1}")
                found = True
                for inst in text_instances:
                    # Place the seal to the right of the text
                    seal_width = 120
                    seal_height = 120
                    
                    x_offset = 10
                    # Center vertically with the text
                    y_center = (inst.y0 + inst.y1) / 2
                    
                    rect = fitz.Rect(
                        inst.x1 + x_offset,
                        y_center - seal_height/2,
                        inst.x1 + x_offset + seal_width,
                        y_center + seal_height/2
                    )
                    
                    page.insert_image(rect, filename=temp_image_path)
                    print(f"Placed seal at {rect}")
                break # Move to next page if found on this page
                
    if not found:
        print("Could not find any target text. Placing at default position.")
    else:
        doc.save(output_path)
        print(f"Saved stamped PDF to {output_path}")
    
    doc.close()
    
    # Clean up temp file
    if os.path.exists(temp_image_path):
        os.remove(temp_image_path)

if __name__ == "__main__":
    main()
