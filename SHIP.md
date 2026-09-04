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
- Flutter app: sign in → onboarding → paywall → journal. Full core loop + insights
  + settings + crisis-safety. `flutter analyze` clean, unit tests passing, debug APK
  builds, native mic/speech permissions set.
- Subscriptions: **direct Google Play Billing** (Google's own `in_app_purchase`
  plugin, no third-party billing service). Monthly + yearly products, yearly
  carrying a 3-day free trial; plan switching handled as a Play replacement.
- Server-side purchase verification: `/billing/verify` and `/billing/state` on the
  Worker check purchase tokens against the Play Developer API and cache the answer
  with its paid-through date, so a cancellation or refund actually ends the tier.
  Unit-tested (`npm test`).
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
- [ ] `wrangler secret put` ANTHROPIC_API_KEY, OPENAI/VOYAGE key, PLAY_SERVICE_ACCOUNT_JSON (§3).
- [ ] `wrangler dev` to verify, then `wrangler deploy`. See `dreamlore/worker/README.md`.
- [ ] **Set an Anthropic Console spend limit + billing alert.** (Runaway-bill backstop.)

### 3. Subscriptions — Google Play (Play Console + a service account)

The app talks to Play directly; the Worker checks every purchase against Google
before granting anything. Nothing here needs a third-party billing service.

**In Play Console → Monetise → Subscriptions**, create two subscriptions whose
product ids match `dreamlore_app/lib/core/config.dart`:

| Product id | Base plan | Offer |
|---|---|---|
| `dreamlore_plus_monthly` | monthly, auto-renewing | none |
| `dreamlore_plus_yearly` | yearly, auto-renewing | **Free trial, 3 days**, new customers only |

- [ ] Create both subscriptions, activate the base plans, and set prices.
- [ ] Add the **3-day free trial offer** to the yearly base plan. The paywall's
      "3-day free trial" copy comes from `Config.trialDays` — if you choose a
      different length, change it there too, or the app promises something Play
      will not honour.
- [ ] Upload a build to **Internal Testing** and add your account as a licence
      tester. Play only returns real products to an app installed *via Play* —
      a sideloaded debug build always shows "Plans unavailable".

**Service account, so the Worker can verify purchases:**
- [ ] Google Cloud console → the project linked to Play → create a service
      account → create a JSON key.
- [ ] Play Console → Users and permissions → invite that service account, grant
      **View financial data** and **Manage orders and subscriptions**.
- [ ] `cd dreamlore/worker && npx wrangler secret put PLAY_SERVICE_ACCOUNT_JSON`
      (paste the whole key JSON). Confirm `ANDROID_PACKAGE_NAME` and the two
      product ids in `wrangler.toml`.
- [ ] Point the app at the deployed Worker: `--dart-define=DREAMLORE_API_BASE=…`
- [ ] Test a purchase end-to-end: buy → `/usage` returns tier `paid` and the
      quotas rise → cancel in Play → the tier lapses at the paid-through date.

Until the service account exists, `/billing/verify` grants nothing and every user
stays `free`. The app honours an unverifiable purchase locally for 24 hours so a
paying user is never stranded, then re-checks.

### 3b. Sign-in — Firebase Auth + Google (mostly done)

`flutterfire configure` has already been run against Firebase project
**`dreamlore-app-51321`**, so `firebase_options.dart`, `google-services.json` and
the Gradle plugins are in place. One thing is missing:

- [ ] **Register your SHA-1/SHA-256 signing fingerprints** in Firebase console →
      Project settings → your Android app. The current `google-services.json` has
      an empty `oauth_client` array, which means Google Sign-In will return no ID
      token and sign-in will fail. Add the debug *and* upload/release
      fingerprints, then re-download `google-services.json`.
- [ ] Copy the **Web client id** (type 3) that appears afterwards and pass it as
      `--dart-define=GOOGLE_WEB_CLIENT_ID=…`, or set the default in
      `lib/core/config.dart`.
- [ ] Enable **Google** as a sign-in provider in Firebase console → Authentication.
- [ ] The Crashlytics Gradle plugin was added by `flutterfire configure`, but
      `firebase_crashlytics` is not a dependency. Either add the package or drop
      the plugin line from `android/app/build.gradle.kts`.

Debug builds show a "Skip for now" escape on the sign-in screen while Firebase is
unconfigured; it is compiled out of release builds.

### 4. Legal & trust (lawyer)
- [ ] Review `docs/PRIVACY.md` + `docs/TERMS.md`; fill placeholders; host them.
- [ ] Set `Config.privacyUrl` / `Config.termsUrl` in `dreamlore_app/lib/core/config.dart`.

### 5. Store submission
- [ ] App icon + screenshots (list in `docs/STORE-LISTING.md`).
- [ ] Listing copy, privacy labels, age rating, and review notes per `docs/STORE-LISTING.md`
      (keep it "reflection, not medical").
- [ ] TestFlight / Play internal testing on real devices, then submit.
- [ ] Play Data safety form: declare the Google account (email) collected at
      sign-in. Dreams and audio never leave the device — say so.

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
