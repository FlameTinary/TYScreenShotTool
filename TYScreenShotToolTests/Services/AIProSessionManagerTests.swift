import XCTest
@testable import TShot

final class AIProSessionManagerTests: XCTestCase {

    func test_saveSessionStoresValidUUIDUserIDForStoreKitAppAccountToken() {
        let defaults = UserDefaults.makeIsolated()
        let service = Self.keychainServiceName()
        let userID = "11111111-1111-4111-8111-111111111111"
        let manager = AIProSessionManager(userDefaults: defaults, keychainService: service)

        manager.saveSession(token: "token-1", userID: userID)

        XCTAssertTrue(manager.isSignedIn)
        XCTAssertEqual(manager.currentToken, "token-1")
        XCTAssertEqual(manager.currentUserID, userID)
        XCTAssertEqual(UUID(uuidString: userID)?.uuidString.lowercased(), userID)

        manager.signOut()
    }

    func test_restoreSessionKeepsOnlyValidUUIDUserID() {
        let defaults = UserDefaults.makeIsolated()
        let service = Self.keychainServiceName()
        let userID = "22222222-2222-4222-8222-222222222222"

        let savingManager = AIProSessionManager(userDefaults: defaults, keychainService: service)
        savingManager.saveSession(token: "token-2", userID: userID)

        let restoringManager = AIProSessionManager(userDefaults: defaults, keychainService: service)
        restoringManager.restoreSession()

        XCTAssertTrue(restoringManager.isSignedIn)
        XCTAssertEqual(restoringManager.currentToken, "token-2")
        XCTAssertEqual(restoringManager.currentUserID, userID)

        restoringManager.signOut()
    }

    func test_saveSessionRejectsLegacyNonUUIDUserID() {
        let defaults = UserDefaults.makeIsolated()
        let service = Self.keychainServiceName()
        let manager = AIProSessionManager(userDefaults: defaults, keychainService: service)

        manager.saveSession(token: "token-3", userID: "new_user_1")

        XCTAssertFalse(manager.isSignedIn)
        XCTAssertNil(manager.currentToken)
        XCTAssertNil(manager.currentUserID)
        XCTAssertNil(defaults.string(forKey: "aiProUserID"))

        manager.signOut()
    }

    func test_restoreSessionClearsLegacyNonUUIDUserID() {
        let defaults = UserDefaults.makeIsolated()
        let service = Self.keychainServiceName()
        let savingManager = AIProSessionManager(userDefaults: defaults, keychainService: service)
        savingManager.saveSession(token: "token-4", userID: "33333333-3333-4333-8333-333333333333")
        defaults.set("legacy-user-id", forKey: "aiProUserID")

        let restoringManager = AIProSessionManager(userDefaults: defaults, keychainService: service)
        restoringManager.restoreSession()

        XCTAssertFalse(restoringManager.isSignedIn)
        XCTAssertNil(restoringManager.currentToken)
        XCTAssertNil(restoringManager.currentUserID)
        XCTAssertNil(defaults.string(forKey: "aiProUserID"))
    }
}

private extension AIProSessionManagerTests {
    static func keychainServiceName() -> String {
        "com.sheldon.TShot.tests.aiProSession.\(UUID().uuidString)"
    }
}
