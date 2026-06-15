export interface FaliuAnkiCard {
  id: string;
  type?: "understanding" | "image" | "recitation";
  front: string;
  back: string;
  hint?: string;
  sourceText?: string;
  imagePrompt?: string;
  imageAlt?: string;
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
 * - front: question, cloze prompt, or visual cue.
 * - back: exact minimal answer.
 * - hint: optional short cue.
 * - sourceText: exact original sentence/paragraph for audit and source jump.
 * - imagePrompt/imageAlt: optional imagery prompt for image cards.
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
        type: "understanding",
        front: "《心經》的實修主軸可怎樣概括？",
        back: "依般若照見五蘊皆空。",
        hint: "先建立全經大意，再記細節。",
        sourceText: "觀自在菩薩，行深般若波羅蜜多時，照見五蘊皆空，度一切苦厄。",
        tags: ["T0251", "心經", "總綱", "理解"],
      },
      {
        id: "cbeta:T0251:1:understand-002",
        type: "understanding",
        front: "經中「照見五蘊皆空」直接對治什麼？",
        back: "一切苦厄。",
        hint: "觀空的作用。",
        sourceText: "照見五蘊皆空，度一切苦厄。",
        tags: ["T0251", "心經", "總綱", "苦厄"],
      },
      {
        id: "cbeta:T0251:1:understand-003",
        type: "understanding",
        front: "《心經》中被觀為「皆空」的身心總類是什麼？",
        back: "五蘊。",
        hint: "色、受、想、行、識的總名。",
        sourceText: "照見五蘊皆空。",
        tags: ["T0251", "心經", "五蘊", "基礎"],
      },
      {
        id: "cbeta:T0251:1:understand-004",
        type: "understanding",
        front: "「色不異空，空不異色」避免把色與空看成什麼？",
        back: "彼此分離的兩物。",
        hint: "先記「不異」。",
        sourceText: "色不異空，空不異色。",
        tags: ["T0251", "心經", "色空", "理解"],
      },
      {
        id: "cbeta:T0251:1:understand-005",
        type: "understanding",
        front: "「色即是空，空即是色」強調色與空的哪種關係？",
        back: "色空相即。",
        hint: "再記「即是」。",
        sourceText: "色即是空，空即是色。",
        tags: ["T0251", "心經", "色空", "理解"],
      },
      {
        id: "cbeta:T0251:1:understand-006",
        type: "understanding",
        front: "除色蘊外，經文說哪四蘊也「亦復如是」？",
        back: "受、想、行、識。",
        hint: "這是短枚舉，保留為一張。",
        sourceText: "受、想、行、識，亦復如是。",
        tags: ["T0251", "心經", "五蘊", "枚舉"],
      },
      {
        id: "cbeta:T0251:1:understand-007",
        type: "understanding",
        front: "「是諸法空相」先破哪一對相？",
        back: "生／滅。",
        hint: "三對相之一。",
        sourceText: "是諸法空相，不生不滅，不垢不淨，不增不減。",
        tags: ["T0251", "心經", "空相", "最小信息"],
      },
      {
        id: "cbeta:T0251:1:understand-008",
        type: "understanding",
        front: "「是諸法空相」第二對破哪一對相？",
        back: "垢／淨。",
        hint: "三對相之一。",
        sourceText: "是諸法空相，不生不滅，不垢不淨，不增不減。",
        tags: ["T0251", "心經", "空相", "最小信息"],
      },
      {
        id: "cbeta:T0251:1:understand-009",
        type: "understanding",
        front: "「是諸法空相」最後破哪一對相？",
        back: "增／減。",
        hint: "三對相之一。",
        sourceText: "是諸法空相，不生不滅，不垢不淨，不增不減。",
        tags: ["T0251", "心經", "空相", "最小信息"],
      },
      {
        id: "cbeta:T0251:1:understand-010",
        type: "understanding",
        front: "「空中無色，無受、想、行、識」否定的是哪一組分類？",
        back: "五蘊。",
        hint: "不要背整串，先認出分類。",
        sourceText: "是故空中無色，無受、想、行、識。",
        tags: ["T0251", "心經", "五蘊", "分類"],
      },
      {
        id: "cbeta:T0251:1:understand-011",
        type: "understanding",
        front: "「無眼、耳、鼻、舌、身、意」否定的是哪一組？",
        back: "六根。",
        hint: "主觀能取的六根。",
        sourceText: "無眼、耳、鼻、舌、身、意。",
        tags: ["T0251", "心經", "六根", "分類"],
      },
      {
        id: "cbeta:T0251:1:understand-012",
        type: "understanding",
        front: "「無色、聲、香、味、觸、法」否定的是哪一組？",
        back: "六塵／六境。",
        hint: "六根所對的六境。",
        sourceText: "無色、聲、香、味、觸、法。",
        tags: ["T0251", "心經", "六塵", "分類"],
      },
      {
        id: "cbeta:T0251:1:understand-013",
        type: "understanding",
        front: "「無眼界，乃至無意識界」攝略哪一法門？",
        back: "十八界。",
        hint: "從眼界略至意識界。",
        sourceText: "無眼界，乃至無意識界。",
        tags: ["T0251", "心經", "十八界", "分類"],
      },
      {
        id: "cbeta:T0251:1:understand-014",
        type: "understanding",
        front: "十二因緣的否定，經文從哪一支說起？",
        back: "無明。",
        hint: "只問起點，避免長枚舉。",
        sourceText: "無無明，亦無無明盡；乃至無老死，亦無老死盡。",
        tags: ["T0251", "心經", "十二因緣", "最小信息"],
      },
      {
        id: "cbeta:T0251:1:understand-015",
        type: "understanding",
        front: "十二因緣的否定，經文攝略到哪一支？",
        back: "老死。",
        hint: "只問終點，避免長枚舉。",
        sourceText: "無無明，亦無無明盡；乃至無老死，亦無老死盡。",
        tags: ["T0251", "心經", "十二因緣", "最小信息"],
      },
      {
        id: "cbeta:T0251:1:understand-016",
        type: "understanding",
        front: "「無苦、集、滅、道」否定的是哪一組佛法分類？",
        back: "四聖諦。",
        hint: "把四項歸成一個已知分類。",
        sourceText: "無苦、集、滅、道。",
        tags: ["T0251", "心經", "四聖諦", "分類"],
      },
      {
        id: "cbeta:T0251:1:understand-017",
        type: "understanding",
        front: "「無智亦無得」的理由是什麼？",
        back: "以無所得故。",
        hint: "經文直接給出原因。",
        sourceText: "無智亦無得，以無所得故。",
        tags: ["T0251", "心經", "無所得", "因果"],
      },
      {
        id: "cbeta:T0251:1:understand-018",
        type: "understanding",
        front: "菩提薩埵心無罣礙，是因為依何法？",
        back: "般若波羅蜜多。",
        hint: "依般若，所以無礙。",
        sourceText: "菩提薩埵，依般若波羅蜜多故，心無罣礙。",
        tags: ["T0251", "心經", "菩薩行", "因果"],
      },
      {
        id: "cbeta:T0251:1:understand-019",
        type: "understanding",
        front: "心無罣礙後，經文首先說消除了哪種心理狀態？",
        back: "恐怖。",
        hint: "無礙故無怖。",
        sourceText: "心無罣礙；無罣礙故，無有恐怖。",
        tags: ["T0251", "心經", "菩薩行", "心理"],
      },
      {
        id: "cbeta:T0251:1:understand-020",
        type: "understanding",
        front: "菩薩遠離顛倒夢想後，趣向什麼果？",
        back: "究竟涅槃。",
        hint: "離倒夢想，至涅槃。",
        sourceText: "遠離顛倒夢想，究竟涅槃。",
        tags: ["T0251", "心經", "涅槃", "因果"],
      },
      {
        id: "cbeta:T0251:1:understand-021",
        type: "understanding",
        front: "三世諸佛依般若波羅蜜多，證得什麼？",
        back: "阿耨多羅三藐三菩提。",
        hint: "諸佛所證的無上正等正覺。",
        sourceText: "三世諸佛，依般若波羅蜜多故，得阿耨多羅三藐三菩提。",
        tags: ["T0251", "心經", "佛果", "因果"],
      },
      {
        id: "cbeta:T0251:1:understand-022",
        type: "understanding",
        front: "經文稱般若波羅蜜多為「大神呪、大明呪……」，主要是在讚歎哪一面向？",
        back: "般若的不可思議力用。",
        hint: "不是單純記名號，而是抓功能定位。",
        sourceText: "故知般若波羅蜜多，是大神呪，是大明呪，是無上呪，是無等等呪。",
        tags: ["T0251", "心經", "般若呪", "理解"],
      },
      {
        id: "cbeta:T0251:1:understand-023",
        type: "understanding",
        front: "般若波羅蜜多呪的作用是什麼？",
        back: "能除一切苦。",
        hint: "問功能，不背整段。",
        sourceText: "能除一切苦。",
        tags: ["T0251", "心經", "般若呪", "作用"],
      },
      {
        id: "cbeta:T0251:1:understand-024",
        type: "understanding",
        front: "經文如何判定般若波羅蜜多呪的可靠性？",
        back: "真實不虛。",
        hint: "問判定語。",
        sourceText: "真實不虛。",
        tags: ["T0251", "心經", "般若呪", "判定"],
      },
      {
        id: "cbeta:T0251:1:image-001",
        type: "image",
        front: "圖像卡：五個透明包袱在月光中變空，對應《心經》的哪個核心觀照？",
        back: "照見五蘊皆空。",
        hint: "圖像只提示一個核心觀照，不要求背整句。",
        sourceText: "照見五蘊皆空，度一切苦厄。",
        imagePrompt: "五個半透明包袱標成色、受、想、行、識，在清澈月光中逐漸透明，遠處苦厄雲散開。",
        imageAlt: "五蘊透明化，苦雲散開",
        tags: ["T0251", "心經", "圖像卡", "五蘊", "理解"],
      },
      {
        id: "cbeta:T0251:1:image-002",
        type: "image",
        front: "圖像卡：波浪與海水不可分，幫助記住色與空的什麼關係？",
        back: "色空相即。",
        hint: "用波與水降低「色/空」干擾。",
        sourceText: "色不異空，空不異色；色即是空，空即是色。",
        imagePrompt: "一個波浪由海水升起，波形清楚但與海水無法分開，旁邊不要加入多餘符號。",
        imageAlt: "波浪與海水不可分",
        tags: ["T0251", "心經", "圖像卡", "色空", "理解"],
      },
      {
        id: "cbeta:T0251:1:image-003",
        type: "image",
        front: "圖像卡：生滅、垢淨、增減三組標籤都淡出，對應「空相」破哪三對相？",
        back: "生／滅、垢／淨、增／減。",
        hint: "三對相一起成組，但每對清楚分隔。",
        sourceText: "是諸法空相，不生不滅，不垢不淨，不增不減。",
        imagePrompt: "三扇門分別寫生滅、垢淨、增減，字跡在空明背景中淡出。",
        imageAlt: "三對二元相淡出",
        tags: ["T0251", "心經", "圖像卡", "空相", "對照"],
      },
      {
        id: "cbeta:T0251:1:image-004",
        type: "image",
        front: "圖像卡：六扇感官門標著眼耳鼻舌身意，這張圖對應哪一組分類？",
        back: "六根。",
        hint: "只問分類，不要求列整串。",
        sourceText: "無眼、耳、鼻、舌、身、意。",
        imagePrompt: "六扇小門依序標示眼、耳、鼻、舌、身、意，門都敞開但內部空明。",
        imageAlt: "六扇感官門",
        tags: ["T0251", "心經", "圖像卡", "六根", "分類"],
      },
      {
        id: "cbeta:T0251:1:image-005",
        type: "image",
        front: "圖像卡：六個外境泡泡標著色聲香味觸法，這張圖對應哪一組分類？",
        back: "六塵／六境。",
        hint: "與六根圖分開，避免混淆。",
        sourceText: "無色、聲、香、味、觸、法。",
        imagePrompt: "六個泡泡在六扇門外，分別標色、聲、香、味、觸、法，泡泡清亮而短暫。",
        imageAlt: "六個外境泡泡",
        tags: ["T0251", "心經", "圖像卡", "六塵", "分類"],
      },
      {
        id: "cbeta:T0251:1:image-006",
        type: "image",
        front: "圖像卡：一雙空手沒有抓到任何東西，對應《心經》的哪個要點？",
        back: "無所得。",
        hint: "以簡單畫面提示核心詞。",
        sourceText: "無智亦無得，以無所得故。",
        imagePrompt: "一雙放鬆張開的空手，掌心明亮，沒有任何物件可抓取。",
        imageAlt: "張開的空手",
        tags: ["T0251", "心經", "圖像卡", "無所得", "理解"],
      },
      {
        id: "cbeta:T0251:1:image-007",
        type: "image",
        front: "圖像卡：心上沒有繩結和網，恐怖影子退去，對應菩薩行的哪個結果？",
        back: "心無罣礙，無有恐怖。",
        hint: "圖像把無礙與無怖連成因果。",
        sourceText: "菩提薩埵，依般若波羅蜜多故，心無罣礙；無罣礙故，無有恐怖。",
        imagePrompt: "一顆心前方的繩結鬆開，黑色恐怖影子向後退去，整體安穩明亮。",
        imageAlt: "心無繩結，恐怖退散",
        tags: ["T0251", "心經", "圖像卡", "菩薩行", "因果"],
      },
      {
        id: "cbeta:T0251:1:image-008",
        type: "image",
        front: "圖像卡：咒語像渡橋，把苦雲帶到彼岸消散，對應般若呪的哪個作用？",
        back: "能除一切苦。",
        hint: "問作用，不背整段咒名。",
        sourceText: "能除一切苦，真實不虛。",
        imagePrompt: "金色咒語化成一座簡潔渡橋，灰色苦雲過橋後消散，畫面不加入人物崇拜元素。",
        imageAlt: "咒語渡橋除苦",
        tags: ["T0251", "心經", "圖像卡", "般若呪", "作用"],
      },
    ],
  },
];

export const FALIU_ANKI_DECK_MAP = Object.fromEntries(FALIU_ANKI_CARD_DECKS.map((deck) => [deck.contentId, deck]));
