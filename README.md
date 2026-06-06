# ScreenshotTool

一个用于学习 macOS 原生开发和 AI 辅助开发流程的个人项目。

---

## 项目目标

ScreenshotTool 不是为了替代现有截图软件。

项目主要用于：

* 学习 macOS 开发
* 实践 SwiftUI
* 熟悉 ScreenCaptureKit
* 探索 AI 编程工作流
* 构建个人效率工具

未来将逐步扩展为：

AI Screenshot Assistant

即：

截图 → OCR → AI分析 → 输出结果

---

## 开发路线图

### V0.1

基础截图功能

功能：

* 菜单栏应用
* 全局快捷键
* 框选截图
* 保存 PNG
* 保存到桌面
* 自动复制到剪贴板

---

### V0.2

OCR

功能：

* 图片文字识别

---

### V0.3

设置增强

功能：

* HotKey 配置
* 保存目录配置
* OCR 开关

---

### V0.4

AI分析

功能：

* 截图发送给AI
* 分析代码报错
* 分析UI界面
* 分析文档内容

---

### V1.0

AI Screenshot Assistant

目标：

截图不仅是保存图片。

而是成为工作流入口。

例如：

截图代码

↓

AI解释错误

↓

提供修复方案

或者：

截图设计稿

↓

生成 SwiftUI 代码

---

## 技术栈

* Swift 6
* SwiftUI
* AppKit
* ScreenCaptureKit
* Vision
* UserNotifications

---

## 项目结构

ScreenshotTool/

├── App/
├── Features/
├── Services/
├── Shared/
└── Resources/

---

## 开发原则

* MVP优先
* 原生优先
* 小步迭代
* 可读性优先
* 尽量减少第三方依赖

---

## 当前状态

当前开发阶段：

V0.3 前置能力已基本完成

当前目标：

在已完成截图、PNG 保存、剪贴板、OCR、最小设置入口的基础上，
继续推进 AI 分析能力。

流程：

⌘⇧2

↓

框选区域

↓

保存 PNG 到桌面

↓

自动复制到剪贴板

↓

执行 OCR

---

说明：

* 当前精确迭代阶段以 `docs/ROADMAP.md` 为准
* 当前唯一任务范围以 `TASK.md` 为准

---

## 长期愿景

打造一个真正服务于开发者自己的 AI 工作助手。

从截图开始，但不止于截图。
