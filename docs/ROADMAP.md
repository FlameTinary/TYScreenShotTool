# TYScreenShotTool Roadmap

Version: V0.1

Status: In Development

---

# Vision

TYScreenShotTool 是一个专注于效率的 macOS 截图工具。

目标：

- 快速截图
- 简洁体验
- 原生实现
- 最少依赖
- AI 能力可选增强

优先解决：

用户从截图到获得最终结果的时间成本。

---

# Design Principles

始终遵循：

- MVP
- KISS
- YAGNI

优先：

- 小步迭代
- 可验证成果
- 保持代码简单

避免：

- 过度设计
- 提前抽象
- 提前优化

---

# V0.1 MVP

目标：

实现一个可用的截图工具。

---

## Sprint 01

Menu Bar App

Status: Completed

完成：

- MenuBarExtra
- 菜单栏应用
- Quit 菜单

---

## Sprint 02

Global HotKey

Status: Completed

完成：

- ⌘⇧2
- Carbon RegisterEventHotKey

---

## Sprint 03

Capture Overlay

Status: Completed

完成：

- Overlay
- 多显示器支持
- 选区交互
- ESC 退出

---

## Sprint 04

Capture Session State Machine

Status: Completed

完成：

- CaptureState
- CaptureSessionService
- 生命周期管理

---

## Sprint 05

Real Screenshot

Status: Planned

目标：

- ScreenCaptureKit
- 根据选区截图
- 获取 CGImage

交付：

- 截图成功
- Console 输出截图信息

---

## Sprint 06

Save Screenshot

Status: Planned

目标：

- PNG 输出
- 保存到桌面

交付：

- 自动生成截图文件
- 输出保存路径

---

## Sprint 07

Clipboard Support

Status: Planned

目标：

- 自动复制到剪贴板

交付：

- Command + V 可直接粘贴截图

---

## Sprint 08

Preview Window

Status: Planned

目标：

- 截图完成后显示预览

参考：

- Shottr
- CleanShot

---

# V0.2

目标：

增强截图体验。

---

## Planned Features

### Annotation

图片标注

支持：

- 矩形
- 箭头
- 文本

---

### OCR

文字识别

技术方向：

- Vision Framework

---

### History

截图历史记录

支持：

- 最近截图
- 快速复制

---

# V0.3

目标：

AI 增强能力。

---

## Planned Features

### OCR + AI

截图后：

- 提取文字
- 自动总结

---

### Explain Screenshot

截图后：

- AI 分析图片内容
- 生成解释

---

### Ask About Screenshot

截图后：

用户可以直接提问：

"这是什么错误？"

"帮我解释这段代码"

"翻译这段文字"

---

# Success Metrics

V0.1 完成标准：

用户可以：

1. 快捷键截图
2. 选择区域
3. 保存图片
4. 粘贴图片

达到替代系统截图的基本能力。

---

# Non Goals

当前阶段不考虑：

- 云同步
- 团队协作
- 在线存储
- 账户系统
- 插件系统
- 跨平台支持

专注：

macOS 原生截图体验。