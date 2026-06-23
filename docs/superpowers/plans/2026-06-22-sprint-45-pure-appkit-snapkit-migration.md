# Sprint 45 - 纯 AppKit + SnapKit UI 迁移 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在一个 Sprint 中一次性移除项目业务 UI 对 SwiftUI 的依赖，并将入口、菜单栏、Settings、OCR/AI 结果窗、长截图控制面板和长截图预览窗全部迁移到纯 AppKit + SnapKit。

**Architecture:** 保留当前 `CaptureSessionService`、`OCRPreviewWindowService`、`AIAnalysisPreviewWindowService`、`ScrollingCapturePanelService`、`ScrollingCapturePreviewWindowService` 这些窗口级与业务级协调边界，不重写截图主链路；新增 AppKit `AppDelegate`、状态栏控制器、Settings 控制器和若干 AppKit 内容视图，删除 `SwiftUI App`、`NSHostingView`、`NSHostingController`、`NSViewRepresentable` 这些过渡结构。普通界面布局统一使用 SnapKit，窗口定位与 Overlay 绘制继续保留必要的手动 `frame`。

**Tech Stack:** Swift 6、AppKit、SnapKit 6、UserDefaults、NSStatusItem、NSPanel、xcodebuild、项目构建脚本 `./scripts/build.sh`。

---

## 规划说明

本计划基于设计文档 [2026-06-22-sprint-45-pure-appkit-snapkit-migration-design.md](/Users/sheldon/CodeRepo/TYScreenShotTool/docs/superpowers/specs/2026-06-22-sprint-45-pure-appkit-snapkit-migration-design.md)。

执行约束：

- 本轮允许中间阶段暂时不可编译
- 中间任务不要求逐个构建通过
- 所有 SwiftUI 替换完成后再统一构建
- 中间阶段用静态校验和调用点检查替代构建门槛

当前关键文件：

- `TYScreenShotTool/App/TYScreenShotToolApp.swift`：当前 `SwiftUI App` 入口，同时持有全部 service 初始化和菜单栏 UI。
- `TYScreenShotTool/App/MenuBarContentView.swift`：当前菜单栏菜单内容。
- `TYScreenShotTool/App/SettingsView.swift`：当前 SwiftUI Settings 页面，使用 `@AppStorage`。
- `TYScreenShotTool/App/HotKeyRecorderField.swift`：当前 `NSViewRepresentable` 风格热键录制桥接控件。
- `TYScreenShotTool/App/SettingsOpenCoordinator.swift`：当前 Settings 唯一窗口协调器，但内部依赖 `NSHostingController`。
- `TYScreenShotTool/Features/Preview/OCRPreviewView.swift` 与 `TYScreenShotTool/Features/Preview/AIAnalysisPreviewView.swift`：当前 SwiftUI 结果窗内容视图。
- `TYScreenShotTool/Features/ScrollingCapture/ScrollingCaptureAIPopoverView.swift`、`ScrollingCaptureControlPanelView.swift`、`ScrollingCapturePreviewContentView.swift`：当前长截图 SwiftUI 内容层。
- `TYScreenShotTool/Services/OCRPreviewWindowService.swift`、`AIAnalysisPreviewWindowService.swift`、`ScrollingCapturePanelService.swift`、`ScrollingCapturePreviewWindowService.swift`：当前通过 `NSHostingView` 承载 SwiftUI 的窗口 service。

需要创建的文件：

- `TYScreenShotTool/App/AppDelegate.swift`
- `TYScreenShotTool/App/MenuBarController.swift`
- `TYScreenShotTool/App/SettingsWindowController.swift`
- `TYScreenShotTool/App/SettingsViewController.swift`
- `TYScreenShotTool/App/HotKeyRecorderTextField.swift`
- `TYScreenShotTool/Features/Preview/OCRPreviewContentView.swift`
- `TYScreenShotTool/Features/Preview/AIAnalysisPreviewContentView.swift`
- `TYScreenShotTool/Features/ScrollingCapture/ScrollingCaptureControlPanelContentView.swift`
- `TYScreenShotTool/Features/ScrollingCapture/ScrollingCapturePreviewContentView.swift`
- `docs/SPRINTS/Sprint-45.md`

需要修改的文件：

- `TYScreenShotTool/App/SettingsOpenCoordinator.swift`
- `TYScreenShotTool/Services/OCRPreviewWindowService.swift`
- `TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift`
- `TYScreenShotTool/Services/ScrollingCapturePanelService.swift`
- `TYScreenShotTool/Services/ScrollingCapturePreviewWindowService.swift`
- `TYScreenShotTool/Shared/AppText.swift`
- `TYScreenShotTool/Shared/AppThemeCoordinator.swift`（只有在新窗口刷新注册缺口出现时才补）
- `TYScreenShotTool.xcodeproj/project.pbxproj`（仅当新增文件未自动入 target 时修改）
- `AGENTS.md`
- `README.md`
- `docs/ROADMAP.md`
- `docs/DEVLOG.md`

需要删除的文件：

- `TYScreenShotTool/App/TYScreenShotToolApp.swift`
- `TYScreenShotTool/App/MenuBarContentView.swift`
- `TYScreenShotTool/App/SettingsView.swift`
- `TYScreenShotTool/App/HotKeyRecorderField.swift`
- `TYScreenShotTool/Features/Preview/OCRPreviewView.swift`
- `TYScreenShotTool/Features/Preview/AIAnalysisPreviewView.swift`
- `TYScreenShotTool/Features/ScrollingCapture/ScrollingCaptureAIPopoverView.swift`
- `TYScreenShotTool/Features/ScrollingCapture/ScrollingCaptureControlPanelView.swift`

本轮不预期修改：

- `TYScreenShotTool/Services/CaptureSessionService.swift` 的截图业务语义，除非需要极小范围接入新的 UI 回调。
- Overlay、标注画布、拼接算法、AI/OCR 请求与结果数据结构。

---

### Task 1：重建 Settings 的 AppKit 栈基础骨架

**Files:**
- Create: `TYScreenShotTool/App/HotKeyRecorderTextField.swift`
- Create: `TYScreenShotTool/App/SettingsViewController.swift`
- Create: `TYScreenShotTool/App/SettingsWindowController.swift`
- Modify: `TYScreenShotTool/App/SettingsWindowController.swift`
- Delete: `TYScreenShotTool/App/SettingsView.swift`
- Delete: `TYScreenShotTool/App/HotKeyRecorderField.swift`

- [ ] **Step 1: 新增原生热键录制控件**

创建 `TYScreenShotTool/App/HotKeyRecorderTextField.swift`：

