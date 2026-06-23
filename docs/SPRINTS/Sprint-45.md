# Sprint 45 - 纯 AppKit + SnapKit UI 迁移

## Status

✅ Done

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

---

## Implementation

### 实现

- App 启动入口从 `SwiftUI App` 收口为纯 `@main AppDelegate`
- 菜单栏统一改为 `NSStatusItem` 管理
- Settings 窗口改为纯 AppKit + SnapKit，补齐完整 section 结构与 action wiring
- OCR 结果窗与 AI 结果窗移除 `NSHostingView`，改为纯 AppKit 内容层
- 长截图控制面板与预览窗口移除 SwiftUI 内容层，统一为纯 AppKit + SnapKit
- 保留 Overlay、标注画布、窗口摆放等原有 AppKit 主链路，不额外改动业务状态机
- 新增语言切换通知刷新链路，菜单栏、Settings 与结果窗可即时更新文案
- 针对窄宽度场景收口结果窗与设置页布局，避免按钮区与内容区挤压失真
- 移除业务 UI 对 `NSHostingView`、`NSHostingController`、`NSViewRepresentable` 的依赖
- 文档与协作规则统一更新为 AppKit + SnapKit 技术方向

### 启动链修正

- 迁移过程中曾短暂引入混合入口，导致菜单栏图标不可见、全局截图热键不触发
- 最终入口统一为纯 `AppDelegate.swift` 启动
- 清理 storyboard 残留配置，保证运行时只存在一条启动链

---

## Validation

1. `xcodebuild -project TYScreenShotTool.xcodeproj -scheme TYScreenShotTool -configuration Debug clean build` 构建通过
2. App 启动后菜单栏图标可见
3. 当前配置的全局截图热键可正常进入截图态
4. Settings 入口可正常打开，HotKey / 保存目录 / OCR / 语言 / 外观 section 可用
5. 普通截图 OCR / AI 结果窗人工验证通过
6. 长截图控制面板、预览窗、OCR / AI 结果窗人工验证通过
7. 语言切换后菜单栏与 Settings 文案可即时刷新
8. 迁移后截图、OCR、AI、长截图主链路未回退

---

## Result

Sprint 45 完成后，TShot 的业务 UI 已彻底移除 SwiftUI 依赖，统一回到纯 AppKit + SnapKit 技术栈。
本轮同时完成了 Settings 页面重建、结果窗与长截图 UI 收口、窄宽度适配、语言切换刷新链路，以及启动入口稳定化修复。

当前仓库的历史 Sprint 42 / 43 仍保留为真实演进记录；
但从 Sprint 45 开始，项目当前有效的 UI 方向已经明确为纯 AppKit + SnapKit。
