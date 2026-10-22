"""Contact sheet of every hand-held prop in art_props.py -> out/previews/props_sheet.png"""
import os, sys, math
import numpy as np, skia
sys.path.insert(0, os.path.dirname(__file__))
import art
import art_props as P
from art import W, H, INK, WHITE, G3, G4, G5, G6, fill, stroke, text
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "out", "previews")
os.makedirs(OUT, exist_ok=True)

TOP = 96
COLS, ROWS = 3, 6
CW, CH = W / COLS, (H - TOP) / ROWS
T = 0.6   # frame time used for the sheet


def cell(col, row, span=1):
    x0, y0 = col * CW, TOP + row * CH
    return x0, y0, x0 + CW * span, y0 + CH


def label(c, col, row, s, span=1):
    x0, y0, x1, y1 = cell(col, row, span)
    text(c, s, (x0 + x1) / 2, y1 - 14, 21, "monob", INK)


def grip_mark(c, x, y):
    c.drawCircle(x, y, 7, fill(WHITE)); c.drawCircle(x, y, 7, stroke(INK, 2.5))
    c.drawLine(x - 12, y, x + 12, y, stroke(INK, 1.5)); c.drawLine(x, y - 12, x, y + 12, stroke(INK, 1.5))


def glove_at(c, gx, gy, ang, size=0.9, flip=1):
    """Fist glove whose palm centre lands on (gx, gy)."""
    a = math.radians(ang)
    art.draw_glove(c, gx - math.cos(a) * 11 * size, gy - math.sin(a) * 11 * size, ang, "fist", size, flip=flip)


def fine_print(c):
    """World-space content that the magnifier enlarges."""
    x0, y0 = 760, 1325
    c.drawRect(skia.Rect.MakeLTRB(x0 - 10, y0 - 22, x0 + 300, y0 + 80), fill("#f6f5f0"))
    c.drawRect(skia.Rect.MakeLTRB(x0 - 10, y0 - 22, x0 + 300, y0 + 80), stroke(INK, 3))
    text(c, "*PRICES SUBJECT TO", x0, y0, 17, "monob", INK, align="left")
    text(c, " MARKUP. REFILLS", x0, y0 + 22, 17, "monob", INK, align="left")
    text(c, " COST US $0.04", x0, y0 + 44, 17, "monob", art.MONEY_D, align="left")
    text(c, " (DON'T TELL)", x0, y0 + 66, 17, "monob", INK, align="left")


arr = np.zeros((H, W, 4), np.uint8)
surf = skia.Surface(arr)
c = surf.getCanvas()
c.drawRect(skia.Rect.MakeWH(W, H), fill("#d8d8d3"))
for xx in range(0, W, 30):
    c.drawLine(xx, 0, xx, H, stroke("#cfcfca", 1.5))
for yy in range(0, H, 30):
    c.drawLine(0, yy, W, yy, stroke("#cfcfca", 1.5))
text(c, "MISTER MARKUP  -  PROP SHEET", W / 2, 66, 50, "deco", INK)
for r in range(ROWS):
    for col in range(COLS):
        if r == 5 and col == 2:
            continue
        span = 2 if (r == 5 and col == 1) else 1
        x0, y0, x1, y1 = cell(col, r, span)
        rr = skia.Rect.MakeLTRB(x0 + 8, y0 + 6, x1 - 8, y1 - 6)
        c.drawRoundRect(rr, 14, 14, fill("#e9e9e5")); c.drawRoundRect(rr, 14, 14, stroke(G4, 2.5))


def cc(col, row, span=1):
    x0, y0, x1, y1 = cell(col, row, span)
    return (x0 + x1) / 2, (y0 + y1) / 2 - 12


# ---- row 0: phone (glow, held), switches, stamp
x, y = cc(0, 0)
glove_at(c, x - 4, y + 40, -100, 0.95)
P.draw_phone(c, x, y + 44, 0.95, ang=-6, t=T, glow=1.0, badge=3)
label(c, 0, 0, "draw_phone glow=1")

x, y = cc(1, 0)
P.draw_light_switch(c, x - 70, y, 0.9, on=False, t=T)
P.draw_light_switch(c, x + 70, y, 0.9, on=True, t=T, click=0.35)
label(c, 1, 0, "light_switch off / on")

x, y = cc(2, 0)
P.draw_rubber_stamp(c, x, y - 70, 0.95, ang=8, t=T, inked=True)
glove_at(c, x, y - 70, 100, 0.95)
label(c, 2, 0, "rubber_stamp inked")

