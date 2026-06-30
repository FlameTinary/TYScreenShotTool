import { Buffer } from "node:buffer";

/**
 * Apple Sign In JWT 验证模块
 * 验证 Apple 返回的 identity token（JWT），确保签名和 claims 合法
 *
 * ⚠️ 注意：workerd 运行时内置的 HTTP 客户端可能被 Apple CDN 的 WAF 拦截（返回 403），
 * 因此内嵌了一份备用的 Apple 公钥（EMBEDDED_APPLE_KEYS），
 * 当 fetch 远端失败时自动降级使用。
 */

/**
 * 内嵌备用 Apple 公钥（2026-06-30 抓取）
 * 当 workerd 的 fetch 被 Apple CDN 拦截时自动降级使用。
 */
const EMBEDDED_APPLE_KEYS: AppleKeysResponse = {
  keys: [
    {
      kty: "RSA",
      kid: "1E6VioIaNI",
      use: "sig",
      alg: "RS256",
      n: "ttL4HNkWLS_Oh0GADZqA4lTM8Y8UyaCR2NfIcvxby6quhwIISI9o9iCw3ggMYnqEG-dfRHcpsWLp2MZH_CNC-2pB0l_tDKeLi1eytR0_3YUHQBBQlkDjDP-hlyS0xJD1ds0un4mOIhc-oPHK2xiYbSVbJcBTKYA6FPoAa7u_YbsKN1YnUqzoRf2iOpARBurhCkvmJKjXwcH6RNGM9iScOO-U9orB5-EQivCKdDnMiwsPaA6_Jx1DzKyaZI6UCV_CZV3k59XvbeYGV3JXJMtKjlwaIumX3i5ecT4lz_XUr7ZYf1tA1v4ewGnrb5TFr86U-NE6uhvEtpA-_uVWPMmy_Q",
      e: "AQAB"
    },
    {
      kty: "RSA",
      kid: "5iq33lJBYj",
      use: "sig",
      alg: "RS256",
      n: "vcDUGnc9ITh348cRCn6CENlcFzOm4X_sxDyPumPZrM3YhH_zXfjNhBCQnvTGNFqGzsqok87ufbWSEqYiYQDsh8DMTT_tx5bcuRJI-LmuX3CkLOKq0KXVUzijpj45mTvdGoC_dL2ei_nGs9yz0EJwilNpwPZxkGxNhWi7MWobOd4BjzBIkqDw_HqKZ_486EKHhyV0qgXfwQYgnKT9blBYc6ZNej9MPHyve5lZs084uEiY_UYjV0rlxfZdYa0g3scG7wc2dWMlqZ4QvbPMj0KTzMNtO-9cr3aruTTPQ2qDqFAThZDNrPaScJIXAcgrARvqy1CAMT_8gSYFbb4Ld0tRbQ",
      e: "AQAB"
    },
    {
      kty: "RSA",
      kid: "5RFOSiNIUm",
      use: "sig",
      alg: "RS256",
      n: "qaLbQzOrRmIXwJkuWpRu7T6ApMcoBA_QxFUO4foV5A1JhEE_Gg4uOCQ8kDSPJHGhPl8RBZ0o4niyUWYkS3IIgjUq3pMAwSDxczqKq00Z82gCN6nYAwlI-_iMsepM5kk86XjB_MJMVdU3NGCHReITotsyXnZ0A7v0RU_LYLzdgoobsK1jh5y4XsgiDf25ZGILiYjxVzYNcaJ5G01Rg9j0ydEJYMOC_dT9xcfQzy2LiOlhGn3rDpQIyhVuqprvUeLAJPEFQoH486VjcnDxKMLCs2L5aSlTj78BxgYNV24FRRTl8QAyhIMi4e0Ja_4i59OCOVZMbR4p1_o_cszhOGIlmw",
      e: "AQAB"
    }
  ]
};

/** Apple JWK 公钥结构 */
interface AppleJWK {
  kty: string;
  kid: string;
  use: string;
  alg: string;
  n: string;
  e: string;
}

/** Apple 公钥响应结构 */
interface AppleKeysResponse {
  keys: AppleJWK[];
}

