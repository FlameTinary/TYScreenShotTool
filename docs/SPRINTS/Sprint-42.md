# Sprint 42 - 结果窗口 SwiftUI 化与 AppKit 布局规范

## Status

✅ Done

## Goal

将 OCR / AI 结果窗口内容层迁移为 SwiftUI，并明确 AppKit 布局优先使用 SnapKit 的后续规则。

---

## Scope

### Included

- OCR 结果窗口内容 SwiftUI 化
- AI 结果窗口内容 SwiftUI 化
- 保留 AppKit `NSPanel` 外壳与窗口摆放逻辑
- AppKit 外壳布局使用 SnapKit
- 普通截图与长截图中的 OCR / AI 结果窗口行为保持一致

### Out of Scope

- 不迁移截图 Overlay
- 不迁移标注画布
- 不迁移截图工具栏
- 不迁移长截图控制面板
- 不迁移矩形属性面板
- 不改变 OCR / AI 输入链路
- 不改变 AI prompt、模型配置或网络请求结构

---

## Implementation

### 实现

- 确认 SnapKit 已接入 App target
- 新增 SwiftUI OCR 结果视图 (`OCRPreviewView`)
- 新增 SwiftUI AI 结果视图 (`AIAnalysisPreviewView`)
- `OCRPreviewWindowService` 保留 AppKit 窗口外壳，并通过 `NSHostingView` 承载 SwiftUI 内容
- `AIAnalysisPreviewWindowService` 保留 AppKit 窗口外壳，并通过 `NSHostingView` 承载 SwiftUI 内容
- AppKit 外壳布局使用 SnapKit
- 在 `AGENTS.md` 中明确后续 UI 实现优先级

---

## Validation

1. `./scripts/build.sh` 构建通过
2. 普通截图 OCR 结果窗口人工验证通过，文本仍可选中，并且复制和取消行为保持不变
3. 长截图 OCR 结果窗口人工验证通过，文本仍可选中，并且复制和取消行为保持不变
4. 普通截图 AI 在开发报错分析、摘要总结、界面结构识别、翻译模式下人工验证通过
5. 长截图 AI 在多 section 模式和单 section 模式下人工验证通过
6. AI loading / result / error 三态行为人工验证通过
7. AI 复制全部、模式对应的二级复制、重试、关闭行为人工验证通过
8. OCR / AI 结果窗口继续根据选区左右空间摆放，人工验证通过
9. 结果窗口迁移后未引入额外材质背景，视觉风格与现有 AppKit 外壳一致，人工验证通过
10. 截图 Overlay、标注画布、工具栏、长截图捕获主链路人工验证未受影响

---

## Result

Sprint 42 已完成 OCR / AI 结果窗口的 SwiftUI 内容迁移、SnapKit 接入、code review 收口、构建验证与人工验证。
本轮结果可作为后续面板和工具栏迁移的参考样板。
