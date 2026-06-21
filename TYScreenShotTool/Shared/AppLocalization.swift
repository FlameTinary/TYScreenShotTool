//
//  AppLocalization.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/21.
//

import Foundation

enum AppLocalization {
    static func userSelectedLanguage(
        userDefaults: UserDefaults = .standard
    ) -> AppLanguage {
        let rawValue = userDefaults.string(forKey: AppSettings.appLanguageKey)
            ?? AppSettings.appLanguageDefaultValue
        return AppLanguage(rawValue: rawValue) ?? .system
    }

    static func currentLanguage(
        userDefaults: UserDefaults = .standard,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> AppLanguage {
        let selected = userSelectedLanguage(userDefaults: userDefaults)
        return AppLanguage.resolved(
            userSelection: selected,
            preferredLanguages: preferredLanguages
        )
    }

    static func bundle(
        userDefaults: UserDefaults = .standard,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> Bundle {
        let language = currentLanguage(
            userDefaults: userDefaults,
            preferredLanguages: preferredLanguages
        )

        guard
            let localizationCode = language.localizationCode,
            let bundlePath = Bundle.main.path(forResource: localizationCode, ofType: "lproj"),
            let localizedBundle = Bundle(path: bundlePath)
        else {
            return .main
        }

        return localizedBundle
    }

    static func text(
        _ key: String,
        table: String? = nil,
        userDefaults: UserDefaults = .standard,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        bundle(
            userDefaults: userDefaults,
            preferredLanguages: preferredLanguages
        ).localizedString(forKey: key, value: key, table: table)
    }
}
