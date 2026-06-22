//
//  ScrollingCaptureAIPopoverView.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/22.
//

import SwiftUI

struct ScrollingCaptureAIPopoverView: View {
    let onSelect: (AIAnalysisMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(AIAnalysisMode.topLevelModes.enumerated()), id: \.offset) { _, mode in
                    modeButton(title: mode.menuTitle) {
                        onSelect(mode)
                    }
                }
            }

            Divider()

            Text(AppText.aiTranslationMenu)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(AITranslationLanguage.allCases.enumerated()), id: \.offset) { _, language in
                    modeButton(title: language.menuTitle) {
                        onSelect(.translation(language))
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 220, alignment: .leading)
    }

    private func modeButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.06))
        )
    }
}
