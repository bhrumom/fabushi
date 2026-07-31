# 安全模型：大乘小程序市场

## 1. 安全目标

系统必须保证：

- 用户安装的是自己选择的插件和版本；
- 安装包来自已认证发布者和获批准发布流程；
- 发布后内容不能被静默替换；
- 市场、镜像、网络或插件服务被部分攻破时，客户端能检测异常；
- 单个插件不能获得其他插件的 Secret、数据或写权限；
- 权限扩大必须被用户看见；
- 被撤销、封禁或过期的版本不能继续作为安全更新分发；
- 密钥和凭证泄露的影响范围尽可能小。

## 2. 威胁主体

考虑：

- 恶意发布者；
- 被接管的发布者 GitHub 账号；
- 泄露的长期 Token；
- 被修改的 GitHub Actions workflow；
- 被攻破的插件 Cloudflare 服务；
- 被攻破或错误配置的市场 API；
- 网络中间人和恶意重定向；
- 旧元数据重放、冻结、回退和混搭；
- 压缩炸弹、路径穿越、链接逃逸和超大包；
- 权限声明与包内实际能力不一致；
- 插件间 Secret、数据库和写权限串用；
- 恶意管理员或错误审核操作。

## 3. 信任根

CLI 必须内置或通过受保护升级获得市场根公钥。根信任负责授权在线元数据签名密钥，而不是直接承担每次自动发布。

最低结构：

```text
root key（离线或高保护）
  └── 授权 online targets key
        └── 签署版本、撤销和安全状态元数据
```

要求：

- 公钥有稳定 key ID；
- 支持 `active / retiring / revoked`；
- 根和在线密钥用途分离；
- 在线密钥泄露时可以轮换和撤销；
- CLI 不只依赖 TLS 或 DNS 作为最终信任。

## 4. OIDC 可信发布

GitHub Actions OIDC 用于证明“哪个仓库、哪个 workflow、哪个 commit 正在发布哪个插件版本”。

必须验证：

- `iss` 是允许的 GitHub issuer；
- `aud` 是大乘发布服务；
- repository 与插件配置一致；
- workflow 文件和 ref 一致；
- commit SHA 与 publish intent 一致；
- environment 和分支/标签策略满足发布要求；
- token 未过期；
- nonce 未使用；
- plugin ID 属于该发布者；
- stage token 不能执行 production release。

交换得到的发布 token：

- 最长只存活数分钟；
- 只允许一个 plugin ID 和 version；
- 只允许 stage 或 release 中的一种；
- 使用后记录 jti 摘要；
- 不允许重放；
- 不写入日志。

生产发布流程不能把测试账号登录或长期写 Token 作为唯一认证方式。

## 5. Provenance

来源证明至少绑定：

- 源码仓库；
- commit SHA；
- workflow 文件和 ref；
- Actions run ID；
- 构建者/runner 身份；
- 构件 SHA-256；
- 部署 URL 和 Cloudflare version ID；
- 生成时间。

provenance 证明来源，不证明代码无恶意，因此仍需审核、扫描和权限控制。

市场必须验证 provenance 与 OIDC claims、提交的包哈希和实际 Actions run 一致。

## 6. 不可变发布

正式包 URL 必须包含 version 和内容哈希。服务端和市场共同保证：

- 同一 version 不能重新提交；
- 同一路径不能返回不同内容；
- URL 中 SHA 与包 SHA 一致；
- 正式包使用不可变缓存语义；
- `latest` 只作为指针；
- 撤销不删除历史内容和审计记录；
- 回滚只切换生产 deployment，不覆盖旧包。

## 7. 签名元数据

被签名字段至少包括：

- protocol/schema version；
- metadata version；
- plugin ID 和 version；
- package URL、SHA、size、content type；
- manifest/provenance URL；
- permissions；
- source identity；
- review tier 和安全状态；
- published/expiry time；
- revocation/replacement 信息。

