# 08 RustDesk 能力映射

| Upstream area | RustDesk evidence | Fabushi target | State |
|---|---|---|---|
| Registration/presence | RegisterPeer/RegisterPk, keep-alive | Account-bound device inventory | RDF-001 implementing |
| Direct/relay | PunchHole, RequestRelay, hbbs/hbbr | Fabushi session broker/provider | planned |
| Permissions | ControlPermissions, PermissionInfo | Fabushi consent/policy grants | planned |
| Desktop/video | VideoFrame, display info/switch | Existing WebRTC frame path + future provider | partial existing |
| Input | MouseEvent, KeyEvent, pointer device events | Existing ComputerAction + provider adapter | partial existing |
| Clipboard | Clipboard/MultiClipboards | Permissioned clipboard channel | planned |
| Files | FileAction/FileResponse | Resumable transfer provider | planned |
| Audio | AudioFormat/AudioFrame | Negotiated audio channel | planned |
| Sessions/recovery | Login/session fields, close/restart/control messages | Expiring sessions, reconnect, revoke/audit | partial existing |

“Partial existing” is not RustDesk protocol interoperability.
