"""Render still previews of characters/props/backgrounds for QA."""
import os, sys, numpy as np, skia
sys.path.insert(0, os.path.dirname(__file__))
import art
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "out", "previews")
os.makedirs(OUT, exist_ok=True)


def surf():
    arr = np.zeros((art.H, art.W, 4), np.uint8)
    return arr, skia.Surface(arr)


def save(arr, name):
    Image.fromarray(arr[..., :3]).save(os.path.join(OUT, name))


# 1. lineup on stage
arr, s = surf(); c = s.getCanvas()
art.bg_stage(c)
art.draw_markup(c, 540, 1560, 1.0, {"arms": "present", "mouth": "grin", "expr": "sly"}, t=0.3, price="$9.00")
art.draw_footnote(c, 170, 1600, 0.9, t=0.2)
art.draw_wally(c, 900, 1600, 0.9, thick=1.0)
save(arr, "01_lineup.png")

# 2. pose sheet
arr, s = surf(); c = s.getCanvas()
art.bg_grid(c)
poses = [("hips", "grin", "proud", "up"), ("whisper", "O", "whisper", "up"), ("wide", "outrage", "outrage", "knot"),
         ("shrug", "guilty", "guilty", "down"), ("point", "A", "sly", "up"), ("think", "closed", "sly", "up")]
for i, (a, m, e, st) in enumerate(poses):
    x = 200 + (i % 3) * 340
    y = 900 + (i // 3) * 900
    art.draw_markup(c, x, y, 0.62, {"arms": a, "mouth": m, "expr": e, "string": st}, t=i, price="$9" if i == 0 else None)
save(arr, "02_poses.png")

# 3. counter scene with props
arr, s = surf(); c = s.getCanvas()
art.bg_counter(c)
art.draw_markup(c, 330, 1560, 1.0, {"arms": "point", "mouth": "E", "expr": "sly"}, t=1.0)
art.draw_popcorn(c, 780, 1215, 1.05, price="$9.00", face=True)
art.draw_receipt(c, 50, 160, [("TICKET -> STUDIO", "~50%+"), ("CORN+OIL+SALT", "PENNIES"), ("BUCKET", "$0.2")], 3)
art.draw_caption(c, [("THEY", False), ("CHARGE", False), ("YOU", False), ("$9", True)], 540, 1330)
save(arr, "03_counter.png")

# 4. vault scene
arr, s = surf(); c = s.getCanvas()
art.bg_vault(c)
art.draw_pipe(c)
for k in range(6):
    art.draw_bill(c, 230 + k * 80, 500 + (k % 2) * 30, 0.7, ang=k * 20)
art.draw_wally(c, 240, 1620, 0.8, thick=0.7, walk=0.3)
art.draw_footnote(c, 880, 1640, 0.8, mouth="open")
art.draw_card(c, 540, 1300, ["*Source: AMC 10-K (2025)", "film rent ~ half of tickets"], w=820, size=36)
save(arr, "04_vault.png")

# 5. soda cutaway + decoy grid + stamp
arr, s = surf(); c = s.getCanvas()
art.bg_grid(c, "THE DECOY")
for i, (sc, p) in enumerate(((0.62, "$6.50"), (0.8, "$8.75"), (0.98, "$9.25"))):
    art.draw_popcorn(c, 210 + i * 330, 1400, sc, price=p, label=False, seed=i + 2)
art.draw_soda(c, 900, 1000, 0.7, cutaway=1.0)
art.draw_stamp(c, 540, 820, "STEEP", 1.0, sub="BUT IT KEEPS THE LIGHTS ON")
save(arr, "05_decoy_stamp.png")

# 6. boardroom
arr, s = surf(); c = s.getCanvas()
art.bg_boardroom(c)
for i, x in enumerate((260, 540, 820)):
    art.draw_fat_cat(c, x, 1400, 1.0, puff=0.3 * i)
save(arr, "06_boardroom.png")
print("ok", os.listdir(OUT))
