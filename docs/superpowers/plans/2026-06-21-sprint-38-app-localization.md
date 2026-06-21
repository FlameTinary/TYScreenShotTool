# Sprint 38 App Localization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 TShot 建立统一的 App 本地化能力，支持简体中文、English、日本語、한국어、Deutsch、Français，并让 UI 文案、AI prompt 与 AI 输出语言按当前有效语言切换。

**Architecture:** 本轮基于 Apple 原生 `String Catalog (.xcstrings)` 建立统一文案资源，并新增一个很薄的 App 语言模型与本地化入口。Settings 负责“跟随系统 + 手动覆盖语言”配置；UI 模块按当前有效语言读取可见文案；AIAnalysisService 与 OCRService 负责语言联动，不改变现有截图、OCR、AI 主链路结构。

**Tech Stack:** Swift 6, SwiftUI, AppKit, Foundation, Vision, Xcode String Catalog

---

## File Structure

- Create: `TYScreenShotTool/Resources/Localizable.xcstrings`
  - 统一存放用户可见文案及 AI 固定标题的 6 种语言翻译
- Create: `TYScreenShotTool/Shared/AppLanguage.swift`
  - 定义支持语言、系统语言匹配、OCR 优先语言列表、AI 输出语言信息
- Create: `TYScreenShotTool/Shared/AppLocalization.swift`
  - 提供当前有效语言解析、本地化取值入口、AI 固定标题访问
- Modify: `TYScreenShotTool/Shared/AppSettings.swift`
  - 新增 App 语言设置键与默认值
- Modify: `TYScreenShotTool/App/SettingsView.swift`
  - 新增语言设置 UI，并本地化页面文案
- Modify: `TYScreenShotTool/App/HotKeyRecorderField.swift`
  - placeholder 与录制相关提示文案本地化
- Modify: `TYScreenShotTool/App/MenuBarContentView.swift`
  - 菜单栏文案本地化
- Modify: `TYScreenShotTool/App/SettingsOpenCoordinator.swift`
  - Settings 窗口标题本地化，并确保重新打开时读取当前语言
- Modify: `TYScreenShotTool/App/TYScreenShotToolApp.swift`
  - 菜单栏图标可访问文案与 Settings 初始化链路接入当前语言读取
- Modify: `TYScreenShotTool/Shared/AnnotationTool.swift`
  - 标注工具标题本地化
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift`
  - 截图编辑态按钮和顶部浮层文案本地化
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureAnnotationCanvasView.swift`
  - 文字输入 placeholder 本地化
- Modify: `TYScreenShotTool/Services/OCRPreviewWindowService.swift`
  - OCR 结果窗标题、按钮、空态文案本地化
- Modify: `TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift`
  - AI 结果窗标题、按钮、默认状态文案本地化
- Modify: `TYScreenShotTool/Shared/AIAnalysisMode.swift`
  - 各模式菜单标题、loading、复制按钮、成功提示本地化
- Modify: `TYScreenShotTool/Shared/AITranslationLanguage.swift`
  - 翻译方向菜单标题、loading、结果标题本地化，并保留目标语言边界
- Modify: `TYScreenShotTool/Services/AIAnalysisService.swift`
  - prompt 语言、固定标题、结构解析、错误文案按当前有效语言切换
- Modify: `TYScreenShotTool/Services/OCRService.swift`
  - OCR 识别语言改为“当前语言优先 + 中英兜底”，错误文案本地化
- Modify: `TASK.md`
  - 当前范围切换为 Sprint 38 planned / done
- Modify: `docs/ROADMAP.md`
  - Sprint 38 planned / done 状态同步
- Create: `docs/SPRINTS/Sprint-38.md`
  - Sprint 38 planned 文档，完成后补结果
- Modify: `docs/DEVLOG.md`
  - Sprint 38 完成后补开发结果

说明：

- 当前项目没有独立 test target，本轮仍以 `./scripts/build.sh` 和人工验证为主。
- 本轮不要求切换语言后强制刷新已打开窗口。
- 本轮不本地化控制台 `print(...)` 调试日志。

