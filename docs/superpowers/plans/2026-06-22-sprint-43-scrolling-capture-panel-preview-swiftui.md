# Sprint 43 - 长截图控制面板与预览窗口 SwiftUI 化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将长截图控制面板与预览窗口的内容层迁移为 SwiftUI，保留现有 AppKit `NSPanel` 外壳、窗口定位和长截图主链路不变，并把长截图 AI 入口从 `NSMenu` 收口为 SwiftUI `Popover`。

**Architecture:** 保留 `ScrollingCapturePanelService` 与 `ScrollingCapturePreviewWindowService` 两个 service 作为 AppKit 窗口协调器，继续负责面板生命周期、位置计算、层级和主题刷新；新增专注的 SwiftUI 内容视图，通过 `NSHostingView` 承载；所有仍留在 AppKit 内的布局统一改用 SnapKit，避免继续扩散手动 `frame`。

**Tech Stack:** SwiftUI、AppKit、SnapKit 6.0.0、`NSHostingView`、现有 `CaptureSessionService`/`AIAnalysisMode`/`AppThemeCoordinator`、项目构建脚本 `./scripts/build.sh`。

---

## 规划说明

本计划基于设计文档 [2026-06-22-sprint-43-scrolling-capture-panel-preview-swiftui-design.md](/Users/sheldon/CodeRepo/TYScreenShotTool/docs/superpowers/specs/2026-06-22-sprint-43-scrolling-capture-panel-preview-swiftui-design.md)。

当前关键文件：

- `TYScreenShotTool/Services/ScrollingCapturePanelService.swift`：现有长截图控制面板，内部仍是 AppKit 自绘按钮和 `NSMenu`。
- `TYScreenShotTool/Services/ScrollingCapturePreviewWindowService.swift`：现有长截图预览窗口，内部仍是 AppKit `NSImageView` 和手动 `frame`。
- `TYScreenShotTool/Services/CaptureSessionService.swift`：长截图主链路入口，负责启动长截图、更新预览以及关闭面板。
- `TYScreenShotTool/Shared/AppText.swift`：长截图按钮文案与新增预览占位文案的来源。
- `TYScreenShotTool/Shared/AIAnalysisMode.swift`：SwiftUI AI Popover 需要复用的模式定义。
- `TYScreenShotTool/Shared/AITranslationLanguage.swift`：SwiftUI AI Popover 的翻译语言列表来源。

需要创建的文件：

- `TYScreenShotTool/Features/ScrollingCapture/ScrollingCaptureAIPopoverView.swift`
- `TYScreenShotTool/Features/ScrollingCapture/ScrollingCaptureControlPanelView.swift`
- `TYScreenShotTool/Features/ScrollingCapture/ScrollingCapturePreviewContentView.swift`
- `docs/SPRINTS/Sprint-43.md`

需要修改的文件：

- `TYScreenShotTool/Shared/AppText.swift`
- `TYScreenShotTool/Services/ScrollingCapturePanelService.swift`
- `TYScreenShotTool/Services/ScrollingCapturePreviewWindowService.swift`
- `TYScreenShotTool/Services/CaptureSessionService.swift`
- `TASK.md`
- `docs/ROADMAP.md`
- `docs/DEVLOG.md`

本轮不预期修改：

- `TYScreenShotTool.xcodeproj/project.pbxproj`：项目已使用 `PBXFileSystemSynchronizedRootGroup`，新增 Swift 文件先按自动同步处理，只有构建证明未被纳入 target 时才回头处理工程元数据。
- 长截图拼接算法、滚动监听、OCR/AI 请求与结果窗口摆放逻辑。
- 普通截图工具栏、Overlay、标注画布、矩形属性面板。

---

### Task 1：补齐 Sprint 43 的 SwiftUI 文件骨架与预览占位文案

**Files:**
- Create: `TYScreenShotTool/Features/ScrollingCapture/`
- Modify: `TYScreenShotTool/Shared/AppText.swift`

- [ ] **Step 1: 创建长截图 SwiftUI 视图目录**

运行：

```bash
mkdir -p TYScreenShotTool/Features/ScrollingCapture
find TYScreenShotTool/Features -maxdepth 2 -type d | sort
```

预期输出包含：

```text
TYScreenShotTool/Features/ScrollingCapture
```

