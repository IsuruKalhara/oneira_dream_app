# Dreamlore Worker — production `/explain` proxy

Same request/response contract as the local Node server (`src/server.mjs`), so the
Flutter app points at either unchanged.

| Concern | How it works |
|---|---|
| Retrieval | **In-bundle.** `src/kb.json` ships with the Worker; cosine runs in JS. No Vectorize, no embedding API, no subrequest. |
| Interpretation | **OpenAI `gpt-4o-mini`** by default (~$0.001/dream). Set `LLM_PROVIDER=claude` to switch. |
| Quotas | KV, per device token: free 1/day · 5/month, paid 3/day · 50/month. |
| Tier | Google Play Billing. `/billing/verify` checks a purchase token against the Play Developer API and caches the answer (with its paid-through date) in KV. Without `PLAY_SERVICE_ACCOUNT_JSON` everyone is `free`. |
| Safety | Expressed self-harm intent returns crisis resources **before** any model call — no cost, no quota. |
| Quote integrity | Every quote is checked verbatim against the retrieved passages; anything else is dropped. |

Infrastructure cost is **$0/month** — only the model calls are billed.

## Deploy

```bash
# 1. Build the knowledge base (once, and after any change to the corpus or chunker)
npm run download          # public-domain texts → data/raw/
npm run ingest            # chunk + index      → data/index.json
npm run build:kb          # bake for the Worker → worker/src/kb.json

# 2. KV namespace for quota counters (once)
npx wrangler kv namespace create RATE_LIMIT   # paste the id into wrangler.toml

# 3. Provider key
cd worker
npx wrangler secret put OPENAI_API_KEY

# 3b. Subscriptions: the Play service-account key, as one line of JSON.
#     Skip it and every user stays 'free' — nothing else breaks.
npx wrangler secret put PLAY_SERVICE_ACCOUNT_JSON < play-service-account.json

# 4. Ship
npx wrangler deploy
```

> **If `secret put` fails with "the latest version of your Worker isn't currently
> deployed"** — run `npx wrangler deploy` first, then retry. Cloudflare blocks
> secret edits while an undeployed version exists, so that saving a secret cannot
> silently promote it.

## Verify

```bash
B=https://dreamlore-proxy.<subdomain>.workers.dev

curl -s $B/health
# {"ok":true,"kb":"bundled","chunks":3475,"provider":"openai","model":"gpt-4o-mini"}

curl -s -X POST $B/explain -H 'content-type: application/json' \
  -H 'x-device-token: test-1' -d '{"dream":"My teeth were falling out."}'

# free tier is 1/day — a second call with the same token must return 429
```

## Point the app at it

```bash
flutter run --dart-define=DREAMLORE_API_BASE=https://dreamlore-proxy.<subdomain>.workers.dev
```

## Before charging money

- **Set a spend limit** in the OpenAI dashboard. This is the runaway-bill backstop.
- Tune `LIMITS` in `src/index.js`.
- `npx wrangler tail` to watch live requests.
- Rebuild `kb.json` and redeploy whenever the knowledge base changes — the Worker
  serves whatever was baked in at deploy time.
