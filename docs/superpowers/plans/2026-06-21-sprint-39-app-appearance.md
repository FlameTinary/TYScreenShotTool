# Sprint 39 App Appearance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 TShot 增加统一的 App 外观切换能力，支持“跟随系统 / 浅色 / 深色”，并让当前已打开的 App 自有窗口立即切换。

**Architecture:** 本轮沿用 Sprint 38 的设置模型，新增一个很薄的 `AppAppearance` 枚举和 `AppThemeCoordinator` 协调器，统一读取设置并应用 `NSAppearance`。窗口层面通过 `NSApp.appearance + window.appearance` 保证立即切换，界面层面将少量固定深色样式收口为语义色与自适应材质，确保浅色模式下真实可读。

**Tech Stack:** Swift 6, SwiftUI, AppKit, Foundation, Xcode String Catalog

---

## File Structure

- Create: `TYScreenShotTool/Shared/AppAppearance.swift`
  - 定义外观模式、存储值和 `NSAppearance` 映射
- Create: `TYScreenShotTool/Shared/AppThemeCoordinator.swift`
  - 统一读取当前外观设置，应用到 `NSApp` 和当前已打开窗口
- Modify: `TYScreenShotTool/Shared/AppSettings.swift`
  - 新增外观设置 key 和默认值
- Modify: `TYScreenShotTool/App/TYScreenShotToolApp.swift`
  - App 启动时应用当前外观
- Modify: `TYScreenShotTool/App/SettingsView.swift`
  - 新增外观设置 UI，并在切换时立即触发外观应用
- Modify: `TYScreenShotTool/App/SettingsOpenCoordinator.swift`
  - 创建和刷新 Settings 窗口时同步应用当前外观
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayWindow.swift`
  - 覆盖层窗口创建和显示时同步应用当前外观
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift`
  - 顶部浮层和底部工具栏由固定白字 / 固定 HUD 风格收口为自适应风格
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureAnnotationCanvasView.swift`
  - 活动文本输入框背景与输入态颜色按当前外观自适应
- Modify: `TYScreenShotTool/Services/OCRPreviewWindowService.swift`
  - OCR 结果窗接入外观切换，并改用语义文本色
- Modify: `TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift`
  - AI 结果窗接入外观切换，并改用语义文本色
- Modify: `TYScreenShotTool/Services/ScrollingCapturePreviewWindowService.swift`
  - 长截图预览窗接入外观切换
- Modify: `TYScreenShotTool/Services/ScrollingCapturePanelService.swift`
  - 长截图控制面板接入外观切换，并收口浅色/深色下的控制面板可读性
- Modify: `TYScreenShotTool/Services/PinWindowService.swift`
  - 图钉窗口接入外观切换
- Modify: `TYScreenShotTool/Services/ToastService.swift`
  - Toast 改为按当前外观自适应底色和文字色
- Modify: `TYScreenShotTool/Resources/Localizable.xcstrings`
  - 增加外观设置相关文案的 6 语言翻译
- Modify: `TASK.md`
  - Sprint 39 完成后切换为 done
- Modify: `docs/ROADMAP.md`
  - Sprint 39 状态改为 done
- Modify: `docs/SPRINTS/Sprint-39.md`
  - 补实现结果与验证结果
- Modify: `docs/DEVLOG.md`
  - 记录 Sprint 39 完成结果

说明：

- 当前项目没有独立 test target，本轮仍以 `./scripts/build.sh` 和人工验证为主。
- 菜单栏下拉菜单不属于本轮范围。
- 本轮不引入第二套主题系统，不做品牌色配置。

---

### Task 1: 建立外观模型与统一应用入口

**Files:**
- Create: `TYScreenShotTool/Shared/AppAppearance.swift`
- Create: `TYScreenShotTool/Shared/AppThemeCoordinator.swift`
- Modify: `TYScreenShotTool/Shared/AppSettings.swift`

- [ ] **Step 1: 在 AppSettings 中新增外观设置键**

Update `TYScreenShotTool/Shared/AppSettings.swift`:

```swift
/// App 外观设置键
static let appAppearanceKey = "settings.appAppearance"
/// App 外观默认值
static let appAppearanceDefaultValue = AppAppearance.system.storageValue
```

- [ ] **Step 2: 新增 AppAppearance 枚举**

Create `TYScreenShotTool/Shared/AppAppearance.swift`:

```swift
import AppKit