---

### Task 1: 对齐 Sprint 38 planned 文档

**Files:**
- Modify: `docs/ROADMAP.md`
- Create: `docs/SPRINTS/Sprint-38.md`
- Modify: `TASK.md`

- [ ] **Step 1: 在 ROADMAP 中增加 Sprint 38 planned 段落**

Ensure `docs/ROADMAP.md` contains:

```md
### Sprint 38

App 本地化

状态：
🚧 Planned

目标：

- 为 App 建立统一的本地化资源基础设施
- 支持简体中文、English、日本語、한국어、Deutsch、Français
- Settings 中支持“跟随系统 + 手动覆盖语言”
- 菜单栏、Settings、截图编辑态、OCR 窗口、AI 窗口文案本地化
- AI prompt、AI 固定输出标题与 AI 输出语言跟随当前有效语言切换
- OCR 识别语言改为“当前语言优先 + 中英兜底”
```

- [ ] **Step 2: 新建 Sprint-38 planned 文档**

Create `docs/SPRINTS/Sprint-38.md` with sections:

```md
# Sprint 38 - App 本地化

## Status

Planned
```

and align `Goal / Scope / Out of Scope / Implementation / Validation / Result` with the approved spec.

- [ ] **Step 3: 将 TASK.md 切换到 Sprint 38 planned**

Update `TASK.md` to:

```md
Current Sprint: Sprint 38 Planned

## 当前状态

Sprint 37 已完成实现、构建验证与人工验证。
Sprint 38 已完成本地化设计对齐，准备进入 implementation plan 阶段。
```

and replace the current goal/range/acceptance text with Sprint 38 localization scope.

- [ ] **Step 4: 检查文档对齐**

Run:

```bash
sed -n '1,220p' TASK.md
sed -n '620,735p' docs/ROADMAP.md
sed -n '1,260p' docs/SPRINTS/Sprint-38.md
```

Expected: `ROADMAP -> Sprint-38 -> TASK.md` 三者描述同一件事，不再停留在 Sprint 37。

- [ ] **Step 5: 提交 planned 文档对齐**

Run:

```bash
git add TASK.md docs/ROADMAP.md docs/SPRINTS/Sprint-38.md
git commit -m "docs(sprint-38): 对齐应用本地化范围"
```

Expected: Sprint 38 planned 文档单独成一个提交。

---

### Task 2: 建立语言模型与本地化入口

**Files:**
- Create: `TYScreenShotTool/Shared/AppLanguage.swift`
- Create: `TYScreenShotTool/Shared/AppLocalization.swift`
- Modify: `TYScreenShotTool/Shared/AppSettings.swift`

- [ ] **Step 1: 新增 App 语言设置键**

Update `TYScreenShotTool/Shared/AppSettings.swift` with:

```swift
/// App 语言设置键
static let appLanguageKey = "settings.appLanguage"
/// App 语言默认值
static let appLanguageDefaultValue = "system"
```

- [ ] **Step 2: 新增 AppLanguage 枚举**

Create `TYScreenShotTool/Shared/AppLanguage.swift`:

```swift
import Foundation

enum AppLanguage: String, CaseIterable {
    case system
    case simplifiedChinese
    case english
    case japanese
    case korean
    case german
    case french

    static let supportedDisplayLanguages: [AppLanguage] = [
        .simplifiedChinese,
        .english,
        .japanese,
        .korean,
        .german,
        .french,
    ]

    var storageValue: String {
        rawValue
    }
}
```

- [ ] **Step 3: 为 AppLanguage 增加系统匹配与 OCR 语言优先级**

Append in `AppLanguage.swift`:

