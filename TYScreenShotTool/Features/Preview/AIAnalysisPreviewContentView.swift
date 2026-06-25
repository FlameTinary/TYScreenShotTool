//
//  AIAnalysisPreviewContentView.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/22.
//

import AppKit
import SnapKit

enum AIAnalysisPreviewContent {
    case loading(message: String)
    case error(title: String, message: String)
    case result(AIAnalysisResult)
}

@MainActor
final class AIAnalysisPreviewContentView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let scrollView = NSScrollView()
    private let bodyStack = NSStackView()
    private let copyAllButton = NSButton(title: "", target: nil, action: nil)
    private let secondaryButton = NSButton(title: "", target: nil, action: nil)
    private let retryButton = NSButton(title: "", target: nil, action: nil)
    private let closeButton = NSButton(title: "", target: nil, action: nil)
    private let topButtonRow = NSStackView()
    private let bottomButtonRow = NSStackView()

    var onCopyAll: (() -> Void)?
    var onCopySecondary: (() -> Void)?
    var onRetry: (() -> Void)?
    var onClose: (() -> Void)?

    private var currentContent: AIAnalysisPreviewContent = .loading(message: "")
    private var hasSecondary: Bool = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        copyAllButton.target = self
        copyAllButton.action = #selector(handleCopyAll)
        secondaryButton.target = self
        secondaryButton.action = #selector(handleCopySecondary)
        retryButton.target = self
        retryButton.action = #selector(handleRetry)
        closeButton.target = self
        closeButton.action = #selector(handleClose)
    }

    func configure(
        title: String,
        content: AIAnalysisPreviewContent,
        copyAllTitle: String,
        secondaryTitle: String?,
        retryTitle: String,
        closeTitle: String
    ) {
        currentContent = content
        titleLabel.stringValue = title
        copyAllButton.title = copyAllTitle
        secondaryButton.title = secondaryTitle ?? ""
        retryButton.title = retryTitle
        closeButton.title = closeTitle

        switch content {
        case .result:
            hasSecondary = true
            secondaryButton.isHidden = false
        default:
            hasSecondary = false
            secondaryButton.isHidden = true
        }

        rebuildBody()
        arrangeButtons()
    }

    @objc private func handleCopyAll() { onCopyAll?() }
    @objc private func handleCopySecondary() { onCopySecondary?() }
    @objc private func handleRetry() { onRetry?() }
    @objc private func handleClose() { onClose?() }
}

// MARK: - Layout

private extension AIAnalysisPreviewContentView {
    func buildLayout() {
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)

        bodyStack.translatesAutoresizingMaskIntoConstraints = false
        bodyStack.orientation = .vertical
        bodyStack.spacing = 12
        bodyStack.alignment = .leading

        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.documentView = bodyStack

        topButtonRow.orientation = .horizontal
        topButtonRow.spacing = 10
        topButtonRow.alignment = .centerY

        bottomButtonRow.orientation = .horizontal
        bottomButtonRow.spacing = 10
        bottomButtonRow.alignment = .centerY

        addSubview(titleLabel)
        addSubview(scrollView)
        addSubview(topButtonRow)
        addSubview(bottomButtonRow)

        titleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
        }
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        topButtonRow.snp.makeConstraints { make in
            make.top.equalTo(scrollView.snp.bottom).offset(8)
            make.trailing.equalToSuperview().inset(16)
        }
        bottomButtonRow.snp.makeConstraints { make in
            make.top.equalTo(topButtonRow.snp.bottom).offset(6)
            make.trailing.bottom.equalToSuperview().inset(16)
        }
    }

    func rebuildBody() {
        bodyStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        switch currentContent {
        case let .loading(message):
            let label = NSTextField(labelWithString: message)
            label.font = .systemFont(ofSize: 13, weight: .medium)
            label.textColor = .secondaryLabelColor
            bodyStack.addArrangedSubview(label)

        case let .error(title, message):
            let titleField = NSTextField(labelWithString: title)
            titleField.font = .systemFont(ofSize: 13, weight: .medium)
            titleField.textColor = .secondaryLabelColor

            let messageField = NSTextField(labelWithString: message)
            messageField.font = .systemFont(ofSize: 13)
            messageField.maximumNumberOfLines = 0

            bodyStack.addArrangedSubview(titleField)
            bodyStack.addArrangedSubview(messageField)

        case let .result(result):
            let statusLabel = NSTextField(labelWithString: result.statusTitle)
            statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
            statusLabel.textColor = .secondaryLabelColor
            bodyStack.addArrangedSubview(statusLabel)

            for section in result.sections {
                let sectionTitle = NSTextField(labelWithString: section.title)
                sectionTitle.font = .systemFont(ofSize: 13, weight: .semibold)

                let sectionContent = NSTextField(labelWithString: section.content)
                sectionContent.font = .systemFont(ofSize: 13)
                sectionContent.maximumNumberOfLines = 0

                bodyStack.addArrangedSubview(sectionTitle)
                bodyStack.addArrangedSubview(sectionContent)
            }
        }
    }

    func arrangeButtons() {
        topButtonRow.setViews([], in: .trailing)
        bottomButtonRow.setViews([], in: .trailing)

        let narrow = bounds.width < 340

        if narrow {
            if hasSecondary {
                topButtonRow.setViews([copyAllButton, secondaryButton], in: .trailing)
            } else {
                topButtonRow.setViews([copyAllButton], in: .trailing)
            }

            var bottomViews: [NSView] = []
            if onRetry != nil {
                bottomViews.append(retryButton)
            }
            bottomViews.append(closeButton)
            bottomButtonRow.setViews(bottomViews, in: .trailing)
        } else {
            var allButtons: [NSView] = []
            if hasSecondary {
                allButtons.append(contentsOf: [copyAllButton, secondaryButton])
            } else {
                allButtons.append(copyAllButton)
            }
            if onRetry != nil {
                allButtons.append(retryButton)
            }
            allButtons.append(closeButton)
            topButtonRow.setViews(allButtons, in: .trailing)
        }
    }
}
