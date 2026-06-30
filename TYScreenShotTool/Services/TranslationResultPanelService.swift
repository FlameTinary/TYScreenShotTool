//
//  TranslationResultPanelService.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/27.
//

import AppKit
import SnapKit
import SwiftUI
import Translation

// MARK: - AppKit Window Service

/// 翻译结果浮动面板服务
///
/// 使用 AppKit NSPanel 承载 SwiftUI 翻译视图。
/// 翻译在 SwiftUI `.translationTask` 中完成。
@MainActor
final class TranslationResultPanelService {
    private let panel = NSPanel(
        contentRect: .zero,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    private let containerView = NSVisualEffectView()
    private var hostingController: NSHostingController<TranslationResultSwiftUIView>?

    init() {
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false

        containerView.material = .popover
        containerView.blendingMode = .withinWindow
        containerView.state = .active
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 14
        containerView.layer?.borderWidth = 1

        panel.contentView = containerView

        AppThemeCoordinator.shared.registerRefreshHandler(for: self) { [weak self] in
            self?.applyAppearanceStyling()
        }
        applyAppearanceStyling()
    }

    deinit {
        let ownerID = ObjectIdentifier(self)
        Task { @MainActor in
            AppThemeCoordinator.shared.unregisterRefreshHandler(for: ownerID)
        }
    }

    /// 打开翻译窗口，在 SwiftUI 内部执行翻译
    ///
    /// - Parameters:
    ///   - sourceText: OCR 识别出的原文
    ///   - selectionRect: 选择区域
    ///   - onCopySource: 复制原文回调
    ///   - onCopyTarget: 复制译文回调
    ///   - onClose: 关闭回调
    func presentTranslating(
        sourceText: String,
        selectionRect: CGRect,
        onCopySource: @escaping (String) -> Void,
        onCopyTarget: @escaping (String) -> Void,
        onClose: @escaping () -> Void
    ) {
        guard let screen = screenContaining(selectionRect) else {
            dismiss()
            return
        }

        let swiftUIView = TranslationResultSwiftUIView(
            sourceText: sourceText,
            onCopySource: onCopySource,
            onCopyTarget: onCopyTarget,
            onClose: { [weak self] in
                self?.dismiss()
                onClose()
            }
        )

        let hostingController = NSHostingController(rootView: swiftUIView)
        self.hostingController = hostingController
        hostingController.view.wantsLayer = true

        // 替换 containerView 中的所有子视图
        containerView.subviews.forEach { $0.removeFromSuperview() }
        containerView.addSubview(hostingController.view)
        hostingController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let panelFrame = frame(for: selectionRect, on: screen)
        AppThemeCoordinator.shared.applyCurrentAppearance(to: panel)
        panel.setFrame(panelFrame, display: true)
        applyAppearanceStyling()
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 直接展示已翻译的文本（用于中文文本等无需翻译的场景）
    func presentResult(
        sourceText: String,
        translatedText: String,
        selectionRect: CGRect,
        onCopySource: @escaping (String) -> Void,
        onCopyTarget: @escaping (String) -> Void,
        onClose: @escaping () -> Void
    ) {
        guard let screen = screenContaining(selectionRect) else {
            dismiss()
            return
        }

        let swiftUIView = TranslationResultSwiftUIView(
            sourceText: sourceText,
            preTranslatedText: translatedText,
            onCopySource: onCopySource,
            onCopyTarget: onCopyTarget,
            onClose: { [weak self] in
                self?.dismiss()
                onClose()
            }
        )

        let hostingController = NSHostingController(rootView: swiftUIView)
        self.hostingController = hostingController

        containerView.subviews.forEach { $0.removeFromSuperview() }
        containerView.addSubview(hostingController.view)
        hostingController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let panelFrame = frame(for: selectionRect, on: screen)
        AppThemeCoordinator.shared.applyCurrentAppearance(to: panel)
        panel.setFrame(panelFrame, display: true)
        applyAppearanceStyling()
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        TYLogger.debug("translation window will close", tag: "LocalTranslation")
        panel.close()
        hostingController = nil
        TYLogger.debug("translation window closed", tag: "LocalTranslation")
    }

    // MARK: - Private

    private func applyAppearanceStyling() {
        containerView.material = .popover
        containerView.layer?.borderColor = NSColor.separatorColor.cgColor
    }

    private func frame(for selectionRect: CGRect, on screen: NSScreen) -> CGRect {
        let visibleFrame = screen.visibleFrame
        let outerMargin: CGFloat = 24
        let gap: CGFloat = 20
        let minWidth: CGFloat = 300
        let maxWidth: CGFloat = 440
        let minHeight: CGFloat = 340
        let maxHeight: CGFloat = 520

        let leftAvailableWidth = selectionRect.minX - visibleFrame.minX - gap
        let rightAvailableWidth = visibleFrame.maxX - selectionRect.maxX - gap
        let leftEffectiveWidth = max(leftAvailableWidth - outerMargin, 0)
        let rightEffectiveWidth = max(rightAvailableWidth - outerMargin, 0)
        let placeOnLeft = leftAvailableWidth >= rightAvailableWidth

        let availableWidth = placeOnLeft ? leftEffectiveWidth : rightEffectiveWidth
        let availableHeight = max(visibleFrame.height - outerMargin * 2, 0)

        let panelWidth = min(max(max(availableWidth, minWidth), minWidth), maxWidth)
        let panelHeight = min(max(max(availableHeight * 0.5, minHeight), minHeight), maxHeight)

        let panelX: CGFloat
        if placeOnLeft {
            panelX = max(visibleFrame.minX + outerMargin, selectionRect.minX - gap - panelWidth)
        } else {
            panelX = min(visibleFrame.maxX - outerMargin - panelWidth, selectionRect.maxX + gap)
        }

        let panelY = min(
            max(selectionRect.midY - panelHeight / 2, visibleFrame.minY + outerMargin),
            visibleFrame.maxY - outerMargin - panelHeight
        )

        return CGRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight)
    }

    private func screenContaining(_ rect: CGRect) -> NSScreen? {
        NSScreen.screens.first { screen in
            screen.frame.contains(CGPoint(x: rect.midX, y: rect.midY))
        }
    }
}

// MARK: - Translation Target Language

/// 支持的翻译目标语言
enum TranslationTargetLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese
    case english
    case japanese
    case korean
    case traditionalChinese

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .simplifiedChinese: return "简体中文"
        case .english: return "English"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .traditionalChinese: return "繁體中文"
        }
    }

    var languageIdentifier: String {
        switch self {
        case .simplifiedChinese: return "zh-Hans"
        case .english: return "en"
        case .japanese: return "ja"
        case .korean: return "ko"
        case .traditionalChinese: return "zh-Hant"
        }
    }

    var localeLanguage: Locale.Language {
        Locale.Language(identifier: languageIdentifier)
    }
}

