# Sprint 33 Custom Hotkey Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `Settings` 页面中增加最小自定义截图热键能力，让用户可以点击编辑框录入热键组合、按回车确认，并在失败时回退旧热键。

**Architecture:** 继续保留 `SettingsView` 的 SwiftUI 页面结构，新增长按键录制桥接控件专门负责捕获组合输入，`ScreenshotHotKey` 扩展为真实热键模型，`GlobalHotKeyService` 继续只负责注册和更新。输入捕获与全局注册分层处理，避免把设置页交互和系统热键注册耦合在一起。

**Tech Stack:** Swift 6, SwiftUI, AppKit, Carbon, UserDefaults / AppStorage

---

## File Structure

- Modify: `TYScreenShotTool/Features/Hotkey/ScreenshotHotKey.swift`
  - 从预设集合扩展为可表达任意 `keyCode + modifiers` 的热键模型
  - 统一处理持久化值和显示文案
- Create: `TYScreenShotTool/Features/Hotkey/KeyEquivalentNameMap.swift`
  - 收口字母、数字、功能键、方向键等主键的显示名称映射
- Create: `TYScreenShotTool/App/HotKeyRecorderField.swift`
  - 提供桥接 AppKit 的热键录制输入控件
  - 负责捕获键盘组合、回车确认、`Esc` 取消、失焦取消
- Modify: `TYScreenShotTool/App/SettingsView.swift`
  - 将现有热键 `Picker` 改为可点击编辑框
  - 接入录制状态、失败提示和热键更新流程
- Modify: `TYScreenShotTool/App/TYScreenShotToolApp.swift`
  - 保持从持久化值恢复热键时兼容新的存储格式
- Modify: `TYScreenShotTool/Shared/AppSettings.swift`
  - 更新截图热键默认存储值定义，适配新序列化格式
- Modify: `TASK.md`
  - 实现完成后同步 Sprint 33 当前任务状态
- Modify: `docs/ROADMAP.md`
  - 实现完成后同步 Sprint 33 状态
- Modify: `docs/SPRINTS/Sprint-33.md`
  - 实现完成后补充结果与验证
- Modify: `docs/DEVLOG.md`
  - 实现完成后记录 Sprint 33 的实现和验证结果

说明：

- 当前项目没有独立 test target，本轮验证以 `./scripts/build.sh` 与 `Settings` 页面人工交互验证为主。
- 本轮不实现快捷键冲突详情列表，也不扩展到截图快捷键以外的其他动作。

---

### Task 1: 扩展 ScreenshotHotKey 为真实热键模型

**Files:**
- Modify: `TYScreenShotTool/Features/Hotkey/ScreenshotHotKey.swift`
- Create: `TYScreenShotTool/Features/Hotkey/KeyEquivalentNameMap.swift`
- Modify: `TYScreenShotTool/Shared/AppSettings.swift`

- [ ] **Step 1: 先阅读当前热键模型和默认配置，确认现有预设结构**

Read:

```swift
struct ScreenshotHotKey: Equatable {
    let storageValue: String
    let id: UInt32
    let keyCode: UInt32
    let modifiers: UInt32
    let displayName: String
}
```

and:

```swift
static let screenshotHotKeyDefaultValue = "commandShift2"
```

Expected: 当前模型只能表达少量预设字符串，无法承载任意组合。

- [ ] **Step 2: 新增主键显示名映射文件，收口可支持的主键范围**

Create `TYScreenShotTool/Features/Hotkey/KeyEquivalentNameMap.swift`:

```swift
import Carbon
import Foundation

enum KeyEquivalentNameMap {
    static func displayName(for keyCode: UInt32) -> String? {
        switch Int(keyCode) {
        case kVK_ANSI_A ... kVK_ANSI_Z:
            let scalarOffset = keyCode - UInt32(kVK_ANSI_A)
            let scalar = UnicodeScalar(Int(("A" as UnicodeScalar).value) + Int(scalarOffset))
            return scalar.map(String.init)
        case kVK_ANSI_0 ... kVK_ANSI_9:
            let scalarOffset = keyCode - UInt32(kVK_ANSI_0)
            let scalar = UnicodeScalar(Int(("0" as UnicodeScalar).value) + Int(scalarOffset))
            return scalar.map(String.init)
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        default:
            return nil
        }
    }
}
```

