//
//  SettingsViewController.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/22.
//

import AppKit
import SnapKit

@MainActor
final class SettingsViewController: NSViewController {
    private let globalHotKeyService: GlobalHotKeyService

    private let scrollView = NSScrollView()
    private let contentStack = NSStackView()
    private let hotKeyField = HotKeyRecorderTextField()
    private let hotKeyErrorLabel = NSTextField(labelWithString: "")
    private let languagePopUp = NSPopUpButton()
    private let appearancePopUp = NSPopUpButton()
    private let aiVisionCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let saveDirectoryLabel = NSTextField(labelWithString: "")

    private var pendingHotKey: ScreenshotHotKey?
    private var previousHotKey: ScreenshotHotKey?

    init(globalHotKeyService: GlobalHotKeyService) {
        self.globalHotKeyService = globalHotKeyService
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
        buildLayout()
        bindActions()
        reloadValues()
    }
}

// MARK: - Layout

private extension SettingsViewController {
    func buildLayout() {
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 16

        let documentView = NSView()
        documentView.addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(24)
            make.width.equalToSuperview().offset(-48)
        }

        scrollView.documentView = documentView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func bindActions() {
        hotKeyField.onBeginRecording = { [weak self] in self?.beginHotKeyRecording() }
        hotKeyField.onCandidateChanged = { [weak self] candidate in self?.pendingHotKey = candidate }
        hotKeyField.onCommit = { [weak self] in self?.commitHotKey() }
        hotKeyField.onCancel = { [weak self] in self?.cancelHotKeyRecording() }

        languagePopUp.target = self
        languagePopUp.action = #selector(languageChanged)
        appearancePopUp.target = self
        appearancePopUp.action = #selector(appearanceChanged)
        aiVisionCheckbox.target = self
        aiVisionCheckbox.action = #selector(aiVisionChanged)
    }

    func reloadValues() {
        let storedHotKey = ScreenshotHotKey(
            storageValue: UserDefaults.standard.string(forKey: AppSettings.screenshotHotKeyKey)
                ?? AppSettings.screenshotHotKeyDefaultValue
        ) ?? .screenshot
        hotKeyField.resetRecordingState(displayedValue: storedHotKey.displayName)
        hotKeyErrorLabel.stringValue = ""
        saveDirectoryLabel.stringValue = currentSaveDirectoryPath
    }

    var currentSaveDirectoryPath: String {
        let path = UserDefaults.standard.string(forKey: AppSettings.saveDirectoryPathKey) ?? ""
        return path.isEmpty ? AppLocalization.text("settings.save.not_configured") : path
    }
}

// MARK: - Actions

private extension SettingsViewController {
    @objc func languageChanged() {
        let selected = AppLanguage.allCases[languagePopUp.indexOfSelectedItem]
        UserDefaults.standard.set(selected.storageValue, forKey: AppSettings.appLanguageKey)
    }

    @objc func appearanceChanged() {
        let selected = AppAppearance.allCases[appearancePopUp.indexOfSelectedItem]
        UserDefaults.standard.set(selected.storageValue, forKey: AppSettings.appAppearanceKey)
        AppThemeCoordinator.shared.applyCurrentAppearance()
    }

    @objc func aiVisionChanged() {
        UserDefaults.standard.set(
            aiVisionCheckbox.state == .on,
            forKey: AppSettings.aiUseVisionTextExtractionKey
        )
    }

    func beginHotKeyRecording() {
        let current = ScreenshotHotKey(
            storageValue: UserDefaults.standard.string(forKey: AppSettings.screenshotHotKeyKey)
                ?? AppSettings.screenshotHotKeyDefaultValue
        ) ?? .screenshot
        previousHotKey = current
        pendingHotKey = nil
        hotKeyField.isRecordingHotKey = true
    }

    func commitHotKey() {
        guard let pendingHotKey else {
            cancelHotKeyRecording()
            return
        }

        if globalHotKeyService.updateHotKey(pendingHotKey) {
            UserDefaults.standard.set(pendingHotKey.storageValue, forKey: AppSettings.screenshotHotKeyKey)
            hotKeyField.resetRecordingState(displayedValue: pendingHotKey.displayName)
            hotKeyErrorLabel.stringValue = ""
        } else {
            hotKeyErrorLabel.stringValue = AppLocalization.text("settings.hotkey.error.registration_failed")
            cancelHotKeyRecording()
        }
    }

    func cancelHotKeyRecording() {
        let fallback = previousHotKey ?? .screenshot
        hotKeyField.resetRecordingState(displayedValue: fallback.displayName)
        pendingHotKey = nil
    }

    func chooseSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = AppLocalization.text("settings.save.choose")
        panel.message = AppLocalization.text("settings.save.panel_message")

        let currentPath = UserDefaults.standard.string(forKey: AppSettings.saveDirectoryPathKey) ?? ""
        if currentPath.isEmpty == false {
            panel.directoryURL = URL(fileURLWithPath: currentPath, isDirectory: true)
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
            UserDefaults.standard.set(bookmarkData, forKey: AppSettings.saveDirectoryBookmarkDataKey)
            UserDefaults.standard.set(selectedDirectoryURL.path, forKey: AppSettings.saveDirectoryPathKey)
            saveDirectoryLabel.stringValue = selectedDirectoryURL.path
        } catch {
            print("Save directory bookmark creation failed: \(error.localizedDescription)")
        }
    }

    func clearSaveDirectory() {
        UserDefaults.standard.set("", forKey: AppSettings.saveDirectoryPathKey)
        UserDefaults.standard.set(Data(), forKey: AppSettings.saveDirectoryBookmarkDataKey)
        saveDirectoryLabel.stringValue = currentSaveDirectoryPath
    }
}
