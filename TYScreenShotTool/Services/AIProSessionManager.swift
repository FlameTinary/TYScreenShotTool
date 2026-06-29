import Foundation
import Security

/// AI Pro 会话管理器
///
/// 使用 Keychain 安全存储后端 Bearer Token，管理登录状态。
/// 内部使用原生 Security Framework API，无第三方依赖。
final class AIProSessionManager {
    static let shared = AIProSessionManager()

    private let userDefaults: UserDefaults

    private let tokenKey = "bearer-token"
    private let userIDKey = "aiProUserID"
    private let keychainService = "com.tshot.app.aiProSession"

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Public API

    /// 当前 Bearer Token（仅内存缓存，启动时从 Keychain 恢复）
    private(set) var currentToken: String?

    /// 当前登录用户 ID
    private(set) var currentUserID: String?

    /// 是否已登录
    var isSignedIn: Bool {
        currentToken != nil
    }

    /// 从 Keychain 恢复会话（App 启动时调用）
    func restoreSession() {
        currentToken = readFromKeychain(key: tokenKey)
        currentUserID = userDefaults.string(forKey: userIDKey)
    }

    /// 保存登录成功后的会话
    func saveSession(token: String, userID: String) {
        currentToken = token
        currentUserID = userID
        writeToKeychain(key: tokenKey, value: token)
        userDefaults.set(userID, forKey: userIDKey)
    }

    /// 清除会话（退出登录）
    func signOut() {
        currentToken = nil
        currentUserID = nil
        deleteFromKeychain(key: tokenKey)
        userDefaults.removeObject(forKey: userIDKey)
    }

    // MARK: - Keychain Helpers

    private func writeToKeychain(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        // 先删除已有条目
        deleteFromKeychain(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    private func readFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
