# 用户需求：油猴式用户脚本更新源

用户明确要求 ChatGPT 自动确认脚本的更新方式与 Tampermonkey/GreaseMonkey 一致：Marketplace 只负责首次发现和安装脚本，不应在每次脚本发布时同步修改市场目录的版本、commit、大小和摘要。已安装脚本应从自身 `@updateURL`（必要时使用 `@downloadURL`）检查元数据中的 `@version`，发现新版本后取得并安装脚本。

约束：保留 Fabushi 当前的用户脚本安全边界。更新地址必须是 HTTPS；当前 Marketplace 远程可执行代码边界继续限制为同一公开 GitHub 仓库的 `raw.githubusercontent.com` 地址；更新前校验用户脚本元数据、脚本身份、大小和现有危险语法规则，失败时保留旧版本。
