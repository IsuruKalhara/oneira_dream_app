# Dreamlore — brand and motion notes

*For Bitfuzed's marketing and anyone touching the UI. Everything here ships in
the app; nothing is aspirational.*

## Mark

`dreamlore_app/assets/brand/mark.svg` (source) · `mark.png` (1024, transparent)

A waxing crescent whose inner curve opens into the pages of a small book:
the night, and the library the readings quote. One colour — parchment
`#E9E1D0` — on ink `#0E0E1A`. `mark_alt.*` is the runner-up (crescent resting
on an open book), kept for store graphics where a wider shape fits better.

In the app it appears through one widget, `BrandMark`, on the splash, sign-in,
and the startup-error screen, so it is always the same mark at the same
weight. The share card carries a small drawn moon plus the wordmark instead.

The Android/iOS **launcher icons** were not replaced — they are the crescent
already shipped. If you adopt the new mark as the icon, regenerate with
`flutter_launcher_icons` from `mark.png` on an ink background and check it at
48 px: the pages are fine at that size but the margin should be tightened.

## Type

Two variable faces, bundled (nothing fetched at runtime):

| Role | Face | Where |
|---|---|---|
| Serif | **Newsreader** | wordmark, the dream itself, quotes from the library, share card |
| Sans | **DM Sans** | everything else — UI, readings, buttons, labels |

Sign-in uses Google's dark button with the four-colour G (`google_g.dart`), per their branding rules.

The pairing is deliberate: a warm text serif with a quiet geometric sans,
the same temperature as Claude's own interface. `Ob.serif(...)` is the only
way to reach the serif in code; the theme's `fontFamily` handles the sans.

## Colour

| Token | Hex | Use |
|---|---|---|
| ink | `#0E0E1A` | ground |
| ink deep | `#07070F` | gradient falloff, floating chrome |
| parchment | `#E9E1D0` | display type, primary pill, the mark |
| muted | `#9490AC` | secondary text |
| rule | `#2E2A47` | hairlines |
| indigo | `#6C5CE7` | Material seed; accents, chips, the picture glow |

## Onboarding clip

`assets/video/onboarding.mp4` — 20 s, 540×960, silent, ~1.2 MB. The Milky
Way over a perfectly still lake, a crescent mirrored in it, mist drifting.
Generated with Seedance 2.0 Mini via Higgsfield (25 credits, 10 s), then
made a ping-pong (forward + reversed) with ffmpeg so the clip's own ends meet
without a cut, and re-encoded at `-crf 25` with audio stripped.

Playback (`AmbientVideo`) never relies on the player's loop, which stutters
a frame on Android: two players of the same clip cross-fade a beat before
the end, then back, so the seam is always under a fade. Plays behind
onboarding page 1 only, under an ink gradient; frozen under reduced motion;
if the asset fails to load the page keeps its starfield.

## Splash

Native: the mark **with the wordmark** (`assets/brand/splash_lockup.png`) on
legacy Android and iOS; Android 12+ shows the mark alone inside the system's
icon circle (the OS allows no text there). Flutter's first frame repeats the
lockup and dissolves into the app.

## Book covers

`assets/brand/book1..3.jpg` — cover art for the three library books, shown on
the cards that fan out while a reading is being written. Art-nouveau engraved
frames on the night ground: a closed eye with a crescent lid (*The
Interpretation of Dreams*), a constellation profile (*Dream Psychology*), a key
hanging from a moon (*Ten Thousand Dreams Interpreted*). Generated with Recraft
V4.1 (`utility_vector`, brand palette, 2.5 credits each) and rasterised to
336×468 — three times the 112×156 card. Deliberately textless, so the title
sits over the art in Newsreader and stays legible at card size.

## Motion

One vocabulary, in `lib/ui/motion.dart`:

- **Reveal** — content settles in with a 14 px drift and a fade; siblings
  stagger 70 ms. Used for readings, journal rows, sign-in.
- **StateSwitcher** — screen states cross-fade with a 2 % drift instead of a
  cut (capture → reading → done on the record screen).
- **PressScale** — tappables ease to 97 % under a finger and spring back.
- Tab pages use Material's shared-axis X: the outgoing page drifts toward the
  side it came from while the incoming settles, both under a fade. Forward
  navigation uses Material's fade-forwards;
  the picture's arrival is the one flourish (glow bloom, 1.04 → 1 settle, a
  medium haptic).
- **The mic orb** ripples while listening: three phased rings born at its edge,
  their thickness and starting radius driven by live loudness, so the screen
  proves the mic hears you.
- **The wait for a reading** shows the three books fanned out, each lighting in
  turn under a sweeping beam, with a caption naming the book being read. The
  narration is honest — retrieval really does go book by book.
- Every effect collapses to nothing when the OS asks for reduced motion.

## Errors

`lib/core/errors.dart` maps anything thrown to a `Friendly` — a title, a body
that says what to do next, an icon, and whether retrying helps. Copy is calm
("The library is closed for a moment"), never technical. Startup failure has
its own screen with a retry; a widget that fails to build renders as a quiet
card, not the red box.

## Price

Plus at **$4.99 / month, $29.99 / year** with a 3-day trial on yearly.
Reasoning and competitor table in `GROWTH-ASO-SEO-GEO.md` §7b.
