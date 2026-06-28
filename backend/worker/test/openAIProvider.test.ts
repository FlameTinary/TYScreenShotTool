import { afterEach, describe, expect, it, vi } from "vitest";
import { createAIProvider } from "../src/openAIProvider";

describe("AI provider selection", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("rejects image analysis for DeepSeek because it is text-only", async () => {
    const fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);

    const provider = createAIProvider({
      AI_PROVIDER: "deepseek",
      OPENAI_API_KEY: "test-key",
      OPENAI_BASE_URL: "https://api.deepseek.com"
    });

    await expect(provider.analyzeScreenshot({
      requestId: "req_1",
      userId: "user_1",
      imageBase64: "aGVsbG8=",
      prompt: "描述图片",
      model: "deepseek-v4-flash",
      maxOutputTokens: 1200
    })).rejects.toMatchObject({
      code: "ai_provider_input_unsupported"
    });
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("uses OpenAI-compatible chat completions for vision-capable compatible providers", async () => {
    const fetchMock = vi.fn(async (_input: RequestInfo | URL, _init?: RequestInit) => new Response(
      JSON.stringify({
        model: "deepseek-v4-flash",
        choices: [
          {
            message: {
              content: "这是一张 1x1 的测试图片。"
            }
          }
        ],
        usage: {
          prompt_tokens: 12,
          completion_tokens: 9
        }
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" }
      }
    ));
    vi.stubGlobal("fetch", fetchMock);

    const provider = createAIProvider({
      AI_PROVIDER: "openai-compatible",
      OPENAI_API_KEY: "test-key",
      OPENAI_BASE_URL: "https://api.example.com"
    });

    const result = await provider.analyzeScreenshot({
      requestId: "req_1",
      userId: "user_1",
      imageBase64: "aGVsbG8=",
      prompt: "描述图片",
      model: "deepseek-v4-flash",
      maxOutputTokens: 1200
    });

    expect(fetchMock).toHaveBeenCalledOnce();
    const call = fetchMock.mock.calls[0];
    if (!call) {
      throw new Error("Expected fetch to be called");
    }
    const [url, init] = call;
    expect(typeof url).toBe("string");
    if (!init) {
      throw new Error("Expected fetch init to be set");
    }
    expect(url).toBe("https://api.example.com/v1/chat/completions");
    expect(init.method).toBe("POST");
    expect(init.headers).toMatchObject({
      Authorization: "Bearer test-key",
      "Content-Type": "application/json"
    });
    expect(JSON.parse(init.body as string)).toMatchObject({
      model: "deepseek-v4-flash",
      max_tokens: 1200,
      messages: [
        {
          role: "user",
          content: [
            { type: "text", text: "描述图片" },
            { type: "image_url", image_url: { url: "data:image/png;base64,aGVsbG8=" } }
          ]
        }
      ]
    });
    expect(result).toMatchObject({
      text: "这是一张 1x1 的测试图片。",
      model: "deepseek-v4-flash",
      inputTokenCount: 12,
      outputTokenCount: 9
    });
  });

  it("uses OpenAI responses by default", async () => {
    const fetchMock = vi.fn(async (_input: RequestInfo | URL, _init?: RequestInit) => new Response(
      JSON.stringify({
        model: "gpt-5.4-mini",
        output_text: "A tiny test image.",
        usage: {
          input_tokens: 10,
          output_tokens: 5
        }
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" }
      }
    ));
    vi.stubGlobal("fetch", fetchMock);

    const provider = createAIProvider({
      OPENAI_API_KEY: "test-key"
    });

    const result = await provider.analyzeScreenshot({
      requestId: "req_1",
      userId: "user_1",
      imageBase64: "aGVsbG8=",
      prompt: "Describe image",
      model: "gpt-5.4-mini",
      maxOutputTokens: 1200
    });

    const call = fetchMock.mock.calls[0];
    if (!call) {
      throw new Error("Expected fetch to be called");
    }
    const [url] = call;
    expect(url).toBe("https://api.openai.com/v1/responses");
    expect(result.text).toBe("A tiny test image.");
  });

  it("includes truncated OpenAI responses error details for diagnostics", async () => {
    const fetchMock = vi.fn(async (_input: RequestInfo | URL, _init?: RequestInit) => new Response(
      JSON.stringify({
        error: {
          message: "Unsupported parameter: max_output_tokens",
          type: "invalid_request_error",
          code: "unsupported_parameter"
        }
      }),
      {
        status: 400,
        headers: { "Content-Type": "application/json" }
      }
    ));
    vi.stubGlobal("fetch", fetchMock);

    const provider = createAIProvider({
      AI_PROVIDER: "openai",
      OPENAI_API_KEY: "test-key"
    });

    await expect(provider.analyzeScreenshot({
      requestId: "req_error",
      userId: "user_1",
      imageBase64: "aGVsbG8=",
      prompt: "Describe image",
      model: "gpt-5.3",
      maxOutputTokens: 1200
    })).rejects.toThrow(/OpenAI Responses API failed: 400.*unsupported_parameter/s);
  });
});
