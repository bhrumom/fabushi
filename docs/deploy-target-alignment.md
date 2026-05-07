# 部署目标与 Smoke Gate 对齐规则

这份文档沉淀 `issue #204` / `PR #206` 暴露出来的一条长期规则：当 Fabushi 的部署形态发生变化时，CI/CD 的 smoke gate、E2E 变量命名和发布摘要必须与真实部署目标保持同一个模型。

## 这次暴露出的根因

staging / production 的 CD workflow 已经在部署独立后端 API，但 smoke gate 仍按“前后端未拆分”的旧模型检查根路径首页。

结果是：

- 真实部署成功了，workflow 仍然会因为根路径 `404` 被误判成失败
- 变量名继续使用 `STAGING_APP_URL` / `PRODUCTION_APP_URL`，会让后续维护者误以为 gate 目标是前端站点
- deployment summary / failure note 里的 gate 描述会继续传播过时心智模型

## 默认规则

涉及 deploy、smoke、E2E 或发布摘要的改动时，默认同时检查下面四项：

1. 部署出去的真实目标是什么
2. smoke gate 探测的 URL / endpoint 是什么
3. E2E 使用的环境变量命名是否仍准确表达目标语义
4. step summary、failure issue、release 说明是否仍与当前部署模型一致

只要这四项里有一项还停留在旧模型，就不能把 workflow 绿灯当成稳定闭环。

## Fabushi 当前适用的判断方式

如果当前 workflow 部署的是后端 API，而不是同时部署前端静态站点，则默认按下面方式建 gate：

- smoke gate 先检查健康接口，例如 `/health`
- 再检查一条明确的 auth boundary，例如未登录访问 `/api/auth/user-info` 应返回 `401` 或 `403`
- 不再把根路径首页可访问当作后端 deploy 成功的必要条件

如果未来 workflow 重新切回“同一步同时发布前端和后端”的模型，则要把这条文档和对应 gate 一起更新，而不是只改其中一处。

## 变量命名规则

环境变量名必须反映真实部署目标：

- 面向 API 的地址用 `*_API_URL`
- 面向前端站点的地址用 `*_APP_URL` 或其他明确站点语义的名称

不要为了沿用旧脚本而保留误导性的变量名。变量名语义漂移会直接降低后续主控排障速度。

## 发布摘要同步规则

以下内容必须和真实 gate 保持一致：

- workflow step 名称
- `GITHUB_STEP_SUMMARY` 中的 gate 描述
- 自动创建或更新的 failure issue 文案
- 任何给 release / deployment 状态页展示的目标 URL

如果 gate 已改成 API health + auth boundary，但摘要里还写着“site smoke test”，这仍然属于未完全收口。

## 合并前最小核对清单

每次调整 deploy 或 smoke gate 前，至少核对：

- 实际部署目标是前端、后端，还是两者一起
- smoke gate 是否命中了真实目标
- E2E 变量名是否与目标一致
- summary / failure issue 文案是否同步更新
- 若目标模型发生变化，相关运行手册是否也已更新

## 与主控流程的关系

这条规则属于发布闭环工位和仓库同步工位的交叉门禁：

- 发布闭环工位负责发现“真实部署成功但 gate 仍按旧模型误报”的问题
- 仓库同步工位负责把这种长期规则写回版本管理资产，避免下轮继续靠临时记忆排障

当这类问题再次出现时，默认先查“部署目标、变量名、smoke gate、摘要文案”是否仍处于同一个模型，再决定是否进入更深层产品故障排查。
