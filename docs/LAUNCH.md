# Dreamlore — deploying the backend & making money
### A Bitfuzed product

Two parts: getting the proxy live on Cloudflare, and the business around it.
Everything here is costed against *this* repo — `TOP_K=6`, 1200-char chunks,
the frozen system prompt in `src/prompt.mjs` — not generic estimates.

---

# Part 1 · Deploying the backend

## What the app actually needs

The Flutter app only ever calls two endpoints, and it doesn't care what serves
them (`lib/core/config.dart` → `DREAMLORE_API_BASE`):

| Endpoint | Used by | Notes |
|---|---|---|
| `POST /explain` | the Interpret button | Returns the structured reading; `429` becomes the quota wall |
| `GET /usage` | the quota pill | Powers "N of M free readings left today" |

`dreamlore/src/server.mjs` (Node, local) and `dreamlore/worker/src/index.js`
(Cloudflare) implement the **same contract**. Local is for development; the
Worker is what ships.

## Step 0 — build the knowledge base (nothing works without this)

`dreamlore/data/` currently contains only `samples/`. **The books have never been
downloaded or embedded**, so retrieval has nothing to retrieve. Do this first,
and do it with a real embedding provider — the stub/hash embeddings can't do
semantics (snake → "Reptile" fails).

```bash
cd dreamlore
npm install
npm run download                                  # Gutenberg → data/raw
EMBEDDINGS_PROVIDER=openai OPENAI_API_KEY=sk-... npm run ingest
```

Sanity-check before spending anything on infrastructure:

```bash
LLM_PROVIDER=claude ANTHROPIC_API_KEY=sk-ant-... npm run serve
curl -s localhost:8787/explain -H 'content-type: application/json' \
  -H 'x-device-token: dev' \
  -d '{"dream":"I was swimming in a dark sea and lost my shoes"}' | head -40
```

You are looking for **quotes that actually match the dream**. If the passages
are irrelevant, the embeddings or the ingest are wrong, and no amount of
frontend work will save the product — quoting real books is the whole pitch.

## Step 1 — Cloudflare resources

```bash
cd dreamlore/worker
npx wrangler kv namespace create RATE_LIMIT
```

Paste the returned id into `wrangler.toml` → `[[kv_namespaces]] id`. It is
still the literal string `PASTE_KV_NAMESPACE_ID_HERE`.

```bash
npx wrangler vectorize create dreamlore-kb --dimensions=1536 --metric=cosine
```

> ⚠️ **Dimensions must match the model that built the KB.** `1536` for
> `text-embedding-3-small`, `1024` for `voyage-3.5-lite`. A mismatch doesn't
> error loudly — you get garbage neighbours and readings that quote the wrong
> book. Whatever you set in `[vars] EMBEDDINGS_PROVIDER` has to be the provider
> you ran `npm run ingest` with.

## Step 2 — push the KB

```bash
cd dreamlore
npm run push                       # → data/vectorize.ndjson
cd worker
npx wrangler vectorize insert dreamlore-kb --file=../data/vectorize.ndjson
```

## Step 3 — secrets

```bash
npx wrangler secret put ANTHROPIC_API_KEY
npx wrangler secret put OPENAI_API_KEY        # or VOYAGE_API_KEY
npx wrangler secret put REVENUECAT_API_KEY    # optional — see trap below
```

## Step 4 — verify, then deploy

```bash
npx wrangler dev
curl localhost:8787/health
# then deploy
npx wrangler deploy
```

Point the app at it:

```bash
flutter build apk --release \
  --dart-define=DREAMLORE_API_BASE=https://dreamlore-proxy.<subdomain>.workers.dev \
  --dart-define=REVENUECAT_KEY=<public sdk key>
```

## Traps specific to this codebase

