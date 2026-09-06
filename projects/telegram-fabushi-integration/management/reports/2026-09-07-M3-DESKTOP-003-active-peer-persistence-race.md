# M3-DESKTOP-003 — active-peer persistence setup repair round

Status: `TESTING / IN_PROGRESS`

Exact trigger: canonical `71168adbeea65e998bb650ba3a4636911287636a`, Electron run `34058850412`, macOS job `101555620505`, diagnostics artifact `9996959351`.

The packaged returning-user test never reached its performance measurement because the seed conversation's durable `activePeerKey` was read before persistence completed. The repair adds only a bounded wait for `selfhosted:*` after the real peer click, reusing an existing test pattern in the same file. The `<1000ms` gate and P0-P9 diagnostic contract are unchanged.

Validation baseline is `ee8cd4b3a7b51b18497fd34164781f13e3ebaf31` or a later protected-main descendant. Required CI, protected merge, exact-main packaged retest and visual/trace/log evidence remain `PENDING`.