enum AppAppearance: String, CaseIterable {
    case system
    case light
    case dark

    var storageValue: String {
        rawValue
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }
}
```

- [ ] **Step 3: 新增 AppThemeCoordinator**

Create `TYScreenShotTool/Shared/AppThemeCoordinator.swift`:

```swift
import AppKit

@MainActor
final class AppThemeCoordinator {
    static let shared = AppThemeCoordinator()

    private init() {}
    private var refreshHandlers: [ObjectIdentifier: @MainActor () -> Void] = [:]

    func userSelectedAppearance(
        userDefaults: UserDefaults = .standard
    ) -> AppAppearance {
        let rawValue = userDefaults.string(forKey: AppSettings.appAppearanceKey)
            ?? AppSettings.appAppearanceDefaultValue
        return AppAppearance(rawValue: rawValue) ?? .system
    }

    func resolvedAppearance(
        userDefaults: UserDefaults = .standard
    ) -> NSAppearance? {
        userSelectedAppearance(userDefaults: userDefaults).nsAppearance
    }

    func applyCurrentAppearance(
        userDefaults: UserDefaults = .standard
    ) {
        let appearance = resolvedAppearance(userDefaults: userDefaults)
        NSApp.appearance = appearance

        for window in NSApp.windows {
            applyCurrentAppearance(to: window, userDefaults: userDefaults)
        }

        for refresh in refreshHandlers.values {
            refresh()
        }
    }

    func applyCurrentAppearance(
        to window: NSWindow,
        userDefaults: UserDefaults = .standard
    ) {
        window.appearance = resolvedAppearance(userDefaults: userDefaults)
        window.invalidateShadow()
        window.displayIfNeeded()
    }

    func registerRefreshHandler(
        for owner: AnyObject,
        _ refresh: @escaping @MainActor () -> Void
    ) {
        refreshHandlers[ObjectIdentifier(owner)] = refresh
    }

    func unregisterRefreshHandler(
        for owner: AnyObject
    ) {
        refreshHandlers.removeValue(forKey: ObjectIdentifier(owner))
    }
}
```

- [ ] **Step 4: 运行构建验证基础模型通过**

Run:

```bash
./scripts/build.sh
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 提交外观模型基础能力**

Run:

```bash
git add TYScreenShotTool/Shared/AppSettings.swift TYScreenShotTool/Shared/AppAppearance.swift TYScreenShotTool/Shared/AppThemeCoordinator.swift
git commit -m "feat(sprint-39): 增加外观模式模型"
```

Expected: 只包含本轮外观模型与协调器文件。

---

### Task 2: 接入 App 启动与 Settings 外观切换

**Files:**
- Modify: `TYScreenShotTool/App/TYScreenShotToolApp.swift`
- Modify: `TYScreenShotTool/App/SettingsView.swift`
- Modify: `TYScreenShotTool/App/SettingsOpenCoordinator.swift`

- [ ] **Step 1: App 启动时应用当前外观**

Update `TYScreenShotTool/App/TYScreenShotToolApp.swift` inside `init()`:

```swift
init() {
    AppThemeCoordinator.shared.applyCurrentAppearance()

    let overlayService = CaptureOverlayService()
    let screenCaptureService = ScreenCaptureService()
    // ... keep the remaining setup unchanged
}
```

- [ ] **Step 2: SettingsView 增加外观设置存储与绑定**

Update `TYScreenShotTool/App/SettingsView.swift` properties:

