# Development Log

---

# 2026-06-05

## Sprint 01 完成

### Menu Bar App

实现：

- SwiftUI MenuBarExtra
- 菜单栏运行模式
- 隐藏 Dock 图标
- Quit 菜单

新增：

- App 目录
- Features 目录
- Services 目录
- Shared 目录
- Resources 目录

项目从普通 SwiftUI App 转换为 Menu Bar App。

---

## Sprint 02 完成

### Global Hotkey

实现：

- Carbon RegisterEventHotKey
- 全局快捷键注册
- ⌘⇧2

输出：

Screenshot shortcut triggered

新增：

- ScreenshotHotKey
- GlobalHotKeyService

项目具备全局唤起能力。

---

## Sprint 03 完成

### Capture Overlay

实现：

- Overlay Window
- Overlay View
- 多显示器支持
- 十字光标
- ESC退出
- 拖拽选区
- Selection Rect 输出

新增：

- CaptureOverlayWindow
- CaptureOverlayView
- CaptureOverlayService

项目具备完整截图交互壳层。

---

## Sprint 04 完成

### Capture Session State Machine

实现：

状态：

- Idle
- OverlayPresented
- Dragging
- SelectionCompleted

新增：

- CaptureState
- CaptureSessionService

统一管理：

- 热键
- Overlay
- Session 生命周期

---

### Bug Fix

#### ESC 无法退出 Overlay

问题：

Borderless Window 默认无法成为 Key Window。

导致：

ESC 无法响应。

修复：

CaptureOverlayWindow：

canBecomeKey = true

canBecomeMain = true

修复后：

ESC 正常退出。

---

## Sprint 05

日期：2026-06-05

### Goal

接入真实截图能力。

### Completed

#### ScreenCaptureService

新增独立截图服务：

- 权限检查
- ScreenCaptureKit 封装
- 返回 CGImage

---

#### ScreenCaptureKit

实现双路径支持：

macOS 15.2+

- captureImage(in:)

macOS 15.0~15.1

- SCShareableContent
- SCContentFilter
- SCStreamConfiguration
- captureImage(contentFilter:)

---

#### 坐标转换

改用：

window.convertRectToScreen(...)

统一转换到全局屏幕坐标。

---

#### 生命周期

保持 Sprint 04 四状态：

Idle
OverlayPresented
Dragging
SelectionCompleted

未新增截图相关状态。

---

### Validation

#### 单显示器

验证通过。

成功输出：

Capture Success

---

#### 双显示器

验证通过。

副显示器坐标：

x = -1440

截图成功。

---

#### Retina

验证通过。

截图尺寸约为选区尺寸 2 倍。

---

# 2026-06-07

## Sprint 15 完成

### 基础标注工具

实现：

- 在截图工具栏中增加矩形、圆形、箭头、画笔、文字 5 类基础标注能力
- 标注内容能够实时显示在截图编辑态预览中
- 复制与保存导出结果均包含已添加的标注内容

新增：

- AnnotationTool
- CaptureAnnotation
- CaptureAnnotationCanvasView

修改：

- CaptureOverlayView
- CaptureOverlayService
- CaptureSessionService
- TYScreenShotToolApp

关键修复：

- 修复预览标注与最终导出 PNG 位置不一致问题
- 导出阶段按预览尺寸统一缩放标注坐标，保证预览与最终结果一致

验证结果：

- 工程编译通过
- 5 类标注工具均可正常使用
- 保存后的 PNG 与预览标注位置一致
- 复制结果包含标注内容
- 圆角、阴影、复制、保存、取消主链路保持正常

#### ESC

验证通过。

Overlay 可正常退出。

---

### Outcome

项目首次具备真实截图能力。

MVP 已完成：

HotKey
→ Overlay
→ Selection
→ ScreenCaptureKit
→ CGImage

---

## 当前项目能力

已完成：

✓ Menu Bar App

✓ Global Hotkey

✓ Capture Overlay

✓ Capture Session

