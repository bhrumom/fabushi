# Evidence index

本目录记录可重放证据，不把聊天结论当作证据。

证据已归档；以下记录可重放本轮结果：

- 项目治理 PR、merge queue、canonical-main readback。
- 迁移前后 heads/tags OID 清单与保护规则快照。
- 过滤规则、关键路径差异、fsck/connectivity 输出。
- 推送结果、规则恢复结果、pack/LFS/object 体积对照。
- GitHub Actions 的 packaged/quality gate 结果和诊断产物；本机未执行构建、打包或测试。

| Evidence | Location / identifier | Result |
| --- | --- | --- |
| Project registration | PR [#2482](https://github.com/bhrumom/fabushi/pull/2482) | merged |
| Canonical rewritten main | `bc4fb3032a03d6600d733ce28295256d77cca9d4` | remote readback passed |
| Original refs | `/Users/gloriachan/Documents/fabushi-rhs-archive-20260907/refs-before-7f31e977.txt` | SHA-256 `939f903334e216be9c3ba173e65cc7870a4d5c11fbae66606454374211deeecd` |
| Rewind mirror | `/Users/gloriachan/Documents/fabushi-rhs-archive-20260907/remote-source-before-rewrite.git` | fsck passed |
| Product/legal materials archive | `/Users/gloriachan/Documents/fabushi-rhs-archive-20260907/materials-7f31e977.tar.gz` | SHA-256 `a743786000d237b62c101a4edc0f526d0c5238ed6e5bc7643fad1c24ce88e667` |
| Candidate integrity | `candidate-slim` | 75,238 objects; garbage 0; fsck passed |
| Remote heads/tags | `git ls-remote` | 1572 heads; 401 immutable-release tags |
| Electron quality gate | [run 34085259212](https://github.com/bhrumom/fabushi/actions/runs/34085259212)；macOS [job 101639923085](https://github.com/bhrumom/fabushi/actions/runs/34085259212/job/101639923085) | passed on rerun; first-attempt failure diagnostics retained |
| Electron packaged evidence | `fabushi-electron-mac` / `fabushi-electron-mac-e2e-diagnostics` artifacts `10006720572` / `10006708101`; first-attempt diagnostics `10006079668` | retained, unexpired at verification |
| Native mobile quality gate | [run 34085259258](https://github.com/bhrumom/fabushi/actions/runs/34085259258) | passed; Android reports and iOS xcresult retained |
| Final record | PR [#2483](https://github.com/bhrumom/fabushi/pull/2483), merged `6afd3475744d284d797140a2393d3a3fc551c211`; current main `7ea5055b1e0d7ee078d0d21321b5884fa93bead2` | canonical-main readback passed |

The original dirty worktree and untracked user files were not included in the rewrite source and were not modified.
