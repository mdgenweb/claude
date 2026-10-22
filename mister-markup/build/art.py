"""Vector art for Mister Markup — 1950s black-and-white cartoon, only money is green.

All characters/props are drawn in a local coordinate space (origin at the feet / bottom
centre, y grows downward, so things are drawn at negative y). Every draw_* function takes
(canvas, x, y, s, ...) and handles its own save/translate/scale/restore.
"""
import math, os
import skia

HERE = os.path.dirname(__file__)
FONTS = os.path.join(HERE, "..", "assets", "fonts")


def _tf(name):
    return skia.Typeface.MakeFromFile(os.path.join(FONTS, name))


TF = {
    "anton": _tf("anton-latin-400-normal.ttf"),
    "bungee": _tf("bungee-latin-400-normal.ttf"),
    "slab": _tf("alfa-slab-one-latin-400-normal.ttf"),
    "mono": _tf("courier-prime-latin-400-normal.ttf"),
    "monob": _tf("courier-prime-latin-700-normal.ttf"),
    "deco": _tf("limelight-latin-400-normal.ttf"),
    "marker": _tf("permanent-marker-latin-400-normal.ttf"),
}


def hexc(h, a=255):
    h = h.lstrip("#")
    return skia.ColorSetARGB(a, int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


INK = "#121212"
PAPER = "#f1f0ec"
G1, G2, G3, G4, G5, G6 = "#2b2b2b", "#4a4a4a", "#6f6f6f", "#949494", "#bdbdbd", "#dcdcdc"
WHITE = "#fbfbf8"
MONEY = "#1fd67a"      # the ONLY colour in the world
MONEY_D = "#0f8f4e"
MONEY_L = "#8ff0bd"


def fill(c, a=255):
    return skia.Paint(AntiAlias=True, Color=hexc(c, a), Style=skia.Paint.kFill_Style)


def stroke(c=INK, w=6, a=255, boil=None, cap="round"):
    p = skia.Paint(AntiAlias=True, Color=hexc(c, a), Style=skia.Paint.kStroke_Style, StrokeWidth=w,
                   StrokeCap=skia.Paint.kRound_Cap if cap == "round" else skia.Paint.kButt_Cap,
                   StrokeJoin=skia.Paint.kRound_Join)
    if boil is not None:
        p.setPathEffect(skia.DiscretePathEffect.Make(16, 0.9, boil))
    return p


def path_poly(pts, close=True):
    p = skia.Path()
    p.moveTo(*pts[0])
    for q in pts[1:]:
        p.lineTo(*q)
    if close:
        p.close()
    return p


def inked(canvas, path, fc, w=6, boil=None, oc=INK):
    if fc is not None:
        canvas.drawPath(path, fill(fc))
    canvas.drawPath(path, stroke(oc, w, boil=boil))


def text(canvas, s, x, y, size, tf="anton", color=WHITE, outline=None, ow=8, align="center", alpha=255, skew=0):
    font = skia.Font(TF[tf], size)
    if skew:
        font.setSkewX(skew)
    w = font.measureText(s)
    if align == "center":
        x -= w / 2
    elif align == "right":
        x -= w
    if outline:
        p = skia.Paint(AntiAlias=True, Color=hexc(outline, alpha), Style=skia.Paint.kStroke_Style,
                       StrokeWidth=ow, StrokeJoin=skia.Paint.kRound_Join)
        canvas.drawString(s, x, y, font, p)
    canvas.drawString(s, x, y, font, skia.Paint(AntiAlias=True, Color=hexc(color, alpha)))
    return w


def text_width(s, size, tf="anton"):
    return skia.Font(TF[tf], size).measureText(s)


def lerp(a, b, t):
    return a + (b - a) * t


# ------------------------------------------------------------------ gloves
def draw_glove(c, x, y, ang, kind="open", size=1.0, boil=None, flip=1):
    """White four-finger cartoon glove. ang = direction the hand points (degrees)."""
    c.save(); c.translate(x, y); c.rotate(ang); c.scale(size * flip, size)
    sw = 5
    # cuff (flared)
    cuff = path_poly([(-34, -22), (-10, -16), (-10, 16), (-34, 22)])
    inked(c, cuff, WHITE, sw, boil)
    c.drawLine(-26, -14, -26, 14, stroke(INK, 3))
    if kind == "point":
        finger = skia.Path(); finger.addRRect(skia.RRect.MakeRectXY(skia.Rect.MakeLTRB(14, -11, 78, 9), 10, 10))
        inked(c, finger, WHITE, sw, boil)
        palm = skia.Path(); palm.addOval(skia.Rect.MakeLTRB(-14, -26, 30, 26))
        inked(c, palm, WHITE, sw, boil)
        c.drawArc(skia.Rect.MakeLTRB(6, 4, 34, 30), 200, 160, False, stroke(INK, 4))
        thumb = skia.Path(); thumb.addOval(skia.Rect.MakeLTRB(2, -36, 26, -14))
        inked(c, thumb, WHITE, sw, boil)
    elif kind == "fist":
        palm = skia.Path(); palm.addOval(skia.Rect.MakeLTRB(-14, -28, 36, 28))
        inked(c, palm, WHITE, sw, boil)
        for yy in (-14, 0, 14):
            c.drawArc(skia.Rect.MakeLTRB(18, yy - 9, 40, yy + 9), 270, 180, False, stroke(INK, 4))
    else:  # open hand, fingers fanned
        for i, a in enumerate((-38, -12, 14, 40)):
            c.save(); c.rotate(a)
            f = skia.Path(); f.addRRect(skia.RRect.MakeRectXY(skia.Rect.MakeLTRB(12, -10, 66 - abs(a) * 0.3, 10), 10, 10))
            inked(c, f, WHITE, sw, boil)
            c.restore()
        palm = skia.Path(); palm.addOval(skia.Rect.MakeLTRB(-14, -30, 34, 30))
        inked(c, palm, WHITE, sw, boil)
        for yy in (-10, 2, 14):
            c.drawLine(2, yy, 18, yy * 0.8, stroke(INK, 3))
        thumb = skia.Path(); thumb.addRRect(skia.RRect.MakeRectXY(skia.Rect.MakeLTRB(-4, -48, 14, -18), 9, 9))
        inked(c, thumb, WHITE, sw, boil)
    c.restore()


def noodle(c, p0, p1, bend, w, col, boil=None, ow=7):
    """Rubber-hose limb: cubic from p0 to p1 bulging by `bend` (perp offset)."""
    (x0, y0), (x1, y1) = p0, p1
    dx, dy = x1 - x0, y1 - y0
    L = math.hypot(dx, dy) + 1e-6
    nx, ny = -dy / L, dx / L
    c1 = (x0 + dx * 0.3 + nx * bend, y0 + dy * 0.3 + ny * bend)
    c2 = (x0 + dx * 0.7 + nx * bend, y0 + dy * 0.7 + ny * bend)
    p = skia.Path(); p.moveTo(x0, y0); p.cubicTo(*c1, *c2, x1, y1)
    c.drawPath(p, stroke(INK, w + ow * 2, boil=boil))
    c.drawPath(p, stroke(col, w))
    return p


# ------------------------------------------------------------------ MISTER MARKUP
MOUTHS = ("closed", "grin", "A", "E", "O", "outrage", "guilty")


def draw_markup(c, x, y, s, pose=None, t=0.0, boil=None, price=None, price_pop=0.0, upper_only=False):
    pose = pose or {}
    lean = pose.get("lean", 0.0)
    squash = pose.get("squash", 1.0)
    expr = pose.get("expr", "sly")         # sly | outrage | guilty | whisper | proud | shock
    mouth = pose.get("mouth", "grin")
    look = pose.get("look", (0, 0))
    blink = pose.get("blink", False)
    arms = pose.get("arms", "hips")        # hips | whisper | wide | shrug | point | present | hold | wave
    string = pose.get("string", "up")      # up | down | knot
    stick = pose.get("stick", arms == "point")
    walk = pose.get("walk", None)

    c.save(); c.translate(x, y); c.scale(s, s * squash); c.rotate(lean)
    sw = 7

    # ---- legs + shoes
    if not upper_only:
        if walk is None:
            feet = [(-62, 0), (62, 0)]
        else:
            ph = walk * 2 * math.pi
            feet = [(-50 + 40 * math.sin(ph), -abs(18 * math.cos(ph))), (50 - 40 * math.sin(ph), -abs(18 * math.sin(ph)))]
        for side, (fx, fy) in zip((-1, 1), feet):
            noodle(c, (side * 46, -425), (fx, fy - 40), side * -14, 58, G3, boil)
            # pinstripe hint
            c.drawLine(side * 46, -415, fx, fy - 50, stroke(G4, 2))
            # shoe: black toe/heel, white saddle
            shoe = skia.Path(); shoe.addOval(skia.Rect.MakeLTRB(fx - 34 + side * 18, fy - 46, fx + 34 + side * 40, fy + 6))
            inked(c, shoe, G1, sw, boil)
            sad = skia.Path(); sad.addOval(skia.Rect.MakeLTRB(fx - 8 + side * 14, fy - 42, fx + 22 + side * 20, fy - 4))
            inked(c, sad, WHITE, 4)

    # ---- torso (double-breasted suit)
    torso = skia.Path()
    torso.moveTo(-150, -715)
    torso.cubicTo(-160, -745, -120, -752, -60, -748)
    torso.lineTo(60, -748)
    torso.cubicTo(120, -752, 160, -745, 150, -715)
    torso.lineTo(118, -470)
    torso.lineTo(132, -410)
    torso.lineTo(8, -400)
    torso.lineTo(0, -430)
    torso.lineTo(-8, -400)
    torso.lineTo(-132, -410)
    torso.lineTo(-118, -470)
    torso.close()
    c.drawPath(torso, fill(G3))
    c.save(); c.clipPath(torso, doAntiAlias=True)
    for xx in range(-170, 180, 20):
        c.drawLine(xx, -760, xx + 6, -395, stroke(G4, 2.2))
    c.restore()
    c.drawPath(torso, stroke(INK, sw, boil=boil))
    # shirt V
    inked(c, path_poly([(-48, -745), (48, -745), (0, -600)]), WHITE, 5, boil)
    # lapels
    inked(c, path_poly([(-60, -748), (-48, -745), (0, -600), (-30, -560), (-64, -660), (-90, -690)]), G2, 5, boil)
    inked(c, path_poly([(60, -748), (48, -745), (0, -600), (30, -560), (64, -660), (90, -690)]), G2, 5, boil)
    for bx, by in ((-30, -540), (30, -540), (-30, -488), (30, -488)):
        c.drawCircle(bx, by, 9, fill(G1)); c.drawCircle(bx, by, 9, stroke(INK, 3))
    # pocket square
    inked(c, path_poly([(70, -640), (110, -644), (104, -620), (72, -618)]), WHITE, 4)
    # bow tie
    inked(c, path_poly([(0, -735), (-46, -758), (-48, -706)]), G1, 5, boil)
    inked(c, path_poly([(0, -735), (46, -758), (48, -706)]), G1, 5, boil)
    knot = skia.Path(); knot.addRRect(skia.RRect.MakeRectXY(skia.Rect.MakeLTRB(-13, -748, 13, -722), 6, 6))
    inked(c, knot, G2, 5)

    # ---- arms
    SL, SR = (-138, -706), (138, -706)
    arm_targets = {
        "hips":    (((-150, -470), 40, "fist", 120), ((150, -470), -40, "fist", 60)),
        "whisper": (((-150, -470), 40, "fist", 120), ((58, -835), -60, "open", 200)),
        "wide":    (((-300, -930), 50, "open", -130), ((300, -930), -50, "open", -50)),
        "shrug":   (((-250, -760), 60, "open", -150), ((250, -760), -60, "open", -30)),
        "point":   (((-150, -470), 40, "fist", 120), ((330, -760), -30, "point", -10)),
        "present": (((-150, -470), 40, "fist", 120), ((300, -640), -50, "open", -20)),
        "hold":    (((-90, -560), 60, "open", 30), ((90, -560), -60, "open", 150)),
        "wave":    (((-150, -470), 40, "fist", 120), ((250, -980), -40, "open", -80)),
        "think":   (((-150, -470), 40, "fist", 120), ((40, -800), -80, "fist", 200)),
    }
    if arms == "walk":
        sw_ = math.sin((walk or 0) * 2 * math.pi) * 70
        arm_targets["walk"] = (((-170 - sw_ * 0.3, -470 + abs(sw_) * 0.2), 30, "fist", 100 + sw_ * 0.3),
                               ((170 + sw_ * 0.3, -470 + abs(sw_) * 0.2), -30, "fist", 80 + sw_ * 0.3))
    (lt, lb, lk, la), (rt, rb, rk, ra) = arm_targets.get(arms, arm_targets["hips"])
    wob = math.sin(t * 6.0) * 6
    lt = (lt[0], lt[1] + wob * (0 if arms == "hips" else 1))
    rt = (rt[0], rt[1] - wob * (0 if arms in ("hips", "whisper") else 1))
    noodle(c, SL, lt, lb, 50, G3, boil)
    noodle(c, SR, rt, rb, 50, G3, boil)
    draw_glove(c, lt[0], lt[1], la, lk, 1.05, boil)
    draw_glove(c, rt[0], rt[1], ra, rk, 1.05, boil)
    if stick:
        ang = math.radians(ra)
        sx, sy = rt[0] + math.cos(ang) * 40, rt[1] + math.sin(ang) * 40
        ex, ey = sx + math.cos(ang) * 230, sy + math.sin(ang) * 230
        c.drawLine(sx, sy, ex, ey, stroke(INK, 16)); c.drawLine(sx, sy, ex, ey, stroke(G5, 8))
        c.drawCircle(ex, ey, 7, fill(WHITE)); c.drawCircle(ex, ey, 7, stroke(INK, 3))

    # ---- head: price tag
    c.save(); c.translate(0, -755)
    hb = math.sin(t * 7.0) * 2.0
    c.rotate(hb * 0.6)
    tag = path_poly([(-125, 0), (-125, -290), (-70, -350), (70, -350), (125, -290), (125, 0)])
    c.drawPath(tag, fill("#e3e1da"))
    # paper fibre shading on one side
    c.save(); c.clipPath(tag, doAntiAlias=True)
    c.drawRect(skia.Rect.MakeLTRB(70, -360, 130, 10), fill(G6))
    c.restore()
    c.drawPath(tag, stroke(INK, sw + 1, boil=boil))
    # reinforcement ring + hole
    c.drawCircle(0, -300, 26, fill(G5)); c.drawCircle(0, -300, 26, stroke(INK, 4))
    c.drawCircle(0, -300, 13, fill(G1))
    # string cowlick
    sp = skia.Path(); sp.moveTo(0, -300)
    sway = math.sin(t * 3.1) * 12
    if string == "up":
        sp.cubicTo(-6, -380, 40 + sway, -440, 70 + sway, -400)
        sp.cubicTo(95 + sway, -370, 60 + sway, -330, 35 + sway, -360)
        sp.cubicTo(20 + sway, -380, 30 + sway, -420, 55 + sway, -430)
    elif string == "down":
        sp.cubicTo(-30, -330, -110, -320, -140 + sway * 0.3, -250)
        sp.cubicTo(-150, -220, -150, -190, -138, -170)
    else:  # knot
        sp.cubicTo(-30, -380, 30, -390, 20, -350)
        sp.cubicTo(5, -320, -35, -345, -10, -372)
        sp.cubicTo(15, -398, 45, -370, 30, -342)
        sp.cubicTo(18, -322, -5, -330, 5, -355)
    c.drawPath(sp, stroke(INK, 11)); c.drawPath(sp, stroke(G6, 5))

    # forehead price (green grease pencil) — only money is in colour
    if price:
        sz = 60 * (1 + 0.35 * price_pop)
        c.save(); c.translate(0, -232); c.rotate(-4)
        text(c, price, 0, sz * 0.36, sz, "marker", MONEY, outline=MONEY_D, ow=3)
        c.restore()

    # ---- face
    ex, ey = 52, -150
    lid = {"sly": 0.45, "proud": 0.35, "whisper": 0.5, "outrage": 0.15, "guilty": 0.3, "shock": 0.0}.get(expr, 0.4)
    if blink:
        lid = 1.0
    for side in (-1, 1):
        cx = side * ex
        eye = skia.Rect.MakeLTRB(cx - 19, ey - 26, cx + 19, ey + 26)
        c.drawOval(eye, fill(WHITE))
        px, py = cx + look[0] * 6 + side * 2, ey + 6 + look[1] * 6
        # pie-cut pupil
        pup = skia.Path(); pup.addOval(skia.Rect.MakeLTRB(px - 9, py - 13, px + 9, py + 13))
        c.drawPath(pup, fill(INK))
        c.drawPath(path_poly([(px + 2, py - 13), (px + 9, py - 11), (px + 4, py - 3)]), fill(WHITE))
        if lid > 0:
            c.save(); c.clipRect(skia.Rect.MakeLTRB(cx - 22, ey - 28, cx + 22, ey - 26 + 52 * lid), doAntiAlias=True)
            c.drawOval(eye, fill(G4))
            c.restore()
            c.drawLine(cx - 19, ey - 26 + 52 * lid, cx + 19, ey - 26 + 52 * lid, stroke(INK, 4))
        c.drawOval(eye, stroke(INK, 5, boil=boil))
        # brows
        bt = {"sly": (8, -6), "proud": (4, -2), "whisper": (6, -4), "outrage": (-16, 14), "guilty": (16, -14), "shock": (18, 0)}.get(expr, (6, -4))
        inner, outer = bt
        c.drawLine(cx - side * 22, ey - 44 - inner * (1 if side < 0 else 1) * 0.6, cx + side * 22, ey - 44 - outer * 0.6,
                   stroke(INK, 8))
    # nose hint
    c.drawArc(skia.Rect.MakeLTRB(-10, -120, 14, -96), 300, 160, False, stroke(INK, 4))

    # mouth
    mx, my = 0, -70
    if mouth == "grin":
        mp = skia.Path(); mp.moveTo(-62, my - 12)
        mp.cubicTo(-30, my - 4, 30, my - 4, 62, my - 12)
        mp.cubicTo(42, my + 36, -42, my + 36, -62, my - 12); mp.close()
        c.drawPath(mp, fill(G1))
        c.save(); c.clipPath(mp, doAntiAlias=True)
        c.drawRect(skia.Rect.MakeLTRB(-70, my - 20, 70, my + 6), fill(WHITE))
        c.drawRect(skia.Rect.MakeLTRB(14, my - 20, 32, my + 7), fill(MONEY))   # the gold tooth is money
        c.drawLine(14, my - 20, 14, my + 7, stroke(INK, 2)); c.drawLine(32, my - 20, 32, my + 7, stroke(INK, 2))
        c.restore()
        c.drawPath(mp, stroke(INK, 5, boil=boil))
    elif mouth in ("A", "outrage"):
        h = 58 if mouth == "A" else 66
        w = 44 if mouth == "A" else 58
        mp = skia.Path(); mp.addOval(skia.Rect.MakeLTRB(-w, my - 20, w, my - 20 + h))
        c.drawPath(mp, fill(G1))
        c.save(); c.clipPath(mp, doAntiAlias=True)
        c.drawRect(skia.Rect.MakeLTRB(-w, my - 22, w, my - 8), fill(WHITE))
        c.drawRect(skia.Rect.MakeLTRB(10, my - 22, 26, my - 6), fill(MONEY))
        c.drawOval(skia.Rect.MakeLTRB(-24, my + h - 44, 24, my + h - 6), fill(G4))
        c.restore()
        c.drawPath(mp, stroke(INK, 5, boil=boil))
    elif mouth == "E":
        mp = skia.Path(); mp.addRRect(skia.RRect.MakeRectXY(skia.Rect.MakeLTRB(-54, my - 16, 54, my + 16), 16, 16))
        c.drawPath(mp, fill(G1))
        c.save(); c.clipPath(mp, doAntiAlias=True)
        c.drawRect(skia.Rect.MakeLTRB(-60, my - 18, 60, my - 2), fill(WHITE))
        c.drawRect(skia.Rect.MakeLTRB(12, my - 18, 28, my - 1), fill(MONEY))
        c.restore()
        c.drawPath(mp, stroke(INK, 5, boil=boil))
    elif mouth == "O":
        mp = skia.Path(); mp.addOval(skia.Rect.MakeLTRB(-22, my - 18, 22, my + 26))
        inked(c, mp, G1, 5, boil)
    elif mouth == "guilty":
        mp = skia.Path(); mp.moveTo(-50, my)
        for i in range(1, 6):
            mp.lineTo(-50 + i * 20, my + (8 if i % 2 else -6))
        c.drawPath(mp, stroke(INK, 6))
    else:  # closed smirk
        mp = skia.Path(); mp.moveTo(-50, my - 8); mp.cubicTo(-20, my + 10, 30, my + 8, 56, my - 16)
        c.drawPath(mp, stroke(INK, 7))
        c.drawLine(52, my - 22, 60, my - 10, stroke(INK, 5))
    c.restore()  # head
    c.restore()


# ------------------------------------------------------------------ FOOTNOTE (walking asterisk)
def draw_footnote(c, x, y, s, t=0.0, mouth="closed", boil=None, hold_card=False, glass=True, blink=False):
    c.save(); c.translate(x, y); c.scale(s, s)
    sw = 6
    cy = -230
    # legs + spats
    for side in (-1, 1):
        noodle(c, (side * 16, cy + 60), (side * 40, -22), side * 10, 14, INK, boil, ow=0)
        spat = skia.Path(); spat.addRRect(skia.RRect.MakeRectXY(skia.Rect.MakeLTRB(side * 40 - 16, -40, side * 40 + 16, -16), 6, 6))
        inked(c, spat, WHITE, 4)
        shoe = skia.Path(); shoe.addOval(skia.Rect.MakeLTRB(side * 40 - 22 + side * 8, -22, side * 40 + 22 + side * 8, 4))
        inked(c, shoe, G1, 4)
    # spokes
    spin = math.sin(t * 2.0) * 4
    for k in range(6):
        a = math.radians(90 + k * 60 + spin)
        ex, ey = math.cos(a) * 112, cy - math.sin(a) * 112
        c.drawLine(0, cy, ex, ey, stroke(INK, 58))
        c.drawLine(0, cy, ex, ey, stroke(G1, 44))
    # face plate
    c.drawCircle(0, cy, 62, fill(WHITE)); c.drawCircle(0, cy, 62, stroke(INK, sw, boil=boil))
    # visor (grey — only money gets colour)
    vis = skia.Path(); vis.moveTo(-66, cy - 30); vis.cubicTo(-30, cy - 70, 30, cy - 70, 66, cy - 30)
    vis.lineTo(80, cy - 20); vis.cubicTo(30, cy - 50, -30, cy - 50, -80, cy - 20); vis.close()
    inked(c, vis, G3, 4)
    # glasses
    for side in (-1, 1):
        c.drawCircle(side * 24, cy - 4, 19, fill(WHITE))
        if blink:
            c.drawLine(side * 24 - 9, cy - 4, side * 24 + 9, cy - 4, stroke(INK, 4))
        else:
            c.drawCircle(side * 24 + 2, cy - 2, 6, fill(INK))
        c.drawCircle(side * 24, cy - 4, 19, stroke(INK, 4))
    c.drawLine(-6, cy - 6, 6, cy - 6, stroke(INK, 4))
    # mouth
    if mouth == "open":
        c.drawOval(skia.Rect.MakeLTRB(-11, cy + 26, 11, cy + 44), fill(G1))
    else:
        c.drawLine(-14, cy + 34, 14, cy + 32, stroke(INK, 4))
    # magnifying glass in right spoke hand
    if glass:
        hx, hy = 112 * math.cos(math.radians(-30)), cy + 56
        c.drawLine(hx, hy, hx + 40, hy - 50, stroke(INK, 12))
        c.drawCircle(hx + 58, hy - 74, 32, fill(WHITE, 140)); c.drawCircle(hx + 58, hy - 74, 32, stroke(INK, 7))
        c.drawArc(skia.Rect.MakeLTRB(hx + 36, hy - 96, hx + 70, hy - 62), 200, 60, False, stroke(WHITE, 4))
    c.restore()


# ------------------------------------------------------------------ WALLY (silent wallet)
def draw_wally(c, x, y, s, thick=1.0, t=0.0, boil=None, expr="nervous", flat=0.0, walk=None):
    c.save(); c.translate(x, y); c.scale(s, s)
    hgt = 150 * thick * (1 - 0.75 * flat) + 18
    wid = 230 * (1 + 0.35 * flat)
    by = -70 if flat < 0.5 else -26
    # legs
    if flat < 0.6:
        ph = (walk or 0) * 2 * math.pi
        for side in (-1, 1):
            fx = side * 44 + (side * 18 * math.sin(ph) if walk is not None else 0)
            noodle(c, (side * 40, by), (fx, -10), side * 8, 12, INK, boil, ow=0)
            sh = skia.Path(); sh.addOval(skia.Rect.MakeLTRB(fx - 24 + side * 6, -22, fx + 24 + side * 6, 4))
            inked(c, sh, WHITE, 4)
    # bills peeking out (green — money)
    nb = max(0, int(round(3 * thick))) if flat < 0.5 else 0
    for i in range(nb):
        bx = -70 + i * 50
        r = skia.Rect.MakeLTRB(bx, by - hgt - 46 + i * 6, bx + 110, by - hgt + 30)
        c.save(); c.rotate(-8 + i * 7, bx + 55, by - hgt)
        p = skia.Path(); p.addRect(r)
        inked(c, p, MONEY, 4)
        c.drawRect(skia.Rect.MakeLTRB(r.left() + 8, r.top() + 8, r.right() - 8, r.bottom() - 8), stroke(MONEY_D, 3))
        text(c, "$", r.centerX(), r.top() + 42, 34, "slab", MONEY_D)
        c.restore()
    body = skia.Path(); body.addRRect(skia.RRect.MakeRectXY(skia.Rect.MakeLTRB(-wid / 2, by - hgt, wid / 2, by), 26, 26))
    inked(c, body, "#3a3a3a", 7, boil)
    st = stroke(G5, 3); st.setPathEffect(skia.DashPathEffect.Make([10, 8], 0))
    inner = skia.Path(); inner.addRRect(skia.RRect.MakeRectXY(skia.Rect.MakeLTRB(-wid / 2 + 12, by - hgt + 12, wid / 2 - 12, by - 12), 18, 18))
    c.drawPath(inner, st)
    c.drawLine(0, by - hgt + 6, 0, by - 6, stroke("#262626", 5))
    # face
    fy = by - hgt * 0.55
    if flat < 0.5:
        for side in (-1, 1):
            r = skia.Rect.MakeLTRB(side * 46 - 18, fy - 24, side * 46 + 18, fy + 24)
            c.drawOval(r, fill(WHITE)); c.drawOval(r, stroke(INK, 4))
            c.drawOval(skia.Rect.MakeLTRB(side * 46 - 8, fy - 6, side * 46 + 8, fy + 16), fill(INK))
            c.drawPath(path_poly([(side * 46 + 1, fy - 6), (side * 46 + 8, fy - 3), (side * 46 + 3, fy + 4)]), fill(WHITE))
            if expr == "nervous":
                c.drawLine(side * 46 - 18, fy - 34 - side * 4, side * 46 + 18, fy - 34 + side * 4, stroke(G6, 5))
        mp = skia.Path(); mp.moveTo(-26, fy + 42)
        for i in range(1, 5):
            mp.lineTo(-26 + i * 13, fy + 42 + (6 if i % 2 else -4))
        c.drawPath(mp, stroke(G6, 4))
        # sweat drop
        if expr == "nervous":
            d = skia.Path(); d.moveTo(wid / 2 - 30, fy - 50); d.quadTo(wid / 2 - 16, fy - 26, wid / 2 - 30, fy - 20)
            d.quadTo(wid / 2 - 44, fy - 26, wid / 2 - 30, fy - 50); inked(c, d, WHITE, 3)
    else:
        for side in (-1, 1):  # x_x flattened eyes
            cx = side * 50
            c.drawLine(cx - 12, fy - 8, cx + 12, fy + 8, stroke(G6, 5)); c.drawLine(cx - 12, fy + 8, cx + 12, fy - 8, stroke(G6, 5))
    c.restore()


# ------------------------------------------------------------------ PROPS
def draw_bill(c, x, y, s=1.0, ang=0.0, boil=None):
    c.save(); c.translate(x, y); c.rotate(ang); c.scale(s, s)
    r = skia.Rect.MakeLTRB(-60, -30, 60, 30)
    p = skia.Path(); p.addRect(r)
    inked(c, p, MONEY, 4, boil)
    c.drawRect(skia.Rect.MakeLTRB(-52, -22, 52, 22), stroke(MONEY_D, 3))
    c.drawCircle(0, 0, 15, fill(MONEY_L)); c.drawCircle(0, 0, 15, stroke(MONEY_D, 3))
    text(c, "$", 0, 11, 28, "slab", MONEY_D)
    c.restore()


def draw_coin(c, x, y, s=1.0):
    c.drawCircle(x, y, 22 * s, fill(MONEY)); c.drawCircle(x, y, 22 * s, stroke(INK, 4))
    c.drawCircle(x, y, 15 * s, stroke(MONEY_D, 3))


def draw_popcorn(c, x, y, s=1.0, t=0.0, boil=None, face=False, label=True, mouth="grin", dance=0.0, price=None, seed=3, tag_side=1):
    c.save(); c.translate(x, y)
    if dance:
        c.rotate(math.sin(t * 8) * 6 * dance)
        c.scale(s * (1 + 0.04 * math.sin(t * 16) * dance), s * (1 - 0.04 * math.sin(t * 16) * dance))
    else:
        c.scale(s, s)
    H, BW, TW = 300, 190, 270
    body = path_poly([(-BW / 2, 0), (BW / 2, 0), (TW / 2, -H), (-TW / 2, -H)])
    c.save(); c.clipPath(body, doAntiAlias=True)
    c.drawPath(body, fill(WHITE))
    for i in range(-6, 7):
        if i % 2 == 0:
            continue
        x0b, x0t = i * BW / 10, i * TW / 10
        stripe = path_poly([(x0b - BW / 20, 0), (x0b + BW / 20, 0), (x0t + TW / 20, -H), (x0t - TW / 20, -H)])
        c.drawPath(stripe, fill(G4))
    c.restore()
    c.drawPath(body, stroke(INK, 7, boil=boil))
    # popcorn heap (white puffs)
    import random
    rnd = random.Random(seed)
    puffs = []
    for i in range(22):
        px = rnd.uniform(-TW / 2 + 20, TW / 2 - 20)
        py = -H - rnd.uniform(-5, 70) * (1 - abs(px) / (TW / 2) * 0.6)
        puffs.append((px, py, rnd.uniform(24, 36)))
    puffs.sort(key=lambda q: q[1])
    for px, py, r in puffs:
        pf = skia.Path()
        for k in range(4):
            a = k * math.pi / 2 + rnd.random()
            pf.addCircle(px + math.cos(a) * r * 0.45, py + math.sin(a) * r * 0.45, r * 0.62)
        pf.setFillType(skia.PathFillType.kWinding)
        c.drawPath(pf, fill(WHITE)); c.drawPath(pf, stroke(INK, 4))
        c.drawCircle(px + r * 0.2, py + r * 0.1, r * 0.18, fill(G6))
    # rim
    rim = skia.Path(); rim.addRRect(skia.RRect.MakeRectXY(skia.Rect.MakeLTRB(-TW / 2 - 8, -H - 6, TW / 2 + 8, -H + 20), 8, 8))
    inked(c, rim, G5, 6, boil)
    if label:
        lab = skia.Path(); lab.addOval(skia.Rect.MakeLTRB(-95, -205, 95, -125))
        inked(c, lab, WHITE, 5)
        text(c, "POPCORN", 0, -152, 34, "slab", INK)
    if face:
        for side in (-1, 1):
            r = skia.Rect.MakeLTRB(side * 40 - 16, -112, side * 40 + 16, -70)
            c.drawOval(r, fill(WHITE)); c.drawOval(r, stroke(INK, 4))
            c.drawOval(skia.Rect.MakeLTRB(side * 40 - 6, -98, side * 40 + 8, -76), fill(INK))
        mp = skia.Path(); mp.moveTo(-30, -52); mp.cubicTo(-10, -30, 10, -30, 30, -52)
        if mouth == "grin":
            mp.close(); inked(c, mp, G1, 4)
        else:
            c.drawPath(mp, stroke(INK, 5))
    if price:
        draw_tag(c, tag_side * (TW / 2 - 10), -H + 50, 0.9, price, t, side=tag_side)
    c.restore()


def draw_tag(c, x, y, s, label, t=0.0, ang=12, side=1):
    c.save(); c.translate(x, y); c.rotate(side * ang + math.sin(t * 4) * 3); c.scale(s, s)
    c.drawLine(0, 0, side * 30, 30, stroke(INK, 4))
    tw = max(130, text_width(label, 40, "marker") + 50)
    tag = path_poly([(side * 30, 20), (side * (30 + tw), 20), (side * (30 + tw), 100), (side * 30, 100), (side * 10, 60)])
    inked(c, tag, "#e3e1da", 5)
    c.drawCircle(side * 28, 60, 6, fill(G1))
    text(c, label, side * (30 + tw / 2 + 8), 76, 40, "marker", MONEY, outline=MONEY_D, ow=2)
    c.restore()


def draw_soda(c, x, y, s=1.0, t=0.0, boil=None, cutaway=0.0, label=True):
    c.save(); c.translate(x, y); c.scale(s, s)
    H, BW, TW = 320, 150, 200
    body = path_poly([(-BW / 2, 0), (BW / 2, 0), (TW / 2, -H), (-TW / 2, -H)])
    c.drawPath(body, fill(WHITE))
    c.save(); c.clipPath(body, doAntiAlias=True)
    for k in range(4):
        wv = skia.Path(); yy = -60 - k * 70
        wv.moveTo(-120, yy)
        for i in range(8):
            wv.quadTo(-105 + i * 30, yy - 18, -90 + i * 30, yy)
        c.drawPath(wv, stroke(G4, 14))
    if cutaway > 0:
        a = int(255 * min(1, cutaway))
        c.drawRect(skia.Rect.MakeLTRB(-120, -H, 120, 0), fill("#1c1c1c", a))
        # syrup at bottom (dark), ice cubes above
        c.drawRect(skia.Rect.MakeLTRB(-120, -70, 120, 0), fill(G2, a))
        import random
        rnd = random.Random(5)
        for i in range(9):
            cx, cy = rnd.uniform(-70, 70), -90 - i * 26 - rnd.uniform(0, 10)
            c.save(); c.translate(cx, cy); c.rotate(rnd.uniform(-25, 25))
            cube = skia.Rect.MakeLTRB(-30, -26, 30, 26)
            c.drawRoundRect(cube, 8, 8, fill(G6, a)); c.drawRoundRect(cube, 8, 8, stroke(INK, 4, a))
            c.drawLine(-18, -14, -4, -18, stroke(WHITE, 4, a))
            c.restore()
    c.restore()
    c.drawPath(body, stroke(INK, 7, boil=boil))
    lid = skia.Path(); lid.addRRect(skia.RRect.MakeRectXY(skia.Rect.MakeLTRB(-TW / 2 - 10, -H - 22, TW / 2 + 10, -H + 6), 10, 10))
    inked(c, lid, G5, 6)
    c.drawLine(18, -H - 20, 50, -H - 140, stroke(INK, 22)); c.drawLine(18, -H - 20, 50, -H - 140, stroke(WHITE, 12))
    if label and cutaway < 0.5:
        lab = skia.Path(); lab.addOval(skia.Rect.MakeLTRB(-70, -200, 70, -140))
        inked(c, lab, WHITE, 5)
        text(c, "SODA", 0, -158, 34, "slab", INK)
    c.restore()


# ------------------------------------------------------------------ BACKGROUNDS (static → cached)
W, H = 1080, 1920


def bg_stage(c, spot=True):
    c.drawRect(skia.Rect.MakeWH(W, H), fill("#1d1d1d"))
    # curtains
    for i in range(0, W + 90, 90):
        g = skia.GradientShader.MakeLinear([skia.Point(i, 0), skia.Point(i + 90, 0)],
                                           [hexc("#2c2c2c"), hexc("#6a6a6a"), hexc("#2c2c2c")])
        p = skia.Paint(AntiAlias=True, Shader=g)
        c.drawRect(skia.Rect.MakeLTRB(i, 0, i + 90, 1500), p)
    # valance
    val = skia.Path(); val.moveTo(0, 0); val.lineTo(W, 0); val.lineTo(W, 170)
    for i in range(12, -1, -1):
        val.quadTo(i * 90 + 45, 230, i * 90, 170)
    val.close()
    inked(c, val, "#3a3a3a", 6)
    for i in range(0, W, 30):
        c.drawCircle(i + 15, 196 if (i // 30) % 3 else 214, 7, fill(G5))
    # floor boards
    c.drawRect(skia.Rect.MakeLTRB(0, 1500, W, H), fill("#5b5b5b"))
    for yy in range(1500, H, 70):
        c.drawLine(0, yy, W, yy, stroke("#3f3f3f", 4))
    for k in range(-6, 8):
        c.drawLine(W / 2 + k * 70, 1500, W / 2 + k * 260, H, stroke("#474747", 3))
    c.drawLine(0, 1500, W, 1500, stroke(INK, 8))
    if spot:
        g = skia.GradientShader.MakeRadial(skia.Point(W / 2, 1580), 620,
                                           [hexc("#ffffff", 120), hexc("#ffffff", 40), hexc("#ffffff", 0)], [0, 0.6, 1])
        c.drawOval(skia.Rect.MakeLTRB(W / 2 - 560, 1440, W / 2 + 560, 1730), skia.Paint(AntiAlias=True, Shader=g))
        cone = path_poly([(W / 2 - 80, 0), (W / 2 + 80, 0), (W / 2 + 520, 1590), (W / 2 - 520, 1590)])
        g2 = skia.GradientShader.MakeLinear([skia.Point(0, 0), skia.Point(0, 1590)], [hexc("#ffffff", 10), hexc("#ffffff", 60)])
        c.drawPath(cone, skia.Paint(AntiAlias=True, Shader=g2))


BULBS = [(130 + i * 32.5, by) for i in range(26) for by in (232, 718)]


def bg_counter(c, part="all", rot=0.0):
    if part in ("all", "back", "wall"):
        c.drawRect(skia.Rect.MakeWH(W, H), fill("#cfcfcb"))
        cx, cy = W / 2, 470
        for k in range(36):
            a0, a1 = k * 10 + rot, k * 10 + 5 + rot
            p = skia.Path(); p.moveTo(cx, cy)
            p.lineTo(cx + 1600 * math.cos(math.radians(a0)), cy + 1600 * math.sin(math.radians(a0)))
            p.lineTo(cx + 1600 * math.cos(math.radians(a1)), cy + 1600 * math.sin(math.radians(a1)))
            p.close(); c.drawPath(p, fill("#bdbdb8"))
    if part in ("all", "back", "board"):
        board = skia.Rect.MakeLTRB(110, 250, 970, 700)
        c.drawRoundRect(board, 24, 24, fill("#1c1c1c")); c.drawRoundRect(board, 24, 24, stroke(INK, 10))
        for bx, by in BULBS:
            c.drawCircle(bx, by, 9, fill(WHITE)); c.drawCircle(bx, by, 9, stroke(INK, 3))
        text(c, "SNACK BAR", W / 2, 360, 96, "deco", WHITE)
        c.drawLine(180, 392, 900, 392, stroke(G4, 4))
        rows = [("POPCORN", "S  M  L"), ("SODA", "S  M  L"), ("CANDY", "")]
        for i, (a, b) in enumerate(rows):
            text(c, a, 200, 470 + i * 78, 54, "slab", G6, align="left")
            if b:
                text(c, b, 880, 470 + i * 78, 54, "slab", G5, align="right")
    if part in ("all", "front"):
        c.drawRect(skia.Rect.MakeLTRB(0, 1240, W, H), fill("#454545"))
        for yy, col in ((1300, "#8f8f8f"), (1318, "#e2e2e2"), (1500, "#8f8f8f"), (1518, "#e2e2e2")):
            c.drawRect(skia.Rect.MakeLTRB(0, yy, W, yy + 14), fill(col))
        for xx in range(60, W, 180):
            c.drawRect(skia.Rect.MakeLTRB(xx, 1560, xx + 120, 1880), fill("#3a3a3a"))
            c.drawRect(skia.Rect.MakeLTRB(xx, 1560, xx + 120, 1880), stroke("#2a2a2a", 4))
        top = skia.Rect.MakeLTRB(-20, 1190, W + 20, 1250)
        c.drawRect(top, fill("#e9e9e6")); c.drawRect(top, stroke(INK, 8))
        c.drawRect(skia.Rect.MakeLTRB(0, 1250, W, 1262), fill("#262626"))


def bg_vault(c, wheel=True):
    c.drawRect(skia.Rect.MakeWH(W, H), fill("#bcbcb7"))
    for yy in range(0, 1500, 60):  # brick rows
        off = 0 if (yy // 60) % 2 else 60
        for xx in range(-off, W, 120):
            c.drawRect(skia.Rect.MakeLTRB(xx + 4, yy + 4, xx + 116, yy + 56), fill("#b0b0ab"))
    c.drawRect(skia.Rect.MakeLTRB(0, 1500, W, H), fill("#6b6b6b"))
    c.drawLine(0, 1500, W, 1500, stroke(INK, 8))
    # vault door
    cx, cy, r = 760, 1060, 270
    c.drawCircle(cx, cy, r + 40, fill("#5a5a5a")); c.drawCircle(cx, cy, r + 40, stroke(INK, 9))
    c.drawCircle(cx, cy, r, fill("#8d8d8d")); c.drawCircle(cx, cy, r, stroke(INK, 8))
    for k in range(16):
        a = k * math.pi / 8
        c.drawCircle(cx + math.cos(a) * (r - 30), cy + math.sin(a) * (r - 30), 12, fill(G5))
        c.drawCircle(cx + math.cos(a) * (r - 30), cy + math.sin(a) * (r - 30), 12, stroke(INK, 3))
    if wheel:
        draw_vault_wheel(c, 0.0)
    if False:
      for k in range(3):
        a = k * math.pi / 3
        c.drawLine(cx - math.cos(a) * 110, cy - math.sin(a) * 110, cx + math.cos(a) * 110, cy + math.sin(a) * 110, stroke(INK, 18))
        c.drawLine(cx - math.cos(a) * 110, cy - math.sin(a) * 110, cx + math.cos(a) * 110, cy + math.sin(a) * 110, stroke(G6, 8))
    plate = skia.Rect.MakeLTRB(cx - 110, cy - r - 150, cx + 190, cy - r - 50)
    c.drawRoundRect(plate, 12, 12, fill("#2a2a2a")); c.drawRoundRect(plate, 12, 12, stroke(INK, 7))
    text(c, "STUDIO", cx + 40, cy - r - 78, 66, "deco", WHITE)
    # ticket booth
    bx0, bx1, by0, by1 = 60, 400, 820, 1500
    c.drawRect(skia.Rect.MakeLTRB(bx0, by0, bx1, by1), fill("#7a7a7a")); c.drawRect(skia.Rect.MakeLTRB(bx0, by0, bx1, by1), stroke(INK, 8))
    roof = path_poly([(bx0 - 30, by0), (bx1 + 30, by0), (bx1, by0 - 70), (bx0, by0 - 70)])
    inked(c, roof, "#3c3c3c", 7)
    text(c, "TICKETS", (bx0 + bx1) / 2, by0 - 18, 56, "deco", WHITE)
    win = skia.Rect.MakeLTRB(bx0 + 40, by0 + 60, bx1 - 40, by0 + 300)
    c.drawRoundRect(win, 60, 60, fill("#e8e8e4")); c.drawRoundRect(win, 60, 60, stroke(INK, 6))
    c.drawRect(skia.Rect.MakeLTRB(bx0 + 70, by0 + 300, bx1 - 70, by0 + 330), fill(G2))


VAULT_PIPE = [(400, 752), (400, 560), (430, 470), (500, 470), (600, 470), (620, 600), (600, 800)]


def pipe_path():
    p = skia.Path(); p.moveTo(*VAULT_PIPE[0])
    pts = VAULT_PIPE
    for i in range(1, len(pts) - 1, 2):
        p.quadTo(*pts[i], *pts[i + 1])
    return p


def draw_pipe(c, boil=None):
    p = pipe_path()
    c.drawPath(p, stroke(INK, 96)); c.drawPath(p, stroke("#f4f4f0", 80, a=200))
    c.drawPath(p, stroke(WHITE, 10, a=180))


def bg_grid(c, title=None):
    c.drawRect(skia.Rect.MakeWH(W, H), fill("#e4e4df"))
    for xx in range(0, W, 45):
        c.drawLine(xx, 0, xx, H, stroke("#cfcfca", 2))
    for yy in range(0, H, 45):
        c.drawLine(0, yy, W, yy, stroke("#cfcfca", 2))
    for xx in range(0, W, 225):
        c.drawLine(xx, 0, xx, H, stroke("#bdbdb8", 3))
    for yy in range(0, H, 225):
        c.drawLine(0, yy, W, yy, stroke("#bdbdb8", 3))
    c.drawRect(skia.Rect.MakeLTRB(0, 1520, W, H), fill("#9c9c97"))
    c.drawLine(0, 1520, W, 1520, stroke(INK, 8))
    if title:
        text(c, title, W / 2, 560, 92, "deco", INK)


def bg_boardroom(c):
    c.drawRect(skia.Rect.MakeWH(W, H), fill("#262626"))
    # window with blinds
    win = skia.Rect.MakeLTRB(160, 260, 920, 900)
    c.drawRect(win, fill("#8c8c8c"))
    for yy in range(270, 900, 34):
        c.drawRect(skia.Rect.MakeLTRB(160, yy, 920, yy + 18), fill("#b9b9b9"))
    c.drawRect(win, stroke(INK, 12))
    # city skyline in window
    for i, (x0, h0) in enumerate(((180, 320), (300, 420), (430, 260), (520, 470), (650, 300), (760, 390), (860, 250))):
        c.drawRect(skia.Rect.MakeLTRB(x0, 900 - h0, x0 + 90, 900), fill("#5e5e5e", 150))
    # table
    tab = path_poly([(60, 1380), (1020, 1380), (1080, 1560), (0, 1560)])
    inked(c, tab, "#4a4a4a", 8)
    c.drawRect(skia.Rect.MakeLTRB(0, 1560, W, H), fill("#1a1a1a"))


def draw_fat_cat(c, x, y, s, t=0.0, puff=0.0):
    """Silhouetted top-hatted boardroom executive (generic, not any real person)."""
    c.save(); c.translate(x, y); c.scale(s, s)
    body = skia.Path(); body.moveTo(-120, 0); body.cubicTo(-130, -160, -80, -230, 0, -230)
    body.cubicTo(80, -230, 130, -160, 120, 0); body.close()
    c.drawPath(body, fill("#0c0c0c"))
    c.drawCircle(0, -290, 78, fill("#0c0c0c"))
    for side in (-1, 1):  # cat ears
        c.drawPath(path_poly([(side * 30, -350), (side * 70, -400), (side * 76, -320)]), fill("#0c0c0c"))
    c.drawRect(skia.Rect.MakeLTRB(-62, -470, 62, -350), fill("#0c0c0c"))
    c.drawRect(skia.Rect.MakeLTRB(-96, -360, 96, -338), fill("#0c0c0c"))
    c.drawRect(skia.Rect.MakeLTRB(-62, -390, 62, -372), fill(G2))
    for side in (-1, 1):  # glinting eyes
        c.drawOval(skia.Rect.MakeLTRB(side * 34 - 14, -306, side * 34 + 14, -290), fill(WHITE))
    c.drawLine(40, -262, 120, -276, stroke(G5, 12))
    c.drawCircle(124, -277, 6, fill(WHITE))
    for k in range(3):
        rr = 18 + k * 10 + puff * 20
        c.drawCircle(140 + k * 22 + puff * 40, -300 - k * 40 - puff * 80, rr, fill(G4, int(120 - k * 30)))
    c.restore()


# ------------------------------------------------------------------ OVERLAYS
def draw_receipt(c, x, y, lines, shown, total=None, total_reveal=0.0, w=390, torn=0.0, title="RACKET #001", total_label="MARKUP", scale=1.0):
    """Receipt printing from the top. `shown` = how many lines are visible (float for typing)."""
    lh = 38
    nshow = int(math.floor(shown))
    rows = 3 + nshow + 2
    h = 30 + rows * lh + 20
    c.save(); c.translate(x, y + torn * 2400); c.rotate(torn * 25); c.scale(scale, scale)
    body = skia.Path(); body.moveTo(0, 0); body.lineTo(w, 0); body.lineTo(w, h)
    zz = 14
    for i in range(int(w / zz), -1, -1):
        body.lineTo(i * zz, h + (8 if i % 2 else 0))
    body.close()
    sh = skia.Paint(AntiAlias=True, Color=hexc("#000000", 90))
    c.save(); c.translate(8, 8); c.drawPath(body, sh); c.restore()
    c.drawPath(body, fill("#f6f5f0")); c.drawPath(body, stroke(INK, 4))
    text(c, "MISTER MARKUP & CO.", w / 2, 40, 27, "monob", INK)
    text(c, title, w / 2, 72, 26, "mono", G2)
    c.drawLine(16, 88, w - 16, 88, stroke(G4, 2))
    yy = 88 + lh
    for i, (a, b) in enumerate(lines[:nshow]):
        text(c, a, 18, yy, 27, "mono", INK, align="left")
        if b:
            text(c, b, w - 18, yy, 27, "monob", MONEY_D if "$" in b or "%" in b or "X" in b else INK, align="right")
        yy += lh
    c.drawLine(16, yy - 18, w - 16, yy - 18, stroke(G4, 2))
    text(c, total_label, 18, yy + 16, 30, "monob", INK, align="left")
    if total and total_reveal > 0:
        sz = 34 * (1 + 0.8 * max(0.0, 1 - total_reveal))
        text(c, total, w - 18, yy + 16, sz, "monob", MONEY_D, align="right")
    else:
        text(c, "$???", w - 18, yy + 16, 28, "monob", G3, align="right")
    c.restore()
    return h


def draw_stamp(c, x, y, word, k=1.0, ang=-12, sub=None):
    """Rubber stamp slamming in. k: 0→1 animation progress."""
    if k <= 0:
        return
    sc = 1 + 2.2 * max(0.0, 1 - k / 0.35) if k < 0.35 else 1 + 0.06 * math.sin((k - 0.35) * 25) * math.exp(-(k - 0.35) * 6)
    a = int(255 * min(1, k / 0.2))
    c.save(); c.translate(x, y); c.rotate(ang); c.scale(sc, sc)
    font_sz = 150
    wd = text_width(word, font_sz, "bungee") + 80
    r = skia.Rect.MakeLTRB(-wd / 2, -120, wd / 2, 70 if not sub else 130)
    c.drawRoundRect(r, 18, 18, stroke(MONEY, 16, a))
    c.drawRoundRect(skia.Rect.MakeLTRB(r.left() + 16, r.top() + 16, r.right() - 16, r.bottom() - 16), 10, 10, stroke(MONEY, 5, a))
    text(c, word, 0, 36, font_sz, "bungee", MONEY, alpha=a)
    if sub:
        text(c, sub, 0, 104, 40, "anton", MONEY, alpha=a)
    c.restore()


def draw_card(c, x, y, lines, w=860, a=255, scale=1.0, size=40):
    c.save(); c.translate(x, y); c.scale(scale, scale)
    h = 40 + len(lines) * (size + 14)
    r = skia.Rect.MakeLTRB(-w / 2, 0, w / 2, h)
    c.drawRoundRect(skia.Rect.MakeLTRB(r.left() + 10, 10, r.right() + 10, h + 10), 14, 14, fill("#000000", int(a * 0.35)))
    c.drawRoundRect(r, 14, 14, fill("#f6f5f0", a)); c.drawRoundRect(r, 14, 14, stroke(INK, 6, a))
    yy = 20 + size
    for ln in lines:
        text(c, ln, 0, yy, size, "mono" if not ln.startswith("*") else "monob", INK, alpha=a)
        yy += size + 14
    c.restore()
    return h


def draw_caption(c, words, cx, cy, size=78, k=1.0, maxw=900):
    """words: list of (word, is_money). Centered, wraps to two lines, white w/ black outline, money words green."""
    font = skia.Font(TF["anton"], size)
    space = font.measureText(" ")
    lines, cur, curw = [], [], 0
    for wd, m in words:
        ww = font.measureText(wd)
        if cur and curw + space + ww > maxw:
            lines.append((cur, curw)); cur, curw = [], 0
        cur.append((wd, m, ww)); curw += (space if len(cur) > 1 else 0) + ww
    if cur:
        lines.append((cur, curw))
    sc = 0.85 + 0.15 * min(1, k)
    c.save(); c.translate(cx, cy); c.scale(sc, sc)
    y0 = -(len(lines) - 1) * size * 0.55
    for li, (ln, lw) in enumerate(lines):
        x = -lw / 2
        y = y0 + li * size * 1.1
        for wd, m, ww in ln:
            p = skia.Paint(AntiAlias=True, Color=hexc(INK), Style=skia.Paint.kStroke_Style, StrokeWidth=14,
                           StrokeJoin=skia.Paint.kRound_Join)
            c.drawString(wd, x, y, font, p)
            c.drawString(wd, x, y, font, skia.Paint(AntiAlias=True, Color=hexc(MONEY if m else WHITE)))
            x += ww + space
    c.restore()


def film_frame_fx(c, fr, rnd, strength=1.0):
    """Dust, hairs, scratches drawn on top (on twos)."""
    for _ in range(int(rnd.integers(2, 7) * strength)):
        x, y = rnd.uniform(0, W), rnd.uniform(0, H)
        r = rnd.uniform(1.5, 4.5)
        col = INK if rnd.random() < 0.6 else WHITE
        c.drawCircle(x, y, r, fill(col, int(rnd.uniform(90, 200))))
    if rnd.random() < 0.25 * strength:
        x, y = rnd.uniform(0, W), rnd.uniform(0, H)
        p = skia.Path(); p.moveTo(x, y)
        p.cubicTo(x + rnd.uniform(-40, 40), y + rnd.uniform(-40, 40), x + rnd.uniform(-60, 60), y + rnd.uniform(-60, 60),
                  x + rnd.uniform(-80, 80), y + rnd.uniform(-80, 80))
        c.drawPath(p, stroke(INK, 2, a=150))
    if rnd.random() < 0.12 * strength:
        x = rnd.uniform(80, W - 80)
        c.drawLine(x, 0, x + rnd.uniform(-6, 6), H, stroke(WHITE if rnd.random() < 0.5 else INK, 1.6, a=110))


def vignette_paint():
    g = skia.GradientShader.MakeRadial(skia.Point(W / 2, H / 2), 1150,
                                       [hexc("#000000", 0), hexc("#000000", 0), hexc("#000000", 120), hexc("#000000", 200)],
                                       [0, 0.55, 0.85, 1.0])
    return skia.Paint(AntiAlias=True, Shader=g)


def draw_vault_wheel(c, ang, cx=760, cy=1060):
    c.save(); c.translate(cx, cy); c.rotate(ang)
    c.drawCircle(0, 0, 90, stroke(INK, 14)); c.drawCircle(0, 0, 90, stroke(G6, 6))
    for k in range(3):
        a = k * math.pi / 3
        c.drawLine(-math.cos(a) * 110, -math.sin(a) * 110, math.cos(a) * 110, math.sin(a) * 110, stroke(INK, 18))
        c.drawLine(-math.cos(a) * 110, -math.sin(a) * 110, math.cos(a) * 110, math.sin(a) * 110, stroke(G6, 8))
    c.drawCircle(0, 0, 22, fill(G2)); c.drawCircle(0, 0, 22, stroke(INK, 5))
    c.restore()


def stage_live(c, t, sweep=0.0):
    """Stage with swaying curtains and a sweeping spotlight (drawn every frame)."""
    c.drawRect(skia.Rect.MakeWH(W, H), fill("#1d1d1d"))
    for i in range(-90, W + 90, 90):
        off = math.sin(t * 1.3 + i * 0.02) * 10
        g = skia.GradientShader.MakeLinear([skia.Point(i + off, 0), skia.Point(i + 90 + off, 0)],
                                           [hexc("#2c2c2c"), hexc("#6a6a6a"), hexc("#2c2c2c")])
        c.drawRect(skia.Rect.MakeLTRB(i + off, 0, i + 92 + off, 1500), skia.Paint(AntiAlias=True, Shader=g))
    val = skia.Path(); val.moveTo(0, 0); val.lineTo(W, 0); val.lineTo(W, 170)
    for i in range(12, -1, -1):
        val.quadTo(i * 90 + 45, 230, i * 90, 170)
    val.close()
    inked(c, val, "#3a3a3a", 6)
    for i in range(0, W, 30):
        on = (i // 30 + int(t * 6)) % 3 == 0
        c.drawCircle(i + 15, 196 if (i // 30) % 3 else 214, 7, fill(WHITE if on else G4))
    c.drawRect(skia.Rect.MakeLTRB(0, 1500, W, H), fill("#5b5b5b"))
    for yy in range(1500, H, 70):
        c.drawLine(0, yy, W, yy, stroke("#3f3f3f", 4))
    for k in range(-6, 8):
        c.drawLine(W / 2 + k * 70, 1500, W / 2 + k * 260, H, stroke("#474747", 3))
    c.drawLine(0, 1500, W, 1500, stroke(INK, 8))
    sx = W / 2 + sweep
    g = skia.GradientShader.MakeRadial(skia.Point(sx, 1580), 620,
                                       [hexc("#ffffff", 120), hexc("#ffffff", 40), hexc("#ffffff", 0)], [0, 0.6, 1])
    c.drawOval(skia.Rect.MakeLTRB(sx - 560, 1440, sx + 560, 1730), skia.Paint(AntiAlias=True, Shader=g))
    cone = path_poly([(W / 2 - 80, 0), (W / 2 + 80, 0), (sx + 520, 1590), (sx - 520, 1590)])
    g2 = skia.GradientShader.MakeLinear([skia.Point(0, 0), skia.Point(0, 1590)], [hexc("#ffffff", 10), hexc("#ffffff", 60)])
    c.drawPath(cone, skia.Paint(AntiAlias=True, Shader=g2))


def bulb_glow(c, t, speed=8, chase=True, strength=1.0):
    ph = int(t * speed)
    for i, (bx, by) in enumerate(BULBS):
        on = ((i // 2) + ph) % 3 == 0 if chase else True
        if on:
            g = skia.GradientShader.MakeRadial(skia.Point(bx, by), 34, [hexc("#ffffff", int(255 * strength)), hexc("#ffffff", 0)])
            c.drawCircle(bx, by, 34, skia.Paint(AntiAlias=True, Shader=g))
