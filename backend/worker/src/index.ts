import { createApp } from "./app";
import { SupabaseRepository, type SupabaseEnv } from "./supabaseRepository";

type WorkerEnv = Env & SupabaseEnv;

const worker = {
  async fetch(request, env) {
    const app = createApp(new SupabaseRepository(env));
    return app.fetch(request, env);
  }
} satisfies ExportedHandler<WorkerEnv>;

export default worker;
