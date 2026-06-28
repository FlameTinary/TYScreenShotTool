import type { AIProvider, AIProviderRequest, AIProviderResult } from "./app";

export interface OpenAIProviderEnv {
  OPENAI_API_KEY: string;
  OPENAI_BASE_URL?: string;
}

interface ResponsesAPIOutputText {
  type?: string;
  text?: string;
}

interface ResponsesAPIOutputItem {
  content?: ResponsesAPIOutputText[];
}

interface ResponsesAPIUsage {
  input_tokens?: number;
  output_tokens?: number;
}

interface ResponsesAPIResponse {
  output_text?: string;
  output?: ResponsesAPIOutputItem[];
  model?: string;
  usage?: ResponsesAPIUsage;
}

export class OpenAIResponsesProvider implements AIProvider {
  constructor(private readonly env: OpenAIProviderEnv) {}

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

  private responsesURL(): string {
    const baseURL = this.env.OPENAI_BASE_URL || "https://api.openai.com";
    const normalized = baseURL.replace(/\/+$/, "");
    return normalized.endsWith("/v1") ? `${normalized}/responses` : `${normalized}/v1/responses`;
  }
}

function normalizeImageURL(imageBase64: string): string {
  if (imageBase64.startsWith("data:")) {
    return imageBase64;
  }
  return `data:image/png;base64,${imageBase64}`;
}

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
