import { T0235_JUAN_1_MERIT_BENEFITS } from "./faliu-merit-benefits-t0235";
import { T0237_JUAN_1_MERIT_BENEFITS } from "./faliu-merit-benefits-t0237";
import { T0238_JUAN_1_MERIT_BENEFITS } from "./faliu-merit-benefits-t0238";
import { T0239_JUAN_1_MERIT_BENEFITS } from "./faliu-merit-benefits-t0239";
import { T0240_JUAN_1_MERIT_BENEFITS } from "./faliu-merit-benefits-t0240";
import { T0241_JUAN_1_MERIT_BENEFITS } from "./faliu-merit-benefits-t0241";
import { T0242_JUAN_1_MERIT_BENEFITS } from "./faliu-merit-benefits-t0242";
import { T0243_JUAN_1_MERIT_BENEFITS } from "./faliu-merit-benefits-t0243";
import { T0244_JUAN_1_MERIT_BENEFITS } from "./faliu-merit-benefits-t0244";
import { T0244_JUAN_2_MERIT_BENEFITS } from "./faliu-merit-benefits-t0244-juan2";
import { T0244_JUAN_2_SEGMENT_8_MERIT_BENEFITS } from "./faliu-merit-benefits-t0244-juan2-segment8";
import { T0244_JUAN_2_SEGMENT_9_MERIT_BENEFITS } from "./faliu-merit-benefits-t0244-juan2-segment9";
import { T0244_JUAN_2_SEGMENT_10_MERIT_BENEFITS } from "./faliu-merit-benefits-t0244-juan2-segment10";
import { T0244_JUAN_3_MERIT_BENEFITS } from "./faliu-merit-benefits-t0244-juan3";
import { T0244_JUAN_4_MERIT_BENEFITS } from "./faliu-merit-benefits-t0244-juan4";
import { T0244_JUAN_4_SEGMENT_16_MERIT_BENEFITS } from "./faliu-merit-benefits-t0244-juan4-segment16";
import { T0244_JUAN_5_MERIT_BENEFITS } from "./faliu-merit-benefits-t0244-juan5";
import { T0244_JUAN_6_MERIT_BENEFITS } from "./faliu-merit-benefits-t0244-juan6";
import { T0244_JUAN_6_SEGMENT_23_MERIT_BENEFITS } from "./faliu-merit-benefits-t0244-juan6-segment23";
import { T0244_JUAN_7_MERIT_BENEFITS } from "./faliu-merit-benefits-t0244-juan7";
import { T0244_JUAN_7_SEGMENT_25_MERIT_BENEFITS } from "./faliu-merit-benefits-t0244-juan7-segment25";
import { T0245_JUAN_1_MERIT_BENEFITS } from "./faliu-merit-benefits-t0245";
import { T0245_JUAN_2_MERIT_BENEFITS } from "./faliu-merit-benefits-t0245-juan2";
import { T0246_JUAN_1_MERIT_BENEFITS } from "./faliu-merit-benefits-t0246";
import { T0262_JUAN_7_MERIT_BENEFITS } from "./faliu-merit-benefits-t0262";
import { T0366_JUAN_1_MERIT_BENEFITS } from "./faliu-merit-benefits-t0366";
import { T1153_JUAN_1_MERIT_BENEFITS, T1153_JUAN_2_MERIT_BENEFITS } from "./faliu-merit-benefits-t1153";

export interface FaliuMeritBenefit {
  id: string;
  category: string;
  sectionTitle?: string;
  text: string;
  anchorText: string;
  note?: string;
  occurrence?: number;
}

