import Foundation
import AuthenticationServices

/// Sign in with Apple 登录服务
///
/// 发起 Apple 登录、获取 identity token、调用后端 API 完成认证、保存会话。
final class AIProAuthService: NSObject {
    static let shared = AIProAuthService()

    private let backendClient: AIProBackendClient
    private let sessionManager: AIProSessionManager

    private var continuation: CheckedContinuation<AuthAppleResponse, Error>?

    private override init() {
        self.backendClient = AIProBackendClient()
        self.sessionManager = .shared
    }

    /// 发起 Sign in with Apple 登录
    ///
    /// - Returns: (bearer token, user ID)
    /// - Throws: 用户取消、Apple 返回无效 JWT、后端认证失败
    func signIn() async throws -> (token: String, userID: String) {
        let response: AuthAppleResponse = try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self else {
                continuation.resume(throwing: AuthError.unknown)
                return
            }

            self.continuation = continuation

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
}

// MARK: - ASAuthorizationControllerDelegate

extension AIProAuthService: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            continuation?.resume(throwing: AuthError.invalidIdentityToken)
            continuation = nil
            return
        }

        Task {
            do {
                let response = try await backendClient.authApple(identityToken: identityToken)
                continuation?.resume(returning: response)
            } catch {
                continuation?.resume(throwing: error)
            }
            continuation = nil
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        let nsError = error as NSError
        if nsError.domain == ASAuthorizationError.errorDomain,
           nsError.code == ASAuthorizationError.canceled.rawValue {
            continuation?.resume(throwing: AuthError.userCancelled)
        } else {
            continuation?.resume(throwing: AuthError.appleAuthFailed(error.localizedDescription))
        }
        continuation = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AIProAuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? ASPresentationAnchor()
    }
}

// MARK: - Errors

extension AIProAuthService {
    enum AuthError: LocalizedError {
        case userCancelled
        case invalidIdentityToken
        case appleAuthFailed(String)
        case unknown

        var errorDescription: String? {
            switch self {
            case .userCancelled:
                return "已取消登录"
            case .invalidIdentityToken:
                return "Apple 返回的凭据无效"
            case .appleAuthFailed(let message):
                return "Apple 登录失败：\(message)"
            case .unknown:
                return "未知登录错误"
            }
        }
    }
}