Expected: 后续热键模型和录制控件都能共用同一套主键显示规则。

- [ ] **Step 3: 将 ScreenshotHotKey 改为根据 keyCode/modifiers 生成存储值和显示值**

Update `TYScreenShotTool/Features/Hotkey/ScreenshotHotKey.swift`:

```swift
import Carbon

struct ScreenshotHotKey: Equatable {
    let id: UInt32
    let keyCode: UInt32
    let modifiers: UInt32

    var storageValue: String {
        "\(keyCode):\(modifiers)"
    }

    var displayName: String {
        var parts: [String] = []

        if modifiers & UInt32(cmdKey) != 0 {
            parts.append("⌘")
        }
        if modifiers & UInt32(shiftKey) != 0 {
            parts.append("⇧")
        }
        if modifiers & UInt32(optionKey) != 0 {
            parts.append("⌥")
        }
        if modifiers & UInt32(controlKey) != 0 {
            parts.append("⌃")
        }

        guard let keyName = KeyEquivalentNameMap.displayName(for: keyCode) else {
            return parts.joined()
        }

        return parts.joined() + keyName
    }

    init(
        id: UInt32 = 1,
        keyCode: UInt32,
        modifiers: UInt32
    ) {
        self.id = id
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    static let screenshot = ScreenshotHotKey(
        keyCode: UInt32(kVK_ANSI_2),
        modifiers: UInt32(cmdKey | shiftKey)
    )

    init?(storageValue: String) {
        let parts = storageValue.split(separator: ":")
        guard parts.count == 2,
              let keyCode = UInt32(parts[0]),
              let modifiers = UInt32(parts[1]),
              KeyEquivalentNameMap.displayName(for: keyCode) != nil else {
            return nil
        }

        self.init(keyCode: keyCode, modifiers: modifiers)
    }

    static func makeCandidate(
        keyCode: UInt32,
        modifiers: UInt32
    ) -> ScreenshotHotKey? {
        guard KeyEquivalentNameMap.displayName(for: keyCode) != nil else {
            return nil
        }

        return ScreenshotHotKey(keyCode: keyCode, modifiers: modifiers)
    }
}
```

Expected: 模型已经不再依赖 `presets`，能承载任意支持范围内的组合。

- [ ] **Step 4: 将默认存储值切换为新格式，但继续保持默认热键不变**

Update `TYScreenShotTool/Shared/AppSettings.swift`:

```swift
static let screenshotHotKeyDefaultValue = ScreenshotHotKey.screenshot.storageValue
```

Expected: 默认仍然是 `⌘⇧2`，但存储值格式与新模型保持一致。

- [ ] **Step 5: 运行构建，确认热键模型层改动可独立编译**

Run: `./scripts/build.sh`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: 提交这一任务**

```bash
git add TYScreenShotTool/Features/Hotkey/ScreenshotHotKey.swift TYScreenShotTool/Features/Hotkey/KeyEquivalentNameMap.swift TYScreenShotTool/Shared/AppSettings.swift
git commit -m "feat(sprint-33): 扩展自定义截图热键模型"
```

Expected: 热键数据层独立成一个小提交。

---

### Task 2: 增加最小热键录制输入控件

**Files:**
- Create: `TYScreenShotTool/App/HotKeyRecorderField.swift`

- [ ] **Step 1: 新建桥接控件骨架，先定义输入输出边界**

Create `TYScreenShotTool/App/HotKeyRecorderField.swift`:

```swift
import AppKit
import SwiftUI

struct HotKeyRecorderField: NSViewRepresentable {
    @Binding var displayedValue: String
    @Binding var isRecording: Bool
    var onCandidateChanged: (ScreenshotHotKey?) -> Void
    var onCommit: () -> Void
    var onCancel: () -> Void

    func makeNSView(context: Context) -> HotKeyRecorderTextField {
        let textField = HotKeyRecorderTextField()
        textField.recorderDelegate = context.coordinator
        return textField
    }

    func updateNSView(_ nsView: HotKeyRecorderTextField, context: Context) {
        nsView.stringValue = displayedValue
        nsView.isRecording = isRecording

        if isRecording, nsView.window?.firstResponder !== nsView {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}
```

