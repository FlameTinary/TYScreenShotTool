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

## Sprint 05

日期：2026-06-05

### Goal

接入真实截图能力。

### Completed

#### ScreenCaptureService

新增独立截图服务：

- 权限检查
- ScreenCaptureKit 封装
- 返回 CGImage

---

#### ScreenCaptureKit

实现双路径支持：

macOS 15.2+

- captureImage(in:)

macOS 15.0~15.1

- SCShareableContent
- SCContentFilter
- SCStreamConfiguration
- captureImage(contentFilter:)

---

#### 坐标转换

改用：

window.convertRectToScreen(...)

统一转换到全局屏幕坐标。

---

#### 生命周期

保持 Sprint 04 四状态：

Idle
OverlayPresented
Dragging
SelectionCompleted

未新增截图相关状态。

---

### Validation

#### 单显示器

验证通过。

成功输出：

Capture Success

---

#### 双显示器

验证通过。

副显示器坐标：

x = -1440

截图成功。

---

#### Retina

验证通过。

截图尺寸约为选区尺寸 2 倍。

---

#### ESC

验证通过。

Overlay 可正常退出。

---

### Outcome

项目首次具备真实截图能力。

MVP 已完成：

HotKey
→ Overlay
→ Selection
→ ScreenCaptureKit
→ CGImage

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

✓ ScreenCaptureKit

下一阶段：

