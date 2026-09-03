# 2026-09-03 — 修复 Mac 测试版并持续实机验证直到无已知问题

用户在 `1.2.14-test.152` 实机评审后明确要求：修复已经发现的问题，然后继续在 Mac 上使用真实测试账号和 `fabushi test` 连接器验证，持续推进直到本轮已知问题全部关闭，不以只写代码、只出包或只通过静态检查作为完成。

## 本轮必须关闭的已知问题

1. macOS test release 不能再是 ad-hoc 签名；测试版必须使用与正式版一致的 Fabushi Developer ID / canonical code identifier，但仍可跳过 notarization 和长 App E2E 以保持快速发布。
2. `mahayana-app-host` 不能再因 test artifact 的签名身份变化触发已有 `com.ombhrum.fabushi.auth.v2` Keychain 密钥访问阻塞；Host `feature.*` 请求必须恢复正常。
3. 设置中的退出登录必须从 `退出中…` 正常完成，并能进入真实登录入口。
4. 使用受保护测试账号完成真实登录，再验证重启后的会话恢复和显式退出。
5. Messenger 真实发送必须获得正常 Mahayana 回复；不得继续以 `feature.execute` 两分钟超时结束。
6. `fabushi test` ChatGPT connector 必须恢复账号连接并能进行设备发现；若根因在远端 MCP/OAuth，修复对应服务/流程，不把 400 当作客户端成功。
7. Mini Apps 市场需要区分真实空 catalog 与客户端/服务故障，并恢复可验证的线上市场数据或明确的可操作错误状态。
8. Mahayana 同一 Bot 的 Messenger/list/header/Workbench 必须解析到相同 canonical Bot identity。
9. 实机空闲/近空闲 CPU 异常高必须继续定位并降到合理范围；至少不能长期由无任务的 avatar/render loop 维持双位数 GPU + Renderer CPU。
10. 修复后重新发布 **仅 macOS test**，安装到目标 Mac，与正式版隔离，完成 logout -> test login -> connector/device -> Agent -> Mini App -> restart -> idle-energy 回归并记录客观证据。

## 约束

- 本机禁止构建/打包/完整 E2E；重型验证使用 GitHub Actions。
- 测试版仍不自动运行长 App-driving E2E；先用真实 Mac 校准，随后才更新 formal gate。
- 不通过“始终允许”给 ad-hoc/错误签名 Host 永久 Keychain 权限来绕过问题。
- 不自动构建 Windows/Linux/Android/iOS。
- 账号密码、token、证书、Keychain 密码不得进入 Git、日志或项目记录。

## Open-source-first 参考

- `electron-userland/electron-builder` 官方 code-signing/GitHub Actions 实现：签名凭证应通过 CI secret 注入；缺少 CSC signing identity 时默认可能静默跳过签名，`forceCodeSigning` 可将其变成失败；macOS Developer ID 签名与 notarization 是可分离阶段。
- 本轮采用现有 electron-builder 管线和仓库已有 Developer ID 导入逻辑，不引入第二套打包器；test lane 只复用签名阶段，仍跳过 notarization 和长 E2E。

## 完成定义

只有新 Mac test artifact 在目标 Mac 上完成上述真实旅程、没有剩余本轮已知 blocker，且项目记录、commit/PR/CI/release/实机证据全部更新后，本轮才可报告完成。