- [ ] **Step 2: 在 `AppText` 中新增长截图预览占位文案**

在 `TYScreenShotTool/Shared/AppText.swift` 的长截图相关文案附近加入：

```swift
    static var scrollingCapturePreviewPreparingTitle: String {
        choose(
            zhHans: "等待生成预览",
            en: "Preparing Preview",
            ja: "プレビューを準備中",
            ko: "미리보기를 준비 중",
            de: "Vorschau wird vorbereitet",
            fr: "Préparation de l’aperçu"
        )
    }

    static var scrollingCapturePreviewPreparingMessage: String {
        choose(
            zhHans: "开始滚动后，这里会持续更新长截图预览。",
            en: "The long-capture preview will update here after scrolling starts.",
            ja: "スクロールを開始すると、ここに長いキャプチャのプレビューが更新されます。",
            ko: "스크롤을 시작하면 여기에서 긴 캡처 미리보기가 계속 업데이트됩니다.",
            de: "Sobald du scrollst, wird hier die Vorschau der langen Aufnahme laufend aktualisiert.",
            fr: "Dès que le défilement commence, l’aperçu de la capture longue se met à jour ici."
        )
    }
```

这两个文案用于预览窗口的初始占位态，不再让窗口在首帧出现前完全空白。

- [ ] **Step 3: 构建确认新增目录与文案不影响工程**

运行：

```bash
./scripts/build.sh
```

预期：

```text
** BUILD SUCCEEDED **
```

- [ ] **Step 4: 提交**

```bash
git status --short
git add TYScreenShotTool/Shared/AppText.swift
git commit -m "feat(sprint-43): 补齐长截图预览占位文案"
```

---

### Task 2：新增 SwiftUI AI Popover 视图

**Files:**
- Create: `TYScreenShotTool/Features/ScrollingCapture/ScrollingCaptureAIPopoverView.swift`

- [ ] **Step 1: 新增 `ScrollingCaptureAIPopoverView.swift`**

创建 `TYScreenShotTool/Features/ScrollingCapture/ScrollingCaptureAIPopoverView.swift`：

```swift
//
//  ScrollingCaptureAIPopoverView.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/22.
//

import SwiftUI

struct ScrollingCaptureAIPopoverView: View {
    let onSelect: (AIAnalysisMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(AIAnalysisMode.topLevelModes.enumerated()), id: \.offset) { _, mode in
                    modeButton(title: mode.menuTitle) {
                        onSelect(mode)
                    }
                }
            }

            Divider()

            Text(AppText.aiTranslationMenu)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(AITranslationLanguage.allCases.enumerated()), id: \.offset) { _, language in
                    modeButton(title: language.menuTitle) {
                        onSelect(.translation(language))
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 220, alignment: .leading)
    }

    private func modeButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.06))
        )
    }
}
```

这里不用做“真正的二级弹出子菜单”，而是在一个 Popover 内分组展示“顶层模式”和“翻译语言”，既保留层级感，又避免 AppKit `NSMenu` 的桥接复杂度。

- [ ] **Step 2: 构建确认 Popover 视图可编译**

运行：

```bash
./scripts/build.sh
```

预期：

```text
** BUILD SUCCEEDED **
```

- [ ] **Step 3: 提交**

```bash
git status --short
git add TYScreenShotTool/Features/ScrollingCapture/ScrollingCaptureAIPopoverView.swift
git commit -m "feat(sprint-43): 新增长截图 AI Popover 视图"
```

---

### Task 3：新增 SwiftUI 长截图控制面板视图

**Files:**
- Create: `TYScreenShotTool/Features/ScrollingCapture/ScrollingCaptureControlPanelView.swift`

- [ ] **Step 1: 新增 `ScrollingCaptureControlPanelView.swift`**

创建 `TYScreenShotTool/Features/ScrollingCapture/ScrollingCaptureControlPanelView.swift`：

