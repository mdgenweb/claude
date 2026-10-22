"""Hand-held / interactive props for Mister Markup (1950s black-and-white cartoon, only money is green).

Convention (every prop):
    draw_xxx(c, x, y, s=1.0, ang=0.0, t=0.0, **kw)
The prop is drawn so that its GRIP / HANDLE point lands on world (x, y): a cartoon glove
placed at (x, y) looks like it is holding it.  Internally:  c.save(); c.translate(x, y);
c.rotate(ang); c.scale(s, s) ... c.restore().  Sizes at s=1 suit a ~1100 px character.

Everything is a pure function of its arguments (deterministic randomness only via
numpy.random.default_rng(seed) / random.Random(seed) where the original art uses it).

Helpers:
    local_to_world(x, y, s, ang, lx, ly)          -> world point of prop-local (lx, ly)
    magnifier_lens_center(x, y, s=1, ang=0, lens_r=90) -> (cx, cy, world_radius)
"""
import math
import random
from contextlib import contextmanager

import numpy as np
import skia

import art
from art import (INK, WHITE, PAPER, G1, G2, G3, G4, G5, G6, MONEY, MONEY_D, MONEY_L,
                 fill, stroke, inked, path_poly, text, text_width, hexc, TF)


# ------------------------------------------------------------------ helpers
@contextmanager
def _at(c, x, y, s=1.0, ang=0.0):
    c.save(); c.translate(x, y); c.rotate(ang); c.scale(s, s)
    try:
        yield
    finally:
        c.restore()


def local_to_world(x, y, s, ang, lx, ly):
    """World position of the prop-local point (lx, ly) for a prop drawn at (x, y, s, ang)."""
    a = math.radians(ang)
    ca, sa = math.cos(a), math.sin(a)
    return x + s * (lx * ca - ly * sa), y + s * (lx * sa + ly * ca)


def _rr(l, t, r, b, rad):
    p = skia.Path(); p.addRRect(skia.RRect.MakeRectXY(skia.Rect.MakeLTRB(l, t, r, b), rad, rad))
    return p


def _oval(l, t, r, b):
    p = skia.Path(); p.addOval(skia.Rect.MakeLTRB(l, t, r, b))
    return p


def _circ(cx, cy, r):
    p = skia.Path(); p.addCircle(cx, cy, r)
    return p


def _union(*paths):
    out = paths[0]
    for p in paths[1:]:
        out = skia.Op(out, p, skia.PathOp.kUnion_PathOp)
    return out


def _cap(size, tf):
    return skia.Font(TF[tf], size).getMetrics().fCapHeight


def _fit(s, maxw, size, tf):
    w = text_width(s, size, tf)
    return size if w <= maxw else size * maxw / w


def _ctext(c, s, x, yc, size, tf="anton", color=INK, outline=None, ow=4, align="center", alpha=255):
    """Text whose CAP-HEIGHT is vertically centred on yc."""
    return text(c, s, x, yc + _cap(size, tf) / 2, size, tf, color, outline=outline, ow=ow, align=align, alpha=alpha)


def _is_money(s):
    u = s.upper()
    return "$" in u or "FREE" in u or "¢" in u


def _shade(c, clip, band, col, a=255):
    """Fill `band` (path) clipped to `clip` (path) — flat cartoon side-shading."""
    c.save(); c.clipPath(clip, doAntiAlias=True); c.drawPath(band, fill(col, a)); c.restore()


def _sparkle(c, x, y, r, a=255):
    p = path_poly([(x, y - r), (x + r * 0.22, y - r * 0.22), (x + r, y), (x + r * 0.22, y + r * 0.22), (x, y + r),
                   (x - r * 0.22, y + r * 0.22), (x - r, y), (x - r * 0.22, y - r * 0.22)])
    c.drawPath(p, fill(WHITE, a)); c.drawPath(p, stroke(INK, 2.5, a=a))


def _soft_glow(c, cx, cy, r, a):
    g = skia.GradientShader.MakeRadial(skia.Point(cx, cy), r, [hexc(WHITE, int(a)), hexc(WHITE, int(a * 0.45)), hexc(WHITE, 0)],
                                       [0.0, 0.45, 1.0])
    c.drawCircle(cx, cy, r, skia.Paint(AntiAlias=True, Shader=g))


def _ray(c, x0, y0, x1, y1, w=7, a=255):
    """Ink-edged white action line (reads on any background)."""
    c.drawLine(x0, y0, x1, y1, stroke(INK, w + 6, a=a)); c.drawLine(x0, y0, x1, y1, stroke(WHITE, w, a=a))


def _fade(c, a):
    """Begin a faded group; caller must c.restore()."""
    c.saveLayerAlpha(None, int(max(0, min(255, a))))


# ------------------------------------------------------------------ 1. PHONE
def draw_phone(c, x, y, s=1.0, ang=0.0, t=0.0, lines=("FREE", "REFILL!"), header="THEATER APP", glow=0.0, **kw):
    """Modern smartphone, 118x222, grip (0,0) on the lower half (66% down).
    kw: button=None (pill label under the text), badge=None (notification count on the corner)."""
    L, R, T, B = -59, 59, -148, 74
    button = kw.get("button")
    badge = kw.get("badge")
    with _at(c, x, y, s, ang):
        if glow > 0:
            pulse = 0.5 + 0.5 * math.sin(t * 7.0)
            _soft_glow(c, 0, (T + B) / 2, 210 + 25 * pulse, 210 * min(1, glow))
            # three "ding!" notification rays off the top-right corner
            ox, oy = R + 6, T - 6
            for i, a in enumerate((-80, -45, -10)):
                ra = math.radians(a)
                r0 = 18 + 6 * pulse
                r1 = r0 + (34 + 10 * pulse + (8 if i == 1 else 0)) * min(1, glow)
                _ray(c, ox + math.cos(ra) * r0, oy + math.sin(ra) * r0, ox + math.cos(ra) * r1, oy + math.sin(ra) * r1,
                     7, int(255 * min(1, glow * 1.5)))
        # side buttons (behind body)
        for (l, tp, r, b) in ((L - 6, -110, L + 4, -84), (L - 6, -74, L + 4, -48), (R - 4, -118, R + 6, -78)):
            inked(c, _rr(l, tp, r, b, 3), G3, 3)
        body = _rr(L, T, R, B, 24)
        c.drawPath(body, fill(G1))
        _shade(c, body, _rr(R - 14, T - 10, R + 20, B + 10, 0), "#0d0d0d")
        c.drawPath(_rr(L + 4, T + 4, R - 4, B - 4, 20), stroke(G3, 2))
        c.drawPath(body, stroke(INK, 6))
        # speaker slit + camera dot on the bezel
        c.drawLine(-12, T + 7, 12, T + 7, stroke(G3, 3))
        c.drawCircle(20, T + 7, 2.6, fill(G3))
        # screen
        sL, sT, sR, sB = L + 8, T + 13, R - 8, B - 12
        screen = _rr(sL, sT, sR, sB, 12)
        c.drawPath(screen, fill("#f4f3ef"))
        c.save(); c.clipPath(screen, doAntiAlias=True)
        hb = sT + 30
        c.drawRect(skia.Rect.MakeLTRB(sL, sT, sR, hb), fill(G5))
        c.drawLine(sL, hb, sR, hb, stroke(INK, 2.5))
        hs = _fit(header, sR - sL - 14, 13, "monob")
        _ctext(c, header, 0, sT + 15, hs, "monob", INK)
        # big lines
        btn_h = 30 if button else 0
        a_top, a_bot = hb + 6, sB - 14 - btn_h
        n = max(1, len(lines))
        slot = (a_bot - a_top) / n
        for i, ln in enumerate(lines):
            base = min(48, slot * 0.78)
            sz = _fit(ln, sR - sL - 14, base, "anton")
            yc = a_top + slot * (i + 0.5)
            if _is_money(ln):
                _ctext(c, ln, 0, yc, sz, "anton", MONEY, outline=MONEY_D, ow=4)
            else:
                _ctext(c, ln, 0, yc, sz, "anton", INK)
        if button:
            br = _rr(sL + 10, sB - 14 - btn_h, sR - 10, sB - 16, 12)
            inked(c, br, INK, 2)
            bs = _fit(button, sR - sL - 34, 15, "anton")
            _ctext(c, button, 0, sB - 15 - btn_h / 2, bs, "anton", MONEY if _is_money(button) else WHITE)
        c.restore()
        rim = skia.Path(); rim.moveTo(L + 4, B - 40); rim.lineTo(L + 4, T + 26); rim.quadTo(L + 5, T + 5, L + 26, T + 4)
        c.drawPath(rim, stroke(WHITE, 2.5, a=150))
        c.drawPath(screen, stroke(INK, 3))
        c.drawLine(-16, B - 6, 16, B - 6, stroke(G3, 3))
        if badge is not None:
            bx, by = R - 4, T + 4
            lab = str(badge)
            bw = max(30, text_width(lab, 22, "anton") + 18)
            inked(c, _rr(bx - bw / 2, by - 15, bx + bw / 2, by + 15, 15), INK, 3, oc=WHITE)
            _ctext(c, lab, bx, by, 22, "anton", MONEY if _is_money(lab) else WHITE)


