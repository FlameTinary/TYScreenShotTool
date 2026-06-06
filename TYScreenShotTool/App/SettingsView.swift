//
//  SettingsView.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/6.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)

            Text("当前版本仅提供最小设置入口，以下配置项将在后续 Sprint 中逐步实现。")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                settingPlaceholder(title: "HotKey 配置")
                settingPlaceholder(title: "保存目录配置")
                settingPlaceholder(title: "OCR 开关")
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 260, alignment: .topLeading)
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
