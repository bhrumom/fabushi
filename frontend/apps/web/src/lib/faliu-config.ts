export type FaliuTabKey =
  | "all"
  | "buddha"
  | "prajna"
  | "pureland"
  | "lotus"
  | "huayan"
  | "agama"
  | "zen"
  | "mantra"
  | "vinaya"
  | "abhidharma";

export interface FaliuTabConfig {
  key: FaliuTabKey;
  labelZh: string;
  labelEn: string;
  featured: string[];
  tokens: string[];
}

export const CARD_LIMIT = 12;

export const FALIU_TABS: FaliuTabConfig[] = [
  {
    key: "all",
    labelZh: "全部",
    labelEn: "All",
    featured: [
      "T0365",
      "T0251",
      "T0235",
      "T0262",
      "T0279",
      "T0366",
      "T0001",
      "T0099",
      "T0220",
      "T0374",
      "T0261",
      "T0278",
    ],
    tokens: [],
  },
  {
    key: "buddha",
    labelZh: "佛说",
    labelEn: "Buddha",
    featured: [],
    tokens: ["佛說", "佛说"],
  },
  {
    key: "prajna",
    labelZh: "般若",
    labelEn: "Prajna",
    featured: [],
    tokens: ["般若", "金剛", "金刚", "心經", "心经"],
  },
  {
    key: "pureland",
    labelZh: "净土",
    labelEn: "Pure Land",
    featured: [],
    tokens: ["無量壽", "无量寿", "阿彌陀", "阿弥陀", "觀無量壽", "观无量寿", "淨土", "净土"],
  },
  {
    key: "lotus",
    labelZh: "法华",
    labelEn: "Lotus",
    featured: [],
    tokens: ["法華", "法华", "妙法蓮華", "妙法莲华"],
  },
  {
    key: "huayan",
    labelZh: "华严",
    labelEn: "Huayan",
    featured: [],
    tokens: ["華嚴", "华严", "大方廣佛", "大方广佛"],
  },
  {
    key: "agama",
    labelZh: "阿含",
    labelEn: "Agama",
    featured: [],
    tokens: ["阿含", "長阿含", "长阿含", "雜阿含", "杂阿含", "中阿含", "增壹阿含"],
  },
  {
    key: "zen",
    labelZh: "禅门",
    labelEn: "Zen",
    featured: [],
    tokens: ["壇經", "坛经", "禪", "禅", "祖師", "祖师", "公案"],
  },
  {
    key: "mantra",
    labelZh: "密教",
    labelEn: "Mantra",
    featured: [],
    tokens: ["陀羅尼", "陀罗尼", "真言", "密", "咒"],
  },
  {
    key: "vinaya",
    labelZh: "律藏",
    labelEn: "Vinaya",
    featured: [],
    tokens: ["律", "毘尼", "戒"],
  },
  {
    key: "abhidharma",
    labelZh: "论藏",
    labelEn: "Abhidharma",
    featured: [],
    tokens: ["論", "论", "俱舍", "毘婆沙", "阿毘達磨", "阿毗达磨"],
  },
];

export const FALIU_FEATURED_WORKS = FALIU_TABS[0].featured;
