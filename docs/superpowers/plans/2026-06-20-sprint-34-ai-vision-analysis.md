# Sprint 34 AI Vision Analysis Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `Settings` 中增加 `AI 使用视觉取字` 开关，让普通截图与长截图中的 `AI` 分析可以在“本地 OCR 链路”和“AI 视觉取字链路”之间切换，同时保持 `OCR` 功能与当前 `AI` 结果窗结构不变。

**Architecture:** 保留现有 `AIAnalysisService` 专注做文本分析，新建 `AIImageTextExtractionService` 负责图片到文本的视觉 AI 提取。`CaptureSessionService` 继续作为编排层，根据 `Settings` 开关解析当前输入策略，在普通截图与长截图的 `AI` 流程中切换“本地 OCR”或“视觉 AI 取字”，两条链路最终统一汇聚到现有 `AIAnalysisService` 与 `AIAnalysisPreviewWindowService`。

**Tech Stack:** Swift 6, SwiftUI, AppKit, Foundation, UserDefaults / AppStorage, Vision, OpenAI Responses API

---

## File Structure

- Modify: `TYScreenShotTool/Shared/AppSettings.swift`
  - 增加 `AI 使用视觉取字` 开关的持久化 key 与默认值
- Modify: `TYScreenShotTool/App/SettingsView.swift`
  - 增加 `AI 分析配置` 小节与开关 UI
  - 保持现有热键录制与保存目录配置行为不变
- Create: `TYScreenShotTool/Services/AIImageTextExtractionService.swift`
  - 负责 `CGImage -> data URL -> OpenAI vision request -> extracted text`
  - 定义视觉取字错误类型
- Modify: `TYScreenShotTool/Services/AIAnalysisService.swift`
  - 只在必要时补充公共请求配置辅助和文案适配
  - 保持文本分析职责不变
- Modify: `TYScreenShotTool/Services/CaptureSessionService.swift`
  - 读取 AI 输入策略
  - 普通截图与长截图的 `AI` 流程切换输入链路
  - 新增统一的 AI 文本提取编排与错误处理
  - 保留长截图现有异步失效保护
- Modify: `TYScreenShotTool/App/TYScreenShotToolApp.swift`
  - 注入 `AIImageTextExtractionService`
- Modify: `TASK.md`
  - 实现完成后同步 Sprint 34 当前任务状态
- Modify: `docs/ROADMAP.md`
  - 实现完成后同步 Sprint 34 状态
- Modify: `docs/SPRINTS/Sprint-34.md`
  - 实现完成后补充结果与验证
- Modify: `docs/DEVLOG.md`
  - 实现完成后记录 Sprint 34 的实现和验证结果

说明：

- 当前项目没有独立 test target，本轮验证以 `./scripts/build.sh` 与人工交互验证为主。
- 当前 `AI` 配置沿用 `AppSettings.aiAnalysisAPIKeyKey / aiAnalysisBaseURLKey / aiAnalysisModelKey`，本轮不增加第二套视觉模型设置项。
- 本轮不实现 “AI 多方向菜单”，只记录为后续需求。

---

### Task 1: 确认 Sprint 34 planned 文档已对齐

**Files:**
- Read: `TASK.md`
- Read: `docs/ROADMAP.md`
- Read: `docs/SPRINTS/Sprint-34.md`

- [ ] **Step 1: 确认 TASK.md 已切换到 Sprint 34 planned**

Read `TASK.md` and confirm it already contains:

```md
Current Sprint: Sprint 34 Planned

## 当前状态

Sprint 33 已完成实现、构建验证与人工验证。
Sprint 34 已完成设计文档，准备进入实现计划阶段。

## 当前目标

在 `Settings` 页面中增加 `AI 使用视觉取字` 开关，
让 `AI` 分析可以在“本地 OCR 链路”和“AI 视觉取字链路”之间切换，
并同时覆盖普通截图与长截图模式。
```

Expected: `TASK.md` 已表达 Sprint 34 planned，不需要再次修改。

- [ ] **Step 2: 确认 ROADMAP 已存在 Sprint 34 planned 段落**

Read `docs/ROADMAP.md` and confirm it already contains:

```md
### Sprint 34

AI 视觉取字分析

状态：
🚧 Planned

目标：

- 在 `Settings` 中增加 `AI 使用视觉取字` 开关，默认关闭
- 开关关闭时保留当前 `本地 OCR -> AI 文本分析` 链路
- 开关打开时切换为 `AI 视觉取字 -> AI 文本分析` 链路
- 同时覆盖普通截图与长截图中的 `AI` 分析入口
- 保持 `OCR` 按钮、`OCR` 结果预览与当前 `AI` 结果窗结构不变
- 将 `AI` 多方向菜单仅记录为后续需求，不进入本轮实现
```

