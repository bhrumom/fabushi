# 项目文件清单

## Root governance

- `CHANGELOG.md`
- `CONTRIBUTING.md`
- `FILE_INDEX.md`
- `OWNERS.md`
- `PROJECT.yaml`
- `README.md`
- `SECURITY.md`
- `SOURCE_OF_TRUTH.md`

## Decisions

- `decisions/ADR-0001-rust-first.md`
- `decisions/ADR-0002-self-hosted-protocol.md`
- `decisions/ADR-0003-unified-conversation-model.md`
- `decisions/ADR-0004-local-first-sync.md`
- `decisions/ADR-0005-agent-first-class.md`
- `decisions/ADR-0006-miniapp-sandbox.md`
- `decisions/ADR-0007-payment-adapter.md`
- `decisions/ADR-0008-canonical-messaging-core-and-legacy-freeze.md`
- `decisions/README.md`

## Product / architecture docs

- `docs/00-项目章程.md`
- `docs/01-范围与非目标.md`
- `docs/02-产品需求-PRD.md`
- `docs/03-系统架构.md`
- `docs/04-领域模型与协议.md`
- `docs/05-Rust-Workspace与模块边界.md`
- `docs/06-身份联系人与会话.md`
- `docs/07-客户端架构与交互.md`
- `docs/08-服务端与部署.md`
- `docs/09-Bot-Agent统一网络.md`
- `docs/10-Mini-Apps平台.md`
- `docs/11-Fabushi-Pay.md`
- `docs/12-音视频与媒体.md`
- `docs/13-安全威胁模型与隐私.md`
- `docs/14-性能SLO与可观测性.md`
- `docs/15-测试策略.md`
- `docs/16-CICD与发布.md`
- `docs/17-迁移与兼容策略.md`
- `docs/18-许可证与来源合规.md`
- `docs/19-完成定义与验收.md`
- `docs/20-计划维护规则.md`
- `docs/20-现状审计与迁移边界.md`
- `docs/README.md`

## Management

- `management/00-路线图.md`
- `management/01-WBS原子任务.md`
- `management/02-里程碑.md`
- `management/03-验收追踪矩阵.md`
- `management/04-风险登记.md`
- `management/05-状态报告.md`
- `management/06-PR分支规则.md`
- `management/06-依赖与阻塞.md`
- `management/07-变更日志.md`
- `management/08-问题与行动项.md`
- `management/wbs/M0.md` … `M14.md`
- `management/wbs/governance.md`

### Active / durable task records

- `management/tasks/TFI-GOV-001-github-authority-and-skill.md`
- `management/tasks/TFI-GOV-002-enterprise-standard.md`
- `management/tasks/M0-T01-current-messaging-audit.md`
- `management/tasks/M1-T06-sqlite-storage.md` (on active implementation branch until merged)
- `management/tasks/M1-T02-production-storage.md` (on active implementation branch until merged)

## Runbooks

- `runbooks/README.md`
- `runbooks/messaging-server.md`
- `runbooks/sqlite-storage-migration.md`
- `runbooks/rollback.md`

## Source / evidence / templates

- `source/完整telegram融合进fabushi.txt`
- `source/full-plan/part-01.txt` … `part-08.txt`
- `evidence/TFI-GOV-001/README.md`
- `evidence/TFI-GOV-002/README.md`
- `evidence/M1-T06/README.md` (on active implementation branch until merged)
- `templates/ADR_TEMPLATE.md`
- `templates/PR_ACCEPTANCE_TEMPLATE.md`
- `templates/STATUS_REPORT_TEMPLATE.md`
- `templates/TASK_TEMPLATE.md`

## Repository-level governance

- `.agent/skills/fabushi-project-governance/`

## Maintenance rule

This index describes the durable project structure on or intended for the authoritative project path. Task/evidence files created on implementation branches become canonical only after their PRs pass CI, merge through protected `main`, and are verified there.
