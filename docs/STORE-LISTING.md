# Store listing & review notes — Dreamlore

Positioning copy + the App Store / Play rules that matter for this app. The core
rule: **frame everything as reflection/journaling, never as medical, psychological,
or predictive.** Health-claim language triggers rejection and liability.

> Listing copy, keyword map, screenshots plan and the web/AI-search side now live in
> `GROWTH-ASO-SEO-GEO.md`. This file keeps the store *rules*: claims, ratings, privacy.

## Name / subtitle
- Play name: **Dreamlore: Dream Journal & AI** · App Store name: **Dreamlore: Dream Journal**
- Subtitle: *Interpretation, quoted & private* — avoid "analysis", "therapy", "meaning decoder".

## Description (draft)
> Wake, speak your dream, and get a thoughtful reflection grounded in classic
> public-domain dream literature — with real quotes. Your journal stays private on
> your device. Dreamlore is a space for reflection and curiosity, not medical or
> psychological advice.
>
> • Speak or type your dream — transcribed on your device
> • A grounded reading that quotes real sources
> • A private, searchable dream journal
> • See the symbols that recur over time
>
> Dreamlore is for reflection and entertainment. It is not medical, psychological, or
> predictive advice, and not a substitute for professional care.

## Words to USE
reflection, journaling, curiosity, explore, grounded in literature, private, on-device.

## Words to AVOID
diagnose, therapy, therapeutic, treat, cure, disorder, mental health, predict,
fortune, guaranteed, "what your dream *means*" as a factual claim.

## Age rating
Suggest **12+ / Teen** (infrequent mature/scary themes from dream content). Confirm
against Apple/Google questionnaires. Not directed at children.

## Apple privacy "nutrition label" (answer honestly)
- **Data used to track you:** None.
- **Data linked to you:** Email address (Google sign-in, used only to attach the
  subscription to the account).
- **Data not linked to you:** Purchases (subscription status); "Other data" — dream
  text sent transiently to the AI provider for interpretation and, on Plus, for the
  dream picture (not stored by you); **Diagnostics** — crash reports and app usage
  (Firebase Crashlytics + Analytics, release builds only, both off in debug).
Disclose the AI-provider processing; do not claim "no data leaves the device" — the
dream *text* does, at interpretation time. (Audio does not.)

## Google Play Data safety
Mirror the above: Google sign-in (email), transient dream text sent for processing
(reading + Plus picture), purchases handled by Google Play Billing and verified
server-side. Dreams, audio and pictures are stored only on the device.

Also declare, because the app now ships them:
- **Crash logs** and **Diagnostics** — Firebase Crashlytics, collected, not linked
  to the user, not used for tracking. Enabled in release builds only.
- **App interactions** — Firebase Analytics, same treatment.
Both must be listed even though they are Google's own SDKs; "we didn't write it"
is not an exemption.

## Account deletion (Play policy — mandatory)
Any app that lets an account be created must offer deletion **both** in-app and at
a public URL, and the URL must be reachable without installing the app.

- **In-app:** Settings → Delete account. Removes the Firebase user and every dream
  on the device, behind a confirmation that says it cannot be undone.
- **URL:** must be live before submission and entered in the Play Console under
  *App content → Data safety → Account deletion*. Suggested:
  `https://tropicalai.net/dreamlore/delete-account` — a static page explaining the
  in-app route plus an email address for anyone who has uninstalled.
- Deleting the account does **not** cancel a Play subscription; the dialog says so,
  because a user who expects otherwise will file a refund dispute.

## App review notes (paste into the review-notes field)
> Dreamlore transcribes a spoken dream on-device and returns an AI-generated reflective
> interpretation grounded in public-domain texts. It is explicitly framed as reflection/
> entertainment, not medical or psychological advice (see onboarding + in-app footer).
> A safety check detects expressed self-harm intent and shows crisis resources instead
> of an interpretation. Subscriptions (Google Play Billing) unlock more readings and dream pictures.
> Sign-in is Google via Firebase Auth; a licence-tester Google account is attached to
> this submission. Backend is a stateless proxy that does not store user data.

## Screenshots to produce
See `GROWTH-ASO-SEO-GEO.md` §2 for the seven-frame storyboard (record → quote card →
dream picture → journal → insights → paywall with trial → privacy).
