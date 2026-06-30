import Foundation
import AuthenticationServices

/// Sign in with Apple 登录服务
///
/// 发起 Apple 登录、获取 identity token、调用后端 API 完成认证、保存会话。
@MainActor
final class AIProAuthService: NSObject {
    static let shared = AIProAuthService()

    private let backendClient: AIProBackendClient
    private let sessionManager: AIProSessionManager

    private var continuation: CheckedContinuation<AuthAppleResponse, Error>?
    private var hasResumed = false

    /// Apple 登录超时时间（秒）
    private static let signInTimeout: UInt64 = 30_000_000_000 // 30 秒

    private override init() {
        self.backendClient = AIProBackendClient()
        self.sessionManager = .shared
    }

    /// 发起 Sign in with Apple 登录
    ///
    /// - Returns: (bearer token, user ID)
    /// - Throws: 用户取消、Apple 返回无效 JWT、后端认证失败、超时
    func signIn() async throws -> (token: String, userID: String) {
        hasResumed = false
        continuation = nil

        let response: AuthAppleResponse = try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self else {
                continuation.resume(throwing: AuthError.unknown)
                return
            }

            self.continuation = continuation

            // 超时保护：30 秒后如果 delegate 还没返回，主动恢复 continuation
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: Self.signInTimeout)
                self?.handleTimeout()
            }

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }

        sessionManager.saveSession(token: response.token, userID: response.user_id)
        return (response.token, response.user_id)
    }

    private func handleTimeout() {
        guard !hasResumed else { return }
        hasResumed = true
        continuation?.resume(throwing: AuthError.timeout)
        continuation = nil
    }

    private func complete(response: AuthAppleResponse) {
        guard !hasResumed else { return }
        hasResumed = true
        sessionManager.saveSession(token: response.token, userID: response.user_id)
        continuation?.resume(returning: response)
        continuation = nil
    }

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
                print("[AI Pro Auth] Apple login credential received")
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
