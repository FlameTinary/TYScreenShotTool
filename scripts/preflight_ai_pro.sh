#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_FILE="$ROOT_DIR/TYScreenShotTool.xcodeproj/project.pbxproj"
RELEASE_SCHEME_FILE="$ROOT_DIR/TYScreenShotTool.xcodeproj/xcshareddata/xcschemes/TYScreenShotTool_Release.xcscheme"
ENTITLEMENTS_FILE="$ROOT_DIR/TYScreenShotTool/TYScreenShotTool.entitlements"
STOREKIT_FILE="$ROOT_DIR/TYScreenShotTool/TShot.storekit"
WRANGLER_FILE="$ROOT_DIR/backend/worker/wrangler.jsonc"
PACKAGE_FILE="$ROOT_DIR/backend/worker/package.json"
WORKER_TYPES_FILE="$ROOT_DIR/backend/worker/worker-configuration.d.ts"
LOCAL_STOREKIT_MIGRATION_FILE="$ROOT_DIR/backend/supabase/migrations/202606300001_allow_local_storekit_subscription_environment.sql"

fail() {
  print -u2 "❌ $1"
  exit 1
}

pass() {
  print "✅ $1"
}

require_file() {
  [[ -f "$1" ]] || fail "Missing required file: $1"
}

require_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  rg -q "$pattern" "$file" || fail "$message"
}

require_not_contains() {
  local pattern="$1"
  shift
  if rg -q "$pattern" "$@"; then
    fail "Found stale AI Pro wording or unsafe production text: $pattern"
  fi
}

require_file "$PROJECT_FILE"
require_file "$RELEASE_SCHEME_FILE"
require_file "$ENTITLEMENTS_FILE"
require_file "$STOREKIT_FILE"
require_file "$WRANGLER_FILE"
require_file "$PACKAGE_FILE"
require_file "$WORKER_TYPES_FILE"

require_contains "$ENTITLEMENTS_FILE" "com.apple.developer.applesignin" "Sign in with Apple entitlement is missing."
require_contains "$ENTITLEMENTS_FILE" "com.apple.security.app-sandbox" "App Sandbox entitlement is missing."
require_contains "$ROOT_DIR/TYScreenShotTool/Shared/AIProSubscriptionModels.swift" 'static let monthly = "tshot.pro.monthly"' "AI Pro monthly product ID must match App Store Connect."
require_contains "$STOREKIT_FILE" '"productID" : "tshot.pro.monthly"' "Local StoreKit product ID must match App Store Connect and app code."
require_contains "$ROOT_DIR/backend/worker/src/app.ts" 'AI_PRO_MONTHLY_PRODUCT_ID = "tshot.pro.monthly"' "Backend subscription verification must only grant AI Pro for the configured monthly product."
if awk '
  /nonisolated func presentationAnchor/ { in_anchor = 1; depth = 0 }
  in_anchor {
    if ($0 ~ /NSApplication\.shared/) found = 1
    depth += gsub(/\{/, "{")
    depth -= gsub(/\}/, "}")
    if (depth == 0 && $0 ~ /\}/) in_anchor = 0
  }
  END { exit found ? 0 : 1 }
' "$ROOT_DIR/TYScreenShotTool/Services/AIProAuthService.swift"; then
  fail "Sign in with Apple presentationAnchor must not read NSApplication.shared from a nonisolated context."
fi
pass "App entitlements include Apple Sign In and sandbox."

release_block="$(
  awk '
    index($0, "08E7B3B12FD276F300BC7687 /* Release */") { in_release = 1 }
    in_release { print }
    in_release && index($0, "name = Release;") { exit }
  ' "$PROJECT_FILE"
)"
[[ "$release_block" == *"ENABLE_OUTGOING_NETWORK_CONNECTIONS = YES;"* ]] || fail "Release build must allow outgoing network connections."
[[ "$release_block" != *'"CODE_SIGN_IDENTITY[sdk=macosx*]" = "Apple Distribution";'* ]] || fail "Release automatic signing must not manually specify Apple Distribution, otherwise archive fails."
pass "Release build settings allow backend access and avoid archive signing conflicts."

require_contains "$WRANGLER_FILE" '"AI_PROVIDER": "openai"' "Worker default AI provider must support screenshot image input."
require_contains "$WRANGLER_FILE" '"AI_MODEL": "gpt-4.1-mini"' "Worker default AI model should be an image-capable model."
require_contains "$WRANGLER_FILE" '"OPENAI_BASE_URL": "https://api.openai.com"' "Worker default base URL should match OpenAI provider."
require_contains "$WRANGLER_FILE" '"APPLE_BUNDLE_ID": "com.sheldon.TShot"' "Worker Apple bundle ID must match the app bundle ID."
require_contains "$WORKER_TYPES_FILE" 'APPLE_BUNDLE_ID: "com.sheldon.TShot"' "Generated Worker types must be refreshed after Apple bundle ID changes."
require_contains "$WRANGLER_FILE" '"nodejs_compat"' "Worker must enable nodejs_compat for Apple signed-data verification."
require_file "$LOCAL_STOREKIT_MIGRATION_FILE"
require_contains "$LOCAL_STOREKIT_MIGRATION_FILE" "'Xcode'" "Supabase subscriptions environment constraint must allow local Xcode StoreKit transactions for development restore tests."
require_contains "$LOCAL_STOREKIT_MIGRATION_FILE" "'LocalTesting'" "Supabase subscriptions environment constraint must allow LocalTesting StoreKit transactions for development restore tests."
if rg -q "StoreKitConfigurationFileReference" "$RELEASE_SCHEME_FILE"; then
  fail "Release scheme must not use a local StoreKit configuration; Sandbox/TestFlight verification needs App Store StoreKit."