```swift
extension AppLanguage {
    var localizationCode: String? {
        switch self {
        case .system:
            return nil
        case .simplifiedChinese:
            return "zh-Hans"
        case .english:
            return "en"
        case .japanese:
            return "ja"
        case .korean:
            return "ko"
        case .german:
            return "de"
        case .french:
            return "fr"
        }
    }

    static func resolved(
        userSelection: AppLanguage,
        preferredLanguages: [String]
    ) -> AppLanguage {
        guard userSelection == .system else {
            return userSelection
        }

        for preferred in preferredLanguages {
            let normalized = preferred.lowercased()
            if normalized.hasPrefix("zh") {
                return .simplifiedChinese
            }
            if normalized.hasPrefix("ja") {
                return .japanese
            }
            if normalized.hasPrefix("ko") {
                return .korean
            }
            if normalized.hasPrefix("de") {
                return .german
            }
            if normalized.hasPrefix("fr") {
                return .french
            }
            if normalized.hasPrefix("en") {
                return .english
            }
        }

        return .english
    }

    var ocrRecognitionLanguages: [String] {
        switch self {
        case .simplifiedChinese:
            return ["zh-Hans", "zh-Hant", "en-US"]
        case .english:
            return ["en-US", "zh-Hans", "zh-Hant"]
        case .japanese:
            return ["ja-JP", "en-US", "zh-Hans", "zh-Hant"]
        case .korean:
            return ["ko-KR", "en-US", "zh-Hans", "zh-Hant"]
        case .german:
            return ["de-DE", "en-US", "zh-Hans", "zh-Hant"]
        case .french:
            return ["fr-FR", "en-US", "zh-Hans", "zh-Hant"]
        case .system:
            return AppLanguage.english.ocrRecognitionLanguages
        }
    }
}
```

- [ ] **Step 4: 新增本地化入口**

Create `TYScreenShotTool/Shared/AppLocalization.swift`:

```swift
import Foundation

enum AppLocalization {
    static func userSelectedLanguage(
        userDefaults: UserDefaults = .standard
    ) -> AppLanguage {
        let rawValue = userDefaults.string(forKey: AppSettings.appLanguageKey)
            ?? AppSettings.appLanguageDefaultValue
        return AppLanguage(rawValue: rawValue) ?? .system
    }

    static func currentLanguage(
        userDefaults: UserDefaults = .standard,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> AppLanguage {
        let selected = userSelectedLanguage(userDefaults: userDefaults)
        return AppLanguage.resolved(
            userSelection: selected,
            preferredLanguages: preferredLanguages
        )
    }

    static func bundle(
        userDefaults: UserDefaults = .standard,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> Bundle {
        let language = currentLanguage(
            userDefaults: userDefaults,
            preferredLanguages: preferredLanguages
        )

        guard
            let localizationCode = language.localizationCode,
            let bundlePath = Bundle.main.path(forResource: localizationCode, ofType: "lproj"),
            let localizedBundle = Bundle(path: bundlePath)
        else {
            return .main
        }

        return localizedBundle
    }

    static func text(
        _ key: String,
        table: String? = nil,
        userDefaults: UserDefaults = .standard,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        bundle(
            userDefaults: userDefaults,
            preferredLanguages: preferredLanguages
        ).localizedString(forKey: key, value: key, table: table)
    }
}
```

- [ ] **Step 5: 构建验证并提交**

Run:

```bash
./scripts/build.sh
git add TYScreenShotTool/Shared/AppSettings.swift TYScreenShotTool/Shared/AppLanguage.swift TYScreenShotTool/Shared/AppLocalization.swift
git commit -m "feat(sprint-38): 增加应用语言模型"
```

Expected: 工程可编译，语言模型与本地化入口已具备后续接入基础。

---

### Task 3: 建立 String Catalog 并本地化菜单栏与设置页

**Files:**
- Create: `TYScreenShotTool/Resources/Localizable.xcstrings`
- Modify: `TYScreenShotTool/App/MenuBarContentView.swift`
- Modify: `TYScreenShotTool/App/SettingsView.swift`
- Modify: `TYScreenShotTool/App/HotKeyRecorderField.swift`
- Modify: `TYScreenShotTool/App/SettingsOpenCoordinator.swift`
- Modify: `TYScreenShotTool/App/TYScreenShotToolApp.swift`

- [ ] **Step 1: 新建 Localizable.xcstrings**