```swift
@AppStorage(AppSettings.appAppearanceKey)
private var appAppearanceStorageValue = AppSettings.appAppearanceDefaultValue

private var appAppearanceSelection: Binding<AppAppearance> {
    Binding(
        get: {
            AppAppearance(rawValue: appAppearanceStorageValue) ?? .system
        },
        set: { newValue in
            appAppearanceStorageValue = newValue.storageValue
            AppThemeCoordinator.shared.applyCurrentAppearance()
        }
    )
}
```

- [ ] **Step 3: SettingsView 增加外观设置区块**

Append in `TYScreenShotTool/App/SettingsView.swift`:

```swift
private var appearanceSettings: some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(AppLocalization.text("settings.appearance.section"))
            .font(.headline)

        Picker(
            AppLocalization.text("settings.appearance.label"),
            selection: appAppearanceSelection
        ) {
            Text(AppLocalization.text("settings.appearance.option.system")).tag(AppAppearance.system)
            Text(AppLocalization.text("settings.appearance.option.light")).tag(AppAppearance.light)
            Text(AppLocalization.text("settings.appearance.option.dark")).tag(AppAppearance.dark)
        }
        .pickerStyle(.menu)
        .frame(maxWidth: 240, alignment: .leading)
    }
}
```

and insert it into `body`:

```swift
VStack(alignment: .leading, spacing: 12) {
    hotKeyPicker
    languageSettings
    appearanceSettings
    aiAnalysisSettings
    saveDirectoryPicker
}
```

- [ ] **Step 4: Settings 窗口创建与刷新时应用外观**

Update `TYScreenShotTool/App/SettingsOpenCoordinator.swift`:

```swift
let window = NSWindow()
window.title = AppLocalization.text("window.settings.title")
window.styleMask = [.titled, .closable, .miniaturizable]
window.isReleasedWhenClosed = false
window.minSize = NSSize(width: 460, height: 360)
window.setContentSize(NSSize(width: 520, height: 460))
window.center()
AppThemeCoordinator.shared.applyCurrentAppearance(to: window)
refreshContentViewController(for: window)
```

and inside `refreshContentViewController(for:)`:

```swift
window.title = AppLocalization.text("window.settings.title")
let hostingController = NSHostingController(rootView: contentProvider())
window.contentViewController = hostingController
AppThemeCoordinator.shared.applyCurrentAppearance(to: window)
```

- [ ] **Step 5: 运行构建验证 Settings 接入通过**

Run:

```bash
./scripts/build.sh
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: 提交 Settings 外观切换**

Run:

```bash
git add TYScreenShotTool/App/TYScreenShotToolApp.swift TYScreenShotTool/App/SettingsView.swift TYScreenShotTool/App/SettingsOpenCoordinator.swift
git commit -m "feat(sprint-39): 接入设置页外观切换"
```

Expected: 提交只包含启动与 Settings 外观切换接入。

---

### Task 3: 将外观应用到当前已打开的 App 自有窗口

**Files:**
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayWindow.swift`
- Modify: `TYScreenShotTool/Services/OCRPreviewWindowService.swift`
- Modify: `TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift`
- Modify: `TYScreenShotTool/Services/ScrollingCapturePreviewWindowService.swift`
- Modify: `TYScreenShotTool/Services/ScrollingCapturePanelService.swift`
- Modify: `TYScreenShotTool/Services/PinWindowService.swift`
- Modify: `TYScreenShotTool/Services/ToastService.swift`

- [ ] **Step 1: 为需要即时刷新的窗口服务注册样式刷新入口**

Add lightweight refresh hooks in long-lived services:

```swift
// AIAnalysisPreviewWindowService.swift
init() {
    // existing setup...
    AppThemeCoordinator.shared.registerRefreshHandler(for: self) { [weak self] in
        self?.applyAppearanceStyling()
    }
}

deinit {
    AppThemeCoordinator.shared.unregisterRefreshHandler(for: self)
}

// OCRPreviewWindowService.swift
init() {
    // existing setup...
    AppThemeCoordinator.shared.registerRefreshHandler(for: self) { [weak self] in
        self?.applyAppearanceStyling()
    }
}

deinit {
    AppThemeCoordinator.shared.unregisterRefreshHandler(for: self)
}

// ScrollingCapturePreviewWindowService.swift / ToastService.swift use the same pattern
```