Expected: SettingsView 后续可以通过 bindings 控制显示值和录制态。

- [ ] **Step 2: 在同文件中补上自定义输入视图，拦截按键和失焦事件**

Append:

```swift
final class HotKeyRecorderTextField: NSTextField {
    weak var recorderDelegate: HotKeyRecorderField.Coordinator?
    var isRecording = false

    override var acceptsFirstResponder: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted {
            recorderDelegate?.didBeginRecording()
        }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            recorderDelegate?.didLoseFocus()
        }
        return resigned
    }

    override func keyDown(with event: NSEvent) {
        recorderDelegate?.handleKeyDown(event)
    }

    override func flagsChanged(with event: NSEvent) {
        recorderDelegate?.handleFlagsChanged(event)
    }
}
```

Expected: 控件自身只负责把事件转发给 coordinator，不持有业务逻辑。

- [ ] **Step 3: 实现 coordinator，完成候选组合、回车确认和取消逻辑**

Append:

```swift
extension HotKeyRecorderField {
    final class Coordinator: NSObject {
        private let parent: HotKeyRecorderField
        private var currentModifiers: UInt32 = 0
        private var currentCandidate: ScreenshotHotKey?
        private var isCancellingForFocusLoss = false

        init(_ parent: HotKeyRecorderField) {
            self.parent = parent
        }

        func didBeginRecording() {
            parent.isRecording = true
        }

        func didLoseFocus() {
            guard parent.isRecording, isCancellingForFocusLoss == false else {
                isCancellingForFocusLoss = false
                return
            }

            cancelRecording()
        }

        func handleFlagsChanged(_ event: NSEvent) {
            currentModifiers = carbonModifiers(from: event.modifierFlags)
            updateDisplayedValueForCurrentState()
        }

        func handleKeyDown(_ event: NSEvent) {
            switch Int(event.keyCode) {
            case kVK_Return:
                parent.onCommit()
            case kVK_Escape:
                cancelRecording()
            default:
                guard let candidate = ScreenshotHotKey.makeCandidate(
                    keyCode: UInt32(event.keyCode),
                    modifiers: currentModifiers
                ) else {
                    return
                }

                currentCandidate = candidate
                parent.displayedValue = candidate.displayName
                parent.onCandidateChanged(candidate)
            }
        }

        private func cancelRecording() {
            currentModifiers = 0
            currentCandidate = nil
            parent.onCandidateChanged(nil)
            parent.onCancel()
        }

        private func updateDisplayedValueForCurrentState() {
            guard currentCandidate == nil else {
                return
            }

            parent.displayedValue = modifierDisplayName(for: currentModifiers)
            parent.onCandidateChanged(nil)
        }

        private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
            var value: UInt32 = 0

            if flags.contains(.command) {
                value |= UInt32(cmdKey)
            }
            if flags.contains(.shift) {
                value |= UInt32(shiftKey)
            }
            if flags.contains(.option) {
                value |= UInt32(optionKey)
            }
            if flags.contains(.control) {
                value |= UInt32(controlKey)
            }

            return value
        }

        private func modifierDisplayName(for modifiers: UInt32) -> String {
            var parts: [String] = []

            if modifiers & UInt32(cmdKey) != 0 {
                parts.append("⌘")
            }
            if modifiers & UInt32(shiftKey) != 0 {
                parts.append("⇧")
            }
            if modifiers & UInt32(optionKey) != 0 {
                parts.append("⌥")
            }
            if modifiers & UInt32(controlKey) != 0 {
                parts.append("⌃")
            }

            return parts.joined()
        }
    }
}
```

Expected: 控件已经具备最小录制行为，且只有有效主键组合才会生成候选热键。

- [ ] **Step 4: 给录制控件补最小外观，让它看起来像设置编辑框**

Update `makeNSView`:

```swift
let textField = HotKeyRecorderTextField(frame: .zero)
textField.isEditable = false
textField.isBordered = true
textField.drawsBackground = true
textField.backgroundColor = .textBackgroundColor
textField.alignment = .left
textField.font = .systemFont(ofSize: 13)
textField.focusRingType = .default
```