Expected: `ROADMAP` 已表达 Sprint 34 planned，不需要再次修改。

- [ ] **Step 3: 确认 Sprint-34.md 已创建且内容对齐 spec**

Read `docs/SPRINTS/Sprint-34.md` and confirm it already contains:

```md
# Sprint 34 - AI 视觉取字分析

## Status

Planned

## Goal

在现有截图编辑体验中，
为 `AI` 分析增加一个可切换的新输入链路，
让用户能够在 `Settings` 中决定：

- 继续使用 `本地 OCR -> AI 文本分析`
- 或切换到 `AI 视觉取字 -> AI 文本分析`

本轮必须同时覆盖：

- 普通截图编辑模式
- 长截图模式

同时保持：

- `OCR` 按钮与 `OCR` 结果预览窗口不变
- 当前 `AI` 结果窗结构不变

---

## Scope

### Included

- 在 `Settings` 页面中新增 `AI 使用视觉取字` 开关
- 开关默认关闭，保持当前老链路不变
- 开关关闭时，普通截图与长截图中的 `AI` 继续走本地 OCR 链路
- 开关打开时，普通截图与长截图中的 `AI` 切换为视觉 AI 取字链路
- 新增 `AIImageTextExtractionService` 负责基于截图图片调用视觉模型提取文字
- 保持现有 `AIAnalysisService` 继续专注于文本分析
- 保持长截图现有的结果窗摆放、单窗互斥与异步失效保护

### Out of Scope

- `OCR` 按钮与 `OCR` 结果预览窗口改造
- `AI` 多方向菜单实现
- 摘要、翻译、待办提取、表格转 CSV、UI / 代码识别等新 AI 能力
- 新链路失败时自动回退旧链路
- 为视觉模型与文本模型分别增加设置项

---

## Implementation

### 方向

优先采用双链路可切换实现：

1. `SettingsView` 增加 `AI 使用视觉取字` 开关
2. `CaptureSessionService` 统一读取当前 AI 输入策略
3. 保留本地 `ocrService` 作为老链路输入来源
4. 新增 `AIImageTextExtractionService` 作为新链路输入来源
5. 两条链路最终都汇聚到现有 `AIAnalysisService`

### 约束

- 遵循 MVP
- 遵循 KISS
- 遵循 YAGNI
- 不重做现有 `AI` 结果窗口结构
- 不影响保存、复制、`OCR`、`Pin`、长截图主链路
- 默认关闭新链路，保证升级后现有用户行为不变

---

## Validation

### 场景 1

进入 `Settings` 页面后，
可看到新增的 `AI 使用视觉取字` 开关，
且默认值为关闭。

### 场景 2

开关关闭时，
普通截图点击 `AI` 后，
行为与当前版本保持一致。

### 场景 3

开关关闭时，
长截图点击 `AI` 后，
行为与当前版本保持一致。

### 场景 4

开关打开时，
普通截图点击 `AI` 后，
能够通过视觉模型提取文字并继续输出当前结构结果。

### 场景 5

开关打开时，
长截图点击 `AI` 后，
能够通过视觉模型提取文字并继续输出当前结构结果。

### 场景 6

开关关闭时，
若本地 OCR 未识别到有效文字，
仍提示 `OCR 未识别到有效文本`。

### 场景 7

开关打开时，
若视觉取字失败，
提示 `AI 识别失败`，
并支持重试。

### 场景 8

开关打开时，
若视觉取字成功但没有有效文字，
只提示 `AI 未识别到有效文字`，
不打开结果窗。

### 场景 9

两条链路中任一条文本分析失败时，
提示 `AI 分析失败`，
并支持重试。

### 场景 10

长截图继续滚动后，
旧 AI 请求不会晚到覆盖新状态。

---

## Result

Pending
```

Expected: `Sprint-34.md` 已创建且与 spec 对齐，不需要再次修改。

- [ ] **Step 4: 不为 planned 文档重复创建提交**

Do not run a commit here.

Expected: 计划执行从代码实现开始，避免重复编辑和重复提交 planned 文档。

---

### Task 2: 增加 AI 输入策略与 Settings 开关配置

**Files:**
- Modify: `TYScreenShotTool/Shared/AppSettings.swift`
- Modify: `TYScreenShotTool/App/SettingsView.swift`

- [ ] **Step 1: 在 AppSettings 中增加 AI 视觉取字配置项**

Update `TYScreenShotTool/Shared/AppSettings.swift`:

