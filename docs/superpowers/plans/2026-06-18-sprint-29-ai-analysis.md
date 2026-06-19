# Sprint 29 - AI 分析实施计划

> **面向 Agent 执行说明：** 实施本计划时，必须按任务逐项推进。推荐使用 `superpowers:subagent-driven-development`，也可使用 `superpowers:executing-plans`。任务使用复选框 `- [ ]` 形式跟踪。

**目标：** 为开发报错截图增加一个最小 `AI 分析` 工作流，且只使用 `OCR` 文本作为 AI 输入来源。

**架构：** 新流程继续放在现有 `CaptureSessionService` 编排层内完成。新增一个专门的 AI 请求服务、一个专门的 AI 结果面板服务，以及一个新的工具栏动作。继续复用当前“基于原始截图执行 OCR”的行为和现有浮层式预览交互。

**技术栈：** Swift 6、AppKit、Foundation、Vision OCR、URLSession、OpenAI Responses API

---

## 规划说明

- 当前仓库没有 XCTest target。
- 因此本计划以 `./scripts/build.sh` 和人工验证作为主要验收手段，而不是强行要求完整的 RED / GREEN 自动化测试流程。
- 但实现时仍应把 AI 请求逻辑隔离清楚，方便未来补充单元测试。

---

## 文件结构

### 新增文件

- `TYScreenShotTool/Services/AIAnalysisService.swift`
  负责隐藏配置读取、提示词构造、HTTP 请求、响应解析和 AI 相关错误定义。

- `TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift`
  负责加载中 / 成功 / 失败三种结果面板展示，以及按钮回调。

### 修改文件

- `TYScreenShotTool/Shared/AppSettings.swift`
  增加 AI 分析所需的隐藏配置键和默认模型常量。

- `TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift`
  增加 `AI` 工具栏按钮，并上抛点击事件。

- `TYScreenShotTool/Services/CaptureOverlayService.swift`
  增加 `AI` 事件转发。

- `TYScreenShotTool/Services/CaptureSessionService.swift`
  串联 `OCR -> AI -> 结果面板`，并处理流程切换时的面板清理。

- `TYScreenShotTool/App/TYScreenShotToolApp.swift`
  在应用入口处装配新服务。

- `README.md`
  记录本地隐藏 AI 配置方式。

- `docs/DEVLOG.md`
  在实现完成后记录本轮结果。

---

### 任务 1：增加隐藏 AI 配置键

**文件：**
- 修改：`TYScreenShotTool/Shared/AppSettings.swift`

- [ ] **步骤 1：增加隐藏配置键**

更新 `AppSettings`，让 AI 分析可以读取本地配置，但不暴露设置页 UI。

```swift
enum AppSettings {
    static let screenshotHotKeyKey = "settings.screenshotHotKey"
    static let screenshotHotKeyDefaultValue = "commandShift2"
    static let saveDirectoryPathKey = "settings.saveDirectoryPath"
    static let saveDirectoryBookmarkDataKey = "settings.saveDirectoryBookmarkData"

    static let aiAnalysisAPIKeyKey = "local.aiAnalysis.openAIAPIKey"
    static let aiAnalysisModelKey = "local.aiAnalysis.model"
    static let aiAnalysisModelDefaultValue = "gpt-5.4-mini"
}
```

- [ ] **步骤 2：修改后执行构建**

运行：`./scripts/build.sh`

预期：`** BUILD SUCCEEDED **`

---

### 任务 2：新增 AI 请求服务

**文件：**
- 新增：`TYScreenShotTool/Services/AIAnalysisService.swift`

- [ ] **步骤 1：增加服务与错误定义**

创建一个聚焦的服务，
输入为 `OCR` 文本，
输出为最终分析字符串。

```swift
import Foundation

final class AIAnalysisService {
    private let session: URLSession
    private let userDefaults: UserDefaults

    init(
        session: URLSession = .shared,
        userDefaults: UserDefaults = .standard
    ) {
        self.session = session
        self.userDefaults = userDefaults
    }

    func analyzeDeveloperError(text: String) async throws -> String {
        let apiKey = try resolvedAPIKey()
        let prompt = buildDeveloperErrorPrompt(from: text)
        let request = try makeRequest(apiKey: apiKey, prompt: prompt)
        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data)
        return try parseOutputText(from: data)
    }
}

enum AIAnalysisError: LocalizedError {
    case missingAPIKey
    case emptyInput
    case invalidResponse
    case emptyOutput
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API Key 未配置。"
        case .emptyInput:
            return "OCR 文本为空。"
        case .invalidResponse:
            return "AI 返回格式无效。"
        case .emptyOutput:
            return "AI 返回内容为空。"
        case let .requestFailed(reason):
            return "AI 请求失败：\(reason)"
        }
    }
}
```