# ------------------------------------------------------------------ 2. LIGHT SWITCH
def draw_light_switch(c, x, y, s=1.0, on=False, t=0.0, ang=0.0, **kw):
    """1950s wall switch plate 112x176, (x,y)=plate centre. `on` may be a float 0..1 to animate the lever.
    kw: click=0.0 (0..1 progress of a 'click!' burst at the lever tip; 0 = none)."""
    k = max(0.0, min(1.0, float(on)))
    click = kw.get("click", 0.0)
    PW, PH = 112, 176
    with _at(c, x, y, s, ang):
        c.drawPath(_rr(-PW / 2 + 7, -PH / 2 + 9, PW / 2 + 7, PH / 2 + 9, 16), fill("#000000", 45))
        plate = _rr(-PW / 2, -PH / 2, PW / 2, PH / 2, 16)
        c.drawPath(plate, fill(G6))
        _shade(c, plate, _rr(-PW / 2 - 4, -PH / 2 - 4, PW / 2 - 7, PH / 2 - 8, 14), WHITE)
        c.drawPath(_rr(-PW / 2 + 9, -PH / 2 + 9, PW / 2 - 9, PH / 2 - 9, 10), stroke(G5, 2.5))
        c.drawPath(plate, stroke(INK, 6))
        # screws
        for sy, sa in ((-62, 35), (62, -20)):
            c.drawCircle(0, sy, 9, fill(G5)); c.drawCircle(0, sy, 9, stroke(INK, 3))
            r = math.radians(sa)
            c.drawLine(-6 * math.cos(r), sy - 6 * math.sin(r), 6 * math.cos(r), sy + 6 * math.sin(r), stroke(INK, 2.5))
        # slot
        inked(c, _rr(-14, -34, 14, 34, 9), G1, 4)
        # lever (k=0 down, k=1 up; foreshortens through the middle)
        tip = 50 * (1 - 2 * k)
        sgn = -1 if tip < 0 else 1
        lev = path_poly([(-10, 0), (10, 0), (13, tip), (-13, tip)])
        c.drawPath(lev, fill(WHITE))
        _shade(c, lev, _rr(3, -60, 20, 60, 0), G5)
        c.drawPath(lev, stroke(INK, 4))
        c.drawCircle(0, tip, 13, fill(WHITE)); c.drawCircle(0, tip, 13, stroke(INK, 4))
        c.drawCircle(-4, tip - 4, 3.5, fill(G6))
        c.drawCircle(0, 0, 8, fill(G2)); c.drawCircle(0, 0, 8, stroke(INK, 3))
        if 0 < click < 1:
            a = int(255 * (1 - click))
            for da in (-50, 0, 50):
                ra = math.radians((-90 if sgn < 0 else 90) + da)
                r0, r1 = 24 + 20 * click, 44 + 34 * click
                _ray(c, math.cos(ra) * r0, tip + math.sin(ra) * r0, math.cos(ra) * r1, tip + math.sin(ra) * r1, 5, a)


# ------------------------------------------------------------------ 3. RUBBER STAMP
def draw_rubber_stamp(c, x, y, s=1.0, ang=0.0, t=0.0, inked=True, **kw):
    """Wooden office rubber stamp; grip (0,0) = knob centre; stamp hangs down to y=+168.
    kw: label='MM & CO.' (brass plate on the base)."""
    label = kw.get("label", "MM & CO.")
    _inked = art.inked
    with _at(c, x, y, s, ang):
        neck = skia.Path(); neck.moveTo(-15, 16); neck.quadTo(-8, 52, -20, 88); neck.lineTo(20, 88)
        neck.quadTo(8, 52, 15, 16); neck.close()
        c.drawPath(neck, fill(G3))
        _shade(c, neck, _rr(4, 0, 30, 100, 0), G2)
        c.drawPath(neck, stroke(INK, 5))
        collar = _rr(-42, 84, 42, 102, 8)
        _inked(c, collar, G4, 5)
        c.drawLine(-32, 89, 30, 89, stroke(WHITE, 2.5, a=150))
        base = _rr(-88, 100, 88, 150, 8)
        c.drawPath(base, fill(G4))
        c.save(); c.clipPath(base, doAntiAlias=True)
        for i, yy in enumerate((108, 118, 128, 140)):
            g = skia.Path(); g.moveTo(-95, yy)
            g.cubicTo(-40, yy - 6 + i * 2, 10, yy + 7, 95, yy - 3)
            c.drawPath(g, stroke(G3, 2))
        c.drawRect(skia.Rect.MakeLTRB(62, 96, 96, 156), fill(G3))
        c.restore()
        c.drawLine(-78, 106, 56, 106, stroke(WHITE, 3, a=150))
        c.drawPath(base, stroke(INK, 6))
        plate = _rr(-46, 113, 46, 138, 4)
        _inked(c, plate, G6, 3)
        c.drawCircle(-40, 125.5, 2, fill(G3)); c.drawCircle(40, 125.5, 2, fill(G3))
        _ctext(c, label, 0, 125.5, _fit(label, 70, 15, "monob"), "monob", INK)
        pad = _rr(-82, 148, 82, 166, 3)
        _inked(c, pad, G1, 4)
        if inked:
            c.drawLine(-80, 167, 80, 167, stroke(MONEY_D, 7))
            c.drawLine(-79, 166, 79, 166, stroke(MONEY, 4))
            for dx, ln in ((-48, 14), (22, 9), (60, 18)):
                d = skia.Path(); d.moveTo(dx - 4, 166); d.lineTo(dx + 4, 166)
                d.quadTo(dx + 5, 166 + ln, dx, 168 + ln); d.quadTo(dx - 5, 166 + ln, dx - 4, 166); d.close()
                c.drawPath(d, fill(MONEY)); c.drawPath(d, stroke(MONEY_D, 2))
        # knob
        knob = _circ(0, 0, 33)
        c.drawPath(knob, fill(G1))
        _shade(c, knob, _circ(-5, -5, 29), G2)
        c.drawOval(skia.Rect.MakeLTRB(-20, -22, -4, -10), fill(WHITE, 200))
        c.drawCircle(4, -18, 3, fill(WHITE, 160))
        c.drawPath(knob, stroke(INK, 6))


# ------------------------------------------------------------------ 4. JOURNAL
def draw_journal(c, x, y, s=1.0, ang=0.0, t=0.0, lines=("JOURNAL OF", "CONSUMER", "RESEARCH", "1982"), **kw):
    """Hardcover academic journal ~230x266; grip (0,0) on the spine, lower-middle (65% down)."""
    T, B = -172, 90
    with _at(c, x, y, s, ang):
        inked(c, _rr(22, T + 6, 216, B + 4, 6), G1, 5)                       # back board
        pages = skia.Rect.MakeLTRB(176, T + 12, 208, B - 4)
        c.drawRect(pages, fill(PAPER))
        for xx in range(186, 207, 4):
            c.drawLine(xx, T + 14, xx, B - 6, stroke(G5, 1.6))
        c.drawRect(pages, stroke(INK, 3))
        cover = _rr(12, T, 198, B, 6)
        c.drawPath(cover, fill(G2))
        c.save(); c.clipPath(cover, doAntiAlias=True)
        for k in range(-30, 30):                                              # cloth weave
            c.drawLine(12 + k * 12, T, 12 + k * 12 + 260, B, stroke("#525252", 1.2))
        c.drawRect(skia.Rect.MakeLTRB(178, T - 4, 204, B + 4), fill("#3a3a3a"))
        c.restore()
        c.drawPath(_rr(26, T + 13, 184, B - 13, 4), stroke(G4, 3))
        c.drawPath(_rr(32, T + 19, 178, B - 19, 2), stroke(G4, 1.4))
        c.drawPath(cover, stroke(INK, 6))
        # title block
        cx, maxw = 105, 128
        n = len(lines)
        yy = T + 52
        for i, ln in enumerate(lines):
            small = n >= 3 and (i == 0 or i == n - 1)
            if small and i == n - 1:
                continue
            if small:
                sz = _fit(ln, maxw, 17, "monob")
                _ctext(c, ln, cx, yy, sz, "monob", G6)
                yy += 30
            else:
                sz = _fit(ln, maxw, 27, "slab")
                _ctext(c, ln, cx, yy, sz, "slab", WHITE)
                yy += sz * 1.15
        # rule with diamond
        ry = yy + 2
        c.drawLine(cx - 52, ry, cx - 10, ry, stroke(G5, 2.5)); c.drawLine(cx + 10, ry, cx + 52, ry, stroke(G5, 2.5))
        c.drawPath(path_poly([(cx, ry - 6), (cx + 6, ry), (cx, ry + 6), (cx - 6, ry)]), fill(G5))
        # seal (a lamp of learning)
        sy = ry + 46
        c.drawCircle(cx, sy, 25, stroke(G5, 2.5)); c.drawCircle(cx, sy, 19, stroke(G5, 1.4))
        lamp = skia.Path(); lamp.moveTo(cx - 12, sy + 6); lamp.quadTo(cx, sy + 14, cx + 14, sy + 2)
        lamp.lineTo(cx + 4, sy + 2); lamp.quadTo(cx - 4, sy - 2, cx - 12, sy + 6); lamp.close()
        c.drawPath(lamp, fill(G5))
        fl = skia.Path(); fl.moveTo(cx + 13, sy + 1); fl.quadTo(cx + 9, sy - 8, cx + 14, sy - 14); fl.quadTo(cx + 19, sy - 6, cx + 13, sy + 1)
        c.drawPath(fl, fill(WHITE))
        if n >= 3:
            ln = lines[-1]
            _ctext(c, ln, cx, B - 34, _fit(ln, maxw, 19, "monob"), "monob", G6)
        # spine
        spine = _rr(-18, T - 2, 20, B + 2, 10)
        c.drawPath(spine, fill(G1))
        for by in (T + 22, T + 32, B - 32, B - 22):
            c.drawLine(-14, by, 16, by, stroke(G3, 3))
        c.drawLine(-7, T + 44, -7, B - 44, stroke(WHITE, 4, a=70))
        c.drawPath(spine, stroke(INK, 6))


