"""Render Mister Markup — Racket #001 "Why is movie popcorn so expensive?" — 1080x1920, 24 fps, animated on twos.

Usage: python3 build/render.py            -> out/frames.mp4 (silent video, full length)
       python3 build/render.py --stills t1,t2,...   -> out/previews/still_<t>.png
"""
import json, math, os, subprocess, sys
import numpy as np, skia

HERE = os.path.dirname(__file__)
sys.path.insert(0, HERE)
import art
from art import W, H, INK, WHITE, MONEY, MONEY_D, G1, G2, G3, G4, G5, G6, fill, stroke, text, hexc
from script import LINES, RECEIPT, RECEIPT_TOTAL

ROOT = os.path.join(HERE, "..")
TL = json.load(open(os.path.join(ROOT, "audio", "timeline.json")))
LN = {l["id"]: l for l in TL["lines"]}
ENV = {k: np.array(v) for k, v in TL["env"].items()}
FPS = 24
TOTAL = TL["total"]


def S(i):
    return LN[i]["start"]


def E(i):
    return LN[i]["end"]


def clamp(x, a=0.0, b=1.0):
    return max(a, min(b, x))


def ease(x):
    x = clamp(x)
    return x * x * (3 - 2 * x)


def ease_out_back(x, k=1.70158):
    x = clamp(x) - 1
    return 1 + (k + 1) * x ** 3 + k * x ** 2


def prog(t, a, b):
    return clamp((t - a) / max(1e-6, b - a))


def speaking(t):
    for l in TL["lines"]:
        if l["start"] <= t <= l["end"]:
            return l
    return None


def env_at(spk, t):
    i = int(t * FPS)
    arr = ENV[spk]
    return float(arr[i]) if 0 <= i < len(arr) else 0.0


def markup_mouth(t, idle="grin"):
    l = speaking(t)
    if not l or l["spk"] != "M":
        return idle
    e = env_at("M", t)
    if e < 0.07:
        return "closed"
    q = int(t * 12) % 3
    if e < 0.28:
        return ("E", "closed", "E")[q]
    if e < 0.55:
        return ("E", "A", "O")[q]
    return ("A", "O", "A")[q]


def fn_mouth(t):
    l = speaking(t)
    return "open" if (l and l["spk"] == "F" and env_at("F", t) > 0.12 and int(t * 12) % 2 == 0) else "closed"


def blink(t, period=3.3, off=0.0):
    return ((t + off) % period) < 0.09


# ------------------------------------------------------------------ cached backgrounds
def make_bg(fn, *a, **kw):
    arr = np.zeros((H, W, 4), np.uint8)
    s = skia.Surface(arr)
    fn(s.getCanvas(), *a, **kw)
    return s.makeImageSnapshot()


BG = {
    "stage": make_bg(art.bg_stage),
    "stage_dark": make_bg(art.bg_stage, spot=True),
    "counter_back": make_bg(art.bg_counter, part="back"),
    "counter_front": make_bg(art.bg_counter, part="front"),
    "vault": make_bg(art.bg_vault),
    "grid": make_bg(art.bg_grid),
    "board": make_bg(art.bg_boardroom),
}


class Cam:
    def __init__(self, c, z=1.0, cx=W / 2, cy=H / 2):
        self.c, self.z, self.cx, self.cy = c, z, cx, cy

    def __enter__(self):
        c = self.c
        c.save(); c.translate(W / 2, H / 2); c.scale(self.z, self.z); c.translate(-self.cx, -self.cy)
        return c

    def __exit__(self, *a):
        self.c.restore()


def bg(c, name):
    c.drawImage(BG[name], 0, 0)


# ------------------------------------------------------------------ shot boundaries
SHOTS = []


def shot(name, a, b):
    SHOTS.append((name, a, b))


shot("A_counter", 0.0, E("racket") + 0.05)
shot("B_title", E("racket") + 0.05, S("greed") - 0.05)
shot("C_stage", S("greed") - 0.05, S("ticket") - 0.1)
shot("D_vault", S("ticket") - 0.1, S("blockbuster") - 0.05)
shot("E_board", S("blockbuster") - 0.05, S("fn_half") - 0.15)
shot("F_footnote", S("fn_half") - 0.15, S("crumbs") - 0.05)
shot("G_stage", S("crumbs") - 0.05, S("counter") - 0.2)
shot("H_counter", S("counter") - 0.2, S("twenty") - 0.1)
shot("I_dollar", S("twenty") - 0.1, S("sneaky") - 0.15)
shot("J_decoy", S("sneaky") - 0.15, S("invented") - 0.2)
shot("K_1953", S("invented") - 0.2, S("fn_1982") - 0.1)
shot("L_fn1982", S("fn_1982") - 0.1, S("poll") - 0.2)
shot("M_poll", S("poll") - 0.2, S("verdict") - 0.2)
shot("N_verdict", S("verdict") - 0.2, S("steep") + 1.3)
shot("N2_lights", S("steep") + 1.3, S("promove") - 0.1)
shot("O_promove", S("promove") - 0.1, S("racket_out") - 0.1)
shot("P_outro", S("racket_out") - 0.1, S("next") - 0.1)
shot("Q_next", S("next") - 0.1, TOTAL)