Create a string catalog containing at least these keys for all 6 languages:

```text
app.name
menu.settings
menu.quit
settings.title
settings.description
settings.hotkey.section
settings.hotkey.label
settings.hotkey.help
settings.hotkey.placeholder
settings.hotkey.error.no_primary_key
settings.hotkey.error.registration_failed
settings.ai.section
settings.ai.use_vision
settings.ai.help
settings.save.section
settings.save.choose
settings.save.clear
settings.save.not_configured
settings.save.help
settings.language.section
settings.language.label
settings.language.option.system
settings.language.option.zh_hans
settings.language.option.en
settings.language.option.ja
settings.language.option.ko
settings.language.option.de
settings.language.option.fr
window.settings.title
```

Expected: 所有键都提供简体中文、English、日本語、한국어、Deutsch、Français 翻译。

- [ ] **Step 2: 菜单栏文案改为本地化**

Update `TYScreenShotTool/App/MenuBarContentView.swift`:

```swift
Button(AppLocalization.text("app.name")) {
}

Divider()

Button(AppLocalization.text("menu.settings")) {
    settingsOpenCoordinator.openSettings()
}

Divider()

Button(AppLocalization.text("menu.quit")) {
    NSApplication.shared.terminate(nil)
}
```

- [ ] **Step 3: Settings 页面接入语言设置项**

Update `TYScreenShotTool/App/SettingsView.swift`:

```swift
@AppStorage(AppSettings.appLanguageKey)
private var appLanguageStorageValue = AppSettings.appLanguageDefaultValue

private var appLanguageSelection: Binding<AppLanguage> {
    Binding(
        get: {
            AppLanguage(rawValue: appLanguageStorageValue) ?? .system
        },
        set: { newValue in
            appLanguageStorageValue = newValue.storageValue
        }
    )
}
```

and add a new section:

```swift
private var languageSettings: some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(AppLocalization.text("settings.language.section"))
            .font(.headline)

        Picker(
            AppLocalization.text("settings.language.label"),
            selection: appLanguageSelection
        ) {
            Text(AppLocalization.text("settings.language.option.system")).tag(AppLanguage.system)
            Text(AppLocalization.text("settings.language.option.zh_hans")).tag(AppLanguage.simplifiedChinese)
            Text(AppLocalization.text("settings.language.option.en")).tag(AppLanguage.english)
            Text(AppLocalization.text("settings.language.option.ja")).tag(AppLanguage.japanese)
            Text(AppLocalization.text("settings.language.option.ko")).tag(AppLanguage.korean)
            Text(AppLocalization.text("settings.language.option.de")).tag(AppLanguage.german)
            Text(AppLocalization.text("settings.language.option.fr")).tag(AppLanguage.french)
        }
        .pickerStyle(.menu)
    }
}
```

and insert it before `aiAnalysisSettings`.

- [ ] **Step 4: Settings 页面其他文案改为本地化**

Replace hardcoded strings in `SettingsView.swift`, `HotKeyRecorderField.swift`, and `SettingsOpenCoordinator.swift` with `AppLocalization.text(...)`, including:

```swift
Text(AppLocalization.text("settings.title"))
Text(AppLocalization.text("settings.description"))
Text(AppLocalization.text("settings.hotkey.section"))
Text(AppLocalization.text("settings.hotkey.label"))
Text(AppLocalization.text("settings.hotkey.help"))
Text(AppLocalization.text("settings.ai.section"))
Toggle(AppLocalization.text("settings.ai.use_vision"), isOn: $aiUseVisionTextExtraction)
Text(AppLocalization.text("settings.ai.help"))
Text(AppLocalization.text("settings.save.section"))
Button(AppLocalization.text("settings.save.choose")) { ... }
Button(AppLocalization.text("settings.save.clear")) { ... }
```

and:

```swift
textField.placeholderString = AppLocalization.text("settings.hotkey.placeholder")
window.title = AppLocalization.text("window.settings.title")
```

- [ ] **Step 5: 录制错误提示接入本地化**

Update in `SettingsView.swift`:

