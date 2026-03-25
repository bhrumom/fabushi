# App Store 审核回复指南

## 需要在 App Store Connect 中手动处理的事项

### 1. 截图问题 (Guideline 2.3.10 & 2.3.3)
- **iPhone 截图**：移除包含非 iOS 状态栏的图片，重新截取真机截图
- **13寸 iPad 截图**：使用 iPad 真机或模拟器截取，不要使用 iPhone 模拟器外框的截图

### 2. 年龄分级 (Guideline 2.3.6)
在 App Store Connect → App 信息 → 年龄分级 中：
- 将"家长控制 (Parental Controls)"设为 **None**
- 将"年龄认证 (Age Assurance)"设为 **None**

### 3. 测试账号 (Guideline 2.1)
在 App Store Connect → App Store → App 审核信息 中提供：
- **用户名**: (填写测试账号)
- **密码**: (填写测试密码)
- **说明**：登录后可访问所有功能，包括收藏、点赞、AI问经等

### 4. 应用图标 (Guideline 2.3.8)
- 上传最终版应用图标到 App Store Connect
- 确保图标不是占位符或通用设计

---

## 需要回复审核团队的问题

### 5. 后台音频说明 (Guideline 2.5.4)

**建议回复（英文）**：

> Our app uses `UIBackgroundModes` audio for the following legitimate purpose:
>
> **Background Scripture Audio Playback**: Our app includes a "Meditation Room" (禅修室) feature where users can play Buddhist scriptures and meditation audio. This feature is designed to play continuously in the background while users perform other tasks or lock their screen, similar to how meditation/prayer apps function.
>
> **How to access this feature:**
> 1. Open the app
> 2. Navigate to the "Meditation Room" (禅修室) tab
> 3. Select a scripture or meditation audio
> 4. Press play - the audio will continue playing when the app is moved to background
>
> We also provide a "Keep-alive" service that uses `audio_service` and `just_audio` packages to maintain background audio playback of scriptures. This is essential for our users who listen to scriptures during meditation or daily activities.

### 6. 用户生成内容 (Guideline 1.2) - 已通过代码修复

已实施的安全措施：
- ✅ **EULA/用户协议**：首次启动必须同意用户服务协议才能继续使用
- ✅ **内容举报**：用户可通过内容页面的"更多"按钮举报不当内容（支持多种举报类型）
- ✅ **用户屏蔽**：用户可屏蔽发布不当内容的用户，被屏蔽用户的内容将从信息流中移除
- ✅ **零容忍政策**：所有举报将在24小时内处理，违规内容立即删除

**建议回复（英文）**：

> We have implemented the following safety measures for user-generated content:
>
> 1. **Terms of Service (EULA)**: Users must accept our Terms of Service before accessing any features. The EULA clearly states our zero-tolerance policy for objectionable content.
>
> 2. **Content Reporting**: Users can report any objectionable content through the "More" (⋯) button on each content item. Reports support multiple categories including inappropriate content, spam, harassment, hate speech, violence, misinformation, and copyright infringement.
>
> 3. **User Blocking**: Users can block other users whose content they find objectionable. Blocked users' content is immediately removed from the blocking user's feed.
>
> 4. **Content Moderation**: All reported content is reviewed and actioned within 24 hours. Accounts that violate our policies are permanently banned.

### 7. 支持页面 (Guideline 1.5)

- 将 `docs/support.html` 部署到 `https://flutter.ombhrum.com/support`
- 在 App Store Connect 中更新 Support URL 为 `https://flutter.ombhrum.com/support`

### 8. 支付宝登录 (Guideline 4.2.3(i)) - 已通过代码修复

已实施的修复：
- ✅ **应用内网页登录体验**：未安装支付宝的用户也可通过 Safari View Controller 直接使用网页完成支付宝登录。
- ✅ **智能体验回退机制**：应用不再强求用户必须安装支付宝 App。

**建议回复（英文）**：

> We have resolved the Guideline 4.2.3(i) issue regarding the Alipay login dependency:
>
> 1. **In-App Web Login**: We have successfully integrated the `SFSafariViewController` API (In-App Browser View) for users who do not have the Alipay app installed on their devices.
> 
> 2. **No Additional App Required**: Users can now fully complete the Alipay login process via the securely embedded webpage without having to install any additional apps. They can also verify the URL and SSL certificates directly within the Safari View Controller during the OAuth process. 
> 
> The app is now fully compliant with the Minimum Functionality requirements.

### 9. Sign in with Apple (Guideline 4.8) - 已通过代码修复

已实施的修复：
- ✅ **Sign in with Apple 按钮**：在登录页面添加了原生的 "Sign in with Apple" 按钮，与支付宝登录并列作为等效的登录方式。
- ✅ **隐私保护**：Apple 登录仅收集用户姓名和邮箱，且用户可选择隐藏真实邮箱地址（使用 Apple 中继邮箱）。
- ✅ **无广告数据收集**：Apple 登录过程不收集任何用于广告目的的交互数据。

**建议回复（英文）**：

> We have resolved the Guideline 4.8 issue by integrating Sign in with Apple as an equivalent login option:
>
> 1. **Sign in with Apple Integration**: We have added a native "Sign in with Apple" button on our login screen, positioned alongside our existing Alipay login option. This provides users with a login service that meets all requirements of Guideline 4.8.
>
> 2. **Minimal Data Collection**: The Sign in with Apple integration only requests the user's name and email address.
>
> 3. **Email Privacy**: Users can choose to hide their real email address using Apple's private relay email service when setting up their account.
>
> 4. **No Advertising Data Collection**: Our Sign in with Apple implementation does not collect any user interactions for advertising purposes.
>
> The Sign in with Apple button is displayed on iOS and macOS platforms, providing full compliance with login service requirements.

---

## 提交前检查清单

- [ ] 更新 iPhone 截图（真机截取）
- [ ] 更新 13寸 iPad 截图（iPad 模拟器截取）
- [ ] 设置年龄分级为 None
- [ ] 提供测试账号
- [ ] 上传最终版应用图标
- [ ] 部署支持页面到服务器
- [ ] 更新 Support URL
- [ ] 提交新版本代码（包含 EULA + 举报 + 屏蔽功能）
- [ ] 撰写审核回复（后台音频 + UGC 安全措施说明）