BURN_CUTS = {"B_title", "C_stage", "E_board", "K_1953", "L_fn1982", "N_verdict"}
FREEZE = (S("poll") + 1.7, S("poll") + 2.7)
T_PRICE = S("hook2") + 0.42
T_RECEIPT_IN = S("greed") + 0.4
T_RECEIPT_CENTER = (S("verdict") - 0.1, S("verdict") + 0.6)
T_TOTAL = E("verdict") + 1.25
T_STAMP = T_TOTAL + 0.35
T_FLAT = T_STAMP + 0.15
T_TEAR = S("steep") + 0.55


def receipt_shown(t):
    n = 0.0
    for i, (_, _, lid, off) in enumerate(RECEIPT):
        if t >= S(lid) + off:
            n = i + 1
    return n


def wally_thick(t):
    th = 1.0
    th -= 0.25 * prog(t, S("ticket"), E("blockbuster"))
    th -= 0.2 * prog(t, S("counter"), E("twenty"))
    th -= 0.15 * prog(t, S("bait"), E("decoy"))
    return th


# ------------------------------------------------------------------ shot drawing
def draw_A(c, t, lt, boil):
    # camera: push in on Markup for hook3/racket
    z = 1.0 + 0.5 * ease(prog(t, S("hook3") - 0.2, S("hook3") + 0.5))
    cx = art.lerp(W / 2, 330, ease(prog(t, S("hook3") - 0.2, S("hook3") + 0.5)))
    cy = art.lerp(H / 2, 780, ease(prog(t, S("hook3") - 0.2, S("hook3") + 0.5)))
    with Cam(c, z, cx, cy):
        bg(c, "counter_back")
        if t < S("hook2"):
            arms, expr = "present", "sly"
        elif t < S("hook3"):
            arms, expr = "wide", "outrage"
        else:
            arms, expr = "whisper", "whisper"
        pop = max(0.0, 1 - (t - T_PRICE) / 0.35) if t >= T_PRICE else 0.0
        art.draw_markup(c, 310, 1650, 1.05, {"arms": arms, "expr": expr, "mouth": markup_mouth(t), "blink": blink(t),
                                            "look": (1, 0) if t < S("hook3") else (0, 0)},
                        t=t, boil=boil, price="$9.00" if t >= T_PRICE else None, price_pop=pop)
        bg(c, "counter_front")
        # bucket drops in with squash on landing
        d = prog(t, 0.0, 0.3)
        yy = 1205 - (1 - d * d) * 1400
        sq = 1.0
        if 0.3 <= t < 0.55:
            k = (t - 0.3) / 0.25
            sq = 1 - 0.18 * math.sin(k * math.pi) * (1 - k)
        c.save(); c.translate(800, yy); c.scale(1 / sq ** 0.5, sq); c.translate(-800, -yy)
        art.draw_popcorn(c, 800, yy, 1.1, t=t, boil=boil, face=True, dance=1.0 if S("hook3") <= t else 0.0,
                         mouth="grin" if t > S("hook3") else "flat", price="$9.00" if t >= T_PRICE else None, tag_side=-1)
        c.restore()
    # question title (keyword in first 3 s)
    if 0.25 <= t < E("racket"):
        k = ease_out_back(prog(t, 0.25, 0.55))
        c.save(); c.translate(W / 2, 330); c.scale(k, k)
        c.drawRoundRect(skia.Rect.MakeLTRB(-470, -170, 470, 150), 26, 26, fill(INK, 225))
        c.drawRoundRect(skia.Rect.MakeLTRB(-470, -170, 470, 150), 26, 26, stroke(WHITE, 6))
        text(c, "WHY IS MOVIE", 0, -80, 82, "bungee", WHITE)
        text(c, "POPCORN SO", 0, 10, 82, "bungee", WHITE)
        text(c, "EXPENSIVE?", 0, 104, 92, "bungee", MONEY)
        c.restore()