Expected: 录制控件在 Settings 中看起来是标准输入框，而不是普通标签。

- [ ] **Step 5: 运行构建，确认录制控件层改动可独立编译**

Run: `./scripts/build.sh`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: 提交这一任务**

```bash
git add TYScreenShotTool/App/HotKeyRecorderField.swift
git commit -m "feat(sprint-33): 增加热键录制输入控件"
```

Expected: 输入捕获控件独立成一个小提交。

---

### Task 3: 将 SettingsView 从预设菜单改为热键编辑框

**Files:**
- Modify: `TYScreenShotTool/App/SettingsView.swift`

- [ ] **Step 1: 增加 SettingsView 的热键编辑状态**

Add state:

```swift
@State private var displayedHotKeyValue = ScreenshotHotKey.screenshot.displayName
@State private var isRecordingHotKey = false
@State private var pendingHotKey: ScreenshotHotKey?
@State private var previousHotKey: ScreenshotHotKey?
@State private var hotKeyErrorMessage = ""
```

Expected: Settings 页具备“显示值、旧值、候选值、错误提示”这几类最小状态。

- [ ] **Step 2: 在 init 或 appearance 流程中从存储值恢复当前显示文本**

Add helper:

```swift
private var configuredHotKey: ScreenshotHotKey {
    ScreenshotHotKey(storageValue: selectedHotKeyStorageValue) ?? .screenshot
}
```

and in `body` chain:

```swift
.onAppear {
    displayedHotKeyValue = configuredHotKey.displayName
}
```

Expected: Settings 首次打开时，编辑框显示当前真实已配置热键。

- [ ] **Step 3: 将当前 Picker 替换为热键录制控件**

Replace `hotKeyPicker` body with:

```swift
private var hotKeyPicker: some View {
    VStack(alignment: .leading, spacing: 6) {
        Text("HotKey 配置")
            .font(.headline)

        VStack(alignment: .leading, spacing: 8) {
            Text("截图快捷键")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HotKeyRecorderField(
                displayedValue: $displayedHotKeyValue,
                isRecording: $isRecordingHotKey,
                onCandidateChanged: { candidate in
                    pendingHotKey = candidate
                },
                onCommit: {
                    commitRecordedHotKey()
                },
                onCancel: {
                    cancelRecordedHotKey()
                }
            )
            .frame(height: 28)
        }

        if hotKeyErrorMessage.isEmpty == false {
            Text(hotKeyErrorMessage)
                .font(.subheadline)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }

        Text("支持修饰键与字母、数字、功能键、方向键组合，按回车确认。")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
```

Expected: 设置页热键项已经从预设选择切换为录制交互。

- [ ] **Step 4: 实现开始编辑、取消编辑和确认提交逻辑**

Add helpers:

```swift
private func beginRecordingIfNeeded() {
    if previousHotKey == nil {
        previousHotKey = configuredHotKey
    }
    hotKeyErrorMessage = ""
}

private func cancelRecordedHotKey() {
    let hotKey = previousHotKey ?? configuredHotKey
    displayedHotKeyValue = hotKey.displayName
    pendingHotKey = nil
    previousHotKey = nil
    isRecordingHotKey = false
}

private func commitRecordedHotKey() {
    defer {
        isRecordingHotKey = false
        pendingHotKey = nil
        previousHotKey = nil
    }

    let fallbackHotKey = previousHotKey ?? configuredHotKey
    guard let pendingHotKey else {
        displayedHotKeyValue = fallbackHotKey.displayName
        hotKeyErrorMessage = "请至少输入一个主键"
        return
    }

    if pendingHotKey == fallbackHotKey {
        displayedHotKeyValue = fallbackHotKey.displayName
        hotKeyErrorMessage = ""
        return
    }

    guard globalHotKeyService.updateHotKey(pendingHotKey) else {
        displayedHotKeyValue = fallbackHotKey.displayName
        hotKeyErrorMessage = "快捷键注册失败，请更换组合"
        return
    }

    selectedHotKeyStorageValue = pendingHotKey.storageValue
    displayedHotKeyValue = pendingHotKey.displayName
    hotKeyErrorMessage = ""
}
```