```swift
hotKeyErrorMessage = AppLocalization.text("settings.hotkey.error.no_primary_key")
```

and:

```swift
hotKeyErrorMessage = AppLocalization.text("settings.hotkey.error.registration_failed")
```

- [ ] **Step 6: 构建验证并提交**

Run:

```bash
./scripts/build.sh
git add TYScreenShotTool/Resources/Localizable.xcstrings TYScreenShotTool/App/MenuBarContentView.swift TYScreenShotTool/App/SettingsView.swift TYScreenShotTool/App/HotKeyRecorderField.swift TYScreenShotTool/App/SettingsOpenCoordinator.swift TYScreenShotTool/App/TYScreenShotToolApp.swift
git commit -m "feat(sprint-38): 本地化菜单栏与设置页"
```

Expected: 菜单栏和 Settings 页面已支持 6 种语言与手动覆盖设置。

---

### Task 4: 本地化截图编辑态与 OCR 结果窗

**Files:**
- Modify: `TYScreenShotTool/Shared/AnnotationTool.swift`
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift`
- Modify: `TYScreenShotTool/Features/CaptureOverlay/CaptureAnnotationCanvasView.swift`
- Modify: `TYScreenShotTool/Services/OCRPreviewWindowService.swift`
- Modify: `TYScreenShotTool/Resources/Localizable.xcstrings`

- [ ] **Step 1: 为截图编辑态补充文案键**

Add these keys to `Localizable.xcstrings` in all 6 languages:

```text
annotation.rectangle
annotation.ellipse
annotation.arrow
annotation.pen
annotation.mosaic
annotation.text
capture.corner_radius
capture.shadow
capture.undo
capture.long_capture
capture.copy
capture.save
capture.cancel
capture.pin
capture.text_input_placeholder
ocr.window.title
ocr.copy
ocr.cancel
ocr.empty
```

- [ ] **Step 2: 标注工具标题改为本地化**

Update `TYScreenShotTool/Shared/AnnotationTool.swift`:

```swift
var title: String {
    switch self {
    case .rectangle:
        return AppLocalization.text("annotation.rectangle")
    case .ellipse:
        return AppLocalization.text("annotation.ellipse")
    case .arrow:
        return AppLocalization.text("annotation.arrow")
    case .pen:
        return AppLocalization.text("annotation.pen")
    case .mosaic:
        return AppLocalization.text("annotation.mosaic")
    case .text:
        return AppLocalization.text("annotation.text")
    }
}
```

- [ ] **Step 3: 截图编辑态按钮与标签改为本地化**

Update `TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift`:

```swift
private let cornerRadiusLabel = NSTextField(labelWithString: AppLocalization.text("capture.corner_radius"))
private let shadowToggle = NSButton(checkboxWithTitle: AppLocalization.text("capture.shadow"), target: nil, action: nil)
private let undoButton = NSButton(title: AppLocalization.text("capture.undo"), target: nil, action: nil)
private let longCaptureButton = NSButton(title: AppLocalization.text("capture.long_capture"), target: nil, action: nil)
private let pinButton = NSButton(title: AppLocalization.text("capture.pin"), target: nil, action: nil)
private let copyButton = NSButton(title: AppLocalization.text("capture.copy"), target: nil, action: nil)
private let saveButton = NSButton(title: AppLocalization.text("capture.save"), target: nil, action: nil)
private let cancelButton = NSButton(title: AppLocalization.text("capture.cancel"), target: nil, action: nil)
```

- [ ] **Step 4: 标注文字输入 placeholder 改为本地化**

Update `TYScreenShotTool/Features/CaptureOverlay/CaptureAnnotationCanvasView.swift`:

```swift
textField.placeholderString = AppLocalization.text("capture.text_input_placeholder")
```

- [ ] **Step 5: OCR 结果窗文案改为本地化**

Update `TYScreenShotTool/Services/OCRPreviewWindowService.swift`:

```swift
private let titleLabel = NSTextField(labelWithString: AppLocalization.text("ocr.window.title"))
private let copyButton = NSButton(title: AppLocalization.text("ocr.copy"), target: nil, action: nil)
private let cancelButton = NSButton(title: AppLocalization.text("ocr.cancel"), target: nil, action: nil)
```

and:

```swift
let displayText = normalizedText.isEmpty ? AppLocalization.text("ocr.empty") : text
```

- [ ] **Step 6: 构建验证并提交**

Run:

```bash
./scripts/build.sh
git add TYScreenShotTool/Shared/AnnotationTool.swift TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift TYScreenShotTool/Features/CaptureOverlay/CaptureAnnotationCanvasView.swift TYScreenShotTool/Services/OCRPreviewWindowService.swift TYScreenShotTool/Resources/Localizable.xcstrings
git commit -m "feat(sprint-38): 本地化截图编辑与OCR结果窗"
```

Expected: 截图编辑态与 OCR 结果窗用户可见文案完成本地化。

---

### Task 5: 本地化 AI 模式文案、AI 结果窗与 AI 固定标题

**Files:**
- Modify: `TYScreenShotTool/Shared/AIAnalysisMode.swift`
- Modify: `TYScreenShotTool/Shared/AITranslationLanguage.swift`
- Modify: `TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift`
- Modify: `TYScreenShotTool/Resources/Localizable.xcstrings`

- [ ] **Step 1: 为 AI UI 补充文案键**

Add these keys to `Localizable.xcstrings` in all 6 languages:

```text
ai.mode.developer_error
ai.mode.summary
ai.mode.interface_structure
ai.mode.translation.chinese
ai.mode.translation.english
ai.loading.developer_error
ai.loading.summary
ai.loading.interface_structure
ai.loading.translation.chinese
ai.loading.translation.english
ai.result.title
ai.result.summary
ai.result.interface_structure
ai.result.copy_all
ai.result.copy_suggestion
ai.result.copy_summary
ai.result.copy_structure
ai.result.copy_translation
ai.result.retry
ai.result.close
ai.result.error
ai.result.copied.suggestion
ai.result.copied.summary
ai.result.copied.structure
ai.result.copied.translation
ai.translation.menu
```

- [ ] **Step 2: AIAnalysisMode 文案改为本地化**

Update `TYScreenShotTool/Shared/AIAnalysisMode.swift` so every visible string uses `AppLocalization.text(...)`, for example:

```swift
case .developerError:
    return AppLocalization.text("ai.mode.developer_error")
