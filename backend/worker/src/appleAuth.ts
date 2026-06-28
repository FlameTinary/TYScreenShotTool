/**
 * Apple Sign In JWT 验证模块
 * 验证 Apple 返回的 identity token（JWT），确保签名和 claims 合法
 */

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
  // 1. 解析 JWT
  const parts = identityToken.split(".");
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

  // 2. 验证算法
  if (header.alg !== "RS256") {
    throw new Error(`Unsupported JWT algorithm: ${header.alg}`);
  }

  // 3. 获取 Apple 公钥并验证签名
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

  // 4. 验证 claims
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
 * 从 Apple 公钥端点获取并匹配 JWK
 * 使用内存缓存，TTL 1 小时
 */
async function findMatchingKey(kid?: string): Promise<AppleJWK> {
  const now = Date.now();

  if (!cachedKeys || now > cachedKeys.expiresAt) {
    const response = await fetch("https://appleid.apple.com/auth/keys");
    if (!response.ok) {
      throw new Error(`Failed to fetch Apple keys: ${response.status}`);
    }
    const body = (await response.json()) as AppleKeysResponse;
    if (!body.keys?.length) {
      throw new Error("Apple returned empty keys");
    }
    cachedKeys = { keys: body.keys, expiresAt: now + CACHE_TTL_MS };
  }

  if (kid) {
    const found = cachedKeys.keys.find((k) => k.kid === kid);
    if (found) return found;
    // kid 未命中但缓存过期了 → 刷新缓存重试一次
    if (cachedKeys && now > cachedKeys.expiresAt) {
      const response = await fetch("https://appleid.apple.com/auth/keys");
      if (!response.ok) {
        throw new Error(`Failed to fetch Apple keys: ${response.status}`);
      }
      const body = (await response.json()) as AppleKeysResponse;
      cachedKeys = { keys: body.keys, expiresAt: Date.now() + CACHE_TTL_MS };
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
