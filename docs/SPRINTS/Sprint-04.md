# Sprint 04 - Capture Session State Machine

## Status

Completed ✅

## Goal

为截图流程建立统一的 Capture Session 生命周期管理。

将 HotKey、Overlay、Dragging、Selection 等行为纳入统一状态机管理，避免 UI 层直接控制业务流程。

---

## Scope

### Included

* CaptureState
* CaptureSessionService
* Session 生命周期管理
* Overlay 与 Session 解耦
* 状态流转日志

### Excluded

* ScreenCaptureKit
* 实际截图
* PNG 保存
* OCR
* AI 能力
* 设置页面

---

## Final State Flow

Idle

↓

OverlayPresented

↓

Dragging

↓

SelectionCompleted

↓

Idle

取消流程：

Idle

↓

OverlayPresented

↓

Idle

---

## Acceptance Criteria

### Scenario 1

按下：

⌘⇧2

输出：

[CaptureSession] Idle -> OverlayPresented

---

### Scenario 2

开始拖拽：

输出：

[CaptureSession] OverlayPresented -> Dragging

---

### Scenario 3

完成选区：

输出：

[CaptureSession] Dragging -> SelectionCompleted

Selection Rect

x
y
width
height

[CaptureSession] SelectionCompleted -> Idle

---

### Scenario 4

ESC 取消：

输出：

[CaptureSession] OverlayPresented -> Idle

---

## Deliverables

新增：

* Shared/CaptureState.swift
* Services/CaptureSessionService.swift

修改：

* CaptureOverlayService.swift
* CaptureOverlayView.swift
* TYScreenShotToolApp.swift

---

## Result

完成统一 Capture Session 生命周期管理。

后续所有截图、保存、OCR、AI 等能力都将在 SelectionCompleted 节点后继续扩展。
