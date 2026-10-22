"""Contact sheet for fx2 effects: each effect frozen at an interesting moment, shown in-frame
(each panel is a crop of the 1080x1920 screen). Saves out/previews/fx2_sheet.png."""
import os, sys, math
import numpy as np, skia
sys.path.insert(0, os.path.dirname(__file__))
import art, fx, fx2
from art import W, H, INK, WHITE, PAPER, G1, G2, G3, G4, G5, G6, MONEY, MONEY_D, fill, stroke, inked, text, hexc
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "out", "previews")
os.makedirs(OUT, exist_ok=True)

arr = np.zeros((H, W, 4), np.uint8)
surf = skia.Surface(arr)
c = surf.getCanvas()

# ---- sheet background: grey gradient + faint dot screen
g = skia.GradientShader.MakeLinear([skia.Point(0, 0), skia.Point(0, H)], [hexc("#d8d8d3"), hexc("#8e8e89")])
c.drawRect(skia.Rect.MakeWH(W, H), skia.Paint(AntiAlias=True, Shader=g))
for yy in range(0, H, 24):
    for xx in range((yy // 24) % 2 * 12, W, 24):
        c.drawCircle(xx, yy, 1.6, fill("#000000", 22))
text(c, "FX2", 64, 112, 96, "bungee", WHITE, outline=INK, ow=14, align="left")
text(c, "CARTOON VFX SHEET", 300, 86, 50, "deco", INK, align="left")
text(c, "13 stateless effects  ·  frozen at t0 + dt", 302, 124, 26, "monob", G1, align="left")

COLS, ROWS = 3, 5
CW, CH = 332, 316
GX = (W - COLS * CW) / (COLS + 1)
Y0, PY = 160, 350


def cell_rect(i):
    col, row = i % COLS, i // COLS
    x = GX + col * (CW + GX)
    y = Y0 + row * PY
    return skia.Rect.MakeXYWH(x, y, CW, CH)


def panel(i, label, draw, view=(540, 960, 1080), bg=None):
    r = cell_rect(i)
    rr = skia.RRect.MakeRectXY(r, 18, 18)
    # card drop shadow
    c.drawRRect(skia.RRect.MakeRectXY(r.makeOffset(8, 10), 18, 18), fill("#000000", 110))
    c.save(); c.clipRRect(rr, doAntiAlias=True)
    c.drawRect(r, fill(G3))
    cx, cy, vw = view
    s = r.width() / vw
    vh = r.height() / s
    c.translate(r.left(), r.top()); c.scale(s, s); c.translate(-(cx - vw / 2), -(cy - vh / 2))
    if bg:
        bg(c)
    draw(c)
    c.restore()
    c.drawRRect(rr, stroke(INK, 7))
    # label tag
    tw = art.text_width(label, 21, "monob") + 26
    tag = skia.Rect.MakeXYWH(r.left() + 12, r.bottom() - 44, tw, 32)
    c.drawRoundRect(tag.makeOffset(3, 4), 9, 9, fill(INK))
    c.drawRoundRect(tag, 9, 9, fill(WHITE)); c.drawRoundRect(tag, 9, 9, stroke(INK, 3.5))
    text(c, label, tag.left() + 13, tag.bottom() - 9, 21, "monob", INK, align="left")
    text(c, f"{i + 1:02d}", r.right() - 16, r.top() + 40, 30, "bungee", WHITE, outline=INK, ow=7, align="right")


def ball(cv, x, y, extra=None, r=70, col=G1):
    cv.drawCircle(x, y, r, fill(col)); cv.drawCircle(x, y, r, stroke(INK, 7))
    cv.drawCircle(x - r * 0.35, y - r * 0.38, r * 0.2, fill(WHITE))
    cv.drawCircle(x - r * 0.1, y - r * 0.5, r * 0.08, fill(WHITE))


# 01 action_word mid-pop (overshoot)
panel(0, "action_word +0.12s",
      lambda cv: fx2.action_word(cv, 540, 930, "POW!", 0.12, 0.0, size=130, seed=3),
      view=(540, 960, 860), bg=lambda cv: art.stage_live(cv, 0.4))

# 02 action_word money variant, settled
panel(1, "money=True +0.40s",
      lambda cv: fx2.action_word(cv, 540, 940, "$9!", 0.40, 0.0, size=150, seed=5, money=True, ang=7),
      view=(540, 960, 860), bg=lambda cv: art.bg_counter(cv, "wall"))

# 03 screen crack
panel(2, "screen_crack +0.20s",
      lambda cv: fx2.screen_crack(cv, 560, 900, 0.2, 0.0, seed=4),
      bg=lambda cv: art.stage_live(cv, 1.0))

VALUES = ["$2.50", "$3.75", "$4.20", "$5.95", "$6.80", "$7.45", "$8.10", "$9.00"]


def slot_bg(cv):
    art.bg_counter(cv, "wall")


# 04 slot roll mid-roll (blurred, moving)
panel(3, "slot_roll mid-roll",
      lambda cv: (fx2.slot_roll(cv, 540, 900, VALUES, 0.30, 0.0, dur=0.8, size=120, color=MONEY),
                  text(cv, "SODA", 540, 1060, 70, "slab", INK)),
      view=(540, 930, 820), bg=slot_bg)

# 05 slot roll landed
panel(4, "slot_roll landed",
      lambda cv: (fx2.slot_roll(cv, 540, 900, VALUES, 1.5, 0.0, dur=0.8, size=120, color=MONEY),
                  text(cv, "SODA", 540, 1060, 70, "slab", INK)),
      view=(540, 930, 820), bg=slot_bg)


# 06 typewriter half way
def tw_draw(cv):
    card = skia.Rect.MakeLTRB(250, 760, 830, 1120)
    cv.drawRoundRect(card.makeOffset(12, 14), 16, 16, fill("#000000", 120))
    cv.drawRoundRect(card, 16, 16, fill(PAPER)); cv.drawRoundRect(card, 16, 16, stroke(INK, 7))
    for k in range(5):
        cv.drawLine(280, 880 + k * 56, 800, 880 + k * 56, stroke(G6, 2))
    text(cv, "EVIDENCE #1", 540, 828, 40, "monob", INK)
    s = "KERNEL COST:  $0.40\nYOUR PRICE:  $9.00\nMARKUP: 2150%"
    fx2.typewriter(cv, s, 290, 920, 0.0 + 26 / 28.0 + 0.01, 0.0, cps=28, size=36, font="mono", color=INK)


panel(5, "typewriter 50%", tw_draw, view=(540, 940, 640), bg=lambda cv: cv.drawRect(skia.Rect.MakeWH(W, H), fill(G2)))


# 07 zoom lines on a shocked popcorn
def zoom_draw(cv):
    fx2.zoom_lines(cv, 540, 900, 0.5, strength=1.0, seed=2, inner=330)
    fx2.contact_shadow(cv, 540, 1080, 340, alpha=120)
    art.draw_popcorn(cv, 540, 1080, 0.85, t=0.5, face=True, mouth="o", seed=4)


panel(6, "zoom_lines", zoom_draw, bg=lambda cv: art.bg_counter(cv, "wall"))


# 08 contact shadow under a dark circle
def shadow_draw(cv):
    cv.drawRect(skia.Rect.MakeLTRB(0, 1000, W, H), fill(G4))
    cv.drawLine(0, 1000, W, 1000, stroke(INK, 7))
    fx2.contact_shadow(cv, 330, 1110, 260, alpha=150)
    ball(cv, 330, 1040, r=80)
    fx2.contact_shadow(cv, 730, 1110, 170, alpha=70)  # hovering -> smaller, lighter
    ball(cv, 730, 870, r=80)


panel(7, "contact_shadow", shadow_draw, view=(540, 980, 900), bg=lambda cv: cv.drawRect(skia.Rect.MakeWH(W, H), fill(G6)))

# 09 / 10 halftone wipe
panel(8, "halftone_wipe 0.3",
      lambda cv: fx2.halftone_wipe(cv, 0.3 * 0.35, 0.0, dur=0.35),
      bg=lambda cv: art.stage_live(cv, 0.2))


def ht_full(cv):
    fx2.halftone_wipe(cv, 0.5 * 0.35, 0.0, dur=0.35)
    text(cv, "100% COVER", 540, 990, 96, "bungee", G2)


panel(9, "halftone_wipe 0.5", ht_full, bg=lambda cv: art.stage_live(cv, 0.2))


# 11 money flash with a cash burst
def flash_draw(cv):
    fx.money_burst(cv, 540, 1080, 0.22, 0.0, n=14, seed=3, scale=1.0)
    art.draw_wally(cv, 540, 1240, 1.1, thick=1.0)
    fx2.money_flash(cv, 0.035, 0.0, dur=0.25, alpha=110)


panel(10, "money_flash +0.03s", flash_draw, bg=lambda cv: art.bg_grid(cv))


# 12 afterimages of a ball on an arc
def trail_draw(cv):
    pts = []
    for k in range(7):
        u = k / 6
        pts.append((220 + 620 * u, 1100 - 420 * math.sin(math.pi * u * 0.85), None))
    fx2.afterimages(cv, lambda cc, x, y, e: ball(cc, x, y, r=72, col=G2), pts, alpha0=140)
    fx2.contact_shadow(cv, pts[-1][0], 1180, 200, alpha=120)
    x, y, _ = pts[-1]
    ball(cv, x, y, r=72, col=G1)


panel(11, "afterimages", trail_draw,
      bg=lambda cv: (cv.drawRect(skia.Rect.MakeWH(W, H), fill(G5)), cv.drawRect(skia.Rect.MakeLTRB(0, 1180, W, H), fill(G3)),
                     cv.drawLine(0, 1180, W, 1180, stroke(INK, 7))))


# 13 sparkles around a coin
def sparkle_draw(cv):
    g2 = skia.GradientShader.MakeRadial(skia.Point(540, 920), 420, [hexc("#ffffff", 70), hexc("#ffffff", 0)])
    cv.drawCircle(540, 920, 420, skia.Paint(AntiAlias=True, Shader=g2))
    art.draw_coin(cv, 540, 920, 3.2)
    art.text(cv, "$", 540, 948, 80, "slab", MONEY_D)
    fx2.sparkles(cv, 540, 920, 0.32, 0.0, life=0.8, n=9, seed=6, radius=300)
    fx2.sparkles(cv, 540, 920, 0.10, 0.0, life=0.8, n=5, seed=9, radius=200)


panel(12, "sparkles +0.32s", sparkle_draw, view=(540, 930, 760),
      bg=lambda cv: cv.drawRect(skia.Rect.MakeWH(W, H), fill(G1)))


# 14 squash_hop filmstrip (onion skin)
def hop_draw(cv):
    floor = 1150
    cv.drawRect(skia.Rect.MakeLTRB(0, floor, W, H), fill(G4)); cv.drawLine(0, floor, W, floor, stroke(INK, 7))
    times = [0.035, 0.105, 0.14, 0.17, 0.205, 0.255, 0.3, 0.345]
    xs = [110 + j * 122 for j in range(len(times))]
    arc = skia.Path()
    for j, tt in enumerate(times):
        dy, _, _ = fx2.squash_hop(tt, 0.0, height=300, dur=0.35)
        (arc.moveTo if j == 0 else arc.lineTo)(xs[j], floor - 45 + dy)
    dash = stroke(G2, 4); dash.setPathEffect(skia.DashPathEffect.Make([14, 12], 0))
    cv.drawPath(arc, dash)
    for j, tt in enumerate(times):
        dy, sx, sy = fx2.squash_hop(tt, 0.0, height=300, dur=0.35)
        x = xs[j]
        fx2.contact_shadow(cv, x, floor + 4, 110 * (1 - min(0.6, -dy / 450)), alpha=int(150 * (1 + dy / 560)))
        cv.save(); cv.translate(x, floor + dy); cv.scale(sx, sy)
        ball(cv, 0, -45, r=45, col=G1 if j in (0, 3, 6) else G2)
        cv.restore()


panel(13, "squash_hop strip", hop_draw, view=(540, 960, 1080), bg=lambda cv: cv.drawRect(skia.Rect.MakeWH(W, H), fill(G6)))


# 15 utility curves: pop_in, impact_text_shake, squash_hop sy
def curves_draw(cv):
    cv.drawRect(skia.Rect.MakeWH(CW, CH), fill(PAPER))
    for xx in range(0, CW, 22):
        cv.drawLine(xx, 0, xx, CH, stroke("#dedcd6", 1.5))
    for yy in range(0, CH, 22):
        cv.drawLine(0, yy, CW, yy, stroke("#dedcd6", 1.5))
    x0, x1, yb, yt = 26, CW - 18, 210, 70  # value 0 at yb, 1 at yt
    cv.drawLine(x0, yb, x1, yb, stroke(INK, 3)); cv.drawLine(x0, yb + 8, x0, 34, stroke(INK, 3))
    cv.drawLine(x0, yt, x1, yt, stroke(G4, 2))
    for name, fn, col, wdt in (("pop_in", lambda tt: fx2.pop_in(tt, 0.0, 0.25), INK, 5),
                               ("shake dx", lambda tt: 0.5 + fx2.impact_text_shake(tt, 0.0, amp=18, dur=0.3)[0] / 40, G3, 3),
                               ("hop sy", lambda tt: fx2.squash_hop(tt, 0.0, dur=0.35)[2], G2, 3)):
        p = skia.Path()
        for k in range(121):
            tt = k / 120 * 0.4
            v = fn(tt)
            px, py = x0 + (x1 - x0) * k / 120, yb - (yb - yt) * v
            (p.moveTo if k == 0 else p.lineTo)(px, py)
        cv.drawPath(p, stroke(col, wdt))
    text(cv, "1.0", x0 + 6, yt - 8, 18, "monob", G2, align="left")
    # legend row (kept clear of the panel number badge and the label tag)
    lx = 28
    for name, col, wdt in (("pop_in", INK, 5), ("shake", G3, 3), ("hop sy", G2, 3)):
        cv.drawLine(lx, 244, lx + 16, 244, stroke(col, wdt))
        lx += 22 + text(cv, name, lx + 22, 250, 16, "monob", col, align="left") + 12


panel(14, "pop_in / shake", curves_draw, view=(CW / 2, CH / 2, CW))

Image.fromarray(arr[..., :3]).save(os.path.join(OUT, "fx2_sheet.png"))
print("saved", os.path.join(OUT, "fx2_sheet.png"))