# ------------------------------------------------------------------ 5. REPORT
def draw_report(c, x, y, s=1.0, ang=0.0, t=0.0, title="ANNUAL REPORT", sub="FORM 10-K", **kw):
    """Thick stapled corporate report with a binder clip, 210x270 + stack edge.
    Grip (0,0) = middle of its LEFT edge.  kw: figure=None (a money figure, drawn green, e.g. '$4.8B')."""
    figure = kw.get("figure")
    L, R, T, B = 0, 210, -140, 130
    with _at(c, x, y, s, ang):
        for i in range(7, 0, -1):                                             # stack edge
            off = i * 3.2
            sh = skia.Rect.MakeLTRB(L + off, T + off * 1.1, R + off, B + off * 1.1)
            c.drawRect(sh, fill(WHITE if i % 2 else G6)); c.drawRect(sh, stroke(INK, 2.2))
        page = skia.Rect.MakeLTRB(L, T, R, B)
        c.drawRect(page, fill(WHITE))
        c.drawRect(skia.Rect.MakeLTRB(R - 18, T, R, B), fill(G6))
        # header band
        c.drawRect(skia.Rect.MakeLTRB(L, T + 34, R, T + 96), fill(G1))
        words = title.split()
        if len(words) >= 2 and text_width(title, 34, "anton") > R - L - 30:
            mid = len(words) // 2
            l1, l2 = " ".join(words[:mid]), " ".join(words[mid:])
            sz = min(_fit(l1, R - 30, 28, "anton"), _fit(l2, R - 30, 28, "anton"))
            _ctext(c, l1, R / 2, T + 50, sz, "anton", WHITE); _ctext(c, l2, R / 2, T + 81, sz, "anton", WHITE)
        else:
            _ctext(c, title, R / 2, T + 65, _fit(title, R - 30, 34, "anton"), "anton", WHITE)
        _ctext(c, sub, R / 2, T + 116, _fit(sub, R - 40, 20, "monob"), "monob", INK)
        c.drawLine(L + 20, T + 132, R - 20, T + 132, stroke(INK, 2.5))
        # body text
        for i, ln in enumerate((150, 120, 140, 95, 150, 70)):
            yy = T + 150 + i * 12
            c.drawLine(L + 22, yy, L + 22 + ln * 0.62, yy, stroke(G4, 4, cap="butt"))
        # bar chart (rising) + arrow
        bx0, by0 = R - 92, B - 26
        for i, hgt in enumerate((18, 30, 44, 62)):
            bar = skia.Rect.MakeLTRB(bx0 + i * 18, by0 - hgt, bx0 + i * 18 + 13, by0)
            c.drawRect(bar, fill(G3)); c.drawRect(bar, stroke(INK, 2.5))
        c.drawLine(bx0 - 6, by0, bx0 + 78, by0, stroke(INK, 3))
        ar = skia.Path(); ar.moveTo(bx0 - 2, by0 - 34); ar.lineTo(bx0 + 66, by0 - 84)
        c.drawPath(ar, stroke(INK, 4))
        c.drawPath(path_poly([(bx0 + 72, by0 - 89), (bx0 + 54, by0 - 86), (bx0 + 66, by0 - 73)]), fill(INK))
        if figure:
            _ctext(c, figure, L + 60, B - 44, _fit(figure, 96, 34, "anton"), "anton", MONEY, outline=MONEY_D, ow=4)
        else:
            for i, ln in enumerate((70, 52, 64)):
                yy = B - 60 + i * 12
                c.drawLine(L + 22, yy, L + 22 + ln, yy, stroke(G5, 4, cap="butt"))
        c.drawRect(page, stroke(INK, 6))
        # staples
        for (sx, sy) in ((16, T + 14), (16, B - 20)):
            c.drawLine(sx, sy, sx + 16, sy + 8, stroke(INK, 6)); c.drawLine(sx, sy, sx + 16, sy + 8, stroke(G5, 2.5))
        # binder clip
        cx = R / 2 + 20
        for side in (-1, 1):
            h = skia.Path(); h.moveTo(cx + side * 20, T - 2); h.quadTo(cx + side * 30, T - 40, cx + side * 8, T - 44)
            c.drawPath(h, stroke(INK, 10)); c.drawPath(h, stroke(G5, 4))
        clip = path_poly([(cx - 34, T + 20), (cx + 34, T + 20), (cx + 28, T - 10), (cx - 28, T - 10)])
        c.drawPath(clip, fill(G1)); c.drawPath(clip, stroke(INK, 5))
        c.drawLine(cx - 22, T - 4, cx + 22, T - 4, stroke(G3, 2.5))


# ------------------------------------------------------------------ 6. CASH REGISTER
def _scroll(c, x, y, r, side, w=2.5, col=INK):
    """Little engraved curlicue (rococo spiral)."""
    p = skia.Path(); p.moveTo(x, y)
    for i in range(1, 30):
        a = i * 0.42
        rr = r * (1 - i / 34)
        p.lineTo(x + side * (math.cos(a) * rr - r), y + math.sin(a) * rr)
    c.drawPath(p, stroke(col, w))


