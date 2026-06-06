//
//  SettingsView.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/6.
//

import SwiftUI

struct SettingsView: View {
    private let globalHotKeyService: GlobalHotKeyService

    @AppStorage(AppSettings.isOCREnabledKey)
    private var isOCREnabled = AppSettings.isOCREnabledDefaultValue
    @AppStorage(AppSettings.screenshotHotKeyKey)
    private var selectedHotKeyStorageValue = AppSettings.screenshotHotKeyDefaultValue

    init(globalHotKeyService: GlobalHotKeyService) {
        self.globalHotKeyService = globalHotKeyService
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)

            Text("当前版本仅提供最小设置入口，以下配置项将在后续 Sprint 中逐步实现。")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                hotKeyPicker
                settingPlaceholder(title: "保存目录配置")
                ocrToggle
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 260, alignment: .topLeading)
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
        }
    }

    private var ocrToggle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("OCR 开关", isOn: $isOCREnabled)
                .font(.headline)

            Text(isOCREnabled ? "截图后将自动执行 OCR。" : "截图后将跳过 OCR。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func settingPlaceholder(title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text("Planned for a future Sprint.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