```

and:

```swift
case .developerError:
    return AppLocalization.text("ai.loading.developer_error")
```

- [ ] **Step 3: AITranslationLanguage 文案改为本地化**

Update `TYScreenShotTool/Shared/AITranslationLanguage.swift`:

```swift
case .simplifiedChinese:
    return AppLocalization.text("ai.mode.translation.chinese")
case .english:
    return AppLocalization.text("ai.mode.translation.english")
```

and matching localized loading / result title values.

- [ ] **Step 4: AI 结果窗标题与按钮改为本地化**

Update `TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift`:

```swift
private let titleLabel = NSTextField(labelWithString: "")
private let copyAllButton = NSButton(title: "", target: nil, action: nil)
private let retryButton = NSButton(title: "", target: nil, action: nil)
private let closeButton = NSButton(title: "", target: nil, action: nil)

private func applyLocalizedStrings() {
    titleLabel.stringValue = AppLocalization.text("ai.result.title")
    copyAllButton.title = AppLocalization.text("ai.result.copy_all")
    retryButton.title = AppLocalization.text("ai.result.retry")
    closeButton.title = AppLocalization.text("ai.result.close")
}
```

and:

```swift
func presentLoading(
    ...,
    message: String? = nil,
    ...
) {
    applyLocalizedStrings()
    let resolvedMessage = message ?? AppLocalization.text("ai.loading.developer_error")
    ...
}
```

and:

```swift
func presentError(
    title: String? = nil,
    ...
) {
    applyLocalizedStrings()
    let resolvedTitle = title ?? AppLocalization.text("ai.result.error")
    ...
}
```

and in the result presentation path:

```swift
func presentResult(...) {
    applyLocalizedStrings()
    ...
}
```

- [ ] **Step 5: 保持结果窗 section 容器复用**

Do not create a new AI result window type. Keep:

```swift
let sectionViews = [summarySectionView, causesSectionView, nextStepsSectionView]
```

Expected: 本轮只本地化标题与按钮，不改 Sprint 35 ~ 37 已有结果窗结构。

- [ ] **Step 6: 构建验证并提交**

Run:

```bash
./scripts/build.sh
git add TYScreenShotTool/Shared/AIAnalysisMode.swift TYScreenShotTool/Shared/AITranslationLanguage.swift TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift TYScreenShotTool/Resources/Localizable.xcstrings
git commit -m "feat(sprint-38): 本地化AI模式与结果窗文案"
```

Expected: AI 菜单、loading、结果窗按钮与标题都能按当前语言显示。

---

### Task 6: 接入 AI prompt / 固定标题 / OCR 语言联动

**Files:**
- Modify: `TYScreenShotTool/Services/AIAnalysisService.swift`
- Modify: `TYScreenShotTool/Services/OCRService.swift`
- Modify: `TYScreenShotTool/Resources/Localizable.xcstrings`

- [ ] **Step 1: 为 AI 固定标题与错误文案补充键**

Add these keys to `Localizable.xcstrings` in all 6 languages:

```text
ai.prompt.output_language.zh_hans
ai.prompt.output_language.en
ai.prompt.output_language.ja
ai.prompt.output_language.ko
ai.prompt.output_language.de
ai.prompt.output_language.fr
ai.section.developer_error.summary
ai.section.developer_error.causes
ai.section.developer_error.next_steps
ai.section.summary.1
ai.section.summary.2
ai.section.summary.3
ai.section.translation
ai.section.interface_structure.root
ai.section.interface_structure.components
ai.section.interface_structure.hierarchy
ai.section.interface_structure.visual
ai.section.interface_structure.interaction
ai.section.interface_structure.implementation
ai.error.missing_api_key
ai.error.empty_input
ai.error.invalid_response
ai.error.empty_output
ai.error.low_quality
ai.error.request_failed
ocr.error.request_failed
ocr.error.no_text
ocr.error.empty_text
```

- [ ] **Step 2: AIAnalysisService 读取当前有效语言**

Add a helper in `TYScreenShotTool/Services/AIAnalysisService.swift`:

```swift
private func currentLanguage() -> AppLanguage {
    AppLocalization.currentLanguage(userDefaults: userDefaults)
}
```

- [ ] **Step 3: AI 固定标题从当前语言生成**

Refactor `definition(for:)` so section titles and prompt titles no longer hardcode Chinese. For example:

```swift
SectionDefinition(
    title: AppLocalization.text("ai.section.developer_error.summary"),
    promptTitle: AppLocalization.text("ai.section.developer_error.summary"),
    acceptedHeaders: [.exact(AppLocalization.text("ai.section.developer_error.summary"))]
)
```

Apply the same rule to:

- developer error 3 sections
- summary 3 sections
- translation `译文`
- interface structure root + 5 sub-headings

- [ ] **Step 4: AI prompt 输出语言按当前语言切换**

Add a helper in `AIAnalysisService.swift`:

```swift
private func promptOutputLanguageName(for language: AppLanguage) -> String {
    switch language {
    case .simplifiedChinese:
        return AppLocalization.text("ai.prompt.output_language.zh_hans")
    case .english:
        return AppLocalization.text("ai.prompt.output_language.en")
    case .japanese:
        return AppLocalization.text("ai.prompt.output_language.ja")
    case .korean:
        return AppLocalization.text("ai.prompt.output_language.ko")
    case .german:
        return AppLocalization.text("ai.prompt.output_language.de")
    case .french:
        return AppLocalization.text("ai.prompt.output_language.fr")
    case .system:
        return AppLocalization.text("ai.prompt.output_language.en")
    }
}
```

and include the resolved output language in prompt generation for non-translation and interface-structure modes.

- [ ] **Step 5: 保留翻译目标语言边界**

Keep translation target language logic independent from UI language. The prompt should still say:

```swift
case .simplifiedChinese:
    targetLanguageInstruction = "目标语言：简体中文"
