import XCTest
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
}
