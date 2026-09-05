# Dreamlore — ASO · SEO · GEO playbook

*Bitfuzed · September 2026. Research-backed, then applied to this app. Everything
here is written for the app as it now ships: sign in → onboarding → paywall,
Plus on Google Play (monthly / yearly with a 3-day trial), dream pictures.*

---

## 0. The one-line position

> **Dreamlore — the dream journal that quotes its sources.**
> Speak your dream when you wake. Get a reading grounded in real books, with the
> actual passages. See it painted. Keep it private.

Every listing, page and screenshot below is a variation of that sentence. The
category is crowded (DreamStream, Noctalia, Hypnos, Mirror, Oniri, Dreamz all
sell "AI dream interpretation"), so the rankable angle is not *AI* — it is
**grounded + quoted + private**, plus the picture. Nobody else leads with
verifiable quotes; own it.

---

## 1. Keyword map

Play has no hidden keyword field: the title, short description and full
description are the index, and 2026 guidance is precision over density —
stuffing lowers conversion and, increasingly, rank. The App Store weights
**name › subtitle › keyword field** (100 chars, no stop words, no repeats).

| Tier | Keywords | Where |
|---|---|---|
| **Head** (high volume, high competition) | dream journal · dream interpretation · dream meaning · dream dictionary | Title/name, short description, first 2 lines of description |
| **Body** (medium, our best fit) | dream journal app · dream interpretation app · voice dream journal · dream diary · dream analysis · dream symbols | Description H2s, subtitle, keyword field |
| **Long-tail** (low competition, high intent — 2026's growth lever) | what does my dream mean · dream about snakes meaning · dream journal with voice recording · dream to image · picture of my dream · recurring dream symbols · freud dream interpretation · private dream journal · dream journal no account | Description body, landing-page FAQ, blog/entity pages, Custom Product Pages |
| **Brand** | dreamlore · dreamlore app · dreamlore plus | Everywhere |

**Reviews are indexed on Play.** Nudge happy users toward the words we want:
the in-app review prompt (when added) should ask *"How is your dream journal
going?"* — not "Rate us" — so replies naturally contain "dream journal".

---

## 2. Google Play listing (primary store)

**App name (30):** `Dreamlore: Dream Journal & AI`
**Short description (80):**
`Speak your dream, get a reading quoted from real books, see it painted. Private.`

**Full description** — first 3 lines show before "Read more"; put the value and
the head keywords there:

```
Dreamlore is a dream journal that quotes its sources. Wake, speak your dream,
and get a thoughtful interpretation grounded in classic dream literature — with
the real passages, not invented meanings. Then see your dream as a picture.

SPEAK IT BEFORE IT FADES
• Tap once and talk. Your voice is transcribed on your phone — audio never leaves it.
• Or type. Edit anything before you ask for a reading.

A READING YOU CAN CHECK
• Grounded in public-domain dream literature: Freud's The Interpretation of Dreams,
  Miller's Ten Thousand Dreams Interpreted, and more.
• Every quote is verified word-for-word against the source before you see it.
• Symbols explained, plus one reflective question to carry into your day.

SEE YOUR DREAM (PLUS)
• Turn a dream into a painting made from your own words, saved with the entry.

A PRIVATE DREAM DIARY
• Your journal is stored only on this device. No cloud copy, no ads, no ad ID.
• Recurring dream symbols surface over weeks and months in Insights.

DREAMLORE PLUS
More readings every day, dream pictures, full symbol trends. Monthly or yearly —
the yearly plan starts with a 3-day free trial. Cancel any time in Google Play.

Dreamlore is for reflection and journaling. It is not medical, psychological, or
predictive advice, and is not a substitute for professional care.
```

**Category:** Lifestyle (not Health & Fitness — avoids the medical-claim lens).
**Tags:** Journal, Diary, Sleep, Self-care, Art.

**Screenshots** (the conversion layer; most users never scroll past image two):

| # | Frame | Caption (≤ 6 words, sentence case) |
|---|---|---|
| 1 | Record screen mid-listening, glowing mic | Speak your dream when you wake |
| 2 | Interpretation with a quote card open | A reading that quotes real books |
| 3 | Dream picture reveal (the image, full bleed) | See your dream, painted |
| 4 | Journal list with picture thumbnails | A private dream diary |
| 5 | Insights: recurring symbols chart | Watch the patterns surface |
| 6 | Paywall — yearly card with "3-day free trial" ribbon | Try Plus free for 3 days |
| 7 | Onboarding "Yours, and only yours" | Stays on your phone |

Dark night-indigo background throughout (the app's own palette, `#0E0E1A` /
`#6C5CE7`), one device per frame, caption on top, 1080×1920. Frame 3 is the
scroll-stopper: make the picture large and the phone bezel small.

**Preview video (30 s, silent-safe):** record → reading appears → "See your
dream" tap → painting reveal → saved in journal. Captions only, no voiceover.

**Custom store listings** (Play allows per-keyword-search listings): make one
for the *dream interpretation* cluster (lead with the quote card) and one for
the *dream to image* cluster (lead with the painting).

---

## 3. App Store listing (when iOS ships)

- **Name (30):** `Dreamlore: Dream Journal`
- **Subtitle (30):** `Interpretation, quoted & private`
- **Keyword field (100, comma-separated, no spaces, no words already in name/subtitle):**
  `diary,meaning,dictionary,symbols,voice,analysis,lucid,sleep,freud,jung,picture,art,recurring,ai`
- **Custom Product Pages** (now surfacing in organic search, 70 allowed): one
  per long-tail cluster — *"dream about snakes"*, *"voice dream journal"*,
  *"dream to image"* — each with the matching screenshot first.
- **In-app events:** *"Full-moon dream week"* style events are indexed metadata;
  cheap visibility once a month.

Frame nothing as health. "Reflection", "journaling", "curiosity" — see
`STORE-LISTING.md` for the words to avoid.

---

## 4. Ratings & reviews loop

- Ask at the calm moment: right after a dream is **saved** for the 3rd time, and
  never on a paywall or error. One ask per install, ever.
- Reply to every review within 48 h using the keywords naturally
  ("Thanks — glad the dream journal…"). Replies are indexed and lift rating
  confidence in the algorithm.
- Watch for "not accurate" reviews: the quote-verification story is the
  answer ("we only show passages that are really in the book").

---

## 5. Web SEO — the landing page

`docs/site/index.html` is a ready-to-host page for `tropicalai.net/dreamlore`
(the URL the app already links). It carries:

- **`SoftwareApplication` JSON-LD** with `applicationCategory`,
  `operatingSystem`, `offers` (free + Plus), and a slot for `aggregateRating`
  once there are ≥ 5 Play ratings (leave it out until then — fake or thin
  ratings are a penalty).
- **`FAQPage` JSON-LD** — the same questions AI engines are asked
  ("Is Dreamlore private?", "What does it quote from?").
- One H1 with the head keyword, H2s with body keywords, and long-tail phrases in
  the FAQ answers.
- Play badge deep link (`https://play.google.com/store/apps/details?id=com.bitfuzed.dreamlore`).

Add when live: `robots.txt` allowing everything, `sitemap.xml` with the page,
and Android App Links (`/.well-known/assetlinks.json`) so search traffic can
open the app directly.

**Entity pages to add over time** (each is a long-tail landing page *and* GEO
bait): `/dreamlore/dreams/snakes`, `/teeth-falling-out`, `/flying`, `/falling`,
`/water` — each: the Miller entry (public domain, quotable), a Freudian
sentence, a picture generated by the app, and the app CTA. Ten pages of this
beats one page of anything.

---

## 6. GEO — being the answer in ChatGPT / Perplexity / AI Overviews

AI engines that browse (Perplexity, Google AI Overviews, ChatGPT search) retrieve
pages at query time; the ones that don't rely on what was indexed and widely
cited before training. Both reward the same things:

1. **A citable entity statement.** One plain paragraph, on the landing page and
   in `llms.txt`, that an engine can lift whole:
   *"Dreamlore is a dream journal app by Bitfuzed for Android. It transcribes a
   spoken dream on the device, returns an interpretation grounded in
   public-domain dream literature with verbatim quotes, can generate a picture
   of the dream, and stores the journal locally. Free tier; Dreamlore Plus is a
   monthly or yearly subscription with a 3-day trial."*
2. **`llms.txt`** at the site root (`docs/site/llms.txt` is ready): what the app
   is, what it is not, pricing, links. Cheap, and Perplexity/Claude-style
   agents read it.
3. **Comparison content.** Engines answering "best dream journal app" cite
   comparison pages. Publish *"Dreamlore vs. AI dream apps: what 'grounded'
   means"* — honest, names competitors, states the difference (verified quotes,
   local-only journal). Refresh it monthly: content updated within 30 days is
   cited ~3× more.