Expected: 当用户在 Settings 切换外观时，已打开窗口除了切 `window.appearance`，还会重新执行内部样式刷新。

- [ ] **Step 2: 覆盖层窗口显示时应用当前外观**

Update `TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayWindow.swift`:

```swift
func showOverlay() {
    AppThemeCoordinator.shared.applyCurrentAppearance(to: self)
    orderFrontRegardless()
    makeKeyAndOrderFront(nil)
    if let contentView {
        makeFirstResponder(contentView)
        invalidateCursorRects(for: contentView)
    }
    NSCursor.crosshair.set()
}
```

- [ ] **Step 3: OCR 与 AI 结果窗显示前应用外观**

Update `TYScreenShotTool/Services/OCRPreviewWindowService.swift` in `present(...)`:

```swift
AppThemeCoordinator.shared.applyCurrentAppearance(to: panel)
panel.setFrame(panelFrame, display: true)
applyAppearanceStyling()
layoutContent(in: panelFrame.size)
panel.orderFrontRegardless()
```

Update `TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift` in `presentPanel(...)` before `orderFrontRegardless()`:

```swift
AppThemeCoordinator.shared.applyCurrentAppearance(to: panel)
applyAppearanceStyling()
panel.orderFrontRegardless()
```

- [ ] **Step 4: 长截图预览窗与控制面板显示前应用外观**

Update `TYScreenShotTool/Services/ScrollingCapturePreviewWindowService.swift`:

```swift
AppThemeCoordinator.shared.applyCurrentAppearance(to: panel)
applyAppearanceStyling()
panel.orderFrontRegardless()
```

Update `TYScreenShotTool/Services/ScrollingCapturePanelService.swift` inside `presentCapturePanel(...)`:

```swift
AppThemeCoordinator.shared.applyCurrentAppearance(to: panel)
panelView.applyAppearanceStyling()
panel.orderFrontRegardless()
```

- [ ] **Step 5: 图钉窗口与 Toast 窗口显示前应用外观**

Update `TYScreenShotTool/Services/PinWindowService.swift`:

```swift
let window = resolvedWindow(with: imageView)
AppThemeCoordinator.shared.applyCurrentAppearance(to: window)
let contentSize = fittedContentSize(for: image)
window.setContentSize(contentSize)
```

Update `TYScreenShotTool/Services/ToastService.swift` in `showToast(message:)`:

```swift
let window = resolvedWindow(with: label)
AppThemeCoordinator.shared.applyCurrentAppearance(to: window)
applyAppearanceStyling()
window.setContentSize(contentSize)
```

- [ ] **Step 6: 运行构建验证窗口级切换链路通过**

Run:

```bash
./scripts/build.sh
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: 提交窗口级外观应用**

Run:

```bash
git add TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayWindow.swift TYScreenShotTool/Services/OCRPreviewWindowService.swift TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift TYScreenShotTool/Services/ScrollingCapturePreviewWindowService.swift TYScreenShotTool/Services/ScrollingCapturePanelService.swift TYScreenShotTool/Services/PinWindowService.swift TYScreenShotTool/Services/ToastService.swift
git commit -m "feat(sprint-39): 应用外观到浮层窗口"
```

Expected: 已打开的窗口具备立即切换的基础能力。

---

### Task 4: 收口浅色与深色下的面板可读性和本地化文案

**Files:**
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift`
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureAnnotationCanvasView.swift`
- Modify: `TYScreenShotTool/Services/OCRPreviewWindowService.swift`
- Modify: `TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift`
- Modify: `TYScreenShotTool/Services/ScrollingCapturePreviewWindowService.swift`
- Modify: `TYScreenShotTool/Services/ScrollingCapturePanelService.swift`
- Modify: `TYScreenShotTool/Services/ToastService.swift`
- Modify: `TYScreenShotTool/Resources/Localizable.xcstrings`

- [ ] **Step 1: 将结果窗、浮层和活动文本输入框的文本色改为语义色**

Update these assignments:

```swift
// OCRPreviewWindowService.swift
titleLabel.textColor = .labelColor
textView.textColor = .labelColor

