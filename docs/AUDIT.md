# Dreamlore — August 2026 deep audit: findings & fixes
### A Bitfuzed product

16-agent audit (4 code auditors + adversarial verification + 3 market researchers).
40 findings; 9 sampled critical/high findings were adversarially re-verified against
the code — **zero refuted**. This file records what was found, what was fixed in the
same session, and what remains open with a reason.

Verification after fixes: `flutter analyze` clean · **22/22 tests pass** ·
backend smoke green (413 cap, quota 429, nightmare-regex fix, x-tier gating).

---

## Fixed ✅ — app

| Severity | Finding | Fix |
|---|---|---|
| HIGH | **Save/New-dream pills rendered under the floating nav bar** — taps hit the nav instead of Save | Bottom inset added; done-state now a single auto-saved "Done" pill |
| HIGH | Newest **journal entries permanently hidden** under the nav capsule | `MediaQuery.paddingOf(context).bottom` added (same as Insights) |
| HIGH | **Recorder stuck on "Listening…"** after the plugin auto-stops (silence/2-min cap/error); further speech silently lost | Real `onStatus`/`onError` plumbing → controller settles to ready/idle; `pauseFor` raised 6s→12s |
| HIGH | **Re-tapping the mic wiped the whole transcript** (dictated + hand edits) | Append mode: new recognition concatenates onto existing text |
| HIGH | **Privacy/Terms links non-functional everywhere** (URL in a dialog) — 3.1.2 rejection risk | `url_launcher` wired in onboarding, Settings, paywall (+ Android `<queries>`); dialog kept only as no-browser fallback |
| HIGH | **"Morning reminder" toggle did nothing** | `NotificationService`: permission request, daily 07:00 `zonedSchedule`, cancel on disable, toggle reverts on denial; manifest receivers + `POST_NOTIFICATIONS` |
| MED | Interpret CTA / Settings footer / EmptyState actions hidden under nav on short screens & large text | Bottom insets at all remaining sites |
| MED | **Mic halo dead on iOS** — negative-dB levels clamped to 0 | Per-platform normalization (`(raw+50)/50` for dB) |
| MED | **Editing text while listening left the mic running**, results discarded, next tap double-started the plugin | `editTranscript` stops STT first |
| MED | **"Resets tomorrow" wrong across month boundaries** (monthly reset shown as "tomorrow") | Calendar-day diff; far resets render "on 1 September" |
| MED | **"Try again" dead after mic errors** (retried interpretation with an empty transcript) | Error source split: mic errors → "Open device settings" + "I'll type instead" |
| MED | **Starfield jumped every 90 s** (non-integer drift wrap) | Integer wrap coefficient, 750 s cycle — seamless |
| MED | **Full-rate starfield repaint under a σ18 BackdropFilter** — battery/jank | Repaints throttled to ~12 fps; animation pauses when app backgrounded |
| MED | **Stagger blanked the outgoing onboarding page** for the whole 520 ms transition | No reset on deactivate; entrance replays on activate |
| MED | `requestMic` could stick `busy=true` forever, hard-locking the last onboarding step | try/finally; `setMicPrompted` inside try |
| LOW | Hidden tabs kept animating (mic-orb ticker on other tabs) | `TickerMode(enabled: i == index)` around IndexedStack children |
| LOW | **Double-tap Save wrote duplicate journal entries** | Auto-save on interpret success; `save()` idempotent (reuses `savedId`) |
| LOW | **EntryDetailScreen was stock Material** — jarring break + no bottom inset | Restyled in the night idiom, custom header, insets |
| — | `micPrompted` was write-only; Record tab had no settings deep-link after iOS denial | Covered by the error-split fix above |

## Fixed ✅ — backend

| Severity | Finding | Fix |
|---|---|---|
| HIGH | **Crisis regex fired on ordinary nightmares** — "a man was trying to kill me" → suicide-hotline card instead of a reading (verified by executing the regex) | First-person anchoring (`kill … myself`, not `… me`) + broader ideation phrasings; app and Worker lists synced; regression tests added |
| HIGH | **No size cap on the dream field** — anyone could inflate the Claude bill | 400 above 4,000 chars, before safety/quota/spend |
| HIGH | **Quota check-then-increment race** — parallel bursts blew through caps | Increment-then-check; refund on over-limit month path. (Durable Object = real fix, deferred) |
| HIGH | **RevenueCat called uncached on every request, no timeout** — latency + outages silently downgraded paying users | KV tier cache (10 min TTL) + 3 s `AbortSignal` timeout; failures not cached |
| HIGH | Self-issued UUID identity + `CORS *` → unlimited quota farming | CORS removed entirely (native app), token length sanity check, **per-IP daily backstop** (30/day). Attestation deferred — see below |
| MED | **Quota consumed before the pipeline ran** — any 502 burned the free user's only daily reading | Refund (decrement) on pipeline failure |
| MED | `max_tokens: 4000` shared with adaptive thinking → truncated JSON → 502 + lost quota | Raised to 12,000; `stop_reason` checked; `JSON.parse` guarded; failures refund |
| MED | **UTC quota windows** — "day" flipped mid-afternoon for the Americas | `x-tz-offset` header from the app; day/month keys and `resetsAt` computed in the user's local day |
| LOW | Raw upstream errors + `_meta.usage` leaked provider/stack details | Generic client message, real error to `console.error`; `_meta` trimmed to model only; `/health` → `{ok:true}` |
| LOW | Crisis backstop missed common phrasings ("end my life", "no point in living") | Added (both sides) |
| LOW | Dev server: >1 MB body reset the socket with no response | Proper 413 + settled promise |
| LOW | Dev server honored client `X-Tier: paid`; bound to all interfaces | Gated behind `NODE_ENV !== 'production'`; binds 127.0.0.1 (HOST to override) |

## Deferred — with reasons

| Item | Why deferred | Where documented |
|---|---|---|
| **Durable Object quota counters** (truly atomic) | Architecture change; inc-then-check closes the practical window for launch scale | docs/LAUNCH.md |
| **Device attestation** (App Attest / Play Integrity → signed tokens) | Needs store accounts + key infra; IP backstop + spend cap are the interim wall | docs/LAUNCH.md backstops |
| `wrangler.toml` KV id still `PASTE_KV_NAMESPACE_ID_HERE` | Requires your Cloudflare account (`wrangler kv namespace create RATE_LIMIT`) | docs/LAUNCH.md step 1 |
| Prompt cache no-op on `claude-opus-4-8` (prompt ≈750 tok < 1024 min) | Engages automatically on `claude-opus-5` (512 min); waste is small; comment added at call site | worker/src/index.js |
| "want to die" can still match dream *imagery* ("in the dream I was going to die") | Regex cannot resolve intent; erring toward safety is the right default; Claude handles nuance downstream | safety.dart comment |
| Journal search (store listing says "searchable") | Feature work; either ship search or cut the word pre-submission | Earlier report §6-B2 |
| Cross-dream context + association capture | Product features (the category's top requests), not bugs | §6-B3/B4, GROWTH.md |
| iOS build entirely unverified | Host Xcode lacks the iOS platform: `xcodebuild -downloadPlatform iOS` (needs your machine) | — |
| Repo path contains `1$` → `flutter test` breaks in-place | Tests run green from a `$`-free copy (`/tmp/dreamlore-test`); **recommend renaming the parent folder** | — |
