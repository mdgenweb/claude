import os, sys, numpy as np, skia
sys.path.insert(0, os.path.dirname(__file__))
import art
from art import W, H, INK, WHITE, MONEY, fill, stroke, text
from PIL import Image
arr = np.zeros((H, W, 4), np.uint8); s = skia.Surface(arr); c = s.getCanvas()
art.bg_counter(c, "back")
art.draw_markup(c, 330, 1800, 1.15, {"arms": "wide", "expr": "outrage", "mouth": "outrage"}, t=0.4, price="$9.00")
art.bg_counter(c, "front")
art.draw_popcorn(c, 800, 1205, 1.15, face=True, price="$9.00", tag_side=-1)
c.drawRoundRect(skia.Rect.MakeLTRB(60, 120, 1020, 560), 30, 30, fill(INK, 252)); c.drawRoundRect(skia.Rect.MakeLTRB(60, 120, 1020, 560), 30, 30, stroke(WHITE, 8))
text(c, "WHY POPCORN", W / 2, 270, 118, "bungee", WHITE)
text(c, "COSTS", W / 2, 400, 118, "bungee", WHITE)
text(c, "$9", W / 2, 530, 140, "bungee", MONEY)
c.drawRect(skia.Rect.MakeWH(W, H), art.vignette_paint())
Image.fromarray(arr[..., :3]).save(os.path.join(os.path.dirname(__file__), "..", "out", "cover.png"))
print("cover ok")