- [ ] **步骤 2：补充请求体类型与请求构造**

使用 OpenAI Responses API，
通过 Bearer 认证发送最小文本输入。

```swift
private extension AIAnalysisService {
    struct ResponseRequestBody: Encodable {
        let model: String
        let instructions: String
        let input: String
        let store: Bool
    }

    func resolvedAPIKey() throws -> String {
        let key = userDefaults.string(forKey: AppSettings.aiAnalysisAPIKeyKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard key.isEmpty == false else {
            throw AIAnalysisError.missingAPIKey
        }

        return key
    }

    func resolvedModel() -> String {
        let configured = userDefaults.string(forKey: AppSettings.aiAnalysisModelKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return (configured?.isEmpty == false)
            ? configured!
            : AppSettings.aiAnalysisModelDefaultValue
    }

    func buildDeveloperErrorPrompt(from text: String) -> String {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)

        return """
        你是一个帮助 macOS / iOS 开发者排查报错的助手。
        请基于下面的报错文本，用简洁中文输出：
        1. 报错大意
        2. 可能原因
        3. 建议下一步

        要求：
        - 保持短而清晰
        - 如果信息不足，明确说明不确定点
        - 不要输出与截图无关的泛泛建议

        报错文本：
        \(normalized)
        """
    }

    func makeRequest(apiKey: String, prompt: String) throws -> URLRequest {
        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            throw AIAnalysisError.requestFailed("API URL 无效。")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body = ResponseRequestBody(
            model: resolvedModel(),
            instructions: "你负责分析开发报错文本，并用简洁中文输出结果。",
            input: prompt,
            store: false
        )

        request.httpBody = try JSONEncoder().encode(body)
        return request
    }
}
```

- [ ] **步骤 3：补充响应校验与文本解析**

从返回的 `output` 结构中提取最终文本结果。

```swift
private extension AIAnalysisService {
    struct ResponseEnvelope: Decodable {
        let output: [OutputItem]
    }

    struct OutputItem: Decodable {
        let type: String
        let content: [OutputContent]?
    }

    struct OutputContent: Decodable {
        let type: String
        let text: String?
    }

    func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIAnalysisError.invalidResponse
        }

        guard 200 ..< 300 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? "未知服务端错误。"
            throw AIAnalysisError.requestFailed(message)
        }
    }

    func parseOutputText(from data: Data) throws -> String {
        let envelope = try JSONDecoder().decode(ResponseEnvelope.self, from: data)

        let text = envelope.output
            .filter { $0.type == "message" }
            .flatMap { $0.content ?? [] }
            .filter { $0.type == "output_text" }
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard text.isEmpty == false else {
            throw AIAnalysisError.emptyOutput
        }

        return text
    }
}
```

- [ ] **步骤 4：新增服务后执行构建**

运行：`./scripts/build.sh`

预期：`** BUILD SUCCEEDED **`

---

### 任务 3：新增 AI 结果预览面板服务

**文件：**
- 新增：`TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift`

- [ ] **步骤 1：创建面板基础结构**

面板结构参考现有 `OCR` 预览面板，
但要支持加载中 / 成功 / 失败三种状态。

```swift
import AppKit

@MainActor
final class AIAnalysisPreviewWindowService {
    private let panel = NSPanel(
        contentRect: .zero,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    private let containerView = NSVisualEffectView()
    private let titleLabel = NSTextField(labelWithString: "AI Analysis")
    private let statusLabel = NSTextField(labelWithString: "")
    private let scrollView = NSScrollView()
    private let textView = NSTextView()
    private let copyButton = NSButton(title: "复制", target: nil, action: nil)
    private let retryButton = NSButton(title: "重试", target: nil, action: nil)
    private let closeButton = NSButton(title: "关闭", target: nil, action: nil)

    private var onCopy: (() -> Void)?
    private var onRetry: (() -> Void)?
    private var onClose: (() -> Void)?

    init() {
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false

        containerView.material = .hudWindow
        containerView.blendingMode = .withinWindow
        containerView.state = .active
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 14
    }
}
```

- [ ] **步骤 2：增加三种状态的展示方法**

为加载中、成功、失败分别提供独立 API，
避免一个方法承担过多分支。

