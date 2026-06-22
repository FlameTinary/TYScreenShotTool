# Sprint 42 - 结果窗口 SwiftUI 与 SnapKit 实施计划

> **面向执行型 Agent：** 必须使用子技能 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 按任务逐项执行本计划。步骤使用复选框语法（`- [ ]`）进行追踪。

**目标：** 将 OCR 和 AI 结果窗口的内容层迁移到 SwiftUI，同时保留 AppKit `NSPanel` 外壳，并在剩余的 AppKit 布局中使用 SnapKit。

**架构：** 保留 `OCRPreviewWindowService` 和 `AIAnalysisPreviewWindowService` 作为 AppKit 窗口协调器，继续负责面板创建、位置计算、生命周期和回调；将用户可见内容迁移到专注的 SwiftUI 视图中，通过 `NSHostingView` 承载；SnapKit 仅用于将 hosting view 约束到 AppKit 容器上。

**技术栈：** SwiftUI、AppKit、SnapKit 6.0.0、现有与 ScreenCaptureKit 相邻的服务、项目构建脚本 `./scripts/build.sh`。

---

## 规划说明

本计划遵循 [2026-06-22-sprint-42-result-windows-swiftui-snapkit-design.md](/Users/sheldon/CodeRepo/TYScreenShotTool/docs/superpowers/specs/2026-06-22-sprint-42-result-windows-swiftui-snapkit-design.md)。

当前关键文件：

- `TYScreenShotTool/Services/OCRPreviewWindowService.swift`：使用 AppKit 实现的 OCR 结果面板，包含标题、滚动区、文本视图和按钮。
- `TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift`：使用 AppKit 实现的 AI 结果面板，包含 loading / error / result 布局。
- `TYScreenShotTool/Services/AIAnalysisService.swift`：定义 `AIAnalysisResult` 和 `AIAnalysisSection`。
- `TYScreenShotTool/Shared/AIAnalysisMode.swift`：定义 AI 模式对应的按钮标题和复制文案。
- `TYScreenShotTool/Shared/AppText.swift`：OCR / AI 窗口使用的本地化 UI 文案。
- `TYScreenShotTool/Shared/PreviewPlacementSide.swift`：长截图结果窗口使用的左右侧偏好。

需要创建的文件：

- `TYScreenShotTool/Features/Preview/OCRPreviewView.swift`
- `TYScreenShotTool/Features/Preview/AIAnalysisPreviewView.swift`

需要修改的文件：

- `TYScreenShotTool.xcodeproj/project.pbxproj`
- `TYScreenShotTool/Services/OCRPreviewWindowService.swift`
- `TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift`
- `docs/SPRINTS/Sprint-42.md`
- `TASK.md`
- `docs/ROADMAP.md`
- `docs/DEVLOG.md`

不要修改：

- 截图 Overlay 的基础窗口行为
- 标注画布
- 截图工具栏
- 长截图控制面板
- AI 请求 / prompt 逻辑
- `CaptureSessionService` 的业务编排流程，除非编译错误明确表明调用点签名已经不匹配

---

### 任务 1：确认并修复 SnapKit 的 Target 关联

**文件：**
- 修改：`TYScreenShotTool.xcodeproj/project.pbxproj`
- 读取：`TYScreenShotTool.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`

- [ ] **步骤 1：确认 SnapKit 包已经被解析**

运行：

```bash
rg -n "SnapKit|snapkit" TYScreenShotTool.xcodeproj
```

预期：

```text
TYScreenShotTool.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved:...
TYScreenShotTool.xcodeproj/project.pbxproj:...
```

- [ ] **步骤 2：确认 App target 已经链接 SnapKit product**

运行：

```bash
rg -n "packageProductDependencies = \\(|SnapKit in Frameworks|productName = SnapKit|XCSwiftPackageProductDependency" TYScreenShotTool.xcodeproj/project.pbxproj
```

