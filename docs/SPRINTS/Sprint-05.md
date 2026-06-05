# Sprint 05 - ScreenCaptureKit 截图能力

## 目标

实现真正截图。

根据 Overlay 选区矩形：

Selection Rect
↓

ScreenCaptureKit
↓

CGImage

完成截图数据获取。

---

## 本 Sprint 范围

实现：

- 获取选区矩形
- 调用 ScreenCaptureKit
- 返回 CGImage
- 输出截图尺寸日志

---

## 不实现

- PNG保存
- 剪贴板
- OCR
- AI
- 历史记录
- 设置页

---

## 验收标准

按下：

⌘⇧2

出现 Overlay

拖拽选区

完成选择

Console 输出：

Capture Success

width: xxx

height: xxx

---

## 完成标志

获得真实截图图像数据。

即：

CGImage 成功生成。