```swift
extension AIAnalysisPreviewWindowService {
    func presentLoading(
        selectionRect: CGRect,
        message: String = "AI 正在分析...",
        onClose: @escaping () -> Void
    ) {
        statusLabel.stringValue = message
        textView.string = ""
        copyButton.isEnabled = false
        retryButton.isEnabled = false
        onCopy = nil
        onRetry = nil
        self.onClose = onClose
        presentPanel(selectionRect: selectionRect)
    }

    func presentResult(
        text: String,
        selectionRect: CGRect,
        onCopy: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        statusLabel.stringValue = "AI 分析结果"
        textView.string = text
        copyButton.isEnabled = true
        retryButton.isEnabled = true
        self.onCopy = onCopy
        self.onRetry = onRetry
        self.onClose = onClose
        presentPanel(selectionRect: selectionRect)
    }

    func presentError(
        message: String,
        selectionRect: CGRect,
        onRetry: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        statusLabel.stringValue = "AI 分析失败"
        textView.string = message
        copyButton.isEnabled = false
        retryButton.isEnabled = true
        onCopy = nil
        self.onRetry = onRetry
        self.onClose = onClose
        presentPanel(selectionRect: selectionRect)
    }
}
```

- [ ] **步骤 3：增加回调、布局和关闭逻辑**

面板位置逻辑尽量复用 `OCR` 预览面板的侧边展示方式。

```swift
extension AIAnalysisPreviewWindowService {
    func dismiss() {
        panel.orderOut(nil)
        textView.string = ""
        onCopy = nil
        onRetry = nil
        onClose = nil
    }

    @objc private func copyRequested() { onCopy?() }
    @objc private func retryRequested() { onRetry?() }
    @objc private func closeRequested() { onClose?() }

    private func presentPanel(selectionRect: CGRect) {
        guard let screen = NSScreen.screens.first(where: {
            $0.frame.contains(CGPoint(x: selectionRect.midX, y: selectionRect.midY))
        }) else {
            dismiss()
            return
        }

        let panelFrame = frame(for: selectionRect, on: screen)
        panel.setFrame(panelFrame, display: true)
        layoutContent(in: panelFrame.size)
        panel.orderFrontRegardless()
    }
}
```

- [ ] **步骤 4：新增面板服务后执行构建**

运行：`./scripts/build.sh`

预期：`** BUILD SUCCEEDED **`

---

### 任务 4：增加 AI 工具栏动作

**文件：**
- 修改：`TYScreenShotTool/Features/CaptureOverlay/CaptureOverlayView.swift`
- 修改：`TYScreenShotTool/Services/CaptureOverlayService.swift`

- [ ] **步骤 1：在 `CaptureOverlayView` 增加回调和按钮**

新增一个回调和一个按钮，
按钮放在现有 `OCR` 按钮附近。

```swift
var onAIRequested: ((CapturePreviewStyle, [CaptureAnnotation]) -> Void)?

private let aiButton = NSButton(title: "AI", target: nil, action: nil)
```

在 `configureToolbar()` 中接线：

```swift
aiButton.target = self
aiButton.action = #selector(requestAI)

(annotationButtons + [undoButton, longCaptureButton, ocrButton, aiButton, pinButton, copyButton, saveButton, cancelButton]).forEach { button in
    button.bezelStyle = .rounded
}

toolbarContainerView.addSubview(aiButton)
```

加入布局：

```swift
aiButton.sizeToFit()
let toolbarButtons = annotationButtons + [undoButton, longCaptureButton, ocrButton, aiButton, pinButton, copyButton, saveButton, cancelButton]
```

增加选择器：

```swift
@objc
private func requestAI() {
    annotationCanvasView.commitActiveTextIfNeeded()
    onAIRequested?(previewStyle, annotationCanvasView.annotations)
}
```

- [ ] **步骤 2：在 `CaptureOverlayService` 转发事件**

增加 service 属性：

```swift
var onAIRequested: ((CapturePreviewStyle, [CaptureAnnotation]) -> Void)?
```

在 `CaptureOverlayView` 装配处转发：

```swift
overlayView.onAIRequested = { [weak self] in
    self?.onAIRequested?($0, $1)
}
```

- [ ] **步骤 3：工具栏改动后执行构建**

运行：`./scripts/build.sh`

预期：`** BUILD SUCCEEDED **`

- [ ] **步骤 4：增加 loading 期间的按钮约束**

为了避免重复触发，
需要给 `AI` 按钮增加最小可用状态控制。