/** JWT 解码后的 header */
interface JWTHeader {
  alg?: string;
  kid?: string;
  x5c?: string[];
  [key: string]: unknown;
}

/** JWT 解码后的 claims */
interface JWTPayload {
  iss?: string;
  sub?: string;
  aud?: string;
  exp?: number;
  iat?: number;
  email?: string;
  email_verified?: boolean;
  [key: string]: unknown;
}

/** Apple JWT 验证成功后返回的 claims（仅提取业务需要的字段） */
export interface AppleJWTClaims {
  /** Apple 用户唯一标识符（sub claim） */
  sub: string;
  /** 用户邮箱（可选） */
  email?: string;
  /** 邮箱是否已验证（可选） */
  emailVerified?: boolean;
}

/**
 * StoreKit 交易 JWT payload 结构
 * 客户端调用 StoreKit 购买后返回的 signedTransaction 中包含的字段
 */
export interface StoreKitTransactionPayload {
  /** 本次交易唯一标识符 */
  transactionId: string;
  /** 原始交易标识符（自动续期订阅跨期关联） */
  originalTransactionId: string;
  /** 购买的产品 ID */
  productId: string;
  /** 应用的 Bundle Identifier */
  bundleId: string;
  /** 交易环境 */
  environment: "Sandbox" | "Production" | "Xcode" | "LocalTesting";
  /** 订阅到期时间（Unix 毫秒时间戳），仅自动续期订阅有此字段 */
  expiresDate?: number | undefined;
  /** 购买时间（Unix 毫秒时间戳） */
  purchaseDate: number;
  /** JWT 签名时间（Unix 毫秒时间戳） */
  signedDate: number;
  /** 用户关联 UUID（可选，客户端购买时传入） */
  appAccountToken?: string;
}

/**
 * App Store Server 通知 payload 结构
 * Apple 服务器推送的通知中包含的字段
 */
export interface AppStoreNotificationPayload {
  /** 通知类型 */
  notificationType: string;
  /** 通知子类型（可选） */
  subtype?: string | undefined;
  /** 应用的 Bundle Identifier */
  bundleId: string;
  /** 交易环境 */
  environment: "Sandbox" | "Production";
  /** 经过签名的交易信息 JWT */
  signedTransactionInfo: string;
  /** 通知唯一标识符 */
  notificationUUID: string;
  /** 通知签名时间（Unix 毫秒时间戳） */
  signedDate: number;
}

export interface AppStoreSignedDataVerificationConfig {
  /** Apple Root CA PEM，可包含多个证书。 */
  rootCertificatesPem?: string;
  /** App Store Connect 中的 Apple App ID。生产环境 JWS 校验需要该值。 */
  appAppleId?: string;
  /** 是否允许 Xcode / LocalTesting StoreKit 交易。仅限本地开发和测试环境开启。 */
  allowLocalTestingTransactions?: boolean;
}

/** 公钥缓存 */
let cachedKeys: { keys: AppleJWK[]; expiresAt: number } | null = null;
const CACHE_TTL_MS = 3_600_000; // 1 小时

/**
 * 清除缓存的 Apple 公钥（仅在测试中使用）
 */
export function resetAppleKeyCache(): void {
  cachedKeys = null;
}

/**
 * 验证 Apple identity token（JWT）
 *
 * @param identityToken Apple 返回的 JWT 字符串
 * @param bundleId 应用的 Bundle Identifier（用于验证 aud claim）
 * @returns 解析后的 claims：sub, email, emailVerified
 * @throws 如果 JWT 格式/签名/claims 不合法则抛出 Error
 */
export async function verifyAppleJWT(
  identityToken: string,
  bundleId: string
): Promise<AppleJWTClaims> {
  const { payload } = await verifyJWTSignature(identityToken);

  if (payload.iss !== "https://appleid.apple.com") {
    throw new Error(`Invalid JWT issuer: ${payload.iss}`);
  }
  if (payload.aud !== bundleId) {
    throw new Error(`Invalid JWT audience: ${payload.aud}`);
  }
  if (!payload.sub) {
    throw new Error("JWT missing sub claim");
  }
  if (payload.exp && payload.exp < Math.floor(Date.now() / 1000)) {
    throw new Error("JWT has expired");
  }

  return {
    sub: payload.sub,
    ...(payload.email !== undefined ? { email: payload.email } : {}),
    ...(payload.email_verified !== undefined ? { emailVerified: payload.email_verified } : {})
  };
}