```swift
//
//  ScrollingCaptureControlPanelView.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/22.
//

import SwiftUI

struct ScrollingCaptureControlPanelView: View {
    let isOCREnabled: Bool
    let isAIEnabled: Bool
    let onCancel: () -> Void
    let onOCR: () -> Void
    let onAISelected: (AIAnalysisMode) -> Void
    let onSave: () -> Void
    let onCopy: () -> Void

    @State private var isAIPopoverPresented = false

    var body: some View {
        ViewThatFits {
            horizontalButtons
            compactButtonRows
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var horizontalButtons: some View {
        HStack(spacing: 10) {
            actionButton(title: AppText.captureCancel, action: onCancel)
            actionButton(title: "OCR", isEnabled: isOCREnabled, action: onOCR)
            aiButton
            actionButton(title: AppText.captureSave, action: onSave)
            actionButton(title: AppText.captureCopy, action: onCopy)
        }
    }

    private var compactButtonRows: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                actionButton(title: AppText.captureCancel, action: onCancel)
                actionButton(title: "OCR", isEnabled: isOCREnabled, action: onOCR)
                aiButton
            }

            HStack(spacing: 10) {
                actionButton(title: AppText.captureSave, action: onSave)
                actionButton(title: AppText.captureCopy, action: onCopy)
            }
        }
    }

    private var aiButton: some View {
        Button {
            isAIPopoverPresented.toggle()
        } label: {
            Text("AI")
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(ScrollingCapturePanelButtonStyle())
        .disabled(isAIEnabled == false)
        .popover(isPresented: $isAIPopoverPresented, arrowEdge: .top) {
            ScrollingCaptureAIPopoverView { mode in
                isAIPopoverPresented = false
                onAISelected(mode)
            }
        }
    }

    private func actionButton(
        title: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(ScrollingCapturePanelButtonStyle())
        .disabled(isEnabled == false)
    }
}

private struct ScrollingCapturePanelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .frame(minHeight: 28)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed ? Color.primary.opacity(0.10) : Color.clear)
            )
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}
```

这一步只做纯 SwiftUI 内容层，不引入业务状态对象，所有动作继续通过闭包回到 service。这里必须把“多语言窄宽度适配”直接纳入控制面板的定义，不能再回到固定单行五等分按钮的布局。

本任务里 `ViewThatFits` 的前提是：横向按钮行必须保留接近内容本身的理想宽度，不能使用 `.frame(maxWidth: .infinity)` 把每个按钮拉伸成“永远能塞下”的状态，也不要用 `.minimumScaleFactor(...)` 通过缩字掩盖布局不足。只有这样，当德语 / 法语文案放不下时，`ViewThatFits` 才会真实切换到双行布局。

- [ ] **Step 2: 构建确认控制面板视图可编译**

运行：

```bash
./scripts/build.sh
```

预期：

```text
** BUILD SUCCEEDED **
```

- [ ] **Step 3: 提交**

```bash
git status --short
git add TYScreenShotTool/Features/ScrollingCapture/ScrollingCaptureControlPanelView.swift
git commit -m "feat(sprint-43): 新增长截图控制面板 SwiftUI 视图"
```

---

### Task 4：将 `ScrollingCapturePanelService` 改为承载 SwiftUI 控制面板

**Files:**
- Modify: `TYScreenShotTool/Services/ScrollingCapturePanelService.swift`

- [ ] **Step 1: 更新 imports 和 service 持有对象**

将文件头部 imports 改为：

```swift
import AppKit
import Foundation
import SnapKit
import SwiftUI
```

将属性替换为：

```swift
    private var panel: ScrollingCapturePanel?
    private let containerView = NSVisualEffectView()
    private var hostingView: NSHostingView<ScrollingCaptureControlPanelView>?
```

删除文件底部整个 `ScrollingCapturePanelView` AppKit 自定义视图实现，不再保留按钮 `frame` 布局和 `NSMenu` 逻辑。

- [ ] **Step 2: 在 `presentCapturePanel` 中改为安装 SwiftUI 内容**

用下面的实现替换 `presentCapturePanel(selectionRect:on:)`：

