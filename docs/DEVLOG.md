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

✓ PNG 自动保存到桌面

---

## Sprint 06

日期：2026-06-05

### Goal

实现：

CGImage
→ PNG
→ Desktop

---

### Completed

#### ImageSaveService

新增独立保存服务：

- `CGImage` 编码 PNG
- 自动生成毫秒级文件名
- 保存到桌面
- 返回最终保存路径

---

#### Capture Session Integration

在 `CaptureSessionService` 中完成：

- 截图成功后调用 `ImageSaveService`
- 控制台输出 `Save Success`
- 控制台输出实际保存路径

---

#### File Naming

使用：

`Screenshot-yyyy-MM-dd-HH-mm-ss-SSS.png`

避免连续截图重名。

---

### Bug Fix

#### Desktop 写入失败

问题：

应用开启 `App Sandbox`，
无法直接写入真实桌面。

修复：

关闭 target 的 `App Sandbox`。

结果：

PNG 可正常保存到真实桌面目录。

---

#### 选区与截图内容不一致

问题：

AppKit 选区坐标与 ScreenCaptureKit 坐标系不一致。

导致：

截图位置偏移。

修复：

- 增加显示空间坐标转换
- 修正 `sourceRect.y`
- 使用 `NSScreen + displayID` 匹配实际显示器

结果：

选区与最终截图内容一致。

---

### Validation

验证通过：

- 编译通过
- ⌘⇧2 可触发截图
- 桌面成功生成 PNG
- Console 输出保存路径
- Retina 正常
- 多显示器正常
- 选区与截图内容一致

---

### Outcome

Sprint 06 完成。

当前 MVP 链路已具备：

HotKey
→ Overlay
→ Selection Rect
→ ScreenCaptureKit
→ CGImage
→ PNG
→ Desktop

✓ ScreenCaptureKit

下一阶段：
