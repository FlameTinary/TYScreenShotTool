# Sprint 04 - Capture Session State Machine

## Sprint Goal

引入统一 Capture Session 生命周期管理。

将截图流程从分散逻辑改为状态驱动。

---

## User Story

作为用户：

当我按下 ⌘⇧2 时，

我希望：

进入截图模式

完成选区

退出截图模式

整个流程状态明确且可维护。

---

## Scope

实现：

* CaptureState
* CaptureSessionService
* 状态切换日志
* Overlay 与 Session 解耦

不实现：

* ScreenCaptureKit
* 实际截图
* PNG 保存
* OCR
* AI

---

## Capture Flow

Idle

↓

OverlayPresented

↓

Dragging

↓

SelectionCompleted

↓

Idle

---

## Acceptance Criteria

启动应用

↓

按下 ⌘⇧2

Console 输出：

Capture State:
Idle -> OverlayPresented

开始拖拽：

Capture State:
OverlayPresented -> Dragging

完成拖拽：

Capture State:
Dragging -> SelectionCompleted

Overlay 自动关闭

Capture State:
SelectionCompleted -> Idle

ESC：

Capture State:
OverlayPresented -> Idle

---

## Expected Directory Changes

新增：

Shared/CaptureState.swift

Services/CaptureSessionService.swift

修改：

Services/CaptureOverlayService.swift

Services/GlobalHotKeyService.swift

App/TYScreenShotToolApp.swift

---

## Done Definition

满足以下条件：

* 编译成功
* 状态切换正常
* Overlay 正常工作
* 不影响 Sprint 03 功能
* 所有状态均输出日志