本任务完成后的预期：

```text
... packageProductDependencies = (
... /* SnapKit */,
... productName = SnapKit;
... SnapKit in Frameworks ...
```

- [ ] **步骤 3：如果 SnapKit 只是被解析但还未链接，则把它接入 App target**

打开 `TYScreenShotTool.xcodeproj/project.pbxproj`，补上缺失的 target product dependency 和 framework build file。

使用现有的 package 引用：

```text
086F7EC12FE8EC800004C83A /* XCRemoteSwiftPackageReference "SnapKit" */
```

新增一个 `XCSwiftPackageProductDependency` 条目：

```text
		<NEW_PRODUCT_ID> /* SnapKit */ = {
			isa = XCSwiftPackageProductDependency;
			package = 086F7EC12FE8EC800004C83A /* XCRemoteSwiftPackageReference "SnapKit" */;
			productName = SnapKit;
		};
```

新增一个 `PBXBuildFile` 条目：

```text
		<NEW_BUILD_FILE_ID> /* SnapKit in Frameworks */ = {isa = PBXBuildFile; productRef = <NEW_PRODUCT_ID> /* SnapKit */; };
```

把 `<NEW_PRODUCT_ID> /* SnapKit */` 加入 target 的 `packageProductDependencies`。

把 `<NEW_BUILD_FILE_ID> /* SnapKit in Frameworks */` 加入 `Frameworks` build phase。

使用与 `project.pbxproj` 现有风格一致的、唯一的 24 位大写十六进制 ID。

- [ ] **步骤 4：验证 SnapKit 可以参与编译**

完成任务 3 后，或者如果步骤 2 已经证明关联完整，不要为了验证额外创建临时源码文件。等到下面任务 3 或任务 4 引入 `import SnapKit` 后再进行编译验证。

运行：

```bash
./scripts/build.sh
```

预期：

```text
** BUILD SUCCEEDED **
```

如果编译报错 `no such module 'SnapKit'`，说明 target 关联仍然不完整，需要回到步骤 3。

- [ ] **步骤 5：提交**

只有在用户希望过程中产生 commit，并且当前没有把无关文件一起 staged 时，才执行提交。

```bash
git status --short
git add TYScreenShotTool.xcodeproj/project.pbxproj TYScreenShotTool.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
git commit -m "chore(sprint-42): 接入 SnapKit 目标依赖"
```

---

### 任务 2：新增 SwiftUI OCR 结果视图

**文件：**
- 创建：`TYScreenShotTool/Features/Preview/OCRPreviewView.swift`

- [ ] **步骤 1：如有需要，先创建 Preview 功能目录**

运行：

```bash
mkdir -p TYScreenShotTool/Features/Preview
```

预期：目录存在。

- [ ] **步骤 2：新增 `OCRPreviewView.swift`**

创建 `TYScreenShotTool/Features/Preview/OCRPreviewView.swift`，内容如下：

