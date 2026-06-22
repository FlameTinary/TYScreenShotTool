//
//  AIAnalysisPreviewView.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/22.
//

import SwiftUI

enum AIAnalysisPreviewContent {
    case loading(message: String)
    case result(AIAnalysisResult)
    case error(title: String, message: String)
}

struct AIAnalysisPreviewView: View {
    let title: String
    let content: AIAnalysisPreviewContent
    let copyAllTitle: String
    let retryTitle: String
    let closeTitle: String
    let onCopyAll: (() -> Void)?
    let onCopySecondary: (() -> Void)?
    let onRetry: (() -> Void)?
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)

            statusContent

            buttonRow
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var statusContent: some View {
        switch content {
        case let .loading(message):
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        case let .error(title, message):
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case let .result(result):
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(result.statusTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    ForEach(Array(result.sections.enumerated()), id: \.offset) { _, section in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)

                            Text(section.content)
                                .font(.system(size: 13))
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var buttonRow: some View {
        ViewThatFits {
            horizontalButtonRow
            verticalButtonRow
        }
    }

    @ViewBuilder
    private var horizontalButtonRow: some View {
        HStack(spacing: 10) {
            Spacer()
            resultButtons
        }
    }

    @ViewBuilder
    private var resultButtons: some View {
        if case let .result(result) = content {
            Button(copyAllTitle) {
                onCopyAll?()
            }
            .disabled(onCopyAll == nil)
            .fixedSize()

            Button(result.mode.secondaryCopyButtonTitle) {
                onCopySecondary?()
            }
            .disabled(onCopySecondary == nil)
            .fixedSize()
        }

        if onRetry != nil {
            Button(retryTitle) {
                onRetry?()
            }
            .fixedSize()
        }

        Button(closeTitle, action: onClose)
            .fixedSize()
    }

    private var verticalButtonRow: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if case let .result(result) = content {
                HStack(spacing: 10) {
                    Spacer()

                    Button(copyAllTitle) {
                        onCopyAll?()
                    }
                    .disabled(onCopyAll == nil)
                    .fixedSize()

                    Button(result.mode.secondaryCopyButtonTitle) {
                        onCopySecondary?()
                    }
                    .disabled(onCopySecondary == nil)
                    .fixedSize()
                }
            }

            HStack(spacing: 10) {
                Spacer()

                if onRetry != nil {
                    Button(retryTitle) {
                        onRetry?()
                    }
                    .fixedSize()
                }

                Button(closeTitle, action: onClose)
                    .fixedSize()
            }
        }
    }
}
