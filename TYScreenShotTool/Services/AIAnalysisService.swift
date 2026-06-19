//
//  AIAnalysisService.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/18.
//

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
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else {
            throw AIAnalysisError.emptyInput
        }

        let apiKey = try resolvedAPIKey()
        let prompt = buildDeveloperErrorPrompt(from: normalized)
        let request = try makeRequest(apiKey: apiKey, prompt: prompt)

        do {
            let (data, response) = try await session.data(for: request)
            try validateHTTPResponse(response, data: data)
            return try parseOutputText(from: data)
        } catch let error as AIAnalysisError {
            throw error
        } catch let error as DecodingError {
            throw AIAnalysisError.requestFailed("响应解析失败：\(error.localizedDescription)")
        } catch {
            throw AIAnalysisError.requestFailed(error.localizedDescription)
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
        """
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
        \(text)
        """
    }

    private func makeRequest(apiKey: String, prompt: String) throws -> URLRequest {
        let url = try resolvedBaseURL()

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

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIAnalysisError.invalidResponse
        }

        guard 200 ..< 300 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? "未知服务端错误。"
            throw AIAnalysisError.requestFailed(message)
        }
    }

    private func parseOutputText(from data: Data) throws -> String {
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

private extension AIAnalysisService {
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