| Trap | Consequence | Fix |
|---|---|---|
| **No `REVENUECAT_API_KEY`** → `resolveTier()` returns `'free'` for everyone | Paying customers get free-tier quotas. Refunds and 1-star reviews. | Set it before you sell anything |
| **`CLAUDE_MODEL` is one global value** | The paywall promises "deeper readings" but every tier gets the same model — an unsubstantiated paid claim | Tier it (below) or change the copy |
| **Prompt caching is probably a no-op** | `cache_control` sits on a ~750-token system prompt; the minimum cacheable prefix is **1024 tokens on `claude-opus-4-8`** | It caches on `claude-opus-5` (512 min). Verify with `usage.cache_read_input_tokens` — don't assume |
| **Only defence is an anonymous device token** | Anyone can mint UUIDs and farm free readings. Your bill, not theirs | Rate-limit by IP in the Worker as well as by token; keep the Anthropic spend cap on |
| **Quotas live in code** (`LIMITS` in `worker/src/index.js`) | Changing them needs a redeploy | Move to `[vars]` if you plan to tune often |

## Cost per reading (measured against this repo)

Input ≈ 750 (system) + 6 × ~300 (chunks) + ~300 (dream) ≈ **3,000 tokens**.
Output ≈ 600 (JSON) + adaptive thinking at `effort: medium` ≈ **1,200 tokens**.

| Model | $/MTok in / out | Cost per reading |
|---|---|---|
| `claude-opus-4-8` *(current default)* | $5 / $25 | **≈ $0.045** |
| `claude-opus-5` | $5 / $25 | ≈ $0.045 |
| `claude-sonnet-5` | $3 / $15 | **≈ $0.027** |
| `claude-haiku-4-5` | $1 / $5 | **≈ $0.009** |

Embeddings are rounding error (~$0.000004/query). Cloudflare Workers/KV are
free at this scale; Vectorize is the only line worth watching.

**Recommended split** — it makes the paywall's "deeper readings" claim *true*
instead of decorative:

```js
const model = tier === 'paid'
  ? (env.CLAUDE_MODEL_PAID || 'claude-opus-5')
  : (env.CLAUDE_MODEL_FREE || 'claude-haiku-4-5');
```

## Before you charge anyone

- [ ] **Anthropic Console → spend limit + billing alert.** Non-negotiable. This is a public endpoint holding your key.
- [ ] `wrangler tail` for a day and watch for token farming.
- [ ] Confirm a real sandbox purchase flips `/usage` to `tier: "paid"`.
- [ ] Host `PRIVACY.md` / `TERMS.md` and set `Config.privacyUrl` / `termsUrl`.

---

# Part 2 · Making money

## Unit economics

Store commission is **15%** on the first $1M/year (Apple Small Business Program —
you must enrol; Google applies it automatically).

| | Monthly $5.99 | Annual $29.99 |
|---|---|---|
| Net after 15% | $5.09 | $25.49 |
| COGS at 25 readings/mo (Sonnet 5) | $0.68 | $8.16/yr |
| **Contribution** | **$4.41/mo** | **$17.33/yr** |

**Free users cost real money.** At 1/day with no monthly cap, a daily free user
on Opus is **$1.35/month** with zero revenue. That is why the current 5/month
cap exists — it holds free cost to ~$0.23/user/month.

This is the number that decides the free tier. My §6 recommendation was to drop
the monthly cap so the app matches the category's "1 free reading a day, forever."
That is only affordable if free routes to Haiku:

| Free tier | Cost per active free user/mo |
|---|---|
| 1/day + 5/mo cap, Opus *(today)* | $0.23 |
| 1/day, no cap, Opus | $1.35 ❌ |
| **1/day, no cap, Haiku 4.5** | **$0.27** ✅ |

So: **remove the monthly cap and move free to Haiku in the same change.** They
are one decision, not two.

## Pricing

Category benchmarks from the competitive research:

| App | Price |
|---|---|
| Dream Interpreter AI | $4.99/mo |
| **Dreamz Journal** *(closest competitor)* | **$5.99/mo** |
| DreamStream | $8–12/mo |

`SHIP.md` proposes **$1–2/month**. That is a mistake in both directions: it
leaves ~70% of revenue on the table *and* it signals low quality in a category
where users equate price with depth. Nothing about $1.99 is more attractive
than $5.99 to someone who wants their recurring dream explained.

**Recommendation: $5.99/mo, $29.99/yr (58% saving), 7-day free trial, annual
pre-selected.** The annual plan is not optional — see below.

## Why paid ads will not work (and what that forces)

Rough funnel math at $5.99/mo:

- LTV ≈ $5.09 × ~4 months average retention ≈ **$20**, less COGS ≈ **$17**
- Install → subscriber ≈ 3–5% for a well-executed onboarding
- A $6 CPA therefore needs a CPI of **≤ $0.25**