def draw_register(c, x, y, s=1.0, t=0.0, drawer=0.0, display="$0.80", ang=0.0, **kw):
    """Ornate 1950s cash register (brass-style, in greys), ~340x440, (x,y) = bottom centre.
    drawer 0..1 slides the cash drawer out (toward camera) revealing green bills; flags hop as it opens."""
    k = max(0.0, min(1.0, drawer))
    seed = kw.get("seed", 4)
    with _at(c, x, y, s, ang):
        # feet
        for side in (-1, 1):
            inked(c, _oval(side * 150 - 22, -16, side * 150 + 22, 6), G2, 5)
        # crank (right side) — turns as the drawer opens
        hub = (166, -168)
        ca = math.radians(-70 + 140 * k)
        kx, ky = hub[0] + 44 * math.cos(ca), hub[1] + 44 * math.sin(ca)
        c.drawLine(hub[0], hub[1], kx, ky, stroke(INK, 14)); c.drawLine(hub[0], hub[1], kx, ky, stroke(G5, 6))
        inked(c, _rr(kx - 9, ky - 20, kx + 9, ky + 4, 8), WHITE, 4)
        c.drawCircle(hub[0], hub[1], 15, fill(G3)); c.drawCircle(hub[0], hub[1], 15, stroke(INK, 4))
        # ---- display box on top (behind the crest housing)
        chars = list(display)
        widths = [16 if ch in ".," else 34 for ch in chars]
        tot = sum(widths) + 4 * (len(chars) - 1)
        dw = max(196, tot + 40)
        dbox = _rr(-dw / 2, -420, dw / 2, -330, 10)
        inked(c, dbox, G3, 6)
        win = _rr(-dw / 2 + 12, -410, dw / 2 - 12, -344, 6)
        c.drawPath(win, fill(G1))
        c.save(); c.clipPath(win, doAntiAlias=True)
        hop = 12 * math.sin(math.pi * k) + 2 * math.sin(t * 9)
        fx = -tot / 2
        for ch, wd in zip(chars, widths):
            fl = _rr(fx, -402 - hop, fx + wd, -336, 5)
            c.drawPath(fl, fill(WHITE)); c.drawPath(fl, stroke(INK, 3))
            if ch.strip():
                _ctext(c, ch, fx + wd / 2, -372 - hop, _fit(ch, wd - 6, 34, "slab"), "slab", MONEY, outline=MONEY_D, ow=4)
            fx += wd + 4
        c.drawPath(path_poly([(-dw / 2, -400), (-dw / 2 + 40, -420), (-dw / 2 + 64, -420), (-dw / 2 + 24, -330)]), fill(WHITE, 60))
        c.restore()
        c.drawPath(win, stroke(INK, 4))
        # crest sunburst finial
        crest = skia.Path(); crest.addArc(skia.Rect.MakeLTRB(-46, -466, 46, -374), 180, 180); crest.close()
        c.drawPath(crest, fill(G4))
        for i in range(9):
            a = math.radians(180 + 10 + i * 20)
            c.drawLine(math.cos(a) * 12, -420 + math.sin(a) * 12, math.cos(a) * 42, -420 + math.sin(a) * 42, stroke(G2, 3))
        c.drawPath(crest, stroke(INK, 5))
        c.drawCircle(0, -420, 10, fill(G2)); c.drawCircle(0, -420, 10, stroke(INK, 3))
        dbox2 = skia.Path(); dbox2.addRRect(skia.RRect.MakeRectXY(skia.Rect.MakeLTRB(-dw / 2, -420, dw / 2, -330), 10, 10))
        c.drawPath(dbox2, stroke(INK, 6))
        # ---- crest housing (ornate)
        hous = skia.Path(); hous.moveTo(-140, -246); hous.lineTo(-140, -300)
        hous.cubicTo(-140, -330, -110, -336, -84, -332); hous.lineTo(84, -332)
        hous.cubicTo(110, -336, 140, -330, 140, -300); hous.lineTo(140, -246); hous.close()
        c.drawPath(hous, fill(G4))
        _shade(c, hous, _rr(100, -340, 150, -240, 0), G3)
        c.drawLine(-128, -322, 70, -322, stroke(WHITE, 3, a=140))
        plate = _rr(-68, -320, 68, -262, 6)
        inked(c, plate, G6, 4)
        _ctext(c, "AMOUNT", 0, -303, 18, "monob", INK)
        _ctext(c, "PURCHASED", 0, -279, _fit("PURCHASED", 110, 16, "mono"), "mono", G2)
        for side in (-1, 1):
            _scroll(c, side * 126, -296, 16, side, 3, G2)
            _scroll(c, side * 124, -262, 8, -side, 2.5, G2)
        c.drawPath(hous, stroke(INK, 6))
        # ---- key deck (sloped)
        deck = path_poly([(-164, -116), (164, -116), (140, -250), (-140, -250)])
        c.drawPath(deck, fill(G5))
        _shade(c, deck, path_poly([(120, -260), (180, -260), (180, -100), (140, -100)]), G4)
        c.drawPath(deck, stroke(INK, 6))
        labels = (("1", "2", "3", "4", "5", "6"), ("10", "20", "30", "40", "50", "60"), ("$1", "$2", "$3", "$4", "$5", "$9"))
        for row in range(3):
            yy = -230 + row * 40
            w = 112 + row * 12
            r = 13 + row * 1.5
            for col in range(6):
                xx = -w + col * (2 * w / 5)
                c.drawLine(xx, yy + r, xx, yy + r + 8, stroke(INK, 5))
                c.drawCircle(xx, yy, r, fill(WHITE)); c.drawCircle(xx, yy, r, stroke(INK, 3.5))
                c.drawCircle(xx, yy, r - 5, stroke(G5, 1.5))
                lab = labels[row][col]
                money_key = lab.startswith("$")
                _ctext(c, lab, xx, yy, _fit(lab, r * 1.4, 13, "monob"), "monob", MONEY_D if money_key else INK)
        # ---- cabinet + drawer
        cab = _rr(-168, -120, 168, -10, 10)
        c.drawPath(cab, fill(G4))
        _shade(c, cab, _rr(130, -130, 180, 0, 0), G3)
        c.drawLine(-156, -112, 120, -112, stroke(WHITE, 3, a=140))
        for side in (-1, 1):
            _scroll(c, side * 154, -64, 9, -side, 2.2, G2)
        c.drawPath(cab, stroke(INK, 6))
        oL, oT, oR, oB = -140, -104, 140, -20
        c.drawRect(skia.Rect.MakeLTRB(oL, oT, oR, oB), fill(G1))
        dy = 74 * k
        sc = 1 + 0.24 * k
        cy0 = (oT + oB) / 2 + dy
        hw, hh = (oR - oL) / 2 * sc, (oB - oT) / 2 * sc
        ft, fb = cy0 - hh, cy0 + hh
        if k > 0.001:
            # side walls
            for side in (-1, 1):
                wall = path_poly([(side * 140, oT), (side * hw, ft), (side * hw, fb - 6), (side * 140, oB)])
                inked(c, wall, G3, 4)
            tray = path_poly([(oL, oT), (oR, oT), (hw, ft), (-hw, ft)])
            c.drawPath(tray, fill(G2))
            rnd = np.random.default_rng(seed)
            c.save(); c.clipRect(skia.Rect.MakeLTRB(-400, -260, 400, ft), doAntiAlias=True)
            ncomp = 5
            for i in range(ncomp):
                u = (i + 0.5) / ncomp
                bxw = lerp_(oL, oR, u)
                bxf = lerp_(-hw, hw, u)
                for j in range(3):
                    lift = (14 + rnd.uniform(0, 16)) * min(1, k * 1.6)
                    bx = lerp_(bxw, bxf, 0.6) + rnd.uniform(-8, 8)
                    by = ft - lift - j * 5
                    c.save(); c.translate(bx, by); c.rotate(rnd.uniform(-10, 10))
                    bw, bh = 42 * sc, 30
                    bill = skia.Rect.MakeLTRB(-bw / 2, -bh / 2, bw / 2, bh / 2 + 30)
                    c.drawRect(bill, fill(MONEY)); c.drawRect(bill, stroke(INK, 3))
                    c.drawRect(skia.Rect.MakeLTRB(-bw / 2 + 5, -bh / 2 + 5, bw / 2 - 5, bh / 2 + 25), stroke(MONEY_D, 2))
                    c.drawCircle(0, 0, 7, fill(MONEY_L)); c.drawCircle(0, 0, 7, stroke(MONEY_D, 2))
                    c.restore()
            c.restore()
            for i in range(1, ncomp):
                u = i / ncomp
                c.drawLine(lerp_(oL, oR, u), oT, lerp_(-hw, hw, u), ft, stroke(INK, 3))
            c.drawPath(tray, stroke(INK, 4))
        front = _rr(-hw, ft, hw, fb, 6)
        c.drawPath(front, fill(G5))
        _shade(c, front, _rr(hw - 22, ft - 4, hw + 4, fb + 4, 0), G4)
        c.drawPath(_rr(-hw + 10, ft + 9, hw - 10, fb - 9, 4), stroke(G3, 2.5))
        c.drawPath(front, stroke(INK, 6))
        inked(c, _rr(-36 * sc, cy0 - 9 * sc, 36 * sc, cy0 + 9 * sc, 9 * sc), G3, 4)
        _ctext(c, "CASH", -hw + 52 * sc, cy0, 22 * sc, "deco", G2)
        c.drawCircle(hw - 44 * sc, cy0 - 3 * sc, 5 * sc, fill(INK))
        c.drawLine(hw - 44 * sc, cy0, hw - 44 * sc, cy0 + 9 * sc, stroke(INK, 3.5 * sc))
        # pop rays off the drawer's bottom corners while it slides / just popped
        if 0.02 < k < 0.98:
            a = int(255 * min(1, k * (1 - k) * 6))
            for side in (-1, 1):
                for da in (25, 50, 75):
                    ra = math.radians(90 - side * da)
                    r0, r1 = 16 + 10 * k, 34 + 22 * k
                    ox, oy = side * hw, fb
                    _ray(c, ox + math.cos(ra) * r0, oy + math.sin(ra) * r0, ox + math.cos(ra) * r1, oy + math.sin(ra) * r1, 4, a)


def lerp_(a, b, u):
    return a + (b - a) * u


# ------------------------------------------------------------------ 7. PITCHER
def _bez(p0, p1, p2, p3, u):
    v = 1 - u
    return (v ** 3 * p0[0] + 3 * v * v * u * p1[0] + 3 * v * u * u * p2[0] + u ** 3 * p3[0],
            v ** 3 * p0[1] + 3 * v * v * u * p1[1] + 3 * v * u * u * p2[1] + u ** 3 * p3[1])


def _pitcher_body():
    p = skia.Path()
    p.moveTo(-212, -134)                      # spout lip
    p.quadTo(-196, -128, -186, -120)
    p.lineTo(-52, -124)                       # rim
    p.cubicTo(-40, -70, -30, 30, -52, 96)     # handle side wall
    p.quadTo(-56, 110, -72, 110)
    p.lineTo(-170, 110)
    p.quadTo(-186, 110, -190, 96)
    p.cubicTo(-214, 20, -204, -60, -186, -92)  # front belly
    p.quadTo(-196, -112, -212, -134)
    p.close()
    return p


