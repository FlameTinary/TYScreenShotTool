/**
 * AI Provider 实现
 * 支持 OpenAI Responses API 与 OpenAI-compatible Chat Completions API。
 */

import type { AIProvider, AIProviderRequest, AIProviderResult } from "./app";

/**
 * OpenAI 提供商环境变量接口
 */
export interface OpenAIProviderEnv {
  /** AI 提供商类型：openai 使用 Responses API；deepseek/openai-compatible 使用 Chat Completions API */
  AI_PROVIDER?: string;
  /** OpenAI API 密钥 */
  OPENAI_API_KEY: string;
  /** OpenAI API 基础 URL（可选，用于自定义端点） */
  OPENAI_BASE_URL?: string;
}

/**
 * AI Provider 不支持当前输入类型时抛出的错误。
 */
export class AIProviderUnsupportedInputError extends Error {
  readonly code = "ai_provider_input_unsupported";

  /**
   * 构造函数
   * @param message 错误说明
   */
  constructor(message: string) {
    super(message);
    this.name = "AIProviderUnsupportedInputError";
  }
}

/**
 * OpenAI Responses API 输出文本结构
 */
interface ResponsesAPIOutputText {
  /** 内容类型 */
  type?: string;
  /** 文本内容 */
  text?: string;
}

/**
 * OpenAI Responses API 输出项结构
 */
interface ResponsesAPIOutputItem {
  /** 内容数组 */
  content?: ResponsesAPIOutputText[];
}

/**
 * OpenAI Responses API 用量信息结构
 */
interface ResponsesAPIUsage {
  /** 输入 Token 数量 */
  input_tokens?: number;
  /** 输出 Token 数量 */
  output_tokens?: number;
}

/**
 * OpenAI Responses API 响应结构
 */
interface ResponsesAPIResponse {
  /** 输出文本（简化格式） */
  output_text?: string;
  /** 输出项数组（完整格式） */
  output?: ResponsesAPIOutputItem[];
  /** 使用的模型名称 */
  model?: string;
  /** 用量信息 */
  usage?: ResponsesAPIUsage;
}

/**
 * Chat Completions API 消息内容结构
 */
type ChatCompletionContent =
  | { type: "text"; text: string }
  | { type: "image_url"; image_url: { url: string } };

/**
 * Chat Completions API 响应结构
 */
interface ChatCompletionsAPIResponse {
  /** 使用的模型名称 */
  model?: string;
  /** 响应候选 */
  choices?: Array<{
    message?: {
      content?: string | Array<{ text?: string }>;
    };
  }>;
  /** 用量信息 */
  usage?: {
    prompt_tokens?: number;
    completion_tokens?: number;
  };
}

/**
 * 根据运行时配置创建 AI Provider。
 * @param env 运行时环境变量
 * @returns AI Provider
 */
export function createAIProvider(env: OpenAIProviderEnv): AIProvider {
  const provider = env.AI_PROVIDER?.trim().toLowerCase();
  if (provider === "deepseek") {
    return new OpenAICompatibleChatProvider(env, { supportsImageInput: false, providerName: "DeepSeek" });
  }
  if (provider === "openai-compatible" || provider === "chat-completions") {
    return new OpenAICompatibleChatProvider(env);
  }
  return new OpenAIResponsesProvider(env);
}

/**
 * OpenAI Responses API 提供商类
 * 实现 AIProvider 接口，用于调用 OpenAI 的图片分析能力
 */
export class OpenAIResponsesProvider implements AIProvider {
  /**
   * 构造函数
   * @param env OpenAI 环境变量配置
   */
  constructor(private readonly env: OpenAIProviderEnv) {}

