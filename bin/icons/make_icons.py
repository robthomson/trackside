"""
Draw the Trackside tool icons (Ethos masks: black art on white, RGB).

Output: src/trackside/tool/gfx/*.png  (70x70 tiles, 32x32 nav)
Usage:  python bin/icons/make_icons.py
Requires: Pillow
"""

from pathlib import Path

from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "src" / "trackside" / "tool" / "gfx"
S = 4  # draw at 4x, then downsample for smooth edges


def canvas(size):
    img = Image.new("L", (size * S, size * S), 255)
    return img, ImageDraw.Draw(img)


def save(img, name, size):
    img.resize((size, size), Image.LANCZOS).convert("RGB").save(OUT / f"{name}.png")


def w(px):
    return int(px * S)


def box(x0, y0, x1, y1):
    return [w(x0), w(y0), w(x1), w(y1)]


def flag():
    img, d = canvas(70)
    d.line([w(14), w(10), w(14), w(62)], fill=0, width=w(4))
    cell = 9
    for r in range(4):
        for c in range(5):
            x, y = 16 + c * cell, 10 + r * cell
            if (r + c) % 2 == 0:
                d.rectangle(box(x, y, x + cell, y + cell), fill=0)
    d.rectangle(box(16, 10, 16 + 5 * cell, 10 + 4 * cell), outline=0, width=w(2))
    save(img, "icon", 70)


def check():
    img, d = canvas(70)
    d.ellipse(box(8, 8, 62, 62), outline=0, width=w(4))
    d.line([w(21), w(36), w(31), w(46), w(50), w(25)], fill=0, width=w(5), joint="curve")
    save(img, "check", 70)


def brake():
    img, d = canvas(70)
    d.ellipse(box(8, 8, 62, 62), outline=0, width=w(4))
    d.ellipse(box(26, 26, 44, 44), outline=0, width=w(3))
    for x, y in ((35, 15), (55, 35), (35, 55), (15, 35)):
        d.ellipse(box(x - 2.5, y - 2.5, x + 2.5, y + 2.5), fill=0)
    # caliper over the top right of the disc
    d.pieslice(box(2, 2, 68, 68), -80, -10, fill=0)
    d.pieslice(box(12, 12, 58, 58), -90, 0, fill=255)
    save(img, "brake", 70)


def wheel():
    img, d = canvas(70)
    d.ellipse(box(8, 8, 62, 62), outline=0, width=w(5))
    d.ellipse(box(28, 28, 42, 42), fill=0)
    d.line([w(10), w(36), w(28), w(35)], fill=0, width=w(5))
    d.line([w(42), w(35), w(60), w(36)], fill=0, width=w(5))
    d.line([w(35), w(42), w(35), w(60)], fill=0, width=w(5))
    save(img, "drive", 70)


def inputs():
    img, d = canvas(70)
    for x, knob in ((22, 26), (48, 46)):
        d.line([w(x), w(10), w(x), w(60)], fill=0, width=w(3))
        d.rounded_rectangle(box(x - 9, knob - 5, x + 9, knob + 5), radius=w(2), fill=0)
    save(img, "inputs", 70)


def laps():
    img, d = canvas(70)
    d.ellipse(box(12, 16, 58, 62), outline=0, width=w(4))
    d.rectangle(box(30, 6, 40, 11), fill=0)
    d.line([w(35), w(11), w(35), w(16)], fill=0, width=w(3))
    d.line([w(35), w(39), w(35), w(24)], fill=0, width=w(4))
    d.line([w(35), w(39), w(46), w(45)], fill=0, width=w(4))
    d.line([w(52), w(16), w(57), w(21)], fill=0, width=w(4))
    save(img, "laps", 70)


def battery():
    img, d = canvas(70)
    d.rounded_rectangle(box(8, 20, 56, 50), radius=w(4), outline=0, width=w(4))
    d.rectangle(box(56, 28, 63, 42), fill=0)
    for i in range(3):
        x = 14 + i * 13
        d.rectangle(box(x, 26, x + 9, 44), fill=0)
    save(img, "battery", 70)


def back():
    img, d = canvas(32)
    d.line([w(20), w(7), w(10), w(16), w(20), w(25)], fill=0, width=w(3.5), joint="curve")
    save(img, "back", 32)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for f in (flag, check, brake, wheel, inputs, laps, battery, back):
        f()
    print(f"Wrote icons to {OUT}")