```swift
    func presentCapturePanel(selectionRect: CGRect, on screen: NSScreen) {
        let panel = panel ?? ScrollingCapturePanel(contentRect: CGRect(x: 0, y: 0, width: 480, height: 42))
        if panel.contentView !== containerView {
            panel.contentView = containerView
        }

        containerView.material = .popover
        containerView.blendingMode = .withinWindow
        containerView.state = .active
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 12
        containerView.layer?.masksToBounds = true

        installContentView()

        let panelSize = measuredPanelSize()
        panel.setFrame(originRect(for: panelSize, selectionRect: selectionRect, on: screen), display: true)

        AppThemeCoordinator.shared.registerRefreshHandler(for: self) { [weak self] in
            guard let self, let panel = self.panel else {
                return
            }

            AppThemeCoordinator.shared.applyCurrentAppearance(to: panel)
            self.applyAppearanceStyling()
        }

        AppThemeCoordinator.shared.applyCurrentAppearance(to: panel)
        applyAppearanceStyling()
        panel.orderFrontRegardless()

        self.panel = panel
    }
```

- [ ] **Step 3: 新增 `installContentView` 和外观辅助方法**

在 `ScrollingCapturePanelService` 中加入：

```swift
    private func installContentView() {
        hostingView?.removeFromSuperview()

        let rootView = ScrollingCaptureControlPanelView(
            isOCREnabled: onOCRRequested != nil,
            isAIEnabled: onAIRequested != nil,
            onCancel: { [weak self] in self?.onCancelRequested?() },
            onOCR: { [weak self] in self?.onOCRRequested?() },
            onAISelected: { [weak self] mode in self?.onAIRequested?(mode) },
            onSave: { [weak self] in self?.onSaveRequested?() },
            onCopy: { [weak self] in self?.onCopyRequested?() }
        )

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(hostingView)
        hostingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        self.hostingView = hostingView
    }

    private func measuredPanelSize() -> CGSize {
        let minWidth: CGFloat = 360
        let maxWidth: CGFloat = 560
        let minHeight: CGFloat = 42
        let maxHeight: CGFloat = 120
        let fallbackSize = CGSize(width: 440, height: 42)

        guard let hostingView else {
            return fallbackSize
        }

        let naturalSize = hostingView.sizeThatFits(
            in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        )
        let clampedWidth = min(max(ceil(naturalSize.width), minWidth), maxWidth)
        let measuredHeight = hostingView.sizeThatFits(
            in: CGSize(width: clampedWidth, height: CGFloat.greatestFiniteMagnitude)
        ).height
        let clampedHeight = min(max(ceil(measuredHeight), minHeight), maxHeight)

        return CGSize(width: clampedWidth, height: clampedHeight)
    }

    private func applyAppearanceStyling() {
        containerView.material = .popover
        containerView.layer?.borderColor = NSColor.separatorColor.cgColor
        containerView.layer?.borderWidth = 1
    }
```

这一步明确把“AppKit 负责窗口外壳，SwiftUI 负责内容层”切开，同时让剩余 AppKit 布局改用 SnapKit。

- [ ] **Step 3.5: 将控制面板尺寸策略改为“内容决定尺寸 + 最小/最大约束”**

不要直接依赖固定宽度或固定高度作为最终窗口尺寸。改为先测量 SwiftUI 内容的自然尺寸，再施加最小 / 最大约束；这样控制面板会优先由内部内容决定大小，同时仍能避免窗口过窄或过宽。

新增：

```swift
    private func measuredPanelSize() -> CGSize {
        let minWidth: CGFloat = 360
        let maxWidth: CGFloat = 560
        let minHeight: CGFloat = 42
        let maxHeight: CGFloat = 120
        let fallbackSize = CGSize(width: 440, height: 42)

        guard let hostingView else {
            return fallbackSize
        }

        let naturalSize = hostingView.sizeThatFits(
            in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        )
        let clampedWidth = min(max(ceil(naturalSize.width), minWidth), maxWidth)
        let measuredHeight = hostingView.sizeThatFits(
            in: CGSize(width: clampedWidth, height: CGFloat.greatestFiniteMagnitude)
        ).height
        let clampedHeight = min(max(ceil(measuredHeight), minHeight), maxHeight)

        return CGSize(width: clampedWidth, height: clampedHeight)
    }
```

然后在 `presentCapturePanel` 中用：

```swift
        let panelSize = measuredPanelSize()
        panel.setFrame(originRect(for: panelSize, selectionRect: selectionRect, on: screen), display: true)
```

其中：

- 自然宽度足够时优先使用单行布局
- 自然宽度过宽时由 `maxWidth` 约束触发 `ViewThatFits` 回落到双行布局
- 面板高度由实际内容重新测量，不使用固定行高硬撑

