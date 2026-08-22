# ADR-0004: Computer Control Capability Model

Status: Accepted — 2026-08-22

## Decision
电脑控制不是万能远程执行 API，而是一组目标绑定、作用域明确、可到期/撤销、可审计的 capabilities。跨平台 adapter 共享同一 contract；敏感输入使用独立一次性通道。
