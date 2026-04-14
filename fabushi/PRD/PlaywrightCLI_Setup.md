# Playwright CLI 安装记录

## 背景需求
用户要求安装官方的 `playwright-cli`（即 `@playwright/cli`）并使用其自带的 `--skills` 命令来安装 Skill 到全局，以便所有项目都可以使用官方提供的详细 Skill 配置文件，而不是自己手写的一个简单版本。

## 执行过程
1. **安装 CLI 工具**:
   使用 `npm install -g @playwright/cli@latest` 命令将 `playwright-cli` 下载并安装到全局 `.npm-global/bin` 目录中。
   
2. **提取官方 Skill 规则**:
   通过命令 `playwright-cli install --skills agents` 自动获取官方生成的 Skill 文件集合（包括 `SKILL.md` 和附带的多个 `/references` 参考文档）。

3. **全局集成**:
   将生成的 `.agents/skills/playwright-cli` 整个目录复制移动到了全局 Skill 目录：`/Users/gloriachan/.gemini/antigravity/skills/playwright-cli` 下。这样可以确保该配置立刻在全部项目中生效。

4. **环境清理**:
   为了保持项目工作区内容的整洁，清除了临时生成的 `.claude` 和 `.agents` 隐藏配置文件夹。

## 遇到的问题与解决方案
- **问题 1: `npm -g` 的可执行路径问题**: 由于环境中全局包的路径位于 `/Users/gloriachan/.npm-global/bin` 而没有默认处于 `PATH` 中，导致一开始安装完成后报 `command not found: playwright-cli` 错误。
  - **解决方式**: 执行时通过 `export PATH=$PATH:/Users/gloriachan/.npm-global/bin` 将其加入路径执行，确保正确调用 CLI 初始化了 Skill 库。

## 后续建议
现在系统已经获取了官方提供的丰富指令支持：
包括 `playwright-cli goto`, `click`, `snapshot`, `type`, `localstorage-list`, `route` 等。直接指示 Agent *"使用 playwright-cli 代我测试 XYZ"* 即可触发操作。
