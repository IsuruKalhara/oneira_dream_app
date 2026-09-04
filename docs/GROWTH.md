# Dreamlore — Growth Plan: competitors, rankings, and income
### A Bitfuzed product · August 2026 · synthesized from a 3-track research sweep (104 cited sources)

Companion to `LAUNCH.md` (deploy + unit economics). This is the how-to-win:
who you're against, how to rank in the **App Store**, on **Google**, and inside
**LLM answers**, and what the money can look like.

**Method note:** all store data fetched August 2026; rating counts are scale
proxies; nothing below is an invented number — where research couldn't verify,
it says "unavailable".

---

## 0. Three urgent findings

1. **Name collision on Google Play.** An app called *"Dreamlore - Dream Journal"*
   already exists (`com.dreamlorepp.dreamlore`, ~50 installs, **3.4★**). It's too
   small to block you, but: check trademark exposure before launch, expect to
   fight for your own brand query on Play, and differentiate the title
   (recommendation below does). A 3.4★ near-namesake beside your listing is a
   conversion risk.
2. **The "best dream app" surface is a competitor land-grab in progress.** The
   entire first page for "best dream interpretation app 2026" is competitor
   blogs ranking themselves #1 (Chitta, Dreamz, Dreamly, DreamStream,
   individuate.me, Noctalia…). No neutral authority owns it — and because LLMs
   retrieve top results, those self-listicles are literally feeding ChatGPT's
   answers today. Cheap to enter, expensive to ignore.
3. **The category's loudest complaint is billing dark patterns.** DreamApp has
   repeated $64–$80 surprise-trial-charge reports ("total scam" reviews);
   Dream Interpreter AI gives 3 free readings ever, then walls. Dreamlore's
   honest free-1/day-forever isn't just pricing — it's a positioning weapon.

---

## 1. Competitor battle card

| App | Price | Scale (iOS ratings) | Their weakness → your attack |
|---|---|---|---|
| **DreamApp** | $9.99–19.99/mo, $59.99–79.99/yr | 4.6★ · 3.9K (Play 1M+ installs) | Trial-charge scandal, generic AI, "same dream, different answer" → **trust + provenance** |
| **Oniri** (incumbent) | ~$7.99/mo / $47.99/yr | 4.6★ · 3.8K | Great lucid tools, weak readings, voice is paywalled → **interpretation depth, voice free** |
| **Dreamz Journal** | $5.99/mo / $49.99/yr | 5★ · **3 ratings** (brand-new) | Sells "omens & rituals" → **verifiable quotes at the same price**; beatable now |
| **Dream Interpreter AI** | 3 free ever, then pay | 4.7★ · 106 | Hard wall + charge complaints → **generosity** |
| **yap** | IAP $1.99–99.99 | 4.6★ · 101 | Kitchen-sink astrology, "AI-bot content" reviews → **focus**; validates voice-first |
| **Chitta** | ~$9.99/mo, web-only | n/a | Unfalsifiable "5,000-year science" → **checkable sources, 40% cheaper, native** |
| **individuate.me** | $1/$5/$20 credits | web-only | No app, no free tier → **own the wake-up moment on a phone** |
| *Adjacent ceiling:* Co–Star 206K ratings, The Pattern 15K (~$400K/mo est.), Moonly 31K | $9–15/mo | — | All punished in reviews for paywall creep; Moonly users now complain about **AI-slop content** — your verbatim-book answer to a felt problem |

**The five attack lines** (each maps to a verified complaint pattern):
provenance vs. AI slop · trust vs. billing dark patterns · on-device privacy
(unclaimed high ground — nobody leads with it) · voice-first at wake-up
(~50% of dream content is lost within 5 minutes; rivals paywall or bury voice)
· publish the listicle (see §4).

**Pricing:** the credible band is $5.99–9.99/mo; adjacent giants get review-
punished at $9–15. **$5.99/mo · $29.99/yr stands** (undercuts Oniri/Chitta/
DreamApp, matches Dreamz). SHIP.md's $1–2/mo remains wrong in both directions.

---

## 2. App-store ranking (ASO)

**How ranking works now:** keywords get you indexed; **conversion, ratings
velocity and retention decide whether you climb**. Post-install behavior is a
first-class signal on both stores. For a zero-review app the only day-1 levers
are metadata on *winnable* terms, listing conversion, a ratings engine, and
freshness surfaces (in-app events / LiveOps).

**Competitor metadata (fetched verbatim):** every incumbent title stacks
`dream · interpretation/-er · journal · meaning · dictionary · AI · lucid ·
sleep`. **Nobody owns:** voice, private/on-device, books/quotes. DreamApp,
Oniri and Dreamy all sit in **Health & Fitness**; only micro-apps sit in
Lifestyle.

**Recommended metadata:**

