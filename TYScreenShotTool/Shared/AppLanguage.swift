//
//  AppLanguage.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/21.
//

import Foundation

enum AppLanguage: String, CaseIterable {
    case system
    case simplifiedChinese
    case english
    case japanese
    case korean
    case german
    case french

    static let supportedDisplayLanguages: [AppLanguage] = [
        .simplifiedChinese,
        .english,
        .japanese,
        .korean,
        .german,
        .french,
    ]

    var storageValue: String {
        rawValue
    }

    var localizationCode: String? {
        switch self {
        case .system:
            return nil
        case .simplifiedChinese:
            return "zh-Hans"
        case .english:
            return "en"
        case .japanese:
            return "ja"
        case .korean:
            return "ko"
        case .german:
            return "de"
        case .french:
            return "fr"
        }
    }

    static func resolved(
        userSelection: AppLanguage,
        preferredLanguages: [String]
    ) -> AppLanguage {
        guard userSelection == .system else {
            return userSelection
        }

        for preferred in preferredLanguages {
            let normalized = preferred.lowercased()
            if normalized.hasPrefix("zh") {
                return .simplifiedChinese
            }
            if normalized.hasPrefix("ja") {
                return .japanese
            }
            if normalized.hasPrefix("ko") {
                return .korean
            }
            if normalized.hasPrefix("de") {
                return .german
            }
            if normalized.hasPrefix("fr") {
                return .french
            }
            if normalized.hasPrefix("en") {
                return .english
            }
        }

        return .english
    }

    var ocrRecognitionLanguages: [String] {
        switch self {
        case .simplifiedChinese:
            return ["zh-Hans", "zh-Hant", "en-US"]
        case .english:
            return ["en-US", "zh-Hans", "zh-Hant"]
        case .japanese:
            return ["ja-JP", "en-US", "zh-Hans", "zh-Hant"]
        case .korean:
            return ["ko-KR", "en-US", "zh-Hans", "zh-Hant"]
        case .german:
            return ["de-DE", "en-US", "zh-Hans", "zh-Hant"]
        case .french:
            return ["fr-FR", "en-US", "zh-Hans", "zh-Hant"]
        case .system:
            return AppLanguage.english.ocrRecognitionLanguages
        }
    }
}