```swift
enum AppSettings {
    static let screenshotHotKeyKey = "settings.screenshotHotKey"
    static let screenshotHotKeyDefaultValue = ScreenshotHotKey.screenshot.storageValue
    static let saveDirectoryPathKey = "settings.saveDirectoryPath"
    static let saveDirectoryBookmarkDataKey = "settings.saveDirectoryBookmarkData"
    static let aiUseVisionTextExtractionKey = "settings.aiUseVisionTextExtraction"
    static let aiUseVisionTextExtractionDefaultValue = false
    static let aiAnalysisAPIKeyKey = "local.aiAnalysis.openAIAPIKey"
    static let aiAnalysisBaseURLKey = "local.aiAnalysis.baseURL"
    static let aiAnalysisModelKey = "local.aiAnalysis.model"
    static let aiAnalysisBaseURLDefaultValue = "https://api.openai.com"
    static let aiAnalysisModelDefaultValue = "gpt-5.4-mini"
}
```

Expected: 开关持久化 key 与默认值有统一定义。

- [ ] **Step 2: 在 SettingsView 中增加开关状态绑定**

Add to `TYScreenShotTool/App/SettingsView.swift`:

```swift
@AppStorage(AppSettings.aiUseVisionTextExtractionKey)
private var aiUseVisionTextExtraction = AppSettings.aiUseVisionTextExtractionDefaultValue
```

Expected: Settings 页面可以直接读写开关状态。

- [ ] **Step 3: 增加 AI 配置小节视图**

Append in `SettingsView.swift`:

```swift
private var aiAnalysisSettings: some View {
    VStack(alignment: .leading, spacing: 6) {
        Text("AI 分析配置")
            .font(.headline)

        Toggle("AI 使用视觉取字", isOn: $aiUseVisionTextExtraction)

        Text("关闭时使用本地 OCR，开启时使用 AI 先识别截图文字再分析。")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
```

Expected: Settings 有独立的 AI 配置块，不与热键或保存目录逻辑混在一起。

- [ ] **Step 4: 将 AI 配置块插入现有 Settings 布局**

Update `body` in `SettingsView.swift`:

```swift
VStack(alignment: .leading, spacing: 12) {
    hotKeyPicker
    aiAnalysisSettings
    saveDirectoryPicker
}
```

And update the description text to:

```swift
Text("当前版本提供截图快捷键、AI 分析链路与保存目录配置。")
```

Expected: 页面文案和新开关一致。

- [ ] **Step 5: 运行构建，确认 Settings 层改动可独立编译**

Run: `./scripts/build.sh`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: 提交这一任务**

```bash
git add TYScreenShotTool/Shared/AppSettings.swift TYScreenShotTool/App/SettingsView.swift
git commit -m "feat(sprint-34): 增加 AI 视觉取字开关"
```

Expected: 配置与 UI 层独立成一个小提交。

---

### Task 3: 新增 AIImageTextExtractionService

**Files:**
- Create: `TYScreenShotTool/Services/AIImageTextExtractionService.swift`

- [ ] **Step 1: 新建服务骨架与最小结果、错误类型**

Create `TYScreenShotTool/Services/AIImageTextExtractionService.swift`:

```swift
import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct AIExtractedTextResult {
    let text: String
    let rawText: String
}

enum AIImageTextExtractionError: LocalizedError {
    case missingAPIKey
    case imageEncodingFailed
    case invalidResponse
    case emptyOutput
    case noUsefulText
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API Key 未配置。"
        case .imageEncodingFailed:
            return "截图编码失败。"
        case .invalidResponse:
            return "AI 识别返回格式无效。"
        case .emptyOutput:
            return "AI 识别返回内容为空。"
        case .noUsefulText:
            return "AI 未识别到有效文字。"
        case let .requestFailed(reason):
            return "AI 识别请求失败：\(reason)"
        }
    }
}

final class AIImageTextExtractionService {
    private let session: URLSession
    private let userDefaults: UserDefaults

    init(
        session: URLSession = .shared,
        userDefaults: UserDefaults = .standard
    ) {
        self.session = session
        self.userDefaults = userDefaults
    }
}
```

Expected: 图片识别服务有清晰的职责边界，不和文本分析混在一起。

- [ ] **Step 2: 增加公开入口和最小清洗逻辑**

Append to the same file:

```swift
extension AIImageTextExtractionService {
    func extractText(from image: CGImage) async throws -> AIExtractedTextResult {
        let apiKey = try resolvedAPIKey()
        let dataURL = try makeImageDataURL(from: image)
        let request = try makeRequest(apiKey: apiKey, imageDataURL: dataURL)

        do {
            let (data, response) = try await session.data(for: request)
            try validateHTTPResponse(response, data: data)
            return try parseExtractionResult(from: data)
        } catch let error as AIImageTextExtractionError {
            throw error
        } catch let error as DecodingError {
            throw AIImageTextExtractionError.requestFailed("响应解析失败：\(error.localizedDescription)")
        } catch {
            throw AIImageTextExtractionError.requestFailed(error.localizedDescription)
        }
    }

    private func normalizeExtractedText(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let filteredLines = normalized
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        return filteredLines.joined(separator: "\n")
    }
}
```

