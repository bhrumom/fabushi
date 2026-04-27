#!/usr/bin/env python3
"""
字体子集化脚本 - 提取常用汉字

减少字体文件大小从 ~80MB 到 ~5MB
节省约 75MB bundle 大小
"""

# 常用汉字 3500字 (GB2312一级字库 + 高频二级字)
COMMON_CHINESE_CHARS = """
的一是在不了有和人这中大为上个国我以要他时来用们生到作地于出就分对成会可主发年动同工也能下过子说产种面而方后多定行学法所民得经十三之进着等部度家电力里如水化高自二理起小物现实加量都两体制机当使点从业本去把性好应开它合还因由其些然前外天政四日那社义事平形相全表间样与关各重新线内数正心反你明看原又么利比或但质气第向道命此变条只没结解问意建月公无系军很情者最立代想已通并提直题党程展五果料象员革位入常文总次品式活设及管特件长求老头基资边流路级少图山统接知较将组见计别她手角期根论运农指几九区强放决西被干做必战先回则任取据处队南给色光门即保治北造百规热领七海口东导器压志世金增争济阶油思术极交受联什认六共权收证改清己美再采转更单风切打白教速花带安场身车例真务具万每目至达走积示议声报斗完类八离华名确才科张信马节话米整空元况今集温传土许步群广石记需段研界拉林律叫且究观越织装影算低持音众书布复容儿须际商非验连断深难近矿千周委素技备半办青省列习响约支般史感劳便团往酸历市克何除消构府称太准精值号率族维划选标写存候毛亲快效斯院查江型眼王按格养易置派层片始却专状育厂京识适属圆包火住调满县局照参红细引听该铁价严龙飞
"""

# 扩展字符集 - 包含标点、数字、英文等
ADDITIONAL_CHARS = """
abcdefghijklmnopqrstuvwxyz
ABCDEFGHIJKLMNOPQRSTUVWXYZ
0123456789
！？。，、；：""''（）《》【】—…·~@#$%^&*_+-=[]{}|\\/<>
　
"""

def generate_char_list():
    """生成完整的字符列表"""
    # 去除空白字符并合并
    chars = set()
    
    # 添加常用汉字
    for char in COMMON_CHINESE_CHARS:
        if char.strip():
            chars.add(char)
    
    # 添加额外字符
    for char in ADDITIONAL_CHARS:
        if char.strip() and char != '\n':
            chars.add(char)
    
    # 添加常见佛教用语
    buddhist_terms = "佛法僧经咒禅净密律宗教寺院菩萨罗汉金刚观音地藏文殊普贤阿弥陀药师释迦牟尼涅槃般若波罗蜜多心无量寿供养功德回向慈悲智慧戒定慧三藏如来应供世尊天龙八部护法伽蓝韦驮"
    for char in buddhist_terms:
        chars.add(char)
    
    return sorted(chars)

def save_char_list(filename='common_chars.txt'):
    """保存字符列表到文件"""
    chars = generate_char_list()
    
    with open(filename, 'w', encoding='utf-8') as f:
        f.write(''.join(chars))
    
    # Count different character types
    chinese_chars = sum(1 for c in chars if '\u4e00' <= c <= '\u9fff')
    english_chars = sum(1 for c in chars if c.isalpha() and ord(c) < 128)
    digit_chars = sum(1 for c in chars if c.isdigit())
    other_chars = sum(1 for c in chars if not (c.isalpha() or c.isdigit() or '\u4e00' <= c <= '\u9fff'))
    
    print(f"✅ 已生成字符列表: {filename}")
    print(f"📊 总字符数: {len(chars)}")
    print(f"   - 汉字: ~{chinese_chars}")
    print(f"   - 英文: {english_chars}")
    print(f"   - 数字: {digit_chars}")
    print(f"   - 其他: {other_chars}")

if __name__ == '__main__':
    save_char_list()
    print("\n💡 下一步:")
    print("   pip3 install fonttools brotli")
    print("   然后运行: ./subset_fonts.sh")
