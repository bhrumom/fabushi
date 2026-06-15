export interface FaliuAnkiCard {
  id: string;
  front: string;
  back: string;
  hint?: string;
  sourceText?: string;
  tags?: string[];
}

export interface FaliuAnkiDeck {
  contentId: string;
  work: string;
  juan: string;
  title: string;
  cards: FaliuAnkiCard[];
}

/**
 * AI batch entry point for 法流背诵卡片.
 *
 * Add one deck per CBETA juan. The key must match buildCbetaContentId(work, juan):
 * contentId: "cbeta:T0251:1"
 *
 * Suggested card style:
 * - front: question, cloze prompt, or first half of a verse/sentence.
 * - back: exact memorization answer.
 * - hint: optional short cue.
 * - sourceText: optional original sentence/paragraph for audit.
 * - tags: work id, title, topic, chapter, or practice label.
 */
export const FALIU_ANKI_CARD_DECKS: FaliuAnkiDeck[] = [
  {
    contentId: "cbeta:T0251:1",
    work: "T0251",
    juan: "1",
    title: "般若波羅蜜多心經",
    cards: [
      {
        id: "cbeta:T0251:1:understand-001",
        front: "《心經》的實修主軸可怎樣概括？",
        back: "依般若照見五蘊皆空。",
        hint: "先建立全經大意，再記細節。",
        sourceText: "觀自在菩薩，行深般若波羅蜜多時，照見五蘊皆空，度一切苦厄。",
        tags: ["T0251", "心經", "總綱", "理解"],
      },
      {
        id: "cbeta:T0251:1:understand-002",
        front: "經中「照見五蘊皆空」直接對治什麼？",
        back: "一切苦厄。",
        hint: "觀空的作用。",
        sourceText: "照見五蘊皆空，度一切苦厄。",
        tags: ["T0251", "心經", "總綱", "苦厄"],
      },
      {
        id: "cbeta:T0251:1:understand-003",
        front: "《心經》中被觀為「皆空」的身心總類是什麼？",
        back: "五蘊。",
        hint: "色、受、想、行、識的總名。",
        sourceText: "照見五蘊皆空。",
        tags: ["T0251", "心經", "五蘊", "基礎"],
      },
      {
        id: "cbeta:T0251:1:understand-004",
        front: "「色不異空，空不異色」避免把色與空看成什麼？",
        back: "彼此分離的兩物。",
        hint: "先記「不異」。",
        sourceText: "色不異空，空不異色。",
        tags: ["T0251", "心經", "色空", "理解"],
      },
      {
        id: "cbeta:T0251:1:understand-005",
        front: "「色即是空，空即是色」強調色與空的哪種關係？",
        back: "色空相即。",
        hint: "再記「即是」。",
        sourceText: "色即是空，空即是色。",
        tags: ["T0251", "心經", "色空", "理解"],
      },
      {
        id: "cbeta:T0251:1:understand-006",
        front: "除色蘊外，經文說哪四蘊也「亦復如是」？",
        back: "受、想、行、識。",
        hint: "這是短枚舉，保留為一張。",
        sourceText: "受、想、行、識，亦復如是。",
        tags: ["T0251", "心經", "五蘊", "枚舉"],
      },
      {
        id: "cbeta:T0251:1:understand-007",
        front: "「是諸法空相」先破哪一對相？",
        back: "生／滅。",
        hint: "三對相之一。",
        sourceText: "是諸法空相，不生不滅，不垢不淨，不增不減。",
        tags: ["T0251", "心經", "空相", "最小信息"],
      },
      {
        id: "cbeta:T0251:1:understand-008",
        front: "「是諸法空相」第二對破哪一對相？",
        back: "垢／淨。",
        hint: "三對相之一。",
        sourceText: "是諸法空相，不生不滅，不垢不淨，不增不減。",
        tags: ["T0251", "心經", "空相", "最小信息"],
      },
      {
        id: "cbeta:T0251:1:understand-009",
        front: "「是諸法空相」最後破哪一對相？",
        back: "增／減。",
        hint: "三對相之一。",
        sourceText: "是諸法空相，不生不滅，不垢不淨，不增不減。",
        tags: ["T0251", "心經", "空相", "最小信息"],
      },
      {
        id: "cbeta:T0251:1:understand-010",
        front: "「空中無色，無受、想、行、識」否定的是哪一組分類？",
        back: "五蘊。",
        hint: "不要背整串，先認出分類。",
        sourceText: "是故空中無色，無受、想、行、識。",
        tags: ["T0251", "心經", "五蘊", "分類"],
      },
      {
        id: "cbeta:T0251:1:understand-011",
        front: "「無眼、耳、鼻、舌、身、意」否定的是哪一組？",
        back: "六根。",
        hint: "主觀能取的六根。",
        sourceText: "無眼、耳、鼻、舌、身、意。",
        tags: ["T0251", "心經", "六根", "分類"],
      },
      {
        id: "cbeta:T0251:1:understand-012",
        front: "「無色、聲、香、味、觸、法」否定的是哪一組？",
        back: "六塵／六境。",
        hint: "六根所對的六境。",
        sourceText: "無色、聲、香、味、觸、法。",
        tags: ["T0251", "心經", "六塵", "分類"],
      },
      {
        id: "cbeta:T0251:1:understand-013",
        front: "「無眼界，乃至無意識界」攝略哪一法門？",
        back: "十八界。",
        hint: "從眼界略至意識界。",
        sourceText: "無眼界，乃至無意識界。",
        tags: ["T0251", "心經", "十八界", "分類"],
      },
      {
        id: "cbeta:T0251:1:understand-014",
        front: "十二因緣的否定，經文從哪一支說起？",
        back: "無明。",
        hint: "只問起點，避免長枚舉。",
        sourceText: "無無明，亦無無明盡；乃至無老死，亦無老死盡。",
        tags: ["T0251", "心經", "十二因緣", "最小信息"],
      },
      {
        id: "cbeta:T0251:1:understand-015",
        front: "十二因緣的否定，經文攝略到哪一支？",
        back: "老死。",
        hint: "只問終點，避免長枚舉。",
        sourceText: "無無明，亦無無明盡；乃至無老死，亦無老死盡。",
        tags: ["T0251", "心經", "十二因緣", "最小信息"],
      },
      {
        id: "cbeta:T0251:1:understand-016",
        front: "「無苦、集、滅、道」否定的是哪一組佛法分類？",
        back: "四聖諦。",
        hint: "把四項歸成一個已知分類。",
        sourceText: "無苦、集、滅、道。",
        tags: ["T0251", "心經", "四聖諦", "分類"],
      },
      {
        id: "cbeta:T0251:1:understand-017",
        front: "「無智亦無得」的理由是什麼？",
        back: "以無所得故。",
        hint: "經文直接給出原因。",
        sourceText: "無智亦無得，以無所得故。",
        tags: ["T0251", "心經", "無所得", "因果"],
      },
      {
        id: "cbeta:T0251:1:understand-018",
        front: "菩提薩埵心無罣礙，是因為依何法？",
        back: "般若波羅蜜多。",
        hint: "依般若，所以無礙。",
        sourceText: "菩提薩埵，依般若波羅蜜多故，心無罣礙。",
        tags: ["T0251", "心經", "菩薩行", "因果"],
      },
      {
        id: "cbeta:T0251:1:understand-019",
        front: "心無罣礙後，經文首先說消除了哪種心理狀態？",
        back: "恐怖。",
        hint: "無礙故無怖。",
        sourceText: "心無罣礙；無罣礙故，無有恐怖。",
        tags: ["T0251", "心經", "菩薩行", "心理"],
      },
      {
        id: "cbeta:T0251:1:understand-020",
        front: "菩薩遠離顛倒夢想後，趣向什麼果？",
        back: "究竟涅槃。",
        hint: "離倒夢想，至涅槃。",
        sourceText: "遠離顛倒夢想，究竟涅槃。",
        tags: ["T0251", "心經", "涅槃", "因果"],
      },
      {
        id: "cbeta:T0251:1:understand-021",
        front: "三世諸佛依般若波羅蜜多，證得什麼？",
        back: "阿耨多羅三藐三菩提。",
        hint: "諸佛所證的無上正等正覺。",
        sourceText: "三世諸佛，依般若波羅蜜多故，得阿耨多羅三藐三菩提。",
        tags: ["T0251", "心經", "佛果", "因果"],
      },
      {
        id: "cbeta:T0251:1:understand-022",
        front: "經文稱般若波羅蜜多為「大神呪、大明呪……」，主要是在讚歎哪一面向？",
        back: "般若的不可思議力用。",
        hint: "不是單純記名號，而是抓功能定位。",
        sourceText: "故知般若波羅蜜多，是大神呪，是大明呪，是無上呪，是無等等呪。",
        tags: ["T0251", "心經", "般若呪", "理解"],
      },
      {
        id: "cbeta:T0251:1:understand-023",
        front: "般若波羅蜜多呪的作用是什麼？",
        back: "能除一切苦。",
        hint: "問功能，不背整段。",
        sourceText: "能除一切苦。",
        tags: ["T0251", "心經", "般若呪", "作用"],
      },
      {
        id: "cbeta:T0251:1:understand-024",
        front: "經文如何判定般若波羅蜜多呪的可靠性？",
        back: "真實不虛。",
        hint: "問判定語。",
        sourceText: "真實不虛。",
        tags: ["T0251", "心經", "般若呪", "判定"],
      },
    ],
  },
];

export const FALIU_ANKI_DECK_MAP = Object.fromEntries(FALIU_ANKI_CARD_DECKS.map((deck) => [deck.contentId, deck]));