export const T0001_JUAN_1_MERIT_BENEFITS: FaliuMeritBenefit[] = [
  {
    id: "t0001-001-001",
    category: "为什么值得读",
    text: "諸賢比丘！唯無上尊為最奇特，神通遠達，威力弘大，乃知過去無數諸佛，入於涅槃，斷諸結使，消滅戲論。",
    anchorText: "唯無上尊為最奇特，神通遠達，威力弘大，乃知過去無數諸佛",
    note: "本卷从比丘赞叹佛的宿命智开篇，说明佛能亲知过去诸佛本末因缘。",
  },
  {
    id: "t0001-001-002",
    category: "为什么值得读",
    text: "汝等欲聞如來識宿命智，知於過去諸佛因緣不？我當說之。",
    anchorText: "汝等欲聞如來識宿命智，知於過去諸佛因緣不？我當說之",
    note: "佛亲自发起宣说过去诸佛因缘，是本卷最直接的阅读入口。",
  },
  {
    id: "t0001-001-003",
    category: "闻已欢喜",
    text: "此是諸佛因緣、名號、種族、所出生處，何有智者聞此因緣而不歡喜，起愛樂心？",
    anchorText: "此是諸佛因緣、名號、種族、所出生處，何有智者聞此因緣而不歡喜，起愛樂心",
    note: "经文直接说，有智慧者听闻诸佛因缘会生欢喜与爱乐心。",
  },
  {
    id: "t0001-001-004",
    category: "认识诸佛",
    text: "日月所不及，莫不蒙大明，處胎淨無穢，諸佛法皆然。",
    anchorText: "日月所不及，莫不蒙大明，處胎淨無穢，諸佛法皆然",
    note: "本卷以诸佛常法呈现佛入胎、出世的清净与光明。",
  },
  {
    id: "t0001-001-005",
    category: "认识佛愿",
    text: "天上天下唯我為尊，要度眾生生老病死。",
    anchorText: "天上天下唯我為尊，要度眾生生老病死",
    note: "一句点出佛出世的核心愿力：度众生出生老病死。",
  },
  {
    id: "t0001-001-006",
    category: "看清出离",
    text: "太子見老、病人，知世苦惱，又見死人，戀世情滅；及見沙門，廓然大悟。下寶車時，步步中間轉遠縛著，是真出家，是真遠離。",
    anchorText: "太子見老、病人，知世苦惱，又見死人，戀世情滅",
    note: "本卷通过老、病、死与沙门相，说明出离心如何生起。",
  },
  {
    id: "t0001-001-007",
    category: "看清出离",
    text: "撰擇深妙法，彼聞隨出家；離於恩愛獄，無有眾結縛。",
    anchorText: "撰擇深妙法，彼聞隨出家；離於恩愛獄，無有眾結縛",
    note: "经文赞叹闻深妙法而出家，能远离恩爱系缚。",
  },
  {
    id: "t0001-001-008",
    category: "理解成道关键",
    text: "菩薩逆順觀十二因緣，如實知，如實見已，即於座上成阿耨多羅三藐三菩提。",
    anchorText: "菩薩逆順觀十二因緣，如實知，如實見已，即於座上成阿耨多羅三藐三菩提",
    note: "本卷明说成道关键在于逆顺观察十二因缘。",
  },
  {
    id: "t0001-001-009",
    category: "理解成道关键",
    text: "此言眾中說，汝等當善聽，過去菩薩觀，本所未聞法。",
    anchorText: "此言眾中說，汝等當善聽，過去菩薩觀，本所未聞法",
    note: "十二因缘观被标举为过去菩萨所观、本所未闻之法。",
  },
  {
    id: "t0001-001-010",
    category: "理解成道关键",
    text: "十二緣甚深，難見難識知；唯佛能善覺，因是有是無。",
    anchorText: "十二緣甚深，難見難識知；唯佛能善覺，因是有是無",
    note: "读者可由此进入佛所善觉的甚深缘起。",
  },
  {
    id: "t0001-001-011",
    category: "法义利益",
    text: "若能自觀察，則無有諸入；深見因緣者，更不外求師。",
    anchorText: "若能自觀察，則無有諸入；深見因緣者，更不外求師",
    note: "这里的利益不是外在福报，而是引导读者自观因缘、建立正见。",
  },
  {
    id: "t0001-001-012",
    category: "法义利益",
    text: "能於陰界入，離欲無染者；堪受一切施，淨報施者恩。",
    anchorText: "能於陰界入，離欲無染者；堪受一切施，淨報施者恩",
    note: "经文把通达阴界入与离欲无染相连，显示修学方向。",
  },
  {
    id: "t0001-001-013",
    category: "法义利益",
    text: "色受想行識，猶如朽故車；能諦觀此法，則成等正覺。",
    anchorText: "色受想行識，猶如朽故車；能諦觀此法，則成等正覺",
    note: "以五阴观照说明谛观此法所指向的觉悟。",
  },
  {
    id: "t0001-001-014",
    category: "法义利益",
    text: "如來無等等，多修於二觀；安隱及出離，仙人度彼岸。",
    anchorText: "如來無等等，多修於二觀；安隱及出離，仙人度彼岸",
    note: "本卷将佛初成道后的观行概括为安隐观与出离观。",
  },
  {
    id: "t0001-001-015",
    category: "甘露法门",
    text: "吾愍汝等，今當開演甘露法門，是法深妙，難可解知，今為信受樂聽者說，不為觸擾無益者說。",
    anchorText: "今當開演甘露法門，是法深妙，難可解知，今為信受樂聽者說",
    note: "经文把所说之法称为深妙难知的甘露法门。",
  },
  {
    id: "t0001-001-016",
    category: "法轮利益",
    text: "此無上法輪，唯佛乃能轉；諸天魔釋梵，無有能轉者。親近轉法輪，饒益天人眾；此等天人師，得度于彼岸。",
    anchorText: "此無上法輪，唯佛乃能轉；諸天魔釋梵，無有能轉者",
    note: "赞叹佛转无上法轮，并说明亲近此法能饶益天人、趣向彼岸。",
  },
  {
    id: "t0001-001-017",
    category: "法义利益",
    text: "苦與苦因，滅苦之諦，賢聖八道，到安隱處。",
    anchorText: "苦與苦因，滅苦之諦，賢聖八道，到安隱處",
    note: "用极短一句指出本卷所开示的离苦、灭苦与八正道。",
  },
  {
    id: "t0001-001-018",
    category: "经文总赞",
    text: "此是諸佛，本末因緣，釋迦如來，之所演說。",
    anchorText: "此是諸佛，本末因緣，釋迦如來，之所演說",
    note: "结尾自明主题：这是释迦如来所演说的诸佛本末因缘。",
  },
  {
    id: "t0001-001-019",
    category: "闻已奉行",
    text: "佛說此大因緣經已，諸比丘聞佛所說，歡喜奉行。",
    anchorText: "佛說此大因緣經已，諸比丘聞佛所說，歡喜奉行",
    note: "以闻法欢喜奉行收束，适合作为读者侧的结尾提示。",
  },
];