def draw_B(c, t, lt, boil):
    c.drawRect(skia.Rect.MakeWH(W, H), fill("#0e0e0e"))
    # film-leader circle with sweep
    cx, cy = W / 2, 820
    c.drawCircle(cx, cy, 300, stroke(G5, 8)); c.drawCircle(cx, cy, 250, stroke(G5, 4))
    c.drawLine(cx - 420, cy, cx + 420, cy, stroke(G4, 4)); c.drawLine(cx, cy - 420, cx, cy + 420, stroke(G4, 4))
    ang = (lt / 0.7) * 360
    p = skia.Path(); p.moveTo(cx, cy); p.arcTo(skia.Rect.MakeLTRB(cx - 300, cy - 300, cx + 300, cy + 300), -90, ang % 360, False); p.close()
    c.drawPath(p, fill(G3, 120))
    text(c, "A FINE PRINT", cx, cy - 40, 104, "deco", WHITE)
    text(c, "PICTURE", cx, cy + 80, 120, "deco", WHITE)
    text(c, "MISTER MARKUP in", cx, 1290, 54, "slab", G5)
    text(c, "RACKET #001: MOVIE POPCORN", cx, 1380, 56, "anton", MONEY)


def draw_C(c, t, lt, boil):
    with Cam(c, 1.0):
        bg(c, "stage")
        sub = t - S("greed")
        arms = "shrug" if sub < 1.9 else "wave"
        art.draw_markup(c, 540, 1600, 1.0, {"arms": arms, "expr": "sly" if sub < 1.9 else "proud", "mouth": markup_mouth(t),
                                           "blink": blink(t), "look": (0, -1) if sub >= 1.9 else (1, 0)}, t=t, boil=boil)
        # green bills rain on "follow the green"
        if sub >= 1.9:
            for i in range(14):
                st = 1.9 + i * 0.07
                k = sub - st
                if k < 0:
                    continue
                x = 80 + (i * 137) % 920 + math.sin(k * 3 + i) * 40
                y = -80 + k * 650
                art.draw_bill(c, x, y, 0.9, ang=math.sin(k * 4 + i) * 40 + i * 20)
        # Wally waddles in from the right
        wx = art.lerp(1180, 820, ease(prog(t, S("greed") + 0.6, S("greed") + 2.0)))
        art.draw_wally(c, wx, 1640, 0.85, thick=wally_thick(t), t=t, boil=boil, walk=t * 1.6)


def draw_D(c, t, lt, boil):
    with Cam(c, 1.0):
        bg(c, "vault")
        art.draw_pipe(c)
        path = art.pipe_path()
        pm = skia.PathMeasure(path, False)
        L = pm.getLength()
        for i in range(9):
            d = ((lt * 520 + i * L / 9) % L)
            pos, tan = pm.getPosTan(d)
            if True:
                ang = math.degrees(math.atan2(tan.y(), tan.x()))
                art.draw_bill(c, pos.x(), pos.y(), 0.55, ang=ang + math.sin(lt * 5 + i) * 15)
        # bills hop from Wally into the booth window
        for i in range(3):
            k = ((lt * 1.4 + i / 3) % 1.0)
            x = art.lerp(250, 230, k); y = 1460 - math.sin(k * math.pi) * 380 - k * 400
            art.draw_bill(c, x, y, 0.5 * (1 - 0.4 * k), ang=k * 300)
        art.draw_wally(c, 240, 1660, 0.85, thick=wally_thick(t), t=t, boil=boil, walk=None)
        # little "~50%" gauge on the vault
        if t > S("ticket") + 1.6:
            k = ease_out_back(prog(t, S("ticket") + 1.6, S("ticket") + 1.9))
            c.save(); c.translate(760, 1060); c.scale(k, k)
            c.drawCircle(0, 0, 120, fill(INK, 230)); c.drawCircle(0, 0, 120, stroke(WHITE, 6))
            text(c, "~50%", 0, 24, 76, "anton", MONEY)
            c.restore()


def draw_E(c, t, lt, boil):
    with Cam(c, 1.0 + 0.04 * lt):
        bg(c, "board")
        for i, x in enumerate((240, 540, 840)):
            art.draw_fat_cat(c, x, 1390 + math.sin(t * 5 + i) * 6, 1.0, t=t, puff=(lt * 0.6 + i * 0.3) % 1.0)
        for i in range(10):
            k = lt - i * 0.08
            if k < 0:
                continue
            x = 120 + (i * 97) % 840
            y = min(1400, -60 + k * 900)
            art.draw_bill(c, x, y, 0.8, ang=i * 33 + k * 80)


