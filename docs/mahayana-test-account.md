# 大乘 CLI 固定测试账号

此账号只用于大乘 CLI、机器人之父、插件生成和部署前冒烟测试，不是普通用户账号。

## 账号信息

- 用户名：`TestAccount`
- 用户 ID：`user:test_account`
- 会员类型：`lifetime`（测试环境专用）
- AI 用量：不设日常测试上限；服务端返回 `999999999` 的测试容量，已用量始终按 `0` 参与限额判断
- 登录方式：`mahayana login test`

## 凭证位置

真实测试令牌绝不写入 Git、文档、命令参数或 CI 日志。生产 Web Worker 与大乘 AI 后端使用同一个部署 Secret：`TEST_ACCOUNT_TOKEN`。本机首次登录从以下任一安全输入读取：

1. `MAHAYANA_TEST_ACCOUNT_TOKEN` 环境变量；
2. `mahayana login test --token-stdin` 的标准输入；
3. 不带参数运行 `mahayana login test` 后的隐藏输入提示。

首次成功后，令牌由大乘 Rust 客户端写入 Codex 加密 Secret 存储；之后可直接运行 `mahayana auth`、`mahayana usage` 和机器人之父测试，无需重复输入。

推荐的快速登录方式（不会把令牌放进 shell 历史）：

```sh
read -s MAHAYANA_TEST_ACCOUNT_TOKEN
export MAHAYANA_TEST_ACCOUNT_TOKEN
mahayana login test
unset MAHAYANA_TEST_ACCOUNT_TOKEN
```

## 验收

```sh
mahayana auth
mahayana usage
mahayana miniapp chat bot-father "读取工作区中的插件清单并使用工具修复测试失败"
```

`auth` 必须返回 `TestAccount`；`usage` 必须返回测试容量且不会因日常冒烟测试产生 429；机器人之父必须出现真实工作区工具调用，不能只返回修改建议。

## 轮换

令牌泄露或人员变更时，同时轮换 Web Worker 与 AI 后端的 `TEST_ACCOUNT_TOKEN`，然后重新执行一次 `mahayana login test`。旧令牌不得保留兼容入口。