Expected: 视觉取字入口可以返回结构化结果，并和现有文本分析前的清洗风格一致。

- [ ] **Step 3: 实现 API Key、Base URL、Model 读取，沿用现有 AI 配置**

Append:

```swift
private extension AIImageTextExtractionService {
    func resolvedAPIKey() throws -> String {
        let key = userDefaults.string(forKey: AppSettings.aiAnalysisAPIKeyKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard key.isEmpty == false else {
            throw AIImageTextExtractionError.missingAPIKey
        }

        return key
    }

    func resolvedModel() -> String {
        let configured = userDefaults.string(forKey: AppSettings.aiAnalysisModelKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let configured, configured.isEmpty == false else {
            return AppSettings.aiAnalysisModelDefaultValue
        }

        return configured
    }

    func resolvedBaseURL() throws -> URL {
        let configured = userDefaults.string(forKey: AppSettings.aiAnalysisBaseURLKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let rawValue = (configured?.isEmpty == false)
            ? configured!
            : AppSettings.aiAnalysisBaseURLDefaultValue

        guard var components = URLComponents(string: rawValue),
              components.scheme?.isEmpty == false,
              components.host?.isEmpty == false else {
            throw AIImageTextExtractionError.requestFailed("AI Base URL 无效。")
        }

        var path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.isEmpty {
            path = "v1"
        }
        components.path = "/" + path + "/responses"

        guard let url = components.url else {
            throw AIImageTextExtractionError.requestFailed("AI Base URL 无效。")
        }

        return url
    }
}
```

Expected: 视觉取字链路不增加第二套本地配置。

- [ ] **Step 4: 先核对 OpenAI 当前视觉输入格式，再实现图片编码与请求体**

Before writing request body code, verify against current official OpenAI documentation for Responses API image input format.

Check:

- whether `input_image` accepts `image_url` as a plain string or nested object
- whether `input_text` and `input_image` must be in a `content` array under one `role`
- whether data URL is acceptable for inline PNG input

Expected: 请求体结构先与当前官方格式核对一致，再进入实现，避免首轮请求因编码结构错误失败。

- [ ] **Step 5: 基于已核对格式，实现图片编码与请求体构建**

Append:

```swift
private extension AIImageTextExtractionService {
    func makeImageDataURL(from image: CGImage) throws -> String {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw AIImageTextExtractionError.imageEncodingFailed
        }

        CGImageDestinationAddImage(destination, image, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw AIImageTextExtractionError.imageEncodingFailed
        }

        let encoded = (mutableData as Data).base64EncodedString()
        return "data:image/png;base64,\(encoded)"
    }

    func buildExtractionPrompt() -> String {
        """
        你负责从截图中尽量忠实提取可见文字。
        要求：
        - 只输出截图中的文字内容
        - 不要解释、不要总结、不要补充前言
        - 不要输出 Markdown 代码块
        - 保持关键信息原始顺序
        - 如果没有可识别的有效文字，返回空字符串
        """
    }

    func makeRequest(apiKey: String, imageDataURL: String) throws -> URLRequest {
        let url = try resolvedBaseURL()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body = VisionResponseRequestBody(
            model: resolvedModel(),
            instructions: "你负责从截图图片中提取文字。",
            input: [
                .init(
                    role: "user",
                    content: [
                        .init(type: "input_text", text: buildExtractionPrompt(), imageURL: nil),
                        .init(type: "input_image", text: nil, imageURL: imageDataURL)
                    ]
                )
            ],
            store: false
        )
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }
}
```

Expected: 请求体明确使用视觉输入，不再依赖系统 OCR，且字段结构与当前官方格式一致。

- [ ] **Step 6: 增加响应解析与无有效文字判断**

Append:

```swift
private extension AIImageTextExtractionService {
    func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIImageTextExtractionError.invalidResponse
        }

        guard 200 ..< 300 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? "未知服务端错误。"
            throw AIImageTextExtractionError.requestFailed(message)
        }
    }

    func parseExtractionResult(from data: Data) throws -> AIExtractedTextResult {
        let envelope = try JSONDecoder().decode(VisionResponseEnvelope.self, from: data)

        let rawText = envelope.output
            .filter { $0.type == "message" }
            .flatMap { $0.content ?? [] }
            .filter { $0.type == "output_text" }
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard rawText.isEmpty == false else {
            throw AIImageTextExtractionError.emptyOutput
        }

        let normalized = normalizeExtractedText(rawText)
        guard normalized.isEmpty == false else {
            throw AIImageTextExtractionError.noUsefulText
        }

        return AIExtractedTextResult(text: normalized, rawText: rawText)
    }
}
```