// AIAnalysisPreviewWindowService.swift
titleLabel.textColor = .labelColor
statusLabel.textColor = .secondaryLabelColor
messageLabel.textColor = .labelColor

// nested SectionView in AIAnalysisPreviewWindowService.swift
titleLabel.textColor = .secondaryLabelColor
contentLabel.textColor = .labelColor

// CaptureOverlayView.swift
sizeLabel.textColor = .labelColor
cornerRadiusLabel.textColor = .labelColor

// CaptureAnnotationCanvasView.swift
textField.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.92)
```

- [ ] **Step 2: 将固定深色材质调整为自适应材质，并给服务补上 applyAppearanceStyling()**

Update these assignments:

```swift
// OCRPreviewWindowService.swift
containerView.material = .popover
containerView.layer?.borderColor = NSColor.separatorColor.cgColor

// AIAnalysisPreviewWindowService.swift
containerView.material = .popover
containerView.layer?.borderColor = NSColor.separatorColor.cgColor

// ScrollingCapturePreviewWindowService.swift
containerView.material = .popover
containerView.layer?.borderColor = NSColor.separatorColor.cgColor

// CaptureOverlayView.swift
topBarContainerView.material = .popover
toolbarContainerView.material = .popover

// ScrollingCapturePanelService.swift
// add applyAppearanceStyling() on ScrollingCapturePanelView:
layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.96).cgColor
layer?.borderWidth = 1
layer?.borderColor = NSColor.separatorColor.cgColor
```

- [ ] **Step 3: Toast 改为按当前外观自适应的前景与背景**

Update `TYScreenShotTool/Services/ToastService.swift`:

```swift
contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.96).cgColor
contentView.layer?.borderWidth = 1
contentView.layer?.borderColor = NSColor.separatorColor.cgColor

label.textColor = .labelColor
```

- [ ] **Step 4: 为已打开窗口的内容层增加立即刷新验证点**

Ensure these methods exist and are called both from `present/show` and theme refresh handlers:

```swift
// AIAnalysisPreviewWindowService.swift
private func applyAppearanceStyling() { ... }

// OCRPreviewWindowService.swift
private func applyAppearanceStyling() { ... }

// ScrollingCapturePreviewWindowService.swift
private func applyAppearanceStyling() { ... }

// ToastService.swift
private func applyAppearanceStyling() { ... }

// ScrollingCapturePanelView
func applyAppearanceStyling() { ... }

// CaptureOverlayView / CaptureAnnotationCanvasView
func applyAppearanceStyling() { ... }
```

Expected: 当前已经显示出来的内容层不会只切换窗口壳，而会同步刷新内部 layer、材质和文字色。

- [ ] **Step 5: 增加外观设置本地化文案**

Add keys to `TYScreenShotTool/Resources/Localizable.xcstrings`:

```text
settings.appearance.section
settings.appearance.label
settings.appearance.option.system
settings.appearance.option.light
settings.appearance.option.dark
```

Use these translations:

```text
settings.appearance.section
zh-Hans: 外观
en: Appearance
ja: 外観
ko: 모양
de: Erscheinungsbild
fr: Apparence

settings.appearance.label
zh-Hans: App 外观
en: App Appearance
ja: App の外観
ko: 앱 모양
de: App-Erscheinungsbild
fr: Apparence de l’app

settings.appearance.option.system
zh-Hans: 跟随系统
en: Follow System
ja: システムに従う
ko: 시스템 따르기
de: System folgen
fr: Suivre le système

settings.appearance.option.light
zh-Hans: 浅色
en: Light
ja: ライト
ko: 라이트
de: Hell
fr: Clair

settings.appearance.option.dark
zh-Hans: 深色
en: Dark
ja: ダーク
ko: 다크
de: Dunkel
fr: Sombre
```

- [ ] **Step 6: 运行构建验证浅色/深色视觉收口通过**

Run:

```bash
./scripts/build.sh
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: 提交面板样式与本地化收口**

