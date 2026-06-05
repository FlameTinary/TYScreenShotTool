# Development Log

---

# 2026-06-05

## Sprint 01 完成

### Menu Bar App

实现：

- SwiftUI MenuBarExtra
- 菜单栏运行模式
- 隐藏 Dock 图标
- Quit 菜单

新增：

- App 目录
- Features 目录
- Services 目录
- Shared 目录
- Resources 目录

项目从普通 SwiftUI App 转换为 Menu Bar App。

---

## Sprint 02 完成

### Global Hotkey

实现：

- Carbon RegisterEventHotKey
- 全局快捷键注册
- ⌘⇧2

输出：

Screenshot shortcut triggered

新增：

- ScreenshotHotKey
- GlobalHotKeyService

项目具备全局唤起能力。

---

## Sprint 03 完成

### Capture Overlay

实现：

- Overlay Window
- Overlay View
- 多显示器支持
- 十字光标
- ESC退出
- 拖拽选区
- Selection Rect 输出

新增：

- CaptureOverlayWindow
- CaptureOverlayView
- CaptureOverlayService

项目具备完整截图交互壳层。

---

## Sprint 04 完成

### Capture Session State Machine

实现：

状态：

- Idle
- OverlayPresented
- Dragging
- SelectionCompleted

新增：

- CaptureState
- CaptureSessionService

统一管理：

- 热键
- Overlay
- Session 生命周期

---

### Bug Fix

#### ESC 无法退出 Overlay

问题：

Borderless Window 默认无法成为 Key Window。

导致：

ESC 无法响应。

修复：

CaptureOverlayWindow：

canBecomeKey = true

canBecomeMain = true

修复后：

ESC 正常退出。

---

## 当前项目能力

已完成：

✓ Menu Bar App

✓ Global Hotkey

✓ Capture Overlay

✓ Capture Session

✓ 多显示器支持

✓ ESC取消

✓ Selection Rect

下一阶段：

Sprint 05 - ScreenCaptureKit