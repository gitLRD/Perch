#!/usr/bin/env python3
"""Generate Perch's mascot assets with Pillow — a warm-white bird looking DOWN
at your work, themed black / white / Claude-orange.
  assets/bird.gif          animated (looks down, scans, blinks), transparent
  assets/bird-1024.png     app icon (white bird on warm-ink card)
  assets/bird-menubar.png  monochrome template glyph for the menu bar
No external tools required.
"""
import os
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), "..")
ASSETS = os.path.join(ROOT, "assets")
os.makedirs(ASSETS, exist_ok=True)

SS = 8                          # supersample for smooth edges
INK    = (26, 22, 20)           # warm near-black (outline + icon bg)
PAPER  = (250, 249, 245)        # warm white body
BELLY  = (238, 236, 228)
ORANGE = (217, 119, 87)         # Claude orange #D97757
ORANGE_DEEP = (193, 95, 60)
WHITE  = (255, 255, 255)
PUPIL  = INK


def draw_bird(size, look=(0.0, 0.85), blink=False, body=PAPER, outline=INK):
    """One frame. `look` = pupil offset (-1..1, -1..1); +y looks DOWN."""
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = S / 2
    ow = int(S * 0.013)

    def ell(box, fill, oc=None, w=0):
        d.ellipse(box, fill=fill, outline=oc, width=w)

    # feet (orange)
    for fx in (-0.13, 0.13):
        x = cx + fx * S
        for dx in (-0.04, 0.0, 0.04):
            d.line([(x, S * 0.95), (x + dx * S, S * 0.995)], fill=ORANGE_DEEP, width=int(S * 0.02))
        d.line([(x, S * 0.86), (x, S * 0.95)], fill=ORANGE_DEEP, width=int(S * 0.022))

    # body + belly
    ell([S * 0.16, S * 0.34, S * 0.84, S * 0.90], body, outline, ow)
    ell([S * 0.30, S * 0.52, S * 0.70, S * 0.86], BELLY if body == PAPER else body)

    # little wing tucked in
    ell([S * 0.13, S * 0.50, S * 0.34, S * 0.74], body, outline, ow)

    # head
    ell([S * 0.24, S * 0.10, S * 0.76, S * 0.56], body, outline, ow)

    # head sprig (orange tip)
    d.line([(cx, S * 0.12), (cx - S * 0.015, S * 0.03)], fill=outline, width=int(S * 0.014))
    d.line([(cx, S * 0.12), (cx + S * 0.05, S * 0.045)], fill=outline, width=int(S * 0.014))
    ell([cx - S * 0.028, S * 0.012, cx + S * 0.012, S * 0.052], ORANGE)

    # eyes — placed a touch high on the head so downward pupils read clearly
    eye_r = S * 0.125
    eyc = S * 0.28
    for ex in (-0.14, 0.14):
        exc = cx + ex * S
        if blink:
            d.arc([exc - eye_r, eyc - eye_r, exc + eye_r, eyc + eye_r], 20, 160,
                  fill=outline, width=int(S * 0.02))
        else:
            ell([exc - eye_r, eyc - eye_r, exc + eye_r, eyc + eye_r], WHITE, outline, int(S * 0.011))
            pr = eye_r * 0.52
            px = exc + look[0] * eye_r * 0.40
            py = eyc + look[1] * eye_r * 0.44
            ell([px - pr, py - pr, px + pr, py + pr], PUPIL)
            ell([px - pr * 0.15, py - pr * 0.55, px + pr * 0.3, py + pr * 0.05], WHITE)  # catchlight
        # brow (adds the intent look)
        d.line([(exc - eye_r * 0.95, eyc - eye_r * 1.25), (exc + eye_r * 0.7, eyc - eye_r * 1.02)],
               fill=outline, width=int(S * 0.016))

    # beak (orange), pointing slightly down
    d.polygon([(cx - S * 0.045, S * 0.42), (cx + S * 0.045, S * 0.42), (cx, S * 0.50)],
              fill=ORANGE, outline=outline)

    # rosy orange cheeks
    for ex in (-0.205, 0.205):
        exc = cx + ex * S
        ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(ov).ellipse([exc - S * 0.05, S * 0.36, exc + S * 0.05, S * 0.43],
                                   fill=(*ORANGE, 90))
        img = Image.alpha_composite(img, ov)

    return img.resize((size, size), Image.LANCZOS)


def make_gif():
    # resting gaze is DOWN; it scans a little, then blinks
    seq = [
        (( 0.0, 0.90), False, 7),
        ((-0.6, 0.95), False, 5),
        (( 0.6, 0.95), False, 5),
        (( 0.0, 0.90), False, 6),
        (( 0.0, 0.90), True,  3),
        (( 0.0, 0.90), False, 6),
    ]
    frames, durations = [], []
    for look, blink, hold in seq:
        frames.append(draw_bird(96, look=look, blink=blink))
        durations.append(hold * 24)
    frames[0].save(
        os.path.join(ASSETS, "bird.gif"),
        save_all=True, append_images=frames[1:], duration=durations,
        loop=0, disposal=2, transparency=0, optimize=False,
    )
    print("wrote assets/bird.gif")


def make_icon_source():
    S = 1024
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([40, 40, S - 40, S - 40], radius=220, fill=(*INK, 255))       # warm-ink card
    d.rounded_rectangle([40, 40, S - 40, S - 40], radius=220, outline=(*ORANGE, 255), width=10)
    bird = draw_bird(720, look=(0.12, 0.9))
    img.alpha_composite(bird, (int((S - 720) / 2), int((S - 720) / 2) + 24))
    img.save(os.path.join(ASSETS, "bird-1024.png"))
    print("wrote assets/bird-1024.png")


def make_menubar():
    # monochrome template: black silhouette + alpha (macOS tints it), looking down
    S = 36 * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    black = (0, 0, 0, 255)
    d.ellipse([S * 0.20, S * 0.34, S * 0.80, S * 0.92], fill=black)   # body
    d.ellipse([S * 0.26, S * 0.10, S * 0.74, S * 0.56], fill=black)   # head
    # eye knockouts sitting low (downward gaze)
    for ex in (0.40, 0.54):
        d.ellipse([S * ex, S * 0.36, S * (ex + 0.09), S * 0.47], fill=(0, 0, 0, 0))
    img = img.resize((36, 36), Image.LANCZOS)
    img.save(os.path.join(ASSETS, "bird-menubar.png"))
    print("wrote assets/bird-menubar.png")


if __name__ == "__main__":
    make_gif()
    make_icon_source()
    make_menubar()
