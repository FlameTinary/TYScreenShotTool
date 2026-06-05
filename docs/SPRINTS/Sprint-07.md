# Sprint 07 - Clipboard 支持

## Status

Completed ✅

## Goal

在 Sprint 06 已完成 PNG 自动保存的基础上，
实现截图后自动复制到系统剪贴板。

实现最小链路：

HotKey
→ Overlay
→ Selection Rect
→ ScreenCaptureKit
→ CGImage
→ Temp PNG
→ Clipboard
→ Desktop PNG

验证能够成功粘贴截图结果。

---

## Scope

### Included

- 将截图结果写入系统剪贴板
- 保持现有 PNG 保存能力
- 控制台输出复制成功信息
- 复制失败时输出明确错误信息
- 复制失败时桌面不保留本次 PNG

### Out of Scope

- 保存成功通知
- OCR
- AI 能力
- 历史记录
- 设置页面
- 自定义保存目录
- 文件命名规则配置
- 多格式导出

---

## Implementation

### 新增

- `ClipboardService`

职责：

- 接收 `CGImage`
- 转换为可写入剪贴板的图像对象
- 写入系统剪贴板

---

### 技术方案

使用：

- `AppKit`
- `NSImage`
- `NSPasteboard`

实现流程：

1. 完成截图并得到 `CGImage`
2. 先保存临时 PNG
3. 将 `CGImage` 转换为 `NSImage`
4. 写入 `NSPasteboard.general`
5. 成功后再移动到桌面生成最终 PNG
6. 失败则清理临时文件并输出错误

---

### 集成位置

在 `CaptureSessionService` 完成截图后，
按顺序调用：

1. `ImageSaveService`
2. `ClipboardService`
3. `ImageSaveService`

成功输出：

- `Save Success`
- `path: ...`
- `Clipboard Copy Success`

说明：

- 只有临时保存、剪贴板复制、最终落桌面都成功后，
  才输出成功日志。

失败规则：

- 如果复制失败，则本次截图整体视为失败
- 清理临时文件
- 桌面不保留本次 PNG
- 控制台输出失败信息

保持当前状态机不变：

Idle
→ OverlayPresented
→ Dragging
→ SelectionCompleted
→ Idle

不新增复制相关状态。

---

### 错误处理

需要明确处理：

- 临时文件保存失败
- 剪贴板清空失败
- 剪贴板写入失败
- 临时文件清理失败
- 最终移动到桌面失败

发生错误时：

- 控制台输出明确错误
- 不静默失败

---

## Validation

### 场景 1

按下：

⌘⇧2

拖拽选区后，
桌面最终生成 PNG 文件。

---

### 场景 2

控制台输出：

Save Success

path: /Users/name/Desktop/Screenshot-xxxx.png

Clipboard Copy Success

并且可以在 Preview、聊天框或文档中直接粘贴。

---

### 场景 3

复制失败时：

- 控制台输出失败信息
- 桌面不保留本次截图 PNG

---

### 场景 4

在 Retina 显示器和多显示器环境下，
复制出的图像内容应与保存结果一致。

---

## Result

成功链路验证通过。

Sprint 07 完成后，项目将具备：

- 全局热键触发
- Overlay 框选
- ScreenCaptureKit 真实截图
- 自动保存 PNG 到桌面
- 自动复制截图到剪贴板

当前已验证：

- 控制台输出 `Save Success`
- 控制台输出 `path: ...`
- 控制台输出 `Clipboard Copy Success`
- 可直接粘贴到聊天框
- 桌面最终生成 PNG 文件

当前未验证：

- 人工制造复制失败时的回滚分支

下一步可继续进入通知或 OCR 之前的最小迭代准备。