Expected: `Return` 成功提交，失败回退，`Esc` 或失焦取消都能恢复旧热键。

- [ ] **Step 5: 给录制过程补最小开始录制钩子**

Update the `HotKeyRecorderField` call:

```swift
HotKeyRecorderField(
    displayedValue: $displayedHotKeyValue,
    isRecording: $isRecordingHotKey,
    onCandidateChanged: { candidate in
        if isRecordingHotKey == false {
            beginRecordingIfNeeded()
            isRecordingHotKey = true
        }
        pendingHotKey = candidate
    },
    onCommit: {
        commitRecordedHotKey()
    },
    onCancel: {
        cancelRecordedHotKey()
    }
)
```

Expected: 录制前能先保存旧热键，取消或失败时可稳定回退。

- [ ] **Step 6: 删除旧的 onChange 预设更新逻辑**

Remove:

```swift
.onChange(of: selectedHotKeyStorageValue) { _, newValue in
    guard let hotKey = ScreenshotHotKey(storageValue: newValue) else {
        return
    }

    if !globalHotKeyService.updateHotKey(hotKey) {
        selectedHotKeyStorageValue = AppSettings.screenshotHotKeyDefaultValue
    }
}
```

Expected: 热键更新改为只在显式按 `Return` 时提交，不再被 `AppStorage` 变化被动驱动。

- [ ] **Step 7: 运行构建，确认设置页热键编辑链路可编译**

Run: `./scripts/build.sh`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: 提交这一任务**

```bash
git add TYScreenShotTool/App/SettingsView.swift
git commit -m "feat(sprint-33): 支持设置页自定义截图热键"
```

Expected: 设置页交互更新独立成一个小提交。

---

### Task 4: 补齐应用初始化与旧配置兼容

**Files:**
- Modify: `TYScreenShotTool/App/TYScreenShotToolApp.swift`
- Modify: `TYScreenShotTool/Features/Hotkey/ScreenshotHotKey.swift`

- [ ] **Step 1: 给 ScreenshotHotKey 增加对旧预设存储值的兼容解析**

Append in `init?(storageValue:)` before split parsing:

```swift
switch storageValue {
case "commandShift2":
    self = .screenshot
    return
case "commandShift8":
    self = ScreenshotHotKey(
        keyCode: UInt32(kVK_ANSI_8),
        modifiers: UInt32(cmdKey | shiftKey)
    )
    return
case "commandShift9":
    self = ScreenshotHotKey(
        keyCode: UInt32(kVK_ANSI_9),
        modifiers: UInt32(cmdKey | shiftKey)
    )
    return
default:
    break
}
```

Expected: 已有用户升级后仍能读回老配置，不会被重置。

- [ ] **Step 2: 保持 App 启动时从存储值恢复热键的入口不变**

Verify `TYScreenShotTool/App/TYScreenShotToolApp.swift` keeps:

```swift
private static func loadConfiguredHotKey() -> ScreenshotHotKey {
    let storageValue = UserDefaults.standard.string(forKey: AppSettings.screenshotHotKeyKey)
        ?? AppSettings.screenshotHotKeyDefaultValue

    return ScreenshotHotKey(storageValue: storageValue) ?? .screenshot
}
```

Expected: 启动恢复路径继续复用，不新增分支。

- [ ] **Step 3: 运行构建，确认兼容层改动可编译**

Run: `./scripts/build.sh`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 提交这一任务**

```bash
git add TYScreenShotTool/App/TYScreenShotToolApp.swift TYScreenShotTool/Features/Hotkey/ScreenshotHotKey.swift
git commit -m "fix(sprint-33): 兼容旧版截图热键配置"
```

Expected: 升级兼容逻辑独立成一个小提交。

---

### Task 5: 人工验证自定义截图热键主链路

**Files:**
- No code change required unless validation reveals issues

- [ ] **Step 1: 运行构建**

Run: `./scripts/build.sh`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: 验证 Settings 默认显示**

Manual:

1. 打开 `Settings`
2. 查看“截图快捷键”项
3. 确认显示为可点击编辑框
4. 确认默认值显示为当前已配置热键

