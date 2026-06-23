//
//  ScrollingCapturePreviewContentView.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/22.
//

import AppKit
import SnapKit

enum ScrollingCapturePreviewContent {
    case preparing(title: String, message: String)
    case image(NSImage)
}

@MainActor
final class ScrollingCapturePreviewContentView: NSView {
    private let imageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let messageLabel = NSTextField(labelWithString: "")
    // private let badgeLabel = NSTextField(labelWithString: AppText.captureLongCapture)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(content: ScrollingCapturePreviewContent) {
        switch content {
        case let .preparing(title, message):
            imageView.image = nil
            imageView.isHidden = true
//            badgeLabel.isHidden = true
            titleLabel.stringValue = title
            messageLabel.stringValue = message
        case let .image(image):
            imageView.image = image
            imageView.isHidden = false
//            badgeLabel.isHidden = false
            titleLabel.stringValue = ""
            messageLabel.stringValue = ""
        }
    }
}

// MARK: - Layout

private extension ScrollingCapturePreviewContentView {
    func buildLayout() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        messageLabel.font = .systemFont(ofSize: 12)
        messageLabel.textColor = .secondaryLabelColor
        messageLabel.maximumNumberOfLines = 0
        messageLabel.alignment = .center

        // badgeLabel.font = .systemFont(ofSize: 11, weight: .medium)
        // badgeLabel.textColor = .secondaryLabelColor
        // badgeLabel.isBordered = false
        // badgeLabel.drawsBackground = false

        addSubview(imageView)
        addSubview(titleLabel)
        addSubview(messageLabel)
        // addSubview(badgeLabel)

        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(12)
            make.trailing.lessThanOrEqualToSuperview().offset(-12)
        }
        messageLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(12)
        }
        // badgeLabel.snp.makeConstraints { make in
        //     make.top.leading.equalToSuperview().inset(8)
        // }
    }
}