  /**
   * 分析截图图片
   * 调用 OpenAI Responses API 进行图片理解和分析
   * @param request AI 请求参数
   * @returns AI 分析结果
   */
  async analyzeScreenshot(request: AIProviderRequest): Promise<AIProviderResult> {
    const response = await fetch(this.responsesURL(), {
      method: "POST",
      headers: {
        Authorization: `Bearer ${this.env.OPENAI_API_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model: request.model,
        max_output_tokens: request.maxOutputTokens,
        input: [
          {
            role: "user",
            content: [
              {
                type: "input_text",
                text: request.prompt
              },
              {
                type: "input_image",
                image_url: normalizeImageURL(request.imageBase64)
              }
            ]
          }
        ]
      })
    });

    if (!response.ok) {
      const diagnostic = await safeErrorText(response);
      throw new Error(`OpenAI Responses API failed: ${response.status}${diagnostic}`);
    }

    const body = (await response.json()) as ResponsesAPIResponse;
    const text = extractResponseText(body);
    if (!text) {
      throw new Error("OpenAI Responses API returned empty text");
    }

    return {
      text,
      model: body.model ?? request.model,
      inputTokenCount: body.usage?.input_tokens ?? 0,
      outputTokenCount: body.usage?.output_tokens ?? 0,
      estimatedCost: 0
    };
  }

  /**
   * 构建 Responses API 的完整 URL
   * @returns API 端点 URL
   */
  private responsesURL(): string {
    const baseURL = this.env.OPENAI_BASE_URL || "https://api.openai.com";
    const normalized = baseURL.replace(/\/+$/, "");
    return normalized.endsWith("/v1") ? `${normalized}/responses` : `${normalized}/v1/responses`;
  }
}

/**
 * OpenAI-compatible Chat Completions 提供商。
 * DeepSeek 等兼容 OpenAI Chat Completions 的服务走这里。
 */
export class OpenAICompatibleChatProvider implements AIProvider {
  /**
   * 构造函数
   * @param env OpenAI-compatible 环境变量配置
   * @param options Provider 能力配置
   */
  constructor(
    private readonly env: OpenAIProviderEnv,
    private readonly options: { supportsImageInput?: boolean; providerName?: string } = { supportsImageInput: true }
  ) {}

  /**
   * 分析截图图片
   * @param request AI 请求参数
   * @returns AI 分析结果
   */
  async analyzeScreenshot(request: AIProviderRequest): Promise<AIProviderResult> {
    if (this.options.supportsImageInput === false) {
      const providerName = this.options.providerName ?? "OpenAI-compatible provider";
      throw new AIProviderUnsupportedInputError(
        `${providerName} does not support image input for screenshot analysis. Configure a vision-capable AI provider.`
      );
    }

    const response = await fetch(this.chatCompletionsURL(), {
      method: "POST",
      headers: {
        Authorization: `Bearer ${this.env.OPENAI_API_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model: request.model,
        max_tokens: request.maxOutputTokens,
        messages: [
          {
            role: "user",
            content: [
              {
                type: "text",
                text: request.prompt
              },
              {
                type: "image_url",
                image_url: {
                  url: normalizeImageURL(request.imageBase64)
                }
              }
            ] satisfies ChatCompletionContent[]
          }
        ]
      })
    });

    if (!response.ok) {
      const diagnostic = await safeErrorText(response);
      throw new Error(`Chat Completions API failed: ${response.status}${diagnostic}`);
    }

    const body = (await response.json()) as ChatCompletionsAPIResponse;
    const text = extractChatCompletionText(body);
    if (!text) {
      throw new Error("Chat Completions API returned empty text");
    }

    return {
      text,
      model: body.model ?? request.model,
      inputTokenCount: body.usage?.prompt_tokens ?? 0,
      outputTokenCount: body.usage?.completion_tokens ?? 0,
      estimatedCost: 0
    };
  }

  /**
   * 构建 Chat Completions API 的完整 URL
   * @returns API 端点 URL
   */
  private chatCompletionsURL(): string {
    const baseURL = this.env.OPENAI_BASE_URL || "https://api.openai.com";
    const normalized = baseURL.replace(/\/+$/, "");
    return normalized.endsWith("/v1") ? `${normalized}/chat/completions` : `${normalized}/v1/chat/completions`;
  }
}

/**
 * 规范化图片 URL
 * 将 Base64 字符串转换为 data URL 格式
 * @param imageBase64 图片的 Base64 编码字符串
 * @returns 规范化的 data URL
 */
function normalizeImageURL(imageBase64: string): string {
  if (imageBase64.startsWith("data:")) {
    return imageBase64;
  }
  return `data:image/png;base64,${imageBase64}`;
}

/**
 * 从 API 响应中提取文本内容
 * 优先使用简化格式的 output_text，回退到完整格式的 output 数组
 * @param body API 响应体
 * @returns 提取的文本内容
 */
function extractResponseText(body: ResponsesAPIResponse): string {
  if (body.output_text?.trim()) {
    return body.output_text.trim();
  }

  return body.output
    ?.flatMap((item) => item.content ?? [])
    .map((content) => content.text ?? "")
    .find((text) => text.trim())
    ?.trim() ?? "";
}

/**
 * 从 Chat Completions 响应中提取文本内容。
 * @param body API 响应体
 * @returns 提取的文本内容
 */
function extractChatCompletionText(body: ChatCompletionsAPIResponse): string {
  const content = body.choices?.[0]?.message?.content;
  if (typeof content === "string") {
    return content.trim();
  }

  return content
    ?.map((item) => item.text ?? "")
    .find((text) => text.trim())
    ?.trim() ?? "";
}

/**
 * 安全读取 provider 错误响应，避免错误文本过长污染日志。
 * @param response Provider 响应
 * @returns 截断后的诊断文本
 */
async function safeErrorText(response: Response): Promise<string> {
  try {
    const text = await response.text();
    const trimmed = text.trim();
    return trimmed ? ` ${trimmed.slice(0, 300)}` : "";
  } catch {
    return "";
  }
}
