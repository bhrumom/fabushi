# 修复 Flutter Web 端文件传输功能

## Core Features

- 修复Web平台因文件API不兼容导致的文件发送错误

- 通过抽象和条件导入重构文件服务，实现跨平台兼容性

## Tech Stack

{
  "Mobile App": {
    "platform": "Flutter",
    "language": "Dart",
    "description": "采用条件导入（Conditional Imports）技术，为移动端（`dart:io`）和Web端（`dart:html`）提供不同的文件服务实现，并通过一个抽象层统一接口调用，解决Web平台兼容性问题。"
  }
}

## Design

本次任务为功能修复，不涉及UI或视觉设计的变更，重点在于优化底层代码架构以实现跨平台兼容。

## Plan

Note: 

- [ ] is holding
- [/] is doing
- [X] is done

---

[X] 创建抽象服务层：定义一个 `AbstractFileService` 抽象类，包含文件选择、读取和发送等核心方法的接口。

[X] 重构原生平台实现：将现有的 `file_service.dart` 重命名为 `file_service_io.dart`，并使其实现 `AbstractFileService` 接口，作为移动和桌面端的实现。

[X] 开发Web平台实现：创建 `file_service_web.dart` 文件，使用 `dart:html` 或 `file_picker` 库实现 `AbstractFileService` 接口，以处理Web环境下的文件操作。

[X] 设置条件导出：创建一个新的 `file_service.dart` 文件，利用条件导入（Conditional Import）机制，根据 `kIsWeb` 标志来决定导出 `file_service_io.dart` 还是 `file_service_web.dart`。

[X] 更新UI调用逻辑：修改UI层代码，确保所有对文件服务的调用都通过 `AbstractFileService` 接口进行，而不是直接依赖于具体实现。

[/] 全面测试与验证：分别在Web、iOS和Android平台上编译并运行应用，验证Web端文件传输功能已修复，并确保移动端原有功能未受影响。
