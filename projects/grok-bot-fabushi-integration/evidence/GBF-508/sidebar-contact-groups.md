# GBF-508 — Sidebar contact grouping

## User-visible requirement

Fabushi Messenger should support Grok-style named sections in the left contact/chat rail, such as `运营部`, `测试部`, and any number of additional user-defined groups. Each section contains the contacts/Bots assigned to it and can be folded independently.

## Reference behavior audit

Reference: `bhrum/grok-bot-0.18-reconstructed`.

The reconstructed product models sidebar grouping as state plus projection, not as visual-only separators:

- `frontend/src/recovered/features/conversation/workspace/sidebar-sections-state.ts` owns persisted named sections, member assignment, rename/remove/move and folded state.
- `frontend/src/recovered/features/conversation/workspace/sidebar-section-projection.ts` projects pinned entries separately, named sections in order and a synthetic unassigned section.
- `frontend/src/production/sidebar-model.ts` keeps pinned ordering separate from ordinary sections.
- A peer belongs to at most one editable section; deleting a section leaves its peers available as unassigned rather than deleting them.

## Fabushi gap before GBF-508

`desktop/src/messaging-shell-v2.tsx` had a top-level `folders` navigation item, but the actual `chats` / `contacts` rail was a single flat `renderedPeers.map(...)` list. There was no durable named-section model, no contact-to-section assignment, no fold state and no section manager.

## Implementation

- `desktop/src/sidebar-contact-groups.tsx`
  - versioned account-scoped persistence (`fabushi.desktop.sidebar-contact-groups.v1`)
  - localStorage first-frame projection plus native `clientPersistence` durability mirror
  - account-session reset cleanup
  - normalization and duplicate-membership fencing
  - exclusive assignment to one editable group
  - synthetic `置顶` and `未分组` sections
  - stable section/member order
  - search temporarily expands matched collapsed groups and omits empty named groups
  - create/edit/delete/reorder manager UI
- `desktop/src/sidebar-contact-groups.css`
  - Grok/Fabushi dark section headings, counts, fold affordance and manager surface
- `desktop/src/messaging-shell-v2.tsx`
  - uses grouped projection only when at least one custom group exists, preserving the prior flat list otherwise
  - exposes `联系人分组` from the create menu in Chats/Contacts
  - preserves existing peer row behavior, pinned/unread/muted/avatar semantics and pagination
- `desktop/e2e/sidebar-contact-groups.spec.ts`
  - pinned / named / unassigned projection
  - exclusive movement and member removal on edit
  - normalization and reserved-id rejection
  - search/fold projection semantics

## Provenance / license decision

This is a clean-room behavior adaptation. No source text, styles or assets from the reconstructed Grok repository are copied into Fabushi. The reference repository is used only to identify observable product behavior and state semantics; all implementation code and CSS in GBF-508 are newly authored for Fabushi and integrated into the existing Mahayana/Fabushi Messenger architecture.

## Acceptance criteria

1. Users can create any number of named contact groups.
2. Users can assign and move contacts/Bots between groups; one peer cannot appear in two editable groups.
3. Group names appear as section headings in the left rail with contained peers below them.
4. Named groups can be folded/unfolded and reordered.
5. Pinned peers remain in a separate top section; unassigned peers remain visible.
6. Deleting a group does not delete contacts.
7. Group configuration survives restart and is cleared with account-session reset.
8. Search does not hide a matching peer merely because its group is folded.
9. Existing flat-list behavior is unchanged until a user creates the first custom group.
