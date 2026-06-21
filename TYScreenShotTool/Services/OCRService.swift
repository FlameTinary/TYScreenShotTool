//
//  OCRService.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/6.
//

import CoreGraphics
import Foundation
import Vision

/// OCR 文字识别服务
///
/// 使用 Apple Vision 框架识别图像中的文字，支持中文和英文。
final class OCRService {
    /// 识别图像中的文字
    ///
    /// 使用精确识别模式和语言校正，支持简体中文、繁体中文和英文。
    /// 在 macOS 13.0+ 会自动检测语言。
    ///
    /// - Parameter image: 要识别的图像
    /// - Returns: 识别出的文字，每行文本以换行符分隔
    /// - Throws: `OCRError.requestFailed` 如果识别请求失败
    /// - Throws: `OCRError.noTextRecognized` 如果图像中没有可识别的文字
    /// - Throws: `OCRError.emptyText` 如果识别结果为空
    func recognizeText(in image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]

        if #available(macOS 13.0, *) {
            request.automaticallyDetectsLanguage = true
        }

        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        do {
            try handler.perform([request])
        } catch {
            throw OCRError.requestFailed(error.localizedDescription)
        }

        guard let observations = request.results, !observations.isEmpty else {
            throw OCRError.noTextRecognized
        }

        let lines = observations.compactMap { observation in
            observation.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            throw OCRError.emptyText
        }

        return lines.joined(separator: "\n")
    }
}

/// OCR 错误类型
///
/// 定义文字识别过程中可能发生的错误情况。
enum OCRError: LocalizedError {
    /// 识别请求失败
    case requestFailed(String)
    /// 未识别到任何文字
    case noTextRecognized
    /// 识别结果为空文本
    case emptyText

    /// 错误的本地化描述
    var errorDescription: String? {
        switch self {
        case let .requestFailed(reason):
            return "Failed to perform OCR request: \(reason)"
        case .noTextRecognized:
            return "No text recognized from screenshot."
        case .emptyText:
            return "Recognized text is empty."
        }
    }
}
