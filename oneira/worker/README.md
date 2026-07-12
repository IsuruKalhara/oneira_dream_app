# Oneira Worker — production `/explain` proxy

Same request/response contract as the local Node server (`src/server.mjs`), so the
Flutter app points at either unchanged. Retrieval uses **Cloudflare Vectorize**,
quotas use **KV**, tier uses **RevenueCat**, interpretation uses **Claude**.

> Not runtime-verified in this repo (it needs your Cloudflare account). Verify with
> `wrangler dev` before deploying.

## One-time setup

```bash
# 1. KV for quota counters
npx wrangler kv namespace create RATE_LIMIT     # paste the id into wrangler.toml

# 2. Vectorize index — dimensions MUST match your embedding model
npx wrangler vectorize create oneira-kb --dimensions=1536 --metric=cosine   # text-embedding-3-small
# (voyage-3.5-lite → --dimensions=1024)

# 3. Build the KB with a REAL (semantic) embedding provider, then push it
cd ..
EMBEDDINGS_PROVIDER=openai OPENAI_API_KEY=sk-... npm run ingest
npm run push                                    # writes data/vectorize.ndjson
npx wrangler vectorize insert oneira-kb --file=../data/vectorize.ndjson

# 4. Secrets
cd worker
npx wrangler secret put ANTHROPIC_API_KEY
npx wrangler secret put OPENAI_API_KEY          # or VOYAGE_API_KEY
npx wrangler secret put REVENUECAT_API_KEY      # optional
```

## Run & deploy

```bash
npx wrangler dev            # test: curl localhost:8787/health ; POST /explain
npx wrangler deploy
```

## Point the app at it

```bash
flutter run \
  --dart-define=ONEIRA_API_BASE=https://oneira-proxy.<your-subdomain>.workers.dev
```

## Backstops (do these before charging money)

- Set a **spend limit + billing alert** in the Anthropic Console.
- Tune quotas in `src/index.js` `LIMITS` (or move them to `[vars]`).
- `wrangler tail` to watch logs; consider Workers Analytics Engine for cost/usage.
