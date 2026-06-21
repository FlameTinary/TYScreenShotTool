//
//  AppThemeCoordinator.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/21.
//

import AppKit

/// App 外观协调器
///
/// 统一读取用户设置，并将外观应用到应用和已打开窗口。
@MainActor
final class AppThemeCoordinator {
    static let shared = AppThemeCoordinator()

    private var refreshHandlers: [ObjectIdentifier: @MainActor () -> Void] = [:]

    private init() {}

    func userSelectedAppearance(
        userDefaults: UserDefaults = .standard
    ) -> AppAppearance {
        let rawValue = userDefaults.string(forKey: AppSettings.appAppearanceKey)
            ?? AppSettings.appAppearanceDefaultValue
        return AppAppearance(rawValue: rawValue) ?? .system
    }

    func resolvedAppearance(
        userDefaults: UserDefaults = .standard
    ) -> NSAppearance? {
        userSelectedAppearance(userDefaults: userDefaults).nsAppearance
    }

    func applyCurrentAppearance(
        userDefaults: UserDefaults = .standard
    ) {
        let appearance = resolvedAppearance(userDefaults: userDefaults)
        let application = NSApplication.shared
        application.appearance = appearance

        for window in application.windows {
            applyCurrentAppearance(to: window, userDefaults: userDefaults)
        }

        for refresh in refreshHandlers.values {
            refresh()
        }
    }

    func applyCurrentAppearance(
        to window: NSWindow,
        userDefaults: UserDefaults = .standard
    ) {
        window.appearance = resolvedAppearance(userDefaults: userDefaults)
        window.invalidateShadow()
        window.displayIfNeeded()
    }

    func registerRefreshHandler(
        for owner: AnyObject,
        _ refresh: @escaping @MainActor () -> Void
    ) {
        refreshHandlers[ObjectIdentifier(owner)] = refresh
    }

    func unregisterRefreshHandler(
        for owner: AnyObject
    ) {
        refreshHandlers.removeValue(forKey: ObjectIdentifier(owner))
    }

    func unregisterRefreshHandler(
        for ownerID: ObjectIdentifier
    ) {
        refreshHandlers.removeValue(forKey: ownerID)
    }
}
