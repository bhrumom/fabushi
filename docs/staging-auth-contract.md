# Staging Auth Contract Rule

Fabushi 的 staging profile API E2E 需要验证的核心是：密码登录后的认证链路仍然可用，而不是某一版登录响应是否刚好内联返回完整 `user` 对象。

## 默认规则

- `POST /api/auth/login` 的硬契约是：成功返回可立即使用的 `token`
- 如果调用方还需要完整用户资料，应允许紧接着用该 `token` 调用 `GET /api/auth/user-info`
- 只有在应用端、Worker 入口和测试门禁都已经统一承诺“登录响应必须内联返回 `user`”时，才可以把 `body.user` 提升为主线 CD 的硬门槛
- 在这条统一承诺形成之前，staging E2E 应优先验证“登录成功后能否立即取回用户信息”，不要把表示层差异误判成认证回归

## 为什么要记录这条规则

2026-05-08 的 mainline CD 在 `issue #237` 暴露出一个典型漂移：staging 登录已经能返回 `token`，但 profile E2E 直接把缺少 `body.user` 判成失败，导致主线发布被响应形状差异卡住，而不是被真实认证故障卡住。

这条规则的目的是让后续主控、PR 修复和 workflow 门禁统一按真实认证能力收口，而不是反复在“登录接口是否顺手附带完整用户对象”上误报。