//
//  AIAnalysisService.swift
//  TYScreenShotTool
//
//  Created by Sheldon on 2026/6/18.
//

import Foundation

struct AIAnalysisSection {
    let title: String
    let content: String
}

struct AIAnalysisResult {
    let mode: AIAnalysisMode
    let statusTitle: String
    let sections: [AIAnalysisSection]
    let rawText: String
    let secondaryCopyText: String

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

    func analyze(text: String, mode: AIAnalysisMode) async throws -> AIAnalysisResult {
        let normalized = normalizeOCRText(text)
        guard normalized.isEmpty == false else {
            throw AIAnalysisError.emptyInput
        }

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
            throw AIAnalysisError.requestFailed("响应解析失败：\(error.localizedDescription)")
        } catch {
            throw AIAnalysisError.requestFailed(error.localizedDescription)
        }
    }

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
            throw AIAnalysisError.requestFailed("AI Base URL 无效。")
        }

        var path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.isEmpty {
            path = "v1"
        }
        components.path = "/" + path + "/responses"

        guard let url = components.url else {
            throw AIAnalysisError.requestFailed("AI Base URL 无效。")
        }

        return url
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
        let sectionsText: String
        switch mode {
        case .interfaceStructure:
            sectionsText = """
            界面结构：
            组件识别：
            <这里填写内容>

            结构层级：
            <这里填写内容>

            视觉特征：
            <这里填写内容>

            交互语义：
            <这里填写内容>

            实现提示：
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
            outputLanguageInstruction = "请基于下面的\(definition.inputLabel)，用简洁中文输出，并严格使用以下结构："
        case .interfaceStructure:
            outputLanguageInstruction = "请基于下面的\(definition.inputLabel)，严格按要求输出一段结构化界面说明，并确保 5 个固定小标题全部出现："
        case .translation:
            outputLanguageInstruction = "请基于下面的\(definition.inputLabel)，严格按要求输出译文："
        }

        let targetLanguageInstruction: String
        switch mode {
        case let .translation(language):
            switch language {
            case .simplifiedChinese:
                targetLanguageInstruction = "目标语言：简体中文"
            case .english:
                targetLanguageInstruction = "目标语言：英文"
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
            let message = String(data: data, encoding: .utf8) ?? "未知服务端错误。"
            throw AIAnalysisError.requestFailed(message)
        }
    }

    private func definition(for mode: AIAnalysisMode) -> AnalysisModeDefinition {
        switch mode {
        case .developerError:
            return AnalysisModeDefinition(
                instructions: "你负责分析开发报错文本，并用简洁中文输出结果。",
                promptIntro: "你是一个帮助 macOS / iOS 开发者排查报错的助手。",
                inputLabel: "报错文本",
                requirements: [
                    "三个部分都必须输出，不能缺省",
                    "保持短而清晰",
                    "如果信息不足，明确说明不确定点",
                    "不要输出与截图无关的泛泛建议",
                    "不要输出额外标题、前言、总结或 Markdown 代码块",
                ],
                sections: [
                    SectionDefinition(
                        title: "报错大意",
                        promptTitle: "报错大意",
                        acceptedHeaders: [.exact("报错大意")]
                    ),
                    SectionDefinition(
                        title: "可能原因",
                        promptTitle: "可能原因",
                        acceptedHeaders: [.exact("可能原因")]
                    ),
                    SectionDefinition(
                        title: "建议下一步",
                        promptTitle: "建议下一步",
                        acceptedHeaders: [.exact("建议下一步")]
                    ),
                ]
            )
        case .summary:
            return AnalysisModeDefinition(
                instructions: "你负责总结截图文字重点，并用简洁中文输出结果。",
                promptIntro: "你是一个帮助用户总结截图文字重点的助手。",
                inputLabel: "文字内容",
                requirements: [
                    "三个部分都必须输出，不能缺省",
                    "每条尽量短句",
                    "如果信息不足，明确说明信息不足",
                    "不要输出额外标题、前言、总结或 Markdown 代码块",
                ],
                sections: [
                    SectionDefinition(
                        title: "重点 1",
                        promptTitle: "重点 1",
                        acceptedHeaders: [.exact("重点 1"), .exact("重点1"), .exact("重点一")]
                    ),
                    SectionDefinition(
                        title: "重点 2",
                        promptTitle: "重点 2",
                        acceptedHeaders: [.exact("重点 2"), .exact("重点2"), .exact("重点二")]
                    ),
                    SectionDefinition(
                        title: "重点 3",
                        promptTitle: "重点 3",
                        acceptedHeaders: [.exact("重点 3"), .exact("重点3"), .exact("重点三")]
                    ),
                ]
            )
        case .translation:
            return AnalysisModeDefinition(
                instructions: "你负责将截图中的文字翻译成指定目标语言，并仅输出译文结果。",
                promptIntro: "你是一个帮助用户翻译截图文字内容的助手。",
                inputLabel: "待翻译文本",
                requirements: [
                    "只输出译文，不要输出原文",
                    "不要输出解释、说明、前言、结语或 Markdown 代码块",
                    "保持语义准确与表达自然",
                    "若原文中存在明显的菜单、按钮或短句，仍然按自然语言翻译",
                ],
                sections: [
                    SectionDefinition(
                        title: "译文",
                        promptTitle: "译文",
                        acceptedHeaders: [.exact("译文")]
                    ),
                ]
            )
        case .interfaceStructure:
            return AnalysisModeDefinition(
                instructions: "你负责识别截图中的界面结构，并输出一段可供设计与开发继续复用的结构化说明。",
                promptIntro: "你是一个帮助设计师和开发者理解截图界面结构的助手。",
                inputLabel: "界面内容",
                requirements: [
                    "必须按固定小标题输出",
                    "保持简洁、具体、可复用",
                    "优先描述组件类型、层级、视觉特征、交互语义与实现提示",
                    "实现提示先给通用方向，再补一句前端或原生可参考的落地建议",
                    "不要输出代码块、JSON、前言、结语或与截图无关的猜测",
                ],
                sections: [
                    SectionDefinition(
                        title: "界面结构",
                        promptTitle: "界面结构",
                        acceptedHeaders: [.exact("界面结构")]
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
            AIAnalysisSection(title: "译文", content: normalized),
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
            AIAnalysisSection(title: "界面结构", content: normalized),
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
            "组件识别",
            "结构层级",
            "视觉特征",
            "交互语义",
            "实现提示",
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
            return "OpenAI API Key 未配置。"
        case .emptyInput:
            return "OCR 文本为空。"
        case .invalidResponse:
            return "AI 返回格式无效。"
        case .emptyOutput:
            return "AI 返回内容为空。"
        case .lowQualityOutput:
            return "AI 返回结果不完整，请重试或调整截图范围后再试。"
        case let .requestFailed(reason):
            return "AI 请求失败：\(reason)"
        }
    }
}