Expected: 不再显示预设菜单，默认显示正确。

- [ ] **Step 3: 验证最小自定义组合录制**

Manual:

1. 点击热键编辑框
2. 输入 `Command + A`
3. 按 `Return`
4. 关闭 `Settings`
5. 真实按下 `⌘A`

Expected: 新热键已生效，可触发截图流程。

- [ ] **Step 4: 验证多种主键范围**

Manual:

1. 重复录制 `Command + Shift + 8`
2. 再录制 `Control + Option + F5`
3. 再录制 `Command + ↑`

Expected: 编辑框均可正确显示组合，按 `Return` 后可成功保存。

- [ ] **Step 5: 验证无效输入不会误保存**

Manual:

1. 点击热键编辑框
2. 只按 `Command` 或 `Shift`
3. 按 `Return`

Expected: 不会保存为有效热键，界面恢复旧热键并给出最小提示。

- [ ] **Step 6: 验证取消路径**

Manual:

1. 点击热键编辑框
2. 输入一个新组合但不要确认
3. 按 `Esc`
4. 再次输入一个新组合但不要确认
5. 点击编辑框外部

Expected: 两种路径都恢复旧热键，不修改已生效配置。

- [ ] **Step 7: 验证注册失败回退**

Manual:

1. 输入一个已知无法注册的组合，或通过冲突场景制造注册失败
2. 按 `Return`

Expected: 界面恢复旧热键，并显示“快捷键注册失败，请更换组合”之类的失败提示。

- [ ] **Step 8: 验证保存目录配置不回归**

Manual:

1. 打开 `Settings`
2. 重新选择或查看保存目录配置
3. 执行一次截图保存

Expected: 保存目录配置与截图保存主链路保持正常。

---

### Task 6: 同步 Sprint 33 文档收尾

**Files:**
- Modify: `TASK.md`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/SPRINTS/Sprint-33.md`
- Modify: `docs/DEVLOG.md`

- [ ] **Step 1: 更新 TASK.md**

Update:

- `Current Sprint` 从 `Sprint 33 Planned` 改为 `Sprint 33 Done`
- 当前状态改为“已完成实现、构建验证与人工验证”
- 验收标准改为验收结果
- 补充构建通过与人工验证通过结论

Expected: `TASK.md` 只表达当前已完成的 Sprint 33。

- [ ] **Step 2: 更新 Sprint 33 文档**

Update `docs/SPRINTS/Sprint-33.md`:

- `Status` 改为 `Done`
- `Result` 从 `Pending` 改为实际实现结果
- 补充人工验证结果

Expected: Sprint 文档完整记录实现、验证与结果。

- [ ] **Step 3: 更新 ROADMAP**

Update `docs/ROADMAP.md`:

- Sprint 33 状态从 `🚧 Planned` 改为 `✅ Done`
- 目标改为成果

Expected: 路线图与当前完成状态一致。

- [ ] **Step 4: 更新 DEVLOG**

Add a `2026-06-20` or实现当天条目，记录：

- 自定义截图热键主题
- 录制编辑框实现
- 旧配置兼容
- 注册失败回退
- 人工验证结果

Expected: `DEVLOG` 记录本轮有意义的实现与问题处理结果。

- [ ] **Step 5: 提交这一任务**

```bash
git add TASK.md docs/ROADMAP.md docs/SPRINTS/Sprint-33.md docs/DEVLOG.md
git commit -m "docs(sprint-33): 同步自定义截图热键结果"
```

Expected: Sprint 33 文档收尾独立成一个小提交。

---

## Self-Review

- Spec coverage：已覆盖设置页编辑框入口、录制模式、支持的键位范围、`Return` 确认、`Esc` / 失焦取消、注册失败回退、旧配置兼容、人工验证与文档收尾。
- Placeholder scan：计划中没有 `TBD`、`TODO` 或“实现细节后补”类占位描述。
- Type consistency：计划统一使用 `HotKeyRecorderField`、`ScreenshotHotKey.makeCandidate(...)`、`commitRecordedHotKey()`、`cancelRecordedHotKey()`、`displayedHotKeyValue`、`pendingHotKey` 这些名称，前后保持一致。