在 `CaptureOverlayView` 中增加：

```swift
func setAIButtonEnabled(_ isEnabled: Bool) {
    aiButton.isEnabled = isEnabled
}
```

并在 `CaptureOverlayService` 中增加对应转发方法，
供 `CaptureSessionService` 在请求开始和结束时调用。

---

### 任务 5：在应用入口装配新服务

**文件：**
- 修改：`TYScreenShotTool/App/TYScreenShotToolApp.swift`

- [ ] **步骤 1：实例化新服务**

在现有 `OCR` 预览相关装配附近新增：

```swift
let aiAnalysisService = AIAnalysisService()
let aiAnalysisPreviewWindowService = AIAnalysisPreviewWindowService()
```

- [ ] **步骤 2：注入到 `CaptureSessionService`**

扩展初始化参数：

```swift
let sessionService = CaptureSessionService(
    overlayService: overlayService,
    screenCaptureService: screenCaptureService,
    clipboardService: clipboardService,
    imageSaveService: imageSaveService,
    ocrService: OCRService(),
    aiAnalysisService: aiAnalysisService,
    pinWindowService: pinWindowService,
    toastService: toastService,
    settingsOpenCoordinator: settingsOpenCoordinator,
    scrollingCaptureService: scrollingCaptureService,
    scrollingCapturePanelService: scrollingCapturePanelService,
    scrollingCapturePreviewWindowService: scrollingCapturePreviewWindowService,
    ocrPreviewWindowService: ocrPreviewWindowService,
    aiAnalysisPreviewWindowService: aiAnalysisPreviewWindowService
)
```

- [ ] **步骤 3：转发 overlay 事件**

```swift
overlayService.onAIRequested = { style, annotations in
    sessionService.analyzePendingCapture(style: style, annotations: annotations)
}
```

- [ ] **步骤 4：入口装配完成后执行构建**

运行：`./scripts/build.sh`

预期：`** BUILD SUCCEEDED **`

---

### 任务 6：在 `CaptureSessionService` 中实现 AI 编排

**文件：**
- 修改：`TYScreenShotTool/Services/CaptureSessionService.swift`

- [ ] **步骤 1：增加依赖和状态**

新增属性：

```swift
private let aiAnalysisService: AIAnalysisService
private let aiAnalysisPreviewWindowService: AIAnalysisPreviewWindowService
private var isAIAnalysisInProgress = false
private var latestAIAnalysisText: String?
```

更新初始化方法：

```swift
init(
    overlayService: CaptureOverlayService,
    screenCaptureService: ScreenCaptureService,
    clipboardService: ClipboardService,
    imageSaveService: ImageSaveService,
    ocrService: OCRService,
    aiAnalysisService: AIAnalysisService,
    pinWindowService: PinWindowService,
    toastService: ToastService,
    settingsOpenCoordinator: SettingsOpenCoordinator,
    scrollingCaptureService: ScrollingCaptureService,
    scrollingCapturePanelService: ScrollingCapturePanelService,
    scrollingCapturePreviewWindowService: ScrollingCapturePreviewWindowService,
    ocrPreviewWindowService: OCRPreviewWindowService,
    aiAnalysisPreviewWindowService: AIAnalysisPreviewWindowService
) {
    self.overlayService = overlayService
    self.screenCaptureService = screenCaptureService
    self.clipboardService = clipboardService
    self.imageSaveService = imageSaveService
    self.ocrService = ocrService
    self.aiAnalysisService = aiAnalysisService
    self.pinWindowService = pinWindowService
    self.toastService = toastService
    self.settingsOpenCoordinator = settingsOpenCoordinator
    self.scrollingCaptureService = scrollingCaptureService
    self.scrollingCapturePanelService = scrollingCapturePanelService
    self.scrollingCapturePreviewWindowService = scrollingCapturePreviewWindowService
    self.ocrPreviewWindowService = ocrPreviewWindowService
    self.aiAnalysisPreviewWindowService = aiAnalysisPreviewWindowService
}
```

- [ ] **步骤 2：增加 AI 分析入口方法**

