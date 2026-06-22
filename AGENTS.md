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

## 架构与实现偏好

优先使用清晰、直接的类型与职责划分。

优先：

* Service
* Struct
* Enum
* 明确职责边界
* 小而清晰的文件划分

避免：

* EventBus
* 复杂状态机
* 过度 Protocol 化
* 为扩展而扩展
* 提前抽象

除非当前任务明确需要，否则不要引入这些复杂设计。

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

# UI 实现优先级

新增或重构界面时，优先级如下：

1. 能使用 SwiftUI 表达的界面，优先使用 SwiftUI
2. 不能使用 SwiftUI、必须保留 AppKit 的地方，AppKit 布局优先使用 SnapKit
3. SwiftUI 和 SnapKit 都不适合的低层场景，才使用手动 `frame` 布局

适合优先使用 SwiftUI 的界面包括：

* 设置页面
* 普通结果展示窗口
* 控制面板
* 属性面板
* 工具栏内容

应继续保留 AppKit 的场景包括：

* 全屏截图 Overlay 窗口
* 多屏窗口层级控制
* 鼠标事件与鼠标穿透
* 截图标注画布绘制
* 全局快捷键与系统能力桥接
* ScreenCaptureKit 相关坐标和窗口处理

当 AppKit 仅作为窗口外壳或系统能力承载层时，
内部可见内容应尽量通过 `NSHostingView` / `NSHostingController` 承载 SwiftUI。

SnapKit 已作为项目允许使用的第三方依赖，
仅用于必须保留 AppKit 的布局代码。

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

# 构建与归档

执行构建与归档时，优先使用项目内脚本：

* `./scripts/build.sh`
* `./scripts/archive.sh`

不要默认直接手写 `xcodebuild` 命令。

只有在脚本本身需要调整、排障或明确要求时，
才直接调用底层 `xcodebuild`。

---

# 注释规范

代码应尽量自解释。

仅在必要时添加注释。

避免描述显而易见的逻辑。

---

# 文档收尾

当某个 Sprint 范围内的功能实现完成，并且构建通过、人工验证通过后，应同步更新相关文档。

通常包括：

* `TASK.md`
* 对应的 Sprint 文档
* `docs/ROADMAP.md`
* `DEVLOG.md`

只更新与本次 Sprint 直接相关的内容，避免顺手改动无关文档。

---

# 文档边界

`AGENTS.md` 仅描述项目长期稳定的工程约束与开发原则。

以下内容不应以 `AGENTS.md` 为准，而应分别参考对应文档：

* 当前版本与长期路线：`README.md`
* 当前迭代阶段与 Sprint 顺序：`docs/ROADMAP.md`
* 当前唯一任务范围：`TASK.md`
* 单个 Sprint 的目标、边界、实现与结果：`docs/SPRINTS`
* 项目文档协作流程：`docs/PROJECT_WORKFLOW.md`
* Git 提交约定：`docs/GIT_WORKFLOW.md`

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
