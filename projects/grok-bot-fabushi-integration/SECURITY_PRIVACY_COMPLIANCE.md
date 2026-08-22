# Security, Privacy and Compliance

## 安全

- renderer 视为低信任层；敏感能力必须经 preload contract + main/host capability gate。
- shell、文件、浏览器、屏幕、键鼠、麦克风、摄像头、凭证均为显式权限能力。
- sensitive-input 请求必须具备一次性、绑定目标、过期、不可重放语义。
- 禁止日志记录密码、token、OTP、支付凭证等秘密。

## 隐私

电脑控制/截图/文件读取只在用户授权范围内执行，记录能力类型和结果，不记录不必要的私密内容。

## 来源合规

所有 Grok 来源代码/资源必须记录来源、许可、可复用边界。若权利或许可不清晰，优先依据观察到的功能行为重新实现，不把不可确认来源代码直接作为自有源码发布。
