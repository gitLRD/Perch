#!/usr/bin/env python3
"""Perch's mascot: a plump little bird in side profile, perched on a branch,
peering DOWN at your work. Side profile (with a clear beak + tail + one eye)
reads unmistakably as a bird — and has no ear-tufts to mistake for horns.
Themed black / white / Claude-orange.
  assets/bird.gif       short one-shot motion (head bob + blink), transparent
  assets/bird-rest.png  the calm resting frame (shown when idle)
  assets/bird-1024.png  app icon (white bird on warm-ink card)
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


def draw_bird(size, look=0.6, blink=False, bob=0.0, body=PAPER, outline=INK):
    """Side-profile bird facing left. look/bob nudge the downward gaze + head."""
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ow = max(2, int(S * 0.014))

    # perch branch
    by = S * 0.86
    d.rounded_rectangle([S * 0.08, by, S * 0.92, by + S * 0.05], radius=S * 0.025,
                        fill=ORANGE_DEEP, outline=outline, width=ow)
    d.line([(S * 0.16, by + S * 0.05), (S * 0.10, by + S * 0.10)], fill=ORANGE_DEEP, width=ow)

    # tail sweeping up behind the body (right)
    d.polygon([(S * 0.70, S * 0.50), (S * 0.99, S * 0.36), (S * 0.88, S * 0.68)],
              fill=body, outline=outline)

    # feet
    for fx in (0.46, 0.60):
        x = S * fx
        d.line([(x, S * 0.80), (x, by)], fill=ORANGE_DEEP, width=int(S * 0.022))
        for dx in (-0.025, 0.025):
            d.line([(x, by), (x + dx * S, by + S * 0.03)], fill=ORANGE_DEEP, width=int(S * 0.018))

    # plump body facing left
    d.ellipse([S * 0.28, S * 0.40, S * 0.82, S * 0.84], body, outline=outline, width=ow)
    d.ellipse([S * 0.38, S * 0.54, S * 0.66, S * 0.82], BELLY if body == PAPER else body)  # belly

    # head (upper-left), tilted down when peering
    hy = S * (0.22 + bob * 0.02)
    head = [S * 0.14, hy, S * 0.52, hy + S * 0.40]
    d.ellipse(head, body, outline=outline, width=ow)
    hcx = (head[0] + head[2]) / 2
    hcy = (head[1] + head[3]) / 2

    # single rounded crest feather (never a horn)
    d.ellipse([hcx - S * 0.028, head[1] - S * 0.05, hcx + S * 0.028, head[1] + S * 0.02],
              body, outline=outline, width=int(S * 0.011))

    # beak pointing forward-left and slightly down (looking down)
    bx = head[0] + S * 0.015
    d.polygon([(bx, hcy - S * 0.005), (bx, hcy + S * 0.055), (bx - S * 0.13, hcy + S * 0.055)],
              fill=ORANGE, outline=outline)

    # wing on the body
    d.ellipse([S * 0.42, S * 0.50, S * 0.74, S * 0.80], body, outline=outline, width=ow)

    # one eye, pupil cast low = looking down
    ex, ey = hcx + S * 0.03, hcy - S * 0.01
    er = S * 0.08
    d.ellipse([ex - er, ey - er, ex + er, ey + er], WHITE, outline=outline, width=int(S * 0.012))
    if blink:
        d.line([(ex - er * 0.7, ey), (ex + er * 0.7, ey)], fill=outline, width=int(S * 0.02))
    else:
        pr = er * 0.55
        px = ex
        py = ey + (0.35 + look * 0.45) * er
        d.ellipse([px - pr, py - pr, px + pr, py + pr], PUPIL)
        d.ellipse([px - pr * 0.1, py - pr * 0.6, px + pr * 0.35, py], WHITE)

    return img.resize((size, size), Image.LANCZOS)


def make_rest():
    draw_bird(256, look=0.65).save(os.path.join(ASSETS, "bird-rest.png"))
    print("wrote assets/bird-rest.png")


def make_gif():
    seq = [
        (0.65, False, 0.0, 9),   # rest, looking down
        (0.85, False, 0.6, 4),   # peer lower (head bob)
        (0.65, False, 0.0, 5),   # back up
        (0.65, True,  0.0, 3),   # blink
        (0.65, False, 0.0, 9),   # rest
    ]
    frames, durations = [], []
    for look, blink, bob, hold in seq:
        frames.append(draw_bird(96, look=look, blink=blink, bob=bob))
        durations.append(hold * 26)
    frames[0].save(
        os.path.join(ASSETS, "bird.gif"),
        save_all=True, append_images=frames[1:], duration=durations,
        disposal=2, transparency=0, optimize=False,
    )
    print("wrote assets/bird.gif")


def make_icon_source():
    S = 1024
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([40, 40, S - 40, S - 40], radius=220, fill=(*INK, 255))
    d.rounded_rectangle([40, 40, S - 40, S - 40], radius=220, outline=(*ORANGE, 255), width=10)
    bird = draw_bird(780)
    img.alpha_composite(bird, (int((S - 780) / 2), int((S - 780) / 2) + 10))
    img.save(os.path.join(ASSETS, "bird-1024.png"))
    print("wrote assets/bird-1024.png")


if __name__ == "__main__":
    make_rest()
    make_gif()
    make_icon_source()