Expected: “响应为空”与“有响应但没有有效文字”被区分开。

- [ ] **Step 7: 定义最小请求/响应模型**

Append:

```swift
private extension AIImageTextExtractionService {
    struct VisionResponseRequestBody: Encodable {
        let model: String
        let instructions: String
        let input: [VisionInputItem]
        let store: Bool
    }

    struct VisionInputItem: Encodable {
        let role: String
        let content: [VisionInputContent]
    }

    struct VisionInputContent: Encodable {
        let type: String
        let text: String?
        let imageURL: String?

        enum CodingKeys: String, CodingKey {
            case type
            case text
            case imageURL = "image_url"
        }
    }

    struct VisionResponseEnvelope: Decodable {
        let output: [VisionOutputItem]
    }

    struct VisionOutputItem: Decodable {
        let type: String
        let content: [VisionOutputContent]?
    }

    struct VisionOutputContent: Decodable {
        let type: String
        let text: String?
    }
}
```

Expected: 新服务具备独立的最小视觉请求/响应模型。

- [ ] **Step 8: 运行构建，确认新服务可独立编译**

Run: `./scripts/build.sh`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 9: 提交这一任务**

```bash
git add TYScreenShotTool/Services/AIImageTextExtractionService.swift
git commit -m "feat(sprint-34): 增加 AI 视觉取字服务"
```

Expected: 新服务独立成一个小提交。

---

### Task 4: 将新服务注入应用并在 session 中增加输入策略

**Files:**
- Modify: `TYScreenShotTool/App/TYScreenShotToolApp.swift`
- Modify: `TYScreenShotTool/Services/CaptureSessionService.swift`

- [ ] **Step 1: 在 CaptureSessionService 中新增依赖与输入策略枚举**

Update `TYScreenShotTool/Services/CaptureSessionService.swift` near properties:

```swift
private let aiImageTextExtractionService: AIImageTextExtractionService

private enum AITextInputStrategy {
    case localOCR
    case visionAI
}
```

And in initializer signature:

```swift
init(
    overlayService: CaptureOverlayService,
    screenCaptureService: ScreenCaptureService,
    clipboardService: ClipboardService,
    imageSaveService: ImageSaveService,
    ocrService: OCRService,
    aiImageTextExtractionService: AIImageTextExtractionService,
    aiAnalysisService: AIAnalysisService,
    ...
) {
    self.aiImageTextExtractionService = aiImageTextExtractionService
    ...
}
```

Expected: session service 已知晓新依赖。

- [ ] **Step 2: 在 app 入口实例化并注入新服务**

Update `TYScreenShotTool/App/TYScreenShotToolApp.swift`:

```swift
let aiImageTextExtractionService = AIImageTextExtractionService()
let aiAnalysisService = AIAnalysisService()
```

And pass it into `CaptureSessionService`:

```swift
aiImageTextExtractionService: aiImageTextExtractionService,
aiAnalysisService: aiAnalysisService,
```

Expected: 应用依赖注入完整，后续不需要在 session 内自行 new service。

- [ ] **Step 3: 在 session 内增加当前策略解析函数**

Append to `CaptureSessionService.swift`:

```swift
private func currentAITextInputStrategy() -> AITextInputStrategy {
    let useVision = UserDefaults.standard.bool(forKey: AppSettings.aiUseVisionTextExtractionKey)
    return useVision ? .visionAI : .localOCR
}
```

Expected: 普通截图与长截图可以共享同一个策略解析入口。

- [ ] **Step 4: 运行构建，确认注入层改动可独立编译**

Run: `./scripts/build.sh`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 提交这一任务**

```bash
git add TYScreenShotTool/App/TYScreenShotToolApp.swift TYScreenShotTool/Services/CaptureSessionService.swift
git commit -m "feat(sprint-34): 注入 AI 视觉取字依赖"
```

Expected: 依赖注入与策略入口独立成一个小提交。

---

### Task 5: 改造普通截图 AI 链路

**Files:**
- Modify: `TYScreenShotTool/Services/CaptureSessionService.swift`
- Modify: `TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift`

- [ ] **Step 1: 抽出统一的图片取字函数，按策略返回文本**

Append to `CaptureSessionService.swift`:

```swift
private func resolveAIText(
    from image: CGImage,
    strategy: AITextInputStrategy
) async throws -> String {
    switch strategy {
    case .localOCR:
        return try ocrService.recognizeText(in: image)
    case .visionAI:
        let extracted = try await aiImageTextExtractionService.extractText(from: image)
        return extracted.text
    }
}
```

Expected: 普通截图与长截图都能共享这一层取字逻辑。

- [ ] **Step 2: 增加普通截图 AI 的视觉取字专用错误处理**