```swift
func analyzePendingCapture(style: CapturePreviewStyle, annotations: [CaptureAnnotation]) {
    guard state == .selectionCompleted, let pendingSelectionRect else {
        return
    }

    guard isAIAnalysisInProgress == false else {
        toastService.showToast(message: "AI 正在分析中")
        return
    }

    isAIAnalysisInProgress = true
    overlayService.setAIButtonEnabled(false)
    ocrPreviewWindowService.dismiss()

    aiAnalysisPreviewWindowService.presentLoading(
        selectionRect: pendingSelectionRect,
        onClose: { [weak self] in
            self?.aiAnalysisPreviewWindowService.dismiss()
        }
    )

    Task { [weak self] in
        guard let self else {
            return
        }

        await self.performAIAnalysis(selectionRect: pendingSelectionRect)
    }
}
```

- [ ] **步骤 3：实现异步 `OCR -> AI` 主流程**

```swift
@MainActor
private func performAIAnalysis(selectionRect: CGRect) async {
    defer {
        isAIAnalysisInProgress = false
        overlayService.setAIButtonEnabled(true)
    }

    do {
        let image = try frozenSelectionImage(for: selectionRect)
        let text = try ocrService.recognizeText(in: image)
        let result = try await aiAnalysisService.analyzeDeveloperError(text: text)
        latestAIAnalysisText = result

        aiAnalysisPreviewWindowService.presentResult(
            text: result,
            selectionRect: selectionRect,
            onCopy: { [weak self] in
                self?.copyAIAnalysisResult(result)
            },
            onRetry: { [weak self] in
                self?.retryAIAnalysis()
            },
            onClose: { [weak self] in
                self?.aiAnalysisPreviewWindowService.dismiss()
            }
        )
    } catch let error as OCRError {
        latestAIAnalysisText = nil
        toastService.showToast(message: "OCR 未识别到有效文本")
        aiAnalysisPreviewWindowService.presentError(
            message: error.localizedDescription,
            selectionRect: selectionRect,
            onRetry: { [weak self] in self?.retryAIAnalysis() },
            onClose: { [weak self] in self?.aiAnalysisPreviewWindowService.dismiss() }
        )
    } catch let error as AIAnalysisError {
        latestAIAnalysisText = nil
        toastService.showToast(message: "AI 分析失败")
        aiAnalysisPreviewWindowService.presentError(
            message: error.localizedDescription,
            selectionRect: selectionRect,
            onRetry: { [weak self] in self?.retryAIAnalysis() },
            onClose: { [weak self] in self?.aiAnalysisPreviewWindowService.dismiss() }
        )
    } catch {
        latestAIAnalysisText = nil
        toastService.showToast(message: "AI 分析失败")
        aiAnalysisPreviewWindowService.presentError(
            message: error.localizedDescription,
            selectionRect: selectionRect,
            onRetry: { [weak self] in self?.retryAIAnalysis() },
            onClose: { [weak self] in self?.aiAnalysisPreviewWindowService.dismiss() }
        )
    }
}
```

- [ ] **步骤 4：增加重试和复制辅助方法**

```swift
@MainActor
private func retryAIAnalysis() {
    guard let pendingSelectionRect else {
        return
    }

    guard isAIAnalysisInProgress == false else {
        return
    }

    isAIAnalysisInProgress = true
    overlayService.setAIButtonEnabled(false)
    aiAnalysisPreviewWindowService.presentLoading(
        selectionRect: pendingSelectionRect,
        onClose: { [weak self] in
            self?.aiAnalysisPreviewWindowService.dismiss()
        }
    )

    Task { [weak self] in
        guard let self else {
            return
        }

        await self.performAIAnalysis(selectionRect: pendingSelectionRect)
    }
}

@MainActor
private func copyAIAnalysisResult(_ text: String) {
    do {
        try clipboardService.copyText(text)
        toastService.showToast(message: "AI 分析结果已复制")
    } catch {
        toastService.showToast(message: "AI 结果复制失败")
    }
}
```

交互约束：

- loading 状态下工具栏 `AI` 按钮禁用
- loading 状态下结果面板 `重试` 按钮禁用
- `关闭` 只关闭面板，不取消已发出的请求
- AI 分析继续基于原始截图区域，不读取标注结果

实现说明：

- `presentLoading(...)` 中保持 `retryButton.isEnabled = false`
- `presentResult(...)` 与 `presentError(...)` 中恢复 `retryButton.isEnabled = true`

- [ ] **步骤 5：在其他流程切换处关闭 AI 面板**

凡是当前存在：

```swift
ocrPreviewWindowService.dismiss()
```

的地方，都同步补上：

```swift
aiAnalysisPreviewWindowService.dismiss()
```

至少覆盖以下路径：