Run:

```bash
git add TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift TYScreenShotTool/Features/CaptureOverlay/CaptureAnnotationCanvasView.swift TYScreenShotTool/Services/OCRPreviewWindowService.swift TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift TYScreenShotTool/Services/ScrollingCapturePreviewWindowService.swift TYScreenShotTool/Services/ScrollingCapturePanelService.swift TYScreenShotTool/Services/ToastService.swift TYScreenShotTool/Resources/Localizable.xcstrings
git commit -m "feat(sprint-39): 收口外观切换面板样式"
```

Expected: 浅色和深色下的主要浮层面板具备可读性，Settings 文案可显示。

---

### Task 5: 完成人工验证与 Sprint 39 收尾文档

**Files:**
- Modify: `TASK.md`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/SPRINTS/Sprint-39.md`
- Modify: `docs/DEVLOG.md`

- [ ] **Step 1: 运行最终构建验证**

Run:

```bash
./scripts/build.sh
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: 执行人工验证**

Manual validation checklist:

```text
1. 启动 App，确认默认外观为“跟随系统”
2. 打开 Settings，确认存在“外观”设置项和 3 个选项
3. 保持 Settings 打开，进入截图编辑态，再分别打开 OCR 或 AI 结果窗
4. 在 Settings 中切到“浅色”，确认 Settings、截图编辑窗、OCR/AI 结果窗立即切换
5. 在 Settings 中切到“深色”，确认上述窗口立即切换
6. 切回“跟随系统”，确认界面恢复跟随系统
7. 关闭并重新打开 Settings、重新触发截图，确认新窗口继承当前外观
8. 重启 App，确认上次选择的外观仍生效
9. 再次验证复制、保存、OCR、AI、长截图主链路无回归
```

- [ ] **Step 3: 将 TASK.md 切换到 Sprint 39 Done**

Update `TASK.md`:

```md
Current Sprint: Sprint 39 Done

## 当前状态

Sprint 39 已完成实现、构建验证与人工验证。
```

- [ ] **Step 4: 更新 ROADMAP / Sprint-39 / DEVLOG**

Ensure:

```md
docs/ROADMAP.md
- Sprint 39 状态改为 ✅ Done
- “目标”改为“成果”

docs/SPRINTS/Sprint-39.md
- Status 改为 Done
- Result 补充实际实现、立即切换行为、验证通过结论

docs/DEVLOG.md
- 新增“Sprint 39 完成”
- 记录外观设置、立即切换、主要窗口覆盖范围和验证结果
```

- [ ] **Step 5: 提交 Sprint 39 收尾文档**

Run:

```bash
git add TASK.md docs/ROADMAP.md docs/SPRINTS/Sprint-39.md docs/DEVLOG.md
git commit -m "docs(sprint-39): 收尾外观切换文档"
```

Expected: Sprint 39 进入完成态，文档与实现状态一致。

---

## Self-Review

- Spec coverage:
  - `AppAppearance` 与 `AppThemeCoordinator` 由 Task 1 覆盖
  - Settings 三选项与立即切换由 Task 2 覆盖
  - 当前已打开窗口立即切换由 Task 3 覆盖
  - 浅色 / 深色下真实可读的视觉收口、活动文本输入框、长截图控制面板与本地化文案由 Task 4 覆盖
  - 构建验证、人工验证和收尾文档由 Task 5 覆盖
- Placeholder scan:
  - 计划中未使用 `TBD / TODO / later` 占位语句
  - 每个 task 都给出了明确文件路径、代码片段、命令和预期结果
- Type consistency:
  - 设置键统一使用 `appAppearanceKey / appAppearanceDefaultValue`
  - 模型统一使用 `AppAppearance`
  - 协调器统一使用 `AppThemeCoordinator.shared.applyCurrentAppearance(...)`
  - 已打开窗口内容层刷新统一使用 `applyAppearanceStyling()`