/**
 * 验证 StoreKit 交易 JWT（signedTransaction）
 *
 * 客户端在 StoreKit 购买成功后得到 signedTransaction（Apple 签名的 JWT），
 * 后端验证签名并提取交易信息，用于创建或更新订阅记录
 *
 * @param signedTransaction StoreKit 返回的 JWT 字符串
 * @param bundleId 应用的 Bundle Identifier（用于验证 aud claim）
 * @returns 交易信息
 * @throws 如果 JWT 格式/签名/claims 不合法则抛出 Error
 */
export async function verifyStoreKitTransactionJWT(
  signedTransaction: string,
  bundleId: string,
  config: AppStoreSignedDataVerificationConfig = {}
): Promise<StoreKitTransactionPayload> {
  const payload = await verifyAppleSignedTransaction(signedTransaction, bundleId, config);

  const transactionId = payload.transactionId;
  const originalTransactionId = payload.originalTransactionId;
  const productId = payload.productId;
  const environment = payload.environment;

  if (!transactionId) throw new Error("StoreKit JWT missing transactionId");
  if (!originalTransactionId) throw new Error("StoreKit JWT missing originalTransactionId");
  if (!productId) throw new Error("StoreKit JWT missing productId");

  const normalizedEnv = normalizeStoreKitEnvironment(environment);

  return {
    transactionId,
    originalTransactionId,
    productId,
    bundleId,
    environment: normalizedEnv,
    ...(typeof payload.expiresDate === "number" ? { expiresDate: payload.expiresDate } : {}),
    purchaseDate: payload.purchaseDate ?? 0,
    signedDate: payload.signedDate ?? 0,
    ...(payload.appAccountToken !== undefined ? { appAccountToken: payload.appAccountToken } : {})
  };
}

/**
 * 验证 App Store Server 通知 JWT（signedPayload）
 *
 * Apple 服务器在订阅状态变更时推送通知，通知中包含 signedPayload JWT，
 * 验证签名后提取通知类型和交易信息
 *
 * @param signedPayload Apple 推送的 JWT 字符串
 * @param bundleId 应用的 Bundle Identifier
 * @returns 通知信息
 * @throws 如果 JWT 格式/签名/claims 不合法则抛出 Error
 */
export async function verifyAppStoreNotificationJWT(
  signedPayload: string,
  bundleId: string,
  config: AppStoreSignedDataVerificationConfig = {}
): Promise<AppStoreNotificationPayload> {
  const payload = await verifyAppleSignedNotification(signedPayload, bundleId, config);

  const notificationType = payload.notificationType;
  if (!notificationType) {
    throw new Error("App Store notification missing notificationType");
  }

  const data = payload.data;
  if (!data || !data.signedTransactionInfo) {
    throw new Error("App Store notification missing data.signedTransactionInfo");
  }

  const notificationBundleId = data.bundleId;
  if (!notificationBundleId || notificationBundleId !== bundleId) {
    throw new Error(`App Store notification bundleId mismatch: ${notificationBundleId}`);
  }

  const environment = data.environment;
  const normalizedEnv = environment === "Sandbox" ? "Sandbox" : "Production";

  return {
    notificationType: String(notificationType),
    ...(payload.subtype !== undefined ? { subtype: String(payload.subtype) } : {}),
    bundleId,
    environment: normalizedEnv,
    signedTransactionInfo: data.signedTransactionInfo,
    notificationUUID: payload.notificationUUID ?? "",
    signedDate: payload.signedDate ?? 0
  };
}

async function verifyAppleSignedTransaction(
  signedTransaction: string,
  bundleId: string,
  config: AppStoreSignedDataVerificationConfig
) {
  const verifiers = await makeSignedDataVerifiers(bundleId, config);
  let lastError: unknown;
  for (const verifier of verifiers) {
    try {
      return await verifier.verifyAndDecodeTransaction(signedTransaction);
    } catch (error) {
      lastError = error;
    }
  }
  throw lastError instanceof Error ? lastError : new Error("StoreKit JWT verification failed");
}

