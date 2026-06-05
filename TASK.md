# TYScreenShotTool

Version: V0.1

Current Sprint: Sprint 07

---

## 目标

在 Sprint 06 已完成 PNG 自动保存的基础上，
实现截图后自动复制到剪贴板。

流程：

Selection Rect

↓

ScreenCaptureKit

↓

CGImage

↓

Clipboard

---

## 必须完成

1. 将截图结果写入系统剪贴板

2. 保持现有 PNG 保存能力不受影响

3. 控制台输出复制成功信息

例如：

Clipboard Copy Success

---

## 不做

通知

PNG 命名配置

保存目录配置

OCR

AI

设置页

历史记录

---

## 验收标准

按下：

⌘⇧2

完成拖拽

控制台输出：

Clipboard Copy Success

并且可以在 Preview、聊天框或文档中直接粘贴截图。

说明截图复制链路已打通。

---

遵循：

MVP

KISS

YAGNI
