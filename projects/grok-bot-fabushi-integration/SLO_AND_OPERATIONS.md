# SLO and Operations

在测量基线建立前，本项目不虚构 P95/P99 数字。

必须观测：Agent turn 延迟、tool dispatch 延迟、host process 启动/崩溃率、IPC 错误率、权限拒绝/超时、电脑控制动作成功率、renderer 卡顿/崩溃、资源占用、动画帧时间。

每个新增能力必须定义：日志事件、错误分类、trace/correlation id、健康检查方式、用户可见错误与降级行为。
