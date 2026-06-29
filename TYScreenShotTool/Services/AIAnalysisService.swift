//
//  AIAnalysisService.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/18.
//

import Foundation

/// AI 分析结果分段
struct AIAnalysisSection {
    /// 分段标题
    let title: String
    /// 分段内容
    let content: String
}

/// AI 分析结果
struct AIAnalysisResult {
    /// 分析模式
    let mode: AIAnalysisMode
    /// 状态标题
    let statusTitle: String
    /// 分析分段
    let sections: [AIAnalysisSection]
    /// 原始文本
    let rawText: String
    /// 备用复制文本
    let secondaryCopyText: String

    /// 摘要内容（第一个分段）
    var summary: String {
        sections[safe: 0]?.content ?? ""
    }

    var possibleCauses: String {
        sections[safe: 1]?.content ?? ""
    }

    var nextSteps: String {
        sections[safe: 2]?.content ?? ""
    }

    var formattedText: String {
        sections
            .flatMap { [$0.title + "：", $0.content, ""] }
            .dropLast()
            .joined(separator: "\n")
    }
}

/// AI 分析服务
///
/// 提供开发报错分析、内容摘要、翻译和界面结构识别功能。
final class AIAnalysisService {
    private let session: URLSession
    private let userDefaults: UserDefaults
    private let aiAvailabilityService: AIAvailabilityService?

    init(
        session: URLSession = .shared,
        userDefaults: UserDefaults = .standard,
        aiAvailabilityService: AIAvailabilityService? = nil
    ) {
        self.session = session
        self.userDefaults = userDefaults
        self.aiAvailabilityService = aiAvailabilityService
    }

    /// 分析文本内容
    ///
    /// - Parameters:
    ///   - text: 输入文本
    ///   - mode: 分析模式
    /// - Returns: 分析结果
    /// - Throws: 分析失败时抛出错误
    func analyze(text: String, mode: AIAnalysisMode) async throws -> AIAnalysisResult {
        let normalized = normalizeOCRText(text)
        guard normalized.isEmpty == false else {
            throw AIAnalysisError.emptyInput
        }

        try ensureDeveloperLocalAIConfigAllowed()
        let apiKey = try resolvedAPIKey()
        let prompt = buildPrompt(for: mode, text: normalized)
        let request = try makeRequest(apiKey: apiKey, prompt: prompt, mode: mode)

        do {
            let (data, response) = try await session.data(for: request)
            try validateHTTPResponse(response, data: data)
            return try parseAnalysisResult(from: data, mode: mode)
        } catch let error as AIAnalysisError {
            throw error
        } catch let error as DecodingError {
            throw AIAnalysisError.requestFailed(
                AppText.aiResponseDecodeFailedPrefix + ": \(error.localizedDescription)"
            )
        } catch {
            throw AIAnalysisError.requestFailed(error.localizedDescription)
        }
    }

    /// 分析开发报错
    ///
    /// - Parameter text: 报错文本
    /// - Returns: 分析结果
    /// - Throws: 分析失败时抛出错误
    func analyzeDeveloperError(text: String) async throws -> AIAnalysisResult {
        try await analyze(text: text, mode: .developerError)
    }

