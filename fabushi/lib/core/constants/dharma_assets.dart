/// 法宝素材列表
///
/// 此文件根据原生Web应用中的 `dharma-assets.js` 文件移植而来。
/// 定义了所有可用于全球法布施的素材。
const List<Map<String, String>> DHARMA_ASSETS = [
  // 内置经文和咒语
  {"name": "《一切如来心秘密全身舍利宝箧印陀罗尼经》", "type": "built_in", "path": "assets/built_in/texts/宝箧印经.txt"},
  {"name": "《僧伽吒经》", "type": "built_in", "path": "assets/built_in/texts/僧伽吒经.txt"},
  {"name": "《金刚般若波罗蜜经》", "type": "built_in", "path": "assets/built_in/texts/金刚经.txt"},
  {"name": "《佛说阿弥陀经》", "type": "built_in", "path": "assets/built_in/texts/佛说阿弥陀经.txt"},
  {"name": "《观世音菩萨普门品》", "type": "built_in", "path": "assets/built_in/texts/普门品.txt"},
  {"name": "《高王观世音经》", "type": "built_in", "path": "assets/built_in/texts/高王观世音经.txt"},
  {"name": "《心经》", "type": "built_in", "path": "assets/built_in/texts/心经.txt"},
  {"name": "《大悲咒》", "type": "built_in", "path": "assets/built_in/mantras/大悲咒.txt"},
  {"name": "《楞严咒》", "type": "built_in", "path": "assets/built_in/mantras/楞严咒.txt"},
  {"name": "《宝箧印陀罗尼》", "type": "built_in", "path": "assets/built_in/mantras/宝箧印陀罗尼.txt"},
  {"name": "《僧伽吒经核心四句偈》", "type": "built_in", "path": "assets/built_in/mantras/僧伽吒经四句偈.txt"},
  {"name": "《六字大明咒》", "type": "built_in", "path": "assets/built_in/mantras/六字大明咒.txt"},
  // 存放在Cloudflare R2的大文件
  {"name": "《乾隆大藏经》完整TXT版 (1.1GB)", "type": "r2-asset", "path": "乾隆大藏经/乾隆大藏经txt版.zip"},
  {"name": "《房山石经》陀罗尼梵音 (2.6GB)", "type": "r2-asset", "path": "乾隆大藏经/房山石经陀罗尼梵音音频.zip"},
];