def draw_F(c, t, lt, boil):
    with Cam(c, 1.0):
        bg(c, "vault")
        art.draw_pipe(c)
        k = ease_out_back(prog(lt, 0.0, 0.3))
        art.draw_footnote(c, 540, 1760, 1.25 * k, t=t, mouth=fn_mouth(t), boil=boil, blink=blink(t, 2.7))
        art.draw_wally(c, 240, 1660, 0.85, thick=wally_thick(t), t=t, boil=boil)
    if lt > 0.5:
        a = int(255 * prog(lt, 0.5, 0.75))
        art.draw_card(c, W / 2, 690, ["*Source: AMC & Cinemark", "2025 annual reports (10-K):", "U.S. film rent = ~51-57%", "of ticket sales"],
                      w=820, a=a, size=42)


def draw_G(c, t, lt, boil):
    with Cam(c, 1.0):
        bg(c, "stage")
        sub = t - S("crumbs")
        arms = "shrug" if sub < 1.0 else "think"
        art.draw_markup(c, 540, 1600, 1.0, {"arms": arms, "expr": "guilty" if sub < 1.0 else "sly", "mouth": markup_mouth(t),
                                           "blink": blink(t), "look": (-1, -1) if sub > 1.0 else (0, 0)}, t=t, boil=boil)
        art.draw_wally(c, 820, 1640, 0.85, thick=wally_thick(t), t=t, boil=boil)


def draw_H(c, t, lt, boil):
    with Cam(c, 1.0):
        bg(c, "counter_back")
        art.draw_markup(c, 250, 1650, 1.05, {"arms": "point", "expr": "sly", "mouth": markup_mouth(t), "blink": blink(t),
                                            "look": (1, 0)}, t=t, boil=boil)
        bg(c, "counter_front")
        art.draw_popcorn(c, 840, 1205, 1.0, t=t, boil=boil, face=True, dance=0.4)
        if t >= S("soda") - 0.2:
            sx = art.lerp(1300, 600, ease(prog(t, S("soda") - 0.2, S("soda") + 0.3)))
            cut = prog(t, S("soda") + 1.4, S("soda") + 2.0)
            art.draw_soda(c, sx, 1205, 0.95, t=t, boil=boil, cutaway=cut)
            if cut > 0.5:
                a = int(255 * prog(t, S("soda") + 1.8, S("soda") + 2.1))
                text(c, "5 PARTS WATER", sx + 80, 760, 46, "anton", WHITE, outline=INK, ow=10, alpha=a)
                text(c, "1 PART SYRUP + ICE", sx + 80, 818, 46, "anton", WHITE, outline=INK, ow=10, alpha=a)


def draw_I(c, t, lt, boil):
    with Cam(c, 1.0):
        bg(c, "grid")
        text(c, "YOUR SNACK DOLLAR", W / 2, 720, 84, "deco", INK)
        k = ease_out_back(prog(lt, 0.0, 0.35))
        c.save(); c.translate(W / 2, 960); c.scale(5.6 * k, 5.6 * k)
        art.draw_bill(c, 0, 0, 1.0)
        split = prog(t, S("twenty") + 2.0, S("twenty") + 2.6)
        if split > 0:
            c.save()
            c.clipRect(skia.Rect.MakeLTRB(-60, -30, -60 + 24 * split, 30))
            c.drawRect(skia.Rect.MakeLTRB(-62, -32, 62, 32), fill(G3, 235))
            for xx in range(-80, 20, 6):
                c.drawLine(xx, -32, xx + 30, 32, stroke(G2, 1.2))
            c.restore()
            c.drawLine(-36, -34, -36, 34, stroke(INK, 1.6))
        c.restore()
        if split >= 1:
            a = int(255 * prog(t, S("twenty") + 2.6, S("twenty") + 2.9))
            text(c, "FOOD ~20¢", 270, 1222, 62, "anton", INK, alpha=a)
            text(c, "THEATER KEEPS ~80¢", 665, 1222, 62, "anton", MONEY_D, alpha=a)
            text(c, "(before staff & rent)", W / 2, 1284, 40, "mono", G2, alpha=a)


BUCKETS = [(205, 0.58, "$7.25", "SMALL"), (535, 0.78, "$8.75", "MEDIUM"), (865, 0.96, "$9.25", "LARGE")]


def draw_buckets(c, t, boil, focus=None, labels=True, freeze=False):
    for i, (x, s, p, nm) in enumerate(BUCKETS):
        bounce = 0.0
        if focus == i and not freeze:
            bounce = abs(math.sin(t * 7)) * 30
        if focus == i:
            g = skia.GradientShader.MakeRadial(skia.Point(x, 1000), 260, [hexc("#ffffff", 200), hexc("#ffffff", 0)])
            c.drawCircle(x, 1000, 260, skia.Paint(AntiAlias=True, Shader=g))
        art.draw_popcorn(c, x, 1120 - bounce, s, t=t, boil=boil, label=False, seed=i + 2, face=(focus == i), mouth="grin")
        if labels:
            text(c, p, x, 1205, 64, "marker", MONEY, outline=MONEY_D, ow=3)
    text(c, "example prices", W / 2, 1262, 34, "mono", G2)


