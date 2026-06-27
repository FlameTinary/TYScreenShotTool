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

    private let contentStack = NSStackView()
    private let hotKeyField = HotKeyRecorderTextField()
    private let hotKeyErrorLabel = NSTextField(labelWithString: "")
    private let languagePopUp = NSPopUpButton()
    private let appearancePopUp = NSPopUpButton()
    private let aiVisionCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    #if DEBUG
    private let aiEntranceCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    #endif
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

extension SettingsViewController {
    func buildLayout() {
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 16
        contentStack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)

        view.addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let titleLabel = makeTitleLabel(AppLocalization.text("settings.title"))
        let descriptionLabel = makeDescriptionLabel(AppLocalization.text("settings.description"))
        let hotKeySection = makeHotKeySection()
        let languageSection = makeLanguageSection()
        let appearanceSection = makeAppearanceSection()
        let aiSection = makeAISection()
        #if DEBUG
        let aiEntranceSection = makeAIEntranceSection()
        #endif
        let saveSection = makeSaveDirectorySection()

        var contentSections: [NSView] = [
            titleLabel, descriptionLabel, hotKeySection, languageSection,
            appearanceSection, aiSection
        ]
        #if DEBUG
        contentSections.append(aiEntranceSection)
        #endif
        contentSections.append(saveSection)
        contentSections.forEach(contentStack.addArrangedSubview)

        // NSStackView .leading alignment does not stretch arranged subviews;
        // each section container fills the stack width explicitly.
        var widthSections: [NSView] = [
            hotKeySection, languageSection, appearanceSection, aiSection
        ]
        #if DEBUG
        widthSections.append(aiEntranceSection)
        #endif
        widthSections.append(saveSection)
        for section in widthSections {
            section.snp.makeConstraints { make in
                make.width.equalTo(contentStack.snp.width).offset(-48)
            }
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
        #if DEBUG
        aiEntranceCheckbox.target = self
        aiEntranceCheckbox.action = #selector(aiEntranceChanged)
        #endif
    }

    func reloadValues() {
        let storedHotKey = ScreenshotHotKey(
            storageValue: UserDefaults.standard.string(forKey: AppSettings.screenshotHotKeyKey)
                ?? AppSettings.screenshotHotKeyDefaultValue
        ) ?? .screenshot
        hotKeyField.resetRecordingState(displayedValue: storedHotKey.displayName)
        hotKeyErrorLabel.stringValue = ""

        let currentLanguage = AppLanguage(rawValue: UserDefaults.standard.string(forKey: AppSettings.appLanguageKey)
            ?? AppSettings.appLanguageDefaultValue) ?? .system
        languagePopUp.selectItem(at: AppLanguage.allCases.firstIndex(of: currentLanguage) ?? 0)

        let currentAppearance = AppAppearance(rawValue: UserDefaults.standard.string(forKey: AppSettings.appAppearanceKey)
            ?? AppSettings.appAppearanceDefaultValue) ?? .system
        appearancePopUp.selectItem(at: AppAppearance.allCases.firstIndex(of: currentAppearance) ?? 0)

        aiVisionCheckbox.state = UserDefaults.standard.bool(forKey: AppSettings.aiUseVisionTextExtractionKey) ? .on : .off
        #if DEBUG
        aiEntranceCheckbox.state = UserDefaults.standard.bool(forKey: AppSettings.showAIEntrancesKey) ? .on : .off
        #endif
        saveDirectoryLabel.stringValue = currentSaveDirectoryPath
    }

    func reloadLocalizedTexts() {
        let windowTitle = AppLocalization.text("window.settings.title")
        view.window?.title = windowTitle

        reloadValues()
        languagePopUp.removeAllItems()
        languagePopUp.addItems(withTitles: [
            AppLocalization.text("settings.language.option.system"),
            AppLocalization.text("settings.language.option.zh_hans"),
            AppLocalization.text("settings.language.option.en"),
            AppLocalization.text("settings.language.option.ja"),
            AppLocalization.text("settings.language.option.ko"),
            AppLocalization.text("settings.language.option.de"),
            AppLocalization.text("settings.language.option.fr"),
        ])
        let currentLanguage = AppLanguage(rawValue: UserDefaults.standard.string(forKey: AppSettings.appLanguageKey)
            ?? AppSettings.appLanguageDefaultValue) ?? .system
        languagePopUp.selectItem(at: AppLanguage.allCases.firstIndex(of: currentLanguage) ?? 0)

        appearancePopUp.removeAllItems()
        appearancePopUp.addItems(withTitles: [
            AppLocalization.text("settings.appearance.option.system"),
            AppLocalization.text("settings.appearance.option.light"),
            AppLocalization.text("settings.appearance.option.dark"),
        ])
        let currentAppearance = AppAppearance(rawValue: UserDefaults.standard.string(forKey: AppSettings.appAppearanceKey)
            ?? AppSettings.appAppearanceDefaultValue) ?? .system
        appearancePopUp.selectItem(at: AppAppearance.allCases.firstIndex(of: currentAppearance) ?? 0)

        hotKeyField.placeholderString = AppLocalization.text("settings.hotkey.placeholder")
        aiVisionCheckbox.title = AppLocalization.text("settings.ai.use_vision")
        #if DEBUG
        aiEntranceCheckbox.title = AppLocalization.text("settings.ai.show_entrances")
        #endif

        saveDirectoryLabel.stringValue = currentSaveDirectoryPath
    }