✓ 多显示器支持

✓ ESC取消

✓ Selection Rect

---

# 2026-06-06

## Sprint 13 补充修复

### 工具栏截图交互收紧

修复：

- 热键唤起 overlay 后可直接开始拖拽
- 连续多次热键截图时无需先额外点击一次
- 拖拽完成后仅保留选区，不再立刻执行真实截图
- 点击复制或保存时才真正调用截图能力
- 导出前临时隐藏 overlay，避免白色选区边框被截入结果图
- 导出失败时恢复当前 overlay，保留用户操作上下文

调整：

- `TYScreenShotToolApp`
- `CaptureOverlayService`
- `CaptureOverlayView`
- `CaptureOverlayWindow`
- `CaptureSessionService`

验证：

- 编译通过
- 连续多次热键截图验证通过
- 工具栏复制与保存触发时机符合预期
- 最终导出 PNG 白边问题修复通过

---

# 2026-06-06

## Sprint 13 完成

### 截图工具栏基础

实现：

- 框选完成后不再自动复制、保存或 OCR
- 截图进入预览编辑态
- 增加底部工具栏：复制、保存、取消
- 增加顶部悬浮设置栏：尺寸、圆角、阴影
- 保存与复制前按当前样式重新导出图片

新增：

- `CapturePreviewStyle`

调整：

- `CaptureOverlayView`
- `CaptureOverlayService`
- `CaptureSessionService`
- `TYScreenShotToolApp`

验证：

- 编译通过
- 工具栏交互正常
- 保存后的 PNG 正常生成
- 剪贴板复制正常
- 圆角、阴影在最终导出 PNG 中生效
- 控制台输出保存成功日志

结果：

项目完成最小截图工具栏主链路，为后续标注与动作扩展提供交互基础。

✓ PNG 自动保存到桌面

---

## Sprint 06

日期：2026-06-05

### Goal

实现：

CGImage
→ PNG
→ Desktop

---

### Completed

#### ImageSaveService

新增独立保存服务：

- `CGImage` 编码 PNG
- 自动生成毫秒级文件名
- 保存到桌面
- 返回最终保存路径

---

#### Capture Session Integration

在 `CaptureSessionService` 中完成：

- 截图成功后调用 `ImageSaveService`
- 控制台输出 `Save Success`
- 控制台输出实际保存路径

---

#### File Naming

使用：

`Screenshot-yyyy-MM-dd-HH-mm-ss-SSS.png`

避免连续截图重名。

---

### Bug Fix

#### Desktop 写入失败

问题：

应用开启 `App Sandbox`，
无法直接写入真实桌面。

修复：

关闭 target 的 `App Sandbox`。

结果：

PNG 可正常保存到真实桌面目录。

---

#### 选区与截图内容不一致

问题：

AppKit 选区坐标与 ScreenCaptureKit 坐标系不一致。

导致：

截图位置偏移。

修复：

- 增加显示空间坐标转换
- 修正 `sourceRect.y`
- 使用 `NSScreen + displayID` 匹配实际显示器

结果：

选区与最终截图内容一致。

---

### Validation

验证通过：

- 编译通过
- ⌘⇧2 可触发截图
- 桌面成功生成 PNG
- Console 输出保存路径
- Retina 正常
- 多显示器正常
- 选区与截图内容一致

---

### Outcome

Sprint 06 完成。

当前 MVP 链路已具备：

HotKey
→ Overlay
→ Selection Rect
→ ScreenCaptureKit
→ CGImage
→ PNG
→ Desktop

✓ ScreenCaptureKit

下一阶段：

---

## Sprint 07

日期：2026-06-06

### Goal

实现：

CGImage
→ Clipboard

并保持 PNG 保存链路成立。

---

### Completed

#### ClipboardService

新增独立剪贴板服务：

- `CGImage` 转换为 `NSImage`
- 写入 `NSPasteboard`
- 输出复制成功结果

---

#### Temp PNG Workflow

