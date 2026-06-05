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
* 保存成功通知

---

### V0.2

截图增强

功能：

* 自动复制到剪贴板
* 文件命名优化
* 截图历史记录

---

### V0.3

OCR

功能：

* 图片文字识别
* 自动复制文本
* OCR结果预览

技术：

Vision Framework

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

V0.1

当前目标：

实现最小可运行截图工具。

流程：

⌘⇧2

↓

框选区域

↓

保存到桌面

↓

通知成功

---

## 长期愿景

打造一个真正服务于开发者自己的 AI 工作助手。

从截图开始，但不止于截图。