| Field | Value |
|---|---|
| iOS title (30) | `Dreamlore: Dream Journal & AI` |
| iOS subtitle (30) | `Interpreter, Meaning & Sleep` |
| iOS keywords (100) | `interpretation,dictionary,symbols,nightmares,lucid,diary,voice,analysis,recorder,psychology,jung` |
| Play title (30) | `Dreamlore: AI Dream Journal` *(also splits you from the Play squatter)* |
| Play short desc (80) | `AI dream interpretation & voice dream journal. Private, with real book sources.` |
| Category | **Health & Fitness primary** (where all the installed money sits), Lifestyle secondary on iOS |
| Screenshot captions (indexed per 2025 reporting) | "Voice-record dreams — transcribed on your phone" · "Readings that quote real books, not a chatbot" · "Your journal never leaves your device" |

Volume labels are qualitative estimates — validate against Apple Search Ads
Popularity (free) before locking metadata.

**90-day expectation, honestly:** days 0–14 index + brand + ultra-long-tail
("voice dream journal", "jung dream analysis"); days 15–45 first 50–200
ratings (prompt at the emotional peak: right after the first reading lands, or
a 3-day streak — never at open) and mid-tail on pages 1–2; days 45–90 one
metadata iteration from real search-term data + screenshot A/B. **Head-term
page-1 ("dream journal") is a 6–12-month, ratings-driven outcome — anyone who
promises it in 90 days is selling something.**

Three highest-leverage actions: day-1 metadata + differentiated screenshots ·
a pre-launch ratings engine (TestFlight cohort primed to rate week one) ·
small always-on Apple Search Ads (paid installs feed organic keyword velocity
on iOS) + a monthly in-app-event cadence.

---

## 3. Google (the dream dictionary — done right)

**Reality check #1 — who actually ranks:** "dream about snakes meaning" is
won by mattress brands (dreams.co.uk, koala.com), Today.com and clinic blogs;
"teeth falling out dream" by Sleep Foundation and Healthline. Old-school
dictionaries (dreammoods ~10.4K pages) survive only on the long tail. The
winners' format: expert byline, psychology-first framing, scenario variations,
honest hedging.

**Reality check #2 — AI Overviews took the clicks.** Informational queries
lose **34–61% of organic CTR** where AIOs appear (Seer: −61%; Pew: 8% vs 15%
click rates). Plan for each page earning **⅓–½ of 2023-era clicks**; the
business case stands on the long tail + being the *cited* source + the high
intent of what does land.

**Reality check #3 — a verbatim Miller republication would fail.** The full
text is already on Gutenberg, Internet Archive, sacred-texts, nickm.com and
four+ others; Google's Aug-2025 scaled-content enforcement targets exactly
"thousands of pages differing by keyword." **Do not ship the Miller mirror I
originally sketched in LAUNCH.md — ship this instead:**

1. **Miller & Freud as cited artifacts, not page bodies** — attributed
   blockquotes ("Historical interpretation — G.H. Miller, 1901") inside
   original, layered editorial (modern psychological view → Freud/Jung →
   Miller 1901 → cultural variants → scenario H2s), with a named reviewing
   editor (a psychologist/sleep researcher is affordable and decisive).
2. **The moat nobody can copy: your app's anonymized statistics.** "Among N
   Dreamlore users who logged snake dreams, X% tagged fear; the most co-occurring
   symbols were water and teeth." Factually unique per page — and statistics
   are also the single best-*proven* LLM-citation trigger (§4).
3. **Launch 150–400 deep symbols, not 10,000 thin ones.** Expand in
   quality-gated batches; a mass day-one launch is the exact spam signature.
4. **Architecture:** `dreamlore.app/dream-dictionary/` subfolder (authority flows
   both ways) → 15–25 category hubs → one canonical page per symbol (variants
   as H2 anchors until they earn their own URL). "Commonly appears with"
   module driven by real co-occurrence data = unique content + crawl paths.