# ---- row 1: journal, report, register
x, y = cc(0, 1)
P.draw_journal(c, x - 92, y + 30, 0.85, ang=-6, t=T)
grip_mark(c, x - 92, y + 30)
label(c, 0, 1, "draw_journal")

x, y = cc(1, 1)
P.draw_report(c, x - 84, y + 4, 0.75, ang=4, t=T, figure="$4.8B")
grip_mark(c, x - 84, y + 4)
label(c, 1, 1, "draw_report")

x, y = cc(2, 1)
P.draw_register(c, x - 8, y + 92, 0.5, t=T, drawer=0.7, display="$0.80")
grip_mark(c, x - 8, y + 92)
label(c, 2, 1, "register drawer=.7")

# ---- row 2: pitcher, syrup, ice
x, y = cc(0, 2)
P.draw_pitcher(c, x + 80, y - 30, 0.6, ang=-35, t=T, fill=0.8, ice=2, pour_len=190)
glove_at(c, x + 80, y - 30, 160, 0.8, flip=-1)
label(c, 0, 2, "pitcher ang=-35")

x, y = cc(1, 2)
P.draw_syrup_bottle(c, x, y + 20, 1.0, ang=-8, t=T)
grip_mark(c, x, y + 20)
label(c, 1, 2, "draw_syrup_bottle")

x, y = cc(2, 2)
P.draw_ice_cube(c, x - 60, y + 10, 1.1, ang=-8, t=T)
P.draw_ice_cube(c, x + 50, y - 20, 0.8, ang=14, t=T + 0.4, phase=1.3)
P.draw_ice_cube(c, x + 40, y + 60, 0.7, ang=-24, t=T + 0.8, phase=2.1)
label(c, 2, 2, "draw_ice_cube")

# ---- row 3: ticket, keycard, clock
x, y = cc(0, 3)
P.draw_ticket(c, x - 120, y + 10, 0.88, ang=-8, t=T)
glove_at(c, x - 120, y + 10, 172, 0.85, flip=-1)
label(c, 0, 3, "draw_ticket")

x, y = cc(1, 3)
P.draw_keycard(c, x - 90, y, 1.0, ang=6, t=T)
grip_mark(c, x - 90, y)
label(c, 1, 3, "draw_keycard")

x, y = cc(2, 3)
P.draw_clock(c, x, y, 1.0, t=T * 20, hour=3, minute=0)
label(c, 2, 3, "draw_clock 3:00")

# ---- row 4: comment bubble, vacuum, hook   (magnifier lives in the last row)
x, y = cc(0, 4)
P.draw_comment_bubble(c, x, y - 6, 1.0, t=T, count="12K")
label(c, 0, 4, "comment_bubble")

x, y = cc(1, 4)
P.draw_vacuum_nozzle(c, x - 20, y + 20, 0.62, ang=0, t=T, hose_to=(x + 130, y - 120), suck=1.0, reach=160, debris="bills")
label(c, 1, 4, "vacuum suck=1")

x, y = cc(2, 4)
P.draw_hook(c, x + 10, y - 60, 1.0, t=T, line_to=(x + 10, cell(2, 4)[1] + 10))
label(c, 2, 4, "draw_hook")

# ---- row 5: magnifier over fine print, tub x-ray (2 cols)
x, y = cc(0, 5)
mx, my = x + 78, y + 96
lcx, lcy, lr = P.magnifier_lens_center(mx, my, 0.72, -34, 82)
FOCUS = (866, 1363)                                  # the "$0.04" in fine_print's own coords
ox, oy = lcx - 12 - FOCUS[0], lcy + 6 - FOCUS[1]
fine_print_local = lambda cv: (cv.save(), cv.translate(ox, oy), fine_print(cv), cv.restore())
fine_print_local(c)
P.draw_magnifier(c, mx, my, 0.72, ang=-34, t=T, lens_r=82, content=fine_print_local, zoom=1.8)
glove_at(c, mx, my, 56, 0.75)
label(c, 0, 5, "magnifier zoom=1.8")

x, y = cc(1, 5, 2)
P.draw_tub_xray(c, x + 10, y + 112, 0.62, t=T, reveal=1.0, costs=("$0.04", "$0.02", "$0.10"))
art.draw_popcorn(c, x + 290, y + 112, 0.3, label=False, seed=3)
label(c, 1, 5, "draw_tub_xray reveal=1  (+ draw_popcorn ref)", span=2)

Image.fromarray(arr[..., :3]).save(os.path.join(OUT, "props_sheet.png"))
print("saved", os.path.abspath(os.path.join(OUT, "props_sheet.png")))