def draw_pitcher(c, x, y, s=1.0, ang=0.0, t=0.0, fill=0.8, **kw):
    """Glass water pitcher; grip (0,0) = the handle (handle on +x side, body/spout toward -x).
    Negative ang tips the spout down (pouring).  The water surface stays level in WORLD space
    (pivoting around the surface midpoint, ~area-preserving); when the spout dips below the
    level a falling stream is drawn.  kw: ice=0 (floating cubes), pour=None(auto)/False, pour_len=300."""
    f = max(0.0, min(1.0, fill))
    ice = kw.get("ice", 0)
    pour = kw.get("pour", None)
    pour_len = kw.get("pour_len", 300)
    paint_fill = art.fill
    body = _pitcher_body()
    top, bot = -122, 104
    lvl = bot - f * (bot - top)
    a = math.radians(ang)
    nx, ny = math.sin(a), math.cos(a)            # world-down in local coords
    dx, dy = math.cos(a), -math.sin(a)           # world-horizontal in local coords
    px, py = -121, lvl                           # pivot = surface midpoint
    spout = (-208, -130)
    with _at(c, x, y, s, ang):
        # handle (behind body edge)
        hp = skia.Path(); hp.moveTo(-58, -96); hp.cubicTo(0, -110, 10, -60, 4, 0)
        hp.cubicTo(0, 44, -20, 64, -48, 66)
        c.drawPath(hp, stroke(INK, 30)); c.drawPath(hp, stroke("#e9e9e6", 17))
        c.drawPath(hp, stroke(WHITE, 4, a=230))
        # glass
        c.drawPath(body, paint_fill(WHITE, 120))
        # water
        if f > 0:
            c.save(); c.clipPath(body, doAntiAlias=True)
            Lw = 420
            wav = skia.Path()
            n = 28
            for i in range(n + 1):
                u = -Lw + 2 * Lw * i / n
                w = 4.5 * math.sin(u * 0.06 + t * 5.0)
                qx, qy = px + dx * u + nx * w, py + dy * u + ny * w
                (wav.moveTo if i == 0 else wav.lineTo)(qx, qy)
            wav.lineTo(px + dx * Lw + nx * 800, py + dy * Lw + ny * 800)
            wav.lineTo(px - dx * Lw + nx * 800, py - dy * Lw + ny * 800)
            wav.close()
            c.drawPath(wav, paint_fill(G5, 165))
            # surface lines + inner highlight
            surf = skia.Path()
            for i in range(n + 1):
                u = -Lw + 2 * Lw * i / n
                w = 4.5 * math.sin(u * 0.06 + t * 5.0)
                qx, qy = px + dx * u + nx * w, py + dy * u + ny * w
                (surf.moveTo if i == 0 else surf.lineTo)(qx, qy)
            c.drawPath(surf, stroke(INK, 3.5))
            c.save(); c.translate(nx * 8, ny * 8); c.drawPath(surf, stroke(WHITE, 4, a=200)); c.restore()
            rnd = np.random.default_rng(12)
            for i in range(7):                                    # bubbles
                bx = rnd.uniform(-180, -70)
                by = (lvl + 20) + ((rnd.uniform(0, 1) - t * 0.25) % 1.0) * (bot - lvl - 30)
                c.drawCircle(bx, by, rnd.uniform(3, 6), stroke(WHITE, 2.5, a=220))
            for i in range(int(ice)):
                u = -40 + i * 60
                ix, iy = px + dx * u + nx * 8, py + dy * u + ny * 8
                draw_ice_cube(c, ix, iy, 0.55, ang=-ang + (i * 23 % 30) - 15, t=t)
            c.restore()
        # glass shading & glints
        _shade(c, body, _rr(-80, -140, -30, 120, 0), G6, 150)
        c.drawLine(-178, -70, -184, 40, stroke(WHITE, 9, a=235))
        c.drawLine(-172, 62, -172, 76, stroke(WHITE, 7, a=235))
        c.drawLine(-70, -90, -64, -20, stroke(WHITE, 4, a=200))
        c.drawPath(body, stroke(INK, 6))
        # thick glass base + rim
        c.drawLine(-176, 100, -66, 100, stroke(G4, 5))
        c.drawLine(-188, -122, -54, -125, stroke(INK, 7))
        c.drawLine(-180, -127, -62, -129, stroke(WHITE, 2.5))
        # pour stream
        spd = (spout[0] - px) * nx + (spout[1] - py) * ny         # >0 => spout below surface
        auto = spd > -6 and f > 0
        if (pour is None and auto) or pour is True:
            amt = 1.0 if pour else max(0.25, min(1.0, (spd + 6) / 40))
            sx, sy = spout
            ox, oy = -dx * 0.9 - nx * 0.1, -dy * 0.9 - ny * 0.1     # out of the spout, world-horizontal
            P0 = (sx, sy); P1 = (sx + ox * 26, sy + oy * 26)
            P2 = (sx + ox * 40 + nx * 60, sy + oy * 40 + ny * 60)
            P3 = (sx + ox * 44 + nx * pour_len, sy + oy * 44 + ny * pour_len)
            cen = [_bez(P0, P1, P2, P3, i / 24) for i in range(25)]
            left, right = [], []
            for i, (qx, qy) in enumerate(cen):
                u = i / 24
                ax_, ay_ = cen[min(i + 1, 24)]; bx_, by_ = cen[max(i - 1, 0)]
                tx_, ty_ = ax_ - bx_, ay_ - by_
                tl = math.hypot(tx_, ty_) + 1e-6
                pnx, pny = -ty_ / tl, tx_ / tl
                hw_ = (12 + 5 * amt) * (1 - 0.45 * u) + 1.8 * math.sin(u * 14 - t * 16)
                left.append((qx + pnx * hw_, qy + pny * hw_)); right.append((qx - pnx * hw_, qy - pny * hw_))
            sp_ = path_poly(left + right[::-1])
            c.drawPath(sp_, paint_fill(G6, 235)); c.drawPath(sp_, stroke(INK, 3.5))
            hl = skia.Path(); hl.moveTo(*cen[1])
            for q in cen[2:20]:
                hl.lineTo(q[0] + nx * 0 - dx * 3, q[1] + ny * 0 - dy * 3)
            c.drawPath(hl, stroke(WHITE, 3, a=230))
            rnd = np.random.default_rng(3)
            for i in range(6):                                     # droplets falling beside
                u = ((rnd.uniform(0, 1) + t * 1.8) % 1.0)
                ddx = rnd.uniform(-18, 18)
                qx = sx + ox * 44 + nx * pour_len * u + dx * ddx
                qy = sy + oy * 44 + ny * pour_len * u + dy * ddx
                c.drawCircle(qx, qy, 4.5, paint_fill(WHITE)); c.drawCircle(qx, qy, 4.5, stroke(INK, 2.5))


# ------------------------------------------------------------------ 8. SYRUP BOTTLE
def draw_syrup_bottle(c, x, y, s=1.0, ang=0.0, t=0.0, **kw):
    """Small dark syrup bottle ~70x200; grip (0,0) = middle of the bottle body."""
    label = kw.get("label", "SYRUP")
    with _at(c, x, y, s, ang):
        b = skia.Path()
        b.moveTo(-13, -110); b.lineTo(-13, -86)
        b.cubicTo(-14, -70, -36, -66, -36, -46)
        b.lineTo(-36, 50); b.quadTo(-36, 64, -22, 64); b.lineTo(22, 64); b.quadTo(36, 64, 36, 50)
        b.lineTo(36, -46); b.cubicTo(36, -66, 14, -70, 13, -86); b.lineTo(13, -110); b.close()
        c.drawPath(b, art.fill("#1b1b1b"))
        _shade(c, b, _rr(18, -120, 50, 80, 0), "#0b0b0b")
        c.drawLine(-24, -36, -24, 44, stroke(WHITE, 7, a=150))
        c.drawCircle(-24, -48, 3.5, art.fill(WHITE, 150))
        c.drawPath(b, stroke(INK, 6))
        inked(c, _rr(-17, -116, 17, -104, 4), G2, 4)
        cap = _rr(-15, -138, 15, -114, 5)
        inked(c, cap, G4, 4)
        for xx in (-8, -2, 4, 10):
            c.drawLine(xx, -134, xx, -118, stroke(G3, 2))
        # label
        lab = _rr(-31, 4, 31, 48, 5)
        inked(c, lab, WHITE, 3)
        c.drawLine(-24, 38, 24, 38, stroke(G4, 2))
        _ctext(c, label, 0, 22, _fit(label, 52, 22, "slab"), "slab", INK)
        d = skia.Path(); d.moveTo(-14, 4); d.lineTo(-4, 4); d.quadTo(-5, 14, -9, 15); d.quadTo(-14, 14, -14, 4); d.close()
        c.drawPath(d, art.fill("#1b1b1b"))


# ------------------------------------------------------------------ 9. ICE CUBE
def draw_ice_cube(c, x, y, s=1.0, ang=0.0, t=0.0, **kw):
    """Chunky 3/4-view ice cube ~78 px, (x,y) = centre; sparkle twinkles with t."""
    cpe = skia.CornerPathEffect.Make(9)
    with _at(c, x, y, s, ang):
        front = path_poly([(-36, -20), (20, -20), (20, 36), (-36, 36)])
        topf = path_poly([(-36, -20), (20, -20), (38, -38), (-18, -38)])
        side = path_poly([(20, -20), (38, -38), (38, 18), (20, 36)])
        for p, col in ((side, G5), (topf, WHITE), (front, G6)):
            pt = art.fill(col); pt.setPathEffect(cpe)
            c.drawPath(p, pt)
        # inner frost + bubbles
        c.drawLine(-26, -8, -26, 22, stroke(WHITE, 5, a=230))
        c.drawLine(-18, -10, -10, -14, stroke(WHITE, 4, a=230))
        c.drawCircle(6, 20, 3.5, stroke(G4, 2)); c.drawCircle(-4, 10, 2.5, stroke(G4, 2)); c.drawCircle(28, 4, 3, stroke(WHITE, 2))
        edge = stroke(INK, 2.5); edge.setPathEffect(cpe)
        c.drawLine(20, -18, 20, 32, stroke(INK, 3))
        c.drawLine(-32, -20, 18, -20, stroke(INK, 3))
        c.drawLine(21, -21, 35, -35, stroke(INK, 3))
        sil = path_poly([(-36, -20), (-18, -38), (38, -38), (38, 18), (20, 36), (-36, 36)])
        out = stroke(INK, 6); out.setPathEffect(cpe)
        c.drawPath(sil, out)
        tw = 0.55 + 0.45 * abs(math.sin(t * 3.3 + kw.get("phase", 0.0)))
        _sparkle(c, -16, -38, 13 * tw)


