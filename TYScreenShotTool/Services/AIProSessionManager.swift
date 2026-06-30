import Foundation
import Security

/// AI Pro 会话管理器
///
/// 负责管理 AI Pro 功能的登录会话，包括：
/// 1. 使用 Keychain 安全存储后端 Bearer Token
/// 2. 使用 UserDefaults 存储用户 ID
/// 3. 提供登录状态检查
/// 4. 支持 App 启动时从 Keychain 恢复会话
///
/// **安全设计**：
/// - Bearer Token 存储在 Keychain 中，受系统安全保护
/// - 用户 ID 存储在 UserDefaults（非敏感信息）
/// - 使用 Security Framework 的 kSecClassGenericPassword 类型存储
/// - Keychain 条目使用 kSecAttrAccessibleAfterFirstUnlock 保护
///
/// **依赖说明**：
/// - 内部使用原生 Security Framework API，无第三方依赖
/// - 支持依赖注入，便于单元测试
final class AIProSessionManager {
    static let shared = AIProSessionManager()

    /// UserDefaults 实例，用于存储用户 ID（非敏感信息）
    private let userDefaults: UserDefaults

    /// Keychain 存储的 Token 键名
    private let tokenKey = "bearer-token"
    /// UserDefaults 存储的用户 ID 键名
    private let userIDKey = "aiProUserID"
    /// Keychain 服务名称，用于区分不同应用的 Keychain 条目
    private let keychainService: String

    init(
        userDefaults: UserDefaults = .standard,
        keychainService: String = "com.tshot.app.aiProSession"
    ) {
        self.userDefaults = userDefaults
        self.keychainService = keychainService
    }

    // MARK: - Public API

    /// 当前 Bearer Token（仅内存缓存，启动时从 Keychain 恢复）
    ///
    /// Token 用于向后端 API 发送请求时的 Authorization 头（Bearer Token）。
    /// 登录成功后保存到 Keychain，App 重启时从 Keychain 恢复。
    private(set) var currentToken: String?

    /// 当前登录用户 ID（UUID 格式）
    ///
    /// 用户 ID 用于：
    /// - 作为 StoreKit 的 appAccountToken 关联交易
    /// - 后端查询订阅状态和用量
    private(set) var currentUserID: String?

    /// 是否已登录
    ///
    /// 判断条件：currentToken 和 currentUserID 都不为 nil
    var isSignedIn: Bool {
        currentToken != nil && currentUserID != nil
    }

    /// 从 Keychain 恢复会话（App 启动时调用）
    ///
    /// App 启动时调用此方法，从 Keychain 恢复之前保存的 Bearer Token 和用户 ID。
    /// 如果 Keychain 中没有有效的 Token 或用户 ID 格式不正确，会自动调用 signOut()。
    ///
    /// **调用时机**：AppDelegate.applicationDidFinishLaunching() 中调用
    func restoreSession() {
        guard let token = readFromKeychain(key: tokenKey),
              !token.isEmpty,
              let userID = userDefaults.string(forKey: userIDKey),
              Self.isValidBackendUserID(userID) else {
            // Token 无效或用户 ID 格式不正确，清除会话
            signOut()
            return
        }

        // 恢复会话到内存
        currentToken = token
        currentUserID = userID
    }

    /// 保存登录成功后的会话
    ///
    /// 登录成功后调用此方法，将 Bearer Token 和用户 ID 保存到持久化存储。
    /// Token 保存到 Keychain，用户 ID 保存到 UserDefaults。
    ///
    /// **验证逻辑**：
    /// - Token 不能为空
    /// - 用户 ID 必须是有效的 UUID 格式
    /// - 验证失败时调用 signOut() 清除会话
    ///
    /// - Parameters:
    ///   - token: 后端返回的 Bearer Token
    ///   - userID: 后端返回的用户 ID（UUID 格式）
    func saveSession(token: String, userID: String) {
        guard !token.isEmpty, Self.isValidBackendUserID(userID) else {
            // 参数无效，清除会话
            signOut()
            return
        }

        // 更新内存状态
        currentToken = token
        currentUserID = userID
        // 保存 Token 到 Keychain
        writeToKeychain(key: tokenKey, value: token)
        // 保存用户 ID 到 UserDefaults
        userDefaults.set(userID, forKey: userIDKey)
    }

    /// 清除会话（退出登录）
    ///
    /// 退出登录时调用此方法，清除所有会话相关的数据：
    /// 1. 清除内存中的 currentToken 和 currentUserID
    /// 2. 从 Keychain 删除 Token
    /// 3. 从 UserDefaults 删除用户 ID
    func signOut() {
        currentToken = nil
        currentUserID = nil
        deleteFromKeychain(key: tokenKey)
        userDefaults.removeObject(forKey: userIDKey)
    }

    /// 验证后端用户 ID 是否为有效的 UUID 格式
    ///
    /// 后端返回的用户 ID 必须是 UUID 格式，用于：
    /// - StoreKit 的 appAccountToken（必须是 UUID 类型）
    /// - 后端查询用户数据
    ///
    /// - Parameter userID: 用户 ID 字符串
    /// - Returns: 是否为有效的 UUID 格式
    static func isValidBackendUserID(_ userID: String) -> Bool {
        UUID(uuidString: userID) != nil
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