def draw_pointer(c, tx, ty, t):
    # Markup's gloved hand + pointer stick entering from the left edge
    hx, hy = -10, ty + 140
    ang = math.degrees(math.atan2(ty - hy, tx - hx))
    c.drawLine(-60, hy + 40, hx, hy, stroke(INK, 62)); c.drawLine(-60, hy + 40, hx, hy, stroke(G3, 50))
    a = math.radians(ang)
    sx, sy = hx + math.cos(a) * 40, hy + math.sin(a) * 40
    ex, ey = tx - math.cos(a) * 30, ty - math.sin(a) * 30
    c.drawLine(sx, sy, ex, ey, stroke(INK, 16)); c.drawLine(sx, sy, ex, ey, stroke(G5, 8))
    art.draw_glove(c, hx, hy, ang, "fist", 1.1)


def draw_J(c, t, lt, boil):
    with Cam(c, 1.0):
        bg(c, "grid")
        focus = 1 if t >= S("sneaky") + 1.1 else None
        if t >= S("bait") + 2.6:
            focus = 2
        draw_buckets(c, t, boil, focus=focus)
        # fishing hook drops onto the medium at "It's bait"
        if t >= S("bait") + 0.9:
            k = ease_out_back(prog(t, S("bait") + 0.9, S("bait") + 1.3))
            hy = art.lerp(-100, 760, k)
            c.drawLine(535, -10, 535, hy, stroke(INK, 4))
            hp = skia.Path(); hp.moveTo(535, hy); hp.lineTo(535, hy + 70)
            hp.cubicTo(535, hy + 120, 470, hy + 120, 470, hy + 70)
            c.drawPath(hp, stroke(INK, 12)); c.drawPath(hp, stroke(G5, 5))
            if k > 0.8:
                text(c, "BAIT", 535, 690, 92, "bungee", WHITE, outline=INK, ow=14)
        if t >= S("bait") + 2.6:
            k = prog(t, S("bait") + 2.6, S("bait") + 3.1)
            ap = skia.Path(); ap.moveTo(600, 840); ap.quadTo(720, 700, 820 * k + 600 * (1 - k), 820 * k + 840 * (1 - k))
            c.drawPath(ap, stroke(INK, 16))
            if k >= 1:
                c.drawPath(art.path_poly([(830, 830), (790, 800), (812, 852)]), fill(INK))
                text(c, "STEAL!", 865, 640, 80, "bungee", MONEY, outline=INK, ow=12)
                for i in range(4):
                    a = t * 3 + i * 1.57
                    sx, sy = 865 + math.cos(a) * 170, 900 + math.sin(a) * 120
                    star = art.path_poly([(sx, sy - 26), (sx + 7, sy - 7), (sx + 26, sy), (sx + 7, sy + 7), (sx, sy + 26),
                                          (sx - 7, sy + 7), (sx - 26, sy), (sx - 7, sy - 7)])
                    c.drawPath(star, fill(WHITE)); c.drawPath(star, stroke(INK, 3))
        tgt = {None: (205, 900), 1: (500, 880), 2: (820, 860)}[focus]
        draw_pointer(c, *tgt, t)
    if t >= S("decoy"):
        k = ease_out_back(prog(t, S("decoy"), S("decoy") + 0.3))
        c.save(); c.translate(W / 2, 430); c.scale(k, k)
        text(c, "THE DECOY EFFECT", 0, 0, 92, "deco", INK)
        c.restore()


def draw_K(c, t, lt, boil):
    with Cam(c, 1.0 + 0.03 * lt):
        bg(c, "stage")
        c.drawRect(skia.Rect.MakeWH(W, H), fill("#000000", 70))
        art.draw_markup(c, 540, 1600, 1.0, {"arms": "hold", "expr": "proud", "mouth": markup_mouth(t), "blink": blink(t),
                                           "string": "up", "look": (0, 0)}, t=t, boil=boil)
        art.draw_popcorn(c, 540, 1080, 0.62, t=t, boil=boil, label=False, seed=3)
    text(c, "1953", W / 2, 300, 150, "deco", WHITE, outline=INK, ow=10)
    text(c, "(as he remembers it)", W / 2, 372, 44, "mono", G6)


