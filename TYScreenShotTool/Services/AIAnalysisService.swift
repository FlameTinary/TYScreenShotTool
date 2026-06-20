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
        buildPrompt(from: definition(for: .developerError), text: text)
    }

    private func buildPrompt(for mode: AIAnalysisMode, text: String) -> String {
        buildPrompt(from: definition(for: mode), text: text)
    }

    private func buildSummaryPrompt(from text: String) -> String {
        buildPrompt(from: definition(for: .summary), text: text)
    }

    private func buildPrompt(from definition: AnalysisModeDefinition, text: String) -> String {
        let sectionsText = definition.sections
            .map { "\($0.promptTitle)：\n<这里填写内容>" }
            .joined(separator: "\n\n")

        let requirementsText = definition.requirements
            .map { "- \($0)" }
            .joined(separator: "\n")

        return """
        \(definition.promptIntro)
        请基于下面的\(definition.inputLabel)，用简洁中文输出，并严格使用以下结构：

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

        return try parseStructuredSections(from: text, mode: mode)
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
            secondaryCopyText: mode == .summary
                ? sections
                    .map { "\($0.title)：\n\($0.content)" }
                    .joined(separator: "\n\n")
                : (sections.last?.content ?? text)
        )
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
