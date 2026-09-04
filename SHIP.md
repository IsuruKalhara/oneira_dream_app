# Dreamlore — Ship checklist

What's built vs. what only you can do. Work top-to-bottom.

```
Bitfuzed/
  dreamlore/        backend — KB, /explain RAG, metering, Node dev server, Cloudflare Worker
  dreamlore_app/    Flutter app — record → transcribe → explain → journal / insights / paywall
  docs/          PRIVACY.md · TERMS.md · STORE-LISTING.md  (drafts to review)
```

## ✅ Done (code, verified where possible)
- Public-domain knowledge base (Freud ×2, Miller's dictionary) + ingestion + `npm run add`.
- RAG `/explain` (grounded, quoted, structured) — Node dev server runs; end-to-end tested on stub providers.
- Usage metering + daily/monthly quotas + tier gating (demonstrated with 429s).
- Flutter app: full core loop + journal + insights + onboarding + paywall + settings + crisis-safety. `flutter analyze` clean, unit test passing, native mic/speech permissions set.
- Cloudflare Worker port + wrangler + push-to-Vectorize script (validated as ESM; needs `wrangler dev` to fully verify).
- Draft privacy policy, terms, store-listing/positioning, crisis-safety handling.

## ⛔ Only you can do these

### 1. Turn on the real AI (minutes)
- [ ] Get an Anthropic API key; choose an embedding provider (Voyage or OpenAI).
- [ ] `cd dreamlore && EMBEDDINGS_PROVIDER=openai OPENAI_API_KEY=… npm run ingest` (semantic KB — fixes snake→"Reptile").
- [ ] `LLM_PROVIDER=claude ANTHROPIC_API_KEY=… npm run serve` and eyeball a few real interpretations.

### 2. Deploy the backend (Cloudflare account)
- [ ] Create KV (`RATE_LIMIT`) + Vectorize index (`dreamlore-kb`, dims matching your model).
- [ ] `npm run push` → `wrangler vectorize insert …`
- [ ] `wrangler secret put` ANTHROPIC_API_KEY, OPENAI/VOYAGE key, (optional) REVENUECAT_API_KEY.
- [ ] `wrangler dev` to verify, then `wrangler deploy`. See `dreamlore/worker/README.md`.
- [ ] **Set an Anthropic Console spend limit + billing alert.** (Runaway-bill backstop.)

### 3. Subscriptions (Apple + Google + RevenueCat accounts)
- [ ] Create auto-renewing subscription products ($1–2/mo) in App Store Connect + Google Play.
- [ ] Configure RevenueCat; entitlement id **`paid`** (matches app + worker).
- [ ] Set `--dart-define=REVENUECAT_KEY=…` and point the app at the deployed worker via `DREAMLORE_API_BASE`.
- [ ] Test purchase → confirm the worker returns tier `paid` and quotas rise.

### 4. Legal & trust (lawyer)
- [ ] Review `docs/PRIVACY.md` + `docs/TERMS.md`; fill placeholders; host them.
- [ ] Set `Config.privacyUrl` / `Config.termsUrl` in `dreamlore_app/lib/core/config.dart`.

### 5. Store submission
- [ ] App icon + screenshots (list in `docs/STORE-LISTING.md`).
- [ ] Listing copy, privacy labels, age rating, and review notes per `docs/STORE-LISTING.md`
      (keep it "reflection, not medical").
- [ ] TestFlight / Play internal testing on real devices, then submit.

## Recommended settings for margin
- Subscription tier on **`claude-sonnet-5`** (≈½ the per-call cost of Opus).
- Keep transcription **on-device** (STT cost = $0).
- Quotas: free 1/day·5/mo, paid 3/day·50/mo (tune in `worker/src/index.js` `LIMITS`).

## Run locally right now
```bash
# backend
cd dreamlore && npm run download && npm run ingest && npm run serve
# app (Android emulator: use 10.0.2.2; iOS sim: localhost)
cd dreamlore_app && flutter run --dart-define=DREAMLORE_API_BASE=http://localhost:8787
```
