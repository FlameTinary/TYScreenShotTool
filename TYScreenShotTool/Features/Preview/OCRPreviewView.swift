//
//  OCRPreviewView.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/22.
//

import SwiftUI

struct OCRPreviewView: View {
    let title: String
    let text: String
    let isCopyEnabled: Bool
    let copyTitle: String
    let cancelTitle: String
    let onCopy: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)

            ScrollView {
                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 10) {
                Spacer()

                Button(copyTitle, action: onCopy)
                    .disabled(isCopyEnabled == false)

                Button(cancelTitle, action: onCancel)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
