# ADR-0001 — History rewrite toolchain

日期：2026-09-07
状态：accepted for preparation

## Context

Fabushi 需要在全部远端 heads/tags 上清理多个生成/缓存路径，同时保留体积较大的合法产品资产。操作必须可审计、可回滚，并且不能污染当前开发工作树。

## Options

1. **git-filter-repo**：官方仓库说明其用于快速重写完整历史，支持路径过滤、ref 限制和自定义回调；适合本项目的多路径规则和全 refs 迁移。
2. **BFG Repo-Cleaner**：成熟、快速，适合大 blob 或简单文本模式；GPL-3.0 且抽象更简单，不足以表达本项目的精确路径族与保留清单。
3. **git-sizer**：只读体积/可达性分析器，不是重写工具；用于指标设计和结果复核，不引入运行时依赖。

## Decision

采用隔离 bare 镜像 + git-filter-repo；使用 Git 原生 refs/tree/fsck 校验和 git-sizer 风格指标。每次重写从最新远端 refs 重新生成，不在当前工作树上运行，不把第三方工具代码提交进 Fabushi。

## Consequences

commit/tree/blob/tag OID 会改变，必须在动作前保存原始 ref 清单并通知贡献者。GitHub 保护规则需要一个最小迁移窗口，窗口关闭后必须读回验证。项目只记录工具链接、版本和许可证判断，不复制实现。
