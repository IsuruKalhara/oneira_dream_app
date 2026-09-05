"""Compose Google Play store assets from real device captures.

Screenshots are the actual app (Play policy requires that); this only frames
them: the brand night ground, a caption, and a slim device.
"""
import math, os, random
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SP = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(SP, "raw")
OUT = os.path.join(SP, "store")
FONTS = "/Users/piumal/Documents/1$/oneira_dream_app/dreamlore_app/assets/fonts"
BRAND = "/Users/piumal/Documents/1$/oneira_dream_app/dreamlore_app/assets/brand"
os.makedirs(OUT, exist_ok=True)

INK = (14, 14, 26)
INK_DEEP = (7, 7, 15)
PARCH = (233, 225, 208)
MUTED = (148, 144, 172)
INDIGO = (108, 92, 231)

W, H = 1080, 1920


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def night(w, h, seed=7, bloom=(0.5, 0.28), bloom_strength=0.5):
    """The app's own ground: ink, an indigo bloom, and a few stars."""
    img = Image.new("RGB", (w, h), INK)
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / h
        d.line([(0, y), (w, y)], fill=(
            int(INK[0] + (INK_DEEP[0] - INK[0]) * t),
            int(INK[1] + (INK_DEEP[1] - INK[1]) * t),
            int(INK[2] + (INK_DEEP[2] - INK[2]) * t)))
    glow = Image.new("RGB", (w, h), (0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cx, cy = int(w * bloom[0]), int(h * bloom[1])
    r = int(max(w, h) * 0.55)
    gd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=INDIGO)
    glow = glow.filter(ImageFilter.GaussianBlur(r // 2))
    img = Image.blend(img, Image.blend(img, glow, 0.30), bloom_strength)
    d = ImageDraw.Draw(img)
    rnd = random.Random(seed)
    for _ in range(int(w * h / 26000)):
        x, y = rnd.randint(0, w), rnd.randint(0, h)
        s = rnd.choice([1, 1, 2])
        a = rnd.randint(70, 190)
        d.ellipse([x, y, x + s, y + s], fill=(a, a, int(a * 1.05)))
    return img


def rounded(im, radius):
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, im.size[0], im.size[1]],
                                           radius=radius, fill=255)
    out = im.convert("RGBA")
    out.putalpha(mask)
    return out


def device(shot_path, width):
    """The capture, status bar and gesture bar trimmed, as a slim device."""
    im = Image.open(shot_path).convert("RGB")
    im = im.crop((0, 74, im.width, im.height - 34))
    h = int(width * im.height / im.width)
    im = im.resize((width, h), Image.LANCZOS)
    r = int(width * 0.055)
    body = rounded(im, r)
    # A hairline bezel so the screen reads as a phone, not a pasted rectangle.
    frame = Image.new("RGBA", (width + 8, h + 8), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle(
        [0, 0, width + 7, h + 7], radius=r + 4,
        outline=(120, 116, 150, 200), width=3)
    frame.alpha_composite(body, (4, 4))
    return frame


def shadow_paste(canvas, layer, xy):
    sh = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sh.alpha_composite(Image.new("RGBA", layer.size, (0, 0, 0, 150)).convert("RGBA"), xy)
    a = layer.split()[3]
    tmp = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    tmp.paste((0, 0, 0, 160), xy, a)
    tmp = tmp.filter(ImageFilter.GaussianBlur(28))
    canvas.alpha_composite(tmp, (0, 18))
    canvas.alpha_composite(layer, xy)


def wrap(draw, text, f, max_w):
    words, lines, cur = text.split(), [], ""
    for wd in words:
        t = (cur + " " + wd).strip()
        if draw.textlength(t, font=f) <= max_w:
            cur = t
        else:
            lines.append(cur)
            cur = wd
    if cur:
        lines.append(cur)
    return lines


def frame(out_name, shot, caption, eyebrow=None, dev_w=700, seed=7):
    canvas = night(W, H, seed=seed).convert("RGBA")
    d = ImageDraw.Draw(canvas)

    f_cap = font("Newsreader.ttf", 76)
    f_eye = font("DMSans.ttf", 30)

    y = 96
    if eyebrow:
        tw = d.textlength(eyebrow, font=f_eye)
        d.text(((W - tw) / 2, y), eyebrow, font=f_eye, fill=INDIGO)
        y += 56

    lines = wrap(d, caption, f_cap, W - 150)
    for ln in lines:
        tw = d.textlength(ln, font=f_cap)
        d.text(((W - tw) / 2, y), ln, font=f_cap, fill=PARCH)
        y += 92

    dev = device(os.path.join(RAW, shot), dev_w)
    top = y + 60
    if top + dev.height > H - 40:
        # Never crop the phone: shrink to fit what's left.
        scale = (H - 40 - top) / dev.height
        dev = dev.resize((int(dev.width * scale), int(dev.height * scale)),
                         Image.LANCZOS)
    shadow_paste(canvas, dev, ((W - dev.width) // 2, top))
    canvas.convert("RGB").save(os.path.join(OUT, out_name), quality=95)
    print("wrote", out_name)


FRAMES = [
    ("01_speak.png", "f1_listening.png", "Speak it before it fades", "VOICE, ON WAKING", 690, 3),
    ("02_reading.png", "f2_quotes.png", "A reading that quotes real books", "GROUNDED, NOT GUESSED", 690, 11),
    ("03_painted.png", "f3_picture.png", "See your dream, painted", None, 800, 5),
    ("04_journal.png", "f4_journal.png", "A private dream diary", "STAYS ON YOUR PHONE", 690, 19),
    ("05_patterns.png", "f5_insights.png", "Watch the patterns surface", "NIGHT AFTER NIGHT", 690, 23),
    ("06_plus.png", "f6_paywall.png", "Plus, from $2.50 a month", "DREAMLORE PLUS", 690, 29),
    ("07_private.png", "f7_privacy.png", "No account. Nothing uploaded.", "PRIVATE BY DEFAULT", 690, 31),
]

for args in FRAMES:
    frame(*args)


# ── Feature graphic: 1024×500, the one banner Play requires ────────────────
def feature(bg_path=None):
    fw, fh = 1024, 500
    if bg_path and os.path.exists(bg_path):
        bg = Image.open(bg_path).convert("RGB")
        # cover-crop to 1024x500
        s = max(fw / bg.width, fh / bg.height)
        bg = bg.resize((int(bg.width * s), int(bg.height * s)), Image.LANCZOS)
        left = (bg.width - fw) // 2
        top = int((bg.height - fh) * 0.45)
        bg = bg.crop((left, top, left + fw, top + fh))
        # Darken so the type reads.
        bg = Image.blend(bg, Image.new("RGB", (fw, fh), INK), 0.42)
    else:
        bg = night(fw, fh, seed=13, bloom=(0.30, 0.35))
    canvas = bg.convert("RGBA")

    mark = Image.open(os.path.join(BRAND, "mark.png")).convert("RGBA")
    ms = 190
    mark = mark.resize((ms, ms), Image.LANCZOS)
    canvas.alpha_composite(mark, (96, (fh - ms) // 2 - 10))

    d = ImageDraw.Draw(canvas)
    f_name = font("Newsreader.ttf", 92)
    f_tag = font("DMSans.ttf", 34)
    x = 96 + ms + 44
    d.text((x, 168), "Dreamlore", font=f_name, fill=PARCH)
    d.text((x, 286), "Dream journal that quotes real books", font=f_tag,
           fill=(200, 195, 220))
    canvas.convert("RGB").save(os.path.join(OUT, "feature_graphic_1024x500.png"),
                               quality=95)
    print("wrote feature_graphic_1024x500.png")


feature(os.path.join(SP, "feature_bg.png"))

# ── Play store icon: 512×512, no alpha ────────────────────────────────────
icon = Image.new("RGB", (512, 512), INK)
g = night(512, 512, seed=2, bloom=(0.5, 0.35), bloom_strength=0.7)
icon.paste(g)
mark = Image.open(os.path.join(BRAND, "mark.png")).convert("RGBA")
mk = mark.resize((330, 330), Image.LANCZOS)
icon_rgba = icon.convert("RGBA")
icon_rgba.alpha_composite(mk, (91, 91))
icon_rgba.convert("RGB").save(os.path.join(OUT, "play_icon_512.png"))
print("wrote play_icon_512.png")