# ------------------------------------------------------------------ 10. TICKET
def draw_ticket(c, x, y, s=1.0, ang=0.0, t=0.0, label="ADMIT ONE", **kw):
    """Movie ticket stub 270x104, grip (0,0) = middle of the LEFT end (text sits right of the hand).
    kw: number='No 0001'."""
    number = kw.get("number", "No 0001")
    L, R, T, B, PX = 0, 270, -52, 52, 210
    with _at(c, x, y, s, ang):
        body = _rr(L, T, R, B, 4)
        notch = []
        for (nx_, ny_) in ((L, T), (L, B), (R, T), (R, B), (PX, T), (PX, B)):
            notch.append(_circ(nx_, ny_, 11 if nx_ != PX else 8))
        tk = body
        for n_ in notch:
            tk = skia.Op(tk, n_, skia.PathOp.kDifference_PathOp)
        c.drawPath(tk, art.fill(G6))
        c.save(); c.clipPath(tk, doAntiAlias=True)
        c.drawRect(skia.Rect.MakeLTRB(L - 5, B - 14, R + 5, B + 5), art.fill(G5))
        c.restore()
        c.drawPath(_rr(L + 16, T + 12, PX - 12, B - 12, 3), stroke(INK, 2.5))
        c.drawPath(_rr(L + 21, T + 17, PX - 17, B - 17, 2), stroke(G4, 1.5))
        tcx = (L + PX) / 2 + 16
        _ctext(c, label, tcx, -6, _fit(label, PX - 76, 30, "slab"), "slab", INK)
        _ctext(c, number, tcx, 22, 13, "monob", G3)
        for sx in (tcx - 58, tcx + 58):
            _sparkle(c, sx, 22, 6)
        # perforation
        for yy in range(int(T + 14), int(B - 10), 9):
            c.drawCircle(PX, yy, 2.6, art.fill(G3))
        # stub text (vertical)
        c.save(); c.translate((PX + R) / 2 + 2, 0); c.rotate(-90)
        _ctext(c, "ADMIT", 0, -9, 15, "anton", INK)
        _ctext(c, "0001", 0, 12, 14, "monob", G3)
        c.restore()
        c.drawPath(tk, stroke(INK, 5))


# ------------------------------------------------------------------ 11a. KEYCARD
def draw_keycard(c, x, y, s=1.0, ang=0.0, t=0.0, label="ROOM 3", **kw):
    """Hotel keycard 184x116, grip (0,0) = middle of the LEFT end; chevrons point the insert direction (+x)."""
    L, R, T, B = 0, 184, -58, 58
    with _at(c, x, y, s, ang):
        card = _rr(L, T, R, B, 12)
        c.drawPath(card, art.fill(G2))
        c.save(); c.clipPath(card, doAntiAlias=True)
        c.drawRect(skia.Rect.MakeLTRB(L, T, R, T + 22), art.fill(G1))
        sw = skia.Path(); sw.moveTo(L, B - 18); sw.cubicTo(60, B - 46, 120, B + 6, R, B - 34); sw.lineTo(R, B); sw.lineTo(L, B); sw.close()
        c.drawPath(sw, art.fill(G3))
        c.drawPath(path_poly([(L + 30, T), (L + 70, T), (L + 10, B), (L - 30, B)]), art.fill(WHITE, 30))
        c.restore()
        c.drawPath(_rr(L + 6, T + 6, R - 6, B - 6, 8), stroke(G4, 1.5))
        c.drawPath(card, stroke(INK, 6))
        # key icon
        kx, ky = 70, -26
        c.drawCircle(kx - 14, ky + 2, 8, stroke(WHITE, 4))
        c.drawLine(kx - 6, ky + 2, kx + 20, ky + 2, stroke(WHITE, 4))
        c.drawLine(kx + 14, ky + 2, kx + 14, ky + 9, stroke(WHITE, 4)); c.drawLine(kx + 20, ky + 2, kx + 20, ky + 8, stroke(WHITE, 4))
        _ctext(c, "HOTEL", kx + 58, ky + 2, 15, "monob", G5)
        _ctext(c, label, 112, 12, _fit(label, 126, 40, "anton"), "anton", WHITE, outline=INK, ow=6)
        for i in range(3):
            cx = 146 + i * 11
            c.drawPath(path_poly([(cx, 34), (cx + 7, 41), (cx, 48)], close=False), stroke(WHITE, 3))


# ------------------------------------------------------------------ 11b. WALL CLOCK
def _hand(c, ang, length, w, tail=14, spade=False, col=INK):
    c.save(); c.rotate(ang)
    p = path_poly([(-w / 2, tail), (w / 2, tail), (w * 0.28, -length), (-w * 0.28, -length)])
    c.drawPath(p, art.fill(col))
    if spade:
        sp = path_poly([(0, -length * 0.62 - 15), (11, -length * 0.62), (0, -length * 0.62 + 10), (-11, -length * 0.62)])
        c.drawPath(sp, art.fill(col)); c.drawPath(sp, stroke(col, 2))
    c.restore()


def draw_clock(c, x, y, s=1.0, t=0.0, hour=3, minute=0, ang=0.0, **kw):
    """1950s schoolroom wall clock, radius ~112, (x,y) = centre. Hands show hour:minute;
    the red-free sweep second hand turns with t (seconds).  kw: second=None (override seconds)."""
    sec = kw.get("second", None)
    secs = (t if sec is None else sec) % 60.0
    with _at(c, x, y, s, ang):
        c.drawCircle(7, 10, 112, art.fill("#000000", 45))
        c.drawCircle(0, 0, 112, art.fill(G4))
        rim = _circ(0, 0, 112)
        _shade(c, rim, _circ(-8, -8, 108), G5)
        c.drawCircle(0, 0, 112, stroke(INK, 7))
        c.drawCircle(0, 0, 96, art.fill(G3)); c.drawCircle(0, 0, 96, stroke(INK, 3))
        face = _circ(0, 0, 90)
        c.drawPath(face, art.fill(WHITE))
        for m in range(60):
            a = math.radians(m * 6 - 90)
            if m % 5 == 0:
                c.drawLine(math.cos(a) * 70, math.sin(a) * 70, math.cos(a) * 84, math.sin(a) * 84, stroke(INK, 5, cap="butt"))
            else:
                c.drawLine(math.cos(a) * 79, math.sin(a) * 79, math.cos(a) * 85, math.sin(a) * 85, stroke(G3, 2, cap="butt"))
        for num, a in (("12", -90), ("3", 0), ("6", 90), ("9", 180)):
            r = math.radians(a)
            _ctext(c, num, math.cos(r) * 55, math.sin(r) * 55, 26, "deco", INK)
        _ctext(c, "ELECTRIC", 0, 30, 10, "monob", G4)
        h_ang = ((hour % 12) + minute / 60.0) * 30.0
        m_ang = (minute % 60) * 6.0 + secs * 0.1 * (sec is not None)
        _hand(c, h_ang, 46, 13, spade=True)
        _hand(c, m_ang, 72, 9, spade=True)
        c.save(); c.rotate(secs * 6.0)
        c.drawLine(0, 18, 0, -80, stroke(G2, 2.5)); c.drawCircle(0, 18, 5, art.fill(G2))
        c.restore()
        c.drawCircle(0, 0, 8, art.fill(INK)); c.drawCircle(0, 0, 3, art.fill(G5))
        # glass glare
        c.save(); c.clipPath(face, doAntiAlias=True)
        gl = skia.Path(); gl.addArc(skia.Rect.MakeLTRB(-78, -78, 78, 78), 195, 70)
        c.drawPath(gl, stroke(WHITE, 12, a=150))
        c.restore()
        c.drawPath(face, stroke(INK, 4))
        c.drawArc(skia.Rect.MakeLTRB(-104, -104, 104, 104), 200, 60, False, stroke(WHITE, 3, a=200))


# ------------------------------------------------------------------ 12. MAGNIFIER
MAG_NECK = 132          # distance (local, s=1) from the grip point to the bottom of the lens circle


def magnifier_lens_center(x, y, s=1.0, ang=0.0, lens_r=90):
    """World-space lens centre and radius for draw_magnifier(c, x, y, s, ang, lens_r=...).
    Local lens centre is (0, -(MAG_NECK + lens_r)); world = (x + s*d*sin(ang), y - s*d*cos(ang))."""
    d = MAG_NECK + lens_r
    cx, cy = local_to_world(x, y, s, ang, 0, -d)
    return cx, cy, lens_r * s


def draw_magnifier(c, x, y, s=1.0, ang=0.0, t=0.0, lens_r=90, content=None, zoom=2.0, focus=None, **kw):
    """Magnifying glass. Grip (0,0) sits on the handle near its butt end; the lens is 'up' (-y) at ang=0.
    Lens centre (world) = magnifier_lens_center(x, y, s, ang, lens_r) = (x + s*d*sin(ang), y - s*d*cos(ang)),
    d = MAG_NECK + lens_r.  If content (callable content(canvas) drawing in WORLD coords) is given, it is
    drawn inside the lens: clipped to the lens circle, the world point `focus` (default = lens centre) is
    moved to the lens centre and scaled by `zoom` (world magnification, independent of s).
    kw: bg=PAPER (lens backdrop under the content; None to skip)."""
    cx, cy, R = magnifier_lens_center(x, y, s, ang, lens_r)
    if content is not None:
        fx, fy = focus if focus is not None else (cx, cy)
        c.save()
        c.clipPath(_circ(cx, cy, R), doAntiAlias=True)
        bg = kw.get("bg", PAPER)
        if bg:
            c.drawCircle(cx, cy, R, art.fill(bg))
        c.translate(cx, cy); c.scale(zoom, zoom); c.translate(-fx, -fy)
        content(c)
        c.restore()
    d = MAG_NECK + lens_r
    with _at(c, x, y, s, ang):
        # handle
        hd = _rr(-16, -104, 16, 44, 15)
        c.drawPath(hd, art.fill(G1))
        _shade(c, hd, _rr(6, -110, 24, 50, 0), "#0c0c0c")
        for gy in (-80, -70, 14, 24):
            c.drawLine(-14, gy, 14, gy, stroke(G3, 3))
        c.drawLine(-7, -58, -7, 2, stroke(WHITE, 4, a=110))
        c.drawPath(hd, stroke(INK, 6))
        inked(c, _rr(-12, 40, 12, 56, 5), G4, 4)
        inked(c, _rr(-10, -136, 10, -100, 3), G5, 4)
        inked(c, _rr(-18, -112, 18, -98, 6), G4, 4)
        # lens
        lc = -d
        if content is None:
            c.drawCircle(0, lc, lens_r, art.fill(WHITE, 70))
        g = skia.GradientShader.MakeRadial(skia.Point(0, lc), lens_r, [hexc(INK, 0), hexc(INK, 0), hexc(INK, 60)], [0, 0.72, 1])
        c.drawCircle(0, lc, lens_r, skia.Paint(AntiAlias=True, Shader=g))
        c.save(); c.clipPath(_circ(0, lc, lens_r), doAntiAlias=True)
        gl = skia.Path(); gl.addArc(skia.Rect.MakeLTRB(-lens_r * 0.74, lc - lens_r * 0.74, lens_r * 0.74, lc + lens_r * 0.74), 195, 62)
        c.drawPath(gl, stroke(WHITE, lens_r * 0.13, a=210))
        c.drawCircle(-lens_r * 0.62, lc - lens_r * 0.02, lens_r * 0.06, art.fill(WHITE, 210))
        gl2 = skia.Path(); gl2.addArc(skia.Rect.MakeLTRB(-lens_r * 0.8, lc - lens_r * 0.8, lens_r * 0.8, lc + lens_r * 0.8), 20, 40)
        c.drawPath(gl2, stroke(WHITE, lens_r * 0.05, a=150))
        c.restore()
        rr_ = lens_r + 8
        c.drawCircle(0, lc, rr_, stroke(INK, 26))
        c.drawCircle(0, lc, rr_, stroke(G4, 13))
        c.drawArc(skia.Rect.MakeLTRB(-rr_, lc - rr_, rr_, lc + rr_), 200, 70, False, stroke(WHITE, 4, a=220))
        c.drawArc(skia.Rect.MakeLTRB(-rr_, lc - rr_, rr_, lc + rr_), 20, 70, False, stroke(G2, 4))


