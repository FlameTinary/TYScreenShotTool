import Foundation

// MARK: - Response Models

/// Sign in with Apple 登录响应
///
/// 后端验证 Apple identity token 后返回的认证信息。
struct AuthAppleResponse: Decodable {
    /// 后端生成的 Bearer Token，用于后续 API 请求的 Authorization 头
    let token: String
    /// 后端用户 ID（UUID 格式），用于关联订阅交易和查询用户数据
    let user_id: String
}

/// 订阅验证响应
///
/// 后端验证 StoreKit signedTransaction JWT 后返回的结果。
struct SubscriptionVerifyResponse: Decodable {
    /// 订阅状态（active/grace_period/expired/cancelled 等）
    let status: String
    /// 订阅商品 ID
    let product_id: String
    /// 订阅到期时间（ISO 8601 格式）
    let expires_at: String?
    /// 交易环境（Sandbox/Production/Xcode/LocalTesting）
    let environment: String
}

/// 订阅状态查询响应
///
/// 查询用户当前订阅状态时返回的结果。
struct SubscriptionStatusResponse: Decodable {
    /// 用户 ID
    let user_id: String
    /// 订阅状态（active/grace_period/expired/cancelled/unsubscribed 等）
    let status: String
    /// 当前订阅的商品 ID（未订阅时为 nil）
    let product_id: String?
    /// 订阅到期时间（ISO 8601 格式，未订阅时为 nil）
    let expires_at: String?
}

/// 用量查询响应
///
/// 查询用户当前 AI 分析用量时返回的结果。
struct UsageResponse: Decodable {
    /// 用户 ID
    let user_id: String
    /// 本月已使用次数
    let monthly_used_count: Int
    /// 本月限制次数
    let monthly_limit_count: Int
    /// 今日已使用次数
    let daily_used_count: Int
    /// 今日限制次数
    let daily_limit_count: Int
}

/// AI 分析响应
///
/// 调用 AI 分析接口后返回的结果。
struct AIAnalysisResponse: Decodable {
    /// 请求 ID（用于去重和日志追踪）
    let request_id: String
    /// AI 分析结果文本
    let analysis: String
    /// 使用的 AI 模型名称
    let model: String
    /// Token 使用情况
    let usage: AIUsageInfo
}

/// AI Token 使用信息
///
/// 记录单次 AI 请求消耗的 Token 数量。
struct AIUsageInfo: Decodable {
    /// 输入 Token 数量
    let input_tokens: Int
    /// 输出 Token 数量
    let output_tokens: Int
}

// MARK: - Error Types

/// 后端 API 错误类型
///
/// 映射后端返回的 HTTP 状态码到具体的错误类型，便于前端统一处理。
///
/// **HTTP 状态码映射**：
/// - 401 → authRequired（未登录或 token 过期）
/// - 402 → subscriptionRequired（需要订阅）
/// - 403 → regionUnavailable（区域不可用）
/// - 409 → duplicateRequest（重复请求）
/// - 413 → imageTooLarge（图片太大）
/// - 422 → providerInputUnsupported（AI Provider 不支持）
/// - 429 → quotaExceeded（额度用尽）
/// - 502 → providerFailed（AI Provider 调用失败）
/// - 其他 → serverError（服务端错误）
enum AIProBackendError: LocalizedError {
    /// 未登录或 token 过期（HTTP 401）
    case authRequired
    /// 需要订阅才能使用此功能（HTTP 402）
    case subscriptionRequired
    /// 当前区域不可用（HTTP 403）- 中国大陆用户无法使用 AI Pro
    case regionUnavailable
    /// 月/日额度用尽（HTTP 429）
    case quotaExceeded
    /// 重复请求（HTTP 409）- 相同 request_id 的请求已处理过
    case duplicateRequest
    /// 图片大小超过限制（HTTP 413）
    case imageTooLarge
    /// AI Provider 不支持此输入类型（HTTP 422）
    case providerInputUnsupported
    /// AI Provider 调用失败（HTTP 502）- OpenAI 等服务暂时不可用
    case providerFailed
    /// 网络或服务端错误
    case serverError(String)
    /// JSON 响应解析失败
    case decodeFailed(String)

