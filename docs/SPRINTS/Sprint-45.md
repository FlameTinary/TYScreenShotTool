# Sprint 45 - 纯 AppKit + SnapKit UI 迁移

## Status

🚧 In Progress

## Goal

在一个 Sprint 中一次性移除业务 UI 对 SwiftUI 的依赖，并将菜单栏、Settings、结果窗和长截图 UI 统一迁移为纯 AppKit + SnapKit。

---

## Scope

### Included

- App 入口改为 `AppDelegate + NSStatusItem`
- Settings 改为纯 AppKit
- OCR / AI 结果窗改为纯 AppKit
- 长截图控制面板与预览窗改为纯 AppKit
- 清理 `NSHostingView`、`NSHostingController`、`NSViewRepresentable`

### Out of Scope

- 不改截图主状态机
- 不改 OCR / AI 请求链路
- 不改 Overlay 与标注画布主体结构