You cannot buy installs at $0.25 in this category. **So Dreamlore is an organic
growth product, not a paid one.** Everything below follows from that. The annual
plan matters because it roughly doubles LTV and takes cash up front, which is
the only thing that ever makes paid viable later.

## Positioning

One line, and it is already true in the code:

> **Most dream apps invent an answer. Dreamlore shows you the page.**

This is the single most valuable asset you have, because the **#1 complaint in
the entire category** is "the same vague response no matter what I dreamed."
Your `prompt.mjs` mandates verbatim quotes with attribution *and* instructs the
model to admit when the books don't fit. Nobody else can say that honestly.

Every piece of marketing should show the quote card.

## Channels, ranked by expected return

### 1. The SEO asset you already own ⭐ *highest leverage, most overlooked*

You have ingested **Miller's *Ten Thousand Dreams Interpreted*** — a
public-domain dictionary of ~10,000 dream symbols. "What does it mean to dream
about X" is one of the highest-volume evergreen search categories on the web.

Publish it as a free web dictionary: one page per symbol, Miller's actual text,
correctly attributed, with a "get a reading on *your* version of this dream"
CTA to the app. That is thousands of long-tail pages from an asset you already
have, legally free to publish, that no competitor can copy without doing the
same work.

This is the highest-ROI thing on this list and it costs hosting.

### 2. ASO

Your entire discovery surface. Title/subtitle field:
`Dreamlore — Dream Journal` / `Dream diary, grounded in books`.
Keyword targets: `dream journal`, `dream meaning`, `dream interpretation`,
`dream diary`, `lucid dream`, `dream symbols`.

Screenshot order matters more than the copy — lead with **the reading with a
visible quote card**, not the record screen. That image *is* the differentiator.

### 3. Short-form video (TikTok / Reels)

Where the 22–38 cohort actually is, and "dream interpretation" is already a huge
organic content category. The repeatable format writes itself:

> Read a viewer's dream aloud → show the app → **zoom on the quote card** →
> "that's Freud, 1899, page whatever. Not made up."

The reveal *is* the product demo. Solicit dreams in comments for endless
material.

### 4. Reddit

r/Dreams, r/DreamInterpretation, r/Jung. Read each subreddit's self-promo rules
first — this audience punishes ads and rewards genuine participation. Answer
dream questions properly, with quotes, and let people ask what you used.

### 5. Paid — later, or never

Only after the annual plan is live and you know real retention. Apple Search Ads
on your own brand term is the one defensible spend.

## Launch sequence

| Phase | Do |
|---|---|
| **Pre-launch** | Deploy backend · verify readings quote correctly · enrol in Small Business Program · TestFlight/Play internal with 10–20 real people · fix the §6 top-5 |
| **Soft launch** | Ship quietly · watch D1/D7 retention and free→paid conversion · **do not** spend on marketing yet |
| **Content build** | Publish the symbol dictionary · start posting video 3–5×/week · both compound, so start early |
| **Launch** | Product Hunt · the subreddits · press angle: *"an AI dream app that refuses to make things up"* |

## What to measure

Only five numbers matter early:

1. **Install → first dream logged** — if this is under 50%, onboarding or the mic is broken
2. **D7 retention** — under 15% means no habit and nothing else matters
3. **Free → paid conversion** — 3–5% is healthy; under 2% means the wall or the paywall is wrong
4. **Readings per active user per month** — this is your COGS, watch it directly
5. **Trial → paid conversion** — under 40% means the trial isn't delivering the value moment

## The honest risk

This is a **bursty-use product**. People log dreams for three nights, then not
for two weeks. Subscriptions are a poor fit for bursty use — the category's own
critics say so plainly: *"paying $10/month for an app you use four times a year
is wasteful."*

Two hedges, both supported by the research:

- **The annual plan** — reframes it as a yearly companion, not a monthly utility, and removes the monthly cancel decision.
- **Make Insights the reason to return.** It is the only screen that gets *better* the longer you use it, and the only one a competitor can't clone by copying a prompt. That is also why gating it would be a mistake — the category leader un-paywalled exactly this feature after users called it a deal-breaker.
