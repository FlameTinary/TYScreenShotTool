import XCTest
import StoreKitTest
@testable import TShot

final class AIProSubscriptionTests: XCTestCase {

    func test_productIdentifier_matchesSprint53MonthlyProduct() {
        XCTAssertEqual(AIProSubscriptionProductID.monthly, "tshot.pro.monthly")
    }

    func test_unsubscribedStatusUsesLoadedMonthlyProduct() {
        let product = AIProSubscriptionProduct(
            id: AIProSubscriptionProductID.monthly,
            displayName: "AI Pro Monthly",
            displayPrice: "$4.99",
            description: "Monthly AI Pro subscription"
        )

        let status = AIProSubscriptionStatus.unsubscribed(product)

        XCTAssertEqual(status.product, product)
        XCTAssertFalse(status.isSubscribed)
        XCTAssertTrue(status.canStartPurchase)
    }

    func test_subscribedStatusKeepsProductButDisablesPurchase() {
        let product = AIProSubscriptionProduct(
            id: AIProSubscriptionProductID.monthly,
            displayName: "AI Pro Monthly",
            displayPrice: "$4.99",
            description: "Monthly AI Pro subscription"
        )

        let status = AIProSubscriptionStatus.subscribed(product)

        XCTAssertEqual(status.product, product)
        XCTAssertTrue(status.isSubscribed)
        XCTAssertFalse(status.canStartPurchase)
    }

    func test_signedInSubscriptionStatesCanStartRestore() {
        XCTAssertTrue(AIProSubscriptionStatus.unsubscribed(Self.monthlyProduct).canStartRestore)
        XCTAssertTrue(AIProSubscriptionStatus.subscribed(Self.monthlyProduct).canStartRestore)
        XCTAssertTrue(AIProSubscriptionStatus.unavailable.canStartRestore)
        XCTAssertFalse(AIProSubscriptionStatus.notLoaded.canStartRestore)
        XCTAssertFalse(AIProSubscriptionStatus.loading.canStartRestore)
        XCTAssertFalse(AIProSubscriptionStatus.regionUnavailable.canStartRestore)
    }

    func test_settingsRestoreSubscriptionTextIsAvailable() {
        XCTAssertFalse(AppText.settingsRestoreSubscription.isEmpty)
    }

    func test_settingsSuccessfulSignInRefreshesSubscriptionStatusWithoutAutoRestoringPurchases() {
        XCTAssertEqual(
            AIProSettingsSignInCompletionBehavior.afterSuccessfulSignIn,
            .refreshSubscriptionStatus
        )
    }

    func test_promptContentForUnsubscribedProductOffersSubscribeAndRestore() {
        let product = AIProSubscriptionProduct(
            id: AIProSubscriptionProductID.monthly,
            displayName: "AI Pro Monthly",
            displayPrice: "$4.99",
            description: "Monthly AI Pro subscription"
        )

        let content = AIProSubscriptionPromptContent(status: .unsubscribed(product))

        XCTAssertEqual(content.primaryAction, .subscribe)
        XCTAssertEqual(content.secondaryAction, .restore)
        XCTAssertTrue(content.message.contains("$4.99"))
    }

    func test_promptContentForUnavailableProductDoesNotOfferPurchase() {
        let content = AIProSubscriptionPromptContent(status: .unavailable)

        XCTAssertEqual(content.primaryAction, .restore)
        XCTAssertNil(content.secondaryAction)
        XCTAssertFalse(content.message.isEmpty)
    }

    func test_promptContentForRegionUnavailableOnlyDismisses() {
        let content = AIProSubscriptionPromptContent(status: .regionUnavailable)

        XCTAssertEqual(content.primaryAction, .dismiss)
        XCTAssertNil(content.secondaryAction)
        XCTAssertNil(content.cancelButtonTitle)
    }

    func test_accessStateBlocksRegionBeforeLoginAndSubscription() {
        let state = AIProAccessState.resolve(
            isSubscriptionAllowed: false,
            isSignedIn: true,
            subscriptionStatus: .subscribed(Self.monthlyProduct)
        )

        XCTAssertEqual(state, .regionUnavailable)
    }

    func test_accessStateRequiresLoginBeforeSubscription() {
        let state = AIProAccessState.resolve(
            isSubscriptionAllowed: true,
            isSignedIn: false,
            subscriptionStatus: .subscribed(Self.monthlyProduct)
        )

        XCTAssertEqual(state, .needsLogin)
    }

    func test_accessStateUsesCachedSubscribedStatus() {
        let state = AIProAccessState.resolve(
            isSubscriptionAllowed: true,
            isSignedIn: true,
            subscriptionStatus: .subscribed(Self.monthlyProduct)
        )

        XCTAssertEqual(state, .ready)
    }

    func test_accessStateTreatsUnknownOrInactiveCachedStatusAsNeedsSubscription() {
        XCTAssertEqual(
            AIProAccessState.resolve(
                isSubscriptionAllowed: true,
                isSignedIn: true,
                subscriptionStatus: .notLoaded
            ),
            .needsSubscription
        )
        XCTAssertEqual(
            AIProAccessState.resolve(
                isSubscriptionAllowed: true,
                isSignedIn: true,
                subscriptionStatus: .unsubscribed(Self.monthlyProduct)
            ),
            .needsSubscription
        )
    }