```swift
//
//  HotKeyRecorderTextField.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/22.
//

import AppKit
import Carbon

@MainActor
final class HotKeyRecorderTextField: NSTextField {
    var onBeginRecording: (() -> Void)?
    var onCandidateChanged: ((ScreenshotHotKey?) -> Void)?
    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?

    private var currentModifiers: UInt32 = 0
    private var currentCandidate: ScreenshotHotKey?
    private var outsideClickMonitor: Any?

    var isRecordingHotKey = false {
        didSet {
            updateAppearance()
            updateOutsideClickMonitor()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isEditable = false
        isBordered = false
        drawsBackground = true
        focusRingType = .none
        font = .systemFont(ofSize: 13)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        updateAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        if isRecordingHotKey == false {
            onBeginRecording?()
        }
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecordingHotKey else {
            return
        }

        if event.keyCode == UInt16(kVK_Return) {
            onCommit?()
            return
        }

        if event.keyCode == UInt16(kVK_Escape) {
            onCancel?()
            return
        }

        if let candidate = ScreenshotHotKey(event: event, modifiers: currentModifiers) {
            currentCandidate = candidate
            stringValue = candidate.displayName
            onCandidateChanged?(candidate)
        }
    }

    override func flagsChanged(with event: NSEvent) {
        guard isRecordingHotKey else {
            return
        }

        currentModifiers = event.carbonModifiers
        if currentCandidate == nil {
            stringValue = event.modifierDisplayName
            onCandidateChanged?(nil)
        }
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned, isRecordingHotKey {
            onCancel?()
        }
        return resigned
    }

    func resetRecordingState(displayedValue: String) {
        currentModifiers = 0
        currentCandidate = nil
        stringValue = displayedValue
        isRecordingHotKey = false
    }

    private func updateAppearance() {
        let borderColor = isRecordingHotKey
            ? NSColor.systemBlue.withAlphaComponent(0.55)
            : NSColor.separatorColor.withAlphaComponent(0.9)
        let fillColor = isRecordingHotKey
            ? NSColor.systemBlue.withAlphaComponent(0.08)
            : NSColor.textBackgroundColor

        layer?.borderColor = borderColor.cgColor
        layer?.backgroundColor = fillColor.cgColor
        backgroundColor = fillColor
    }

    private func updateOutsideClickMonitor() {
        if isRecordingHotKey, outsideClickMonitor == nil {
            outsideClickMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] event in
                guard let self, let window = self.window, event.window === window else {
                    return event
                }

                let point = self.convert(event.locationInWindow, from: nil)
                if self.bounds.contains(point) == false {
                    self.onCancel?()
                }
                return event
            }
        } else if isRecordingHotKey == false, let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }
}
```

如果 `ScreenshotHotKey(event:modifiers:)`、`NSEvent.carbonModifiers`、`NSEvent.modifierDisplayName` 尚不存在，就在同文件底部补最小 extension，而不是把事件转换逻辑散落回 controller：

```swift
private extension NSEvent {
    var carbonModifiers: UInt32 {
        var value: UInt32 = 0
        if modifierFlags.contains(.command) { value |= UInt32(cmdKey) }
        if modifierFlags.contains(.shift) { value |= UInt32(shiftKey) }
        if modifierFlags.contains(.option) { value |= UInt32(optionKey) }
        if modifierFlags.contains(.control) { value |= UInt32(controlKey) }
        return value
    }

    var modifierDisplayName: String {
        var parts: [String] = []
        if modifierFlags.contains(.command) { parts.append("Command") }
        if modifierFlags.contains(.shift) { parts.append("Shift") }
        if modifierFlags.contains(.option) { parts.append("Option") }
        if modifierFlags.contains(.control) { parts.append("Control") }
        return parts.joined(separator: " + ")
    }
}

private extension ScreenshotHotKey {
    init?(event: NSEvent, modifiers: UInt32) {
        guard let candidate = ScreenshotHotKey.makeCandidate(
            keyCode: UInt32(event.keyCode),
            modifiers: modifiers
        ) else {
            return nil
        }
        self = candidate
    }
}
```

- [ ] **Step 2: 新增 AppKit Settings 页面**

创建 `TYScreenShotTool/App/SettingsViewController.swift`：

```swift
//
//  SettingsViewController.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/22.
//

import AppKit
import SnapKit

@MainActor
final class SettingsViewController: NSViewController {
    private let globalHotKeyService: GlobalHotKeyService

    private let scrollView = NSScrollView()
    private let contentStack = NSStackView()
    private let hotKeyField = HotKeyRecorderTextField()
    private let hotKeyErrorLabel = NSTextField(labelWithString: "")
    private let languagePopUp = NSPopUpButton()
    private let appearancePopUp = NSPopUpButton()
    private let aiVisionCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let saveDirectoryLabel = NSTextField(labelWithString: "")

    private var pendingHotKey: ScreenshotHotKey?
    private var previousHotKey: ScreenshotHotKey?

    init(globalHotKeyService: GlobalHotKeyService) {
        self.globalHotKeyService = globalHotKeyService
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
        buildLayout()
        bindActions()
        reloadValues()
    }
}
```

在同文件里补齐以下私有方法：

```swift
private extension SettingsViewController {
    func buildLayout() {
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 16

        let documentView = NSView()
        documentView.addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(24)
            make.width.equalToSuperview().offset(-48)
        }

        scrollView.documentView = documentView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func bindActions() {
        hotKeyField.onBeginRecording = { [weak self] in self?.beginHotKeyRecording() }
        hotKeyField.onCandidateChanged = { [weak self] candidate in self?.pendingHotKey = candidate }
        hotKeyField.onCommit = { [weak self] in self?.commitHotKey() }
        hotKeyField.onCancel = { [weak self] in self?.cancelHotKeyRecording() }

        languagePopUp.target = self
        languagePopUp.action = #selector(languageChanged)
        appearancePopUp.target = self
        appearancePopUp.action = #selector(appearanceChanged)
        aiVisionCheckbox.target = self
        aiVisionCheckbox.action = #selector(aiVisionChanged)
    }

    func reloadValues() {
        let storedHotKey = ScreenshotHotKey(
            storageValue: UserDefaults.standard.string(forKey: AppSettings.screenshotHotKeyKey)
                ?? AppSettings.screenshotHotKeyDefaultValue
        ) ?? .screenshot
        hotKeyField.resetRecordingState(displayedValue: storedHotKey.displayName)
        hotKeyErrorLabel.stringValue = ""
        saveDirectoryLabel.stringValue = currentSaveDirectoryPath
    }

    var currentSaveDirectoryPath: String {
        let path = UserDefaults.standard.string(forKey: AppSettings.saveDirectoryPathKey) ?? ""
        return path.isEmpty ? AppLocalization.text("settings.save.not_configured") : path
    }
}
```

在同文件里补齐最小动作与持久化方法：

```swift
private extension SettingsViewController {
    @objc func languageChanged() {
        let selected = AppLanguage.allCases[languagePopUp.indexOfSelectedItem]
        UserDefaults.standard.set(selected.storageValue, forKey: AppSettings.appLanguageKey)
    }

    @objc func appearanceChanged() {
        let selected = AppAppearance.allCases[appearancePopUp.indexOfSelectedItem]
        UserDefaults.standard.set(selected.storageValue, forKey: AppSettings.appAppearanceKey)
        AppThemeCoordinator.shared.applyCurrentAppearance()
    }

    @objc func aiVisionChanged() {
        UserDefaults.standard.set(
            aiVisionCheckbox.state == .on,
            forKey: AppSettings.aiUseVisionTextExtractionKey
        )
    }

    func beginHotKeyRecording() {
        let current = ScreenshotHotKey(
            storageValue: UserDefaults.standard.string(forKey: AppSettings.screenshotHotKeyKey)
                ?? AppSettings.screenshotHotKeyDefaultValue
        ) ?? .screenshot
        previousHotKey = current
        pendingHotKey = nil
        hotKeyField.isRecordingHotKey = true
    }

    func commitHotKey() {
        guard let pendingHotKey else {
            cancelHotKeyRecording()
            return
        }

        if globalHotKeyService.updateHotKey(pendingHotKey) {
            UserDefaults.standard.set(pendingHotKey.storageValue, forKey: AppSettings.screenshotHotKeyKey)
            hotKeyField.resetRecordingState(displayedValue: pendingHotKey.displayName)
            hotKeyErrorLabel.stringValue = ""
        } else {
            hotKeyErrorLabel.stringValue = AppLocalization.text("settings.hotkey.error.registration_failed")
            cancelHotKeyRecording()
        }
    }

    func cancelHotKeyRecording() {
        let fallback = previousHotKey ?? .screenshot
        hotKeyField.resetRecordingState(displayedValue: fallback.displayName)
        pendingHotKey = nil
    }

    func chooseSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = AppLocalization.text("settings.save.choose")
        panel.message = AppLocalization.text("settings.save.panel_message")

        let currentPath = UserDefaults.standard.string(forKey: AppSettings.saveDirectoryPathKey) ?? ""
        if currentPath.isEmpty == false {
            panel.directoryURL = URL(fileURLWithPath: currentPath, isDirectory: true)
        } else {
            panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        }

        guard panel.runModal() == .OK, let selectedDirectoryURL = panel.url else {
            return
        }

        do {
            let bookmarkData = try selectedDirectoryURL.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: AppSettings.saveDirectoryBookmarkDataKey)
            UserDefaults.standard.set(selectedDirectoryURL.path, forKey: AppSettings.saveDirectoryPathKey)
            saveDirectoryLabel.stringValue = selectedDirectoryURL.path
        } catch {
            print("Save directory bookmark creation failed: \(error.localizedDescription)")
        }
    }

    func clearSaveDirectory() {
        UserDefaults.standard.set("", forKey: AppSettings.saveDirectoryPathKey)
        UserDefaults.standard.set(Data(), forKey: AppSettings.saveDirectoryBookmarkDataKey)
        saveDirectoryLabel.stringValue = currentSaveDirectoryPath
    }
}
```