`originRect(for:on:)` 本身继续保留原有边距约束，避免面板因为变宽或变高后贴边：

```swift
    private func originRect(for size: CGSize, selectionRect: CGRect, on screen: NSScreen) -> CGRect {
        let frame = screen.visibleFrame
        let x = min(
            max(selectionRect.midX - size.width / 2, frame.minX + 24),
            frame.maxX - size.width - 24
        )
        let y = max(frame.minY + 24, selectionRect.minY - size.height - 24)

        return CGRect(
            x: x,
            y: y,
            width: size.width,
            height: size.height
        )
    }
```

控制面板本轮允许比旧版更高，但不允许重新回到手动子按钮 `frame` 布局。

- [ ] **Step 4: 简化关闭逻辑**

将 `dismissPanel()` 改为：

```swift
    func dismissPanel() {
        AppThemeCoordinator.shared.unregisterRefreshHandler(for: self)
        panel?.orderOut(nil)
        hostingView?.removeFromSuperview()
        hostingView = nil
        panel = nil
    }
```

- [ ] **Step 5: 构建验证控制面板 service 改造**

运行：

```bash
./scripts/build.sh
```

预期：

```text
** BUILD SUCCEEDED **
```

如果报 `Cannot find 'ScrollingCaptureControlPanelView' in scope`，先确认新文件已位于 `TYScreenShotTool/Features/ScrollingCapture/` 且 target 自动同步成功。

- [ ] **Step 6: 提交**

```bash
git status --short
git add TYScreenShotTool/Services/ScrollingCapturePanelService.swift
git commit -m "refactor(sprint-43): 控制面板 service 承载 SwiftUI 内容"
```

---

### Task 5：新增 SwiftUI 长截图预览内容视图

**Files:**
- Create: `TYScreenShotTool/Features/ScrollingCapture/ScrollingCapturePreviewContentView.swift`

- [ ] **Step 1: 新增 `ScrollingCapturePreviewContentView.swift`**

创建 `TYScreenShotTool/Features/ScrollingCapture/ScrollingCapturePreviewContentView.swift`：

```swift
//
//  ScrollingCapturePreviewContentView.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/22.
//

import AppKit
import SwiftUI

enum ScrollingCapturePreviewContent {
    case preparing(title: String, message: String)
    case image(NSImage)
}

struct ScrollingCapturePreviewContentView: View {
    let content: ScrollingCapturePreviewContent

    var body: some View {
        ZStack(alignment: .topLeading) {
            switch content {
            case let .preparing(title, message):
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "rectangle.on.rectangle.angled")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            case let .image(image):
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Text(AppText.captureLongCapture)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.regularMaterial, in: Capsule())
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

这里不再使用 `NSImageView`，预览内容完全交给 SwiftUI。信息层只保留轻量标识，不做交互化改造。

- [ ] **Step 2: 构建确认预览内容视图可编译**

运行：

```bash
./scripts/build.sh
```

预期：

```text
** BUILD SUCCEEDED **
```

- [ ] **Step 3: 提交**

```bash
git status --short
git add TYScreenShotTool/Features/ScrollingCapture/ScrollingCapturePreviewContentView.swift
git commit -m "feat(sprint-43): 新增长截图预览 SwiftUI 内容视图"
```

---

### Task 6：将长截图预览窗口 service 改为承载 SwiftUI，并补齐启动占位态

**Files:**
- Modify: `TYScreenShotTool/Services/ScrollingCapturePreviewWindowService.swift`
- Modify: `TYScreenShotTool/Services/CaptureSessionService.swift`

- [ ] **Step 1: 将预览 service 改为 `NSHostingView` + SnapKit**

更新 `TYScreenShotTool/Services/ScrollingCapturePreviewWindowService.swift` 头部：

```swift
import AppKit
import CoreGraphics
import SnapKit
import SwiftUI
```

将属性替换为：

```swift
    private let containerView = NSVisualEffectView()
    private var hostingView: NSHostingView<ScrollingCapturePreviewContentView>?
    private(set) var attachmentSide: PreviewPlacementSide?
```

移除：

```swift
    private let imageView = NSImageView()
```

并将 `init()` 中的内容初始化保持为“只有 `containerView`，不再添加 `imageView`”：

```swift
        containerView.material = .popover
        containerView.blendingMode = .withinWindow
        containerView.state = .active
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 14
        containerView.layer?.borderWidth = 1

        panel.contentView = containerView
