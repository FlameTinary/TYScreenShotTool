//
//  LocalTranslationService.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/27.
//

import AppKit
import Translation

/// 纯本地翻译服务
///
/// 使用系统内置翻译能力，不依赖任何 AI 或网络服务。
/// 需要 macOS 26.0+（可通过 TranslationSession 程序化 API 创建会话）。
@MainActor
final class LocalTranslationService {
    /// 翻译结果
    struct TranslationResult {
        let sourceText: String
        let translatedText: String
        let targetLanguage: String
    }

    enum TranslationError: LocalizedError {
        case systemNotSupported
        case translationFailed(String)
        case cancelled

        var errorDescription: String? {
            switch self {
            case .systemNotSupported:
                return AppLocalization.text("translate.system_not_supported")
            case let .translationFailed(reason):
                return "\(AppLocalization.text("translate.failed")): \(reason)"
            case .cancelled:
                return AppLocalization.text("translate.failed")
            }
        }
    }

    /// 执行本地翻译
    ///
    /// - Parameters:
    ///   - text: 需要翻译的文本
    ///   - targetLanguage: 目标语言代码（如 "zh-Hans", "en"）
    /// - Returns: 翻译结果
    /// - Throws: TranslationError
    func translate(
        text: String,
        targetLanguage: String = "zh-Hans"
    ) async throws -> TranslationResult {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranslationError.translationFailed("Input text is empty")
        }

        // TranslationSession 程序化 API 自 macOS 26.0+ 可用
        if #available(macOS 26.0, *) {
            return try await performSystemTranslation(text: text, targetLanguage: targetLanguage)
        } else {
            throw TranslationError.systemNotSupported
        }
    }

    @available(macOS 26.0, *)
    private func performSystemTranslation(
        text: String,
        targetLanguage: String
    ) async throws -> TranslationResult {
        let sourceLanguage = Locale.Language(identifier: textLanguageCode(for: text))
        let target = Locale.Language(identifier: targetLanguage)

        // 检查语言对是否支持
        let availability = LanguageAvailability()
        let status = await availability.status(from: sourceLanguage, to: target)
        guard status == .installed || status == .supported else {
            throw TranslationError.translationFailed("Language pair not supported")
        }

        let session = TranslationSession(
            installedSource: sourceLanguage,
            target: target
        )

        let response = try await session.translate(text)

        return TranslationResult(
            sourceText: response.sourceText,
            translatedText: response.targetText,
            targetLanguage: targetLanguage
        )
    }

    /// 简单判断文本语言（用于选择源语言）
    private func textLanguageCode(for text: String) -> String {
        // 如果文本包含较多中文字符，源语言设为中文
        let chineseChars = text.unicodeScalars.filter { $0.properties.isIdeographic }
        if CGFloat(chineseChars.count) / CGFloat(max(text.count, 1)) > 0.3 {
            return "zh-Hans"
        }
        // 默认使用英文（API 会自动检测，nil 也可以）
        return "en"
    }
}
