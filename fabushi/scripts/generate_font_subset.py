#!/usr/bin/env python3
"""
字体子集化脚本
将完整CJK字体（80MB+）压缩为仅包含常用汉字的子集（<5MB）

依赖安装：
pip install fonttools brotli zopfli

使用方法：
python3 scripts/generate_font_subset.py
"""

import os
import sys
import subprocess
from pathlib import Path

# 项目根目录
PROJECT_ROOT = Path(__file__).parent.parent
FONTS_DIR = PROJECT_ROOT / "fonts"
OUTPUT_DIR = PROJECT_ROOT / "fonts" / "subset"
CHARS_FILE = PROJECT_ROOT / "scripts" / "common_chars.txt"

# 常用汉字表（国标一级字3755字 + 常用佛教用字 + 数字标点）
# 这里包含GB2312一级字库中的常用汉字
COMMON_CHINESE_CHARS = """
一丁七万丈三上下不与专且世丙业丛东丝丢两严丧个中丰串临丸丹为主丽举乃久么义之乌乍乎乏乐乒乓乔乖乘乙九乞也习乡书买乱乳了予争事二亏云互五井亚些亡交亥亦产亩享京亭亮亲人亿什仁仂仃仆仇今介仍从仑仓仔他仗付仙代令以仪们仰仲件价任份仿企伊伍伏伐休优伙会伞伟传伤伦伪伯估伴伸似伺佃但位低住佑体何余佛作你佩佬佳使例侄侈侍供依侠侣侥侦侧侨侮侯侵便促俄俊俐俏俗俘保信俩俭修俯俱俺倍倒倔倘候倚借倡倦倩倪债值倾偎偏做停健偶偷偿傀傅傍傣储催傲傻像僚僧僵僻儒儿允元兄充兆先光克免兑兔兜党兰入全八公六兮兰共关兴兵其具典养兼冀内冈冉册再冒冕写军农冠冢冤冥冬冯冰冲决况冷冻净凄准凉凌减凑凛凝凡凤凭凯凰凳凶凸凹出击函凿刀刁刃分切刊刑划列刘则刚创初删判刨利别刮到制刷券刹刺刻刽刿剂剃削前剑剔剖剥剧剩剪副割剿劈力劝办功加务劣动助努劫励劲劳势勃勇勉勋勒勘募勤勺勾勿匀包匆匈匕化北匙匠匪匹区医匿十千升午半华协卓单卖南博卜卡卢卧卫卯印危即却卵卷卸卿厂厄厅历厉压厌厍厕厘厚原厢厦厨去县叁参又叉及友双反发叔取受变叙叛叠口古句另叨叩只叫召叭叮可台叱史右叶号司叹叼吁吃各吆吉吊同名后吏吐向吓吕吗君吝吞吟吠否吧吨吩含听吭吮启吱吴吵吸吹吻吼呀呆呈告呐呕员呛呜呢呦周呱呵呻呼命咀咂咆咋和咏咐咒咕咖咙咚咣咤咨咪咬咯咱咳咸咽哀品哄哆哇哈哉响哎哑哗哟哥哦哨哩哪哭哮哲哺哼唁唆唇唉唐唤唧唬售唯唱唾啃啄商啊啡啤啥啦啧啪啰啸喀喂喇喉喊喘喜喝喧喳喷喻嗅嗓嗜嗡嗣嗤嗦嗽嘀嘁嘉嘎嘘嘛嘟嘱嘲嘴嘶嘹嘻嘿噎噢器噩噪噬噶嚎嚏嚣嚷嚼囊囚四回因团囤园困囱围固国图圃圆圈土圣在圩地圣场圾址坊坎坏坐坑块坚坛坝坞坟坠坡坤坦坪坯坷垂垃型垒垛垢垣垦垫垮垮埃捕埋城域埔培基堂堆堕堡堤堪堰塌塑塔塘塞填境墅墓墙增墟墨墩壁壕壤士壮声壳壶壹处备复夏夕外夙多夜够大天太夫夭央失头夷夸夹夺奂奇奈奉奋奎奏契奔奕奖套奠奢奥女奴奶她好如妄妆妇妈妊妒妓妖妙妥妨妩妮妹妻姆姊始姐姑姓委姗姚姜姥姨姻姿威娃娄娅娇娘娜娟娱娶婆婉婚婴婶婿媒媚媛嫁嫂嫉嫌嫡嫩嬉子孔孕字存孙孝孟季孤学孩孪孵孽宁它宅宇守安宋完宏宗官宙定宛宜宝实宠审客宣室宥宦宪宫宰害宴宵家宾宿寂寄密寇富寐寒寓寝寞察寡寥寨寸对寺寻导封射将尊小少尔尖尘尚尝尤就尺尼尽尾尿局屁层居屈届屋屏屑展属屠屡屯山屹屿岂岔岖岗岘岛岩岭岳岸峙峡峦峨峭峰峻崇崎崔崖崩崭嵌巅巍川州巡巢工左巧巨巩巫差己已巳巴巷巾市布帅帆师希帐帕帖帘帚帛帜帝带席帮帷常帽幅幌幔幕幢干平年并幸幻幼幽广庄庆庇床序庐库应底店庙府庞废度座庭庵庶康庸廉廊廓延廷建开异弃弄弊式弓引弘弛弟张弥弦弧弯弱弹强归当录形彤彩彪彭彰影役彻彼往征径待很徊律徐徒徘得徙御循微德徽心必忆忌忍志忘忙忠忧快忱念忽忿怀态怎怒怔怕怖怜思怠怡急怨怪怯总怼恃恋恍恐恒恢恤恨恩恫恬恭息恳恶恼悄悉悍悔悖悟悠患悦您悬悯悲悴悸悼情惊惋惑惕惜惠惦惧惨惩惫惬惭惮惯惰惹惺愁愈愉愕愚感愣愤愧愿慈慌慎慕慢慧慨慰慷憋憎憔憧憨憩憬憾懂懈懊懒懦戈戊戌戎戏成我戒或战戚截戳戴户房所扁扇扉手才扎扑扒打扔托扛扣扦执扩扫扬扭扮扯扰扳扶批扼找承技抄把抑抒抓投抖抗折抚抛抠抡抢护报抨披抬抱抵抹押抽抿拂拄担拆拇拈拉拌拍拎拐拒拓拔拖拗拘拙招拜拟拢拣拥拦拧拨择括拭拯拱拳拴拷拼拽拾拿持挂指按挎挑挖挚挟挠挡挣挤挥挨挪挫振挺挽捂捅捆捉捌捍捎捏捐捕捞损捡换捣捧据捷捺掀授掉掌掏排掖掘掠探接控推掩措掰掳掴掷掸掺揉揍描提插揖握揣揩揪搀搁搂搅搏搓搔搜搞搪搬搭携摄摆摇摊摔摘摧摩摸撂撇撑撒撕撞撤撩撬播撮撰撵撼擂擅操擎擒擦攀攒攘攥收改攻放政故效敌敏救敖教敛敞敢散敦敬数敲整敷文斋斌斗料斜斟斤斥斧斩断斯新方施旁旅旋旌族旖旗无既日旦旧旨早旬旭旱时旷春昂昆昌明昏易昔昙昧是昨昭星映春昵昼显晃晋晌晒晓晚晤晦晨普景晰晴晶智晾暂暇暑暖暗暮暴曙曲曳更曼曾替最月有朋服朗望朝期朦木未末本札术朱朴朵机朽杀杂权杆杉李杏材村杖杜杞束杠条来杨杭杯杰松板极构枉析枕林枚果枝枢枣枪枫枯架枷柄柏某柑柒染柔柜柠查柬柯柳柱栅标栈栋栏树栓校栗样核根格栽桃桂框案桌桐桑档桥桦桩桶梁梅梆梗梦梢梧梨梭梯械梳检棉棋棍棒棕棘棚棠森棱棵棺椅植椎椒椭椰椿楔楚楞楠楣楷楼概榄榆榔榕榛榜榨榴槐槽樊樟模横樱橄橘橙橡橱檀檐檩檬欠次欢欣欧欲欺款歃歇歉歌止正此步武歧歪死殃殉殊残殖殡殴段殷殿毁毅母每毒比毕毗毙毛毡毫毯氏民氓气氛氢氧氨氮水永汁求汇汉汗汛汝汞江池污汤汪汰汽沃沈沉沙沛沟没沥沦沧沫沮河沸油治沼沾沿泄泉泊泌泛泞泡波泣泥注泪泰泳泻泼泽洁洋洒洗洛洞津洪洱洲洼活洽派流浅浆浇浊测济浑浓浙浚浦浩浪浮浴海浸涂消涉涌涎涓涕涛涝涟涡涣涤润涨涩涮涯液涵淀淆淋淌淑淘淡淤淫深淳混淹添清渊渐渔渗渠渡渣渤温港渴游湃湖湘湾源溃溅溉溜溢溪溯溶溺滁滋滑滓滔滚滞满滤滥滨滩滴漂漆漏演漓漠漩漫漱漾潘潜潦潮潭澄澈澎澜濒灌火灭灯灰灵灶灿炀炉炊炎炒炕炫炬炭炮炸点炼烁烂烈烘烙烛烟烤烦烧烫热烹焉焊焕焚焦焰然煌煎煞煤熄熊熏熔熙熬燃燎燕燥爆爪爬爱爵父爷爸爽片版牌牍牙牛牟牡牢牧物牲牵特牺犀犁犊犬犯状犹犷狂狈狐狗狞狠狡独狭狮狰狱狸狼猎猖猛猜猩猫猬猴猾猿獗玄率玉王玖玛玫环现玲玷珊珍珠班珩球琅理琉琐琢琳琴琼瑙瑚瑞瑟瑰璃璧瓜瓢瓣瓤瓦瓮瓶甘甚甜生甥用甩电由甲申男甸画畅界畏畔畜畦略畸番畴疆疏疑疗疚疟疤疫疮疯疲疴疵疸疹疼疾痈痉痊痒痔痕痘痛痢痣痪痰痴痹痿瘙瘟瘤瘦瘩瘪瘫瘸瘾癌癣登白百皂的皆皇皈皋皮皱皿盅盆盈益盎盏盐监盒盔盖盗盘盛盟目盯盲直相盼盾省眉看眍眙真眠眨眩眯眶眷眺眼着睁睐睡督睦睫睬睹瞄瞅瞎瞒瞥瞧瞩瞪瞬瞭瞰瞻矗矛矢知矩矫短矮石矾矿码砂砌砍研砖砚砰破砷砸砺硅硕硝硫硬确碉碌碍碎碑碗碘碛碟碧碰碱碴碾磁磅磊磋磕磨磷礁礼社祀祁祈祖祛祝神祟祠祥票祭祷祸禀禁禄福离禽禾秀私秆秉秋种科秒秕秘租秤秦秧秩积称移秽稀程稍税稚稠稳稻稼稽稿穆穗穴究穷空穿突窃窄窍窑窒窗窘窜窝窟窥窿立竖站竞竣童竭端竹竿笆笋笑笔笙笛笠笤笥符笨笫第笸笺笼等筋筏筐筑筒答策筛筝筷筹签简箍箔箕算管箩箫箭箱篇篓篙篡篮篱篷簇簸簿籍米类粉粒粗粘粟粤粥粪粱粹精糊糕糖糙糟糠糯系紧絮累絷綦縻繁纠红纤约纫纬纯纰纱纲纳纵纶纷纸纹纺纽线练组绅细织终绊绍绎经绑绒结绘绚绞络绢绣绥绦继绩绪续绮绯绳维绵绷绸综绽绿缀缄编缆缉缎缓缕缚缜缝缠缤缨缩缭缰缴缸缺罂罄罐网罕罗罚罩罪置署羁羊美羔羞羡群羹羽翁翅翊翌翎翔翘翠翩翰翱翻翼耀老考者耐耕耗耙耳耸耻耽耿聂聆聊聋职联聘聚聪肃肄肆肇肉肋肌肖肘肚肛肝肠股肢肤肥肩肪肮肯肴育肺肾肿胀胁胃胆胎胖胚胜胞胡胧胳胶胸能脂脆脉脊脏脐脓脖脚脱脸腊腋腌腐腑腔腕腥腮腰腹腺腻腾腿膀膊膏膘膛膜膝膨臀臂臊臭臼舀舅舆舌舍舒舔舛舜舞舟航般舰舱船艇艘良艰色艳艺艾节芋芍芒芙芜芝芥芦芬芭芯花芳芹芽苇苍苏苔苗苛苞苟若苦英苹茂范茄茅茉茎茧茨茫茬茴茵茶茸茹荆荐草荒荔荚荞荣荤荧荫药荷荻莉莎莫莱莲获莹莺莽菇菊菌菜菠菩菱菲萄萌萍萎萝萤营萦萧萨落葛葡董葩葫葬葱葵蒂蒋蒜蒙蒸蒿蓄蓉蓑蓝蔑蔓蔗蔚蔡蔫蔬蔷蔺蔻蔼蕉蕊蕴蕾薄薇薛薪薯藏藐藕藤藻蘑蘸虎虏虐虑虔虚虫虱虹虽虾蚀蚁蚂蚊蚌蚕蚜蚣蚤蚪蚯蛀蛇蛋蛔蛙蛛蛤蛮蛾蜀蜂蜒蜓蜕蜗蜘蜜蜡蜻蝇蝉蝎蝗蝠蝴蝶蝼螃融螟螺蟀蟋蟑蟹蠕蠢血衅行衍衔街衙衡衣补表衩衫衬衰衷袄袋袍袒袖袜被袭裁裂装裕裘裙裤裳裹褂褐褒褓褛褪襟西要覆见观规觅视觉览觊觐觑角解触言誉誊誓警计订认讥讨让训议讯记讲许论讼讽设访诀证诈诉诊词译试诗诚话诞诡询该详诫诬语误诱诲说诵请诸诺读诽课谁调谅谆谈谊谋谍谎谐谒谓谚谛谜谢谣谤谦谧谨谩谬谭谱谴谷豁豆豌象豪豫豹豺貂貌贝贞负贡财责贤败账货质贩贪贫贬购贮贯贰贱贴贵贷贸费贺贻贼贾贿赁赂赃资赈赊赋赌赎赏赐赔赖赘赚赛赞赠赢赣赤赦赫走赴赵起趁超越趋趟趣足跃跋跌跑跛距跟跨跪路跳践跷跺身躬躲躺车轧轨轩轮软轰轴轻载轿较辅辆辈辉辊辐辑输辕辖辗辙辛辜辞辟辣辨辩辫辰辱边辽达迁迂迄迅过迈迎运近返还这进远违连迟迢迤迥迦迪迫迭述迷迹追退送适逃逆选逊透逐递途通逝逞速造逢逮逸逼逾遁遂遇遍道遏遗遣遥遭遮遵避邀邂邃邑邓邦邪邮邱邵邻郁郊郎郑部郭都鄙酉酋配酒酗酝酣酥酬酱酵酷酸醇醋醉醒醚采释里重野量金鉴针钉钊钒钓钗钙钝钞钟钠钢钥钦钧钩钮钱钳钻钿铁铂铃铅铆铐铛铝铡铣铤铭铲银铸铺链销锁锄锅锈锉锋锌锏锐错锡锢锣锤锥锦锨锭键锯锰锲锹锻镀镁镇镉镌镐镑镕镖镜镣镭镰镶长门闪闭问闯闰闲间闷闸闹闺闻闽闾阀阁阂阅阐阔队阱防阳阴阵阶阻阿附际陆陈陋陌降限陕陛陡院除陨险陪陵陶陷隆随隐隔隘隙障隧隶难雀雁雄雅集雇雌雏雕雨雪零雷雹雾需霆震霉霍霎霜霞露霸霹青靖静非靠靡面革靴靶靼鞋鞍鞘鞠鞭韧韩韭音韵韶页顶项顺须顽顾顿颁颂预颅领颇颈颊颌频颓颖颗题颚颜额颠颤风飒飓飘飙飞食餐饥饭饮饰饱饲饵饶饺饼饿馁馅馆馈馋馒馏馒首香馨马驭驮驯驰驱驳驴驶驹驻驼驾骂骄骆骇骏骑骗骚骡骤骨骰骸髓高鬓鬼魁魂魄魅魏魔鱼鲁鲜鲤鲨鲸鳄鳖鳞鸟鸠鸡鸣鸥鸦鸵鸽鸿鹃鹅鹉鹊鹏鹤鹰鹿麓麦麻黄黎黑黔默鼎鼓鼠鼻齐齿龄龙龟
"""

