# ADR-0005: Fabushi Avatar Animation Engine

Status: Accepted — 2026-08-22

## Decision
保留 Grok 动态表现的产品价值，但正式实现采用 Fabushi 自研语义状态驱动动画引擎，不以 Grok runtime/私有资产作为生产依赖。引擎必须支持可维护状态机、组合、性能降级和 reduced-motion。
