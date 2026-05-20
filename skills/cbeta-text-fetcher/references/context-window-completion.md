# Context-window completion rule for 功德利益 extraction

This note supplements the `cbeta-text-fetcher` skill. It prevents a recurring extraction failure: selecting only the final sentence of a benefit passage while omitting the preceding comparison, condition, proof story, verse/prose cluster, or follow-up question-answer that makes the sentence complete.

## Root cause

The root cause is **not** that one specific example was missing from the rules. The root cause is choosing the wrong extraction unit.

A sentence that contains `功德`, `福德`, `利益`, `是故`, or another obvious benefit marker is often only the conclusion of a larger argument. The correct extraction unit is the smallest complete semantic unit, not the smallest sentence containing a benefit word.

Common failure causes:

1. **Marker anchoring**: anchoring on the visible benefit phrase and clipping only that sentence.
2. **Referent loss**: phrases such as `此菩薩`, `前菩薩`, `斯功德`, `是故`, `如是`, `以是因緣`, or `不受福德` point outside the sentence.
3. **Dialogue splitting**: a question-answer pair is treated as separate content even though the answer explains the benefit phrase.
4. **Comparison loss**: a comparative merit passage is clipped to the doctrinal conclusion, losing what is being compared.
5. **Output compression pressure**: sentence-only / 微信文章式 output is mistaken for one-source-sentence output. It should mean no audit notes, not truncated logic.
6. **Boundary loss**: prose, verse, XML blocks, or paragraph boundaries are treated as hard boundaries even when the logic crosses them.

## Hard rule

When a candidate 功德利益 sentence is found, do not stop at the sentence that contains the obvious benefit phrase. Expand upward and downward until the logical unit is complete.

This is mandatory for:

- comparative merit passages;
- doctrinal explanations;
- dialogue sequences;
- proof stories introduced by `云何得知`, `何以故`, `以是因緣`, or similar phrases;
- verse/prose clusters where the benefit is completed across line or paragraph boundaries;
- passages using `是故`, `以是因緣`, `何以故`, `云何得知`, `此菩薩`, `前菩薩`, `斯功德`, `如是`, `不受福德`, or similar referential phrases;
- any passage where the extracted sentence cannot stand alone without the prior condition, comparison, question, proof, or referent.

## Required reading check

Before finalizing a 功德利益 item:

1. Read at least one paragraph before and one paragraph after the candidate sentence.
2. Reconstruct the logic in one line: `if / because [condition or premise], therefore [benefit or superiority]`.
3. Ask whether that reconstruction needs an earlier condition, comparison, question, proof story, verse line, or referent. If yes, include that earlier text.
4. Ask whether a following question-answer or explanatory sentence completes the candidate. If yes, include it in the same output unit.
5. Run the standalone-unit test below.
6. Only split when each resulting item still contains a complete condition/action/result or a complete doctrinal claim.

## Standalone-unit test

Before output, test the item as if the reader has not seen the source text. The item is incomplete if the reader would ask:

- This benefit belongs to whom or to what practice?
- What is being compared?
- What does `此`, `是故`, `前`, `斯`, `如是`, or `不受` refer to?
- What question is this answer responding to?
- What condition must be fulfilled for this result?
- Is this conclusion supported by a prior proof story or following explanation?

If any question remains, expand the item until the question is answered.

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

## General prevention rule

Do not solve future omissions by only adding more examples. Every missed example should be diagnosed against the root causes above, then the extraction boundary rule should be strengthened so the fix generalizes to other scriptures and other structures.