def draw_L(c, t, lt, boil):
    with Cam(c, 1.0):
        bg(c, "grid")
        k = ease_out_back(prog(lt, 0.0, 0.3))
        art.draw_footnote(c, 330, 1770, 1.45 * k, t=t, mouth=fn_mouth(t), boil=boil, blink=blink(t, 2.7))
        droop = t >= S("fn_1982") + 0.5
        art.draw_markup(c, 820, 1640, 0.62, {"arms": "shrug", "expr": "guilty", "mouth": "guilty" if droop else "grin",
                                            "string": "down" if droop else "up", "blink": blink(t)}, t=t, boil=boil)
    if lt > 0.4:
        a = int(255 * prog(lt, 0.4, 0.65))
        art.draw_card(c, W / 2, 360, ["*Huber, Payne & Puto (1982)", "Journal of Consumer Research"], w=840, a=a, size=42)


def draw_M(c, t, lt, boil, freeze=False):
    with Cam(c, 1.0):
        bg(c, "grid")
        draw_buckets(c, t, boil, focus=None, freeze=freeze)
        for i, (x, s, p, nm) in enumerate(BUCKETS):
            k = ease_out_back(prog(t, S("poll") + i * 0.35, S("poll") + i * 0.35 + 0.3))
            c.save(); c.translate(x, 740); c.scale(k, k)
            text(c, nm + "?", 0, 0, 50, "bungee", WHITE, outline=INK, ow=10)
            c.restore()
    if t > S("poll") + 1.4:
        c.drawRoundRect(skia.Rect.MakeLTRB(140, 330, 940, 470), 24, 24, fill(INK, 230))
        text(c, "BE HONEST:", W / 2, 395, 56, "anton", WHITE)
        text(c, "COMMENT BELOW", W / 2, 455, 56, "anton", MONEY)


def draw_receipt_overlay(c, t, center=False):
    if t < T_RECEIPT_IN:
        return
    sl = ease_out_back(prog(t, T_RECEIPT_IN, T_RECEIPT_IN + 0.45))
    if not center:
        sl *= 1 - ease(prog(t, S("decoy") - 0.3, S("decoy")))
        if sl <= 0.01:
            return
    else:
        sl = 1.0
    x, y, sc = 44, art.lerp(-700, 150, sl), 1.0
    if center:
        k = ease(prog(t, *T_RECEIPT_CENTER))
        x = art.lerp(44, W / 2 - 390 * 1.6 / 2, k)
        y = art.lerp(150, 330, k)
        sc = art.lerp(1.0, 1.6, k)
    torn = ease(prog(t, T_TEAR, T_TEAR + 0.75)) ** 2
    reveal = prog(t, T_TOTAL, T_TOTAL + 0.3) if t >= T_TOTAL else 0.0
    art.draw_receipt(c, x, y, [(a, b) for a, b, _, _ in RECEIPT], receipt_shown(t), total=RECEIPT_TOTAL if t >= T_TOTAL else None,
                     total_reveal=reveal, torn=torn, scale=sc)


def draw_N(c, t, lt, boil):
    with Cam(c, 1.0):
        bg(c, "stage")
        c.drawRect(skia.Rect.MakeWH(W, H), fill("#000000", 60))
        flat = ease(prog(t, T_FLAT, T_FLAT + 0.15))
        art.draw_wally(c, 540, 1720, 1.1, thick=wally_thick(t), t=t, boil=boil, flat=flat)
    draw_receipt_overlay(c, t, center=True)
    if t >= T_STAMP:
        art.draw_stamp(c, W / 2, 1090, "STEEP", prog(t, T_STAMP, T_STAMP + 0.6), sub="BUT IT KEEPS THE LIGHTS ON")