```

- [ ] **Step 2: 加入 SwiftUI 内容安装与占位展示方法**

在 `ScrollingCapturePreviewWindowService` 中加入：

```swift
    func presentPreparingPreview(selectionRect: CGRect) {
        guard let screen = screenContaining(selectionRect) else {
            dismissPreview()
            return
        }

        let placeholderSize = CGSize(width: 240, height: 160)
        guard let panelFrame = frame(for: selectionRect, on: screen, contentSize: placeholderSize) else {
            dismissPreview()
            return
        }
        attachmentSide = panelFrame.maxX <= selectionRect.minX ? .left : .right

        installContentView(
            .preparing(
                title: AppText.scrollingCapturePreviewPreparingTitle,
                message: AppText.scrollingCapturePreviewPreparingMessage
            )
        )

        AppThemeCoordinator.shared.applyCurrentAppearance(to: panel)
        panel.setFrame(panelFrame, display: true)
        applyAppearanceStyling()
        panel.orderFrontRegardless()
    }

    private func installContentView(_ content: ScrollingCapturePreviewContent) {
        hostingView?.removeFromSuperview()

        let hostingView = NSHostingView(
            rootView: ScrollingCapturePreviewContentView(content: content)
        )
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(hostingView)
        hostingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        self.hostingView = hostingView
    }
```

- [ ] **Step 3: 用 SwiftUI 内容替换 `presentOrUpdatePreview(image:selectionRect:)`**

将 `presentOrUpdatePreview(image:selectionRect:)` 改为：

```swift
    func presentOrUpdatePreview(image: CGImage, selectionRect: CGRect) {
        guard let screen = screenContaining(selectionRect) else {
            dismissPreview()
            return
        }

        let imageSize = CGSize(width: image.width, height: image.height)
        guard let panelFrame = frame(for: selectionRect, on: screen, contentSize: imageSize) else {
            dismissPreview()
            return
        }
        attachmentSide = panelFrame.maxX <= selectionRect.minX ? .left : .right

        installContentView(
            .image(NSImage(cgImage: image, size: imageSize))
        )

        AppThemeCoordinator.shared.applyCurrentAppearance(to: panel)
        panel.setFrame(panelFrame, display: true)
        applyAppearanceStyling()
        panel.orderFrontRegardless()
    }
```

将原先手动更新 `containerView.frame`、`imageView.frame`、`imageView.image` 的代码全部删除。

- [ ] **Step 4: 抽出统一的 `frame(for:on:contentSize:)`**

将原先只适用于 `CGImage` 的尺寸计算方法替换为：

```swift
    private func frame(for selectionRect: CGRect, on screen: NSScreen, contentSize: CGSize) -> CGRect? {
        let visibleFrame = screen.visibleFrame
        let outerMargin: CGFloat = 24
        let gap: CGFloat = 20
        let leftAvailableWidth = selectionRect.minX - visibleFrame.minX - gap
        let rightAvailableWidth = visibleFrame.maxX - selectionRect.maxX - gap
        let placeOnLeft = leftAvailableWidth >= rightAvailableWidth
        let chosenAvailableWidth = max(placeOnLeft ? leftAvailableWidth : rightAvailableWidth, 0)
        let availableWidth = max(chosenAvailableWidth - outerMargin, 0)
        let availableHeight = max(visibleFrame.height - outerMargin * 2, 0)

        guard availableWidth >= 140, availableHeight >= 140 else {
            return nil
        }

        let scale = min(
            availableWidth / max(contentSize.width, 1),
            availableHeight / max(contentSize.height, 1),
            1
        )
        let panelSize = CGSize(
            width: max(140, floor(contentSize.width * scale)),
            height: max(140, floor(contentSize.height * scale))
        )

        let panelX: CGFloat
        if placeOnLeft {
            panelX = max(
                visibleFrame.minX + outerMargin,
                selectionRect.minX - gap - panelSize.width
            )
        } else {
            panelX = min(
                visibleFrame.maxX - outerMargin - panelSize.width,
                selectionRect.maxX + gap
            )
        }

        let panelY = min(
            max(selectionRect.midY - panelSize.height / 2, visibleFrame.minY + outerMargin),
            visibleFrame.maxY - outerMargin - panelSize.height
        )

        return CGRect(origin: CGPoint(x: panelX, y: panelY), size: panelSize)
    }
