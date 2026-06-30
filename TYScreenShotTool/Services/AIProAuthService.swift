import Foundation
import AuthenticationServices

/// Sign in with Apple 登录服务
///
/// 负责完整的 Apple 登录流程：
/// 1. 构造 ASAuthorizationAppleIDRequest 请求（请求 email scope）
/// 2. 启动 ASAuthorizationController 展示 Apple 登录弹窗
/// 3. 获取 Apple 返回的 identity token（JWT 格式）
/// 4. 将 identity token 发送到 Cloudflare Worker 后端进行验证
/// 5. 后端返回 Bearer Token，保存到 Keychain
///
/// **线程安全**：使用 @MainActor 保证 UI 操作在主线程，通过 nonisolated delegate 回调切换回主线程处理。
/// **超时机制**：30 秒超时保护，防止 Apple 授权控制器无响应导致的死锁。
/// **重复调用保护**：通过 hasResumed 标志防止多次 resume continuation。
@MainActor
final class AIProAuthService: NSObject {
    static let shared = AIProAuthService()

    /// 后端 API 客户端，用于发送 identity token 进行验证
    private let backendClient: AIProBackendClient
    /// 会话管理器，用于保存登录后的 Bearer Token 和用户 ID
    private let sessionManager: AIProSessionManager

    /// 异步登录流程的 continuation，用于将 delegate 回调转换为 async/await
    private var continuation: CheckedContinuation<AuthAppleResponse, Error>?
    /// 防止重复 resume 的标志位（Apple 登录可能多次回调）
    private var hasResumed = false

    /// Apple 登录超时时间（纳秒）- 30 秒
    /// 防止 ASAuthorizationController 无响应导致的死锁
    private static let signInTimeout: UInt64 = 30_000_000_000

    private override init() {
        self.backendClient = AIProBackendClient()
        self.sessionManager = .shared
    }

    /// 发起 Sign in with Apple 登录
    ///
    /// 完整流程：展示 Apple 登录弹窗 → 获取 identity token → 调用后端验证 → 保存会话
    ///
    /// - Returns: (bearer token, user ID) 元组
    /// - Throws:
    ///   - `AuthError.userCancelled`: 用户点击取消
    ///   - `AuthError.invalidIdentityToken`: Apple 返回的 identity token 无效
    ///   - `AuthError.appleAuthFailed`: Apple 授权过程中发生其他错误
    ///   - `AuthError.timeout`: 30 秒超时
    ///   - `AuthError.unknown`: 未知错误
    ///   - 后端 API 错误（网络错误、验证失败等）
    ///
    /// **设计说明**：
    /// - 使用 `withCheckedThrowingContinuation` 将 delegate 回调模式转换为 async/await
    /// - 启动独立 Task 进行超时监控，防止 UI 阻塞
    /// - 每次调用前重置 continuation 和 hasResumed，支持重复调用
    func signIn() async throws -> (token: String, userID: String) {
        // 重置状态，支持重复调用
        hasResumed = false
        continuation = nil

        let response: AuthAppleResponse = try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self else {
                continuation.resume(throwing: AuthError.unknown)
                return
            }

            self.continuation = continuation

            // 启动超时保护任务：30 秒后如果 delegate 还没返回，主动恢复 continuation
            // 使用 try? 忽略取消错误，因为超时任务被取消是正常行为
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: Self.signInTimeout)
                self?.handleTimeout()
            }

            // 构造 Apple ID 授权请求
            // requestedScopes 请求 email，用户可以选择隐藏真实邮箱
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.email]

            // 创建并启动授权控制器
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }

        // 登录成功后保存会话到 Keychain 和 UserDefaults
        sessionManager.saveSession(token: response.token, userID: response.user_id)
        return (response.token, response.user_id)
    }

    /// 处理登录超时
    ///
    /// 当 Apple 授权控制器在 30 秒内未返回结果时被调用，防止异步流程永久挂起。
    /// 通过 hasResumed 标志防止重复 resume。
    private func handleTimeout() {
        guard !hasResumed else { return }
        hasResumed = true
        continuation?.resume(throwing: AuthError.timeout)
        continuation = nil
    }

    /// 完成登录流程
    ///
    /// 登录成功时调用，保存会话并恢复 continuation。
    /// 注意：signIn() 方法最后也会调用 saveSession()，这里是为了确保在 delegate 回调中也能保存。
    ///
    /// - Parameter response: 后端返回的认证响应（包含 Bearer Token 和用户 ID）
    private func complete(response: AuthAppleResponse) {
        guard !hasResumed else { return }
        hasResumed = true
        sessionManager.saveSession(token: response.token, userID: response.user_id)
        continuation?.resume(returning: response)
        continuation = nil
    }

    /// 处理登录失败
    ///
    /// 登录过程中发生错误时调用，恢复 continuation 并抛出错误。
    ///
    /// - Parameter error: 错误信息
    private func fail(error: Error) {
        guard !hasResumed else { return }
        hasResumed = true
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AIProAuthService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = credential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                self.fail(error: AuthError.invalidIdentityToken)
                return
            }

            do {
                // Apple 登录凭据包含 identity token、authorization code、邮箱和姓名等敏感信息。
                // 这里仅记录不可反推出用户身份的状态字段，避免 Debug 日志泄露认证材料。
                print("[AI Pro Auth] Apple login credential received")
                print("  - realUserStatus: \(credential.realUserStatus.rawValue)")
                print("  - hasState: \(credential.state?.isEmpty == false)")
                
                let response = try await self.backendClient.authApple(identityToken: identityToken)
                self.complete(response: response)
            } catch {
                self.fail(error: error)
            }
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            let nsError = error as NSError
            if nsError.domain == ASAuthorizationError.errorDomain,
               nsError.code == ASAuthorizationError.canceled.rawValue {
                self.fail(error: AuthError.userCancelled)
            } else {
                self.fail(error: AuthError.appleAuthFailed(error.localizedDescription))
            }
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AIProAuthService: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if Thread.isMainThread {
            return MainActor.assumeIsolated {
                Self.currentPresentationAnchor()
            }
        }

        var anchor: ASPresentationAnchor!
        DispatchQueue.main.sync {
            anchor = MainActor.assumeIsolated {
                Self.currentPresentationAnchor()
            }
        }
        return anchor
    }

    @MainActor
    private static func currentPresentationAnchor() -> ASPresentationAnchor {
        NSApplication.shared.keyWindow
            ?? NSApplication.shared.windows.first
            ?? ASPresentationAnchor()
    }
}

// MARK: - Errors

extension AIProAuthService {
    enum AuthError: LocalizedError {
        case userCancelled
        case invalidIdentityToken
        case appleAuthFailed(String)
        case timeout
        case unknown

        var errorDescription: String? {
            switch self {
            case .userCancelled:
                return "已取消登录"
            case .invalidIdentityToken:
                return "Apple 返回的凭据无效"
            case .appleAuthFailed(let message):
                return "Apple 登录失败：\(message)"
            case .timeout:
                return "登录超时，请确认已启用 Sign in with Apple 能力并正确签名"
            case .unknown:
                return "未知登录错误"
            }
        }
    }
}