// MARK: - SwiftUI Translation View

/// SwiftUI 翻译视图
///
/// 负责：
/// 1. 展示原文
/// 2. 使用 `.translationTask` 执行翻译
/// 3. 展示译文/加载/错误状态
/// 4. 复制原文/译文、关闭
struct TranslationResultSwiftUIView: View {
    let sourceText: String
    let onCopySource: (String) -> Void
    let onCopyTarget: (String) -> Void
    let onClose: () -> Void

    /// 预置译文（用于中文文本等直接展示，不触发翻译流程）
    private let preTranslatedText: String?

    @State private var selectedTargetLanguage: TranslationTargetLanguage = .simplifiedChinese
    @State private var configuration: TranslationSession.Configuration?
    @State private var sourceLanguage: Locale.Language?
    @State private var translatedText: String = ""
    @State private var isTranslating: Bool = false
    @State private var errorMessage: String?
    @State private var currentRequestID = UUID()
    @State private var copySourceFeedback: Bool = false
    @State private var copyTargetFeedback: Bool = false

    /// 创建翻译视图
    /// - Parameters:
    ///   - sourceText: OCR 原文
    ///   - preTranslatedText: 预置译文（可选，不为 nil 时跳过翻译）
    ///   - onCopySource: 复制原文
    ///   - onCopyTarget: 复制译文
    ///   - onClose: 关闭
    init(
        sourceText: String,
        preTranslatedText: String? = nil,
        onCopySource: @escaping (String) -> Void,
        onCopyTarget: @escaping (String) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.sourceText = sourceText
        self.preTranslatedText = preTranslatedText
        self.onCopySource = onCopySource
        self.onCopyTarget = onCopyTarget
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            titleBar

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // 原文区域
                    sourceSection

                    Divider()

                    // 目标语言选择器
                    languagePickerSection

                    Divider()

                    // 译文区域
                    targetSection
                }
                .padding(.horizontal, 16)
            }

            Divider()

            // 底部操作栏
            bottomBar
        }
        .translationTask(configuration) { session in
            await performTranslation(session)
        }
        .onAppear {
            setupInitialTranslation()
        }
        .onChange(of: selectedTargetLanguage) { _, _ in
            rebuildTranslationConfiguration()
        }
        .onDisappear {
            TYLogger.debug("translation view disappeared", tag: "LocalTranslation")
        }
    }

    // MARK: - Translation Setup

    private func setupInitialTranslation() {
        TYLogger.debug("translation view appeared", tag: "LocalTranslation")
        TYLogger.debug("source text count: \(sourceText.count)", tag: "LocalTranslation")

        // 如果已经有预置译文，不启动翻译
        if preTranslatedText != nil {
            translatedText = preTranslatedText!
            return
        }

        rebuildTranslationConfiguration()
    }

    private func rebuildTranslationConfiguration() {
        let trimmedText = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            errorMessage = AppLocalization.text("translate.empty_text")
            translatedText = ""
            isTranslating = false
            configuration = nil
            return
        }

        TYLogger.debug("rebuild configuration", tag: "LocalTranslation")
        TYLogger.debug("selected target language: \(selectedTargetLanguage.languageIdentifier)", tag: "LocalTranslation")

        // Reset state for new translation
        translatedText = ""
        errorMessage = nil
        isTranslating = true
        currentRequestID = UUID()

        let detectedSource = LocalTranslationService.fallbackSourceLanguage(for: trimmedText)
        sourceLanguage = detectedSource

        TYLogger.debug("source language: \(detectedSource?.languageCode?.identifier ?? "nil")", tag: "LocalTranslation")
        TYLogger.debug("target language: \(selectedTargetLanguage.languageIdentifier)", tag: "LocalTranslation")

        // 同语言无需翻译
        if isSameLanguage(source: detectedSource, target: selectedTargetLanguage) {
            isTranslating = false
            translatedText = "识别内容已是目标语言，无需翻译。"
            configuration = nil
            return
        }

        // 启动翻译
        configuration = TranslationSession.Configuration(
            source: detectedSource,
            target: selectedTargetLanguage.localeLanguage
        )
        TYLogger.debug("configuration created, requestID: \(currentRequestID)", tag: "LocalTranslation")
    }

    /// 判断源语言和目标语言是否相同（避免无意义翻译）
    private func isSameLanguage(source: Locale.Language?, target: TranslationTargetLanguage) -> Bool {
        guard let source else { return false }
        let sourceCode = source.languageCode?.identifier
        let targetCode = target.localeLanguage.languageCode?.identifier
        guard let sourceCode, let targetCode else { return false }

        guard sourceCode == targetCode else { return false }

        // 中文变体处理：fallback 返回 zh-Hans
        // zh-Hans → zh-Hant 应允许翻译
        if sourceCode == "zh" {
            return target.languageIdentifier == "zh-Hans"
        }

        return true
    }

    // MARK: - Translation

    @MainActor
    private func performTranslation(_ session: TranslationSession) async {
        let requestID = currentRequestID
        TYLogger.debug("translationTask started, requestID: \(requestID)", tag: "LocalTranslation")

        let trimmedText = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            errorMessage = AppLocalization.text("translate.empty_text")
            isTranslating = false
            return
        }

        isTranslating = true
        errorMessage = nil

        do {
            if sourceLanguage != nil {
                TYLogger.debug("prepareTranslation started", tag: "LocalTranslation")
                try await session.prepareTranslation()
                TYLogger.debug("prepareTranslation finished", tag: "LocalTranslation")
            } else {
                TYLogger.debug("skip prepareTranslation because source language is nil", tag: "LocalTranslation")
            }

            TYLogger.debug("translate started", tag: "LocalTranslation")
            let response = try await session.translate(trimmedText)
            TYLogger.debug("translate finished", tag: "LocalTranslation")
            TYLogger.debug("translated text count: \(response.targetText.count)", tag: "LocalTranslation")

            // 防止旧任务覆盖新结果
            guard requestID == currentRequestID else {
                TYLogger.debug("ignore stale translation result", tag: "LocalTranslation")
                return
            }

            translatedText = response.targetText
        } catch {
            TYLogger.error("translation failed", tag: "LocalTranslation", error: error)
            let nsError = error as NSError
            TYLogger.debug("error domain: \(nsError.domain)", tag: "LocalTranslation")
            TYLogger.debug("error code: \(nsError.code)", tag: "LocalTranslation")
            TYLogger.debug("error: \(nsError)", tag: "LocalTranslation")

            // 防止旧任务覆盖新结果
            guard requestID == currentRequestID else {
                TYLogger.debug("ignore stale translation error", tag: "LocalTranslation")
                return
            }

            errorMessage = LocalTranslationService.userFriendlyMessage(for: error)
        }

        isTranslating = false
    }

    // MARK: - UI Components

    private var titleBar: some View {
        HStack {
            Text(AppLocalization.text("translate.window.title"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(AppLocalization.text("translate.source_text"))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            ScrollView([.vertical]) {
                Text(sourceText)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 120)
            .padding(8)
            .background(Color(.textBackgroundColor))
            .cornerRadius(6)
        }
    }

    private var languagePickerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("目标语言")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            Picker("目标语言", selection: $selectedTargetLanguage) {
                ForEach(TranslationTargetLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var targetSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(AppLocalization.text("translate.target_text"))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            if isTranslating {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(AppLocalization.text("translate.loading"))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(6)
            } else {
                ScrollView([.vertical]) {
                    Text(translatedText)
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 120)
                .padding(8)
                .background(Color(.textBackgroundColor))
                .cornerRadius(6)
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            // 复制原文
            Button(action: {
                onCopySource(sourceText)
                copySourceFeedback = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    copySourceFeedback = false
                }
            }) {
                Text(copySourceFeedback ? AppLocalization.text("translate.copied") : AppLocalization.text("translate.copy_source"))
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)

            // 复制译文（翻译完成且有译文时启用）
            Button(action: {
                onCopyTarget(translatedText)
                copyTargetFeedback = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    copyTargetFeedback = false
                }
            }) {
                Text(copyTargetFeedback ? AppLocalization.text("translate.copied") : AppLocalization.text("translate.copy_target"))
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .disabled(translatedText.isEmpty || isTranslating || errorMessage != nil)

            Spacer()

            // 关闭
            Button(action: onClose) {
                Text(AppLocalization.text("translate.close"))
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.escape)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