def draw_N2(c, t, lt, boil):
    with Cam(c, 1.0):
        bg(c, "counter_back")
        # marquee bulbs blaze on — "keeps the lights on"
        ph = int(t * 8) % 2
        for i, (bx, by) in enumerate(art.BULBS):
            if (i // 2) % 2 == ph:
                g = skia.GradientShader.MakeRadial(skia.Point(bx, by), 34, [hexc("#ffffff", 255), hexc("#ffffff", 0)])
                c.drawCircle(bx, by, 34, skia.Paint(AntiAlias=True, Shader=g))
        art.draw_markup(c, 300, 1650, 1.05, {"arms": "present", "expr": "proud", "mouth": markup_mouth(t), "blink": blink(t),
                                            "look": (1, -1)}, t=t, boil=boil)
        bg(c, "counter_front")
        art.draw_popcorn(c, 820, 1205, 1.05, t=t, boil=boil, face=True, dance=1.0)
    draw_receipt_overlay(c, t, center=True)


def draw_O(c, t, lt, boil):
    with Cam(c, 1.0):
        bg(c, "stage")
        art.draw_markup(c, 250, 1600, 0.95, {"arms": "present", "expr": "sly", "mouth": markup_mouth(t), "blink": blink(t),
                                            "look": (1, -1)}, t=t, boil=boil)
    if lt > 0.3:
        k = ease_out_back(prog(lt, 0.3, 0.6))
        art.draw_card(c, 675, 400, ["PRO MOVE:", "check your", "theater's app", "*free refills", "*member deals"], w=490, scale=k, size=50)


def draw_P(c, t, lt, boil):
    with Cam(c, 1.0):
        bg(c, "stage")
        art.draw_markup(c, 540, 1600, 1.0, {"arms": "wave", "expr": "proud", "mouth": markup_mouth(t), "blink": blink(t)}, t=t, boil=boil)
        art.draw_wally(c, 880, 1640, 0.85, thick=0.4, t=t, boil=boil, flat=0.0)
        art.draw_footnote(c, 190, 1660, 0.8, t=t, mouth="closed", boil=boil)
    k = ease_out_back(prog(lt, 0.1, 0.45))
    c.save(); c.translate(W / 2, 360); c.scale(k, k)
    text(c, "NOW YA KNOW", 0, 0, 100, "bungee", WHITE, outline=INK, ow=14)
    text(c, "THE RACKET.", 0, 118, 100, "bungee", WHITE, outline=INK, ow=14)
    c.restore()


def draw_Q(c, t, lt, boil):
    with Cam(c, 1.0):
        bg(c, "stage")
        k = ease_out_back(prog(lt, 0.0, 0.3))
        art.draw_footnote(c, 540, 1720, 1.35 * k, t=t, mouth=fn_mouth(t), boil=boil, blink=blink(t, 2.7))
    if lt > 0.3:
        k = ease_out_back(prog(lt, 0.3, 0.6))
        art.draw_card(c, W / 2, 480, ["NEXT REEL:", "Why is hotel", "check-in at 3?"], w=640, scale=k, size=60)
        text(c, "@mistermarkup", W / 2, 1000, 56, "anton", WHITE, outline=INK, ow=10)


DRAW = {"A_counter": draw_A, "B_title": draw_B, "C_stage": draw_C, "D_vault": draw_D, "E_board": draw_E, "F_footnote": draw_F,
        "G_stage": draw_G, "H_counter": draw_H, "I_dollar": draw_I, "J_decoy": draw_J, "K_1953": draw_K, "L_fn1982": draw_L,
        "M_poll": draw_M, "N_verdict": draw_N, "N2_lights": draw_N2, "O_promove": draw_O, "P_outro": draw_P, "Q_next": draw_Q}
RECEIPT_SHOTS = {"C_stage", "D_vault", "E_board", "F_footnote", "G_stage", "H_counter", "I_dollar", "J_decoy", "K_1953", "L_fn1982", "M_poll"}


# ------------------------------------------------------------------ captions
def caption_chunks():
    out = []
    for lid, spk, tts, cap, gap, fx in LINES:
        l = LN[lid]
        phrases, cur = [], []
        for w in cap.split():
            cur.append(w)
            if w.rstrip("*").endswith((".", "?", "!", ",", ":")):
                phrases.append(cur); cur = []
        if cur:
            phrases.append(cur)
        chunks = []
        for ph in phrases:
            n = len(ph)
            parts = max(1, math.ceil(n / 4))
            size = math.ceil(n / parts)
            for i in range(0, n, size):
                chunks.append(ph[i:i + size])
        # merge a dangling single word into the previous chunk
        merged = []
        for ch in chunks:
            if merged and len(ch) == 1 and len(merged[-1]) < 4 and not merged[-1][-1].rstrip("*").endswith((".", "?", "!")):
                merged[-1] = merged[-1] + ch
            else:
                merged.append(ch)
        total_chars = sum(len(" ".join(ch)) for ch in merged)
        t0 = l["start"]; dur = l["end"] - l["start"]
        for ch in merged:
            d = dur * len(" ".join(ch)) / total_chars
            out.append((t0, t0 + d, [(w.strip("*"), w.startswith("*")) for w in ch], spk))
            t0 += d
    return out


CAPS = caption_chunks()
CAP_Y = {"default": 1330, "I_dollar": 1380, "L_fn1982": 1060, "J_decoy": 1400, "M_poll": 1400, "N_verdict": 1405, "B_title": None}


def draw_captions(c, t, shot_name):
    y = CAP_Y.get(shot_name, CAP_Y["default"])
    if y is None:
        return
    for a, b, words, spk in CAPS:
        if a <= t < b:
            k = prog(t, a, a + 0.12)
            art.draw_caption(c, words, W / 2, y, size=74, k=k)
            return


LN_FIRST_CHUNK = {}


# ------------------------------------------------------------------ iris / burns / film fx
def iris(c, r):
    p = skia.Path(); p.addRect(skia.Rect.MakeWH(W, H)); p.addCircle(W / 2, H / 2 - 100, max(0.0, r))
    p.setFillType(skia.PathFillType.kEvenOdd)
    c.drawPath(p, fill("#050505"))


VIGNETTE = art.vignette_paint()


def render_frame(arr, t, fidx):
    s = skia.Surface(arr)
    c = s.getCanvas()
    c.clear(hexc("#000000"))
    q = int(t * 12)  # animate on twos
    if FREEZE[0] <= t < FREEZE[1]:
        q = int(FREEZE[0] * 12)
        t_draw = FREEZE[0]
    else:
        t_draw = q / 12.0
    rnd = np.random.default_rng(q * 7919 + 13)
    boil = int(q % 3) + 1
    name, a, b = next(((n, a, b) for n, a, b in SHOTS if a <= t < b), SHOTS[-1])
    lt = t_draw - a
    # gate weave
    c.save(); c.translate(rnd.uniform(-1.6, 1.6), rnd.uniform(-1.2, 1.2))
    fn = DRAW[name]
    if name == "M_poll":
        fn(c, t_draw, lt, boil, freeze=FREEZE[0] <= t < FREEZE[1])
    else:
        fn(c, t_draw, lt, boil)
    if name in RECEIPT_SHOTS:
        draw_receipt_overlay(c, t_draw)
    c.restore()
    draw_captions(c, t_draw, name)
    # iris transitions
    if name == "G_stage" and t > b - 0.35:
        iris(c, art.lerp(1400, 0, prog(t, b - 0.35, b)))
    if name == "H_counter" and t < a + 0.35:
        iris(c, art.lerp(0, 1400, prog(t, a, a + 0.35)))
    if name == "Q_next":
        if t > TOTAL - 0.9:
            iris(c, art.lerp(1400, 0, prog(t, TOTAL - 0.9, TOTAL - 0.5)))
    # film burn flash on selected cuts
    if name in BURN_CUTS and t - a < 0.125:
        c.drawRect(skia.Rect.MakeWH(W, H), fill("#ffffff", int(200 * (1 - (t - a) / 0.125))))
    if t < 1 / 12:
        c.drawRect(skia.Rect.MakeWH(W, H), fill("#ffffff", 180))
    # cue dot before the flashback (classic reel-change mark)
    if S("decoy") + 1.2 <= t < S("decoy") + 1.45:
        c.drawCircle(940, 180, 34, fill("#f5f5f5", 220))
    # flicker + dust + vignette
    fl = rnd.uniform(-1, 1)
    c.drawRect(skia.Rect.MakeWH(W, H), fill("#ffffff" if fl > 0 else "#000000", int(abs(fl) * 14)))
    art.film_frame_fx(c, fidx, rnd, strength=2.4 if name == "K_1953" else 1.0)
    c.drawRect(skia.Rect.MakeWH(W, H), VIGNETTE)
    if name == "K_1953":
        c.drawRect(skia.Rect.MakeWH(W, H), art.vignette_paint())


def main():
    if len(sys.argv) > 2 and sys.argv[1] == "--stills":
        from PIL import Image
        os.makedirs(os.path.join(ROOT, "out", "previews"), exist_ok=True)
        for ts in sys.argv[2].split(","):
            t = float(ts)
            arr = np.zeros((H, W, 4), np.uint8)
            render_frame(arr, t, int(t * FPS))
            Image.fromarray(arr[..., :3]).save(os.path.join(ROOT, "out", "previews", f"still_{t:05.2f}.png"))
        return
    # Render unique frames at 12 fps (animation "on twos"); grain is applied per unique frame and
    # ffmpeg duplicates to 24 fps, so the encoder sees identical pairs (much smaller files).
    nuniq = int(TOTAL * 12)
    outp = os.path.join(ROOT, "out", "frames.mp4")
    ff = subprocess.Popen(["ffmpeg", "-y", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgba", "-s", f"{W}x{H}", "-r", "12",
                           "-i", "-", "-vf", "format=yuv420p,noise=c0s=10:c0f=t,fps=24", "-c:v", "libx264", "-preset", "slow",
                           "-crf", "20", "-maxrate", "16M", "-bufsize", "32M", "-pix_fmt", "yuv420p", "-r", "24", outp],
                          stdin=subprocess.PIPE)
    arr = np.zeros((H, W, 4), np.uint8)
    for n in range(nuniq):
        t = n / 12
        render_frame(arr, t, n * 2)
        ff.stdin.write(arr.tobytes())
        if n % 120 == 0:
            print(f"frame {n}/{nuniq}", flush=True)
    ff.stdin.close(); ff.wait()
    print("wrote", outp)


if __name__ == "__main__":
    main()