    /// 用户可读的错误描述
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
/// 封装所有与 Cloudflare Worker 后端交互的 HTTP 请求，提供以下功能：
/// 1. 统一的请求构建和响应处理
/// 2. 自动添加 Authorization 头（Bearer Token）
/// 3. HTTP 状态码到 AIProBackendError 的映射
/// 4. JSON 响应的自动解析
/// 5. 支持自定义 baseURL（用于开发和测试环境）
///
/// **设计说明**：
/// - 使用依赖注入模式，便于单元测试
/// - baseURL 支持从 UserDefaults 读取自定义配置
/// - 请求超时时间：15 秒（请求超时），30 秒（资源超时）
/// - 所有 API 请求默认要求认证（requiresAuth: true）
final class AIProBackendClient {
    /// URLSession 实例，用于发送 HTTP 请求
    private let session: URLSession
    /// 会话管理器，用于获取 Bearer Token
    private let sessionManager: AIProSessionManager
    /// 后端 API 的基础 URL（Cloudflare Worker 地址）
    private let baseURL: URL

    /// 获取默认的后端基础 URL
    ///
    /// 优先从 UserDefaults 读取自定义配置（用于开发调试），
    /// 如果未配置或配置无效，使用 AppSettings 中定义的默认值。
    ///
    /// - Parameter userDefaults: UserDefaults 实例
    /// - Returns: 有效的后端基础 URL
    static func defaultBaseURL(userDefaults: UserDefaults = .standard) -> URL {
        // 优先读取自定义配置
        if let configured = userDefaults.string(forKey: AppSettings.backendBaseURLKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           configured.isEmpty == false,
           let url = URL(string: configured),
           url.scheme != nil,
           url.host != nil {
            return url
        }

        // 使用默认值
        return URL(string: AppSettings.backendBaseURLDefaultValue)!
    }

    /// 创建默认的 URLSession 实例
    ///
    /// 设置超时时间：
    /// - timeoutIntervalForRequest: 15 秒（单个请求超时）
    /// - timeoutIntervalForResource: 30 秒（整个资源加载超时）
    ///
    /// - Returns: 配置好的 URLSession 实例
    static func makeDefaultSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration)
    }

    /// 初始化后端客户端
    ///
    /// 支持依赖注入，便于单元测试时替换依赖。
    ///
    /// - Parameters:
    ///   - session: URLSession 实例，默认使用 makeDefaultSession()
    ///   - sessionManager: 会话管理器，默认使用 AIProSessionManager.shared
    ///   - baseURL: 后端基础 URL，默认使用 defaultBaseURL()
    init(
        session: URLSession = AIProBackendClient.makeDefaultSession(),
        sessionManager: AIProSessionManager = .shared,
        baseURL: URL = AIProBackendClient.defaultBaseURL()
    ) {
        self.session = session
        self.sessionManager = sessionManager
        self.baseURL = baseURL
    }

    // MARK: - Auth

    /// 使用 Apple identity token 登录
    ///
    /// 将 Apple 返回的 identity token（JWT 格式）发送到后端进行验证，
    /// 后端验证通过后返回 Bearer Token 和用户 ID。
    ///
    /// **请求参数**：
    /// - identity_token: Apple 返回的 JWT
    /// - storefront: 可选，用户所在区域（如 US、CN），用于区域策略验证
    ///
    /// **注意**：此接口不需要认证（requiresAuth: false），因为这是登录接口。
    ///
    /// - Parameter identityToken: Apple 返回的 identity token
    /// - Returns: 认证响应（包含 Bearer Token 和用户 ID）
    func authApple(identityToken: String) async throws -> AuthAppleResponse {
        // 获取当前区域策略，用于后端验证
        let policy = AppRegionPolicyProvider().currentPolicy()
        var body: [String: String] = ["identity_token": identityToken]
        // 添加 storefront 参数（如果有），后端用于区域策略验证
        if let storefrontCode = policy.storefrontCode {
            body["storefront"] = storefrontCode
        }
        // 登录接口不需要认证
        let data = try await performRequest(path: "/v1/auth/apple", body: body, requiresAuth: false)
        return try decodeResponse(data)
    }

