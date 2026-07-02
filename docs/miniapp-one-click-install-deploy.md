# 小程序一键安装部署脚本平台设计

## 目标

Fabushi 小程序不仅是页面，也可以是一个“交互式安装部署向导”。

很多 GitHub 项目主可以创建一个小程序，把项目安装、依赖检查、配置、部署、启动、验证等步骤封装成脚本。用户在 Fabushi 平台打开这个小程序后，只需要通过聊天消息回复数字或点击按钮，就能一步步完成安装部署。

```text
用户打开项目小程序
  -> 小程序读取安装 manifest
  -> 宿主选择本地 runtime
  -> 小程序通过聊天提出选择题
  -> 用户回复数字
  -> 宿主执行对应本地脚本步骤
  -> 输出日志、错误、下一步建议
  -> 最终完成安装、部署、启动和验证
```

核心原则：**桌面端最大化脚本能力；移动端也提供脚本能力，但以本地 JS/WASM/内置解释器/远程控制桌面任务为主，不把默认执行转到云端。**

## 产品形态

项目主可以为自己的 GitHub 项目提供一个 Fabushi 小程序：

```text
GitHub 项目
  ├─ fabushi-miniapp.json
  ├─ install.plan.json
  ├─ scripts/
  │   ├─ detect.js
  │   ├─ install_macos.sh
  │   ├─ install_windows.ps1
  │   ├─ install_linux.sh
  │   ├─ verify.js
  │   └─ repair.js
  └─ miniapp/
      └─ UI / Chat Wizard
```

用户打开后，不需要读 README，不需要复制命令，只需要按提示选择：

```text
请选择安装方式：
1. 本机 Docker 部署
2. 本机 Node.js 部署
3. 本机 Rust 编译部署
4. 只下载源码，不启动服务

回复数字继续。
```

## 核心能力：install.wizard

新增能力组：`install.wizard`。

```json
{
  "name": "install.wizard",
  "risk": "critical",
  "officialOrTrustedOnly": true,
  "localFirst": true,
  "reason": "允许项目小程序通过交互式向导在本机执行安装、配置、部署、验证脚本"
}
```

配套能力：

```text
install.plan.load
install.plan.validate
install.step.preview
install.step.run
install.step.cancel
install.step.retry
install.step.rollback
install.status.get
install.logs.read
install.artifacts.list
```

## 安装计划 Install Plan

小程序不能直接丢一串命令给宿主执行。它应声明一个结构化安装计划：

```json
{
  "schemaVersion": 1,
  "projectId": "github.owner.repo",
  "title": "示例项目一键部署",
  "source": {
    "type": "github",
    "repo": "owner/repo",
    "ref": "main"
  },
  "executionPolicy": {
    "mode": "local-first",
    "cloudFallback": false,
    "requiresConfirmation": "perDangerousStep"
  },
  "runtimes": [
    "script.js",
    "script.lua",
    "script.pythonLite",
    "nodeDesktop",
    "shellDesktop",
    "powershellDesktop",
    "rustProgramDesktop"
  ],
  "steps": [
    {
      "id": "detect",
      "title": "检测本机环境",
      "runtime": "script.js",
      "entry": "scripts/detect.js",
      "risk": "low",
      "autoRun": true
    },
    {
      "id": "choose_mode",
      "title": "选择部署方式",
      "type": "choice",
      "message": "请选择安装方式：\n1. Docker 部署\n2. Node.js 部署\n3. Rust 编译部署",
      "options": [
        { "key": "1", "label": "Docker 部署", "next": "install_docker" },
        { "key": "2", "label": "Node.js 部署", "next": "install_node" },
        { "key": "3", "label": "Rust 编译部署", "next": "install_rust" }
      ]
    },
    {
      "id": "install_node",
      "title": "安装 Node.js 依赖并启动",
      "runtime": "nodeDesktop",
      "commands": [
        { "template": "npm.install", "args": [] },
        { "template": "npm.run", "args": ["build"] },
        { "template": "npm.run", "args": ["start"] }
      ],
      "risk": "high",
      "confirmText": "将在本机项目目录中安装依赖并启动服务。"
    },
    {
      "id": "verify",
      "title": "验证部署结果",
      "runtime": "script.js",
      "entry": "scripts/verify.js",
      "risk": "low"
    }
  ]
}
```

## 聊天式交互

安装小程序要支持“发消息回复数字”控制流程。

```text
小程序：检测到你的电脑没有 Docker，但有 Node.js 22。
小程序：请选择下一步：
1. 使用 Node.js 部署
2. 安装 Docker 后部署
3. 只克隆源码
4. 退出

用户：1
小程序：即将执行 npm install / npm run build / npm run start。是否继续？
1. 继续
2. 取消

用户：1
宿主：开始执行 install_node...
```

Host 侧需要把聊天命令转成 install step：

```text
bot.takePendingCommands
  -> install.wizard.handleReply
  -> resolve selected option
  -> preview next step
  -> request confirmation if needed
  -> run step
  -> stream logs back to chat
```

## 桌面端：最大化脚本能力

桌面端是安装部署类小程序的主战场，应提供最大脚本能力：

