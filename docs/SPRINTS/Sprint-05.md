# Sprint 05 - 接入真实截图能力（ScreenCaptureKit）

## Sprint Goal

将 Sprint 03 的选区能力与 Sprint 04 的 Capture Session 生命周期管理接入真实截图能力。

实现以下最小链路：

HotKey
→ Overlay
→ Selection Rect
→ ScreenCaptureKit
→ CGImage

验证能够成功获取截图结果。

---

## Scope

### Included

- 接入 ScreenCaptureKit
- 获取真实 CGImage
- 支持多显示器截图
- 支持 Retina 显示器
- 屏幕录制权限检查
- 截图成功日志输出

### Excluded

- PNG 保存
- 剪贴板
- OCR
- AI
- 历史记录
- 设置页面

---

## Implementation

### 新增

- ScreenCaptureService

职责：

- 屏幕录制权限检查
- ScreenCaptureKit 封装
- 返回 CGImage

---

### macOS 15.2+

使用：

SCScreenshotManager.captureImage(in:)

特点：

- 输入全局屏幕坐标
- 直接返回 CGImage
- 支持多显示器

---

### macOS 15.0 ~ 15.1

兼容路径：

- SCShareableContent
- SCContentFilter
- SCStreamConfiguration
- sourceRect
- captureImage(contentFilter:)

---

### 坐标转换

使用：

window.convertRectToScreen(...)

不再手动计算：

screen.origin + localRect

不做 Y 轴翻转。

---

### 生命周期保持不变

Capture State：

Idle
→ OverlayPresented
→ Dragging
→ SelectionCompleted
→ Idle

未新增任何状态。

---

## Validation

### 单显示器

成功输出：

Capture Success

width: xxxx
height: xxxx

---

### 双显示器

测试结果：

Selection Rect
x: -1440
y: 84
width: 1122
height: 697

Capture Success
width: 2246
height: 1398

验证：

- 多显示器坐标正常
- ScreenCaptureKit 截图正常
- Retina 缩放正常

---

### ESC 测试

Overlay 状态下：

ESC

输出：

OverlayPresented → Idle

通过。

---

## Result

Sprint 05 完成。

当前项目已经具备：

- 全局热键
- Overlay 选区
- 生命周期状态机
- ScreenCaptureKit 截图
- 多显示器支持

下一阶段进入：

Sprint 06 - PNG 自动保存