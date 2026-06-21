//
//  SettingsView.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/6.
//

import AppKit
import SwiftUI

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
    @State private var displayedHotKeyValue = ScreenshotHotKey.screenshot.displayName
    @State private var isRecordingHotKey = false
    @State private var pendingHotKey: ScreenshotHotKey?
    @State private var previousHotKey: ScreenshotHotKey?
    @State private var hotKeyErrorMessage = ""

    init(globalHotKeyService: GlobalHotKeyService) {
        self.globalHotKeyService = globalHotKeyService
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)

            Text("当前版本提供截图快捷键、AI 分析链路与保存目录配置。")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                hotKeyPicker
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
            Text("HotKey 配置")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("截图快捷键")
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

            Text("支持修饰键与字母、数字、功能键、方向键组合，按回车确认。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var aiAnalysisSettings: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AI 分析配置")
                .font(.headline)

            Toggle("AI 使用视觉取字", isOn: $aiUseVisionTextExtraction)

            Text("关闭时使用本地 OCR，开启时使用 AI 先识别截图文字再分析。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var saveDirectoryPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("保存目录配置")
                .font(.headline)

            Text(currentSaveDirectoryPath)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(2)

            HStack(spacing: 12) {
                Button("选择目录") {
                    chooseSaveDirectory()
                }

                Button("清空配置") {
                    saveDirectoryPath = ""
                    saveDirectoryBookmarkData = Data()
                }
            }

            Text("仅支持选择单个目录。保存前必须先选择保存目录。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var currentSaveDirectoryPath: String {
        if saveDirectoryPath.isEmpty {
            return "未配置保存目录"
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
            hotKeyErrorMessage = "请至少输入一个主键"
            return
        }

        if pendingHotKey == fallbackHotKey {
            displayedHotKeyValue = fallbackHotKey.displayName
            hotKeyErrorMessage = ""
            return
        }

        guard globalHotKeyService.updateHotKey(pendingHotKey) else {
            displayedHotKeyValue = fallbackHotKey.displayName
            hotKeyErrorMessage = "快捷键注册失败，请更换组合"
            return
        }

        selectedHotKeyStorageValue = pendingHotKey.storageValue
        displayedHotKeyValue = pendingHotKey.displayName
        hotKeyErrorMessage = ""
    }

    private func chooseSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "选择"
        panel.message = "选择截图 PNG 的保存目录"

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