```swift
//
//  OCRPreviewView.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/22.
//

import SwiftUI

struct OCRPreviewView: View {
    let title: String
    let text: String
    let isCopyEnabled: Bool
    let copyTitle: String
    let cancelTitle: String
    let onCopy: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)

            ScrollView {
                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 10) {
                Spacer()

                Button(copyTitle, action: onCopy)
                    .disabled(isCopyEnabled == false)

                Button(cancelTitle, action: onCancel)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

SwiftUI 内容层必须保持透明。现有的 `NSVisualEffectView` 容器继续作为唯一的材质 / 背景来源，这样 Sprint 42 不会改变当前结果窗的视觉风格。

- [ ] **步骤 3：构建检查新文件是否被同步 Xcode group 正确纳入**

运行：

```bash
./scripts/build.sh
```

预期：

```text
** BUILD SUCCEEDED **
```

如果文件没有被编译，说明同步 group 没有自动拾取，需要检查 Xcode 工程元数据是否使用了 `fileSystemSynchronizedGroups`，然后重新构建。

- [ ] **步骤 4：提交**

```bash
git status --short
git add TYScreenShotTool/Features/Preview/OCRPreviewView.swift
git commit -m "feat(sprint-42): 新增 SwiftUI OCR 结果视图"
```

---

### 任务 3：将 `OCRPreviewWindowService` 重构为承载 SwiftUI

**文件：**
- 修改：`TYScreenShotTool/Services/OCRPreviewWindowService.swift`

- [ ] **步骤 1：用 hosting view 替换 AppKit 内容控件**

更新 imports：

```swift
import AppKit
import SnapKit
import SwiftUI
```

将以下存储属性：

```swift
private let titleLabel = NSTextField(labelWithString: "")
private let scrollView = NSScrollView()
private let textView = NSTextView()
private let copyButton = NSButton(title: "", target: nil, action: nil)
private let cancelButton = NSButton(title: "", target: nil, action: nil)
```

替换为：

```swift
private var hostingView: NSHostingView<OCRPreviewView>?
```

- [ ] **步骤 2：简化 `init()`**

移除 `titleLabel`、`scrollView`、`textView`、`copyButton` 和 `cancelButton` 的初始化与配置。

保留 panel 和 container 的初始化：

```swift
panel.backgroundColor = .clear
panel.isOpaque = false
panel.hasShadow = true
panel.isFloatingPanel = true
panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2)
panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
panel.hidesOnDeactivate = false

containerView.material = .popover
containerView.blendingMode = .withinWindow
containerView.state = .active
containerView.wantsLayer = true
containerView.layer?.cornerRadius = 14
containerView.layer?.borderWidth = 1

panel.contentView = containerView
```

保留 `AppThemeCoordinator` 的注册逻辑。

- [ ] **步骤 3：新增 `installContentView(...)` 辅助方法**

新增以下方法：

```swift
private func installContentView(
    text: String,
    isCopyEnabled: Bool,
    onCopy: @escaping () -> Void,
    onCancel: @escaping () -> Void
) {
    hostingView?.removeFromSuperview()

    let view = OCRPreviewView(
        title: AppText.ocrWindowTitle,
        text: text,
        isCopyEnabled: isCopyEnabled,
        copyTitle: AppText.captureCopy,
        cancelTitle: AppText.captureCancel,
        onCopy: onCopy,
        onCancel: onCancel
    )

    let hostingView = NSHostingView(rootView: view)
    hostingView.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(hostingView)
    hostingView.snp.makeConstraints { make in
        make.edges.equalToSuperview()
    }
    self.hostingView = hostingView
}
```

- [ ] **步骤 4：更新 `present(...)`**

将原来的 AppKit 文本 / 按钮状态设置替换为：

```swift
let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
let displayText = normalizedText.isEmpty ? AppText.ocrEmpty : text
self.onCopy = onCopy
self.onCancel = onCancel
installContentView(
    text: displayText,
    isCopyEnabled: normalizedText.isEmpty == false,
    onCopy: onCopy,
    onCancel: onCancel
)
```

保留现有的 `frame(for:on:preferredSide:)`、`AppThemeCoordinator`、`panel.setFrame(...)` 和 `panel.orderFrontRegardless()`。

移除对 `layoutContent(in:)` 的调用。

- [ ] **步骤 5：更新 `dismiss()`**

使用：

```swift
func dismiss() {
    panel.orderOut(nil)
    hostingView?.removeFromSuperview()
    hostingView = nil
    onCopy = nil
    onCancel = nil
}
```

- [ ] **步骤 6：移除废弃方法**

移除：

```swift
@objc private func copyRequested()
@objc private func cancelRequested()
private func applyLocalizedStrings()
private func layoutContent(in size: CGSize)
```

保留 `applyAppearanceStyling()`，但简化为：

```swift
private func applyAppearanceStyling() {
    containerView.material = .popover
    containerView.layer?.borderColor = NSColor.separatorColor.cgColor
}
```

- [ ] **步骤 7：构建**

运行：

```bash
./scripts/build.sh
```

预期：

```text
** BUILD SUCCEEDED **
```

- [ ] **步骤 8：提交**

```bash
git status --short
git add TYScreenShotTool/Services/OCRPreviewWindowService.swift
git commit -m "feat(sprint-42): OCR 结果窗改用 SwiftUI 内容"
```

---

### 任务 4：新增 SwiftUI AI 结果视图

**文件：**
- 创建：`TYScreenShotTool/Features/Preview/AIAnalysisPreviewView.swift`

- [ ] **步骤 1：新增 `AIAnalysisPreviewView.swift`**

创建 `TYScreenShotTool/Features/Preview/AIAnalysisPreviewView.swift`，内容如下：

```swift
//
//  AIAnalysisPreviewView.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/22.
//