async function verifyAppleSignedNotification(
  signedPayload: string,
  bundleId: string,
  config: AppStoreSignedDataVerificationConfig
) {
  const verifiers = await makeSignedDataVerifiers(bundleId, config);
  let lastError: unknown;
  for (const verifier of verifiers) {
    try {
      return await verifier.verifyAndDecodeNotification(signedPayload);
    } catch (error) {
      lastError = error;
    }
  }
  throw lastError instanceof Error ? lastError : new Error("App Store notification verification failed");
}

async function makeSignedDataVerifiers(
  bundleId: string,
  config: AppStoreSignedDataVerificationConfig
){
  const { Environment, SignedDataVerifier } = await import("@apple/app-store-server-library");
  const localTestingVerifiers = config.allowLocalTestingTransactions
    ? [
        new SignedDataVerifier([], false, Environment.XCODE, bundleId),
        new SignedDataVerifier([], false, Environment.LOCAL_TESTING, bundleId)
      ]
    : [];

  if (!config.rootCertificatesPem?.trim()) {
    if (localTestingVerifiers.length > 0) {
      return localTestingVerifiers;
    }
    throw new Error("Missing APPLE_ROOT_CERTIFICATES_PEM for App Store signed data verification");
  }

  const rootCertificates = parseRootCertificates(config.rootCertificatesPem);
  const appAppleId = parseAppAppleId(config.appAppleId);
  const enableOnlineChecks = true;

  return [
    ...localTestingVerifiers,
    new SignedDataVerifier(rootCertificates, enableOnlineChecks, Environment.SANDBOX, bundleId),
    new SignedDataVerifier(rootCertificates, enableOnlineChecks, Environment.PRODUCTION, bundleId, appAppleId)
  ];
}

function normalizeStoreKitEnvironment(environment: unknown): StoreKitTransactionPayload["environment"] {
  switch (environment) {
    case "Sandbox":
    case "Production":
    case "Xcode":
    case "LocalTesting":
      return environment;
    default:
      return "Production";
  }
}

function parseRootCertificates(rootCertificatesPem?: string): Buffer[] {
  if (!rootCertificatesPem?.trim()) {
    throw new Error("Missing APPLE_ROOT_CERTIFICATES_PEM for App Store signed data verification");
  }

  const matches = rootCertificatesPem.match(
    /-----BEGIN CERTIFICATE-----[\s\S]+?-----END CERTIFICATE-----/g
  );
  if (!matches?.length) {
    throw new Error("APPLE_ROOT_CERTIFICATES_PEM does not contain a PEM certificate");
  }

  return matches.map((pem) => {
    const base64 = pem
      .replace(/-----BEGIN CERTIFICATE-----/g, "")
      .replace(/-----END CERTIFICATE-----/g, "")
      .replace(/\s/g, "");
    return Buffer.from(base64, "base64");
  });
}

function parseAppAppleId(appAppleId?: string): number | undefined {
  if (!appAppleId?.trim()) {
    return undefined;
  }

  const parsed = Number(appAppleId);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error("APPLE_APP_ID must be a positive integer");
  }
  return parsed;
}

/**
 * 解析 JWT 并验证 RS256 签名（共享内部逻辑）
 * 使用 Apple 公钥端点 https://appleid.apple.com/auth/keys
 */
async function verifyJWTSignature(jwt: string): Promise<{ header: JWTHeader; payload: JWTPayload; signingData: Uint8Array }> {
  const parts = jwt.split(".");
  if (parts.length !== 3) {
    throw new Error("Invalid JWT format: expected 3 parts");
  }

  const headerB64 = parts[0]!;
  const payloadB64 = parts[1]!;
  const signatureB64 = parts[2]!;
  const header = decodeJWTJSON<JWTHeader>(headerB64);
  const payload = decodeJWTJSON<JWTPayload>(payloadB64);
  const signature = base64URLDecode(signatureB64);
  const signingData = new TextEncoder().encode(`${headerB64}.${payloadB64}`);

  if (header.alg !== "RS256") {
    throw new Error(`Unsupported JWT algorithm: ${header.alg}`);
  }

  const key = await findMatchingKey(header.kid);
  const cryptoKey = await importApplePublicKey(key);
  const isValid = await crypto.subtle.verify(
    { name: "RSASSA-PKCS1-v1_5" },
    cryptoKey,
    signature.buffer as ArrayBuffer,
    signingData.buffer as ArrayBuffer
  );
  if (!isValid) {
    throw new Error("JWT signature verification failed");
  }

  return { header, payload, signingData };
}

