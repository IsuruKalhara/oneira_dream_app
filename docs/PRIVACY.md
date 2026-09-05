# Privacy Policy — Dreamlore

**DRAFT TEMPLATE — not legal advice. Have a lawyer review before publishing.**
Replace every `[BRACKET]`. Last updated: `[DATE]`.

Dreamlore ("we", "us") is operated by `[COMPANY / SOLE TRADER NAME]`, `[ADDRESS]`,
contact `[PRIVACY EMAIL]`. This policy explains what we do with your information.

## The short version
- Your dream journal is stored **on your device**, not on our servers.
- We do **not** require an account, your name, or your email.
- Your spoken dream is transcribed **on your device**; the **audio never leaves your phone**.
- To generate an interpretation, the **text** of a dream is sent to our processing
  service and our AI provider, used only to produce that reading, and **not stored**
  by us afterwards.

## What we collect and why

| Data | Purpose | Where it lives |
|---|---|---|
| Dream transcripts & interpretations | Your journal | **On your device only** (local database) |
| Dream pictures (Plus) | Illustrate a dream you chose to paint | Generated on request, stored **on your device only** |
| Dream text (transient) | To generate an interpretation, and a picture if you ask | Sent to our proxy → OpenAI at request time; not retained by us |
| Anonymous device token (random ID) | Enforce fair-use limits | Our proxy (rate-limit counters, auto-expiring) |
| Email address and display name | Identify your account so a subscription follows you | Firebase Authentication (Google) |
| Subscription status | Unlock paid features | Google Play Billing, verified by our proxy |
| Crash reports and app-usage events | Diagnose crashes and see which screens are used | Firebase Crashlytics and Analytics, **release builds only** |

Sign-in is optional for using the journal, but required to hold a subscription.

We do **not** collect your contacts, your location, or your audio. Speech is
transcribed **on your device**; the recording itself never leaves it.

## Third parties (sub-processors)
- **OpenAI** — generates the interpretation from your dream text, and the picture
  if you ask for one. Receives the dream text, never your identity.
- **Google (Firebase)** — Authentication (email, display name), Crashlytics and
  Analytics.
- **Google Play** — app distribution, payment processing and subscription state.
- **Cloudflare** — hosts our proxy, which holds the API keys and the rate-limit
  counters so the app never has to.

Retrieval runs inside our own proxy against a public-domain library shipped with
it, so no third party is involved in choosing which passages you are shown. We do
not sell personal data.

## Retention
Journal data remains on your device until you delete it (Settings → "Clear all
dreams", or by uninstalling). Our proxy keeps only short-lived, anonymous rate-limit
counters (auto-expiring). Dream text is not persisted by us after a reading is returned.

## Your choices & rights
- **Delete your dreams** anytime: Settings → Clear all dreams.
- **Delete your account and all local dreams**: Settings → Delete account. This
  removes your Firebase account permanently and cannot be undone. If you have
  uninstalled the app, email `[PRIVACY EMAIL]` and we will delete it for you.
- Deleting your account does **not** cancel a Google Play subscription — cancel
  that in Google Play, or you will continue to be billed.
- Because the journal itself lives on your device, there is no server-side copy of
  your dreams for us to export.
- If you are in the EEA/UK (GDPR) or California (CCPA/CPRA), you have rights to
  access/delete/etc.; contact `[PRIVACY EMAIL]`. `[Confirm obligations with counsel.]`

## Children
Dreamlore is not directed to children under `[13 / 16]` and we do not knowingly collect
their data.

## Security
Data in transit is encrypted (HTTPS). On-device data is protected by your device's
security. No method is 100% secure.

## Changes
We may update this policy; material changes will be noted in the app or here.

## Contact
`[PRIVACY EMAIL]`
