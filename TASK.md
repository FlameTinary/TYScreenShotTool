# TYScreenShotTool

Version: V0.1

Current Sprint: Sprint 04

## Goal

实现 Capture Session State Machine。

建立统一截图状态管理。

本 Sprint 不实现任何实际截图功能。

---

## Requirements

实现以下状态：

* Idle
* OverlayPresented
* Dragging
* SelectionCompleted

新增：

* CaptureState
* CaptureSessionService

要求：

* 所有状态切换输出日志
* Overlay 不再直接控制业务流程
* Overlay 仅负责 UI 交互
* SessionService 负责状态管理

---

## Acceptance Criteria

启动应用

↓

按下 ⌘⇧2

输出：

Idle -> OverlayPresented

↓

开始拖拽

输出：

OverlayPresented -> Dragging

↓

完成拖拽

输出：

Dragging -> SelectionCompleted

↓

Overlay 自动关闭

输出：

SelectionCompleted -> Idle

↓

按 ESC

输出：

OverlayPresented -> Idle

---

## Out Of Scope

禁止实现：

* ScreenCaptureKit
* 实际截图
* PNG 保存
* OCR
* AI
* 设置页面
* 自定义快捷键

严格遵守 MVP、KISS、YAGNI 原则。
