//
//  SettingsView.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/6.
//

import AppKit
import SwiftUI

/// 设置视图
///
/// 提供快捷键配置、AI 分析设置和保存目录选择功能。
struct SettingsView: View {
    private let globalHotKeyService: GlobalHotKeyService

    @AppStorage(AppSettings.screenshotHotKeyKey)
    private var selectedHotKeyStorageValue = AppSettings.screenshotHotKeyDefaultValue
    @AppStorage(AppSettings.saveDirectoryPathKey)
    private var saveDirectoryPath = ""
    @AppStorage(AppSettings.saveDirectoryBookmarkDataKey)
    private var saveDirectoryBookmarkData = Data()
    @AppStorage(AppSettings.aiUseVisionTextExtractionKey)
    private var aiUseVisionTextExtraction = AppSettings.aiUseVisionTextExtractionDefaultValue
    @AppStorage(AppSettings.appLanguageKey)
    private var appLanguageStorageValue = AppSettings.appLanguageDefaultValue
    @State private var displayedHotKeyValue = ScreenshotHotKey.screenshot.displayName
    @State private var isRecordingHotKey = false
    @State private var pendingHotKey: ScreenshotHotKey?
    @State private var previousHotKey: ScreenshotHotKey?
    @State private var hotKeyErrorMessage = ""

    init(globalHotKeyService: GlobalHotKeyService) {
        self.globalHotKeyService = globalHotKeyService
    }

    private var appLanguageSelection: Binding<AppLanguage> {
        Binding(
            get: {
                AppLanguage(rawValue: appLanguageStorageValue) ?? .system
            },
            set: { newValue in
                appLanguageStorageValue = newValue.storageValue
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(AppLocalization.text("settings.title"))
                .font(.title2)
                .fontWeight(.semibold)

            Text(AppLocalization.text("settings.description"))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                hotKeyPicker
                languageSettings
                aiAnalysisSettings
                saveDirectoryPicker
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 460, minHeight: 360, alignment: .topLeading)
        .onAppear {
            resetHotKeyEditorState()
        }
        .onDisappear {
            resetHotKeyEditorState()
        }
    }

    private var hotKeyPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AppLocalization.text("settings.hotkey.section"))
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text(AppLocalization.text("settings.hotkey.label"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HotKeyRecorderField(
                    displayedValue: $displayedHotKeyValue,
                    isRecording: $isRecordingHotKey,
                    onBeginRecording: {
                        beginRecordingIfNeeded()
                    },
                    onCandidateChanged: { candidate in
                        pendingHotKey = candidate
                    },
                    onCommit: {
                        commitRecordedHotKey()
                    },
                    onCancel: {
                        cancelRecordedHotKey()
                    }
                )
                .frame(width: 220, height: 28, alignment: .leading)
            }

            if hotKeyErrorMessage.isEmpty == false {
                Text(hotKeyErrorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(AppLocalization.text("settings.hotkey.help"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var languageSettings: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AppLocalization.text("settings.language.section"))
                .font(.headline)

            Picker(
                AppLocalization.text("settings.language.label"),
                selection: appLanguageSelection
            ) {
                Text(AppLocalization.text("settings.language.option.system")).tag(AppLanguage.system)
                Text(AppLocalization.text("settings.language.option.zh_hans")).tag(AppLanguage.simplifiedChinese)
                Text(AppLocalization.text("settings.language.option.en")).tag(AppLanguage.english)
                Text(AppLocalization.text("settings.language.option.ja")).tag(AppLanguage.japanese)
                Text(AppLocalization.text("settings.language.option.ko")).tag(AppLanguage.korean)
                Text(AppLocalization.text("settings.language.option.de")).tag(AppLanguage.german)
                Text(AppLocalization.text("settings.language.option.fr")).tag(AppLanguage.french)
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 240, alignment: .leading)
        }
    }

    private var aiAnalysisSettings: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AppLocalization.text("settings.ai.section"))
                .font(.headline)

            Toggle(AppLocalization.text("settings.ai.use_vision"), isOn: $aiUseVisionTextExtraction)

            Text(AppLocalization.text("settings.ai.help"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 保存目录配置区域
    private var saveDirectoryPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AppLocalization.text("settings.save.section"))
                .font(.headline)

            Text(currentSaveDirectoryPath)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(2)

            HStack(spacing: 12) {
                Button(AppLocalization.text("settings.save.choose")) {
                    chooseSaveDirectory()
                }

                Button(AppLocalization.text("settings.save.clear")) {
                    saveDirectoryPath = ""
                    saveDirectoryBookmarkData = Data()
                }
            }

            Text(AppLocalization.text("settings.save.help"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var currentSaveDirectoryPath: String {
        if saveDirectoryPath.isEmpty {
            return AppLocalization.text("settings.save.not_configured")
        }

        return saveDirectoryPath
    }

    private var configuredHotKey: ScreenshotHotKey {
        ScreenshotHotKey(storageValue: selectedHotKeyStorageValue) ?? .screenshot
    }

    private func beginRecordingIfNeeded() {
        if isRecordingHotKey == false {
            isRecordingHotKey = true
            previousHotKey = configuredHotKey
            pendingHotKey = nil
        }
        hotKeyErrorMessage = ""
    }

    private func cancelRecordedHotKey() {
        let hotKey = previousHotKey ?? configuredHotKey
        displayedHotKeyValue = hotKey.displayName
        pendingHotKey = nil
        previousHotKey = nil
        isRecordingHotKey = false
        hotKeyErrorMessage = ""
    }

    private func commitRecordedHotKey() {
        let fallbackHotKey = previousHotKey ?? configuredHotKey

        defer {
            isRecordingHotKey = false
            pendingHotKey = nil
            previousHotKey = nil
        }

        guard let pendingHotKey else {
            displayedHotKeyValue = fallbackHotKey.displayName
            hotKeyErrorMessage = AppLocalization.text("settings.hotkey.error.no_primary_key")
            return
        }

        if pendingHotKey == fallbackHotKey {
            displayedHotKeyValue = fallbackHotKey.displayName
            hotKeyErrorMessage = ""
            return
        }

        guard globalHotKeyService.updateHotKey(pendingHotKey) else {
            displayedHotKeyValue = fallbackHotKey.displayName
            hotKeyErrorMessage = AppLocalization.text("settings.hotkey.error.registration_failed")
            return
        }

        selectedHotKeyStorageValue = pendingHotKey.storageValue
        displayedHotKeyValue = pendingHotKey.displayName
        hotKeyErrorMessage = ""
    }

    /// 选择保存目录
    private func chooseSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = AppLocalization.text("settings.save.choose")
        panel.message = AppLocalization.text("settings.save.panel_message")

        if !saveDirectoryPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: saveDirectoryPath, isDirectory: true)
        } else {
            panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        }

        guard panel.runModal() == .OK, let selectedDirectoryURL = panel.url else {
            return
        }

        do {
            let bookmarkData = try selectedDirectoryURL.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            saveDirectoryBookmarkData = bookmarkData
            saveDirectoryPath = selectedDirectoryURL.path
        } catch {
            print("Save directory bookmark creation failed: \(error.localizedDescription)")
        }
    }

    private func resetHotKeyEditorState() {
        displayedHotKeyValue = configuredHotKey.displayName
        isRecordingHotKey = false
        pendingHotKey = nil
        previousHotKey = nil
        hotKeyErrorMessage = ""
    }
}
