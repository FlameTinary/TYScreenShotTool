import XCTest
@testable import TShot

final class RegionPolicyTests: XCTestCase {

    func test_chinaMainlandStorefront_disablesCommercialAIAndNetworkFeatures() {
        let policy = RegionPolicyResolver.policy(forStorefrontCode: "CHN")

        XCTAssertTrue(policy.isChinaMainlandMode)
        XCTAssertFalse(policy.isCommercialAIAllowed)
        XCTAssertFalse(policy.isLoginAllowed)
        XCTAssertFalse(policy.isSubscriptionAllowed)
        XCTAssertFalse(policy.isServerAPIAllowed)
    }

    func test_overseasStorefront_allowsCommercialAIAndNetworkFeatures() {
        let policy = RegionPolicyResolver.policy(forStorefrontCode: "USA")

        XCTAssertFalse(policy.isChinaMainlandMode)
        XCTAssertTrue(policy.isCommercialAIAllowed)
        XCTAssertTrue(policy.isLoginAllowed)
        XCTAssertTrue(policy.isSubscriptionAllowed)
        XCTAssertTrue(policy.isServerAPIAllowed)
    }

    func test_unknownStorefront_disablesCommercialAIAndNetworkFeatures() {
        let policy = RegionPolicyResolver.policy(forStorefrontCode: nil)

        XCTAssertFalse(policy.isChinaMainlandMode)
        XCTAssertFalse(policy.isCommercialAIAllowed)
        XCTAssertFalse(policy.isLoginAllowed)
        XCTAssertFalse(policy.isSubscriptionAllowed)
        XCTAssertFalse(policy.isServerAPIAllowed)
    }

    func test_aiEntryHidden_whenUserSettingEnabledButRegionDisallowsCommercialAI() {
        let defaults = UserDefaults.makeIsolated()
        defaults.set(true, forKey: AppSettings.showAIEntrancesKey)
        let policy = RegionPolicyResolver.policy(forStorefrontCode: "CHN")
        let service = AIAvailabilityService(regionPolicy: policy, userDefaults: defaults)

        XCTAssertFalse(service.shouldShowCommercialAIEntry)
        XCTAssertFalse(service.isServerAIAllowed)
        XCTAssertFalse(service.isSubscriptionAllowed)
    }

    func test_aiEntryVisible_whenUserSettingEnabledAndRegionAllowsCommercialAI() {
        let defaults = UserDefaults.makeIsolated()
        defaults.set(true, forKey: AppSettings.showAIEntrancesKey)
        let policy = RegionPolicyResolver.policy(forStorefrontCode: "USA")
        let service = AIAvailabilityService(regionPolicy: policy, userDefaults: defaults)

        XCTAssertTrue(service.shouldShowCommercialAIEntry)
        XCTAssertTrue(service.isServerAIAllowed)
        XCTAssertTrue(service.isSubscriptionAllowed)
    }

    func test_aiEntryVisibleByDefault_whenRegionAllowsCommercialAI() {
        let defaults = UserDefaults.makeIsolated()
        let policy = RegionPolicyResolver.policy(forStorefrontCode: "USA")
        let service = AIAvailabilityService(regionPolicy: policy, userDefaults: defaults)

        XCTAssertTrue(service.shouldShowCommercialAIEntry)
        XCTAssertTrue(service.isServerAIAllowed)
    }

    func test_aiEntryHiddenWhenUserExplicitlyDisablesEntrance() {
        let defaults = UserDefaults.makeIsolated()
        defaults.set(false, forKey: AppSettings.showAIEntrancesKey)
        let policy = RegionPolicyResolver.policy(forStorefrontCode: "USA")
        let service = AIAvailabilityService(regionPolicy: policy, userDefaults: defaults)

        XCTAssertFalse(service.shouldShowCommercialAIEntry)
        XCTAssertTrue(service.isServerAIAllowed)
    }
}
