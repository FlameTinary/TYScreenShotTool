# Sprint 08 - OCR

## Status

Completed ✅

## Goal

在 Sprint 07 已完成截图保存与剪贴板复制的基础上，
实现截图结果进入 OCR 链路，
并输出识别文字结果。

实现最小链路：

HotKey
→ Overlay
→ Selection Rect
→ ScreenCaptureKit
→ CGImage
→ Desktop PNG
→ Clipboard
→ OCR
→ Text

验证能够成功输出可读文本。

---

## Scope

### Included

- 对截图结果执行文字识别
- 控制台输出 OCR 成功信息
- 控制台输出 OCR 识别文本
- OCR 失败时输出明确错误信息
- 保持现有截图、PNG 保存、剪贴板复制链路不受影响

### Out of Scope

- OCR 结果预览界面
- OCR 开关配置
- AI 分析
- 保存成功通知
- 历史记录
- 设置页面
- 云同步
- 多语言支持

---

## Implementation

### 新增

- `OCRService`

职责：

- 接收截图结果
- 调用系统 OCR 能力
- 返回识别文本

---

### 技术方向

使用：

- `Vision`
- `VNRecognizeTextRequest`

最小实现方向：

1. 截图完成后获得 `CGImage`
2. 保持现有 PNG 保存与剪贴板复制链路成功完成
3. 将 `CGImage` 送入 OCR 服务
4. 返回识别文本
5. 控制台输出结果

---

### 集成位置

在 `CaptureSessionService` 完成截图后，
保持现有主链路不变，
在 PNG 保存与剪贴板复制成功节点后增加 OCR 处理。

不新增状态机状态。

保持：

Idle
→ OverlayPresented
→ Dragging
→ SelectionCompleted
→ Idle

---

### 错误处理

需要明确处理：

- OCR 请求执行失败
- 无法获取识别结果
- 识别结果为空

发生错误时：

- 控制台输出明确错误
- 不静默失败

---

## Validation

### 场景 1

按下：

⌘⇧2

拖拽选区后，
现有 PNG 保存与剪贴板复制链路成功，
控制台输出：

OCR Success

text: ...

---

### 场景 2

PNG 保存与剪贴板复制仍正常工作。

---

### 场景 3

当截图中包含中英文文本时，
OCR 能输出可读结果。

---

### 场景 4

OCR 失败时，
控制台输出明确错误信息。

---

## Result

验证通过。

Sprint 08 完成后，项目将具备：

- 全局热键触发
- Overlay 框选
- ScreenCaptureKit 真实截图
- PNG 保存到桌面
- 自动复制到剪贴板
- OCR 文本识别输出

当前已验证：

- 控制台输出 `Save Success`
- 控制台输出 `path: ...`
- 控制台输出 `Clipboard Copy Success`
- 控制台输出 `OCR Success`
- 控制台输出 `text: ...`
- PNG 保存正常
- 剪贴板复制正常
- OCR 可识别实际界面文字

当前未处理：

- `fopen failed for data file: errno = 2 (No such file or directory)` 这条日志来源尚未定位
- OCR 失败分支仍未人工制造验证

下一步进入：

Sprint 09 - 设置页面