# ------------------------------------------------------------------ 13. COMMENT BUBBLE
def draw_comment_bubble(c, x, y, s=1.0, t=0.0, ang=0.0, **kw):
    """Generic speech bubble with three typing dots (not any app's logo), (x,y) = centre; gentle pulse with t.
    kw: count=None (little count badge, e.g. '12K')."""
    count = kw.get("count")
    pulse = 1 + 0.045 * math.sin(t * 5.0)
    with _at(c, x, y, s * pulse, ang):
        body = _rr(-82, -58, 82, 46, 44)
        tail = path_poly([(-46, 30), (-70, 82), (-8, 42)])
        b = _union(body, tail)
        c.drawPath(b, art.fill(WHITE))
        _shade(c, b, _rr(-120, 22, 120, 100, 0), G6)
        c.drawPath(b, stroke(INK, 7))
        for i in range(3):
            hop = max(0.0, math.sin(t * 8.0 - i * 0.9))
            dx = -38 + i * 38
            c.drawCircle(dx, -6 - 9 * hop, 12 + 1.5 * hop, art.fill(INK))
        if count is not None:
            lab = str(count)
            bw = max(44, text_width(lab, 26, "anton") + 22)
            bx, by = 74, -52
            inked(c, _rr(bx - bw / 2, by - 19, bx + bw / 2, by + 19, 19), INK, 4, oc=WHITE)
            _ctext(c, lab, bx, by, 26, "anton", MONEY if _is_money(lab) else WHITE)


# ------------------------------------------------------------------ 14. VACUUM NOZZLE
def draw_vacuum_nozzle(c, x, y, s=1.0, ang=0.0, t=0.0, hose_to=(0, 0), suck=0.0, **kw):
    """1950s vacuum nozzle; (x,y) = centre of the mouth (bottom edge) — the mouth faces local +y.
    Wand rises to local (0,-140); a corrugated hose curves from there to WORLD point hose_to (None = no hose).
    suck 0..1 draws white airflow streamlines curling into the mouth (animated with t).
    kw: reach=190 (how far in front the suction reaches), debris=None | 'bills' | 'dust' (things being sucked in)."""
    k = max(0.0, min(1.0, suck))
    if hose_to is not None:
        hx, hy = local_to_world(x, y, s, ang, 0, -140)
        a = math.radians(ang)
        ux, uy = math.sin(a), -math.cos(a)
        ex, ey = hose_to
        D = math.hypot(ex - hx, ey - hy) + 1e-6
        p = skia.Path(); p.moveTo(hx, hy)
        p.cubicTo(hx + ux * D * 0.45, hy + uy * D * 0.45, ex, ey + D * 0.35, ex, ey)
        hw = 34 * s
        c.drawPath(p, stroke(INK, hw + 12 * s))
        c.drawPath(p, stroke(G3, hw))
        rib = stroke(G1, hw, cap="butt"); rib.setPathEffect(skia.DashPathEffect.Make([4 * s, 9 * s], -t * 40 * s * k))
        c.drawPath(p, rib)
        c.drawPath(p, stroke(G5, hw * 0.22, a=200))
    with _at(c, x, y, s, ang):
        if k > 0:
            reach = kw.get("reach", 190)

            def flow(fx_, fy_, u):
                """Point on an airflow streamline from far point F curving up into the mouth."""
                mx_, my_ = fx_ * 0.18, 6.0
                qx_, qy_ = fx_ * 0.12, fy_ * 0.95
                v = 1 - u
                return v * v * fx_ + 2 * v * u * qx_ + u * u * mx_, v * v * fy_ + 2 * v * u * qy_ + u * u * my_

            rnd = np.random.default_rng(21)
            for i in range(10):
                side = -1 if i % 2 else 1
                fx_ = side * reach * rnd.uniform(0.45, 1.25)
                fy_ = reach * rnd.uniform(0.25, 0.85)
                ph = (rnd.uniform(0, 1) + t * (1.2 + 1.6 * k)) % 1.0
                u0, u1 = ph, min(1.0, ph + 0.3 + 0.15 * k)
                st = skia.Path()
                for j in range(9):
                    qx, qy = flow(fx_, fy_, lerp_(u0, u1, j / 8))
                    (st.moveTo if j == 0 else st.lineTo)(qx, qy)
                al = int(255 * k * min(1.0, 3 * math.sin(math.pi * ph)))
                c.drawPath(st, stroke(INK, 10, a=al)); c.drawPath(st, stroke(WHITE, 4.5, a=al))
            deb = kw.get("debris")
            if deb:
                rnd2 = np.random.default_rng(33)
                for i in range(5):
                    side = -1 if i % 2 else 1
                    fx_ = side * reach * rnd2.uniform(0.3, 1.1)
                    fy_ = reach * rnd2.uniform(0.3, 0.8)
                    ph = (rnd2.uniform(0, 1) + t * 0.9) % 1.0
                    u = ph ** 1.5
                    px_, py_ = flow(fx_, fy_, u)
                    sc_ = 0.4 * (0.35 + 0.65 * (1 - u))
                    al = int(255 * min(1.0, 4 * (1 - u)) * min(1.0, 5 * ph))
                    _fade(c, al)
                    if deb == "bills":
                        art.draw_bill(c, px_, py_, sc_, ang=ph * 420 + i * 70)
                    else:
                        r_ = 22 * sc_
                        c.drawCircle(px_, py_, r_, art.fill(G4)); c.drawCircle(px_, py_, r_, stroke(INK, 2.5))
                    c.restore()
        # wand
        c.drawLine(0, -44, 0, -132, stroke(INK, 34)); c.drawLine(0, -44, 0, -132, stroke(G5, 22))
        c.drawLine(-5, -50, -5, -126, stroke(WHITE, 4, a=220))
        inked(c, _rr(-19, -146, 19, -124, 6), G3, 4)
        c.drawLine(-19, -135, 19, -135, stroke(INK, 2.5))
        # swivel
        c.drawCircle(0, -42, 20, art.fill(G3)); c.drawCircle(0, -42, 20, stroke(INK, 5))
        c.drawCircle(0, -42, 7, art.fill(G1))
        # head
        head = skia.Path(); head.moveTo(-112, -2); head.cubicTo(-122, -24, -104, -40, -76, -40)
        head.lineTo(76, -40); head.cubicTo(104, -40, 122, -24, 112, -2); head.close()
        c.drawPath(head, art.fill(G5))
        _shade(c, head, _rr(-130, -22, 130, 4, 0), G4)
        c.drawLine(-80, -32, 70, -32, stroke(WHITE, 5, a=230))
        c.drawPath(head, stroke(INK, 6))
        c.drawLine(-108, -20, 108, -20, stroke(INK, 3))
        # bristles
        br = skia.Rect.MakeLTRB(-108, -3, 108, 9)
        c.drawRect(br, art.fill(G1))
        for xx in range(-104, 108, 6):
            c.drawLine(xx, -1, xx + 1, 8, stroke(G3, 1.5))
        c.drawRect(br, stroke(INK, 3))
        for side in (-1, 1):
            c.drawCircle(side * 100, -14, 6, art.fill(G2))