    func test_cachedSubscriptionStatesDoNotBlockToolbarAIOnNetworkRefresh() {
        XCTAssertFalse(AIProSubscriptionStatus.subscribed(Self.monthlyProduct).needsNetworkRefresh)
        XCTAssertFalse(AIProSubscriptionStatus.unsubscribed(Self.monthlyProduct).needsNetworkRefresh)
        XCTAssertTrue(AIProSubscriptionStatus.notLoaded.needsNetworkRefresh)
        XCTAssertTrue(AIProSubscriptionStatus.failed("offline").needsNetworkRefresh)
    }

    func test_purchaseConfirmationRequiresBackendActiveStatus() {
        let failedStatus = AIProSubscriptionStatus.statusAfterVerifiedPurchase(
            product: Self.monthlyProduct,
            backendConfirmed: false
        )

        XCTAssertFalse(failedStatus.isSubscribed)
        XCTAssertEqual(failedStatus, .failed(AppText.aiProBackendVerificationFailed))

        let subscribedStatus = AIProSubscriptionStatus.statusAfterVerifiedPurchase(
            product: Self.monthlyProduct,
            backendConfirmed: true
        )

        XCTAssertEqual(subscribedStatus, .subscribed(Self.monthlyProduct))
    }

    func test_subscriptionStatusCacheRestoresFreshSubscribedStatus() {
        let defaults = UserDefaults.makeIsolated()

        AIProSubscriptionStatus.subscribed(Self.monthlyProduct).saveCachedStatus(
            in: defaults,
            now: Date(timeIntervalSince1970: 1_000)
        )

        XCTAssertEqual(
            AIProSubscriptionStatus.cachedStatus(
                in: defaults,
                now: Date(timeIntervalSince1970: 1_100)
            ),
            .subscribed(Self.monthlyProduct)
        )
    }

    func test_subscriptionStatusCacheIgnoresExpiredStatus() {
        let defaults = UserDefaults.makeIsolated()

        AIProSubscriptionStatus.subscribed(Self.monthlyProduct).saveCachedStatus(
            in: defaults,
            now: Date(timeIntervalSince1970: 1_000),
            maxAge: 60
        )

        XCTAssertNil(
            AIProSubscriptionStatus.cachedStatus(
                in: defaults,
                now: Date(timeIntervalSince1970: 1_061),
                maxAge: 60
            )
        )
    }

    func test_clearCachedSubscriptionStatusRemovesStoredStatus() {
        let defaults = UserDefaults.makeIsolated()

        AIProSubscriptionStatus.subscribed(Self.monthlyProduct).saveCachedStatus(in: defaults)
        AIProSubscriptionStatus.clearCachedStatus(in: defaults)

        XCTAssertNil(AIProSubscriptionStatus.cachedStatus(in: defaults))
    }

    func test_backendActiveStatusKeepsAccessWhenStoreKitProductIsUnavailableButCachedProductExists() {
        let status = AIProSubscriptionStatus.statusAfterBackendRefresh(
            loadedProduct: nil,
            cachedProduct: Self.monthlyProduct,
            backendStatus: "active",
            backendProductID: AIProSubscriptionProductID.monthly
        )

        XCTAssertEqual(status, .subscribed(Self.monthlyProduct))
    }

    func test_backendInactiveWithoutLoadedProductShowsSubscriptionUnavailable() {
        let status = AIProSubscriptionStatus.statusAfterBackendRefresh(
            loadedProduct: nil,
            cachedProduct: Self.monthlyProduct,
            backendStatus: "inactive",
            backendProductID: AIProSubscriptionProductID.monthly
        )

        XCTAssertEqual(status, .unavailable)
    }

    @MainActor
    func test_storeKitConfigurationCanPurchaseMonthlyProduct() async throws {
        let isEnabledByEnvironment = ProcessInfo.processInfo.environment["TSHOT_RUN_STOREKIT_SANDBOX_TESTS"] == "1"
        let isEnabledByDefaults = UserDefaults.standard.bool(forKey: AppSettings.debugRunStoreKitSandboxTestsKey)
        guard isEnabledByEnvironment || isEnabledByDefaults else {
            throw XCTSkip("Set debug.runStoreKitSandboxTests=true and run with code signing enabled for local StoreKit purchase verification.")
        }

        let session = try SKTestSession(configurationFileNamed: "TShot")
        session.disableDialogs = true
        session.askToBuyEnabled = false
        session.clearTransactions()

        try await session.buyProduct(identifier: AIProSubscriptionProductID.monthly)

        let transactions = session.allTransactions()
        XCTAssertTrue(
            transactions.contains { $0.productIdentifier == AIProSubscriptionProductID.monthly },
            "Expected local StoreKit purchase to create a monthly subscription transaction"
        )
    }
}

private extension AIProSubscriptionTests {
    static let monthlyProduct = AIProSubscriptionProduct(
        id: AIProSubscriptionProductID.monthly,
        displayName: "AI Pro Monthly",
        displayPrice: "$4.99",
        description: "Monthly AI Pro subscription"
    )
}