case .english:
    targetLanguageInstruction = "目标语言：英文"
```

but the surrounding prompt narration can use the current effective language.

Expected: UI 语言是德文时，“翻译成中文”仍输出中文译文。

- [ ] **Step 6: OCR 识别语言改为当前语言优先**

Update `TYScreenShotTool/Services/OCRService.swift`:

```swift
func recognizeText(in image: CGImage) throws -> String {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = AppLocalization.currentLanguage(
        userDefaults: .standard
    ).ocrRecognitionLanguages
    ...
}
```

- [ ] **Step 7: AI / OCR 错误文案本地化**

Update `AIAnalysisError.errorDescription` and `OCRError.errorDescription` to use `AppLocalization.text(...)` and string interpolation helpers instead of hardcoded Chinese / English text.

- [ ] **Step 8: 构建验证并提交**

Run:

```bash
./scripts/build.sh
git add TYScreenShotTool/Services/AIAnalysisService.swift TYScreenShotTool/Services/OCRService.swift TYScreenShotTool/Resources/Localizable.xcstrings
git commit -m "feat(sprint-38): 接入本地化AI与OCR链路"
```

Expected: AI prompt / 固定标题 / OCR 语言优先级都按当前有效语言联动，且翻译目标语言边界保持正确。

---

### Task 7: 最终验证并同步 Sprint 38 文档

**Files:**
- Modify: `docs/ROADMAP.md`
- Modify: `docs/SPRINTS/Sprint-38.md`
- Modify: `TASK.md`
- Modify: `docs/DEVLOG.md`

- [ ] **Step 1: 运行最终构建验证**

Run:

```bash
./scripts/build.sh
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: 执行人工验证**