4. **Third-party mentions.** Product Hunt, r/Dreams, r/LucidDreaming (as a
   maker, not an ad), a Hacker News "Show HN" on the quote-verification
   technique. Entity authority comes from being mentioned elsewhere, and the
   verification story is genuinely interesting to those audiences.
5. **Answer-shaped FAQ.** Question as heading, answer in the first sentence,
   under 60 words. Already structured that way in `index.html`.

---

## 7. "Attractive to buy" — the conversion path, end to end

| Moment | What they see | Why it converts |
|---|---|---|
| Store | Frame 3 (the painting) + "3-day free trial" in frame 6 | The picture is the shareable hook; the trial removes risk |
| Sign-in | One tap, "journal stays on your phone" | No friction, privacy stated up front |
| Onboarding | 4 pages, ends with a mic ask that is explained | Permission granted in context → first dream logged |
| First reading | Quote card + **"See your dream" card with PLUS pill** | Curiosity gap: the feature is visible, unlocked in one tap |
| Tap (free user) | Blurred painting behind glass, lock, one CTA | Loss aversion + curiosity; no dark patterns, "Maybe later" honest |
| First reading (Plus) | The painting starts on its own the moment the reading lands — no second tap — and settles in with a glow | The feature pays off immediately; the wait is narrated, not blank |
| Share | "Share" on any painting composes a 4:5 card: the painting, one line of the dream in the app serif, the Dreamlore mark, and the store link in the share text | The picture is the shareable hook; every share carries the brand and a way in, with no account or upload |
| Paywall | Yearly pre-selected, trial ribbon, savings %, "How the trial works" timeline | Trial anxiety removed; price from Play in their currency |
| Success | "Your trial has started" + when the charge lands | Trust → fewer refunds and chargebacks |

