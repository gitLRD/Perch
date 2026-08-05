#!/usr/bin/env python3
"""Generate Perch's comical bird assets with Pillow:
  assets/bird.gif          animated, looping, transparent (panel header + empty state)
  assets/bird-1024.png     one big frame for the app icon
  assets/bird-menubar.png  small black+alpha template glyph for the menu bar
No external tools required.
"""
import os
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), "..")
ASSETS = os.path.join(ROOT, "assets")
os.makedirs(ASSETS, exist_ok=True)

SS = 8                      # supersample factor for smooth edges
BODY = (245, 200, 66)      # warm chick yellow
BELLY = (252, 224, 130)
BEAK = (240, 140, 40)
FEET = (232, 120, 30)
OUTLINE = (60, 45, 20)
WHITE = (255, 255, 255)
PUPIL = (40, 30, 25)


def draw_bird(size, look=(0.0, 0.0), blink=False, transparent=True):
    """Draw one bird frame. `look` is pupil offset (-1..1, -1..1)."""
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0) if transparent else (255, 255, 255, 255))
    d = ImageDraw.Draw(img)
    cx = S / 2

    def ell(box, fill, outline=None, w=0):
        d.ellipse(box, fill=fill, outline=outline, width=w)

    # feet
    for fx in (-0.13, 0.13):
        x = cx + fx * S
        d.line([(x, S * 0.86), (x, S * 0.95)], fill=FEET, width=int(S * 0.02))
        d.line([(x, S * 0.95), (x - S * 0.04, S * 0.99)], fill=FEET, width=int(S * 0.02))
        d.line([(x, S * 0.95), (x + S * 0.04, S * 0.99)], fill=FEET, width=int(S * 0.02))
        d.line([(x, S * 0.95), (x, S * 0.995)], fill=FEET, width=int(S * 0.02))

    # body (fat egg) + belly
    ell([S * 0.16, S * 0.34, S * 0.84, S * 0.90], BODY, OUTLINE, int(S * 0.012))
    ell([S * 0.30, S * 0.52, S * 0.70, S * 0.86], BELLY)

    # little wing
    ell([S * 0.13, S * 0.50, S * 0.34, S * 0.74], BODY, OUTLINE, int(S * 0.012))

    # head
    ell([S * 0.24, S * 0.10, S * 0.76, S * 0.56], BODY, OUTLINE, int(S * 0.012))

    # head tuft (comedy sprig)
    d.line([(cx, S * 0.12), (cx - S * 0.02, S * 0.03)], fill=OUTLINE, width=int(S * 0.014))
    d.line([(cx, S * 0.12), (cx + S * 0.05, S * 0.045)], fill=OUTLINE, width=int(S * 0.014))
    ell([cx - S * 0.03, S * 0.015, cx + S * 0.01, S * 0.055], BEAK)

    # eyes
    eye_r = S * 0.115
    for ex in (-0.135, 0.135):
        exc = cx + ex * S
        eyc = S * 0.30
        if blink:
            d.arc([exc - eye_r, eyc - eye_r, exc + eye_r, eyc + eye_r], 200, 340,
                  fill=OUTLINE, width=int(S * 0.018))
        else:
            ell([exc - eye_r, eyc - eye_r, exc + eye_r, eyc + eye_r], WHITE, OUTLINE, int(S * 0.01))
            pr = eye_r * 0.5
            px = exc + look[0] * eye_r * 0.42
            py = eyc + look[1] * eye_r * 0.42
            ell([px - pr, py - pr, px + pr, py + pr], PUPIL)
            # catchlight
            ell([px - pr * 0.2, py - pr * 0.5, px + pr * 0.25, py], WHITE)
        # eyebrow (comedy)
        d.line([(exc - eye_r, eyc - eye_r * 1.35), (exc + eye_r * 0.6, eyc - eye_r * 1.15)],
               fill=OUTLINE, width=int(S * 0.016))

    # beak (open, cheeky)
    d.polygon([(cx - S * 0.05, S * 0.40), (cx + S * 0.05, S * 0.40), (cx, S * 0.47)],
              fill=BEAK, outline=OUTLINE)

    # rosy cheeks
    for ex in (-0.20, 0.20):
        exc = cx + ex * S
        ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
        od = ImageDraw.Draw(ov)
        od.ellipse([exc - S * 0.05, S * 0.37, exc + S * 0.05, S * 0.44], fill=(255, 150, 120, 110))
        img = Image.alpha_composite(img, ov)

    return img.resize((size, size), Image.LANCZOS)


def make_gif():
    # a looking sequence + a blink
    seq = [
        (( 0.0,  0.0), False, 6),
        ((-1.0,  0.0), False, 5),
        ((-1.0, -0.6), False, 4),
        (( 1.0, -0.3), False, 5),
        (( 1.0,  0.4), False, 4),
        (( 0.0,  0.0), False, 5),
        (( 0.0,  0.0), True,  3),
        (( 0.0,  0.0), False, 5),
    ]
    frames, durations = [], []
    for look, blink, hold in seq:
        f = draw_bird(96, look=look, blink=blink)
        # flatten onto transparent palette-friendly frame
        frames.append(f)
        durations.append(hold * 22)
    frames[0].save(
        os.path.join(ASSETS, "bird.gif"),
        save_all=True, append_images=frames[1:], duration=durations,
        loop=0, disposal=2, transparency=0, optimize=False,
    )
    print("wrote assets/bird.gif")


def make_icon_source():
    # app icon: bird on a soft rounded background for legibility in the Dock
    S = 1024
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([40, 40, S - 40, S - 40], radius=220, fill=(120, 190, 235, 255))
    bird = draw_bird(720, look=(0.3, -0.2))
    img.alpha_composite(bird, (int((S - 720) / 2), int((S - 720) / 2) + 30))
    img.save(os.path.join(ASSETS, "bird-1024.png"))
    print("wrote assets/bird-1024.png")


def make_menubar():
    # template image: black silhouette + alpha, ~36px (18pt @2x)
    S = 36 * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    black = (0, 0, 0, 255)
    d.ellipse([S * 0.20, S * 0.34, S * 0.80, S * 0.92], fill=black)   # body
    d.ellipse([S * 0.26, S * 0.10, S * 0.74, S * 0.56], fill=black)   # head
    d.polygon([(S * 0.48, S * 0.30), (S * 0.60, S * 0.30), (S * 0.54, S * 0.40)], fill=black)  # tuft base
    # eye knockout
    d.ellipse([S * 0.40, S * 0.24, S * 0.52, S * 0.36], fill=(0, 0, 0, 0))
    img = img.resize((36, 36), Image.LANCZOS)
    img.save(os.path.join(ASSETS, "bird-menubar.png"))
    print("wrote assets/bird-menubar.png")


if __name__ == "__main__":
    make_gif()
    make_icon_source()
    make_menubar()
