# Google Sheets 项目总控规则

## 文档地位

本文件是 ChatGPT 自动确认小程序对项目管理、任务执行、进度汇报和外部协作应用读取顺序的最高优先级管理规则之一。

当前项目总控 Google Sheets：

`https://docs.google.com/spreadsheets/d/1APOqImrgfukFwLyW2NHimPYV0hLInYV9zpgTYWVUDHg/edit`

表名：`法布施｜全项目任务总控与验收台账`

## 1. 单一项目管理入口

所有项目统一进入同一个 Google Sheets 文件管理，不为每个项目另建彼此脱节的管理体系。

职责固定如下：

- Gmail：只作为通知、汇报发送和人工入口；原则上邮件只放项目总控 Google Sheets 这一张表，不再堆叠大量 Drive/Calendar/GitHub 链接。
- Google Sheets：项目管理的单一总控和状态事实表，汇总全部项目、阶段、原子任务、文件、日程、GitHub 自动验收、阻塞、下一步和每轮汇报。
- Google Drive：保存权威任务文件、阶段任务文件、验收说明和长期文档；由 Sheets 中的可点击单元格引用。
- Google Calendar：保存项目排期、阶段时间窗口和每日执行安排；由 Sheets 中的可点击单元格引用。
- GitHub / GitHub Actions：代码和自动验收的工程事实源；commit、PR、workflow run、required check、Release 等证据回写到 Sheets。

不得把 Gmail、Drive 或 Calendar 单独当作项目状态事实源。发生冲突时，工程事实以 GitHub 为准，项目状态与管理视图以 Google Sheets 为准；Sheets 必须及时同步 GitHub 的真实结果。

## 2. Google Sheets 固定结构

至少包含以下页签：

### 项目总览

每个项目一行，至少包含：

- 项目 ID
- 项目名称
- 状态
- 总进度
- 当前阶段
- 开始日期
- 目标完成日期
- 项目负责人
- 权威任务文件
- Drive 项目目录
- Calendar 总项目
- GitHub 主仓库
- GitHub 规范 PR
- 当前阻塞
- 下一步
- 最近汇报时间

### 阶段总览

每个 Txx 阶段一行，至少包含：

- 项目 ID
- 阶段 ID
- 阶段名称
- 状态
- 阶段进度
- 阶段任务文件
- Calendar 安排
- Required Check / Gate
- 验收目标
- 当前结论
- 下一步
- 最近汇报

### 原子任务

每个可独立验收任务一行，至少包含：

- 项目 ID
- 阶段 ID
- Task ID
- 原子任务
- 业务验收标准
- Required Check
- 是否通过
- 进度
- 任务文件
- Calendar 安排
- GitHub 证据
- Commit / Run
- 负责人
- 状态
- 阻塞
- 下一动作
- 最近汇报
- 备注

### 汇报记录

每执行一轮追加一行，不覆盖历史，至少包含：

- 汇报 ID
- 时间
- 项目 ID
- 阶段 ID
- Task ID
- 轮次
- 本轮完成
- 自动验收结果
- 证据链接
- 发现问题
- 阻塞
- 下一轮计划
- 进度变化
- 结论

## 3. 原子任务与自动验收

任务必须拆到可以被 GitHub Actions 或等价自动测试独立验证的粒度。

每个原子任务必须有：

1. 唯一稳定 Task ID，例如 `T02.3`；
2. 明确的实现目标；
3. 明确的业务验收标准；
4. 稳定的 GitHub Actions required check 名称或可自动核验的等价证据；
5. commit SHA / PR / workflow run / check / Release / API 结果等证据；
6. 当前状态与阻塞；
7. 下一动作。

原子任务只有在以下条件同时满足时才可标记完成：

- 实现已进入目标代码分支或目标仓库；
- 对应自动测试/required check conclusion 为 `success`；
- 业务验收标准满足；
- 证据已写回 Google Sheets。

不得因为“代码看起来完成”或“人工认为差不多”就打勾。

## 4. 进度计算

所有派生进度必须由表格公式计算，禁止主观手填百分比。

- 原子任务：未通过为 0%，通过为 100%；如确有可验证中间状态，可单独记录状态，但父级进度仍只按通过的必需任务计算。
- 阶段进度 = 该阶段已通过必需原子任务数 / 该阶段必需原子任务总数。
- 项目总进度 = 该项目已通过必需原子任务数 / 该项目必需原子任务总数。
- 所有必需原子任务通过后，父阶段才允许标记 100% / 完成。
- 所有阶段完成后，项目才允许报告完成。

## 5. ChatGPT 自动确认执行顺序

每次继续执行本项目时，ChatGPT 自动确认小程序必须优先读取和核对：

1. Google Sheets 项目总控表；
2. 当前项目行、当前阶段行和待执行原子任务行；
3. Sheets 中引用的权威 Drive 任务文件；
4. Sheets 中引用的 Calendar 当前安排；
5. GitHub 当前分支、PR、commit、Actions、Release 等真实工程状态。

然后只执行 Sheets 中状态允许且未通过的任务。

如果 Sheets 与 GitHub 不一致：

- 不允许根据旧 Sheets 状态继续猜测；
- 先读取 GitHub 事实；
- 修正 Sheets；
- 再继续执行。

## 6. 每轮执行后的强制回写

每一轮实际工作完成后，必须更新 Google Sheets：

- 原子任务状态；
- required check / Actions 结果；
- commit / PR / run / Release 证据；
- 阻塞；
- 下一动作；
- 最近汇报时间；
- 汇报记录新增一行；
- 阶段和项目进度由公式自动更新。

同时仅在确有必要时更新对应 Drive 文档和 Calendar 安排。

Gmail 不保存项目唯一状态；需要发送汇报时，邮件正文应保持简洁，并只引用这一张 Google Sheets 总控表作为统一入口。

## 7. 多项目规则

以后新项目也进入同一个 Google Sheets 文件：

- `项目总览` 新增项目行；
- `阶段总览` 新增对应阶段；
- `原子任务` 新增对应任务；
- `汇报记录` 追加执行记录。

不得为新项目重新复制一套互不关联的 Gmail/Drive/Calendar 管理结构。

## 8. 当前迁移要求

现有 `mahayana-marketplace-cloudflare-20260730` 项目必须迁移到以上规则：

- T01-T08 状态以总控 Sheets 为管理入口；
- 后续原子任务继续补齐到 Sheets；
- GitHub Actions required checks 与每个原子任务建立一一对应；
- Calendar 用于安排，不代替任务状态；
- Drive 用于文档，不代替进度状态；
- Gmail 只保留总控表入口和必要汇报通知。
