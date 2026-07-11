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
    #if DEBUG
    private let aiVisionCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    #endif
    #if DEBUG
    private let aiEntranceCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let debugStorefrontCodeField = NSTextField()
    #endif
    private let saveDirectoryLabel = NSTextField(labelWithString: "")

    // MARK: - AI Pro Login Section

    private let loginStatusLabel = NSTextField(labelWithString: "")
    private let subscriptionInfoLabel = NSTextField(labelWithString: "")
    private let loginActionButton = NSButton(title: "", target: nil, action: nil)
    private let subscriptionActionsStack = NSStackView()
    private let subscribeButton = NSButton(title: "", target: nil, action: nil)
    private let restoreSubscriptionButton = NSButton(title: "", target: nil, action: nil)

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
        #if DEBUG
        let aiSection = makeAISection()
        #endif
        #if DEBUG
        let aiEntranceSection = makeAIEntranceSection()
        let debugRegionPolicySection = makeDebugRegionPolicySection()
        #endif
        let saveSection = makeSaveDirectorySection()
        let loginSection = makeLoginSection()

        var contentSections: [NSView] = [
            titleLabel, descriptionLabel, hotKeySection, languageSection,
            appearanceSection, loginSection
        ]
        #if DEBUG
        contentSections.append(aiSection)
        contentSections.append(aiEntranceSection)
        contentSections.append(debugRegionPolicySection)
        #endif
        contentSections.append(saveSection)
        contentSections.forEach(contentStack.addArrangedSubview)

        // NSStackView .leading alignment does not stretch arranged subviews;
        // each section container fills the stack width explicitly.
        var widthSections: [NSView] = [
            hotKeySection, languageSection, appearanceSection, loginSection
        ]
        #if DEBUG
        widthSections.append(aiSection)
        widthSections.append(aiEntranceSection)
        widthSections.append(debugRegionPolicySection)
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
        subscribeButton.target = self
        subscribeButton.action = #selector(handleSubscribeAction)
        restoreSubscriptionButton.target = self
        restoreSubscriptionButton.action = #selector(handleRestoreSubscriptionAction)
        #if DEBUG
        aiVisionCheckbox.target = self
        aiVisionCheckbox.action = #selector(aiVisionChanged)
        #endif
        #if DEBUG
        aiEntranceCheckbox.target = self
        aiEntranceCheckbox.action = #selector(aiEntranceChanged)
        debugStorefrontCodeField.target = self
        debugStorefrontCodeField.action = #selector(debugStorefrontOverrideChanged)
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

        #if DEBUG
        aiVisionCheckbox.state = UserDefaults.standard.bool(forKey: AppSettings.aiUseVisionTextExtractionKey) ? .on : .off
        #endif
        #if DEBUG
        aiEntranceCheckbox.state = AppSettings.boolValue(
            forKey: AppSettings.showAIEntrancesKey,
            defaultValue: AppSettings.showAIEntrancesDefaultValue
        ) ? .on : .off
        debugStorefrontCodeField.stringValue = UserDefaults.standard.string(
            forKey: AppSettings.debugStorefrontCodeOverrideKey
        ) ?? ""
        #endif
        saveDirectoryLabel.stringValue = currentSaveDirectoryPath
        reloadLoginStatus()
    }

    func reloadLoginStatus() {
        guard AIAvailabilityService().isSubscriptionAllowed else {
            loginStatusLabel.stringValue = AppText.settingsLoginNotAvailable
            subscriptionInfoLabel.isHidden = true
            loginActionButton.isHidden = true
            subscribeButton.isHidden = true
            restoreSubscriptionButton.isHidden = true
            return
        }

        subscriptionInfoLabel.isHidden = false
        subscriptionInfoLabel.stringValue = AppText.settingsSubscriptionInfo
        loginActionButton.isHidden = false

        if AIProSessionManager.shared.isSignedIn {
            let userID = AIProSessionManager.shared.currentUserID ?? "--"
            loginStatusLabel.textColor = .labelColor
            loginActionButton.title = AppText.settingsSignOut
            loginActionButton.action = #selector(handleLoginAction)
            renderSignedInStatus(
                userID: userID,
                subscriptionStatus: AIProSubscriptionService.shared.status
            )

            if AIProSubscriptionService.shared.status.needsNetworkRefresh {
                Task {
                    let status = await AIProSubscriptionService.shared.refreshStatus()
                    guard AIProSessionManager.shared.isSignedIn else {
                        return
                    }
                    let userID = AIProSessionManager.shared.currentUserID ?? "--"
                    renderSignedInStatus(userID: userID, subscriptionStatus: status)
                }
            }
        } else {
            loginStatusLabel.stringValue = ""
            loginActionButton.title = AppText.aiProLoginButton
            loginActionButton.action = #selector(handleLoginAction)
            subscribeButton.isHidden = true
            restoreSubscriptionButton.isHidden = true
        }
    }

    func renderSignedInStatus(userID: String, subscriptionStatus: AIProSubscriptionStatus) {
        let statusText: String
        switch subscriptionStatus {
        case .notLoaded:
            statusText = AppText.settingsSubscriptionChecking
        case .loading:
            statusText = AppText.settingsSubscriptionChecking
        case .regionUnavailable:
            statusText = AppText.settingsLoginNotAvailable
        case .unavailable:
            statusText = AppText.aiProSubscriptionUnavailableMessage
        case .unsubscribed:
            statusText = AppText.settingsSubscriptionNone
        case .subscribed:
            statusText = AppText.settingsSubscriptionActive
        case .failed:
            statusText = AppText.settingsSubscriptionFetchFailed
        }

        loginStatusLabel.stringValue = "\(AppText.settingsSignedInAs(userID))\n\(statusText)"
        subscribeButton.title = AppText.settingsSubscribe
        subscribeButton.isHidden = !subscriptionStatus.canStartPurchase
        restoreSubscriptionButton.title = AppText.settingsRestoreSubscription
        restoreSubscriptionButton.isHidden = !subscriptionStatus.canStartRestore
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
        #if DEBUG
        aiVisionCheckbox.title = AppLocalization.text("settings.ai.use_vision")
        #endif
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

    #if DEBUG
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
    #endif

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

    #if DEBUG
    func makeDebugRegionPolicySection() -> NSView {
        let container = NSView()

        let sectionTitle = makeSectionTitle(AppLocalization.text("settings.region_policy.section"))
        let helpLabel = makeSecondaryLabel(AppLocalization.text("settings.region_policy.help"))
        let applyButton = NSButton(
            title: AppLocalization.text("settings.region_policy.apply"),
            target: self,
            action: #selector(debugStorefrontOverrideChanged)
        )

        debugStorefrontCodeField.placeholderString = AppLocalization.text("settings.region_policy.placeholder")

        container.addSubview(sectionTitle)
        container.addSubview(debugStorefrontCodeField)
        container.addSubview(applyButton)
        container.addSubview(helpLabel)

        sectionTitle.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        debugStorefrontCodeField.snp.makeConstraints { make in
            make.top.equalTo(sectionTitle.snp.bottom).offset(8)
            make.leading.equalToSuperview()
            make.width.equalTo(160)
        }
        applyButton.snp.makeConstraints { make in
            make.centerY.equalTo(debugStorefrontCodeField)
            make.leading.equalTo(debugStorefrontCodeField.snp.trailing).offset(8)
        }
        helpLabel.snp.makeConstraints { make in
            make.top.equalTo(debugStorefrontCodeField.snp.bottom).offset(6)
            make.leading.trailing.bottom.equalToSuperview()
        }

        return container
    }
    #endif

    func makeLoginSection() -> NSView {
        let container = NSView()

        let sectionTitle = makeSectionTitle(AppText.settingsLoginSection)

        loginStatusLabel.font = .systemFont(ofSize: 12)
        loginStatusLabel.textColor = .secondaryLabelColor
        loginStatusLabel.maximumNumberOfLines = 0

        // 订阅审核截图需要清楚展示商品名称和权益。
        // 这块说明保持在登录状态附近，方便审核人员直接对应 App Store Connect 的订阅项目。
        subscriptionInfoLabel.font = .systemFont(ofSize: 12)
        subscriptionInfoLabel.textColor = .secondaryLabelColor
        subscriptionInfoLabel.maximumNumberOfLines = 0
        subscriptionInfoLabel.stringValue = AppText.settingsSubscriptionInfo

        loginActionButton.bezelStyle = .rounded
        loginActionButton.target = self
        loginActionButton.action = #selector(handleLoginAction)

        subscribeButton.bezelStyle = .rounded
        subscribeButton.target = self
        subscribeButton.action = #selector(handleSubscribeAction)
        subscribeButton.isHidden = true

        restoreSubscriptionButton.bezelStyle = .rounded
        restoreSubscriptionButton.target = self
        restoreSubscriptionButton.action = #selector(handleRestoreSubscriptionAction)
        restoreSubscriptionButton.isHidden = true

        subscriptionActionsStack.orientation = .horizontal
        subscriptionActionsStack.alignment = .centerY
        subscriptionActionsStack.spacing = 8
        subscriptionActionsStack.addArrangedSubview(subscribeButton)
        subscriptionActionsStack.addArrangedSubview(restoreSubscriptionButton)

        container.addSubview(sectionTitle)
        container.addSubview(loginStatusLabel)
        container.addSubview(subscriptionInfoLabel)
        container.addSubview(loginActionButton)
        container.addSubview(subscriptionActionsStack)

        sectionTitle.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        loginStatusLabel.snp.makeConstraints { make in
            make.top.equalTo(sectionTitle.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
        }
        subscriptionInfoLabel.snp.makeConstraints { make in
            make.top.equalTo(loginStatusLabel.snp.bottom).offset(6)
            make.leading.trailing.equalToSuperview()
        }
        loginActionButton.snp.makeConstraints { make in
            make.top.equalTo(subscriptionInfoLabel.snp.bottom).offset(8)
            make.leading.equalToSuperview()
        }
        subscriptionActionsStack.snp.makeConstraints { make in
            make.top.equalTo(subscriptionInfoLabel.snp.bottom).offset(8)
            make.leading.equalTo(loginActionButton.snp.trailing).offset(8)
        }
        subscriptionActionsStack.snp.makeConstraints { make in
            make.bottom.equalToSuperview()
        }

        return container
    }

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

    #if DEBUG
    @objc func aiVisionChanged() {
        UserDefaults.standard.set(
            aiVisionCheckbox.state == .on,
            forKey: AppSettings.aiUseVisionTextExtractionKey
        )
    }
    #endif

    #if DEBUG
    @objc func aiEntranceChanged() {
        UserDefaults.standard.set(
            aiEntranceCheckbox.state == .on,
            forKey: AppSettings.showAIEntrancesKey
        )
    }
    #endif

    #if DEBUG
    @objc func debugStorefrontOverrideChanged() {
        let storefrontCode = debugStorefrontCodeField.stringValue
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if storefrontCode.isEmpty {
            UserDefaults.standard.removeObject(forKey: AppSettings.debugStorefrontCodeOverrideKey)
        } else {
            UserDefaults.standard.set(storefrontCode, forKey: AppSettings.debugStorefrontCodeOverrideKey)
        }
    }
    #endif

    @objc func handleChooseSaveDirectory() { chooseSaveDirectory() }
    @objc func handleClearSaveDirectory() { clearSaveDirectory() }

    @objc func handleLoginAction() {
        if AIProSessionManager.shared.isSignedIn {
            AIProSessionManager.shared.signOut()
            AIProSubscriptionService.shared.clearCachedStatus()
            reloadLoginStatus()
        } else {
            Task {
                await signInAndRefreshStatus()
            }
        }
    }

    func signInAndRefreshStatus() async {
        setAccountButtonsEnabled(false)
        do {
            _ = try await AIProAuthService.shared.signIn()
            switch AIProSettingsSignInCompletionBehavior.afterSuccessfulSignIn {
            case .refreshSubscriptionStatus:
                _ = await AIProSubscriptionService.shared.refreshStatus()
            }
            reloadLoginStatus()
        } catch {
            loginStatusLabel.stringValue = error.localizedDescription
        }
        setAccountButtonsEnabled(true)
    }

    func setAccountButtonsEnabled(_ isEnabled: Bool) {
        loginActionButton.isEnabled = isEnabled
    }

    @objc func handleSubscribeAction() {
        setSubscriptionButtonsEnabled(false)
        Task {
            let status = await AIProSubscriptionService.shared.purchaseMonthly()
            setSubscriptionButtonsEnabled(true)
            
            switch status {
            case .subscribed:
                // 订阅成功，刷新状态显示
                reloadLoginStatus()
            case .failed(let error):
                loginStatusLabel.stringValue = error
            default:
                break
            }
        }
    }

    @objc func handleRestoreSubscriptionAction() {
        setSubscriptionButtonsEnabled(false)
        Task {
            let status = await AIProSubscriptionService.shared.restorePurchases()
            setSubscriptionButtonsEnabled(true)

            switch status {
            case .subscribed:
                reloadLoginStatus()
            case .failed(let error):
                loginStatusLabel.stringValue = error
            default:
                renderSignedInStatus(
                    userID: AIProSessionManager.shared.currentUserID ?? "--",
                    subscriptionStatus: status
                )
            }
        }
    }

    func setSubscriptionButtonsEnabled(_ isEnabled: Bool) {
        subscribeButton.isEnabled = isEnabled
        restoreSubscriptionButton.isEnabled = isEnabled
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
            TYLogger.error("Save directory bookmark creation failed", tag: "Settings", error: error)
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