Append helper:

```swift
@MainActor
private func handleVisionAIExtractionError(
    _ error: AIImageTextExtractionError,
    selectionRect: CGRect,
    onRetry: @escaping () -> Void
) {
    switch error {
    case .noUsefulText:
        toastService.showToast(message: "AI 未识别到有效文字")
        aiAnalysisPreviewWindowService.dismiss()
    case .missingAPIKey, .imageEncodingFailed, .invalidResponse, .emptyOutput, .requestFailed:
        toastService.showToast(message: "AI 识别失败")
        aiAnalysisPreviewWindowService.presentError(
            title: "AI 识别失败",
            message: error.localizedDescription,
            selectionRect: selectionRect,
            onRetry: onRetry,
            onClose: { [weak self] in
                self?.aiAnalysisPreviewWindowService.dismiss()
            }
        )
    }
}
```

Expected: “AI 未识别到有效文字”与“AI 识别失败”被明确区分。

- [ ] **Step 3: 调整普通截图 performAIAnalysis，按策略走不同取字来源**

Replace `performAIAnalysis(for:)` core body with:

```swift
@MainActor
private func performAIAnalysis(for source: PendingCaptureSource) async {
    let selectionRect = source.selectionRect
    let strategy = currentAITextInputStrategy()

    defer {
        isAIAnalysisInProgress = false
        overlayService.setAIButtonEnabled(true)
    }

    do {
        let image = try await captureImageForPendingSource(source)
        let text = try await resolveAIText(from: image, strategy: strategy)
        let result = try await aiAnalysisService.analyzeDeveloperError(text: text)

        aiAnalysisPreviewWindowService.presentResult(
            result: result,
            selectionRect: selectionRect,
            onCopyAll: { [weak self] in
                self?.copyAIAnalysisResult(result.formattedText)
            },
            onCopyNextSteps: { [weak self] in
                self?.copyAIAnalysisNextSteps(result.nextSteps)
            },
            onRetry: { [weak self] in
                self?.retryAIAnalysis()
            },
            onClose: { [weak self] in
                self?.aiAnalysisPreviewWindowService.dismiss()
            }
        )
    } catch let error as OCRError {
        toastService.showToast(message: "OCR 未识别到有效文本")
        aiAnalysisPreviewWindowService.presentError(
            title: "AI 分析失败",
            message: error.localizedDescription,
            selectionRect: selectionRect,
            onRetry: { [weak self] in
                self?.retryAIAnalysis()
            },
            onClose: { [weak self] in
                self?.aiAnalysisPreviewWindowService.dismiss()
            }
        )
    } catch let error as AIImageTextExtractionError {
        handleVisionAIExtractionError(
            error,
            selectionRect: selectionRect,
            onRetry: { [weak self] in
                self?.retryAIAnalysis()
            }
        )
    } catch let error as AIAnalysisError {
        toastService.showToast(message: "AI 分析失败")
        aiAnalysisPreviewWindowService.presentError(
            title: "AI 分析失败",
            message: error.localizedDescription,
            selectionRect: selectionRect,
            onRetry: { [weak self] in
                self?.retryAIAnalysis()
            },
            onClose: { [weak self] in
                self?.aiAnalysisPreviewWindowService.dismiss()
            }
        )
    } catch {
        toastService.showToast(message: "AI 分析失败")
        aiAnalysisPreviewWindowService.presentError(
            title: "AI 分析失败",
            message: error.localizedDescription,
            selectionRect: selectionRect,
            onRetry: { [weak self] in
                self?.retryAIAnalysis()
            },
            onClose: { [weak self] in
                self?.aiAnalysisPreviewWindowService.dismiss()
            }
        )
    }
}
```

Expected: 普通截图 AI 已能按开关切换取字链路。

- [ ] **Step 4: 让 AI 错误窗支持可传入标题，区分“AI 识别失败”和“AI 分析失败”**

Update `TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift` signature:

```swift
func presentError(
    title: String = "AI 分析失败",
    message: String,
    selectionRect: CGRect,
    preferredSide: PreviewPlacementSide? = nil,
    onRetry: @escaping () -> Void,
    onClose: @escaping () -> Void
) {
    statusLabel.stringValue = title
    ...
}
```

Expected: 普通截图新链路可以显示 “AI 识别失败”。

- [ ] **Step 5: 明确 noUsefulText 的结束状态，不弹错误窗但完整结束本轮分析**

When handling `AIImageTextExtractionError.noUsefulText`, verify the flow now does all of the following:

- shows `toastService.showToast(message: "AI 未识别到有效文字")`
- dismisses the existing loading panel
- does not call `presentError(...)`
- allows the `defer` in `performAIAnalysis(for:)` to restore button enabled state and clear in-progress status

