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
        id: "cbeta:T0251:1:sample-001",
        front: "請背誦《心經》開頭：觀自在菩薩，行深般若波羅蜜多時，照見……",
        back: "五蘊皆空，度一切苦厄。",
        hint: "接在「照見」之後。",
        sourceText: "觀自在菩薩，行深般若波羅蜜多時，照見五蘊皆空，度一切苦厄。",
        tags: ["T0251", "心經", "般若"],
      },
    ],
  },
];

export const FALIU_ANKI_DECK_MAP = Object.fromEntries(FALIU_ANKI_CARD_DECKS.map((deck) => [deck.contentId, deck]));
