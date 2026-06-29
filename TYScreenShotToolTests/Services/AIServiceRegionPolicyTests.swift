import CoreGraphics
import XCTest
@testable import TShot

final class AIServiceRegionPolicyTests: XCTestCase {

    override func setUp() {
        super.setUp()
        RequestCountingURLProtocol.reset()
    }

    func test_analysisService_blocksChinaMainlandBeforeNetworkEvenWithLocalAPIKey() async {
        let defaults = UserDefaults.makeIsolated()
        defaults.set("test-api-key", forKey: AppSettings.aiAnalysisAPIKeyKey)
        let service = AIAnalysisService(
            session: .requestCounting,
            userDefaults: defaults,
            aiAvailabilityService: AIAvailabilityService(
                regionPolicy: RegionPolicyResolver.policy(forStorefrontCode: "CHN"),
                userDefaults: defaults
            )
        )

        do {
            _ = try await service.analyze(text: "hello", mode: .summary)
            XCTFail("Expected region policy to block AI analysis")
        } catch let error as AIAnalysisError {
            XCTAssertTrue(error.isRegionPolicyBlock)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(RequestCountingURLProtocol.requestCount, 0)
    }

    func test_analysisService_blocksUnknownStorefrontBeforeNetworkEvenWithLocalAPIKey() async {
        let defaults = UserDefaults.makeIsolated()
        defaults.set("test-api-key", forKey: AppSettings.aiAnalysisAPIKeyKey)
        let service = AIAnalysisService(
            session: .requestCounting,
            userDefaults: defaults,
            aiAvailabilityService: AIAvailabilityService(
                regionPolicy: RegionPolicyResolver.policy(forStorefrontCode: nil),
                userDefaults: defaults
            )
        )

        do {
            _ = try await service.analyze(text: "hello", mode: .summary)
            XCTFail("Expected unknown storefront to block AI analysis")
        } catch let error as AIAnalysisError {
            XCTAssertTrue(error.isRegionPolicyBlock)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(RequestCountingURLProtocol.requestCount, 0)
    }

    func test_analysisService_allowsOverseasPolicyToReachExistingAPIKeyValidation() async {
        let defaults = UserDefaults.makeIsolated()
        let service = AIAnalysisService(
            session: .requestCounting,
            userDefaults: defaults,
            aiAvailabilityService: AIAvailabilityService(
                regionPolicy: RegionPolicyResolver.policy(forStorefrontCode: "USA"),
                userDefaults: defaults
            )
        )

        do {
            _ = try await service.analyze(text: "hello", mode: .summary)
            XCTFail("Expected missing API key after overseas policy allows developer AI path")
        } catch AIAnalysisError.missingAPIKey {
            // Expected: overseas policy allows the existing developer API key validation to run.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(RequestCountingURLProtocol.requestCount, 0)
    }

    func test_analysisService_defaultAvailabilityUsesCachedStorefrontAtRequestTime() async {
        let defaults = UserDefaults.makeIsolated()
        defaults.set("test-api-key", forKey: AppSettings.aiAnalysisAPIKeyKey)
        defaults.set("USA", forKey: AppSettings.cachedStorefrontCodeKey)
        let service = AIAnalysisService(
            session: .requestCounting,
            userDefaults: defaults
        )

        do {
            _ = try await service.analyze(text: "hello", mode: .summary)
            XCTFail("Expected request counting session to fail after region policy allows network")
        } catch let error as AIAnalysisError {
            XCTAssertFalse(error.isRegionPolicyBlock)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(RequestCountingURLProtocol.requestCount, 1)
    }

    func test_imageTextExtractionService_blocksChinaMainlandBeforeNetworkEvenWithLocalAPIKey() async throws {
        let defaults = UserDefaults.makeIsolated()
        defaults.set("test-api-key", forKey: AppSettings.aiAnalysisAPIKeyKey)
        let service = AIImageTextExtractionService(
            session: .requestCounting,
            userDefaults: defaults,
            aiAvailabilityService: AIAvailabilityService(
                regionPolicy: RegionPolicyResolver.policy(forStorefrontCode: "CHN"),
                userDefaults: defaults
            )
        )

        do {
            _ = try await service.extractText(from: try makeTestImage())
            XCTFail("Expected region policy to block AI image text extraction")
        } catch let error as AIImageTextExtractionError {
            XCTAssertTrue(error.isRegionPolicyBlock)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(RequestCountingURLProtocol.requestCount, 0)
    }

    func test_imageTextExtractionService_blocksUnknownStorefrontBeforeNetworkEvenWithLocalAPIKey() async throws {
        let defaults = UserDefaults.makeIsolated()
        defaults.set("test-api-key", forKey: AppSettings.aiAnalysisAPIKeyKey)
        let service = AIImageTextExtractionService(
            session: .requestCounting,
            userDefaults: defaults,
            aiAvailabilityService: AIAvailabilityService(
                regionPolicy: RegionPolicyResolver.policy(forStorefrontCode: nil),
                userDefaults: defaults
            )
        )

        do {
            _ = try await service.extractText(from: try makeTestImage())
            XCTFail("Expected unknown storefront to block AI image text extraction")
        } catch let error as AIImageTextExtractionError {
            XCTAssertTrue(error.isRegionPolicyBlock)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(RequestCountingURLProtocol.requestCount, 0)
    }

    func test_imageTextExtractionService_allowsOverseasPolicyToReachExistingAPIKeyValidation() async throws {
        let defaults = UserDefaults.makeIsolated()
        let service = AIImageTextExtractionService(
            session: .requestCounting,
            userDefaults: defaults,
            aiAvailabilityService: AIAvailabilityService(
                regionPolicy: RegionPolicyResolver.policy(forStorefrontCode: "USA"),
                userDefaults: defaults
            )
        )

        do {
            _ = try await service.extractText(from: try makeTestImage())
            XCTFail("Expected missing API key after overseas policy allows developer AI path")
        } catch AIImageTextExtractionError.missingAPIKey {
            // Expected: overseas policy allows the existing developer API key validation to run.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(RequestCountingURLProtocol.requestCount, 0)
    }

    private func makeTestImage() throws -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixel: UInt32 = 0xFFFFFFFF
        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        let image = context.makeImage() else {
            throw NSError(domain: "AIServiceRegionPolicyTests", code: 1)
        }
        return image
    }
}

private extension URLSession {
    static var requestCounting: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RequestCountingURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class RequestCountingURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var count = 0

    static var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    static func reset() {
        lock.lock()
        count = 0
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lock.lock()
        Self.count += 1
        Self.lock.unlock()
        client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
    }

    override func stopLoading() {}
}

private extension AIAnalysisError {
    var isRegionPolicyBlock: Bool {
        if case let .requestFailed(reason) = self {
            return reason.contains("区域") || reason.lowercased().contains("region")
        }
        return false
    }
}

private extension AIImageTextExtractionError {
    var isRegionPolicyBlock: Bool {
        if case let .requestFailed(reason) = self {
            return reason.contains("区域") || reason.lowercased().contains("region")
        }
        return false
    }
}