    var currentSaveDirectoryPath: String {
        let path = UserDefaults.standard.string(forKey: AppSettings.saveDirectoryPathKey) ?? ""
        return path.isEmpty ? AppLocalization.text("settings.save.not_configured") : path
    }
}

// MARK: - Section Builders

private extension SettingsViewController {
    func makeTitleLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        return label
    }

    func makeDescriptionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 0
        return label
    }

    func makeSectionTitle(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        return label
    }

    func makeSecondaryLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 0
        return label
    }

    func makeHotKeySection() -> NSView {
        let container = NSView()

        let sectionTitle = makeSectionTitle(AppLocalization.text("settings.hotkey.section"))
        let label = makeSecondaryLabel(AppLocalization.text("settings.hotkey.label"))

        hotKeyField.placeholderString = AppLocalization.text("settings.hotkey.placeholder")

        let helpLabel = makeSecondaryLabel(AppLocalization.text("settings.hotkey.help"))

        hotKeyErrorLabel.font = .systemFont(ofSize: 11)
        hotKeyErrorLabel.textColor = .systemRed
        hotKeyErrorLabel.maximumNumberOfLines = 0

        container.addSubview(sectionTitle)
        container.addSubview(label)
        container.addSubview(hotKeyField)
        container.addSubview(hotKeyErrorLabel)
        container.addSubview(helpLabel)

        sectionTitle.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        label.snp.makeConstraints { make in
            make.top.equalTo(sectionTitle.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
        }
        hotKeyField.snp.makeConstraints { make in
            make.top.equalTo(label.snp.bottom).offset(6)
            make.leading.equalToSuperview()
            make.width.equalTo(220)
            make.height.equalTo(28)
        }
        hotKeyErrorLabel.snp.makeConstraints { make in
            make.top.equalTo(hotKeyField.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview()
        }
        helpLabel.snp.makeConstraints { make in
            make.top.equalTo(hotKeyErrorLabel.snp.bottom).offset(4)
            make.leading.trailing.bottom.equalToSuperview()
        }

        return container
    }

    func makeLanguageSection() -> NSView {
        let container = NSView()

        let sectionTitle = makeSectionTitle(AppLocalization.text("settings.language.section"))
        let label = makeSecondaryLabel(AppLocalization.text("settings.language.label"))

        languagePopUp.removeAllItems()
        languagePopUp.addItems(withTitles: [
            AppLocalization.text("settings.language.option.system"),
            AppLocalization.text("settings.language.option.zh_hans"),
            AppLocalization.text("settings.language.option.en"),
            AppLocalization.text("settings.language.option.ja"),
            AppLocalization.text("settings.language.option.ko"),
            AppLocalization.text("settings.language.option.de"),
            AppLocalization.text("settings.language.option.fr"),
        ])

        container.addSubview(sectionTitle)
        container.addSubview(label)
        container.addSubview(languagePopUp)

        sectionTitle.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        label.snp.makeConstraints { make in
            make.top.equalTo(sectionTitle.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
        }
        languagePopUp.snp.makeConstraints { make in
            make.top.equalTo(label.snp.bottom).offset(6)
            make.leading.bottom.equalToSuperview()
            make.width.equalTo(240)
        }

        return container
    }

    func makeAppearanceSection() -> NSView {
        let container = NSView()

        let sectionTitle = makeSectionTitle(AppLocalization.text("settings.appearance.section"))
        let label = makeSecondaryLabel(AppLocalization.text("settings.appearance.label"))

        appearancePopUp.removeAllItems()
        appearancePopUp.addItems(withTitles: [
            AppLocalization.text("settings.appearance.option.system"),
            AppLocalization.text("settings.appearance.option.light"),
            AppLocalization.text("settings.appearance.option.dark"),
        ])

        container.addSubview(sectionTitle)
        container.addSubview(label)
        container.addSubview(appearancePopUp)

        sectionTitle.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        label.snp.makeConstraints { make in
            make.top.equalTo(sectionTitle.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
        }
        appearancePopUp.snp.makeConstraints { make in
            make.top.equalTo(label.snp.bottom).offset(6)
            make.leading.bottom.equalToSuperview()
            make.width.equalTo(240)
        }

        return container
    }

    func makeAISection() -> NSView {
        let container = NSView()

        let sectionTitle = makeSectionTitle(AppLocalization.text("settings.ai.section"))

        aiVisionCheckbox.title = AppLocalization.text("settings.ai.use_vision")

        let helpLabel = makeSecondaryLabel(AppLocalization.text("settings.ai.help"))

        container.addSubview(sectionTitle)
        container.addSubview(aiVisionCheckbox)
        container.addSubview(helpLabel)

        sectionTitle.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        aiVisionCheckbox.snp.makeConstraints { make in
            make.top.equalTo(sectionTitle.snp.bottom).offset(8)
            make.leading.equalToSuperview()
        }
        helpLabel.snp.makeConstraints { make in
            make.top.equalTo(aiVisionCheckbox.snp.bottom).offset(4)
            make.leading.trailing.bottom.equalToSuperview()
        }

        return container
    }

    #if DEBUG
    func makeAIEntranceSection() -> NSView {
        let container = NSView()

        let sectionTitle = makeSectionTitle(AppLocalization.text("settings.ai_entrance.section"))

        aiEntranceCheckbox.title = AppLocalization.text("settings.ai.show_entrances")

        let helpLabel = makeSecondaryLabel(AppLocalization.text("settings.ai_entrance.help"))

        container.addSubview(sectionTitle)
        container.addSubview(aiEntranceCheckbox)
        container.addSubview(helpLabel)

        sectionTitle.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        aiEntranceCheckbox.snp.makeConstraints { make in
            make.top.equalTo(sectionTitle.snp.bottom).offset(8)
            make.leading.equalToSuperview()
        }
        helpLabel.snp.makeConstraints { make in
            make.top.equalTo(aiEntranceCheckbox.snp.bottom).offset(4)
            make.leading.trailing.bottom.equalToSuperview()
        }

        return container
    }
    #endif

    func makeSaveDirectorySection() -> NSView {
        let container = NSView()

        let sectionTitle = makeSectionTitle(AppLocalization.text("settings.save.section"))

        saveDirectoryLabel.font = .systemFont(ofSize: 12)
        saveDirectoryLabel.textColor = .secondaryLabelColor
        saveDirectoryLabel.maximumNumberOfLines = 2

        let chooseButton = NSButton(
            title: AppLocalization.text("settings.save.choose"),
            target: self,
            action: #selector(handleChooseSaveDirectory)
        )
        let clearButton = NSButton(
            title: AppLocalization.text("settings.save.clear"),
            target: self,
            action: #selector(handleClearSaveDirectory)
        )

        let helpLabel = makeSecondaryLabel(AppLocalization.text("settings.save.help"))

        container.addSubview(sectionTitle)
        container.addSubview(saveDirectoryLabel)
        container.addSubview(chooseButton)
        container.addSubview(clearButton)
        container.addSubview(helpLabel)

        sectionTitle.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        saveDirectoryLabel.snp.makeConstraints { make in
            make.top.equalTo(sectionTitle.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
        }
        chooseButton.snp.makeConstraints { make in
            make.top.equalTo(saveDirectoryLabel.snp.bottom).offset(8)
            make.leading.equalToSuperview()
        }
        clearButton.snp.makeConstraints { make in
            make.centerY.equalTo(chooseButton)
            make.leading.equalTo(chooseButton.snp.trailing).offset(12)
        }
        helpLabel.snp.makeConstraints { make in
            make.top.equalTo(chooseButton.snp.bottom).offset(6)
            make.leading.trailing.bottom.equalToSuperview()
        }

        return container
    }
}

// MARK: - Actions

private extension SettingsViewController {
    @objc func languageChanged() {
        let selected = AppLanguage.allCases[languagePopUp.indexOfSelectedItem]
        UserDefaults.standard.set(selected.storageValue, forKey: AppSettings.appLanguageKey)
        NotificationCenter.default.post(name: .appLanguageDidChange, object: nil)
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

    #if DEBUG
    @objc func aiEntranceChanged() {
        UserDefaults.standard.set(
            aiEntranceCheckbox.state == .on,
            forKey: AppSettings.showAIEntrancesKey
        )
    }
    #endif

    @objc func handleChooseSaveDirectory() { chooseSaveDirectory() }
    @objc func handleClearSaveDirectory() { clearSaveDirectory() }

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

// MARK: - Notifications

extension Notification.Name {
    static let appLanguageDidChange = Notification.Name("appLanguageDidChange")
}
