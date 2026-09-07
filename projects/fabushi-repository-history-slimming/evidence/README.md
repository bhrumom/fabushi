# Evidence index

本目录记录可重放证据，不把聊天结论当作证据。

待归档：

- 项目治理 PR、merge queue、canonical-main readback。
- 迁移前后 heads/tags OID 清单与保护规则快照。
- 过滤规则、关键路径差异、fsck/connectivity 输出。
- 推送结果、规则恢复结果、pack/LFS/object 体积对照。
- 若 GitHub Actions 运行治理检查，记录 workflow/run/job/check URL；本轮因当前树移除运行时输入，必须等待 packaged/quality gate 结果，不能以本机检查替代。

| Evidence | Location / identifier | Result |
| --- | --- | --- |
| Project registration | PR [#2482](https://github.com/bhrumom/fabushi/pull/2482) | merged |
| Canonical rewritten main | `bc4fb3032a03d6600d733ce28295256d77cca9d4` | remote readback passed |
| Original refs | `/Users/gloriachan/Documents/fabushi-rhs-archive-20260907/refs-before-7f31e977.txt` | SHA-256 `939f903334e216be9c3ba173e65cc7870a4d5c11fbae66606454374211deeecd` |
| Rewind mirror | `/Users/gloriachan/Documents/fabushi-rhs-archive-20260907/remote-source-before-rewrite.git` | fsck passed |
| Product/legal materials archive | `/Users/gloriachan/Documents/fabushi-rhs-archive-20260907/materials-7f31e977.tar.gz` | SHA-256 `a743786000d237b62c101a4edc0f526d0c5238ed6e5bc7643fad1c24ce88e667` |
| Candidate integrity | `candidate-slim` | 75,238 objects; garbage 0; fsck passed |
| Remote heads/tags | `git ls-remote` | 1572 heads; 401 immutable-release tags |
| Electron quality gate | [run 34085259212](https://github.com/bhrumom/fabushi/actions/runs/34085259212) | in progress |
| Native mobile quality gate | [run 34085259258](https://github.com/bhrumom/fabushi/actions/runs/34085259258) | in progress |

The original dirty worktree and untracked user files were not included in the rewrite source and were not modified.
