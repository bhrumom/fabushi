# ADR-0016 — Userscript task attachments use browser-local Blob storage and ChatGPT native upload

- Status: Proposed
- Date: 2026-09-13
- Project: \`FAB-P0001 / TFI\`
- Related task: \`TFI-USERSCRIPT-RECOVERY-007\`

## Context

The independent ChatGPT userscript workbench currently persists task goals as text. The new requirement is to accept images, videos and other files as task inputs. File bytes cannot safely or reliably be put into the existing localStorage task JSON, and sending a text-only prompt after an unconfirmed upload would silently change the user's requested task.

ChatGPT's public DOM has no stable documented upload API for this userscript. The page does expose its native file picker/composer, and mature community work around \`chatgpt.js\` demonstrates a DataTransfer/ClipboardEvent compatibility path. The task must preserve the existing single-file userscript, local-first state, no-token boundary and fail-closed send semantics.

## Decision

1. The workbench uses a multiple file input for explicit user selection. It accepts arbitrary browser-selectable files rather than maintaining a brittle MIME allowlist.
2. Task JSON stores only attachment metadata and stable ids. The selected File/Blob is stored in IndexedDB under the ChatGPT origin and is loaded only immediately before dispatch.
3. Dispatch first targets a ChatGPT \`input[type=file]\` in the current composer. If no suitable native input is available, it tries a ClipboardEvent/DataTransfer paste to the composer.
4. The script waits for each selected filename or a bounded, visible attachment surface in the current composer to confirm upload. Missing/failed/timeout uploads keep the task in uploading/blocked recovery and never click Send with text alone.
5. Continuous-task rounds and safe abnormal retries reuse the attachment references; task deletion removes the related IndexedDB records. Clearing site data is documented as a local-data loss boundary.

## Alternatives considered

- Embed file bytes in localStorage or the prompt: rejected because of storage quota, memory growth, privacy leakage into logs/prompts and loss of binary semantics.
- Call undocumented ChatGPT upload HTTP endpoints: rejected because it would require private protocol/session handling and would bypass the page's own permission/quota/security checks.
- Adopt \`TETRA326/ChatGPT-File-Upload\`: rejected because it is GPL-3.0, raw-text-only, and inserts content into the text bar rather than preserving image/video/file attachments.
- Add \`@kudoai/chatgpt.js\` as a runtime dependency: rejected because the script is intentionally standalone and the relevant upload behavior is a community DOM technique, not a stable public API. Its editor/readiness abstractions remain architectural reference only.

## Consequences

Positive:

- Images, videos and arbitrary files remain real attachments visible to ChatGPT.
- Task recovery does not duplicate file contents across localStorage and prompt history.
- The fail-closed confirmation prevents silent degradation to a text-only task.

Costs:

- ChatGPT DOM changes can require selector updates.
- IndexedDB is local to the browser profile and can be cleared independently.
- Large files and account limits remain page/platform constraints; live tests need safe samples and explicit user awareness of transmission.

## Provenance

- [KudoAI/chatgpt.js](https://github.com/KudoAI/chatgpt.js) — MIT; editor/readiness API reference.
- [KudoAI/chatgpt.js discussion #347](https://github.com/KudoAI/chatgpt.js/discussions/347) — community DataTransfer/ClipboardEvent file-to-composer technique; archived repository, not copied.
- [TETRA326/ChatGPT-File-Upload](https://github.com/TETRA326/ChatGPT-File-Upload) — GPL-3.0 raw-text-only extension; rejected.