# 佛教常用字（确保经文显示正确）
BUDDHIST_CHARS = """
阿弥陀佛南无观世音菩萨大势至般若波罗蜜多心经摩诃萨埵地藏王金刚六字真言唵嘛呢叭咪吽梵文三宝
皈依戒定慧涅槃轮回因果业障消除福慧念诵持咒禅坐冥想慈悲喜舍布施供养礼拜忏悔众生解脱净土
极乐世界西方莲花化生出家受戒袈裟钵盂丛林寺庙道场塔殿佛像开光加持回向功德圆满吉祥如意平安健康
咒语陀罗尼楞严楞伽华严法华涅槃阿含四谛十二因缘八正道五戒十善六度万行菩提心无上正等正觉
"""

# ASCII字符和常用标点
ASCII_AND_PUNCTUATION = """
 !"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~
，。、；：？！""''【】《》（）——……·
"""

def check_dependencies():
    """检查依赖是否安装"""
    try:
        import fontTools
        print("✅ fonttools 已安装")
    except ImportError:
        print("❌ 缺少 fonttools，正在安装...")
        subprocess.run([sys.executable, "-m", "pip", "install", "fonttools", "brotli", "zopfli"], check=True)
        print("✅ fonttools 安装完成")

def create_chars_file():
    """创建字符集文件"""
    all_chars = set()
    
    # 合并所有字符
    for chars in [COMMON_CHINESE_CHARS, BUDDHIST_CHARS, ASCII_AND_PUNCTUATION]:
        for char in chars:
            if char.strip():
                all_chars.add(char)
    
    # 去除空白字符，保留空格
    all_chars = {c for c in all_chars if c not in '\n\r\t'}
    all_chars.add(' ')  # 确保空格存在
    
    # 写入字符集文件
    CHARS_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(CHARS_FILE, 'w', encoding='utf-8') as f:
        f.write(''.join(sorted(all_chars)))
    
    print(f"✅ 字符集文件已创建: {CHARS_FILE}")
    print(f"   包含 {len(all_chars)} 个字符")
    
    return CHARS_FILE

