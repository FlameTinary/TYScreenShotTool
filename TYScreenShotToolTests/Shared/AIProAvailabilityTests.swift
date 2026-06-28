import XCTest
@testable import TShot

final class AIProAvailabilityTests: XCTestCase {

    func test_debugStorefrontOverride_buildsOverseasPolicy() {
        let defaults = UserDefaults.makeIsolated()
        defaults.set("usa", forKey: AppSettings.debugStorefrontCodeOverrideKey)

        let policy = AppRegionPolicyProvider(userDefaults: defaults).currentPolicy()

        XCTAssertEqual(policy.storefrontCode, "USA")
        XCTAssertTrue(policy.isCommercialAIAllowed)
        XCTAssertTrue(policy.isLoginAllowed)
        XCTAssertTrue(policy.isSubscriptionAllowed)
        XCTAssertTrue(policy.isServerAPIAllowed)
    }

    func test_aiProShellVisibleOnlyWhenRegionAllowsAndEntranceSettingEnabled() {
        let defaults = UserDefaults.makeIsolated()
        defaults.set(true, forKey: AppSettings.showAIEntrancesKey)

        XCTAssertFalse(
            AIAvailabilityService(
                regionPolicy: RegionPolicyResolver.policy(forStorefrontCode: "CHN"),
                userDefaults: defaults
            ).shouldShowAIProShellEntry
        )
        XCTAssertFalse(
            AIAvailabilityService(
                regionPolicy: RegionPolicyResolver.policy(forStorefrontCode: nil),
                userDefaults: defaults
            ).shouldShowAIProShellEntry
        )
        XCTAssertTrue(
            AIAvailabilityService(
                regionPolicy: RegionPolicyResolver.policy(forStorefrontCode: "USA"),
                userDefaults: defaults
            ).shouldShowAIProShellEntry
        )
    }

    func test_aiProShellActionShowsPromptInsteadOfStartingAIRequest() {
        let availability = AIProShellAvailability(
            regionPolicy: RegionPolicyResolver.policy(forStorefrontCode: "USA"),
            isEntranceSettingEnabled: true
        )

        XCTAssertEqual(availability.selectionBehavior, .showPrompt)
        XCTAssertNil(availability.requestMode(for: .summary))
    }
}
