# Play Store assets — what to upload, and where

Everything in this folder is ready to upload as-is. Sizes and formats already
match what Play Console accepts, so nothing needs resizing.

In Play Console the slots are under
**Grow → Store presence → Main store listing**, unless noted.

| File | Play Console slot | Spec | Required? |
|---|---|---|---|
| `play_icon_512.png` | **App icon** | 512×512 PNG | Required |
| `feature_graphic_1024x500.png` | **Feature graphic** | 1024×500 PNG | Required |
| `01_speak.png` … `07_private.png` | **Phone screenshots** | 1080×1920, 2–8 allowed | Required (min 2) |

Upload the screenshots **in numbered order**. Play shows them in the order
you place them, and most people never scroll past the second one — so the
order is the argument, not just a gallery.

---

## The screenshots, and what each one is for

| # | File | Caption on the frame | The job it does |
|---|---|---|---|
| 1 | `01_speak.png` | Speak it before it fades | The core promise in one image: you talk, at 6am, and it catches it |
| 2 | `02_reading.png` | A reading that quotes real books | The differentiator. Every competitor sells "AI dream meanings"; only this shows real quotes with named sources |
| 3 | `03_painted.png` | See your dream, painted | The scroll-stopper and the shareable hook. Biggest device on purpose |
| 4 | `04_journal.png` | A private dream diary | Shows it is a real journal that accumulates, not a one-shot toy |
| 5 | `05_patterns.png` | Watch the patterns surface | The reason to come back a fourth time — "Horse, across 3 nights" |
| 6 | `06_plus.png` | Plus, from $2.50 a month | Price transparency before install reduces the bounce at the paywall |
| 7 | `07_private.png` | No account. Nothing uploaded. | Kills the biggest objection to a dream journal: who else can read it |

Frames 2 and 5 carry the ASO keywords that matter (*dream interpretation*,
*dream symbols*, *recurring dreams*) as visible on-image text, which Play's
own search indexing and every "is this app any good" glance both pick up.

---

## Two things to redo before you publish

1. **`06_plus.png` should be re-shot from a Play build.** These were captured
   from a sideloaded debug build, where Play returns no products — so the card
   shows the fallback "from $29.99/yr" and **no 3-day trial ribbon**. Once the
   subscriptions exist and you install from Internal Testing, retake this one
   screen and the caption should become **"Try Plus free for 3 days"**, which
   is the stronger line. Everything else on the frame is final.

2. **The paintings in frames 3–5 came from the local mock**, not the real
   image model, so they are simpler than what ships. Retake 3, 4 and 5 against
   the deployed Worker and the real pictures will be noticeably better. The
   framing script handles it — see below.

Nothing else here needs changing.

---

## Custom store listings (worth doing, cheap)

Play allows extra listings targeted at specific search terms. Make two, both
reusing these files, only reordered:

- **"dream interpretation" cluster** — lead with `02_reading.png`
- **"dream to image" / "picture of my dream" cluster** — lead with `03_painted.png`

---

## Regenerating

Screenshots are real captures of the running app — Play policy requires that
they show actual in-app content, so none of this is mocked up in a design
tool. The frame around each capture (background, caption, device) is drawn by
`make_store.py`, kept in the session scratchpad alongside the raw captures.

To redo a frame: capture the screen with
`adb exec-out screencap -p > raw/fN_name.png`, then rerun the script. It trims
the status and gesture bars, rounds the corners, adds the bezel and shadow,
and lays the caption over the app's own night ground.

The feature graphic's background art was generated (Recraft V4.1 via
Higgsfield, ~2.5 credits); the mark and type are composited from
`assets/brand/mark.png` and the app's bundled fonts.