---

## 7b. Price

| App | Monthly | Yearly | Trial |
|---|---|---|---|
| DreamApp | $7.99 | $47.99 | — |
| Dream Book | $6.99 | $34.99 | 7 days |
| Dream Interpreter AI | $4.99 | — | 7 days |
| **Dreamlore Plus** | **$4.99** | **$29.99** (≈ $2.50/mo) | **3 days**, yearly |

Under every comparable on both plans, with the yearly framed per month on the
paywall. The short trial is deliberate: three days is long enough to log two
mornings and see a painting, short enough that the charge date is memorable —
that is what the "How the trial works" timeline on the paywall is for. Revisit
after 60 days of Play data; the lever to pull first is yearly price, not monthly.

## 7c. Staying — what brings people back

Dream apps churn because the morning is the only moment that matters and
nothing pulls the user into it. Four things in the app carry retention, in
order of weight:

1. **The morning reminder** (Settings → on by default after onboarding's mic
   step is granted). It is the whole loop: wake, tap, talk. Ask for it once,
   in context, never with a modal.
2. **The picture.** A painting of last night is the thing people open the app
   to look at again and the thing they show someone. Plus users get one on
   every reading with no second tap; free users see the invitation on every
   reading.
3. **The week strip on Patterns.** Seven dots, filled or not. No streak
   counter, no guilt copy — a rhythm is legible without being a score.
4. **Plain words.** "Your dream", "What does it mean?", "What keeps coming
   back". Anyone half-awake understands the whole app on first open, which is
   the retention lever nobody measures.

Measure: D1 and D7 return rate by whether the reminder is on; readings per
week; share taps per painting. Change the reminder copy before anything else.

## 8. Launch order (do these in sequence)

1. Play Console: products + 3-day trial offer (SHIP.md §3). Internal test.
2. Screenshots 1–7 + preview video from a real device.
3. Publish `docs/site/` to `tropicalai.net/dreamlore` with `llms.txt`.
4. Listing copy above → Play. Submit.
5. Week 1: Product Hunt + Show HN (quote verification) + two subreddit posts.
6. Week 2: first three entity pages (snakes, teeth, flying). Monthly refresh.
7. Month 2: read Play's search-term report; move winning long-tails into the
   short description and a custom store listing.

---

## Sources

- AppTweak — [Google Play ASO guide](https://www.apptweak.com/en/aso-blog/aso-for-google-play-app-store-optimization-guide-for-android) · [What is ASO (2026)](https://www.apptweak.com/en/aso-blog/what-is-app-store-optimization-and-why-is-aso-important)
- ASOMobile — [App listings in Google Play 2026](https://asomobile.net/en/blog/app-listings-in-google-play-2026/) · [ASO in 2026](https://asomobile.net/en/blog/aso-in-2026-the-complete-guide-to-app-optimization/)
- Phiture — [ASO trends in 2026](https://phiture.com/asostack/aso-trends-in-2026/)
- AppLaunchFlow — [Google Play optimization 2026](https://www.applaunchflow.com/blog/google-play-store-optimization-2026) · [iOS ASO best practices](https://www.applaunchflow.com/blog/aso-best-practices)
- ScreenFast — [Listing checklist 2026](https://screenfast.app/blog/app-store-listing-optimization-checklist)
- Enrich Labs — [GEO complete guide 2026](https://www.enrichlabs.ai/blog/generative-engine-optimization-geo-complete-guide-2026) · LLMrefs — [GEO guide](https://llmrefs.com/generative-engine-optimization) · Kick Ads — [Getting cited in AI Overviews](https://www.kickads.co/en/generative-engine-optimization)
- Geodocs — [GEO for mobile app developers](https://geodocs.dev/geo/geo-for-mobile-app-developers) · App SEO — [App SEO 2026](https://appseo.com/app-seo/) · FreelanceSEO — [App indexing strategy 2026](https://freelanceseo.sg/blog/app-indexing-strategy-2026/)
- Competitor landscape — [DreamStream](https://dreamstream.art/blog/best-dream-apps-2026/) · [Hypnos](https://www.usehypnos.com/blog/best-dream-journal-apps-2026) · [Noctalia](https://noctalia.app/en/dream-journal-apps) · [Mirror](https://mirrorwithin.org/best-dream-journal-and-interpretation-apps/) · [Dreamz](https://dreamz-journal.com/blog/best-dream-interpretation-apps-2026)