fi
default_worker_config="$(
  awk '
    index($0, "\"env\"") { exit }
    { print }
  ' "$WRANGLER_FILE"
)"
if [[ "$default_worker_config" =~ \"ALLOW_LOCAL_STOREKIT_TRANSACTIONS\"[[:space:]]*:[[:space:]]*\"(true|1)\" ]]; then
  fail "Worker default config must not enable local Xcode StoreKit transaction verification."
fi
require_contains "$WORKER_TYPES_FILE" 'interface DevEnv' "Generated Worker types must include the dev environment after wrangler env changes."
require_contains "$WORKER_TYPES_FILE" 'SUPABASE_URL: "http://127.0.0.1:54321"' "Generated Worker dev types must point to local Supabase."
pass "Worker default config is production-safe, and dev config points to local Supabase."

require_contains "$PACKAGE_FILE" '"@apple/app-store-server-library"' "Apple App Store Server library dependency is missing."
if rg -q '^import \{ Environment, SignedDataVerifier \} from "@apple/app-store-server-library";' "$ROOT_DIR/backend/worker/src/appleAuth.ts"; then
  fail "Apple App Store Server library must be loaded dynamically inside request handling; static import prevents Worker startup."
fi
require_contains "$ROOT_DIR/backend/README.md" "APPLE_ROOT_CERTIFICATES_PEM" "Backend README must document Apple Root CA secret."
require_contains "$ROOT_DIR/backend/README.md" "App Store Server Notifications V2 URL" "Backend README must document notification URL setup."
pass "Backend Apple signed-data verification dependency and deployment notes are present."

if awk '
  /AIProAuthService\.shared\.signIn\(\)/ { in_sign_in = 1; depth = 0 }
  in_sign_in {
    if ($0 ~ /restorePurchases\(\)/) found = 1
    depth += gsub(/\{/, "{")
    depth -= gsub(/\}/, "}")
    if (depth == 0 && $0 ~ /\}/) in_sign_in = 0
  }
  END { exit found ? 0 : 1 }
' "$ROOT_DIR/TYScreenShotTool/App/SettingsViewController.swift" \
  "$ROOT_DIR/TYScreenShotTool/Services/AIProPromptPresenter.swift"; then
  fail "Apple sign-in completion must refresh subscription status, not auto-trigger StoreKit restore purchases."
fi
pass "Apple sign-in completion does not auto-trigger StoreKit restore purchases."

if awk '
  /static func showSubscriptionOnboarding/ { in_func = 1; depth = 0 }
  in_func {
    if ($0 ~ /showLoginIfNeeded\(from: view\)/) saw_login = 1
    if (saw_login && $0 ~ /return/) found = 1
    depth += gsub(/\{/, "{")
    depth -= gsub(/\}/, "}")
    if (depth == 0 && $0 ~ /\}/) in_func = 0
  }
  END { exit found ? 0 : 1 }
' "$ROOT_DIR/TYScreenShotTool/Services/AIProPromptPresenter.swift"; then
  fail "Subscription onboarding must continue to subscription status after successful login, not return early."
fi
pass "Subscription onboarding continues after successful login."

if rg -q "fallbackID: String = AIProSubscriptionProductID\\.monthly" "$ROOT_DIR/TYScreenShotTool/Services/AIProSubscriptionService.swift"; then
  fail "AI Pro subscription helpers must not reference MainActor-isolated product constants from default argument expressions."
fi
pass "AI Pro subscription helpers avoid actor-isolated default argument expressions."

if rg -n "print\\(.*(identityToken|authorizationCode|fullName|givenName|familyName|email)" "$ROOT_DIR/TYScreenShotTool/Services/AIProAuthService.swift" >/dev/null; then
  fail "Apple login must not print identity tokens, authorization codes, names, or email addresses."
fi
pass "Apple login avoids printing sensitive credential fields."

require_not_contains \
  "不会调用 AI 后端|正式接入仍未完成|尚未正式交付的 AI|本阶段不真实调用 AI 后端|AI 后端、登录和额度校验仍留给后续 Feature|Release 模式下永远返回 false" \
  "$ROOT_DIR/README.md" \
  "$ROOT_DIR/PROJECT_CONTEXT.md" \
  "$ROOT_DIR/backend/README.md" \
  "$ROOT_DIR/docs/privacy-policy.md" \
  "$ROOT_DIR/docs/AppStore" \
  "$ROOT_DIR/TYScreenShotTool"
require_not_contains \
  "such as DeepSeek" \
  "$ROOT_DIR/docs/privacy-policy.md"
pass "No stale AI Pro launch-blocking wording found."

print "AI Pro preflight passed."
