//
//  ScrollingCaptureControlPanelView.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/22.
//

import SwiftUI

struct ScrollingCaptureControlPanelView: View {
    let isOCREnabled: Bool
    let isAIEnabled: Bool
    let onCancel: () -> Void
    let onOCR: () -> Void
    let onAISelected: (AIAnalysisMode) -> Void
    let onSave: () -> Void
    let onCopy: () -> Void

    @State private var isAIPopoverPresented = false

    var body: some View {
        ViewThatFits {
            horizontalButtons
            compactButtonRows
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var horizontalButtons: some View {
        HStack(spacing: 10) {
            actionButton(title: AppText.captureCancel, action: onCancel)
            actionButton(title: "OCR", isEnabled: isOCREnabled, action: onOCR)
            aiButton
            actionButton(title: AppText.captureSave, action: onSave)
            actionButton(title: AppText.captureCopy, action: onCopy)
        }
    }

    private var compactButtonRows: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                actionButton(title: AppText.captureCancel, action: onCancel)
                actionButton(title: "OCR", isEnabled: isOCREnabled, action: onOCR)
                aiButton
            }

            HStack(spacing: 10) {
                actionButton(title: AppText.captureSave, action: onSave)
                actionButton(title: AppText.captureCopy, action: onCopy)
            }
        }
    }

    private var aiButton: some View {
        Button {
            isAIPopoverPresented.toggle()
        } label: {
            Text("AI")
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(ScrollingCapturePanelButtonStyle())
        .disabled(isAIEnabled == false)
        .popover(isPresented: $isAIPopoverPresented, arrowEdge: .top) {
            ScrollingCaptureAIPopoverView { mode in
                isAIPopoverPresented = false
                onAISelected(mode)
            }
        }
    }

    private func actionButton(
        title: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(ScrollingCapturePanelButtonStyle())
        .disabled(isEnabled == false)
    }
}

private struct ScrollingCapturePanelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .frame(minHeight: 28)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed ? Color.primary.opacity(0.10) : Color.clear)
            )
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}