- `cancelSession()`
- `copyPendingCapture(...)`
- `savePendingCapture(...)`
- `pinPendingCapture(...)`
- `startScrollingCapture(...)`
- `finishFailedSaveSession()`
- `cancelScrollingCapture()`
- `finishScrollingCaptureSession()`
- `failScrollingCapture(...)`

- [ ] **步骤 6：在 `clearPendingCapture()` 中清理 AI 状态**

```swift
private func clearPendingCapture() {
    pendingSelectionRect = nil
    pendingScreenImages.removeAll()
    scrollingCaptureFrames.removeAll()
    scrollingCaptureResultImage = nil
    isAppendingScrollingFrame = false
    removeScrollingEventMonitor()
    scrollingAppendTask?.cancel()
    scrollingAppendTask = nil
    isInScrollingCaptureMode = false
    isAIAnalysisInProgress = false
    latestAIAnalysisText = nil
}
```

- [ ] **步骤 7：编排层改完后执行构建**

运行：`./scripts/build.sh`

预期：`** BUILD SUCCEEDED **`

---

### 任务 7：补充本地配置文档

**文件：**
- 修改：`README.md`

- [ ] **步骤 1：增加隐藏 AI 配置说明**

在 `README` 的 AI 路线或本地配置位置补充说明：

```md
## AI 分析本地配置

当前 `AI 分析` 仍处于最小开发阶段，
暂不提供设置页配置入口。

本地可通过以下命令写入 API Key：

```bash
defaults write com.sheldon.TShot local.aiAnalysis.openAIAPIKey -string "YOUR_OPENAI_API_KEY"
```

如需覆盖默认模型，可使用：

```bash
defaults write com.sheldon.TShot local.aiAnalysis.model -string "gpt-5.4-mini"
```
```

- [ ] **步骤 2：文档修改后执行构建**

运行：`./scripts/build.sh`

预期：`** BUILD SUCCEEDED **`

---

### 任务 8：人工验证并完成 Sprint 文档收尾

**文件：**
- 修改：`docs/SPRINTS/Sprint-29.md`
- 修改：`TASK.md`
- 修改：`docs/DEVLOG.md`

- [ ] **步骤 1：执行人工验证**

逐项确认以下场景：

```text
1. 截图进入编辑态后可见 AI 按钮
2. 点击 AI 后出现 loading 状态
3. 开发报错截图返回可读结果
4. 复制按钮可以复制结果
5. 重试按钮可以重新发起分析
6. 关闭按钮只关闭 AI 面板
7. API Key 缺失时有明确反馈
8. OCR 空结果时有明确反馈
9. 保存 / 复制 / OCR / Pin / 长截图链路不受影响
```

- [ ] **步骤 2：执行最终构建验证**

运行：`./scripts/build.sh`

预期：`** BUILD SUCCEEDED **`

- [ ] **步骤 3：人工验证通过后更新 Sprint 状态**

在 `docs/SPRINTS/Sprint-29.md` 中改为：

```md
## Status

Completed
```

只有在人工验证通过后，
才更新 `TASK.md` 进入下一 Sprint 状态。

- [ ] **步骤 4：补充 DEVLOG 记录**

增加一条简洁总结：

```md
- Sprint 29 完成最小 AI 分析闭环：
  - 编辑工具栏新增 `AI`
  - 基于 OCR 文本执行开发报错分析
  - 结果面板支持复制、重试、关闭
  - 缺少配置与失败场景有明确反馈
```

---

## 自检

### Spec 覆盖检查

- `AI` 工具栏入口：由任务 4 覆盖
- 仅使用 `OCR` 文本输入：由任务 6 覆盖
- 轻量加载 / 成功 / 失败面板：由任务 3 和任务 6 覆盖
- 隐藏本地配置：由任务 1 和任务 7 覆盖
- 明确错误反馈：由任务 2 和任务 6 覆盖
- 现有主链路不受影响：由任务 6 和任务 8 覆盖

### 占位内容检查

- 无 `TODO` / `TBD`
- 所有文件路径明确
- 所有命令明确

### 类型一致性检查

- `analyzePendingCapture(...)` 是新的公开流程入口
- `AIAnalysisService` 输出纯文本 `String`
- `AIAnalysisPreviewWindowService` 只负责展示状态，不负责业务编排

---

计划已完成，保存路径：

`docs/superpowers/plans/2026-06-18-sprint-29-ai-analysis.md`

后续执行方式有两种：

1. `子 Agent 执行（推荐）`
   每个任务交给独立子 Agent 执行，中间穿插评审，推进更快。

2. `当前会话直接执行`
   在当前会话里按计划逐项执行。
