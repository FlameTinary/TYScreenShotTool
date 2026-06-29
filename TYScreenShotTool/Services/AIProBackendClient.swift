import Foundation

// MARK: - Response Models

struct AuthAppleResponse: Decodable {
    let token: String
    let user_id: String
}

struct SubscriptionVerifyResponse: Decodable {
    let status: String
    let product_id: String
    let expires_at: String?
    let environment: String
}

struct SubscriptionStatusResponse: Decodable {
    let user_id: String
    let status: String
    let product_id: String?
    let expires_at: String?
}

struct UsageResponse: Decodable {
    let user_id: String
    let monthly_used_count: Int
    let monthly_limit_count: Int
    let daily_used_count: Int
    let daily_limit_count: Int
}

struct AIAnalysisResponse: Decodable {
    let request_id: String
    let analysis: String
    let model: String
    let usage: AIUsageInfo
}

struct AIUsageInfo: Decodable {
    let input_tokens: Int
    let output_tokens: Int
}

// MARK: - Error Types

enum AIProBackendError: LocalizedError {
    /// 未登录或 token 过期
    case authRequired
    /// 需要订阅
    case subscriptionRequired
    /// 区域不可用
    case regionUnavailable
    /// 月/日额度用尽
    case quotaExceeded
    /// 重复请求
    case duplicateRequest
    /// 图片太大
    case imageTooLarge
    /// AI Provider 不支持
    case providerInputUnsupported
    /// AI Provider 调用失败
    case providerFailed
    /// 网络或服务端错误
    case serverError(String)
    /// 解析响应失败
    case decodeFailed(String)

    var errorDescription: String? {
        switch self {
        case .authRequired:
            return "请先登录"
        case .subscriptionRequired:
            return "需要有效订阅才能使用 AI 功能"
        case .regionUnavailable:
            return "当前区域不可用"
        case .quotaExceeded:
            return "本月或今日额度已用尽"
        case .duplicateRequest:
            return "此请求已处理过"
        case .imageTooLarge:
            return "图片大小超过限制"
        case .providerInputUnsupported:
            return "当前 AI 模型不支持此输入类型"
        case .providerFailed:
            return "AI 服务暂时不可用，请稍后重试"
        case .serverError(let message):
            return "服务端错误：\(message)"
        case .decodeFailed(let message):
            return "响应解析失败：\(message)"
        }
    }
}

// MARK: - Backend Client

/// 后端 API 统一网络客户端
///
/// 封装所有与 Cloudflare Worker 后端交互的 HTTP 请求。
final class AIProBackendClient {
    private let session: URLSession
    private let sessionManager: AIProSessionManager
    private let baseURL: URL

    static func makeDefaultSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration)
    }

    init(
        session: URLSession = AIProBackendClient.makeDefaultSession(),
        sessionManager: AIProSessionManager = .shared,
        baseURL: URL = URL(string: AppSettings.backendBaseURLDefaultValue)!
    ) {
        self.session = session
        self.sessionManager = sessionManager
        self.baseURL = baseURL
    }

    // MARK: - Auth

    /// 使用 Apple identity token 登录
    func authApple(identityToken: String) async throws -> AuthAppleResponse {
        let body: [String: String] = ["identity_token": identityToken]
        let data = try await performRequest(path: "/v1/auth/apple", body: body, requiresAuth: false)
        return try decodeResponse(data)
    }

    // MARK: - Subscription

    /// 验证 StoreKit signedTransaction JWT
    func verifySubscription(signedTransaction: String) async throws -> SubscriptionVerifyResponse {
        let body: [String: String] = ["signed_transaction": signedTransaction]
        let data = try await performRequest(path: "/v1/subscriptions/verify", body: body)
        return try decodeResponse(data)
    }

    /// 查询后端订阅状态
    func fetchSubscriptionStatus() async throws -> SubscriptionStatusResponse {
        let data = try await performRequest(path: "/v1/subscriptions/status")
        return try decodeResponse(data)
    }

    // MARK: - Usage

    /// 查询当前用量
    func fetchUsage() async throws -> UsageResponse {
        let data = try await performRequest(path: "/v1/usage/current")
        return try decodeResponse(data)
    }

    // MARK: - AI

    /// 截图 AI 分析
    func analyzeScreenshot(
        requestID: String,
        imageBase64: String,
        prompt: String?
    ) async throws -> AIAnalysisResponse {
        var body: [String: String] = [
            "request_id": requestID,
            "image_base64": imageBase64
        ]
        if let prompt {
            body["prompt"] = prompt
        }
        let data = try await performRequest(path: "/v1/ai/analyze-screenshot", body: body)
        return try decodeResponse(data)
    }

    /// 文字 AI 分析
    func analyzeText(
        requestID: String,
        prompt: String
    ) async throws -> AIAnalysisResponse {
        let body: [String: String] = [
            "request_id": requestID,
            "prompt": prompt
        ]
        let data = try await performRequest(path: "/v1/ai/analyze-text", body: body)
        return try decodeResponse(data)
    }

    // MARK: - Private

    private func performRequest(
        path: String,
        method: String = "POST",
        body: [String: String]? = nil,
        requiresAuth: Bool = true
    ) async throws -> Data {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw AIProBackendError.serverError("Invalid URL path: \(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if requiresAuth {
            guard let token = sessionManager.currentToken else {
                throw AIProBackendError.authRequired
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AIProBackendError.serverError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProBackendError.serverError("Invalid response")
        }

        try mapHTTPError(statusCode: httpResponse.statusCode, data: data)
        return data
    }

    private func performRequest(path: String) async throws -> Data {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw AIProBackendError.serverError("Invalid URL path: \(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        guard let token = sessionManager.currentToken else {
            throw AIProBackendError.authRequired
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AIProBackendError.serverError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProBackendError.serverError("Invalid response")
        }

        try mapHTTPError(statusCode: httpResponse.statusCode, data: data)
        return data
    }

    private func mapHTTPError(statusCode: Int, data: Data) throws {
        let message = (try? JSONDecoder().decode(ErrorBody.self, from: data)).map { $0.error } ?? "HTTP \(statusCode)"

        switch statusCode {
        case 200...299:
            return
        case 401:
            throw AIProBackendError.authRequired
        case 402:
            throw AIProBackendError.subscriptionRequired
        case 403:
            throw AIProBackendError.regionUnavailable
        case 409:
            throw AIProBackendError.duplicateRequest
        case 413:
            throw AIProBackendError.imageTooLarge
        case 422:
            throw AIProBackendError.providerInputUnsupported
        case 429:
            throw AIProBackendError.quotaExceeded
        case 502:
            throw AIProBackendError.providerFailed
        default:
            throw AIProBackendError.serverError(message)
        }
    }

    private func decodeResponse<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AIProBackendError.decodeFailed(error.localizedDescription)
        }
    }
}

private struct ErrorBody: Decodable {
    let error: String
}