`chooseSaveDirectory()` 保持旧 `SettingsView.swift` 的 `NSOpenPanel` 与 bookmark 逻辑语义不变，只把状态回显从 SwiftUI 绑定改成显式控件刷新。

- [ ] **Step 3: 新增 `SettingsWindowController` 并改造协调器**

创建 `TYScreenShotTool/App/SettingsWindowController.swift`：

```swift
//
//  SettingsWindowController.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/22.
//

import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    init(contentViewController: NSViewController) {
        let window = NSWindow(contentViewController: contentViewController)
        window.title = AppLocalization.text("window.settings.title")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 460, height: 360)
        window.setContentSize(NSSize(width: 520, height: 580))
        window.center()
        AppThemeCoordinator.shared.applyCurrentAppearance(to: window)
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
```

把 `TYScreenShotTool/App/SettingsOpenCoordinator.swift` 改成：

```swift
import AppKit

@MainActor
final class SettingsOpenCoordinator {
    private var settingsWindowController: SettingsWindowController?
    private var settingsViewController: SettingsViewController?

    func configure(contentProvider: @escaping () -> SettingsViewController) {
        let viewController = settingsViewController ?? contentProvider()
        settingsViewController = viewController

        if let settingsWindowController {
            settingsWindowController.contentViewController = viewController
            settingsWindowController.window?.title = AppLocalization.text("window.settings.title")
        }
    }

    func openSettings() {
        guard let settingsViewController else {
            return
        }

        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                contentViewController: settingsViewController
            )
        } else {
            settingsWindowController?.contentViewController = settingsViewController
            settingsWindowController?.window?.title = AppLocalization.text("window.settings.title")
        }

        if let window = settingsWindowController?.window {
            AppThemeCoordinator.shared.applyCurrentAppearance(to: window)
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
    }
}
```

这里要显式复用同一个 `SettingsViewController` 实例，而不是每次打开窗口或语言变化时都重新创建 content view controller；否则会丢失窗口内的临时编辑状态，也会让后续语言刷新链路退化成“重建整个设置页”。

- [ ] **Step 4: 做静态校验，确认这是允许的中间态**

运行：

```bash
rg -n "SettingsView\\(|SettingsOpenCoordinator\\.configure|HotKeyRecorderField" TYScreenShotTool -S
```

预期：

```text
仍能看到旧 SwiftUI Settings 调用点，这是预期中的中间态。
```

这一步的目标是先把 AppKit Settings 栈引入工程，入口和旧 SwiftUI Settings 调用点会在后续任务统一切换。

- [ ] **Step 5: 提交**

```bash
git add TYScreenShotTool/App/HotKeyRecorderTextField.swift \
  TYScreenShotTool/App/SettingsViewController.swift \
  TYScreenShotTool/App/SettingsWindowController.swift \
  TYScreenShotTool/App/SettingsOpenCoordinator.swift
git commit -m "feat(settings): 新增 AppKit 设置窗口栈"
```

---

### Task 2：补齐完整 Settings 页面结构与 action wiring

**Files:**
- Modify: `TYScreenShotTool/App/SettingsViewController.swift`
- Modify: `TYScreenShotTool/App/HotKeyRecorderTextField.swift`
- Modify: `TYScreenShotTool/Shared/AppText.swift`

- [ ] **Step 1: 把 Settings 拆成完整的 5 个 section**

在 `SettingsViewController.swift` 中新增并接入：

```swift
private extension SettingsViewController {
    func makeHotKeySection() -> NSView
    func makeLanguageSection() -> NSView
    func makeAppearanceSection() -> NSView
    func makeAISection() -> NSView
    func makeSaveDirectorySection() -> NSView
    func makeTitleLabel(_ text: String) -> NSTextField
    func makeDescriptionLabel(_ text: String) -> NSTextField
    func makeSectionTitle(_ text: String) -> NSTextField
    func makeSecondaryLabel(_ text: String) -> NSTextField
}
```

并将 `buildLayout()` 改为把以下内容真实加入 `contentStack`：

```swift
let titleLabel = makeTitleLabel(AppLocalization.text("settings.title"))
let descriptionLabel = makeDescriptionLabel(AppLocalization.text("settings.description"))
let hotKeySection = makeHotKeySection()
let languageSection = makeLanguageSection()
let appearanceSection = makeAppearanceSection()
let aiSection = makeAISection()
let saveSection = makeSaveDirectorySection()

[titleLabel, descriptionLabel, hotKeySection, languageSection, appearanceSection, aiSection, saveSection]
    .forEach(contentStack.addArrangedSubview)
```

页面结构必须与旧 [SettingsView.swift](/Users/sheldon/CodeRepo/TYScreenShotTool/TYScreenShotTool/App/SettingsView.swift:62) 的 section 顺序一致，而不是只保留一堆未挂载控件。

- [ ] **Step 2: 把每个 section 的控件和文案挂到真实视图树**

要求每个 section 都包含：

- section 标题
- 说明文字
- 输入控件
- 对应操作按钮
- 必要的错误提示

关键 wiring 至少要包括：

```swift
hotKeyField.placeholderString = AppLocalization.text("settings.hotkey.placeholder")
aiVisionCheckbox.title = AppLocalization.text("settings.ai.use_vision")

languagePopUp.removeAllItems()
languagePopUp.addItems(withTitles: [
    AppLocalization.text("settings.language.option.system"),
    AppLocalization.text("settings.language.option.zh_hans"),
    AppLocalization.text("settings.language.option.en"),
    AppLocalization.text("settings.language.option.ja"),
    AppLocalization.text("settings.language.option.ko"),
    AppLocalization.text("settings.language.option.de"),
    AppLocalization.text("settings.language.option.fr"),
])

appearancePopUp.removeAllItems()
appearancePopUp.addItems(withTitles: [
    AppLocalization.text("settings.appearance.option.system"),
    AppLocalization.text("settings.appearance.option.light"),
    AppLocalization.text("settings.appearance.option.dark"),
])

let chooseButton = NSButton(
    title: AppLocalization.text("settings.save.choose"),
    target: self,
    action: #selector(handleChooseSaveDirectory)
)
let clearButton = NSButton(
    title: AppLocalization.text("settings.save.clear"),
    target: self,
    action: #selector(handleClearSaveDirectory)
)
```

