/**
 * Apple JWT 验证模块测试
 * 使用真实 RSA 密钥对测试 JWT 签名验证流程
 */

import { afterEach, describe, expect, it, vi } from "vitest";
import { resetAppleKeyCache, verifyAppleJWT, verifyStoreKitTransactionJWT } from "../src/appleAuth";

afterEach(() => {
  vi.restoreAllMocks();
  resetAppleKeyCache();
});

/**
 * Base64URL 编码
 */
function base64URLEncode(data: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < data.length; i++) {
    binary += String.fromCharCode(data[i]!);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/**
 * 异步生成 RSA 密钥对
 */
async function generateTestKeyPair(): Promise<CryptoKeyPair> {
  return crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256"
    },
    true,
    ["sign", "verify"]
  );
}

/**
 * 导出公钥为 JWK 格式（模拟 Apple 返回的格式）
 */
async function exportPublicKeyJWK(key: CryptoKey, kid: string) {
  const jwk = await crypto.subtle.exportKey("jwk", key);
  return {
    kty: jwk.kty!,
    kid,
    use: "sig",
    alg: "RS256",
    n: jwk.n!,
    e: jwk.e!
  };
}

/**
 * 创建测试用 Apple JWT
 */
async function createTestJWT(
  privateKey: CryptoKey,
  kid: string,
  payloadOverrides: Record<string, unknown> = {}
): Promise<string> {
  const header = { alg: "RS256", kid };
  const payload = {
    iss: "https://appleid.apple.com",
    sub: "test-apple-user-001",
    aud: "com.tshot.app",
    exp: 4_500_000_000,
    iat: 1_700_000_000,
    email: "test@example.com",
    email_verified: true,
    ...payloadOverrides
  };

  const headerB64 = base64URLEncode(new TextEncoder().encode(JSON.stringify(header)));
  const payloadB64 = base64URLEncode(new TextEncoder().encode(JSON.stringify(payload)));
  const signingInput = `${headerB64}.${payloadB64}`;

  const signature = await crypto.subtle.sign(
    { name: "RSASSA-PKCS1-v1_5" },
    privateKey,
    new TextEncoder().encode(signingInput)
  );

  const signatureB64 = base64URLEncode(new Uint8Array(signature));
  return `${signingInput}.${signatureB64}`;
}

