//
//  SettingsView.swift
//  TYScreenShotTool
//
//  Created by Sheldon on 2026/6/6.
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

    init(globalHotKeyService: GlobalHotKeyService) {
        self.globalHotKeyService = globalHotKeyService
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)

            Text("当前版本提供截图快捷键与保存目录配置。")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                hotKeyPicker
                saveDirectoryPicker
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 460, minHeight: 360, alignment: .topLeading)
        .onChange(of: selectedHotKeyStorageValue) { _, newValue in
            guard let hotKey = ScreenshotHotKey(storageValue: newValue) else {
                return
            }

            if !globalHotKeyService.updateHotKey(hotKey) {
                selectedHotKeyStorageValue = AppSettings.screenshotHotKeyDefaultValue
            }
        }
    }

    private var hotKeyPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HotKey 配置")
                .font(.headline)

            Picker("截图快捷键", selection: $selectedHotKeyStorageValue) {
                ForEach(ScreenshotHotKey.presets, id: \.storageValue) { hotKey in
                    Text(hotKey.displayName)
                        .tag(hotKey.storageValue)
                }
            }
            .pickerStyle(.menu)

            Text("仅支持少量预设快捷键，修改后立即生效。")
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
}
