# M5-CONTACTS-001 — Contacts and groups closure

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M5-CONTACTS-001`
- **Stage**: `M5 联系人 + 群组`
- **WBS**: `M5.T01`–`M5.T08`
- **Status**: `IN_PROGRESS`
- **Started**: `2026-08-23`
- **Depends on**: M4 / PR #2037

## Reused foundation

- `mahayana-social` imports platform contacts into the shared `Actor` model; M5 does not create a second contacts database.
- `SearchIndex` already indexes actors, groups, channels and messages.
- `CommunityState` already models owner/admin/member/restricted/left/banned, granular admin rights, member restrictions, invites and join requests.
- M3 actor-scoped read cursors already apply to group conversations.

## Product gaps being closed

1. Search existed only as an in-process index, not as a Fabushi Messaging protocol request/response.
2. Community administration used a coarse any-admin-right authorization check instead of operation-specific rights.
3. Group sends did not apply `MemberStatus` / `MemberRestrictions` after conversation-level permissions.
4. M5 lacked an acceptance contract covering contacts search, group creation/member management, role permissions, invite rights and group unread/read recovery.

## Acceptance criteria

- contacts and user search are served from the same Actor model and exclude bot-only results in contact scope;
- group search uses the same search protocol and conversation state;
- owner has full administrative authority;
- administrators are authorized only for the exact granted right;
- regular members cannot manage membership/invites/topics;
- restricted/banned/left members cannot bypass send restrictions;
- invite creation/revocation and join approval require `inviteMembers` or owner;
- promoting/demoting administrators requires `addAdmins` or owner, and only an owner may create/replace an owner;
- group unread remains actor-scoped and clears only for the reading actor;
- all contracts pass in the permanent Messaging Product Gate before protected merge.

## Evidence targets

- protocol/service: `native/mahayana-messaging/src/{protocol.rs,service.rs}`
- authorization: `native/mahayana-messaging/src/engine.rs`
- acceptance: `native/mahayana-messaging/tests/m5_contacts_groups_contract.rs`
- upstream contact projection: `third_party/mahayana/mahayana-rs/mahayana-social`

## Completion rule

Keep `IN_PROGRESS` until M4 lands, this branch is retargeted to `main`, final-head CI passes, protected merge completes, canonical `main` is re-read, and M5 WBS/evidence records are closed.
