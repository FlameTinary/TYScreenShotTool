import XCTest
@testable import TShot

final class AIProAvailabilityTests: XCTestCase {

    func test_debugStorefrontOverride_buildsOverseasPolicy() {
        let defaults = UserDefaults.makeIsolated()
        defaults.set("usa", forKey: AppSettings.debugStorefrontCodeOverrideKey)
        defaults.set("CHN", forKey: AppSettings.cachedStorefrontCodeKey)

        let policy = AppRegionPolicyProvider(userDefaults: defaults).currentPolicy()

        XCTAssertEqual(policy.storefrontCode, "USA")
        XCTAssertTrue(policy.isCommercialAIAllowed)
        XCTAssertTrue(policy.isLoginAllowed)
        XCTAssertTrue(policy.isSubscriptionAllowed)
        XCTAssertTrue(policy.isServerAPIAllowed)
    }

    func test_cachedStorefrontBuildsPolicyWhenDebugOverrideIsEmpty() {
        let defaults = UserDefaults.makeIsolated()
        defaults.set("jpn", forKey: AppSettings.cachedStorefrontCodeKey)

        let policy = AppRegionPolicyProvider(userDefaults: defaults).currentPolicy()

        XCTAssertEqual(policy.storefrontCode, "JPN")
        XCTAssertTrue(policy.isCommercialAIAllowed)
        XCTAssertTrue(policy.isSubscriptionAllowed)
    }

    func test_emptyDebugOverrideFallsBackToCachedStorefront() {
        let defaults = UserDefaults.makeIsolated()
        defaults.set("", forKey: AppSettings.debugStorefrontCodeOverrideKey)
        defaults.set("CHN", forKey: AppSettings.cachedStorefrontCodeKey)

        let policy = AppRegionPolicyProvider(userDefaults: defaults).currentPolicy()

        XCTAssertEqual(policy.storefrontCode, "CHN")
        XCTAssertFalse(policy.isCommercialAIAllowed)
        XCTAssertFalse(policy.isSubscriptionAllowed)
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

    func test_aiProShellActionStartsGatedMenuFlowInsteadOfPromptOnly() {
        let availability = AIProShellAvailability(
            regionPolicy: RegionPolicyResolver.policy(forStorefrontCode: "USA"),
            isEntranceSettingEnabled: true
        )

        XCTAssertEqual(availability.selectionBehavior, .showGatedMenu)
        XCTAssertNil(availability.requestMode(for: .summary))
    }
}