Expected: 无文字场景完整结束当前 AI 流程，用户不会看到残留 loading 窗，也不会被误导为系统错误。

- [ ] **Step 6: 运行构建，确认普通截图 AI 改造可独立编译**

Run: `./scripts/build.sh`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: 人工验证普通截图两条链路**

Manual:

1. 打开 `Settings`，确认 `AI 使用视觉取字` 默认关闭
2. 截图一段明确文字，点击 `AI`
3. 确认关闭状态下仍能得到当前结构结果
4. 打开 `AI 使用视觉取字`
5. 再次截图明确文字，点击 `AI`
6. 确认打开状态下也能得到当前结构结果
7. 截取一块几乎没有文字的区域，点击 `AI`

Expected:

- 默认关闭时行为与旧版本一致
- 打开后新链路可出结果
- 无文字时提示 `AI 未识别到有效文字`，不保留结果窗，也不残留 loading 窗

- [ ] **Step 8: 提交这一任务**

```bash
git add TYScreenShotTool/Services/CaptureSessionService.swift TYScreenShotTool/Services/AIAnalysisPreviewWindowService.swift
git commit -m "feat(sprint-34): 支持普通截图 AI 视觉取字"
```

Expected: 普通截图 AI 改造独立成一个小提交。

---

### Task 6: 改造长截图 AI 链路并保留异步失效保护

**Files:**
- Modify: `TYScreenShotTool/Services/CaptureSessionService.swift`

- [ ] **Step 1: 删除长截图 AI 专用的本地 OCR 包装函数**

Remove from `CaptureSessionService.swift`:

```swift
private func recognizeScrollingAIText(in image: CGImage) async throws -> String
```

Expected: 长截图 AI 将改为和普通截图共享 `resolveAIText`。

- [ ] **Step 2: 在长截图 AI 分析函数内引入当前策略**

At the start of `performScrollingAIAnalysis(...)`, add:

```swift
let strategy = currentAITextInputStrategy()
```

Expected: 长截图 AI 和普通截图使用同一个策略来源。

- [ ] **Step 3: 将长截图取字逻辑改为复用 resolveAIText**

Replace:

```swift
let text = try await recognizeScrollingAIText(in: image)
```

with:

```swift
let text = try await resolveAIText(from: image, strategy: strategy)
```

Expected: 长截图 AI 已按开关切换取字链路。

- [ ] **Step 4: 为长截图新增视觉取字错误处理分支，但保留现有 requestID / revision 守卫**

Insert before `catch let error as AIAnalysisError`:

```swift
} catch let error as AIImageTextExtractionError {
    await MainActor.run {
        guard shouldAcceptScrollingAIResult(
            requestID: requestID,
            resultRevision: resultRevision
        ) else {
            return
        }

        switch error {
        case .noUsefulText:
            toastService.showToast(message: "AI 未识别到有效文字")
            aiAnalysisPreviewWindowService.dismiss()
        case .missingAPIKey, .imageEncodingFailed, .invalidResponse, .emptyOutput, .requestFailed:
            toastService.showToast(message: "AI 识别失败")
            aiAnalysisPreviewWindowService.presentError(
                title: "AI 识别失败",
                message: error.localizedDescription,
                selectionRect: selectionRect,
                preferredSide: preferredSide,
                onRetry: { [weak self] in
                    self?.retryScrollingAIAnalysis()
                },
                onClose: { [weak self] in
                    self?.aiAnalysisPreviewWindowService.dismiss()
                }
            )
        }
    }
```

Expected: 长截图新链路错误语义与普通截图一致，同时不破坏过期结果保护。

- [ ] **Step 5: 保持重试继续走当前策略，不增加自动回退**

Confirm `retryScrollingAIAnalysis()` still calls:

```swift
analyzeScrollingCaptureResult()
```

Expected: 重试仍由当前开关决定链路，不引入额外状态。

- [ ] **Step 6: 运行构建，确认长截图 AI 改造可独立编译**

Run: `./scripts/build.sh`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: 人工验证长截图两条链路和旧请求失效保护**

Manual:

1. 关闭 `AI 使用视觉取字`
2. 进入长截图模式并生成当前长图
3. 点击 `AI`，确认行为与当前版本一致
4. 打开 `AI 使用视觉取字`
5. 再次进入长截图模式并点击 `AI`
6. 在 AI 分析过程中继续滚动追加或重新触发新一轮 AI

Expected:

- 开关关闭时行为与旧版本一致
- 开关打开时可通过视觉取字得到结果
- 旧 AI 结果不会晚到覆盖新的长截图状态

- [ ] **Step 8: 提交这一任务**

```bash
git add TYScreenShotTool/Services/CaptureSessionService.swift
git commit -m "feat(sprint-34): 支持长截图 AI 视觉取字"
```

