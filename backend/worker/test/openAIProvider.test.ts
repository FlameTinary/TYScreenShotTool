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

  it("analyzeText works with DeepSeek (text-only chat completions)", async () => {
    const fetchMock = vi.fn(async (_input: RequestInfo | URL, _init?: RequestInit) => new Response(
      JSON.stringify({
        model: "deepseek-v4-flash",
        choices: [{ message: { content: "REST API 是一种设计风格。" } }],
        usage: { prompt_tokens: 10, completion_tokens: 8 }
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    ));
    vi.stubGlobal("fetch", fetchMock);

    const provider = createAIProvider({
      AI_PROVIDER: "deepseek",
      OPENAI_API_KEY: "test-key",
      OPENAI_BASE_URL: "https://api.deepseek.com"
    });

    const result = await provider.analyzeText({
      requestId: "req_text_1",
      userId: "user_1",
      prompt: "什么是 REST API？",
      model: "deepseek-v4-flash",
      maxOutputTokens: 1200
    });

    expect(fetchMock).toHaveBeenCalledOnce();
    const call = fetchMock.mock.calls[0];
    if (!call) throw new Error("Expected fetch to be called");
    const [url, init] = call;
    expect(url).toBe("https://api.deepseek.com/v1/chat/completions");
    const body = JSON.parse(init?.body as string);
    expect(body).toMatchObject({
      model: "deepseek-v4-flash",
      max_tokens: 1200,
      messages: [{ role: "user", content: "什么是 REST API？" }]
    });
    // 文字请求不应包含 image_url
    expect(body.messages[0].content).toBeTypeOf("string");
    expect(result).toMatchObject({
      text: "REST API 是一种设计风格。",
      model: "deepseek-v4-flash",
      inputTokenCount: 10,
      outputTokenCount: 8
    });
  });

  it("analyzeText uses OpenAI-compatible chat completions without image", async () => {
    const fetchMock = vi.fn(async (_input: RequestInfo | URL, _init?: RequestInit) => new Response(
      JSON.stringify({
        model: "gpt-5.4-mini",
        choices: [{ message: { content: "这是一段文字分析结果。" } }],
        usage: { prompt_tokens: 15, completion_tokens: 12 }
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    ));
    vi.stubGlobal("fetch", fetchMock);

    const provider = createAIProvider({
      AI_PROVIDER: "openai-compatible",
      OPENAI_API_KEY: "test-key",
      OPENAI_BASE_URL: "https://api.example.com"
    });

    const result = await provider.analyzeText({
      requestId: "req_text_2",
      userId: "user_1",
      prompt: "分析这段文字",
      model: "gpt-5.4-mini",
      maxOutputTokens: 1200
    });

    expect(fetchMock).toHaveBeenCalledOnce();
    const call = fetchMock.mock.calls[0];
    if (!call) throw new Error("Expected fetch to be called");
    const [url, init] = call;
    expect(url).toBe("https://api.example.com/v1/chat/completions");
    const body = JSON.parse(init?.body as string);
    expect(body).toMatchObject({
      model: "gpt-5.4-mini",
      max_tokens: 1200,
      messages: [{ role: "user", content: "分析这段文字" }]
    });
    expect(body.messages[0].content).toBeTypeOf("string");
    expect(result).toMatchObject({
      text: "这是一段文字分析结果。",
      model: "gpt-5.4-mini",
      inputTokenCount: 15,
      outputTokenCount: 12
    });
  });

  it("analyzeText uses OpenAI Responses API with plain text input", async () => {
    const fetchMock = vi.fn(async (_input: RequestInfo | URL, _init?: RequestInit) => new Response(
      JSON.stringify({
        model: "gpt-5.4-mini",
        output_text: "Plain text analysis result.",
        usage: { input_tokens: 8, output_tokens: 5 }
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    ));
    vi.stubGlobal("fetch", fetchMock);

    const provider = createAIProvider({
      OPENAI_API_KEY: "test-key"
    });

    const result = await provider.analyzeText({
      requestId: "req_text_3",
      userId: "user_1",
      prompt: "Describe REST API",
      model: "gpt-5.4-mini",
      maxOutputTokens: 1200
    });

    const call = fetchMock.mock.calls[0];
    if (!call) throw new Error("Expected fetch to be called");
    const [url, init] = call;
    expect(url).toBe("https://api.openai.com/v1/responses");
    const body = JSON.parse(init?.body as string);
    expect(body).toMatchObject({
      model: "gpt-5.4-mini",
      max_output_tokens: 1200,
      input: "Describe REST API"
    });
    // 文字请求的 input 应为字符串，而非数组
    expect(body.input).toBeTypeOf("string");
    expect(result.text).toBe("Plain text analysis result.");
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
