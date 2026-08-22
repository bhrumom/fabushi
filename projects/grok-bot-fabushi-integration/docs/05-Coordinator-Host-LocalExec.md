# 05 Coordinator / Host / Local Exec

目标是一个执行图：Mahayana Agent runtime 产生结构化 capability request -> policy/approval -> host adapter -> platform operation -> structured result -> Agent/event stream。

不得让 Grok coordinator、Fabushi host、MCP local exec 分别拥有互相绕过的权限模型。重试、取消、超时、并发和恢复语义必须集中定义。
