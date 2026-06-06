# TYScreenShotTool

Version: V0.1

Current Sprint: Sprint 08

---

## 目标

在 Sprint 07 已完成剪贴板复制的基础上，
实现截图结果进入 OCR 链路。

流程：

Selection Rect

↓

ScreenCaptureKit

↓

CGImage

↓

OCR

↓

Text

---

## 必须完成

1. 对截图结果执行文字识别

2. 输出 OCR 识别结果

例如：

OCR Success

text: ...

3. 保持现有截图、PNG 保存、剪贴板复制能力不受影响

4. OCR 失败时输出明确错误信息

例如：

OCR failed: ...

---

## 不做

通知

PNG 命名配置

保存目录配置

AI

设置页

历史记录

OCR 结果预览界面

---

## 验收标准

按下：

⌘⇧2

完成拖拽

控制台输出：

OCR Success

text

并且现有 PNG 保存与剪贴板复制链路仍正常可用。

说明 OCR 主链路已打通。

---

遵循：

MVP

KISS

YAGNI
