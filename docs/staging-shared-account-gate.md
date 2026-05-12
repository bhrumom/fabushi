# Staging 共享测试账号门禁规则

本文档把一条已经在 `bhrumom/fabushi` 主线事故中反复验证过的发布规则沉淀为仓库资产：当 staging API E2E 依赖共享测试账号时，账号本身属于环境依赖，而不是产品行为契约。

## 适用范围

当前直接受这条规则影响的检查包括：

- `fabushi/e2e/tests/staging-profile-api.spec.js`
- `fabushi/e2e/tests/staging_social_privacy.spec.ts`
- `.github/workflows/deploy-production.yml` 里的 `Staging API E2E and smoke gate`

只要某条 staging API E2E 必须先用共享账号登录，后续也默认适用同样的判定方式。

## 已验证过的失败特征

当环境缺口来自共享账号本身，而不是产品回归时，通常会同时出现这些信号：

- `/api/auth/login` 直接返回 `401`
- 响应体包含 `{"error":"用户不存在"}` 或同类“账号缺失/失效”信号
- 多条依赖同一账号的 staging API 用例在同一轮里一起打红
- `Build release artifact` 与 `Deploy staging environment` 已成功，说明 deploy 主链已经继续向前

这类失败不应直接解释为“staging API 产品回归”。

## 默认处理规则

当 staging API E2E 遇到共享测试账号不可用时：

1. 保留 smoke / health / 已登录后可独立验证的 API 边界检查
2. 把依赖该共享账号的具体 API 用例降级为 `skip` 或等效的环境依赖报告
3. 在测试输出中明确写出账号不可用原因，避免被误读成普通通过
4. 不让单个共享账号缺口直接把整条主线 CD 判成新的产品红灯

反过来，如果失败信号不是账号缺失，而是：

- 登录成功但后续接口返回异常
- `/health`、`/api/auth/user-info` 等基础边界失败
- 部署步骤本身失败

则继续按真实产品或部署回归处理，不套用这条降级规则。

## Workflow 与测试的同步要求

为了避免测试和 workflow 契约漂移，默认同时保持以下约束：

- 共享账号相关测试必须给出清晰的 `skip` 原因，而不是只在断言里直接红掉
- `deploy-production.yml` 里的 staging gate 应继续保留 smoke 证据，不能因为单条共享账号依赖失败就掩盖 deploy 真实状态
- 新增依赖共享账号的 staging API E2E 时，要在 PR 描述或相关文档中明确说明它属于环境依赖还是产品契约
- 若共享账号长期不可用，应优先补可自动维护的种子数据或独立测试账号，而不是把整条 gate 永久改成静默通过

## 关闭 issue 的证据要求

仅仅把代码改成 `skip/report` 还不够；要关闭相关 deployment-failure issue，仍需满足：

- 拿到一条晚于修复 merge 时间的 `main` 上新 CD 运行结果
- 该结果显示共享账号缺失不再把整条 gate 判成产品红灯
- smoke / health / 其他不依赖共享账号的边界检查仍然保持有效

在拿到这条新运行证据之前，旧 issue 可以保留为“代码已修、外部结果待确认”。

## 为什么要版本化

如果这条规则只留在一次性的调度记录里，后续很容易再次出现两种误判：

- 把环境账号缺口误判成产品回归，导致主线发布被无效阻塞
- 为了追求绿灯，把真实 smoke 边界也一起弱化掉

把规则写回仓库，目的是让之后的 PR、Issue、workflow 调整与自动巡检都使用同一套判断标准。