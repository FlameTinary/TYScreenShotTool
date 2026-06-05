# Sprint 03 - Capture Overlay MVP

## Sprint Goal

实现截图模式 Overlay，并完成选区交互闭环。

## Status

✅ Completed

---

## Scope

实现：

* 全局快捷键触发 Overlay
* 多显示器 Overlay
* 半透明遮罩
* 十字光标
* 鼠标拖拽选区
* 实时选区边框
* ESC 退出
* 输出选区坐标

明确不实现：

* ScreenCaptureKit
* 实际截图
* PNG 保存
* OCR
* AI 功能
* 设置页面

---

## Technical Decisions

采用：

AppKit

* NSWindow
* NSView

方案

原因：

* Overlay 控制简单
* 多显示器支持简单
* 鼠标事件处理直接
* ESC 处理方便
* 后续可无缝接入 ScreenCaptureKit

---

## Deliverables

新增：

* Features/CaptureOverlay/CaptureOverlayWindow.swift
* Features/CaptureOverlay/CaptureOverlayView.swift
* Services/CaptureOverlayService.swift

修改：

* Services/GlobalHotKeyService.swift
* App/TYScreenShotToolApp.swift

---

## Acceptance Result

验证通过：

1. 菜单栏应用正常运行
2. ⌘⇧2 触发 Overlay
3. 所有显示器显示遮罩
4. 显示十字光标
5. 拖拽显示选区边框
6. 松开鼠标输出选区坐标
7. ESC 正常退出

---

## Notes

当前坐标为屏幕本地坐标。

跨显示器选区暂不支持。

截图能力将在 Sprint 05 实现。