    private func normalizeOCRText(_ text: String) -> String {
        let normalizedLineBreaks = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var cleanedLines: [String] = []
        var previousLineWasEmpty = false

        for line in normalizedLineBreaks.components(separatedBy: "\n") {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedLine.isEmpty {
                guard previousLineWasEmpty == false else {
                    continue
                }
                cleanedLines.append("")
                previousLineWasEmpty = true
                continue
            }

            cleanedLines.append(trimmedLine)
            previousLineWasEmpty = false
        }

        return cleanedLines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func ensureDeveloperLocalAIConfigAllowed() throws {
        let availabilityService = aiAvailabilityService ?? AIAvailabilityService(userDefaults: userDefaults)
        guard availabilityService.isDeveloperLocalAIConfigAllowed else {
            throw AIAnalysisError.requestFailed(AppText.aiRegionPolicyBlocked)
        }
    }

    private func resolvedAPIKey() throws -> String {
        let key = userDefaults.string(forKey: AppSettings.aiAnalysisAPIKeyKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard key.isEmpty == false else {
            throw AIAnalysisError.missingAPIKey
        }

        return key
    }

    private func resolvedModel() -> String {
        let configured = userDefaults.string(forKey: AppSettings.aiAnalysisModelKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let configured, configured.isEmpty == false else {
            return AppSettings.aiAnalysisModelDefaultValue
        }

        return configured
    }

    private func resolvedBaseURL() throws -> URL {
        let configured = userDefaults.string(forKey: AppSettings.aiAnalysisBaseURLKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let rawValue = (configured?.isEmpty == false)
            ? configured!
            : AppSettings.aiAnalysisBaseURLDefaultValue

        guard var components = URLComponents(string: rawValue),
              components.scheme?.isEmpty == false,
              components.host?.isEmpty == false else {
            throw AIAnalysisError.requestFailed(AppText.aiBaseURLInvalid)
        }

        var path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.isEmpty {
            path = "v1"
        }
        components.path = "/" + path + "/responses"

        guard let url = components.url else {
            throw AIAnalysisError.requestFailed(AppText.aiBaseURLInvalid)
        }

        return url
    }

    private func currentLanguage() -> AppLanguage {
        AppLocalization.currentLanguage(userDefaults: userDefaults)
    }

    private func buildDeveloperErrorPrompt(from text: String) -> String {
        buildPrompt(from: definition(for: .developerError), text: text, mode: .developerError)
    }

    private func buildPrompt(for mode: AIAnalysisMode, text: String) -> String {
        buildPrompt(from: definition(for: mode), text: text, mode: mode)
    }

    private func buildSummaryPrompt(from text: String) -> String {
        buildPrompt(from: definition(for: .summary), text: text, mode: .summary)
    }

    private func buildPrompt(
        from definition: AnalysisModeDefinition,
        text: String,
        mode: AIAnalysisMode
    ) -> String {
        let language = currentLanguage()
        let sectionsText: String
        switch mode {
        case .interfaceStructure:
            sectionsText = """
            \(AppText.interfaceStructureTitle)：
            \(AppText.interfaceComponentsTitle)：
            <这里填写内容>

            \(AppText.interfaceHierarchyTitle)：
            <这里填写内容>

            \(AppText.interfaceVisualTitle)：
            <这里填写内容>

            \(AppText.interfaceInteractionTitle)：
            <这里填写内容>

            \(AppText.interfaceImplementationTitle)：
            <这里填写内容>
            """
        default:
            sectionsText = definition.sections
                .map { "\($0.promptTitle)：\n<这里填写内容>" }
                .joined(separator: "\n\n")
        }

        let requirementsText = definition.requirements
            .map { "- \($0)" }
            .joined(separator: "\n")

        let outputLanguageInstruction: String
        switch mode {
        case .developerError, .summary:
            outputLanguageInstruction = """
            Please use \(AppText.promptOutputLanguageName(for: language)) for the final answer and follow the required structure strictly based on the \(definition.inputLabel).
            """
        case .interfaceStructure:
            outputLanguageInstruction = """
            Please use \(AppText.promptOutputLanguageName(for: language)) for the final answer, output a structured interface description based on the \(definition.inputLabel), and ensure all 5 fixed subheadings appear.
            """
        case .translation:
            outputLanguageInstruction = "Please output only the translation result based on the \(definition.inputLabel)."
        }

        let targetLanguageInstruction: String
        switch mode {
        case let .translation(language):
            switch language {
            case .simplifiedChinese:
                targetLanguageInstruction = "Target language: Simplified Chinese"
            case .english:
                targetLanguageInstruction = "Target language: English"
            }
        default:
            targetLanguageInstruction = ""
        }

        return """
        \(definition.promptIntro)
        \(outputLanguageInstruction)

        \(targetLanguageInstruction.isEmpty ? "" : targetLanguageInstruction + "\n")

        \(sectionsText)

        要求：
        \(requirementsText)

        \(definition.inputLabel)：
        \(text)
        """
    }

    private func buildInstructions(for mode: AIAnalysisMode) -> String {
        definition(for: mode).instructions
    }

    private func makeRequest(apiKey: String, prompt: String, mode: AIAnalysisMode) throws -> URLRequest {
        let url = try resolvedBaseURL()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body = ResponseRequestBody(
            model: resolvedModel(),
            instructions: buildInstructions(for: mode),
            input: prompt,
            store: false
        )
        request.httpBody = try JSONEncoder().encode(body)

        return request
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIAnalysisError.invalidResponse
        }

        guard 200 ..< 300 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? AppText.aiUnknownServerError
            throw AIAnalysisError.requestFailed(message)
        }
    }

    private func definition(for mode: AIAnalysisMode) -> AnalysisModeDefinition {
        switch mode {
        case .developerError:
            return AnalysisModeDefinition(
                instructions: "Analyze developer-facing error text and return a concise structured answer.",
                promptIntro: "You help macOS and iOS developers understand and troubleshoot errors from screenshots.",
                inputLabel: "error text",
                requirements: [
                    "all three sections must be present",
                    "keep the wording concise and clear",
                    "if the information is insufficient, state the uncertainty explicitly",
                    "do not provide generic advice unrelated to the screenshot",
                    "do not add extra headings, prefaces, conclusions, or Markdown code blocks",
                ],
                sections: [
                    SectionDefinition(
                        title: AppText.developerErrorSummaryTitle,
                        promptTitle: AppText.developerErrorSummaryTitle,
                        acceptedHeaders: [.exact(AppText.developerErrorSummaryTitle), .exact("报错大意"), .exact("Error Summary")]
                    ),
                    SectionDefinition(
                        title: AppText.developerErrorCausesTitle,
                        promptTitle: AppText.developerErrorCausesTitle,
                        acceptedHeaders: [.exact(AppText.developerErrorCausesTitle), .exact("可能原因"), .exact("Possible Causes")]
                    ),
                    SectionDefinition(
                        title: AppText.developerErrorNextStepsTitle,
                        promptTitle: AppText.developerErrorNextStepsTitle,
                        acceptedHeaders: [.exact(AppText.developerErrorNextStepsTitle), .exact("建议下一步"), .exact("Suggested Next Steps")]
                    ),
                ]
            )
        case .summary:
            return AnalysisModeDefinition(
                instructions: "Summarize the key points from screenshot text and return a concise structured answer.",
                promptIntro: "You help users extract the key points from screenshot text.",
                inputLabel: "text content",
                requirements: [
                    "all three sections must be present",
                    "keep each point short",
                    "if the information is insufficient, say so clearly",
                    "do not add extra headings, prefaces, conclusions, or Markdown code blocks",
                ],
                sections: [
                    SectionDefinition(
                        title: AppText.summaryPoint1Title,
                        promptTitle: AppText.summaryPoint1Title,
                        acceptedHeaders: [.exact(AppText.summaryPoint1Title), .exact("重点 1"), .exact("重点1"), .exact("重点一"), .exact("Point 1")]
                    ),
                    SectionDefinition(
                        title: AppText.summaryPoint2Title,
                        promptTitle: AppText.summaryPoint2Title,
                        acceptedHeaders: [.exact(AppText.summaryPoint2Title), .exact("重点 2"), .exact("重点2"), .exact("重点二"), .exact("Point 2")]
                    ),
                    SectionDefinition(
                        title: AppText.summaryPoint3Title,
                        promptTitle: AppText.summaryPoint3Title,
                        acceptedHeaders: [.exact(AppText.summaryPoint3Title), .exact("重点 3"), .exact("重点3"), .exact("重点三"), .exact("Point 3")]
                    ),
                ]
            )
        case .translation:
            return AnalysisModeDefinition(
                instructions: "Translate the screenshot text into the requested target language and output only the translation result.",
                promptIntro: "You help users translate text extracted from screenshots.",
                inputLabel: "source text",
                requirements: [
                    "output only the translation, not the source text",
                    "do not add explanations, notes, prefaces, conclusions, or Markdown code blocks",
                    "keep the meaning accurate and the phrasing natural",
                    "translate menus, buttons, and short phrases naturally",
                ],
                sections: [
                    SectionDefinition(
                        title: AppText.translationSectionTitle,
                        promptTitle: AppText.translationSectionTitle,
                        acceptedHeaders: [.exact(AppText.translationSectionTitle), .exact("译文"), .exact("Translation")]
                    ),
                ]
            )
        case .interfaceStructure:
            return AnalysisModeDefinition(
                instructions: "Identify the interface structure from the screenshot and output a structured description that designers and developers can reuse.",
                promptIntro: "You help designers and developers understand screenshot UI structure.",
                inputLabel: "interface content",
                requirements: [
                    "use the fixed subheadings",
                    "keep it concise, concrete, and reusable",
                    "prioritize component types, hierarchy, visual traits, interaction semantics, and implementation notes",
                    "give implementation notes as a general direction first, then one practical suggestion",
                    "do not output code blocks, JSON, prefaces, conclusions, or irrelevant guesses",
                ],
                sections: [
                    SectionDefinition(
                        title: AppText.interfaceStructureTitle,
                        promptTitle: AppText.interfaceStructureTitle,
                        acceptedHeaders: [.exact(AppText.interfaceStructureTitle), .exact("界面结构"), .exact("Interface Structure")]
                    ),
                ]
            )
        }
    }

    private func parseAnalysisResult(from data: Data, mode: AIAnalysisMode) throws -> AIAnalysisResult {
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

        switch mode {
        case .translation:
            return try parseTranslationResult(from: text, mode: mode)
        case .interfaceStructure:
            return try parseInterfaceStructureResult(from: text, mode: mode)
        default:
            return try parseStructuredSections(from: text, mode: mode)
        }
    }

    private func parseTranslationResult(from text: String, mode: AIAnalysisMode) throws -> AIAnalysisResult {
        if let structuredResult = try? parseStructuredSections(from: text, mode: mode) {
            return structuredResult
        }

        let normalized = normalizeTranslationText(text)
        guard normalized.isEmpty == false else {
            throw AIAnalysisError.lowQualityOutput
        }

        print("[AI Analysis] Translation output missing explicit section header, fallback to raw translated text")

        let sections = [
            AIAnalysisSection(title: AppText.translationSectionTitle, content: normalized),
        ]

        return AIAnalysisResult(
            mode: mode,
            statusTitle: mode.resultStatusTitle,
            sections: sections,
            rawText: text,
            secondaryCopyText: normalized
        )
    }

    private func parseInterfaceStructureResult(from text: String, mode: AIAnalysisMode) throws -> AIAnalysisResult {
        if let structuredResult = try? parseStructuredSections(from: text, mode: mode) {
            guard hasAllInterfaceStructureHeadings(in: structuredResult.sections.first?.content ?? "") else {
                throw AIAnalysisError.lowQualityOutput
            }
            return structuredResult
        }

        let normalized = normalizeInterfaceStructureText(text)
        guard normalized.isEmpty == false, hasAllInterfaceStructureHeadings(in: normalized) else {
            throw AIAnalysisError.lowQualityOutput
        }

        print("[AI Analysis] Interface structure output missing explicit section header, fallback to raw structured text")

        let sections = [
            AIAnalysisSection(title: AppText.interfaceStructureTitle, content: normalized),
        ]

        return AIAnalysisResult(
            mode: mode,
            statusTitle: mode.resultStatusTitle,
            sections: sections,
            rawText: text,
            secondaryCopyText: normalized
        )
    }

    private func parseStructuredSections(from text: String, mode: AIAnalysisMode) throws -> AIAnalysisResult {
        let definition = definition(for: mode)
        let titles = definition.sections.map(\.title)
        var currentTitle: String?
        var collectedSections: [String: [String]] = [:]

        for rawLine in text.components(separatedBy: .newlines) {
            if let header = parseSectionHeader(from: rawLine, sections: definition.sections) {
                currentTitle = header.title
                if header.inlineContent.isEmpty == false {
                    collectedSections[header.title, default: []].append(header.inlineContent)
                }
                continue
            }

            guard let currentTitle else {
                continue
            }

            collectedSections[currentTitle, default: []].append(rawLine)
        }

        func resolvedContent(for title: String) -> String? {
            let lines = collectedSections[title, default: []]
            let joined = lines
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .drop(while: \.isEmpty)
                .reversed()
                .drop(while: \.isEmpty)
                .reversed()
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return joined.isEmpty ? nil : joined
        }

        let sections = try titles.map { title -> AIAnalysisSection in
            guard let content = resolvedContent(for: title) else {
                throw AIAnalysisError.lowQualityOutput
            }

            return AIAnalysisSection(title: title, content: content)
        }

        return AIAnalysisResult(
            mode: mode,
            statusTitle: mode.resultStatusTitle,
            sections: sections,
            rawText: text,
            secondaryCopyText: secondaryCopyText(for: mode, sections: sections, fallback: text)
        )
    }

    private func secondaryCopyText(
        for mode: AIAnalysisMode,
        sections: [AIAnalysisSection],
        fallback: String
    ) -> String {
        switch mode {
        case .summary:
            return sections
                .map { "\($0.title)：\n\($0.content)" }
                .joined(separator: "\n\n")
        case .translation:
            return sections.first?.content ?? fallback
        case .interfaceStructure:
            return sections.first?.content ?? fallback
        case .developerError:
            return sections.last?.content ?? fallback
        }
    }

    private func normalizeTranslationText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return ""
        }

        let candidates = [
            "\(AppText.translationSectionTitle)：",
            "\(AppText.translationSectionTitle):",
            "译文：",
            "译文:",
            "Translation:",
            "Translation：",
        ]

        for prefix in candidates {
            if trimmed.hasPrefix(prefix) {
                return trimmed
                    .dropFirst(prefix.count)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return trimmed
    }

    private func normalizeInterfaceStructureText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return ""
        }

        let candidates = [
            "\(AppText.interfaceStructureTitle)：",
            "\(AppText.interfaceStructureTitle):",
            "界面结构：",
            "界面结构:",
        ]

        for prefix in candidates {
            if trimmed.hasPrefix(prefix) {
                return trimmed
                    .dropFirst(prefix.count)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return trimmed
    }

    private func hasAllInterfaceStructureHeadings(in text: String) -> Bool {
        let headings = [
            AppText.interfaceComponentsTitle,
            AppText.interfaceHierarchyTitle,
            AppText.interfaceVisualTitle,
            AppText.interfaceInteractionTitle,
            AppText.interfaceImplementationTitle,
        ]

        return headings.allSatisfy { heading in
            text.contains("\(heading)：") || text.contains("\(heading):")
        }
    }

    private func parseSectionHeader(
        from line: String,
        sections: [SectionDefinition]
    ) -> (title: String, inlineContent: String)? {
        let sanitizedLine = line
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(
                of: #"^\s*[\-\*\•]?\s*\d*\s*[\.、]?\s*"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

        for section in sections {
            guard let matchedHeader = section.matchedHeader(in: sanitizedLine) else {
                continue
            }

            let remainder = sanitizedLine.dropFirst(matchedHeader.count)
            let normalizedRemainder = remainder.trimmingCharacters(in: .whitespacesAndNewlines)

            if normalizedRemainder.isEmpty {
                return (section.title, "")
            }

            if normalizedRemainder.hasPrefix("：") || normalizedRemainder.hasPrefix(":") {
                let inlineContent = normalizedRemainder
                    .dropFirst()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return (section.title, inlineContent)
            }
        }

        return nil
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else {
            return nil
        }

        return self[index]
    }
}

private extension AIAnalysisService {
    struct AnalysisModeDefinition {
        let instructions: String
        let promptIntro: String
        let inputLabel: String
        let requirements: [String]
        let sections: [SectionDefinition]
    }

    struct SectionDefinition {
        let title: String
        let promptTitle: String
        let acceptedHeaders: [AcceptedHeader]

        func matchedHeader(in line: String) -> String? {
            for acceptedHeader in acceptedHeaders {
                if let matchedHeader = acceptedHeader.matchedHeader(in: line) {
                    return matchedHeader
                }
            }

            return nil
        }
    }

    enum AcceptedHeader {
        case exact(String)

        func matchedHeader(in line: String) -> String? {
            switch self {
            case let .exact(header):
                return line.hasPrefix(header) ? header : nil
            }
        }
    }

    struct ResponseRequestBody: Encodable {
        let model: String
        let instructions: String
        let input: String
        let store: Bool
    }

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
}

enum AIAnalysisError: LocalizedError {
    case missingAPIKey
    case emptyInput
    case invalidResponse
    case emptyOutput
    case lowQualityOutput
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return AppText.aiMissingAPIKey
        case .emptyInput:
            return AppText.aiEmptyInput
        case .invalidResponse:
            return AppText.aiInvalidResponse
        case .emptyOutput:
            return AppText.aiEmptyOutput
        case .lowQualityOutput:
            return AppText.aiLowQualityOutput
        case let .requestFailed(reason):
            return AppText.aiRequestFailedPrefix + ": \(reason)"
        }
    }
}
