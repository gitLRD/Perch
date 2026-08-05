#!/usr/bin/env python3
"""Perch's mascot: a little owl-ish bird perched on a branch, looking DOWN at
your work. Themed black / white / Claude-orange. Ear tufts + a real beak + a
perch branch make it read as a bird even at menu-bar size.
  assets/bird.gif          short one-shot motion (blink + tilt), transparent
  assets/bird-rest.png     the calm resting frame (shown when idle)
  assets/bird-1024.png     app icon (white owl on warm-ink card)
  assets/bird-menubar.png  monochrome template glyph
No external tools required.
"""
import os
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), "..")
ASSETS = os.path.join(ROOT, "assets")
os.makedirs(ASSETS, exist_ok=True)

SS = 8
INK    = (26, 22, 20)
PAPER  = (250, 249, 245)
BELLY  = (236, 234, 226)
ORANGE = (217, 119, 87)
ORANGE_DEEP = (176, 84, 52)
WHITE  = (255, 255, 255)
PUPIL  = INK


def draw_owl(size, look=(0.0, 0.7), blink=False, tilt=0.0, body=PAPER, outline=INK):
    """One frame of the owl. look = pupil offset (+y = down). tilt = head lean."""
    S = size * SS
    big = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    cx = S / 2
    ow = max(2, int(S * 0.014))

    # perch branch
    by = S * 0.90
    d.rounded_rectangle([S * 0.12, by, S * 0.88, by + S * 0.05], radius=S * 0.025,
                        fill=ORANGE_DEEP, outline=outline, width=ow)
    d.line([(S * 0.20, by + S * 0.05), (S * 0.14, by + S * 0.10)], fill=ORANGE_DEEP, width=ow)

    # feet gripping the branch
    for fx in (-0.11, 0.11):
        x = cx + fx * S
        for dx in (-0.03, 0.03):
            d.line([(x, by - S * 0.01), (x + dx * S, by + S * 0.035)], fill=ORANGE_DEEP, width=int(S * 0.02))

    # ear tufts (say "bird" instantly)
    for ex, sign in ((-0.24, -1), (0.24, 1)):
        tx = cx + ex * S
        d.polygon([(tx, S * 0.30), (tx + sign * S * 0.10, S * 0.05), (tx + sign * S * 0.16, S * 0.26)],
                  fill=body, outline=outline)

    # body/head (one owl egg)
    d.ellipse([S * 0.14, S * 0.16, S * 0.86, S * 0.92], body, outline=outline, width=ow)
    # belly
    d.ellipse([S * 0.34, S * 0.52, S * 0.66, S * 0.88], BELLY if body == PAPER else body)

    # wings
    d.pieslice([S * 0.10, S * 0.34, S * 0.42, S * 0.86], 70, 210, fill=body, outline=outline, width=ow)
    d.pieslice([S * 0.58, S * 0.34, S * 0.90, S * 0.86], 330, 110, fill=body, outline=outline, width=ow)

    # eyes — big owl discs, close together, pupils cast down
    eye_r = S * 0.155
    eyc = S * 0.42 + tilt * S * 0.02
    for ex in (-0.155, 0.155):
        exc = cx + ex * S
        # eye disc ring
        d.ellipse([exc - eye_r, eyc - eye_r, exc + eye_r, eyc + eye_r], WHITE, outline=outline, width=int(S * 0.012))
        if blink:
            d.line([(exc - eye_r * 0.7, eyc), (exc + eye_r * 0.7, eyc)], fill=outline, width=int(S * 0.02))
        else:
            pr = eye_r * 0.62
            px = exc + look[0] * eye_r * 0.34
            py = eyc + look[1] * eye_r * 0.40
            d.ellipse([px - pr, py - pr, px + pr, py + pr], PUPIL)
            d.ellipse([px - pr * 0.1, py - pr * 0.6, px + pr * 0.35, py], WHITE)  # catchlight

    # beak — prominent orange downward triangle between the eyes
    d.polygon([(cx - S * 0.06, eyc + eye_r * 0.55), (cx + S * 0.06, eyc + eye_r * 0.55),
               (cx, eyc + eye_r * 1.35)], fill=ORANGE, outline=outline)

    return big.resize((size, size), Image.LANCZOS)


def make_rest():
    draw_owl(256, look=(0.0, 0.72)).save(os.path.join(ASSETS, "bird-rest.png"))
    print("wrote assets/bird-rest.png")


def make_gif():
    # brief, one-shot-friendly: rest -> tilt/glance -> blink -> rest
    seq = [
        ((0.0, 0.72), False, 0.0, 8),
        ((-0.5, 0.8), False, -0.5, 4),
        ((0.4, 0.8),  False, 0.4, 4),
        ((0.0, 0.72), True,  0.0, 3),
        ((0.0, 0.72), False, 0.0, 8),
    ]
    frames, durations = [], []
    for look, blink, tilt, hold in seq:
        frames.append(draw_owl(96, look=look, blink=blink, tilt=tilt))
        durations.append(hold * 26)
    frames[0].save(
        os.path.join(ASSETS, "bird.gif"),
        save_all=True, append_images=frames[1:], duration=durations,
        disposal=2, transparency=0, optimize=False,   # no loop extension -> plays through
    )
    print("wrote assets/bird.gif")


def make_icon_source():
    S = 1024
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([40, 40, S - 40, S - 40], radius=220, fill=(*INK, 255))
    d.rounded_rectangle([40, 40, S - 40, S - 40], radius=220, outline=(*ORANGE, 255), width=10)
    owl = draw_owl(760, look=(0.05, 0.72))
    img.alpha_composite(owl, (int((S - 760) / 2), int((S - 760) / 2) + 20))
    img.save(os.path.join(ASSETS, "bird-1024.png"))
    print("wrote assets/bird-1024.png")


def make_menubar():
    S = 36 * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    black = (0, 0, 0, 255)
    cx = S / 2
    # ear tufts
    for ex, sign in ((-0.22, -1), (0.22, 1)):
        tx = cx + ex * S
        d.polygon([(tx, S * 0.34), (tx + sign * S * 0.09, S * 0.10), (tx + sign * S * 0.15, S * 0.30)], fill=black)
    d.ellipse([S * 0.18, S * 0.24, S * 0.82, S * 0.92], fill=black)   # body/head
    for ex in (0.34, 0.52):                                          # eye knockouts (low = looking down)
        d.ellipse([S * ex, S * 0.46, S * (ex + 0.14), S * 0.66], fill=(0, 0, 0, 0))
    img = img.resize((36, 36), Image.LANCZOS)
    img.save(os.path.join(ASSETS, "bird-menubar.png"))
    print("wrote assets/bird-menubar.png")


if __name__ == "__main__":
    make_rest()
    make_gif()
    make_icon_source()
    make_menubar()