Manual verification checklist:

1. Settings 中可看到语言设置项
2. 语言设置支持“跟随系统 + 6 种语言手动覆盖”
3. 菜单栏菜单文案会跟随当前语言变化
4. Settings 页面文案会跟随当前语言变化
5. 普通截图编辑态按钮和标签会跟随当前语言变化
6. OCR 结果窗标题、按钮、空态会跟随当前语言变化
7. AI 菜单项、AI 结果窗标题、按钮、错误态会跟随当前语言变化
8. 用户切换语言后，新打开的窗口和新触发流程使用新语言
9. 已打开窗口不要求即时刷新
10. AI prompt 与 AI 固定输出标题会随当前有效语言切换
11. `翻译成中文 / 翻译成英文` 的目标语言不受 UI 语言影响
12. OCR 在日语、韩语、德语、法语界面下仍保持中英 fallback
13. 普通截图、长截图、OCR、AI 主链路无功能回归

- [ ] **Step 3: 将 Sprint-38.md 更新为 done**

Update:

```md
## Status

Done
```

and replace `Result` with implementation summary, bug-fix if any, and verification outcomes.

- [ ] **Step 4: 更新 ROADMAP 中 Sprint 38 状态**

Change:

```md
状态：
🚧 Planned
```

to:

```md
状态：
✅ Done
```

and replace `目标` with `成果`.

- [ ] **Step 5: 更新 TASK.md 当前状态**

Update `TASK.md` from Sprint 38 planned to Sprint 38 done or the next active Sprint state according to the actual outcome.

- [ ] **Step 6: 更新 DEVLOG**

Append a Sprint 38 section including:

- 主题：App 本地化
- 实现
- Bug Fix（如果实施过程中有）
- 验证
- 结果

- [ ] **Step 7: 提交收尾文档**

Run:

```bash
git add TASK.md docs/ROADMAP.md docs/SPRINTS/Sprint-38.md docs/DEVLOG.md
git commit -m "docs(sprint-38): 同步应用本地化完成状态"
```

Expected: Sprint 38 文档状态、验证与结果全部收尾完成。