```

这一步保留原有左右摆放语义，不引入新的位置决策规则。

- [ ] **Step 5: 更新 `dismissPreview()` 清理 hosting view**

将 `dismissPreview()` 改为：

```swift
    func dismissPreview() {
        panel.orderOut(nil)
        hostingView?.removeFromSuperview()
        hostingView = nil
        attachmentSide = nil
    }
```

- [ ] **Step 6: 在长截图启动时先展示预览占位态**

在 `TYScreenShotTool/Services/CaptureSessionService.swift` 的 `startScrollingCapture(annotations:)` 中，`presentCapturePanel` 之后、`reactivateSourceApplicationForScrolling()` 之前加入：

```swift
        scrollingCapturePreviewWindowService.presentPreparingPreview(selectionRect: pendingSelectionRect)
```

加入后的结构应接近：

```swift
        if let screen = screenContaining(pendingSelectionRect) {
            scrollingCapturePanelService.presentCapturePanel(selectionRect: pendingSelectionRect, on: screen)
        } else if let screen = NSScreen.main ?? NSScreen.screens.first {
            scrollingCapturePanelService.presentCapturePanel(selectionRect: pendingSelectionRect, on: screen)
        }
        scrollingCapturePreviewWindowService.presentPreparingPreview(selectionRect: pendingSelectionRect)
        pendingScreenImages.removeAll()
        reactivateSourceApplicationForScrolling()
```

这样可以保证用户进入长截图模式后，预览窗先有明确状态，再等待首帧拼接结果更新。

- [ ] **Step 7: 构建验证预览窗口改造**

运行：

```bash
./scripts/build.sh
```

预期：

```text
** BUILD SUCCEEDED **
```

- [ ] **Step 8: 提交**

```bash
git status --short
git add TYScreenShotTool/Services/ScrollingCapturePreviewWindowService.swift TYScreenShotTool/Services/CaptureSessionService.swift
git commit -m "refactor(sprint-43): 长截图预览窗口承载 SwiftUI 内容"
```

---

### Task 7：执行 Sprint 43 的构建与人工验证

**Files:**
- Read: `TYScreenShotTool/Services/ScrollingCapturePanelService.swift`
- Read: `TYScreenShotTool/Services/ScrollingCapturePreviewWindowService.swift`
- Read: `TYScreenShotTool/Services/CaptureSessionService.swift`

- [ ] **Step 1: 完整构建**

运行：

```bash
./scripts/build.sh
```

预期：

```text
** BUILD SUCCEEDED **
```

- [ ] **Step 2: 人工验证长截图控制面板**

在 Xcode 运行 App 后，按下面顺序验证：

```text
1. 触发截图 -> 进入编辑态 -> 点击“长截图”
2. 长截图控制面板显示为 SwiftUI 内容，按钮顺序仍为：取消 / OCR / AI / 保存 / 复制
3. OCR 与 AI 按钮在长截图模式下可点击，保存 / 复制 / 取消行为不回归
4. AI 按钮点击后弹出 SwiftUI Popover，而不是 AppKit NSMenu
5. Popover 中包含：开发报错分析 / 摘要总结 / 界面结构识别 / 翻译成中文 / 翻译成英文
6. 代码级确认 `isOCREnabled` / `isAIEnabled` 仍由回调是否存在驱动
7. 浅色与深色主题下按钮文字都可读
```

预期结果：控制面板交互与原业务语义一致，唯一变化是内容层实现从 AppKit 切换为 SwiftUI。

如果第 4 步的 `Popover` 在 `nonactivatingPanel` 上出现焦点问题，本轮 fallback 方案是：保留同一个 SwiftUI 选择视图内容，但改由一个小型 AppKit child panel / transient panel 承载，而不是退回 `NSMenu`。只有在这个 fallback 也不可行时，才重新评估 AI 入口交互形式。

- [ ] **Step 3: 人工验证长截图预览窗口**

继续验证：

```text
1. 进入长截图模式后，预览窗先显示“等待生成预览”的占位态
2. 开始滚动并生成首帧后，占位态切换为实际长图预览
3. 后续滚动时预览内容持续更新
4. 预览窗仍悬浮在选区左侧或右侧，不遮挡主选区
5. 结束长截图后，OCR / AI 结果窗口仍根据 preview attachmentSide 反向摆放
6. 预览窗仍保持不可交互，不抢焦点
7. `AI` 按钮在长截图控制面板所属 `NSPanel` 上弹出 Popover 时，不出现无法展开、焦点异常或点击即关闭的问题
```

预期结果：预览窗口内容层改为 SwiftUI 后，窗口行为与摆放规则保持不变。

- [ ] **Step 4: 记录验证结论**

不要创建空提交。将构建结果和人工验证结论写入 Sprint 文档与 `docs/DEVLOG.md`，再与本轮代码改动一起提交。

---

### Task 8：同步 Sprint 43 文档

**Files:**
- Create: `docs/SPRINTS/Sprint-43.md`
- Modify: `TASK.md`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/DEVLOG.md`

