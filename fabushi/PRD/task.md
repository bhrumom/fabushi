# 账户注销功能任务列表

- [x] 在 `api_constants_template.dart` 和 `api_constants.dart`中添加注销账号的API端点 `deleteAccount`。
- [x] 在 `auth_service.dart` 中实现网络请求调用注销接口。
- [x] 在 `auth_model.dart` 中实现 `deleteAccount` 逻辑（清除缓存并执行登出业务逻辑）。
- [x] 在 `settings_screen.dart` 的底部增加一个“注销账户”行选项，并给以醒目的红色警示语。
- [x] 点击“注销账户”时，弹出双重确认对话框。确认后触发 `auth_model.deleteAccount`。
- [x] 确保注销成功后回到登录页面。
- [x] 本地自测完整的重新登录、注销流程。
- [ ] 留出物理设备提供录制使用。
