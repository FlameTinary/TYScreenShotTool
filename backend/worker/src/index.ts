import { createApp } from "./app";
import { OpenAIResponsesProvider, type OpenAIProviderEnv } from "./openAIProvider";
import { SupabaseRepository, type SupabaseEnv } from "./supabaseRepository";

type WorkerEnv = Env & SupabaseEnv & OpenAIProviderEnv;

const worker = {
  async fetch(request, env) {
    const app = createApp(new SupabaseRepository(env), new OpenAIResponsesProvider(env));
    return app.fetch(request, env);
  }
} satisfies ExportedHandler<WorkerEnv>;

export default worker;