5. **Schema:** `DefinedTermSet`/`DefinedTerm`, `Article` with author +
   `reviewedBy`, `isBasedOn`/`citation` → the Gutenberg editions
   (machine-readable proof you're transformative, not a scrape),
   `BreadcrumbList`, `SoftwareApplication` on app pages.

---

## 4. LLM ranking (GEO) — getting recommended by ChatGPT/Claude/Perplexity/Gemini

**What the evidence says (not vendor folklore):**

| Tactic | Evidence status |
|---|---|
| Statistics, quotations, cited sources on-page (+25–40% generative visibility) | **Proven** — the only controlled study (Princeton/GaTech, KDD 2024) |
| Reddit threads (≈40% of LLM citations; 3–4× on "best/top/vs" prompts; individual threads, not brand pages) | **Measured** (Semrush 150K citations; Profound 4B+) |
| Third-party listicle inclusion | **Measured** + the live SERP is competitor blogs — the retrieval substrate for app recommendations |
| Allow AI crawlers + server-side render | **Mechanical necessity** (several AI crawlers run little/no JS) |
| Schema for LLM citation, answer-first formatting | Practitioner consensus, unproven |
| **llms.txt** | **Effectively disproven** — 97% never fetched (Ahrefs, 137K sites); Google confirms Search ignores it. Skip. |

**The plan, in priority order:**
1. **Reddit, honestly.** r/Dreams, r/DreamInterpretation, r/LucidDreaming —
   founder-flagged, genuinely useful answers with quotes; the goal is being
   *mentioned by others* in threads, because threads are what get cited.
   Astroturfing risks bans and brand damage.
2. **Digital PR into the listicles that already rank** (androidally,
   technicalustad, requiemforadream, alternativeto, world-of-lucid-dreaming…)
   — a handful of inclusions moves LLM answers more than any on-site change.
   Notably: **no Wirecutter/Healthline-class list exists** — one mainstream
   placement would outrank the whole competitor-blog ecosystem.
3. **Publish your own honest comparison page** ("Dreamlore vs Oniri vs
   DreamApp") — the bar is currently micro-blogs with no authority.
4. **Robots + rendering:** allow GPTBot, OAI-SearchBot, ClaudeBot,
   PerplexityBot, Google-Extended; SSR the dictionary; verify Bing indexation
   (ChatGPT browsing leans on Bing).
5. **App-store hygiene** — engines read your listing; reviews and a
   descriptive listing shape how models describe you.
6. **Measure from day one:** a fixed 30–50-prompt panel ("best dream journal
   app", "what does dreaming about snakes mean"…) run weekly across
   ChatGPT/Claude/Gemini/Perplexity/AIO; track share of voice, citation share,
   and the mention-without-citation gap (each one is a PR target). Free
   signals: GA4 referrals from chatgpt.com/perplexity.ai; GPTBot/ClaudeBot
   crawl volume in server logs.

---

## 5. Income model

Unit economics from LAUNCH.md: net $5.09/mo (monthly) or $25.49/yr (annual)
after the 15% Small Business rate; COGS ≈$0.027/reading (Sonnet 5) /
$0.009 (Haiku); free user ≈$0.27/mo on Haiku at 1/day uncapped.

**These are planning scaffolds, not forecasts** — the app is pre-launch and
every input is an assumption you replace with data in month one.

| | Conservative | Base | Upside |
|---|---|---|---|
| What happens | Ship + ASO only | + dictionary (150→400 pages) + Reddit/listicle PR + weekly short-form video | + one viral format or store featuring + mainstream listicle |
| Installs/mo by M12 | 1,500 | 6,000 | 25,000 |
| Install → paid (blend) | 2% | 3.5% | 5% |
| Paying subs at M12 | ~90 | ~600 | ~3,500 |
| Monthly:annual mix | 70:30 | 60:40 | 50:50 |
| **MRR-equivalent at M12** | **≈$400** | **≈$2,800** | **≈$17,000** |
| Year-1 cumulative revenue | ≈$2K | ≈$14K | ≈$80K |
| Year-1 AI COGS | <$500 | ≈$2.5K | ≈$12K |

Sanity anchors: The Pattern ≈$400K/mo with 15K ratings after years; Dreamz
(your price twin) has 3 ratings — the niche's middle class is thousands, not
millions, of dollars a month. The realistic year-1 goal is **base case +
D7 retention ≥15% + free→paid ≥3%** — proof the machine converts, which is
what justifies pouring fuel (content, then maybe paid) in year 2.

**The five numbers that matter** (unchanged from LAUNCH.md): install→first
dream ≥50% · D7 ≥15% · free→paid 3–5% · readings/user/mo (COGS) · trial→paid
≥40%.

---

## 6. Sequenced 12-month roadmap

| When | Do |
|---|---|
| **Pre-launch (now)** | Fix list from AUDIT.md ✅ · deploy Worker (LAUNCH.md) · trademark check on "Dreamlore" · reserve subreddit/handles · TestFlight cohort of 10–20 who will rate in week one |
| **M1 — soft launch** | Ship with §2 metadata · ratings prompt after first reading · Search Ads $5–10/day exact-match · watch the five numbers; **no marketing spend** |
| **M2–3 — content foundations** | Dictionary v1: 150 symbols, layered format, named reviewer · robots/SSR/schema · own comparison page · first 2 CPPs + monthly in-app events · founder Reddit presence begins |
| **M4–6 — distribution** | Dictionary → 400 symbols with app-stat modules · listicle PR round 1 (the §4 target list) · short-form video 3–5×/wk (read a dream → show the quote card → "that's Freud, 1899") · prompt-panel tracking live |
| **M7–9** | Product Hunt + press angle *"the AI dream app that refuses to make things up"* · pitch one mainstream publisher (the unowned slot) · metadata iteration 2 from real search terms |
| **M10–12** | If base-case numbers hold: scale video + consider Apple Search Ads beyond brand · begin cross-dream context (the category's #1 requested feature — and your retention moat) |

**Deliberately not in the plan:** paid UA beyond brand-term Search Ads
(LTV ≈$17–20 cannot buy installs in this category — see LAUNCH.md),
llms.txt, and a 10,000-page dictionary dump.
