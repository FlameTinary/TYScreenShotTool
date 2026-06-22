# Sprint 43 - 长截图控制面板与预览窗口 SwiftUI 化

## Status

✅ Done

## Goal

将长截图控制面板与预览窗口的内容层迁移为 SwiftUI，保留 AppKit `NSPanel` 外壳与窗口摆放逻辑，并将长截图 AI 入口改为 SwiftUI `Popover`。

---

## Scope

### Included

- 长截图控制面板内容层 SwiftUI 化
- 长截图预览窗口内容层 SwiftUI 化
- 长截图 AI 入口从 `NSMenu` 改为 SwiftUI `Popover`
- 预览窗口补齐启动占位态
- AppKit 外壳布局统一使用 SnapKit

### Out of Scope

- 不重写长截图拼接算法
- 不修改 OCR / AI 请求链路
- 不修改 OCR / AI 结果窗口语义
- 不迁移普通截图工具栏、Overlay、标注画布

---

## Implementation

- 新增 `ScrollingCaptureAIPopoverView`
- 新增 `ScrollingCaptureControlPanelView`
- 新增 `ScrollingCapturePreviewContentView`
- `ScrollingCapturePanelService` 改为通过 `NSHostingView` 承载 SwiftUI 控制面板
- 长截图控制面板外壳最终收口为 `borderless` `NSPanel`，避免标题栏安全区导致的额外高度
- `ScrollingCapturePreviewWindowService` 改为通过 `NSHostingView` 承载 SwiftUI 预览内容
- `CaptureSessionService` 在进入长截图模式后先显示预览占位态

---

## Validation

1. `./scripts/build.sh` 构建通过
2. 长截图控制面板人工验证通过
3. 长截图控制面板高度异常修复后人工验证通过
4. 长截图 AI Popover 人工验证通过
5. 长截图预览窗口占位态与实时更新人工验证通过
6. OCR / AI 结果窗口反向摆放规则人工验证通过

---

## Result

Sprint 43 完成长截图控制面板与预览窗口的 SwiftUI 内容迁移，并在人工验证后补齐了控制面板高度收口，继续保留 AppKit 窗口外壳与原有长截图主链路，为后续长截图 UI 收口提供统一的 SwiftUI / SnapKit 样板。
