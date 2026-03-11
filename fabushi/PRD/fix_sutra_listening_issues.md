# 修复听经页面朗读问题

## 问题

1. **句间延迟**：朗读完一句后停留一会才切换下一句
2. **退出后继续播放**：退出听经页面后经文继续在后台朗读

## 根因

### 问题1
`sutra_listening_service.dart` 中 `awaitSpeakCompletion(false)` 导致 completion handler 触发时机不精确，产生句间延迟。

### 问题2
`sutra_listening_screen.dart` 的 `dispose()` 未调用 `_service.stop()`。`SutraListeningService` 是单例，页面销毁后 TTS 引擎仍在运行。

## 修复

| 文件 | 修改 |
|------|------|
| `sutra_listening_service.dart` | `awaitSpeakCompletion(true)` + `await speak()` |
| `sutra_listening_screen.dart` | `dispose()` 中添加 `_service.stop()` |

## 验证

- [x] 静态分析通过
- [ ] 手动测试：进入听经页面确认句间无延迟
- [ ] 手动测试：退出听经页面确认朗读停止
