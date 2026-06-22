# TShot

Version: v1.0.0+

Current Sprint: Sprint 42 Completed

---

## 当前状态

Sprint 42 已完成实现、构建验证与人工验证。

## 当前目标

将 OCR / AI 结果窗口内容层迁移为 SwiftUI，并明确 AppKit 布局优先使用 SnapKit 的后续规则。

---

## 本次范围

1. 确认 SnapKit 已接入 App target
2. 新增 SwiftUI OCR 结果视图
3. 新增 SwiftUI AI 结果视图
4. 保留 AppKit `NSPanel` 外壳与窗口摆放逻辑
5. 使用 `NSHostingView` 承载 SwiftUI 内容
6. AppKit 外壳布局使用 SnapKit
7. 保持普通截图与长截图中的 OCR / AI 结果窗口行为一致

---

## 验收标准

1. `./scripts/build.sh` 构建通过
2. 普通截图 OCR 结果窗口可正常显示，文本仍可选中，并且复制和取消行为保持不变
3. 长截图 OCR 结果窗口可正常显示，文本仍可选中，并且复制和取消行为保持不变
4. 普通截图 AI 在开发报错分析、摘要总结、界面结构识别、翻译模式下都可正常显示
5. 长截图 AI 在至少一个多 section 模式和一个单 section 模式下都可正常显示
6. AI loading / result / error 三态行为保持不变
7. AI 复制全部、模式对应的二级复制、重试、关闭行为保持不变
8. OCR / AI 结果窗口继续根据选区左右空间摆放
9. 结果窗口迁移后不引入额外材质背景，视觉风格保持与现有 AppKit 外壳一致
10. 截图 Overlay、标注画布、工具栏、长截图捕获主链路不受影响