为满足失败回滚要求，
调整保存链路为：

CGImage
→ Temp PNG
→ Clipboard
→ Desktop PNG

这样在复制失败时，
桌面不会残留本次截图文件。

---

#### Capture Session Integration

在 `CaptureSessionService` 中完成：

- 截图成功后先生成临时 PNG
- 剪贴板复制成功后再移动到桌面
- 成功后输出：
  - `Save Success`
  - `path: ...`
  - `Clipboard Copy Success`

---

### Validation

已验证通过：

- 编译通过
- ⌘⇧2 可触发截图
- 可正常粘贴到聊天框
- 桌面最终生成 PNG
- Console 输出保存路径
- Console 输出复制成功

未验证：

- 人工制造复制失败时的回滚分支

---

### Outcome

Sprint 07 完成。

当前 MVP 链路已具备：

HotKey
→ Overlay
→ Selection Rect
→ ScreenCaptureKit
→ Temp PNG
→ Clipboard
→ Desktop PNG

---

## Sprint 08

日期：2026-06-06

### Goal

实现：

CGImage
→ OCR
→ Text

并保持 PNG 保存与剪贴板复制链路正常。

---

### Completed

#### OCRService

新增独立 OCR 服务：

- 使用 `Vision`
- 使用 `VNRecognizeTextRequest`
- 接收 `CGImage`
- 返回识别文本
- 明确处理空结果与请求失败

---

#### Capture Session Integration

在 `CaptureSessionService` 中完成：

- 截图成功后保持原有保存与剪贴板链路
- 在 `Save Success` 与 `Clipboard Copy Success` 后执行 OCR
- 成功后输出：
  - `OCR Success`
  - `text: ...`
- 失败时输出：
  - `OCR failed: ...`

---

### Validation

已验证通过：

- 构建通过
- `⌘⇧2` 可触发截图
- 桌面 PNG 保存正常
- 剪贴板复制正常
- Console 输出 `OCR Success`
- Console 输出 `text: ...`
- OCR 可识别实际界面中的英文代码文字

未验证：

- 人工制造 OCR 失败分支
- 中文文本识别效果
- `fopen failed for data file: errno = 2 (No such file or directory)` 日志来源

---

### Outcome

Sprint 08 完成。

当前 MVP 链路已具备：

HotKey
→ Overlay
→ Selection Rect
→ ScreenCaptureKit
→ Temp PNG
→ Clipboard
→ Desktop PNG
→ OCR
→ Text

---

## Sprint 09

日期：2026-06-06

### Goal

实现：

Menu Bar
→ Settings Entry
→ Settings Window

并提供最小设置页面入口。

---

### Completed

#### Settings Scene

在 `App` 层增加：

- 原生 `Settings` scene
- 最小 `SettingsView`
- 设置页占位内容

页面中展示：

- `HotKey 配置`
- `保存目录配置`
- `OCR 开关`

---

#### Menu Bar Integration

在菜单栏中增加：

- `Settings` 入口

并修复：

- 首次点击 `Settings` 无法打开页面的问题

最终改为通过 SwiftUI 原生设置打开动作触发设置窗口。

---

#### OCR Fix

在 `OCRService` 中补充识别语言配置：

- `zh-Hans`
- `zh-Hant`
- `en-US`

并启用自动语言检测，
修复中文识别乱码问题。

---

### Validation

已验证通过：

- 构建通过
- 菜单栏 `Settings` 可正常打开
- `Settings` 页面可正常显示
- 页面包含 3 个最小占位项
- 中文 OCR 识别恢复正常
- 现有截图、PNG、Clipboard、OCR 链路正常

---

### Outcome

Sprint 09 完成。

当前 MVP 链路已具备：

HotKey
→ Overlay
→ Selection Rect
→ ScreenCaptureKit
→ Temp PNG
→ Clipboard
→ Desktop PNG
→ OCR

并新增：

Menu Bar
→ Settings Entry
→ Settings Window
