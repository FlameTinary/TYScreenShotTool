# TShot AI Backend

This directory contains the Sprint 53.5-53.6 backend MVP for the overseas AI Pro path.

## Scope

- Cloudflare Worker API gateway for AI Pro backend checks.
- Supabase schema for users, sessions, subscriptions, usage, quotas, and abuse events.
- OpenAI Responses API forwarding for subscribed, quota-available overseas users.
- Usage recording and monthly quota increment after successful AI calls.
- No real Sign in with Apple verification yet.
- No real App Store Server API verification yet.

The Worker only calls the AI provider after auth, region, subscription, quota, request shape, idempotency, and image size checks pass. Failed AI provider calls are recorded as non-billable usage and do not increment monthly quota.

## Worker

Path: `backend/worker`

Useful commands:

```bash
npm install
npm test
npm run typecheck
npx wrangler types
```

Runtime configuration:

- `ALLOWED_STOREFRONTS`: comma-separated storefront allowlist. `CHN`, unknown, and missing storefronts are always blocked.
- `MONTHLY_REQUEST_LIMIT`: default monthly AI request limit.
- `DAILY_REQUEST_LIMIT`: default daily AI request limit.
- `MAX_IMAGE_BYTES`: maximum accepted image payload size.
- `AI_MODEL`: Responses API model name.
- `AI_MAX_OUTPUT_TOKENS`: max output tokens per request.

Secrets must be set with Wrangler, not committed:

```bash
npx wrangler secret put SUPABASE_URL
npx wrangler secret put SUPABASE_SERVICE_ROLE_KEY
npx wrangler secret put OPENAI_API_KEY
```

Optional secret:

```bash
npx wrangler secret put OPENAI_BASE_URL
```

## API MVP

- `GET /health`
- `POST /v1/auth/apple`: placeholder, returns `501 auth_not_implemented`
- `POST /v1/subscriptions/verify`: placeholder, returns `501 subscription_verify_not_implemented`
- `GET /v1/subscriptions/status`: requires Bearer token, region allowed
- `GET /v1/usage/current`: requires Bearer token, region allowed
- `POST /v1/ai/analyze-screenshot`: requires Bearer token, region allowed, active subscription, available quota, unique `request_id`, valid image payload; returns AI analysis and records usage
- `POST /v1/apple/notifications`: placeholder, returns `202`

## Supabase

Migration path: `backend/supabase/migrations/202606280001_ai_backend_mvp.sql`

The schema enables RLS on all base tables. The Worker uses the Supabase service role key from Cloudflare secrets, so end-user clients must not receive direct table access for this MVP.

Successful AI calls insert `usage_records` and call `increment_monthly_quota` to update the current month's quota row. Duplicate `request_id` values return `409 duplicate_request` before invoking AI.
