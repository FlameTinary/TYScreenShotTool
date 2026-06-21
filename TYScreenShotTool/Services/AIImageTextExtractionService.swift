//
//  AIImageTextExtractionService.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/20.
//

import CoreGraphics
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
            return AppText.aiImageMissingAPIKey
        case .imageEncodingFailed:
            return AppText.aiImageEncodingFailed
        case .invalidResponse:
            return AppText.aiImageInvalidResponse
        case .emptyOutput:
            return AppText.aiImageEmptyOutput
        case .noUsefulText:
            return AppText.aiNoValidText
        case let .requestFailed(reason):
            return AppText.aiImageRequestFailedPrefix + ": \(reason)"
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

extension AIImageTextExtractionService {
    /// 从图像中提取文字
    ///
    /// - Parameter image: 输入图像
    /// - Returns: 提取结果，包含标准化文本和原始文本
    /// - Throws: 提取失败时抛出错误
    func extractText(from image: CGImage) async throws -> AIExtractedTextResult {
        let apiKey = try resolvedAPIKey()
        let dataURL = try makeImageDataURL(from: image)
        let model = resolvedModel()
        let request = try makeRequest(apiKey: apiKey, imageDataURL: dataURL)

        print("[AI Vision] Start text extraction")
        print("[AI Vision] model: \(model)")
        print("[AI Vision] image: \(image.width)x\(image.height)")

        do {
            let (data, response) = try await session.data(for: request)
            try validateHTTPResponse(response, data: data)
            let result = try parseExtractionResult(from: data)
            print("[AI Vision] Extraction success")
            print("[AI Vision] normalized text length: \(result.text.count)")
            return result
        } catch let error as AIImageTextExtractionError {
            print("[AI Vision] Extraction failed: \(error.localizedDescription)")
            throw error
        } catch let error as DecodingError {
            throw AIImageTextExtractionError.requestFailed(
                AppText.aiResponseDecodeFailedPrefix + ": \(error.localizedDescription)"
            )
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
            throw AIImageTextExtractionError.requestFailed(AppText.aiBaseURLInvalid)
        }

        var path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.isEmpty {
            path = "v1"
        }
        components.path = "/" + path + "/responses"

        guard let url = components.url else {
            throw AIImageTextExtractionError.requestFailed(AppText.aiBaseURLInvalid)
        }

        return url
    }

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
        AppText.aiVisionExtractionPrompt
    }

    func makeRequest(apiKey: String, imageDataURL: String) throws -> URLRequest {
        let url = try resolvedBaseURL()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body = VisionResponseRequestBody(
            model: resolvedModel(),
            instructions: AppText.aiVisionExtractionInstructions,
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

    func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIImageTextExtractionError.invalidResponse
        }

        print("[AI Vision] HTTP status: \(httpResponse.statusCode)")

        guard 200 ..< 300 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? AppText.aiUnknownServerError
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
            print("[AI Vision] Response returned empty output text, treating as no useful text")
            throw AIImageTextExtractionError.noUsefulText
        }

        let normalized = normalizeExtractedText(rawText)
        guard normalized.isEmpty == false else {
            print("[AI Vision] Response text normalized to empty text")
            throw AIImageTextExtractionError.noUsefulText
        }

        return AIExtractedTextResult(
            text: normalized,
            rawText: rawText
        )
    }
}

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
