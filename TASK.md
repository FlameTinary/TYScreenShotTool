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

Temp PNG

↓

Clipboard

↓

Desktop PNG

---

## 必须完成

1. 将截图结果写入系统剪贴板

2. 保持现有 PNG 保存能力

要求：

- 成功时最终保存到桌面
- 复制成功后才生成最终桌面 PNG

3. 如果复制失败，则本次截图整体失败

要求：

- 控制台输出明确失败信息
- 不保留本次生成的 PNG 文件

4. 控制台输出复制成功信息

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

并且桌面最终生成一个 PNG 文件。

说明截图复制链路已打通。

如果复制失败：

- 控制台输出失败信息
- 桌面不应保留本次截图 PNG

---

遵循：

MVP

KISS

YAGNI
