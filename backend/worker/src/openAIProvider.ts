/**
 * OpenAI Responses API 提供商实现
 * 封装对 OpenAI 图片分析能力的调用
 */

import type { AIProvider, AIProviderRequest, AIProviderResult } from "./app";

/**
 * OpenAI 提供商环境变量接口
 */
export interface OpenAIProviderEnv {
  /** OpenAI API 密钥 */
  OPENAI_API_KEY: string;
  /** OpenAI API 基础 URL（可选，用于自定义端点） */
  OPENAI_BASE_URL?: string;
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
      throw new Error(`OpenAI Responses API failed: ${response.status}`);
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