describe("Apple JWT verification", () => {
  it("verifies a valid Apple JWT successfully", async () => {
    const keyPair = await generateTestKeyPair();
    const kid = "test-key-id-001";
    const appleJWK = await exportPublicKeyJWK(keyPair.publicKey, kid);

    // Mock Apple 公钥端点
    vi.stubGlobal("fetch", vi.fn(async () =>
      new Response(JSON.stringify({ keys: [appleJWK] }), {
        status: 200,
        headers: { "Content-Type": "application/json" }
      })
    ));

    const jwt = await createTestJWT(keyPair.privateKey, kid);

    const claims = await verifyAppleJWT(jwt, "com.tshot.app");

    expect(claims).toMatchObject({
      sub: "test-apple-user-001",
      email: "test@example.com",
      emailVerified: true
    });
  });

  it("rejects a JWT with invalid issuer", async () => {
    const keyPair = await generateTestKeyPair();
    const kid = "test-key-id-002";
    const appleJWK = await exportPublicKeyJWK(keyPair.publicKey, kid);

    vi.stubGlobal("fetch", vi.fn(async () =>
      new Response(JSON.stringify({ keys: [appleJWK] }), {
        status: 200,
        headers: { "Content-Type": "application/json" }
      })
    ));

    const jwt = await createTestJWT(keyPair.privateKey, kid, { iss: "https://evil.com" });

    await expect(verifyAppleJWT(jwt, "com.tshot.app")).rejects.toThrow("Invalid JWT issuer");
  });

  it("rejects a JWT with wrong audience", async () => {
    const keyPair = await generateTestKeyPair();
    const kid = "test-key-id-003";
    const appleJWK = await exportPublicKeyJWK(keyPair.publicKey, kid);

    vi.stubGlobal("fetch", vi.fn(async () =>
      new Response(JSON.stringify({ keys: [appleJWK] }), {
        status: 200,
        headers: { "Content-Type": "application/json" }
      })
    ));

    const jwt = await createTestJWT(keyPair.privateKey, kid, { aud: "com.other.app" });

    await expect(verifyAppleJWT(jwt, "com.tshot.app")).rejects.toThrow("Invalid JWT audience");
  });

  it("rejects an expired JWT", async () => {
    const keyPair = await generateTestKeyPair();
    const kid = "test-key-id-004";
    const appleJWK = await exportPublicKeyJWK(keyPair.publicKey, kid);

    vi.stubGlobal("fetch", vi.fn(async () =>
      new Response(JSON.stringify({ keys: [appleJWK] }), {
        status: 200,
        headers: { "Content-Type": "application/json" }
      })
    ));

    // 设置 exp 为过去的时间
    const jwt = await createTestJWT(keyPair.privateKey, kid, { exp: 1_000_000 });

    await expect(verifyAppleJWT(jwt, "com.tshot.app")).rejects.toThrow("JWT has expired");
  });

  it("rejects a tampered JWT (wrong signature)", async () => {
    const keyPair = await generateTestKeyPair();
    const kid = "test-key-id-005";
    const appleJWK = await exportPublicKeyJWK(keyPair.publicKey, kid);

    vi.stubGlobal("fetch", vi.fn(async () =>
      new Response(JSON.stringify({ keys: [appleJWK] }), {
        status: 200,
        headers: { "Content-Type": "application/json" }
      })
    ));

    // 创建 JWT 然后篡改 payload
    const jwt = await createTestJWT(keyPair.privateKey, kid);
    const parts = jwt.split(".");
    const originalPayload = JSON.parse(atob(parts[1]!.replace(/-/g, "+").replace(/_/g, "/")));
    const tamperedPayload = base64URLEncode(
      new TextEncoder().encode(JSON.stringify({ ...originalPayload, sub: "hacker" }))
    );
    const tamperedJWT = `${parts[0]}.${tamperedPayload}.${parts[2]}`;

    await expect(verifyAppleJWT(tamperedJWT, "com.tshot.app")).rejects.toThrow("JWT signature verification failed");
  });

  it("rejects an invalid JWT format", async () => {
    vi.stubGlobal("fetch", vi.fn());

    await expect(verifyAppleJWT("not-a-jwt", "com.tshot.app")).rejects.toThrow("Invalid JWT format");
  });

  it("skips emailVerified when not present", async () => {
    const keyPair = await generateTestKeyPair();
    const kid = "test-key-id-006";
    const appleJWK = await exportPublicKeyJWK(keyPair.publicKey, kid);

    vi.stubGlobal("fetch", vi.fn(async () =>
      new Response(JSON.stringify({ keys: [appleJWK] }), {
        status: 200,
        headers: { "Content-Type": "application/json" }
      })
    ));

    const jwt = await createTestJWT(keyPair.privateKey, kid, { email_verified: undefined });
    const claims = await verifyAppleJWT(jwt, "com.tshot.app");

    expect(claims).toMatchObject({
      sub: "test-apple-user-001",
      email: "test@example.com"
    });
    expect(claims.emailVerified).toBeUndefined();
  });

  it("requires Apple root certificates for StoreKit signed transaction verification", async () => {
    await expect(
      verifyStoreKitTransactionJWT("header.payload.signature", "com.tshot.app")
    ).rejects.toThrow("Missing APPLE_ROOT_CERTIFICATES_PEM");
  });

  it("rejects invalid Apple App ID configuration for StoreKit signed transaction verification", async () => {
    await expect(
      verifyStoreKitTransactionJWT("header.payload.signature", "com.tshot.app", {
        rootCertificatesPem: "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----",
        appAppleId: "not-a-number"
      })
    ).rejects.toThrow("APPLE_APP_ID must be a positive integer");
  });
});