import SwiftUI

enum AIAnalysisPreviewContent {
    case loading(message: String)
    case result(AIAnalysisResult)
    case error(title: String, message: String)
}

struct AIAnalysisPreviewView: View {
    let title: String
    let content: AIAnalysisPreviewContent
    let copyAllTitle: String
    let retryTitle: String
    let closeTitle: String
    let onCopyAll: (() -> Void)?
    let onCopySecondary: (() -> Void)?
    let onRetry: (() -> Void)?
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)

            statusContent

            buttonRow
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var statusContent: some View {
        switch content {
        case let .loading(message):
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        case let .error(title, message):
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case let .result(result):
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(result.statusTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    ForEach(Array(result.sections.enumerated()), id: \.offset) { _, section in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)

                            Text(section.content)
                                .font(.system(size: 13))
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var buttonRow: some View {
        HStack(spacing: 10) {
            Spacer()

            if case let .result(result) = content {
                Button(copyAllTitle) {
                    onCopyAll?()
                }
                .disabled(onCopyAll == nil)

                Button(result.mode.secondaryCopyButtonTitle) {
                    onCopySecondary?()
                }
                .disabled(onCopySecondary == nil)
            }

            if onRetry != nil {
                Button(retryTitle) {
                    onRetry?()
                }
            }

            Button(closeTitle, action: onClose)
        }
    }
}
```

SwiftUI 内容层必须保持透明。不要在 SwiftUI 视图中添加 `.regularMaterial`、自定义底色或额外边框，因为 AppKit `containerView` 已经负责结果窗的整体外观。

- [ ] **步骤 2：构建**

运行：

```bash
./scripts/build.sh
```

预期：

```text
** BUILD SUCCEEDED **
```

- [ ] **步骤 3：提交**

```bash
git add TYScreenShotTool/Features/Preview/AIAnalysisPreviewView.swift
git commit -m "feat(sprint-42): 新增 SwiftUI AI 结果视图"
```

---

### 任务 5：将 `AIAnalysisPreviewWindowService` 重构为承载 SwiftUI

**文件：**
- 修改：`TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift`

- [ ] **步骤 1：更新 imports 和存储属性**

使用：

```swift
import AppKit
import SnapKit
import SwiftUI
```

将以下所有内容层相关存储属性：

```swift
private let titleLabel = NSTextField(labelWithString: "")
private let statusLabel = NSTextField(labelWithString: "")
private let scrollView = NSScrollView()
private let documentContentView = FlippedContentView()
private let summarySectionView = SectionView(title: "")
private let causesSectionView = SectionView(title: "")
private let nextStepsSectionView = SectionView(title: "")
private let messageLabel = NSTextField(wrappingLabelWithString: "")
private let copyAllButton = NSButton(title: "", target: nil, action: nil)
private let copyNextStepsButton = NSButton(title: "", target: nil, action: nil)
private let retryButton = NSButton(title: "", target: nil, action: nil)
private let closeButton = NSButton(title: "", target: nil, action: nil)
```

替换为：

```swift
private var hostingView: NSHostingView<AIAnalysisPreviewView>?
```

- [ ] **步骤 2：简化 `init()`**

仅保留 panel、container 的初始化和主题注册：

```swift
panel.backgroundColor = .clear
panel.isOpaque = false
panel.hasShadow = true
panel.isFloatingPanel = true
panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2)
panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
panel.hidesOnDeactivate = false

containerView.material = .popover
containerView.blendingMode = .withinWindow
containerView.state = .active
containerView.wantsLayer = true
containerView.layer?.cornerRadius = 14
containerView.layer?.borderWidth = 1

panel.contentView = containerView
```

- [ ] **步骤 3：新增 `installContentView(...)` 辅助方法**

新增：

```swift
private func installContentView(
    content: AIAnalysisPreviewContent,
    onCopyAll: (() -> Void)?,
    onCopySecondary: (() -> Void)?,
    onRetry: (() -> Void)?,
    onClose: @escaping () -> Void
) {
    hostingView?.removeFromSuperview()

    let view = AIAnalysisPreviewView(
        title: AppText.aiResultTitle,
        content: content,
        copyAllTitle: AppText.aiResultCopyAll,
        retryTitle: AppText.aiResultRetry,
        closeTitle: AppText.aiResultClose,
        onCopyAll: onCopyAll,
        onCopySecondary: onCopySecondary,
        onRetry: onRetry,
        onClose: onClose
    )

    let hostingView = NSHostingView(rootView: view)
    hostingView.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(hostingView)
    hostingView.snp.makeConstraints { make in
        make.edges.equalToSuperview()
    }
    self.hostingView = hostingView
}
```

- [ ] **步骤 4：更新 `presentLoading(...)`**

将内容状态设置替换为：

```swift
onCopyAll = nil
onCopySecondary = nil
onRetry = nil
self.onClose = onClose
installContentView(
    content: .loading(message: message ?? AppText.aiLoadingDeveloperError),
    onCopyAll: nil,
    onCopySecondary: nil,
    onRetry: nil,
    onClose: onClose
)
presentPanel(
    selectionRect: selectionRect,
    preferredSide: preferredSide
)
```

- [ ] **步骤 5：更新 `presentResult(...)`**

将内容状态设置替换为：

```swift
self.onCopyAll = onCopyAll
self.onCopySecondary = onCopySecondary
self.onRetry = onRetry
self.onClose = onClose
installContentView(
    content: .result(result),
    onCopyAll: onCopyAll,
    onCopySecondary: onCopySecondary,
    onRetry: onRetry,
    onClose: onClose
)
presentPanel(
    selectionRect: selectionRect,
    preferredSide: preferredSide
)
```

- [ ] **步骤 6：更新 `presentError(...)`**

将内容状态设置替换为：

```swift
onCopyAll = nil
onCopySecondary = nil
self.onRetry = onRetry
self.onClose = onClose
installContentView(
    content: .error(title: title ?? AppText.aiResultError, message: message),
    onCopyAll: nil,
    onCopySecondary: nil,
    onRetry: onRetry,
    onClose: onClose
)
presentPanel(
    selectionRect: selectionRect,
    preferredSide: preferredSide
)
```

- [ ] **步骤 7：更新 `dismiss()`**

使用：

```swift
func dismiss() {
    panel.orderOut(nil)
    hostingView?.removeFromSuperview()
    hostingView = nil
    onCopyAll = nil
    onCopySecondary = nil
    onRetry = nil
    onClose = nil
}
```

- [ ] **步骤 8：移除废弃的 AppKit 内容布局**

移除：

```swift
@objc private func copyAllRequested()
@objc private func copyNextStepsRequested()
@objc private func retryRequested()
@objc private func closeRequested()
private func applyLocalizedStrings()
private func configureForLoadingOrError(messageVisible:)
private func configureForResult(_:)
private func layoutContent(in:)
private func layoutActionButtons(in:padding:spacing:buttonHeight:)
private func layoutDocumentContent(in:)
private final class FlippedContentView
private final class SectionView
```

保留：

```swift
private func presentPanel(selectionRect: CGRect, preferredSide: PreviewPlacementSide?)
private func frame(for selectionRect: CGRect, on screen: NSScreen, preferredSide: PreviewPlacementSide?) -> CGRect
private func screenContaining(_ rect: CGRect) -> NSScreen?
```

更新 `presentPanel(...)`，让它不再调用 `layoutContent(in:)`。

保留 `applyAppearanceStyling()`，但简化为：

```swift
private func applyAppearanceStyling() {
    containerView.material = .popover
    containerView.layer?.borderColor = NSColor.separatorColor.cgColor
}
```

- [ ] **步骤 9：构建**

运行：

```bash
./scripts/build.sh
```

预期：

```text
** BUILD SUCCEEDED **
```

- [ ] **步骤 10：提交**

```bash
git add TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift
git commit -m "feat(sprint-42): AI 结果窗改用 SwiftUI 内容"
```

---

### 任务 6：人工验证

**文件：**
- 除非验证中发现 bug，否则不改代码文件

- [ ] **步骤 1：构建**

运行：

```bash
./scripts/build.sh
```

预期：

```text
** BUILD SUCCEEDED **
```

- [ ] **步骤 2：验证普通截图 OCR**

手工步骤：

1. 从 Xcode 或构建产物启动应用。
2. 使用当前配置的快捷键触发截图。
3. 选择一块包含文字的区域。
4. 点击 `OCR`。
5. 确认 OCR 结果窗口出现在选区旁边。
6. 在结果窗口内拖拽选择部分 OCR 文本，确认局部文本选择仍然可用。
7. 点击 `取消`，确认截图编辑态仍然保留。
8. 再次点击 `OCR`。
9. 点击 `复制`，确认 OCR 文本被复制，并且截图会话结束。

预期：行为与迁移前的 OCR 结果窗口一致，包括内容区内的文本选择能力。

- [ ] **步骤 3：验证普通截图 AI**

手工步骤：

1. 如有需要，按当前 README 中的方式配置 AI key。
2. 触发截图并选择一段文本内容。
3. 点击 `AI`。
4. 选择 `开发报错分析`。
5. 确认 loading 状态出现。
6. 确认 result 状态出现。
7. 点击 `复制全部`。
8. 再执行一次，并点击二级复制按钮。
9. 再执行一次，选择 `摘要总结`；确认结果包含 3 个 section，且二级复制按钮标题符合该模式。
10. 再执行一次，选择 `界面结构识别`；确认单 section 的结构化输出能正确展示，且二级复制按钮标题符合该模式。
11. 再执行一次，选择任意一种翻译模式；确认单 section 的翻译输出能正确展示，且二级复制按钮标题符合该模式。
12. 暂时移除 API key，制造错误态。
13. 确认错误态支持 `重试` 和 `关闭`。

预期：developer error、summary、interface structure、translation 四种模式下的 loading / result / error 状态与回调行为，都与迁移前保持一致。

- [ ] **步骤 4：验证长截图 OCR / AI**

手工步骤：

1. 触发截图。
2. 选择一个可滚动区域。
3. 点击 `长截图`。
4. 先滚动一次，确保已经生成结果图片。
5. 点击长截图 `OCR`。
6. 确认 OCR 结果窗口出现在预期一侧。
7. 点击长截图 `AI`。
8. 执行一个多 section 的 AI 模式，确认结果窗口出现在预期一侧。
9. 执行一个单 section 的 AI 模式，确认结果窗口仍能在预期一侧正确布局。
10. 在长截图 AI 结果窗口中验证 `复制全部` 和模式对应的二级复制按钮可正常工作。
11. 关闭长截图 AI 结果窗口，确认不会结束长截图会话。
12. 如条件允许，制造一次错误态并验证 `重试` 与 `关闭` 行为仍然正常。

预期：结果窗口保持原有的侧边摆放行为，能够正确承载多 section 和单 section 的 AI 内容，长截图路径下的复制 / 重试 / 关闭行为保持一致，并且关闭窗口不会结束长截图会话。

- [ ] **步骤 5：如果验证中需要修复问题，再提交验证修复**

如果验证过程中需要补修复：

```bash
git status --short
git add <fixed-files>
git commit -m "fix(sprint-42): 修正结果窗 SwiftUI 迁移细节"
```

如果不需要修复，不要创建空提交。

---

### 任务 7：Sprint 文档收尾

**文件：**
- 创建：`docs/SPRINTS/Sprint-42.md`
- 修改：`TASK.md`
- 修改：`docs/ROADMAP.md`
- 修改：`docs/DEVLOG.md`

- [ ] **步骤 1：创建 Sprint 42 文档**

创建 `docs/SPRINTS/Sprint-42.md`：

```markdown
# Sprint 42 - 结果窗口 SwiftUI 化与 AppKit 布局规范

## 状态

✅ Done

## 目标

将 OCR / AI 结果窗口内容层迁移为 SwiftUI，并明确 AppKit 布局优先使用 SnapKit 的后续规则。

## 范围

### 包含内容

- OCR 结果窗口内容 SwiftUI 化
- AI 结果窗口内容 SwiftUI 化
- 保留 AppKit `NSPanel` 外壳与窗口摆放逻辑
- AppKit 外壳布局使用 SnapKit
- 普通截图与长截图中的 OCR / AI 结果窗口行为保持一致

### 不在范围内

- 不迁移截图 Overlay
- 不迁移标注画布
- 不迁移截图工具栏
- 不迁移长截图控制面板
- 不改变 OCR / AI 输入链路

## 实现

### 方向

本轮采用“SwiftUI 内容视图 + AppKit 窗口外壳”的迁移方式。
SwiftUI 负责用户可见内容，AppKit 继续负责 `NSPanel`、窗口层级、摆放和生命周期。

### 实现

- 新增 SwiftUI OCR 结果视图
- 新增 SwiftUI AI 结果视图
- `OCRPreviewWindowService` 改为通过 `NSHostingView` 承载 SwiftUI 内容
- `AIAnalysisPreviewWindowService` 改为通过 `NSHostingView` 承载 SwiftUI 内容
- 保留现有左右摆放逻辑与 callback 语义
- 确认 SnapKit 在 App target 中可用

## 验证

- `./scripts/build.sh` 构建通过
- 普通截图 OCR 结果窗人工验证通过，文本仍可选中
- 普通截图 AI 的开发报错分析、摘要总结、界面结构识别、翻译模式人工验证通过
- 普通截图 AI loading / result / error 三态人工验证通过
- 长截图 OCR / AI 结果窗人工验证通过，包含多 section / 单 section 布局与关键按钮行为
- 结果窗左右摆放行为人工验证通过
- 结果窗口迁移后未引入额外材质背景，视觉风格与现有 AppKit 外壳保持一致

## 结果

Sprint 42 完成后，TShot 建立了第一条可复用的 SwiftUI-first 迁移路径：
普通结果窗口内容优先使用 SwiftUI，必须保留的 AppKit 窗口外壳继续负责 macOS 原生窗口行为，
AppKit 布局优先使用 SnapKit，为后续面板和工具栏迁移提供参考。
```

- [ ] **步骤 2：更新 `TASK.md`**

将当前内容整体替换为：

```markdown
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
```

- [ ] **步骤 3：更新 `docs/ROADMAP.md`**

在 Sprint 41 段落之后追加：

```markdown
### Sprint 42

结果窗口 SwiftUI 化与 AppKit 布局规范

状态：
✅ Done

成果：

- OCR 结果窗口内容层迁移为 SwiftUI
- AI 结果窗口内容层迁移为 SwiftUI
- 保留 AppKit `NSPanel` 外壳与窗口摆放逻辑
- AppKit 外壳布局使用 SnapKit
- 明确后续 UI 实现优先级：SwiftUI 优先，AppKit 布局优先 SnapKit，最后才使用手动 `frame`
```

- [ ] **步骤 4：更新 `docs/DEVLOG.md`**

在靠近顶部的位置前置新增：

```markdown
## Sprint 42 完成

### 主题

结果窗口 SwiftUI 化与 AppKit 布局规范

### 实现

- 新增 SwiftUI OCR 结果视图
- 新增 SwiftUI AI 结果视图
- `OCRPreviewWindowService` 保留 AppKit 窗口外壳，并通过 `NSHostingView` 承载 SwiftUI 内容
- `AIAnalysisPreviewWindowService` 保留 AppKit 窗口外壳，并通过 `NSHostingView` 承载 SwiftUI 内容
- AppKit 外壳布局使用 SnapKit
- 在 `AGENTS.md` 中明确后续 UI 实现优先级

### 验证

- `./scripts/build.sh` 构建通过
- 普通截图 OCR 结果窗口人工验证通过，文本仍可选中
- 普通截图 AI 的开发报错分析、摘要总结、界面结构识别、翻译模式人工验证通过
- 普通截图 AI loading / result / error 三态人工验证通过
- 长截图 OCR / AI 结果窗口人工验证通过，包含多 section / 单 section 布局与关键按钮行为
- 结果窗口左右摆放行为人工验证通过
- 结果窗口迁移后未引入额外材质背景，视觉风格与现有 AppKit 外壳保持一致

### 结果

Sprint 42 建立了 TShot 后续 UI 演进的第一条迁移模式：
用户可见内容优先 SwiftUI，必须保留的 AppKit 继续负责窗口和系统行为，
AppKit 布局优先使用 SnapKit，只有低层坐标和窗口定位场景继续使用 `frame`。
```

- [ ] **步骤 5：构建并提交文档**

运行：

```bash
./scripts/build.sh
```

预期：

```text
** BUILD SUCCEEDED **
```

提交：

```bash
git add docs/SPRINTS/Sprint-42.md TASK.md docs/ROADMAP.md docs/DEVLOG.md AGENTS.md
git commit -m "docs(sprint-42): 记录结果窗口 SwiftUI 化规则"
```

---

## 自检

### 规格覆盖

- SwiftUI-first 的 UI 规则：已由任务 7 覆盖，并且已经写入 `AGENTS.md`。
- 必须保留的 AppKit 布局使用 SnapKit：已由任务 1、任务 3 和任务 5 覆盖。
- OCR 结果窗口 SwiftUI 化：已由任务 2 和任务 3 覆盖。
- AI 结果窗口 SwiftUI 化：已由任务 4 和任务 5 覆盖。
- 保留 AppKit `NSPanel` 外壳和侧边摆放逻辑：已由任务 3 和任务 5 覆盖。
- 普通截图与长截图行为一致：已由任务 6 覆盖。
- 文档收尾：已由任务 7 覆盖。

### 占位内容检查

本计划刻意不保留延后处理标记、空白 checklist 占位说明，或“类似上一任务”这类实现空洞描述。

### 类型一致性

- `OCRPreviewView` 通过 `NSHostingView<OCRPreviewView>` 承载。
- `AIAnalysisPreviewView` 通过 `NSHostingView<AIAnalysisPreviewView>` 承载。
- `AIAnalysisPreviewContent` 定义在 `AIAnalysisPreviewView` 同文件中。
- 现有 service 的公开方法继续保持为 `present(...)`、`presentLoading(...)`、`presentResult(...)`、`presentError(...)` 和 `dismiss()`。