/**
 * 从 Apple 公钥端点获取并匹配 JWK
 * 优先在线获取，失败时降级到内嵌备用密钥
 * 使用内存缓存，TTL 1 小时
 */
async function findMatchingKey(kid?: string): Promise<AppleJWK> {
  const now = Date.now();

  async function fetchKeysOrFallback(): Promise<AppleJWK[]> {
    try {
      const response = await fetch("https://appleid.apple.com/auth/keys", {
        headers: {
          Accept: "application/json",
          "User-Agent": "TShotWorker/1.0"
        }
      });
      if (response.ok) {
        const body = (await response.json()) as AppleKeysResponse;
        if (body.keys?.length) return body.keys;
      }
      // 获取失败时记录日志并降级
      const responseText = await response.text().catch(() => "(no body)");
      console.warn(
        JSON.stringify({
          event: "apple_keys_fetch_failed_fallback_to_embedded",
          status: response.status,
          body: responseText.slice(0, 200)
        })
      );
    } catch (err) {
      console.warn(
        JSON.stringify({
          event: "apple_keys_fetch_error_fallback_to_embedded",
          error: err instanceof Error ? err.message : String(err)
        })
      );
    }
    console.warn(JSON.stringify({ event: "apple_keys_using_embedded_fallback" }));
    return [...EMBEDDED_APPLE_KEYS.keys];
  }

  if (!cachedKeys || now > cachedKeys.expiresAt) {
    const keys = await fetchKeysOrFallback();
    cachedKeys = { keys, expiresAt: now + CACHE_TTL_MS };
  }

  if (kid) {
    const found = cachedKeys.keys.find((k) => k.kid === kid);
    if (found) return found;
    // kid 未命中但缓存过期了 → 刷新重试一次（含降级）
    if (now > cachedKeys.expiresAt) {
      const keys = await fetchKeysOrFallback();
      cachedKeys = { keys, expiresAt: Date.now() + CACHE_TTL_MS };
      const retry = cachedKeys.keys.find((k) => k.kid === kid);
      if (retry) return retry;
    }
    throw new Error(`No matching Apple key found for kid: ${kid}`);
  }

  // 没有 kid 时使用第一把可用的签名密钥
  const defaultKey = cachedKeys.keys.find((k) => k.use === "sig" && k.alg === "RS256");
  if (defaultKey) return defaultKey;
  throw new Error("No suitable Apple key found");
}

/**
 * 将 Apple JWK 导入为 Web Crypto API 可用的 CryptoKey
 */
async function importApplePublicKey(jwk: AppleJWK): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    "jwk",
    {
      kty: jwk.kty,
      n: jwk.n,
      e: jwk.e,
      alg: "RS256",
      ext: true
    },
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"]
  );
}

/**
 * Base64URL 解码为 Uint8Array
 * Base64URL 使用 - 代替 +，_ 代替 /
 */
function base64URLDecode(input: string): Uint8Array {
  const base64 = input.replace(/-/g, "+").replace(/_/g, "/");
  const padded = base64.padEnd(base64.length + ((4 - (base64.length % 4)) % 4), "=");
  const binary = atob(padded);
  const buffer = new ArrayBuffer(binary.length);
  const bytes = new Uint8Array(buffer);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

/**
 * 解码 JWT 的 JSON 段（base64url → UTF-8 → JSON）
 */
function decodeJWTJSON<T>(segment: string): T {
  const bytes = base64URLDecode(segment);
  const json = new TextDecoder().decode(bytes);
  try {
    return JSON.parse(json) as T;
  } catch {
    throw new Error("Invalid JWT segment: not valid JSON");
  }
}
