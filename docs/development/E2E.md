# Browser end-to-end tests

The Playwright suite is a deliberately small Chromium check of the critical MVP journey against the
real Next.js UI and a real **local** Supabase stack. It uses only synthetic `example.test` accounts;
the configuration refuses non-loopback Supabase URLs.

## Run locally

Node.js 20.9+, Docker and the repository dependencies are required. Install Chromium once, start from
the known demo state, and export the local CLI's browser-safe values:

```bash
npm ci
npx playwright install chromium
npm run supabase:start
npm run supabase:reset
npm run demo:local
eval "$(npx supabase status --output env)"
export NEXT_PUBLIC_SUPABASE_URL="$API_URL"
export NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY="$ANON_KEY"
npm run test:e2e
```

Never substitute a hosted project or a service-role key. The test command starts Next.js and expects
the demo reset/load procedure above to have completed. Tests intentionally run serially because the
listing, booking and return scenarios form one short workflow. Playwright retries are deliberately
disabled because retrying that workflow would reuse already-mutated external database state.

For interactive debugging use `npm run test:e2e:headed`. Failures retain a Playwright trace and a
screenshot under ignored `test-results/`; open a trace with `npx playwright show-trace <trace.zip>`.