这里不能只描述“有一个设置页”，而要把旧 SwiftUI 页面中的每个 section 真实落到 AppKit 视图树里。
下拉框不能只声明不填充；必须在本任务里把语言和外观选项完整灌入，否则后面的 `selectItem(at:)` 回显没有意义。
`languagePopUp` 的条目顺序必须与 `AppLanguage.allCases` 完全一致，`appearancePopUp` 的条目顺序必须与 `AppAppearance.allCases` 完全一致；只要顺序漂移，`selectItem(at:)` 的 index 回显就会错位。

- [ ] **Step 3: 补齐所有值回显与 action wiring**

在 `reloadValues()` 中补齐：

```swift
let currentLanguage = AppLanguage(rawValue: UserDefaults.standard.string(forKey: AppSettings.appLanguageKey)
    ?? AppSettings.appLanguageDefaultValue) ?? .system
languagePopUp.selectItem(at: AppLanguage.allCases.firstIndex(of: currentLanguage) ?? 0)

let currentAppearance = AppAppearance(rawValue: UserDefaults.standard.string(forKey: AppSettings.appAppearanceKey)
    ?? AppSettings.appAppearanceDefaultValue) ?? .system
appearancePopUp.selectItem(at: AppAppearance.allCases.firstIndex(of: currentAppearance) ?? 0)

aiVisionCheckbox.state = UserDefaults.standard.bool(forKey: AppSettings.aiUseVisionTextExtractionKey) ? .on : .off
saveDirectoryLabel.stringValue = currentSaveDirectoryPath
```

并补齐：

```swift
@objc func handleChooseSaveDirectory() { chooseSaveDirectory() }
@objc func handleClearSaveDirectory() { clearSaveDirectory() }
func reloadLocalizedTexts()
```

热键录制必须继续保留现有语义：

- 点击输入框开始录制
- `Return` 提交
- `Esc` 取消
- 点击外部取消
- 注册失败恢复旧值

`reloadLocalizedTexts()` 在本任务中就要落地，至少负责：

- 刷新窗口内 title / description
- 刷新 5 个 section 标题
- 刷新按钮标题
- 刷新 help / error / placeholder 文案
- 重新填充语言与外观下拉项并保留当前选中值

- [ ] **Step 4: 做静态校验，确认 Settings 任务描述已经闭环**

运行：

```bash
rg -n "makeHotKeySection|makeLanguageSection|makeAppearanceSection|makeAISection|makeSaveDirectorySection|handleChooseSaveDirectory|handleClearSaveDirectory|reloadLocalizedTexts|addItems\\(withTitles" TYScreenShotTool/App/SettingsViewController.swift -S
```

预期：

```text
每个 section builder 和保存目录 action 都已出现。
```

- [ ] **Step 5: 提交**

```bash
git add TYScreenShotTool/App/SettingsViewController.swift \
  TYScreenShotTool/App/HotKeyRecorderTextField.swift \
  TYScreenShotTool/Shared/AppText.swift
git commit -m "feat(settings): 补齐 AppKit 设置页面结构"
```

---

### Task 3：切换应用入口为 `AppDelegate + NSStatusItem`

**Files:**
- Create: `TYScreenShotTool/App/AppDelegate.swift`
- Create: `TYScreenShotTool/App/MenuBarController.swift`
- Modify: `TYScreenShotTool/App/SettingsOpenCoordinator.swift`
- Delete: `TYScreenShotTool/App/TYScreenShotToolApp.swift`
- Delete: `TYScreenShotTool/App/MenuBarContentView.swift`

- [ ] **Step 1: 新增菜单栏控制器**

创建 `TYScreenShotTool/App/MenuBarController.swift`：

```swift
//
//  MenuBarController.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/22.
//

import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let settingsOpenCoordinator: SettingsOpenCoordinator

    init(settingsOpenCoordinator: SettingsOpenCoordinator) {
        self.settingsOpenCoordinator = settingsOpenCoordinator
        super.init()
        configureStatusItem()
    }

    func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: AppText.openSettingsButton, action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: AppText.appQuit, action: #selector(quitApp), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    private func configureStatusItem() {
        statusItem.button?.image = NSImage(named: "MenuBarIcon")
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.accessibilityLabel = AppLocalization.text("app.name")
        rebuildMenu()
    }

    @objc private func openSettings() {
        settingsOpenCoordinator.openSettings()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
```

在 `TYScreenShotTool/Shared/AppText.swift` 中补一条最小文案：

```swift
static var appQuit: String {
    choose(
        zhHans: "退出",
        en: "Quit",
        ja: "終了",
        ko: "종료",
        de: "Beenden",
        fr: "Quitter"
    )
}
```

- [ ] **Step 2: 将现有 service 初始化迁入 `AppDelegate`**

创建 `TYScreenShotTool/App/AppDelegate.swift`：

```swift
//
//  AppDelegate.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/22.
//

import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var captureSessionService: CaptureSessionService?
    private var globalHotKeyService: GlobalHotKeyService?
    private var settingsOpenCoordinator: SettingsOpenCoordinator?
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppThemeCoordinator.shared.applyCurrentAppearance()

        let overlayService = CaptureOverlayService()
        let screenCaptureService = ScreenCaptureService()
        let clipboardService = ClipboardService()
        let imageSaveService = ImageSaveService()
        let pinWindowService = PinWindowService()
        let toastService = ToastService()
        let scrollingCaptureService = ScrollingCaptureService()
        let scrollingCapturePanelService = ScrollingCapturePanelService()
        let scrollingCapturePreviewWindowService = ScrollingCapturePreviewWindowService()
        let ocrPreviewWindowService = OCRPreviewWindowService()
        let aiImageTextExtractionService = AIImageTextExtractionService()
        let aiAnalysisService = AIAnalysisService()
        let aiAnalysisPreviewWindowService = AIAnalysisPreviewWindowService()
        let windowSelectionService = WindowSelectionService()
        let hotKeyService = GlobalHotKeyService(
            hotKey: Self.loadConfiguredHotKey(),
            onHotKeyPressed: {}
        )
        let settingsCoordinator = SettingsOpenCoordinator()
        settingsCoordinator.configure {
            SettingsViewController(globalHotKeyService: hotKeyService)
        }

        let sessionService = CaptureSessionService(
            overlayService: overlayService,
            screenCaptureService: screenCaptureService,
            clipboardService: clipboardService,
            imageSaveService: imageSaveService,
            ocrService: OCRService(),
            aiImageTextExtractionService: aiImageTextExtractionService,
            aiAnalysisService: aiAnalysisService,
            pinWindowService: pinWindowService,
            toastService: toastService,
            settingsOpenCoordinator: settingsCoordinator,
            scrollingCaptureService: scrollingCaptureService,
            scrollingCapturePanelService: scrollingCapturePanelService,
            scrollingCapturePreviewWindowService: scrollingCapturePreviewWindowService,
            ocrPreviewWindowService: ocrPreviewWindowService,
            aiAnalysisPreviewWindowService: aiAnalysisPreviewWindowService
        )

        overlayService.onCancel = {
            sessionService.cancelSession()
        }
        overlayService.onDragStarted = {
            sessionService.beginDragging()
        }
        overlayService.onSelectionCompleted = { rect in
            sessionService.completeSelection(rect)
        }
        overlayService.onWindowSelectionConfirmed = { candidate in
            sessionService.confirmWindowSelection(candidate)
        }
        overlayService.windowCandidateProvider = { screenPoint in
            windowSelectionService.candidateWindow(at: screenPoint)
        }
        overlayService.onPreviewSelectionChanged = { rect in
            sessionService.updatePendingSelection(rect)
        }
        overlayService.onCopyRequested = { style, annotations in
            sessionService.copyPendingCapture(style: style, annotations: annotations)
        }
        overlayService.onSaveRequested = { style, annotations in
            sessionService.savePendingCapture(style: style, annotations: annotations)
        }
        overlayService.onOCRRequested = { style, annotations in
            sessionService.ocrPendingCapture(style: style, annotations: annotations)
        }
        overlayService.onAIRequested = { mode, style, annotations in
            sessionService.analyzePendingCapture(
                mode: mode,
                style: style,
                annotations: annotations
            )
        }
        overlayService.onPinRequested = { style, annotations in
            sessionService.pinPendingCapture(style: style, annotations: annotations)
        }
        overlayService.onLongCaptureRequested = { annotations in
            sessionService.startScrollingCapture(annotations: annotations)
        }
        scrollingCapturePanelService.onCancelRequested = {
            sessionService.cancelSession()
        }
        scrollingCapturePanelService.onCopyRequested = {
            sessionService.copyScrollingCaptureResult()
        }
        scrollingCapturePanelService.onOCRRequested = {
            sessionService.ocrScrollingCaptureResult()
        }
        scrollingCapturePanelService.onAIRequested = { mode in
            sessionService.analyzeScrollingCaptureResult(mode: mode)
        }
        scrollingCapturePanelService.onSaveRequested = {
            sessionService.saveScrollingCaptureResult()
        }

        hotKeyService.onHotKeyPressed = {
            let sourceApplication = NSWorkspace.shared.frontmostApplication
            sessionService.setSourceApplication(sourceApplication)
            NSApplication.shared.activate(ignoringOtherApps: true)
            sessionService.startSession()
        }

        _ = hotKeyService.register()

        captureSessionService = sessionService
        globalHotKeyService = hotKeyService
        settingsOpenCoordinator = settingsCoordinator
        menuBarController = MenuBarController(settingsOpenCoordinator: settingsCoordinator)
    }

    private static func loadConfiguredHotKey() -> ScreenshotHotKey {
        let storageValue = UserDefaults.standard.string(forKey: AppSettings.screenshotHotKeyKey)
            ?? AppSettings.screenshotHotKeyDefaultValue
        return ScreenshotHotKey(storageValue: storageValue) ?? .screenshot
    }
}
```