    // MARK: - Subscription

    /// 验证 StoreKit signedTransaction JWT
    ///
    /// 将 StoreKit 返回的 signedTransaction（JWS 格式）发送到后端进行验证，
    /// 后端验证 JWT 签名后更新用户订阅状态。
    ///
    /// **请求参数**：
    /// - signed_transaction: StoreKit 交易的 JWS 表示
    ///
    /// **验证流程**：
    /// 1. 后端验证 JWT 签名是否有效（使用 Apple 的公钥）
    /// 2. 验证交易环境（Sandbox/Production）
    /// 3. 使用 appAccountToken 关联用户
    /// 4. 更新用户订阅状态
    ///
    /// - Parameter signedTransaction: StoreKit 交易的 JWS
    /// - Returns: 订阅验证响应
    func verifySubscription(signedTransaction: String) async throws -> SubscriptionVerifyResponse {
        let body: [String: String] = ["signed_transaction": signedTransaction]
        let data = try await performRequest(path: "/v1/subscriptions/verify", body: body)
        return try decodeResponse(data)
    }

    /// 查询后端订阅状态
    ///
    /// 查询当前登录用户的订阅状态，包括：
    /// - 当前订阅状态（active/expired/cancelled 等）
    /// - 订阅商品 ID
    /// - 到期时间
    ///
    /// **注意**：此接口需要认证，会自动添加 Authorization 头。
    ///
    /// - Returns: 订阅状态响应
    func fetchSubscriptionStatus() async throws -> SubscriptionStatusResponse {
        let data = try await performRequest(path: "/v1/subscriptions/status")
        return try decodeResponse(data)
    }

    // MARK: - Usage

    /// 查询当前用量
    ///
    /// 查询当前登录用户的 AI 分析用量，包括：
    /// - 本月已使用次数 / 本月限制次数
    /// - 今日已使用次数 / 今日限制次数
    ///
    /// **注意**：此接口需要认证。
    ///
    /// - Returns: 用量响应
    func fetchUsage() async throws -> UsageResponse {
        let data = try await performRequest(path: "/v1/usage/current")
        return try decodeResponse(data)
    }

    // MARK: - AI

    /// 截图 AI 分析
    ///
    /// 将截图图片（Base64 编码）发送到后端，后端调用 OpenAI API 进行分析。
    ///
    /// **请求参数**：
    /// - request_id: 请求 ID（UUID 格式），用于去重和日志追踪
    /// - image_base64: Base64 编码的图片数据
    /// - prompt: 可选，用户自定义提示词
    ///
    /// **限制**：
    /// - 图片大小不能超过限制（通常为 10MB）
    /// - 需要有效订阅才能使用
    /// - 有每日/每月使用次数限制
    ///
    /// - Parameters:
    ///   - requestID: 请求 ID
    ///   - imageBase64: Base64 编码的图片
    ///   - prompt: 可选提示词
    /// - Returns: AI 分析响应
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
    ///
    /// 将文字内容发送到后端，后端调用 OpenAI API 进行分析。
    ///
    /// **请求参数**：
    /// - request_id: 请求 ID（UUID 格式），用于去重和日志追踪
    /// - prompt: 用户输入的文字内容
    ///
    /// **限制**：
    /// - 需要有效订阅才能使用
    /// - 有每日/每月使用次数限制
    ///
    /// - Parameters:
    ///   - requestID: 请求 ID
    ///   - prompt: 用户输入的文字
    /// - Returns: AI 分析响应
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
