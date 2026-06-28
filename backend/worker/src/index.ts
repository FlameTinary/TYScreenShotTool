/**
 * Cloudflare Worker 入口文件
 * 组装依赖并导出 Worker 处理器
 */

import { createApp } from "./app";
import { OpenAIResponsesProvider, type OpenAIProviderEnv } from "./openAIProvider";
import { SupabaseRepository, type SupabaseEnv } from "./supabaseRepository";

/**
 * Worker 环境变量类型，组合基础 Env、Supabase 配置和 OpenAI 配置
 */
type WorkerEnv = Env & SupabaseEnv & OpenAIProviderEnv;

/**
 * Cloudflare Worker 处理器对象
 * 使用 satisfies 关键字确保类型安全
 */
const worker = {
  /**
   * 处理所有传入的 HTTP 请求
   * @param request 传入的 HTTP 请求对象
   * @param env 运行时环境变量
   * @returns HTTP 响应对象
   */
  async fetch(request, env) {
    const app = createApp(new SupabaseRepository(env), new OpenAIResponsesProvider(env));
    return app.fetch(request, env);
  }
} satisfies ExportedHandler<WorkerEnv>;

/**
 * 导出 Worker 处理器供 Cloudflare 使用
 */
export default worker;
