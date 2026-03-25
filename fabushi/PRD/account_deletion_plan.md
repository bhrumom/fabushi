# 账户注销功能实现计划

## 目标简述
根据 App Store 审查指南 5.1.1(v) 要求，实现 App 内的账户注销和删除功能。提供清晰的用户警告，调用后端 API 清理数据，并在成功后返回登录状态。

## 需用户确认的事项
> [!IMPORTANT]
> - 后端的注销 API 路径假设为 `/api/auth/delete`（或 `/api/user/delete`），如果后端实际并不是这个路径，请您告知或直接在修改环节提出意见。
> - 在开发完毕测试好之后，根据苹果审核要求，您需要在真实设备上录屏“从登录 -> 导航到设置 -> 点击注销 -> 完成”的流程，并在 App Store Connect 的 Notes 中提交。我在这边开发完成后可以在模拟器上通过测试展示大概流程。

## 提议的更改

### 常量定义与 API
更改文件：
#### [MODIFY] [api_constants.dart](file:///Users/gloriachan/Documents/fabushi/fabushi/lib/core/constants/api_constants.dart)
- 添加 API 常量：`static const String deleteAccount = '/api/auth/delete';`。
#### [MODIFY] [api_constants_template.dart](file:///Users/gloriachan/Documents/fabushi/fabushi/lib/core/constants/api_constants_template.dart)
- 同步修正相应的路由说明。

---

### 服务层集成
更改文件：
#### [MODIFY] [auth_service.dart](file:///Users/gloriachan/Documents/fabushi/fabushi/lib/services/auth_service.dart)
- 实现 `deleteAccount` 方法，发送 `DELETE` 请求到指定的注销 API。并在请求成功时返回 `true`。

---

### 状态管理 (Provider)
更改文件：
#### [MODIFY] [auth_model.dart](file:///Users/gloriachan/Documents/fabushi/fabushi/lib/models/auth_model.dart)
- 添加 `deleteAccount()` 方法：
  - 调用 `auth_service.deleteAccount` 取消账号。
  - 清理本地数据并触发注销逻辑 (`logout()`)。

---

### 用户界面
更改文件：
#### [MODIFY] [settings_screen.dart](file:///Users/gloriachan/Documents/fabushi/fabushi/lib/screens/settings_screen.dart)
- 在“设置”页面底部新增“注销账户”行选项。
- 点击时弹出二次确认对话框：“您确定要永久注销并删除您的账户吗？此操作不可逆，您的所有数据将被清除且无法恢复。”
- 用户确认后执行 `AuthModel` 的 `deleteAccount()`。

## 验证计划
### 自动化/本地测试
- 启动应用并登录。
- 进入“设置”界面验证“注销账户”按钮。
- 点击注销账户，验证确认弹窗和注销逻辑流。
