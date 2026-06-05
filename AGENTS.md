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

# 当前开发目标

当前版本：

V0.1

目标流程：

用户按下：

⌘⇧2

↓

进入截图模式

↓

框选区域

↓

保存 PNG 到桌面

↓

收到保存成功通知

仅实现该流程所需功能。

---

# 当前明确不做

以下功能暂不实现：

* OCR
* AI分析
* 图片标注
* 云同步
* 历史记录
* 设置页面
* 滚动截图
* 录屏
* 图床上传
* 多语言支持

除非收到明确需求。

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

# 实施任务前

请先：

1. 理解需求
2. 查看现有代码结构
3. 评估是否已有可复用代码
4. 简述实现方案
5. 再开始编码

---

# 完成任务后

请输出：

## 实现内容

完成了什么

## 修改文件

修改了哪些文件

## 下一步建议

推荐最小下一步迭代

---

# 工作风格

请以资深 macOS 工程师的方式工作。

保持务实。

优先交付可运行结果。

不要追求理论上的完美架构。