def subset_font(input_font, output_font, chars_file):
    """子集化字体"""
    from fontTools import subset
    
    # 确定输出格式
    output_woff2 = output_font.with_suffix('.woff2')
    
    # 使用 pyftsubset 命令
    args = [
        str(input_font),
        f"--text-file={chars_file}",
        f"--output-file={output_woff2}",
        "--flavor=woff2",
        "--layout-features=*",  # 保留所有 OpenType 特性
        "--no-hinting",  # 移除 hinting 以减小文件大小
        "--desubroutinize",  # 有时可以减小文件大小
    ]
    
    try:
        subset.main(args)
        
        # 计算压缩比
        original_size = input_font.stat().st_size
        subset_size = output_woff2.stat().st_size
        ratio = (1 - subset_size / original_size) * 100
        
        print(f"✅ {input_font.name}")
        print(f"   原始大小: {original_size / 1024 / 1024:.2f} MB")
        print(f"   子集大小: {subset_size / 1024:.2f} KB")
        print(f"   压缩比: {ratio:.1f}%")
        
        return output_woff2
    except Exception as e:
        print(f"❌ 子集化失败 {input_font.name}: {e}")
        return None

def main():
    print("=" * 60)
    print("🔤 字体子集化工具")
    print("=" * 60)
    print()
    
    # 检查依赖
    check_dependencies()
    print()
    
    # 创建字符集文件
    chars_file = create_chars_file()
    print()
    
    # 创建输出目录
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    
    # 处理所有字体
    font_files = list(FONTS_DIR.glob("*.otf")) + list(FONTS_DIR.glob("*.ttf"))
    
    if not font_files:
        print("❌ 未找到字体文件")
        return 1
    
    print(f"📁 找到 {len(font_files)} 个字体文件")
    print()
    
    results = []
    total_original = 0
    total_subset = 0
    
    for font_file in font_files:
        if font_file.parent == OUTPUT_DIR:
            continue  # 跳过已子集化的文件
            
        output_name = font_file.stem + "-subset"
        output_path = OUTPUT_DIR / (output_name + font_file.suffix)
        
        result = subset_font(font_file, output_path, chars_file)
        if result:
            results.append(result)
            total_original += font_file.stat().st_size
            total_subset += result.stat().st_size
        print()
    
    # 输出总结
    print("=" * 60)
    print("📊 子集化总结")
    print("=" * 60)
    print(f"原始总大小: {total_original / 1024 / 1024:.2f} MB")
    print(f"子集总大小: {total_subset / 1024 / 1024:.2f} MB")
    print(f"节省空间: {(total_original - total_subset) / 1024 / 1024:.2f} MB ({(1 - total_subset / total_original) * 100:.1f}%)")
    print()
    print(f"✅ 子集化字体保存在: {OUTPUT_DIR}")
    print()
    
    # 生成 Web 字体引用代码
    print("📝 Web字体引用代码 (添加到 index.html):")
    print("-" * 60)
    for result in results:
        font_name = result.stem.replace("-subset", "")
        print(f'<link rel="preload" href="assets/fonts/subset/{result.name}" as="font" type="font/woff2" crossorigin>')
    print("-" * 60)
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
