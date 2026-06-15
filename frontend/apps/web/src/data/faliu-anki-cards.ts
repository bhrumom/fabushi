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
        id: "cbeta:T0251:1:recite-001",
        front: "請背誦《心經》開頭：觀自在菩薩，行深般若波羅蜜多時，照見……",
        back: "五蘊皆空，度一切苦厄。",
        hint: "先記住觀照所得與作用。",
        sourceText: "觀自在菩薩，行深般若波羅蜜多時，照見五蘊皆空，度一切苦厄。",
        tags: ["T0251", "心經", "開頭", "recitation"],
      },
      {
        id: "cbeta:T0251:1:recite-002",
        front: "舍利子，色不異空，空不異色；接著背：",
        back: "色即是空，空即是色。",
        hint: "從「不異」轉到「即是」。",
        sourceText: "舍利子，色不異空，空不異色；色即是空，空即是色。",
        tags: ["T0251", "心經", "色空", "recitation"],
      },
      {
        id: "cbeta:T0251:1:recite-003",
        front: "色即是空，空即是色。其餘四蘊如何？",
        back: "受、想、行、識，亦復如是。",
        hint: "四蘊依次補足五蘊。",
        sourceText: "色即是空，空即是色。受、想、行、識，亦復如是。",
        tags: ["T0251", "心經", "五蘊", "recitation"],
      },
      {
        id: "cbeta:T0251:1:recite-004",
        front: "舍利子，是諸法空相；先背前兩對否定：",
        back: "不生不滅，不垢不淨。",
        hint: "生滅、垢淨。",
        sourceText: "舍利子，是諸法空相，不生不滅，不垢不淨，不增不減。",
        tags: ["T0251", "心經", "空相", "recitation"],
      },
      {
        id: "cbeta:T0251:1:recite-005",
        front: "是諸法空相，不生不滅，不垢不淨；再背最後一對：",
        back: "不增不減。",
        hint: "增減。",
        sourceText: "舍利子，是諸法空相，不生不滅，不垢不淨，不增不減。",
        tags: ["T0251", "心經", "空相", "recitation"],
      },
      {
        id: "cbeta:T0251:1:recite-006",
        front: "是故空中先無五蘊：無色，……",
        back: "無受、想、行、識。",
        hint: "把色之外的四蘊接上。",
        sourceText: "是故空中無色，無受、想、行、識。",
        tags: ["T0251", "心經", "五蘊", "空中無", "recitation"],
      },
      {
        id: "cbeta:T0251:1:recite-007",
        front: "空中無六根：無……",
        back: "眼、耳、鼻、舌、身、意。",
        hint: "從身體感官到意根。",
        sourceText: "無眼、耳、鼻、舌、身、意。",
        tags: ["T0251", "心經", "六根", "recitation"],
      },
      {
        id: "cbeta:T0251:1:recite-008",
        front: "空中無六塵：無……",
        back: "色、聲、香、味、觸、法。",
        hint: "與六根相對的六境。",
        sourceText: "無色、聲、香、味、觸、法。",
        tags: ["T0251", "心經", "六塵", "recitation"],
      },
      {
        id: "cbeta:T0251:1:recite-009",
        front: "六根、六塵之後，十八界以哪一句攝略？",
        back: "無眼界，乃至無意識界。",
        hint: "從眼界略至意識界。",
        sourceText: "無眼界，乃至無意識界。",
        tags: ["T0251", "心經", "十八界", "recitation"],
      },
      {
        id: "cbeta:T0251:1:recite-010",
        front: "十二因緣的前段否定，從無明開始：",
        back: "無無明，亦無無明盡。",
        hint: "無明與無明盡都不可得。",
        sourceText: "無無明，亦無無明盡；乃至無老死，亦無老死盡。",
        tags: ["T0251", "心經", "十二因緣", "recitation"],
      },
      {
        id: "cbeta:T0251:1:recite-011",
        front: "十二因緣攝略到最後：乃至……",
        back: "無老死，亦無老死盡。",
        hint: "從無明略至老死。",
        sourceText: "無無明，亦無無明盡；乃至無老死，亦無老死盡。",
        tags: ["T0251", "心經", "十二因緣", "recitation"],
      },
      {
        id: "cbeta:T0251:1:recite-012",
        front: "四聖諦也空：無……",
        back: "苦、集、滅、道。",
        hint: "依次是苦諦、集諦、滅諦、道諦。",
        sourceText: "無苦、集、滅、道。",
        tags: ["T0251", "心經", "四聖諦", "recitation"],
      },
      {
        id: "cbeta:T0251:1:recite-013",
        front: "四諦之後，智與所得也空：",
        back: "無智亦無得，以無所得故。",
        hint: "這一句承接後面的菩提薩埵。",
        sourceText: "無苦、集、滅、道，無智亦無得，以無所得故。",
        tags: ["T0251", "心經", "無所得", "recitation"],
      },
      {
        id: "cbeta:T0251:1:recite-014",
        front: "菩提薩埵，依般若波羅蜜多故，首先如何？",
        back: "心無罣礙。",
        hint: "先是心中無礙。",
        sourceText: "菩提薩埵，依般若波羅蜜多故，心無罣礙。",
        tags: ["T0251", "心經", "菩薩行", "recitation"],
      },
      {
        id: "cbeta:T0251:1:recite-015",
        front: "心無罣礙；因無罣礙故，接著背：",
        back: "無有恐怖。",
        hint: "從無礙到無怖。",
        sourceText: "心無罣礙；無罣礙故，無有恐怖。",
        tags: ["T0251", "心經", "菩薩行", "recitation"],
      },
      {
        id: "cbeta:T0251:1:recite-016",
        front: "無有恐怖之後，背出離與果：",
        back: "遠離顛倒夢想，究竟涅槃。",
        hint: "遠離顛倒，究竟涅槃。",
        sourceText: "無有恐怖，遠離顛倒夢想，究竟涅槃。",
        tags: ["T0251", "心經", "涅槃", "recitation"],
      },
      {
        id: "cbeta:T0251:1:recite-017",
        front: "三世諸佛，依般若波羅蜜多故，得到什麼？",
        back: "得阿耨多羅三藐三菩提。",
        hint: "諸佛所證的無上正等正覺。",
        sourceText: "三世諸佛，依般若波羅蜜多故，得阿耨多羅三藐三菩提。",
        tags: ["T0251", "心經", "佛果", "recitation"],
      },
      {
        id: "cbeta:T0251:1:recite-018",
        front: "故知般若波羅蜜多，先背前兩個呪名：",
        back: "是大神呪，是大明呪。",
        hint: "大神、大明。",
        sourceText: "故知般若波羅蜜多，是大神呪，是大明呪，是無上呪，是無等等呪。",
        tags: ["T0251", "心經", "般若呪", "recitation"],
      },
      {
        id: "cbeta:T0251:1:recite-019",
        front: "般若波羅蜜多，後兩個呪名是：",
        back: "是無上呪，是無等等呪。",
        hint: "無上、無等等。",
        sourceText: "故知般若波羅蜜多，是大神呪，是大明呪，是無上呪，是無等等呪。",
        tags: ["T0251", "心經", "般若呪", "recitation"],
      },
      {
        id: "cbeta:T0251:1:recite-020",
        front: "四個呪名之後，背出功用與判定：",
        back: "能除一切苦，真實不虛。",
        hint: "除苦，且真實。",
        sourceText: "能除一切苦，真實不虛。",
        tags: ["T0251", "心經", "除苦", "recitation"],
      },
      {
        id: "cbeta:T0251:1:recite-021",
        front: "故說般若波羅蜜多呪，即說呪曰：前半句是……",
        back: "揭諦揭諦，波羅揭諦。",
        hint: "揭諦兩遍，然後波羅揭諦。",
        sourceText: "故說般若波羅蜜多呪，即說呪曰：揭諦揭諦，波羅揭諦，波羅僧揭諦，菩提薩婆訶。",
        tags: ["T0251", "心經", "真言", "recitation"],
      },
      {
        id: "cbeta:T0251:1:recite-022",
        front: "揭諦揭諦，波羅揭諦；真言後半句是……",
        back: "波羅僧揭諦，菩提薩婆訶。",
        hint: "波羅僧揭諦，接菩提薩婆訶。",
        sourceText: "揭諦揭諦，波羅揭諦，波羅僧揭諦，菩提薩婆訶。",
        tags: ["T0251", "心經", "真言", "recitation"],
      },
    ],
  },
];

export const FALIU_ANKI_DECK_MAP = Object.fromEntries(FALIU_ANKI_CARD_DECKS.map((deck) => [deck.contentId, deck]));