把 `TYScreenShotToolApp.init()` 里现有全部 service 回调绑定逐字迁入 `applicationDidFinishLaunching`，不要趁机改闭包语义。

- [ ] **Step 3: 删除旧的 SwiftUI 入口**

运行：

```bash
git rm TYScreenShotTool/App/TYScreenShotToolApp.swift \
  TYScreenShotTool/App/MenuBarContentView.swift
```

然后运行：

```bash
rg -n "@main|MenuBarExtra|NSHostingController|SettingsView\\(" TYScreenShotTool/App -S
```

预期：

```text
只应剩余 `AppDelegate.swift` 中的新 `@main`，不应再命中 `MenuBarExtra` 或旧 `SettingsView(` 入口。
```

如果这里出现“新文件未被 target 包含”，再补 `TYScreenShotTool.xcodeproj/project.pbxproj`，优先确认是否是 `PBXFileSystemSynchronizedRootGroup` 未自动纳入。

- [ ] **Step 4: 提交**

```bash
git add TYScreenShotTool/App/AppDelegate.swift TYScreenShotTool/App/MenuBarController.swift
git commit -m "refactor(app): 切换为 AppKit 菜单栏入口"
```

---

### Task 4：将 OCR / AI 结果窗内容层改为纯 AppKit

**Files:**
- Create: `TYScreenShotTool/Features/Preview/OCRPreviewContentView.swift`
- Create: `TYScreenShotTool/Features/Preview/AIAnalysisPreviewContentView.swift`
- Modify: `TYScreenShotTool/Shared/AppText.swift`
- Modify: `TYScreenShotTool/Services/OCRPreviewWindowService.swift`
- Modify: `TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift`
- Delete: `TYScreenShotTool/Features/Preview/OCRPreviewView.swift`
- Delete: `TYScreenShotTool/Features/Preview/AIAnalysisPreviewView.swift`

- [ ] **Step 1: 新增 OCR 结果内容视图**

创建 `TYScreenShotTool/Features/Preview/OCRPreviewContentView.swift`：

```swift
//
//  OCRPreviewContentView.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/22.
//

import AppKit
import SnapKit

@MainActor
final class OCRPreviewContentView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let scrollView = NSScrollView()
    private let textView = NSTextView()
    private let copyButton = NSButton(title: "", target: nil, action: nil)
    private let cancelButton = NSButton(title: "", target: nil, action: nil)

    var onCopy: (() -> Void)?
    var onCancel: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        copyButton.target = self
        copyButton.action = #selector(handleCopy)
        cancelButton.target = self
        cancelButton.action = #selector(handleCancel)
    }

    func configure(
        title: String,
        text: String,
        isCopyEnabled: Bool,
        copyTitle: String,
        cancelTitle: String
    ) {
        titleLabel.stringValue = title
        textView.string = text
        copyButton.title = copyTitle
        cancelButton.title = cancelTitle
        copyButton.isEnabled = isCopyEnabled
    }

    @objc private func handleCopy() { onCopy?() }
    @objc private func handleCancel() { onCancel?() }
}
```

在同文件 `private extension` 中补齐 `buildLayout()`，要求：

```swift
titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
textView.isEditable = false
textView.drawsBackground = false
scrollView.drawsBackground = false
scrollView.hasVerticalScroller = true
```

并用 SnapKit 完成：

```swift
make.edges.equalToSuperview().inset(16)
```

风格上保持当前面板由 `NSVisualEffectView` 提供背景，本视图不要再加第二层材质背景。

- [ ] **Step 2: 新增 AI 结果内容视图**

创建 `TYScreenShotTool/Features/Preview/AIAnalysisPreviewContentView.swift`，要求保留 3 类状态：

```swift
enum AIAnalysisPreviewContent {
    case loading(message: String)
    case error(title: String, message: String)
    case result(AIAnalysisResult)
}
```

主视图骨架：

```swift
@MainActor
final class AIAnalysisPreviewContentView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let scrollView = NSScrollView()
    private let bodyStack = NSStackView()
    private let copyAllButton = NSButton(title: "", target: nil, action: nil)
    private let secondaryButton = NSButton(title: "", target: nil, action: nil)
    private let retryButton = NSButton(title: "", target: nil, action: nil)
    private let closeButton = NSButton(title: "", target: nil, action: nil)

    var onCopyAll: (() -> Void)?
    var onCopySecondary: (() -> Void)?
    var onRetry: (() -> Void)?
    var onClose: (() -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        copyAllButton.target = self
        copyAllButton.action = #selector(handleCopyAll)
        secondaryButton.target = self
        secondaryButton.action = #selector(handleCopySecondary)
        retryButton.target = self
        retryButton.action = #selector(handleRetry)
        closeButton.target = self
        closeButton.action = #selector(handleClose)
    }

    func configure(
        title: String,
        content: AIAnalysisPreviewContent,
        copyAllTitle: String,
        secondaryTitle: String?,
        retryTitle: String,
        closeTitle: String
    ) {
        titleLabel.stringValue = title
        copyAllButton.title = copyAllTitle
        secondaryButton.title = secondaryTitle ?? ""
        retryButton.title = retryTitle
        closeButton.title = closeTitle
        rebuildBody(for: content)
        rebuildButtons(for: content)
    }

    @objc private func handleCopyAll() { onCopyAll?() }
    @objc private func handleCopySecondary() { onCopySecondary?() }
    @objc private func handleRetry() { onRetry?() }
    @objc private func handleClose() { onClose?() }
}
```

这里的关键不是追求最小代码量，而是把旧 SwiftUI `buttonRow` 的逻辑迁成显式 AppKit 布局：宽度足够时横排，宽度不足时改成纵排；不要硬编码始终单行，否则会退化 Sprint 42 已修好的窄宽度按钮布局。
结果窗按钮不能只存在闭包属性，必须在本任务里把按钮点击桥接到 `onCopyAll/onCopySecondary/onRetry/onClose`，否则 UI 只是“看起来像完成了”。
`secondaryButton` 的标题和可用状态不能写死，必须显式沿用旧 SwiftUI 语义：

- `content` 为 `.result(result)` 时，标题来自 `result.mode.secondaryCopyButtonTitle`
- 非结果态时隐藏或禁用 `secondaryButton`
- `copyAllButton / secondaryButton / retryButton / closeButton` 必须真实加入按钮行 stack，而不是只声明属性再靠闭包“名义存在”

- [ ] **Step 3: 改造两个窗口 service 去掉 `NSHostingView`**

把 `TYScreenShotTool/Services/OCRPreviewWindowService.swift` 改成：

```swift
import AppKit
import SnapKit

@MainActor
final class OCRPreviewWindowService {
    private let panel = NSPanel(
        contentRect: .zero,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    private let containerView = NSVisualEffectView()
    private let contentView = OCRPreviewContentView()

    init() {
        panel.contentView = containerView
        containerView.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
```

把 `installContentView(...)` 替换为：

```swift
contentView.onCopy = onCopy
contentView.onCancel = onCancel
contentView.configure(
    title: AppText.ocrWindowTitle,
    text: text,
    isCopyEnabled: isCopyEnabled,
    copyTitle: AppText.captureCopy,
    cancelTitle: AppText.captureCancel
)
```

`AIAnalysisPreviewWindowService.swift` 做同样改造：移除 `import SwiftUI`、移除 `hostingView` 属性，换成常驻的 `AIAnalysisPreviewContentView`。
调用 `contentView.configure(...)` 时要与前面定义的签名保持一致；如果当前 `content` 是 `.result(result)`，则显式传入：

```swift
secondaryTitle: result.mode.secondaryCopyButtonTitle
```

如果当前 `content` 不是结果态，则传入：

```swift
secondaryTitle: nil
```

不要在 service 层遗漏这个参数，否则 Task 4 前后会出现方法签名不一致。

- [ ] **Step 4: 删除旧 SwiftUI 结果视图并做静态校验**

运行：

```bash
git rm TYScreenShotTool/Features/Preview/OCRPreviewView.swift \
  TYScreenShotTool/Features/Preview/AIAnalysisPreviewView.swift
rg -n "import SwiftUI|NSHostingView" TYScreenShotTool/Features/Preview TYScreenShotTool/Services/OCRPreviewWindowService.swift TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift -S
```

预期：

```text
结果窗相关 SwiftUI / NSHostingView 依赖已清零。
```

- [ ] **Step 5: 提交**

```bash
git add TYScreenShotTool/Features/Preview/OCRPreviewContentView.swift \
  TYScreenShotTool/Features/Preview/AIAnalysisPreviewContentView.swift \
  TYScreenShotTool/Services/OCRPreviewWindowService.swift \
  TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift
git commit -m "refactor(preview): 结果窗口改为纯 AppKit 内容"
```

---

### Task 5：将长截图控制面板与预览窗改为纯 AppKit

**Files:**
- Create: `TYScreenShotTool/Features/ScrollingCapture/ScrollingCaptureControlPanelContentView.swift`
- Modify: `TYScreenShotTool/Shared/AppText.swift`
- Modify: `TYScreenShotTool/Features/ScrollingCapture/ScrollingCapturePreviewContentView.swift`
- Modify: `TYScreenShotTool/Services/ScrollingCapturePanelService.swift`
- Modify: `TYScreenShotTool/Services/ScrollingCapturePreviewWindowService.swift`
- Delete: `TYScreenShotTool/Features/ScrollingCapture/ScrollingCaptureAIPopoverView.swift`
- Delete: `TYScreenShotTool/Features/ScrollingCapture/ScrollingCaptureControlPanelView.swift`

- [ ] **Step 1: 新增长截图控制面板内容视图**

创建 `TYScreenShotTool/Features/ScrollingCapture/ScrollingCaptureControlPanelContentView.swift`：

```swift
//
//  ScrollingCaptureControlPanelContentView.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/22.
//

import AppKit
import SnapKit

@MainActor
final class ScrollingCaptureControlPanelContentView: NSView {
    private let rootStackView = NSStackView()
    private let firstRowStackView = NSStackView()
    private let secondRowStackView = NSStackView()
    private let cancelButton = NSButton(title: "", target: nil, action: nil)
    private let ocrButton = NSButton(title: "", target: nil, action: nil)
    private let aiButton = NSButton(title: "", target: nil, action: nil)
    private let saveButton = NSButton(title: "", target: nil, action: nil)
    private let copyButton = NSButton(title: "", target: nil, action: nil)

    var onCancel: (() -> Void)?
    var onOCR: (() -> Void)?
    var onAISelected: ((AIAnalysisMode) -> Void)?
    var onSave: (() -> Void)?
    var onCopy: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        cancelButton.target = self
        cancelButton.action = #selector(handleCancel)
        ocrButton.target = self
        ocrButton.action = #selector(handleOCR)
        aiButton.target = self
        aiButton.action = #selector(handleAI)
        saveButton.target = self
        saveButton.action = #selector(handleSave)
        copyButton.target = self
        copyButton.action = #selector(handleCopy)
    }

    func configure(isOCREnabled: Bool, isAIEnabled: Bool) {
        cancelButton.title = AppText.captureCancel
        ocrButton.title = AppText.captureOCR
        aiButton.title = AppText.captureAI
        saveButton.title = AppText.captureSave
        copyButton.title = AppText.captureCopy
        ocrButton.isEnabled = isOCREnabled
        aiButton.isEnabled = isAIEnabled
    }

    @objc private func handleCancel() { onCancel?() }
    @objc private func handleOCR() { onOCR?() }
    @objc private func handleAI() { presentAIMenu() }
    @objc private func handleSave() { onSave?() }
    @objc private func handleCopy() { onCopy?() }
}
```

在 `TYScreenShotTool/Shared/AppText.swift` 中补齐最小文案来源：

```swift
static var captureOCR: String { "OCR" }
static var captureAI: String { "AI" }
```

如果希望本轮顺手做完整本地化，也可以把这两个值改成 `choose(...)` 风格；但计划里至少要给出明确来源，不能引用不存在的属性。

`aiButton` 点击后不要再弹 SwiftUI `Popover`，改为当前 view 上下文 `NSMenu.popUpContextMenu`，菜单项复用：

```swift
AIAnalysisMode.topLevelModes
AITranslationLanguage.allCases
```

并将 `.translation(language)` 映射回 `onAISelected`。菜单 wiring 也要写实：

```swift
private func presentAIMenu() {
    let menu = NSMenu()

    for mode in AIAnalysisMode.topLevelModes {
        let item = NSMenuItem(title: mode.menuTitle, action: #selector(handleAIMenuSelection(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = mode
        menu.addItem(item)
    }

    let translationMenu = NSMenu()
    for language in AITranslationLanguage.allCases {
        let item = NSMenuItem(title: language.menuTitle, action: #selector(handleAIMenuSelection(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = AIAnalysisMode.translation(language)
        translationMenu.addItem(item)
    }

    let translationItem = NSMenuItem(title: AppText.aiTranslationMenu, action: nil, keyEquivalent: "")
    translationItem.submenu = translationMenu
    menu.addItem(.separator())
    menu.addItem(translationItem)

    guard let event = NSApp.currentEvent else {
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: aiButton.bounds.height), in: aiButton)
        return
    }
    NSMenu.popUpContextMenu(menu, with: event, for: aiButton)
}

@objc private func handleAIMenuSelection(_ sender: NSMenuItem) {
    guard let mode = sender.representedObject as? AIAnalysisMode else { return }
    onAISelected?(mode)
}
```

控制面板按钮不能只存在闭包属性，必须在本任务里把 `cancel/ocr/ai/save/copy` 全部桥接成可点击行为。
这里要避免对 `NSApp.currentEvent` 做强制解包；按钮 action 路径下拿不到 event 时，仍需能通过相对 `aiButton` 的方式安全弹出菜单。

布局要求必须保留窄宽度自适应，不允许退回固定单行。建议直接复刻当前 SwiftUI 版 [ScrollingCaptureControlPanelView.swift](/Users/sheldon/CodeRepo/TYScreenShotTool/TYScreenShotTool/Features/ScrollingCapture/ScrollingCaptureControlPanelView.swift:21) 的“两行回落”语义：

```swift
override func layout() {
    super.layout()

    let compact = bounds.width < 430
    secondRowStackView.isHidden = compact == false

    if compact {
        firstRowStackView.setViews([cancelButton, ocrButton, aiButton], in: .leading)
        secondRowStackView.setViews([saveButton, copyButton], in: .leading)
    } else {
        firstRowStackView.setViews([cancelButton, ocrButton, aiButton, saveButton, copyButton], in: .leading)
        secondRowStackView.setViews([], in: .leading)
    }
}
```

- [ ] **Step 2: 改造面板 service 去掉 SwiftUI 测量逻辑**

把 `TYScreenShotTool/Services/ScrollingCapturePanelService.swift` 改成常驻 AppKit 内容视图：

```swift
import AppKit
import Foundation
import SnapKit

@MainActor
final class ScrollingCapturePanelService {
    private var panel: ScrollingCapturePanel?
    private let containerView = NSVisualEffectView()
    private let contentView = ScrollingCaptureControlPanelContentView()

    func presentCapturePanel(selectionRect: CGRect, on screen: NSScreen) {
        let panelInstance: ScrollingCapturePanel
        if let existingPanel = self.panel {
            panelInstance = existingPanel
        } else {
            let createdPanel = ScrollingCapturePanel(contentRect: CGRect(x: 0, y: 0, width: 480, height: 42))
            self.panel = createdPanel
            panelInstance = createdPanel
        }
        if panelInstance.contentView !== containerView {
            panelInstance.contentView = containerView
            containerView.addSubview(contentView)
            contentView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }

        contentView.configure(
            isOCREnabled: onOCRRequested != nil,
            isAIEnabled: onAIRequested != nil
        )
    }
}
```

这里不能只把新 panel 放进局部变量；必须显式回写到 `self.panel`，保证控制面板是被 service 持有的常驻实例。

删除 `makeRootView()`、`measuredContentSize()` 和所有 `NSHostingView` 测量代码，但不要把面板尺寸退回固定单行。判断紧凑模式时不要依赖 `NSScreen.main`，而要基于当前截图所在屏幕或当前 `selectionRect` 的真实可用空间。改为：

```swift
private func measuredPanelFrameSize(for panel: NSPanel, selectionRect: CGRect, on screen: NSScreen) -> CGSize {
    let frame = screen.visibleFrame
    let horizontalPadding: CGFloat = 48
    let availableWidth = min(
        selectionRect.midX - frame.minX - horizontalPadding,
        frame.maxX - selectionRect.midX - horizontalPadding
    ) * 2
    let compact = availableWidth < 430
    let contentSize = compact
        ? CGSize(width: 380, height: 78)
        : CGSize(width: 480, height: 42)
    return panel.frameRect(forContentRect: CGRect(origin: .zero, size: contentSize)).size
}
```

如果执行时发现只看 `availableWidth` 还不够稳，再叠加内容 `fittingSize` 判断；关键是不要用主屏宽度去推断副屏上的面板布局。

- [ ] **Step 3: 复用原文件名将预览内容视图改为 AppKit**

将现有 `TYScreenShotTool/Features/ScrollingCapture/ScrollingCapturePreviewContentView.swift` 重写为 AppKit `NSView`，保留文件名，避免 service 改动过多：

```swift
//
//  ScrollingCapturePreviewContentView.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/22.
//

import AppKit
import SnapKit

enum ScrollingCapturePreviewContent {
    case preparing(title: String, message: String)
    case image(NSImage)
}

@MainActor
final class ScrollingCapturePreviewContentView: NSView {
    private let imageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let messageLabel = NSTextField(labelWithString: "")
    private let badgeLabel = NSTextField(labelWithString: AppText.captureLongCapture)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(content: ScrollingCapturePreviewContent) {
        switch content {
        case let .preparing(title, message):
            imageView.image = nil
            imageView.isHidden = true
            badgeLabel.isHidden = true
            titleLabel.stringValue = title
            messageLabel.stringValue = message
        case let .image(image):
            imageView.image = image
            imageView.isHidden = false
            badgeLabel.isHidden = false
            titleLabel.stringValue = ""
            messageLabel.stringValue = ""
        }
    }
}
```

布局要求：

```swift
imageView.imageScaling = .scaleProportionallyUpOrDown
messageLabel.maximumNumberOfLines = 0
messageLabel.alignment = .center
badgeLabel.isBordered = false
badgeLabel.drawsBackground = false
```

并保留当前 SwiftUI 版 [ScrollingCapturePreviewContentView.swift](/Users/sheldon/CodeRepo/TYScreenShotTool/TYScreenShotTool/Features/ScrollingCapture/ScrollingCapturePreviewContentView.swift:45) 里的长截图 badge 语义：图片态下仍显示小标签，而不是在技术迁移时顺手删掉。

- [ ] **Step 4: 改造预览窗 service 去掉 `NSHostingView`**

把 `TYScreenShotTool/Services/ScrollingCapturePreviewWindowService.swift` 改成：

```swift
import AppKit
import CoreGraphics
import SnapKit

@MainActor
final class ScrollingCapturePreviewWindowService {
    private let panel = NSPanel(
        contentRect: .zero,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    private let containerView = NSVisualEffectView()
    private let contentView = ScrollingCapturePreviewContentView()
    private(set) var attachmentSide: PreviewPlacementSide?

    init() {
        panel.contentView = containerView
        containerView.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
```

把 `installContentView(_:)` 改成直接：

```swift
contentView.configure(content: content)
```

并删除 `hostingView` 的创建、销毁和 `import SwiftUI`。

- [ ] **Step 5: 删除旧 SwiftUI 面板文件并做静态校验**

运行：

```bash
git rm TYScreenShotTool/Features/ScrollingCapture/ScrollingCaptureAIPopoverView.swift \
  TYScreenShotTool/Features/ScrollingCapture/ScrollingCaptureControlPanelView.swift
rg -n "import SwiftUI|NSHostingView" TYScreenShotTool/Features/ScrollingCapture TYScreenShotTool/Services/ScrollingCapturePanelService.swift TYScreenShotTool/Services/ScrollingCapturePreviewWindowService.swift -S
```

预期：

```text
长截图相关 SwiftUI / NSHostingView 依赖已清零。
```

- [ ] **Step 6: 提交**

```bash
git add TYScreenShotTool/Features/ScrollingCapture/ScrollingCaptureControlPanelContentView.swift \
  TYScreenShotTool/Features/ScrollingCapture/ScrollingCapturePreviewContentView.swift \
  TYScreenShotTool/Services/ScrollingCapturePanelService.swift \
  TYScreenShotTool/Services/ScrollingCapturePreviewWindowService.swift
git commit -m "refactor(scrolling): 长截图面板改为纯 AppKit"
```

---

### Task 6：补齐语言变更后的 UI 刷新路径，并同步当前规则文档

**Files:**
- Modify: `TYScreenShotTool/Shared/AppText.swift`
- Modify: `TYScreenShotTool/App/MenuBarController.swift`
- Modify: `TYScreenShotTool/App/SettingsWindowController.swift`
- Modify: `TYScreenShotTool/App/SettingsViewController.swift`
- Modify: `AGENTS.md`
- Modify: `README.md`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/DEVLOG.md`
- Create: `docs/SPRINTS/Sprint-45.md`
- Delete: `TYScreenShotTool/App/SettingsView.swift`
- Delete: `TYScreenShotTool/App/HotKeyRecorderField.swift`

- [ ] **Step 1: 为语言切换增加 UI 刷新路径**

补一条轻量刷新链路，至少覆盖：

- 菜单栏菜单标题
- Settings 窗口标题
- Settings 当前已打开窗口中的 section 文案

推荐做法：

```swift
extension Notification.Name {
    static let appLanguageDidChange = Notification.Name("appLanguageDidChange")
}
```

在 `SettingsViewController.languageChanged()` 末尾增加：

```swift
NotificationCenter.default.post(name: .appLanguageDidChange, object: nil)
```

在 `MenuBarController` 中监听后调用：

```swift
rebuildMenu()
statusItem.button?.accessibilityLabel = AppLocalization.text("app.name")
```

在 `SettingsOpenCoordinator` 或 `SettingsWindowController` 中监听后调用：

```swift
window?.title = AppLocalization.text("window.settings.title")
(contentViewController as? SettingsViewController)?.reloadLocalizedTexts()
```

`reloadLocalizedTexts()` 负责把标题、说明、section title、按钮标题、help 文案全部重新刷一遍。
这里不要保留 “二选一” 描述，直接约定由 `SettingsWindowController` 监听 `appLanguageDidChange` 并刷新窗口标题与 `SettingsViewController.reloadLocalizedTexts()`；`SettingsOpenCoordinator` 继续只负责窗口打开与实例复用，不承担通知监听职责。

- [ ] **Step 2: 删除剩余旧 SwiftUI Settings 文件**

运行：

```bash
git rm TYScreenShotTool/App/SettingsView.swift \
  TYScreenShotTool/App/HotKeyRecorderField.swift
```

然后运行：

```bash
rg -n "import SwiftUI|NSHostingView|NSHostingController|NSViewRepresentable|MenuBarExtra|@AppStorage" TYScreenShotTool -S
```

预期：

```text
# 无输出
```

如果仍有命中，逐个处理并在本任务内清零，不要把“最后再清理”留到下一个任务。

- [ ] **Step 3: 更新 `AGENTS.md` 的技术方向**

把 `AGENTS.md` 中任何 “SwiftUI 优先”、“SwiftUI 化”、“SwiftUI + AppKit 混合” 的当前规则，替换为：

```md
## UI 技术规则

默认：

* UI 使用 AppKit + SnapKit
* 普通界面布局优先 SnapKit
* 只有窗口定位、Overlay 绘制、逐像素控制等低层场景才使用手动 frame

禁止：

* 新增 SwiftUI 页面或控件
* 新增 NSHostingView / NSHostingController 桥接
* 无明确理由引入第二套 UI 技术栈
```

这里更新的是“当前有效规则”，不是把历史事实改写成从未使用过 SwiftUI。

- [ ] **Step 4: 同步 README、ROADMAP、DEVLOG 与 Sprint 45**

创建 `docs/SPRINTS/Sprint-45.md`：

```md
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
```

然后同步：

- `README.md`：把对外技术栈说明改成 `AppKit + SnapKit`
- `docs/ROADMAP.md`：新增 Sprint 45，并把它标为当前进行中
- `docs/DEVLOG.md`：新增 Sprint 45 条目，记录“从混合 UI 收口为纯 AppKit”

- [ ] **Step 5: 做静态校验，确认文档与代码方向一致**

运行：

```bash
rg -n "SwiftUI-first|NSHostingView|NSHostingController|NSViewRepresentable" AGENTS.md README.md docs/ROADMAP.md docs/DEVLOG.md docs/SPRINTS/Sprint-45.md -S
```

预期：

```text
当前规则文档中不再保留本轮要废弃的现行口径。
```

- [ ] **Step 6: 提交**

```bash
git add AGENTS.md README.md docs/ROADMAP.md docs/DEVLOG.md docs/SPRINTS/Sprint-45.md
git commit -m "docs(sprint-45): 同步纯 AppKit 迁移规则"
```

---

### Task 7：最终统一构建、纯 AppKit 校验与人工回归

**Files:**
- Modify: `TYScreenShotTool.xcodeproj/project.pbxproj`（仅在前面构建中证明需要时）

- [ ] **Step 1: 做最终静态校验**

运行：

```bash
rg -n "import SwiftUI|NSHostingView|NSHostingController|NSViewRepresentable|MenuBarExtra|@AppStorage" TYScreenShotTool -S
rg -n "@main" TYScreenShotTool/App -S
```

预期：

```text
# 第一条无输出
TYScreenShotTool/App/AppDelegate.swift:...:@main
```

- [ ] **Step 2: 做最终构建**

运行：

```bash
./scripts/build.sh
```

预期：

```text
** BUILD SUCCEEDED **
```

- [ ] **Step 3: 做人工回归验证**

按下面顺序手工验证：

1. 启动应用后菜单栏图标可见，菜单可打开。
2. 点击 `Settings` 能打开唯一设置窗口。
3. 在 Settings 中修改热键并按 `Return` 提交，实际热键能触发截图。
4. 在 Settings 中切换保存目录，截图保存路径真实变化。
5. 在 Settings 中切换语言与外观，菜单栏、Settings 标题、Settings section 文案与新打开窗口都跟随变化。
6. 做一次普通截图并验证 `复制 / 保存 / OCR / AI / Pin`。
7. 做一次长截图并验证 `取消 / OCR / AI / 保存 / 复制 / 预览`。
8. 验证 OCR / AI 结果窗仍按截图区左右空间摆放，且窄宽度下按钮不重叠。

预期结果：

```text
所有入口可用，无明显窗口层级、焦点、布局或主题回归。
```

- [ ] **Step 4: 最终提交**

```bash
git status --short
git add -A
git commit -m "refactor(ui): 完成纯 AppKit + SnapKit 迁移"
```

---

## Spec 覆盖检查

- Settings 基础骨架与热键输入控件：由 Task 1 覆盖。
- 完整 Settings section 结构与 action wiring：由 Task 2 覆盖。
- 入口改为纯 AppKit 菜单栏应用：由 Task 3 覆盖。
- OCR / AI 结果窗改为纯 AppKit：由 Task 4 覆盖。
- 长截图控制面板与预览窗改为纯 AppKit，并保留窄宽度自适应与 badge：由 Task 5 覆盖。
- 语言变更后的 UI 刷新路径与当前规则同步：由 Task 6 覆盖。
- 最终纯 AppKit 校验、统一构建与人工回归：由 Task 7 覆盖。

## 执行提示

- 如果新增文件没有自动进入 target，再回头最小化修改 `TYScreenShotTool.xcodeproj/project.pbxproj`。
- 不要在迁移过程中顺手重构无关 service；本轮以“UI 承载层替换”为边界。
- 中间任务优先做静态校验；统一构建放到最后一个任务执行。