export function getFaliuMeritBenefits(work: string | null | undefined, juan: string | number | null | undefined) {
  const normalizedWork = work?.trim().toUpperCase();
  const normalizedJuan = String(juan ?? "1").replace(/^0+(?=\d)/, "") || "1";

  if (normalizedWork === "T0001" && normalizedJuan === "1") {
    return T0001_JUAN_1_MERIT_BENEFITS;
  }

  if (normalizedWork === "T0235" && normalizedJuan === "1") {
    return T0235_JUAN_1_MERIT_BENEFITS;
  }

  if (normalizedWork === "T0237" && normalizedJuan === "1") {
    return T0237_JUAN_1_MERIT_BENEFITS;
  }

  if (normalizedWork === "T0238" && normalizedJuan === "1") {
    return T0238_JUAN_1_MERIT_BENEFITS;
  }

  if (normalizedWork === "T0239" && normalizedJuan === "1") {
    return T0239_JUAN_1_MERIT_BENEFITS;
  }

  if (normalizedWork === "T0240" && normalizedJuan === "1") {
    return T0240_JUAN_1_MERIT_BENEFITS;
  }

  if (normalizedWork === "T0241" && normalizedJuan === "1") {
    return T0241_JUAN_1_MERIT_BENEFITS;
  }

  if (normalizedWork === "T0242" && normalizedJuan === "1") {
    return T0242_JUAN_1_MERIT_BENEFITS;
  }

  if (normalizedWork === "T0243" && normalizedJuan === "1") {
    return T0243_JUAN_1_MERIT_BENEFITS;
  }

  if (normalizedWork === "T0244" && normalizedJuan === "1") {
    return T0244_JUAN_1_MERIT_BENEFITS;
  }

  if (normalizedWork === "T0244" && normalizedJuan === "2") {
    return [
      ...T0244_JUAN_2_MERIT_BENEFITS,
      ...T0244_JUAN_2_SEGMENT_8_MERIT_BENEFITS,
      ...T0244_JUAN_2_SEGMENT_9_MERIT_BENEFITS,
      ...T0244_JUAN_2_SEGMENT_10_MERIT_BENEFITS,
    ];
  }

  if (normalizedWork === "T0244" && normalizedJuan === "3") {
    return T0244_JUAN_3_MERIT_BENEFITS;
  }

  if (normalizedWork === "T0244" && normalizedJuan === "4") {
    return [
      ...T0244_JUAN_4_MERIT_BENEFITS,
      ...T0244_JUAN_4_SEGMENT_16_MERIT_BENEFITS,
    ];
  }

  if (normalizedWork === "T0244" && normalizedJuan === "5") {
    return T0244_JUAN_5_MERIT_BENEFITS;
  }

  if (normalizedWork === "T0244" && normalizedJuan === "6") {
    return [
      ...T0244_JUAN_6_MERIT_BENEFITS,
      ...T0244_JUAN_6_SEGMENT_23_MERIT_BENEFITS,
    ];
  }

  if (normalizedWork === "T0244" && normalizedJuan === "7") {
    return [
      ...T0244_JUAN_7_MERIT_BENEFITS,
      ...T0244_JUAN_7_SEGMENT_25_MERIT_BENEFITS,
    ];
  }

  if (normalizedWork === "T0245" && normalizedJuan === "1") {
    return T0245_JUAN_1_MERIT_BENEFITS;
  }

  if (normalizedWork === "T0245" && normalizedJuan === "2") {
    return T0245_JUAN_2_MERIT_BENEFITS;
  }

  if (normalizedWork === "T0246" && normalizedJuan === "1") {
    return T0246_JUAN_1_MERIT_BENEFITS;
  }

  if (normalizedWork === "T0262" && normalizedJuan === "7") {
    return T0262_JUAN_7_MERIT_BENEFITS;
  }

  if (normalizedWork === "T0366" && normalizedJuan === "1") {
    return T0366_JUAN_1_MERIT_BENEFITS;
  }

  if (normalizedWork === "T1153" && normalizedJuan === "1") {
    return T1153_JUAN_1_MERIT_BENEFITS;
  }

  if (normalizedWork === "T1153" && normalizedJuan === "2") {
    return T1153_JUAN_2_MERIT_BENEFITS;
  }

  return [];
}