签名采用确定性规范化编码。客户端必须先验证签名，再信任下载 URL 和哈希。

## 8. TUF 核心原则

本任务采用 TUF 思想而非只做 SHA：

- `root`：可信公钥和轮换；
- `targets`：插件包哈希、大小和自定义权限/来源元数据；
- `snapshot` 思想：元数据版本一致性，防混搭；
- `timestamp` 思想：过期时间和最新状态，防冻结；
- consistent snapshot：可唯一寻址的版本+哈希路径；
- anti-rollback：拒绝低于本地最高已知安全版本；
- key compromise containment：在线密钥权限有限，可撤销和轮换。

数据格式应允许未来升级为完整 TUF，而不要求本轮一次实现全部委托角色。

## 9. 域名和网络

CLI 和市场只接受：

- HTTPS；
- 无用户名和密码；
- 无 localhost、私网或 loopback；
- 托管模式下由平台登记的 Cloudflare hostname；
- 自托管模式下已完成所有权验证的 Cloudflare hostname；
- 有限、可验证的重定向链；
- 最终地址仍属于获批 hostname 和不可变路径。

DNS 和 TLS 成功不能替代市场签名。

## 10. 下载限制

- 在下载前检查声明大小上限；
- 流式下载仍执行硬上限，不能只信 Content-Length；
- 限制连接、重定向和总超时；
- 验证内容类型和文件头；
- 下载到隔离临时目录；
- 完成大小和 SHA 验证前不向安装器暴露文件；
- 失败后清理临时数据。

## 11. 解包安全

必须拒绝：

- 绝对路径；
- `..` 路径穿越；
- 符号链接或硬链接逃逸；
- 设备文件；
- 超大文件数量；
- 超大解压后体积；
- 重复路径和大小写冲突；
- 覆盖 CLI、其他插件或用户任意文件；
- manifest 外的可执行入口。

安装在 staging 目录验证完毕后原子切换 `current` 指针。

## 12. 权限和运行隔离

默认拒绝未声明能力。权限包括：

- 网络域名；
- 文件系统范围与读写级别；
- Secret 名称；
- 系统命令；
- MCP tools；
- UI surfaces。

规则：

- 市场元数据与包内 manifest 必须一致；
- 权限扩大需要重新确认；
- 插件不能读取别的插件 Secret；
- 插件的数据库、KV、Durable Object 和日志绑定按插件隔离；
- 不因 official 身份自动授予无限权限；
- 高风险权限触发更严格审核和运行沙箱。

## 13. 审核与撤销

自动审核无法替代人工审核。系统必须支持：

- pending/rejected/approved；
- community/verified/official；
- 单版本 revoked；
- 插件整体 blocked；
- replacement version；
- 安全公告；
- 已安装客户端状态同步。

被撤销版本不能新安装或升级。已安装用户应看到原因和安全替代版本。

## 14. 审计

所有敏感操作写入追加式审计日志：

- 命名空间和插件身份；
- publish intent；
- OIDC 交换结果；
- 构建和扫描；
- Cloudflare version/deployment；
- 版本提交和签名；
- 审核、提升、回滚、撤销和封禁；
- 密钥轮换；
- 客户端安装失败的匿名摘要。

日志禁止包含：

- JWT 原文；
- Cloudflare Token；
- 市场短期 token；
- 用户 Secret；
- 安装包正文。

## 15. 强制攻击测试

必须证明系统拒绝：

- OIDC issuer/audience/repository/workflow/commit 不匹配；
- nonce 重放；
- 同版本覆盖；
- 可变包 URL；
- 非批准域名和异常重定向；
- 包大小或 SHA 篡改；
- 签名字段篡改；
- 过期、冻结、混搭和回退元数据；
- provenance 与包或 workflow 不一致；
- 权限清单不一致；
- 路径穿越、链接逃逸和压缩炸弹；
- revoked/blocked 版本安装；
- 插件访问其他插件 Secret 或数据绑定。