- [ ] **Step 1: 新增 Sprint 43 文档**

创建 `docs/SPRINTS/Sprint-43.md`：

```md
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
- `ScrollingCapturePreviewWindowService` 改为通过 `NSHostingView` 承载 SwiftUI 预览内容
- `CaptureSessionService` 在进入长截图模式后先显示预览占位态

---

## Validation

1. `./scripts/build.sh` 构建通过
2. 长截图控制面板人工验证通过
3. 长截图 AI Popover 人工验证通过
4. 长截图预览窗口占位态与实时更新人工验证通过
5. OCR / AI 结果窗口反向摆放规则人工验证通过

---

## Result

Sprint 43 完成长截图控制面板与预览窗口的 SwiftUI 内容迁移，继续保留 AppKit 窗口外壳与原有长截图主链路，为后续长截图 UI 收口提供统一的 SwiftUI / SnapKit 样板。
```

- [ ] **Step 2: 更新 `TASK.md`**

将 `TASK.md` 更新为 Sprint 43 完成态，核心内容替换为：

```md
# TShot

Version: v1.0.0+

Current Sprint: Sprint 43 Completed

---

## 当前状态

Sprint 43 已完成实现、构建验证与人工验证。

## 当前目标

将长截图控制面板与预览窗口的内容层迁移为 SwiftUI，并将长截图相关 AppKit 布局统一收口到 SnapKit。
```

- [ ] **Step 3: 更新 `docs/ROADMAP.md`**

在“当前状态”下方新增 Sprint 43：

```md
### Sprint 43

长截图控制面板与预览窗口 SwiftUI 化

状态：
✅ Done

成果：

- 长截图控制面板与预览窗口完成 SwiftUI 内容迁移
- 长截图模式下的 AI 入口交互得到统一
- 进入长截图模式后预览反馈更明确
- 长截图相关窗口样式与布局规则进一步收口
```

- [ ] **Step 4: 更新 `docs/DEVLOG.md`**

在 `docs/DEVLOG.md` 追加：

```md
## Sprint 43 完成

### 主题

长截图控制面板与预览窗口 SwiftUI 化

### 实现

- 将长截图控制面板改为 `NSPanel + NSHostingView + SwiftUI View`
- 将长截图 AI 入口从 AppKit `NSMenu` 改为 SwiftUI `Popover`
- 将长截图预览窗口改为 `NSPanel + NSHostingView + SwiftUI View`
- 新增长截图预览启动占位态
- 继续保留长截图预览左右摆放与结果窗口反向摆放规则

### 验证

- `./scripts/build.sh` 构建通过
- 长截图控制面板人工验证通过
- 长截图 AI Popover 人工验证通过
- 长截图预览窗口人工验证通过
- 长截图 OCR / AI 结果窗口摆放链路人工验证通过

### 结果

长截图相关 UI 完成了从 AppKit 内容层向 SwiftUI 内容层的进一步收口，同时保留了 macOS 浮动面板、窗口摆放和长截图主流程这部分最适合继续由 AppKit 管理的能力边界。
```

- [ ] **Step 5: 提交**

```bash
git status --short
git add docs/SPRINTS/Sprint-43.md TASK.md docs/ROADMAP.md docs/DEVLOG.md
git commit -m "docs(sprint-43): 同步长截图 SwiftUI 化结果"
```