```text
shellDesktop
powershellDesktop
nodeDesktop
pythonDesktop / pythonLite
rustProgramDesktop
wasm
script.js
script.lua
gitDesktop
dockerDesktop
fileSystemWorkspace
localPortCheck
browser.open
serviceProcess
```

桌面端可以做：

```text
克隆 GitHub 仓库
选择安装目录
检测 Node/Python/Rust/Docker/Git
安装依赖
创建 .env
写配置文件
运行数据库迁移
启动本地服务
打开浏览器验证
读取日志
失败后自动修复
回滚安装步骤
```

但每个高风险步骤都必须能：

```text
preview：执行前展示将要做什么
confirm：用户回复数字确认
stream：实时输出日志
stop：用户可停止
retry：失败可重试
rollback：支持清理部分安装结果
```

## 移动端：也提供脚本能力

移动端也要提供脚本能力，但不是复制桌面端 shell。移动端的本地脚本能力主要用于：

```text
解析项目 manifest
运行 JS/WASM/Lua/pythonLite 轻脚本
生成配置文件草稿
准备安装参数
远程控制用户自己的桌面 Fabushi 任务
查看桌面任务状态和日志
在移动端本地运行轻量项目或移动端允许的任务
```

移动端 runtime：

```text
script.js
wasm
script.lua
script.pythonLite
rustLibrary
mobileLocalTask
```

移动端可以做：

```text
聊天式安装向导
选择安装模式
填写环境变量
生成部署配置
校验配置
把任务发送到同账号的桌面端本地执行队列
查看桌面端执行日志
停止桌面端任务
```

注意：这里不是使用公共云端执行，而是“移动端控制自己的桌面端本地执行”。如果用户没有桌面端在线，移动端应提示：

```text
当前手机无法本地执行此安装步骤，请打开桌面端 Fabushi 继续。
```

## 同账号设备协同

为了让移动端也能完成复杂安装部署，可以设计“本地设备协同”：

```text
手机小程序
  -> 创建 install job
  -> 选择目标设备：我的 Mac / 我的 Windows PC / 我的 Linux 主机
  -> 桌面端 Fabushi 收到任务
  -> 桌面端本地执行脚本
  -> 手机端查看日志和回复数字
```

这仍然符合本地优先，因为脚本实际运行在用户自己的设备上，不在公共云端运行。

能力命名：

```text
device.localRunner.list
device.localRunner.select
device.localRunner.dispatchJob
device.localRunner.attachJob
device.localRunner.stopJob
device.localRunner.readLogs
```

## GitHub 项目小程序创建流程

项目主可以通过平台生成安装小程序：

```text
1. 输入 GitHub 仓库 URL
2. AI 读取 README、package.json、Dockerfile、Cargo.toml、pyproject.toml 等
3. AI 生成 install.plan.json
4. 项目主确认脚本和步骤
5. 平台打包 miniapp
6. 平台签名 manifest
7. 用户在 Fabushi 中打开小程序
```

生成内容：

```text
安装向导 UI
聊天命令 handlers
环境检测脚本
安装步骤脚本
验证脚本
修复脚本
卸载/回滚脚本
权限声明
平台适配规则
```

## 权限模型

安装部署类小程序需要新的权限组合：

```text
install.wizard
runtime.script.js
runtime.wasm
runtime.script.lua
runtime.script.pythonLite
runtime.nodeDesktop
runtime.shellDesktop
runtime.powershellDesktop
runtime.rustProgramDesktop
fs.workspace.read
fs.workspace.write
git.clone
network.http
local.port
browser.external
service.process
system.keepAwake
device.localRunner
```

早期可以只给官方/受信项目小程序；后续开放给第三方时，需要审核 install plan。

## 安全与用户体验底线

为了最大化脚本能力，同时避免不可控，安装部署流程必须有：

```text
1. 每一步都有 title、risk、description。
2. 高风险步骤执行前展示 preview。
3. 用户可用数字回复确认或取消。
4. 所有命令模板化，尽量避免任意字符串命令。
5. 需要工作目录时必须让用户选择 workspace。
6. 记录日志、退出码、耗时和变更文件摘要。
7. 用户可停止、重试、回滚。
8. 小程序不能静默读取敏感文件。
9. 小程序不能静默写系统目录。
10. 小程序不能把本机 token 输出到日志。
```

## 最小落地版本

第一版先实现：

```text
1. install.plan.json schema
2. install.wizard Host API
3. 聊天回复数字驱动 choice step
4. 桌面端支持 script.js + shellDesktop/powershellDesktop + nodeDesktop
5. 移动端支持 script.js + wasm + 选择桌面 localRunner 执行
6. 日志实时回写到小程序聊天
7. 每个高风险步骤执行前数字确认
8. 支持 stop/retry
```

## 最终产品表达

用户看到的是：

```text
这个 GitHub 项目有一个 Fabushi 小程序。
打开它，按提示回复数字，就能一步步在自己的设备上完成安装、部署、启动和验证。
```

平台能力表达：

```text
桌面端最大化脚本执行能力。
移动端也有脚本能力，并可控制自己的桌面端本地执行复杂任务。
本地能运行的都本地运行，不默认交给公共云端。
```
