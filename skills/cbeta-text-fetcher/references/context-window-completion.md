# Context-window completion rule for 功德利益 extraction

This note supplements the `cbeta-text-fetcher` skill. It prevents a recurring extraction failure: selecting only the final sentence of a benefit passage while omitting the preceding comparison, condition, or follow-up question-answer that makes the sentence complete.

## Hard rule

When a candidate 功德利益 sentence is found, do not stop at the sentence that contains the obvious benefit phrase. Expand upward and downward until the logical unit is complete.

This is mandatory for:

- comparative merit passages;
- doctrinal explanations;
- dialogue sequences;
- passages using `是故`, `以是因緣`, `何以故`, `云何得知`, `此菩薩`, `前菩薩`, `斯功德`, or similar referential phrases;
- any passage where the extracted sentence cannot stand alone without the prior condition, comparison, or question.

## Required reading check

Before finalizing a 功德利益 item:

1. Read at least one paragraph before and one paragraph after the candidate sentence.
2. Ask whether the candidate depends on an earlier condition, comparison, question, or referent. If yes, include that earlier text.
3. Ask whether a following question-answer explains the candidate. If yes, include the question and answer as the same output unit.
4. Only split when each resulting item still contains a complete condition/action/result or a complete doctrinal claim.

## Failure example to avoid

Do **not** extract only:

> 須菩提！菩薩所作福德，不應貪著，是故說不受福德。

This loses the comparative merit and the question-answer structure.

## Correct complete unit

> 須菩提！若菩薩以滿恒河沙等世界七寶布施；若復有人知一切法無我，得成於忍，此菩薩勝前菩薩所得功德。須菩提！以諸菩薩不受福德故。
>
> 須菩提白佛言：「世尊！云何菩薩不受福德？」
>
> 須菩提！菩薩所作福德，不應貪著，是故說不受福德。

In sentence-only / 微信文章式 output, preserve this as one complete item, lightly joined for readability, rather than truncating it to the last sentence.