# ------------------------------------------------------------------ 15. HOOK
def draw_hook(c, x, y, s=1.0, ang=0.0, t=0.0, line_to=None, **kw):
    """Fishing hook hanging from its eye at (x,y); swings gently with t; optional line from WORLD point line_to.
    kw: swing=4.0 (degrees of sway)."""
    swing = kw.get("swing", 4.0)
    if line_to is not None:
        lx, ly = line_to
        p = skia.Path(); p.moveTo(lx, ly)
        p.quadTo((lx + x) / 2 + 6 * s, (ly + y) / 2, x, y)
        c.drawPath(p, stroke(INK, 3.2 * s)); c.drawPath(p, stroke(G6, 1.2 * s, a=180))
    with _at(c, x, y, s, ang + math.sin(t * 2.2) * swing):
        hp = skia.Path(); hp.moveTo(0, 12); hp.lineTo(0, 106)
        hp.cubicTo(0, 152, -56, 152, -56, 106); hp.lineTo(-55, 82)
        c.drawPath(hp, stroke(INK, 16)); c.drawPath(hp, stroke(G5, 8))
        tip = path_poly([(-63, 86), (-55, 58), (-47, 86)])
        inked(c, tip, G5, 4)
        barb = path_poly([(-55, 70), (-40, 98), (-51, 90)])
        inked(c, barb, G5, 3.5)
        hl = skia.Path(); hl.moveTo(-3, 22); hl.lineTo(-3, 104); hl.cubicTo(-4, 138, -40, 142, -50, 116)
        c.drawPath(hl, stroke(WHITE, 2.5, a=230))
        c.drawCircle(0, 0, 11, stroke(INK, 11)); c.drawCircle(0, 0, 11, stroke(G5, 4))
        tw = abs(math.sin(t * 2.7))
        if tw > 0.3:
            _sparkle(c, -40, 140, 12 * tw)


# ------------------------------------------------------------------ 16. TUB X-RAY
def draw_tub_xray(c, x, y, s=1.0, t=0.0, reveal=1.0, ang=0.0, **kw):
    """X-ray of the striped popcorn tub (same silhouette/heap as art.draw_popcorn, origin bottom-centre).
    Dark slate body, white outlines, visible kernels, oil+salt pool, paper wall; three tags
    ('CORN', 'OIL + SALT', 'TUB') fade/pop in one after another as reveal goes 0->1; a scan bar sweeps with t.
    kw: seed=3 (must match the draw_popcorn seed), costs=None (3 strings drawn green under the tags),
        labels=('CORN','OIL + SALT','TUB'), scan=True."""
    seed = kw.get("seed", 3)
    costs = kw.get("costs")
    labels = kw.get("labels", ("CORN", "OIL + SALT", "TUB"))
    scan = kw.get("scan", True)
    Hh, BW, TW = 300, 190, 270
    body = path_poly([(-BW / 2, 0), (BW / 2, 0), (TW / 2, -Hh), (-TW / 2, -Hh)])
    rnd = random.Random(seed)                    # identical heap to art.draw_popcorn(seed=...)
    puffs = []
    for i in range(22):
        px = rnd.uniform(-TW / 2 + 20, TW / 2 - 20)
        py = -Hh - rnd.uniform(-5, 70) * (1 - abs(px) / (TW / 2) * 0.6)
        puffs.append((px, py, rnd.uniform(24, 36)))
    puffs.sort(key=lambda q: q[1])
    puff_paths = []
    for px, py, r in puffs:
        pf = skia.Path()
        for k in range(4):
            a = k * math.pi / 2 + rnd.random()
            pf.addCircle(px + math.cos(a) * r * 0.45, py + math.sin(a) * r * 0.45, r * 0.62)
        pf.setFillType(skia.PathFillType.kWinding)
        puff_paths.append((pf, px, py, r))
    SL = "#1f2223"
    with _at(c, x, y, s, ang):
        # heap
        heap = skia.Path()
        for pf, *_ in puff_paths:
            heap = skia.Op(heap, pf, skia.PathOp.kUnion_PathOp)
        whole = skia.Op(heap, body, skia.PathOp.kUnion_PathOp)
        _soft_glow(c, 0, -Hh * 0.6, 330, 70)
        c.drawPath(whole, art.fill(SL))
        g = skia.GradientShader.MakeRadial(skia.Point(0, -Hh * 0.55), 260, [hexc("#4a5052"), hexc(SL)])
        c.drawPath(body, skia.Paint(AntiAlias=True, Shader=g))
        c.save(); c.clipPath(body, doAntiAlias=True)
        for i in range(-6, 7):                                       # ghost stripes
            if i % 2 == 0:
                continue
            x0b, x0t = i * BW / 10, i * TW / 10
            st = path_poly([(x0b - BW / 20, 0), (x0b + BW / 20, 0), (x0t + TW / 20, -Hh), (x0t - TW / 20, -Hh)])
            c.drawPath(st, art.fill(WHITE, 16))
        # oil + salt pool
        oil_y = -46
        oil = skia.Path(); oil.moveTo(-160, oil_y)
        for i in range(9):
            oil.quadTo(-140 + i * 40, oil_y - 7 + 2 * math.sin(t * 3 + i), -120 + i * 40, oil_y)
        oil.lineTo(160, 10); oil.lineTo(-160, 10); oil.close()
        c.drawPath(oil, art.fill(WHITE, 55))
        c.drawPath(oil, stroke(WHITE, 3, a=220))
        r2 = np.random.default_rng(seed + 100)
        for i in range(26):
            c.drawRect(skia.Rect.MakeXYWH(r2.uniform(-90, 86), r2.uniform(-36, -8), 3.5, 3.5), art.fill(WHITE, 230))
        # loose kernels in the tub
        for i in range(34):
            yy = r2.uniform(-Hh + 10, oil_y - 12)
            half = (BW / 2 + (TW - BW) / 2 * (-yy / Hh)) - 22
            xx = r2.uniform(-half, half)
            rad = r2.uniform(3.5, 7.5)
            if i % 4 == 0:   # unpopped kernel (teardrop)
                c.save(); c.translate(xx, yy); c.rotate(r2.uniform(0, 360))
                kp = skia.Path(); kp.moveTo(0, -8); kp.quadTo(8, 2, 0, 7); kp.quadTo(-8, 2, 0, -8)
                c.drawPath(kp, art.fill(WHITE, 220)); c.restore()
            else:
                c.drawCircle(xx, yy, rad, stroke(WHITE, 2, a=150)); c.drawCircle(xx, yy, rad * 0.35, art.fill(WHITE, 200))
        if scan:
            sy = -Hh - 70 + ((t * 0.55) % 1.0) * (Hh + 70)
            gb = skia.GradientShader.MakeLinear([skia.Point(0, sy - 40), skia.Point(0, sy + 4)],
                                                [hexc(WHITE, 0), hexc(WHITE, 70)])
            c.drawRect(skia.Rect.MakeLTRB(-200, sy - 40, 200, sy), skia.Paint(AntiAlias=True, Shader=gb))
            c.drawLine(-200, sy, 200, sy, stroke(WHITE, 3, a=200))
        c.restore()
        # paper wall (inner offset)
        wall = path_poly([(-BW / 2 + 12, -8), (BW / 2 - 12, -8), (TW / 2 - 12, -Hh + 14), (-TW / 2 + 12, -Hh + 14)])
        wp = stroke(WHITE, 2.5, a=170); wp.setPathEffect(skia.DashPathEffect.Make([12, 8], 0))
        c.drawPath(wall, wp)
        # heap puffs (x-ray: dark with white outline and a kernel heart)
        for pf, px, py, r in puff_paths:
            c.drawPath(pf, art.fill("#2a2e2f")); c.drawPath(pf, stroke(WHITE, 3, a=235))
            c.drawCircle(px + r * 0.1, py + r * 0.05, r * 0.2, art.fill(WHITE, 210))
        rim = _rr(-TW / 2 - 8, -Hh - 6, TW / 2 + 8, -Hh + 20, 8)
        c.drawPath(rim, art.fill("#2f3334")); c.drawPath(rim, stroke(WHITE, 4))
        c.drawPath(body, stroke(WHITE, 5))
        c.drawPath(body, stroke(INK, 2, a=120))
        # tags
        cr = puffs[len(puffs) // 2]
        specs = (
            ((cr[0], cr[1]), (TW / 2 + 70, -Hh - 80), labels[0]),
            ((-30, -26), (-BW / 2 - 120, -60), labels[1]),
            ((BW / 2 + (TW - BW) / 2 * 0.5 - 6, -Hh * 0.5), (TW / 2 + 70, -Hh * 0.42), labels[2]),
        )
        for i, ((ax, ay), (tx, ty), lab) in enumerate(specs):
            kq = max(0.0, min(1.0, reveal * 3 - i))
            if kq <= 0:
                continue
            e = 1 - (1 - kq) ** 3
            pop = 1 + 0.25 * math.sin(math.pi * kq) * (1 - kq)
            _fade(c, 255 * e)
            ex_, ey_ = lerp_(ax, tx, e), lerp_(ay, ty, e)
            c.drawLine(ax, ay, ex_, ey_, stroke(INK, 7)); c.drawLine(ax, ay, ex_, ey_, stroke(WHITE, 3))
            c.drawCircle(ax, ay, 8, art.fill(WHITE)); c.drawCircle(ax, ay, 8, stroke(INK, 3))
            c.save(); c.translate(tx, ty); c.scale(pop * (0.6 + 0.4 * e), pop * (0.6 + 0.4 * e))
            tw_ = text_width(lab, 32, "anton") + 30
            th = 50 if not costs else 82
            left = -tw_ / 2
            tagp = _rr(left, -25, left + tw_, -25 + th, 10)
            c.drawPath(_rr(left + 6, -19, left + tw_ + 6, -19 + th, 10), art.fill("#000000", 70))
            inked(c, tagp, WHITE, 5)
            _ctext(c, lab, 0, 0, 32, "anton", INK)
            if costs and i < len(costs):
                _ctext(c, costs[i], 0, 34, 28, "anton", MONEY, outline=MONEY_D, ow=4)
            c.restore()
            c.restore()