Expected: 长截图 AI 改造独立成一个小提交。

---

### Task 7: 收尾验证与 Sprint 34 文档更新

**Files:**
- Modify: `TASK.md`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/SPRINTS/Sprint-34.md`
- Modify: `docs/DEVLOG.md`

- [ ] **Step 1: 运行最终构建验证**

Run: `./scripts/build.sh`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: 完成完整人工验证清单**

Manual:

1. 默认关闭时，普通截图 `AI` 结果正常
2. 默认关闭时，长截图 `AI` 结果正常
3. 打开开关后，普通截图 `AI` 结果正常
4. 打开开关后，长截图 `AI` 结果正常
5. 关闭开关时，本地 OCR 无文字仍提示 `OCR 未识别到有效文本`
6. 打开开关时，无文字只提示 `AI 未识别到有效文字`
7. 打开开关时，视觉取字请求异常能提示 `AI 识别失败`
8. 两条链路的分析失败都提示 `AI 分析失败`
9. `OCR`、复制、保存、`Pin`、热键设置、保存目录设置不回归

Expected: Sprint 34 验收项全部人工通过。

- [ ] **Step 3: 将 TASK.md 更新为 Sprint 34 完成态**

Update `TASK.md`:

```md
Current Sprint: Sprint 34 Done

## 当前状态

Sprint 34 已完成实现、构建验证与人工验证。
```

And replace acceptance section with actual results covering:

- `AI 使用视觉取字` 开关已上线，默认关闭
- 关闭时保留本地 OCR 链路
- 打开时切换为视觉取字链路
- 普通截图与长截图均已接入
- 构建通过与人工验证通过

Expected: `TASK.md` 只表达 Sprint 34 已完成状态。

- [ ] **Step 4: 更新 Sprint-34.md 的结果与验证**

Replace `Status` and `Result` in `docs/SPRINTS/Sprint-34.md`:

```md
## Status

Done
```

And add result bullets covering:

- Settings 新增开关
- 普通截图与长截图双链路接入
- `OCR` 按钮保持不变
- 新旧链路错误语义区分
- 最终构建与人工验证通过

Expected: Sprint 文档完整记录实现与验证。

- [ ] **Step 5: 将 ROADMAP 中 Sprint 34 从 planned 改为 done**

Replace Sprint 34 section in `docs/ROADMAP.md` with `✅ Done` and concrete成果:

```md
状态：
✅ Done

成果：

- 在 `Settings` 中增加 `AI 使用视觉取字` 开关，默认关闭
- 开关关闭时保留当前 `本地 OCR -> AI 文本分析` 链路
- 开关打开时切换为 `AI 视觉取字 -> AI 文本分析` 链路
- 普通截图与长截图中的 `AI` 分析入口都已接入双链路切换
- `OCR` 按钮、`OCR` 结果预览与当前 `AI` 结果窗结构保持不变
- “AI 多方向菜单”已记录为后续需求，未进入本轮实现
```

Expected: `ROADMAP` 和实际完成状态一致。

- [ ] **Step 6: 在 DEVLOG 记录 Sprint 34 完成条目**

Add a `2026-06-20` Sprint 34 entry to `docs/DEVLOG.md` covering:

- 主题：AI 视觉取字分析
- 实现：双链路开关、视觉取字服务、普通截图 / 长截图接入
- Bug / decision：不做自动回退，区分 `AI 识别失败` / `AI 未识别到有效文字` / `AI 分析失败`
- 验证：构建通过、人工验证通过

Expected: `DEVLOG` 记录本轮有意义的架构与产品决策。

- [ ] **Step 7: 提交 Sprint 34 收尾文档**

```bash
git add TASK.md docs/ROADMAP.md docs/SPRINTS/Sprint-34.md docs/DEVLOG.md
git commit -m "docs(sprint-34): 同步 AI 视觉取字结果"
```

Expected: Sprint 34 收尾文档独立成一个小提交。

---

## Self-Review

- Spec coverage:
  - `Settings` 开关与默认关闭：Task 2
  - 新建视觉取字服务：Task 3
  - app 依赖注入与策略入口：Task 4
  - 普通截图 AI 双链路：Task 5
  - 长截图 AI 双链路与失效保护：Task 6
  - Sprint 34 文档收尾：Task 7
- Placeholder scan:
  - 无 `TODO` / `TBD`
  - 每个代码步骤都给了具体代码或替换内容
- Type consistency:
  - 开关 key 统一使用 `AppSettings.aiUseVisionTextExtractionKey`
  - 新服务统一命名为 `AIImageTextExtractionService`
  - 策略统一命名为 `AITextInputStrategy`
  - 新错误类型统一命名为 `AIImageTextExtractionError`
