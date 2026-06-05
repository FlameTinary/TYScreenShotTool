# Sprint 06 - PNG 自动保存

## Status

Completed ✅

## Goal

在 Sprint 05 已完成真实截图能力的基础上，
将 `CGImage` 保存为 PNG 文件，
并自动写入桌面目录。

实现最小链路：

HotKey
→ Overlay
→ Selection Rect
→ ScreenCaptureKit
→ CGImage
→ PNG
→ Desktop

验证能够成功生成实际文件。

---

## Scope

### Included

- 将 `CGImage` 编码为 PNG
- 保存到桌面目录
- 自动生成时间戳文件名
- 控制台输出保存结果与文件路径
- 失败时输出明确错误信息

### Out of Scope

- 保存成功通知
- 剪贴板支持
- OCR
- AI 能力
- 历史记录
- 设置页面
- 自定义保存目录
- 文件命名规则配置

---

## Implementation

### 新增

- `ImageSaveService`

职责：

- 接收 `CGImage`
- 编码为 PNG 数据
- 生成文件名
- 保存到桌面
- 返回最终保存路径

---

### 技术方案

使用：

- `ImageIO`
- `CGImageDestination`
- `FileManager`

实现流程：

1. 接收 `CGImage`
2. 生成 `Screenshot-yyyy-MM-dd-HH-mm-ss-SSS.png`
3. 通过 `FileManager` 获取桌面目录
4. 使用 `CGImageDestination` 写入 PNG
5. 返回保存路径

---

### 实际实现补充

- 新增 `ImageSaveService`
- 使用毫秒级时间戳避免连续截图重名
- `CaptureSessionService` 在截图成功后直接保存 PNG
- 控制台输出：
  - `Save Success`
  - `path: ...`
- 为桌面写入关闭 `App Sandbox`

---

### Bug Fix

#### 桌面写入失败

问题：

应用启用了 `App Sandbox`，
无法直接写入真实桌面目录。

修复：

- 关闭 target 的 `App Sandbox`

结果：

PNG 可正常保存到：

`/Users/name/Desktop`

---

#### 截图内容与选区不一致

问题：

Overlay 选区使用的是 AppKit 屏幕坐标，
而 `ScreenCaptureKit` 需要显示空间坐标。

导致：

- 截图位置偏移
- 选区内容与实际保存结果不一致

修复：

- 为 `captureImage(in:)` 增加坐标转换
- 修正兼容路径中的 `sourceRect.y`
- 按 `NSScreen` 与 `displayID` 匹配实际显示器

---

### 集成位置

在 `CaptureSessionService` 完成截图后，
调用 `ImageSaveService` 完成文件写入。

保持当前状态机不变：

Idle
→ OverlayPresented
→ Dragging
→ SelectionCompleted
→ Idle

不新增保存相关状态。

---

### 错误处理

需要明确处理：

- 桌面目录获取失败
- PNG 编码失败
- 文件写入失败

发生错误时：

- 控制台输出明确错误
- 不静默失败

---

## Validation

### 场景 1

按下：

⌘⇧2

拖拽选区后，
桌面生成 PNG 文件。

---

### 场景 2

控制台输出：

Save Success

path: /Users/name/Desktop/Screenshot-xxxx.png

说明保存链路已打通。

---

### 场景 3

在 Retina 显示器下测试，
输出文件尺寸应与真实截图像素一致。

---

### 场景 4

在多显示器环境下测试，
主屏与副屏截图都应能正确保存。

---

## Result

验证通过。

Sprint 06 完成后，项目具备：

- 全局热键触发
- Overlay 框选
- ScreenCaptureKit 真实截图
- 自动保存 PNG 到桌面

并已验证：

- 桌面真实生成 PNG 文件
- 控制台输出保存路径
- Retina 显示器正常
- 多显示器正常
- 选区与实际截图内容一致

这将完成 V0.1 主链路中的保存能力，
下一步即可进入“保存成功通知”或剪贴板能力的最小迭代。
