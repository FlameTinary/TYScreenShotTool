# AGENTS.md

## 项目定位

这是一个个人使用的 macOS 截图工具项目。

目标不是商业化产品，也不是为了替代市面上的成熟截图软件。

项目目标：

* 学习 macOS 原生开发
* 建立个人工具链
* 探索 AI 辅助开发流程
* 积累长期维护的个人项目
* 后续逐步演进为 AI 截图助手

开发者为单人开发。

请优先考虑：

* 简单
* 可维护
* 易理解
* 原生技术栈

不要过度设计。

---

# 开发原则

## MVP优先

始终优先实现最小可运行版本。

不要提前开发未来功能。

不要为了未来可能存在的需求增加复杂度。

遵循：

能工作 > 很优雅

---

## 原生优先

优先使用 Apple 官方框架。

首选：

* Swift
* SwiftUI
* AppKit
* ScreenCaptureKit
* Vision
* Foundation
* UserNotifications

未经明确要求，不要引入第三方依赖。

---

## 小步迭代

每次只实现一个明确功能。

功能完成后：

* 编译通过
* 可以运行
* 人工验证

再开始下一个功能。

---

## 可读性优先

优先保证代码易读。

要求：

* 文件不要过大
* 函数不要过长
* 命名清晰
* 逻辑简单

不要为了设计模式而设计模式。

---

# 技术栈

语言：

Swift 6

平台：

macOS 15+

界面：

SwiftUI

截图：

ScreenCaptureKit

通知：

UserNotifications

存储：

FileManager

---

# 项目结构

ScreenshotTool/

App/
Features/
Services/
Shared/
Resources/

请遵守现有目录结构。

不要随意新增顶级目录。

---

# 模块职责

## Features

业务功能模块。

例如：

Capture
Hotkey

---

## Services

系统能力封装。

例如：

ScreenCaptureService
ImageSaveService
NotificationService

---

## Shared

公共代码。

例如：

Models
Utilities
Extensions

---

# 命名规范

推荐：

CaptureManager
ImageSaveService
NotificationService

避免：

Manager
Helper
Utils
Tool

这种缺乏语义的命名。

---

# 错误处理

不要忽略错误。

禁止：

try?

空 catch

静默失败

应提供明确错误信息。

---

# 注释规范

代码应尽量自解释。

仅在必要时添加注释。

避免描述显而易见的逻辑。

---

# 文档边界

`AGENTS.md` 仅描述项目长期稳定的工程约束与开发原则。

以下内容不应以 `AGENTS.md` 为准，而应分别参考对应文档：

* 当前版本与长期路线：`README.md`
* 当前迭代阶段与 Sprint 顺序：`docs/ROADMAP.md`
* 当前唯一任务范围：`TASK.md`
* 单个 Sprint 的目标、边界、实现与结果：`docs/SPRINTS`
* AI Agent 的工作流程与评审流程：`SKILL.md`

避免在 `AGENTS.md` 中重复维护以下高频变化信息：

* 当前版本号
* 当前 Sprint
* 当前任务目标
* 当前明确不做
* AI 工作流程步骤
* 输出格式要求

---

# 工作风格

请以资深 macOS 工程师的方式工作。

保持务实。

优先交付可运行结果。

不要追求理论上的完美架构。
