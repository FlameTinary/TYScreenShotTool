-- Allow local StoreKit transactions to be persisted only when the backend
-- explicitly verifies Xcode / LocalTesting signed transactions in development.
alter table public.subscriptions
  drop constraint if exists subscriptions_environment_check;

alter table public.subscriptions
  add constraint subscriptions_environment_check check (
    environment in ('Sandbox', 'Production', 'Xcode', 'LocalTesting')
  );
