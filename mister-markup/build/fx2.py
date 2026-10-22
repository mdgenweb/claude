"""Attention-grabbing cartoon VFX (1950s B&W house style, money green only).

Every function is stateless: a pure function of its arguments (time t in seconds, a
trigger time t0, and a seed for deterministic numpy randomness). Nothing is cached.
Drawing functions take a skia canvas `c` first; utility curves return numbers.
"""
import math
import numpy as np
import skia
import art
from art import (W, H, INK, WHITE, PAPER, G1, G2, G3, G4, G5, G6, MONEY, MONEY_D, MONEY_L,
                 TF, fill, stroke, inked, path_poly, hexc)


# ------------------------------------------------------------------ small helpers
def _rng(seed):
    return np.random.default_rng(int(seed) & 0xFFFFFFFF)


def _clamp(v, a=0.0, b=1.0):
    return a if v < a else b if v > b else v


def _ease_out_cubic(k):
    k = _clamp(k)
    return 1 - (1 - k) ** 3


def _ease_in_out(k):
    k = _clamp(k)
    return k * k * (3 - 2 * k)


def _ease_out_back(k, s=2.165):
    k = _clamp(k)
    u = k - 1
    return 1 + (s + 1) * u ** 3 + s * u ** 2


def _cap(font):
    return font.getMetrics().fCapHeight


def _star4(r, thin=0.24):
    return path_poly([(0, -r), (r * thin, -r * thin), (r, 0), (r * thin, r * thin), (0, r),
                      (-r * thin, r * thin), (-r, 0), (-r * thin, -r * thin)])


def _poly_at_radius(pts, rr):
    """First point where a polyline starting near the origin crosses distance rr (or None)."""
    for (x0, y0), (x1, y1) in zip(pts[:-1], pts[1:]):
        d0, d1 = math.hypot(x0, y0), math.hypot(x1, y1)
        if (d0 - rr) * (d1 - rr) <= 0 and d0 != d1:
            k = (rr - d0) / (d1 - d0)
            return (x0 + (x1 - x0) * k, y0 + (y1 - y0) * k)
    return None


# ------------------------------------------------------------------ 10. pop_in
def pop_in(t, t0, dur=0.25):
    """Overshoot scale curve 0 -> ~1.15 -> 1 (ease-out-back). 0 before t0, 1 after t0+dur."""
    if t <= t0:
        return 0.0
    if t >= t0 + dur:
        return 1.0
    return _ease_out_back((t - t0) / dur)


# ------------------------------------------------------------------ 11. squash_hop
def squash_hop(t, t0, height=60, dur=0.35):
    """Anticipation squash -> hop -> landing squash. Returns (dy, sx, sy); dy<0 is up.
    Apply around the character's feet: translate(x, y+dy); scale(sx, sy)."""
    if t <= t0 or t >= t0 + dur:
        return 0.0, 1.0, 1.0
    k = (t - t0) / dur
    A, L = 0.2, 0.78  # anticipation end, landing start
    dy = 0.0
    if k < A:
        sy = 1 - 0.2 * math.sin(math.pi * k / A)
    elif k < L:
        u = (k - A) / (L - A)
        dy = -height * 4 * u * (1 - u)
        sy = 1 + 0.14 * math.sin(2 * math.pi * u) ** 2
    else:
        v = (k - L) / (1 - L)
        sy = 1 - 0.24 * math.sin(math.pi * v) * (1 - 0.25 * v)
    sx = 1 + (1 - sy) * 0.9
    return dy, sx, sy


# ------------------------------------------------------------------ 13. impact_text_shake
def impact_text_shake(t, t0, amp=18, dur=0.3):
    """Decaying shake offsets (dx, dy) for text/objects."""
    dt = t - t0
    if dur <= 0 or dt < 0 or dt > dur:
        return 0.0, 0.0
    dec = (1 - dt / dur) ** 2
    dx = amp * dec * math.sin(dt * 97 + 0.4)
    dy = amp * dec * 0.75 * math.sin(dt * 123 + 1.9)
    return dx, dy


# ------------------------------------------------------------------ 1. action_word
def _burst_paths(r, rx, ry, spike, inset):
    """Comic burst around an ellipse: spikes spaced evenly by arc length and pushed out along
    the ellipse normal (so long words get even spikes, not needles). Returns (outer, inner)
    paths built from the same vertices; inner is inset along the normals by `inset`."""
    m = 360
    th = np.linspace(0, 2 * np.pi, m + 1)
    ex, ey = rx * np.cos(th), ry * np.sin(th)
    seg = np.hypot(np.diff(ex), np.diff(ey))
    arc = np.concatenate([[0.0], np.cumsum(seg)])
    per = arc[-1]
    n = max(9, int(round(per / (spike * 1.15))))
    off = r.uniform(0, 1)
    outer, inner = [], []
    for i in range(n * 2):
        s = ((i + off + r.uniform(-0.18, 0.18)) / (n * 2)) % 1.0 * per
        a = float(np.interp(s, arc, th))
        px, py = rx * math.cos(a), ry * math.sin(a)
        nx, ny = math.cos(a) / rx, math.sin(a) / ry
        nl = math.hypot(nx, ny)
        nx, ny = nx / nl, ny / nl
        d = spike * r.uniform(0.75, 1.3) if i % 2 == 0 else -spike * r.uniform(0.02, 0.2)
        ox, oy = px + nx * d, py + ny * d
        outer.append((ox, oy))
        ii = inset * (1.5 if i % 2 == 0 else 1.0)
        inner.append((ox - nx * ii, oy - ny * ii))
    return path_poly(outer), path_poly(inner)


def action_word(c, x, y, word, t, t0, life=0.7, size=120, seed=1, money=False, ang=-8):
    """Comic 'POW!' pop: jagged two-tier burst + extruded Bungee word, overshoot pop-in,
    rubbery wobble, shrink/fade over the last 25% of life."""
    dt = t - t0
    if life <= 0 or dt < 0 or dt > life:
        return
    word = str(word)
    # --- scale envelope: 0 -> 1.25 (0.075 s) -> 1 (0.15 s) -> damped wobble -> shrink out
    if dt < 0.075:
        sc = 1.25 * math.sin(0.5 * math.pi * dt / 0.075)
    elif dt < 0.15:
        sc = 1.25 - 0.25 * _ease_in_out((dt - 0.075) / 0.075)
    else:
        sc = 1 + 0.045 * math.sin((dt - 0.15) * 30) * math.exp(-(dt - 0.15) * 7)
    k_out = _clamp((dt - 0.75 * life) / (0.25 * life))
    sc *= 1 - 0.7 * k_out ** 1.6
    alpha = int(255 * (1 - k_out ** 1.3))
    if sc <= 0.01 or alpha <= 0:
        return
    rot = ang + 5 * math.sin(dt * 24) * math.exp(-dt * 5) + 1.2 * math.sin(dt * 9)
    r = _rng(seed)
    font = skia.Font(TF["bungee"], size)
    tw = font.measureText(word)
    rx = tw / 2 + size * 0.5
    ry = max(size * 0.78, rx * 0.36)
    outer, inner = _burst_paths(r, rx, ry, spike=size * 0.52, inset=size * 0.2)
    rx_t, ry_t = rx + size * 0.5, ry + size * 0.5  # tick ring

    c.save(); c.translate(x, y - 26 * dt); c.rotate(rot); c.scale(sc, sc)
    c.saveLayerAlpha(None, alpha)
    sw = max(6.0, size * 0.065)
    # flying action ticks around the burst (first 0.3 s)
    if dt < 0.3:
        kk = dt / 0.3
        rt = _rng(seed + 77)
        for i in range(12):
            a = 2 * math.pi * (i + rt.uniform(-0.25, 0.25)) / 12
            r0 = 0.95 + 0.45 * _ease_out_cubic(kk)
            r1 = r0 + 0.35 * (1 - kk) + 0.05
            p0 = (math.cos(a) * rx_t * r0, math.sin(a) * ry_t * r0)
            p1 = (math.cos(a) * rx_t * r1, math.sin(a) * ry_t * r1)
            c.drawLine(*p0, *p1, stroke(INK, sw * 2.2 * (1 - kk) + 2))
            c.drawLine(*p0, *p1, stroke(WHITE, sw * 0.9 * (1 - kk) + 0.5))
    # hard comic drop shadow
    c.save(); c.translate(size * 0.11, size * 0.13); c.drawPath(outer, fill(INK)); c.restore()
    inked(c, outer, MONEY_D if money else G4, sw)
    inked(c, inner, MONEY if money else WHITE, sw * 0.6)
    # soft inner rim shading (flat tone, clipped) for a little depth
    c.save(); c.clipPath(inner, doAntiAlias=True)
    c.drawPath(inner, stroke(MONEY_L if money else G6, size * 0.16))
    c.restore()
    c.drawPath(inner, stroke(INK, sw * 0.6))
    # --- the word: per-letter rubber bounce, 3D extrude, thick outline, two-tone fill
    cap = _cap(font)
    x0, base = -tw / 2, cap / 2
    ow = max(8.0, size * 0.15)
    ext = size * 0.075
    lo = MONEY_L if money else G6
    two_tone = skia.GradientShader.MakeLinear([skia.Point(0, -cap), skia.Point(0, 0)],
                                              [hexc(WHITE), hexc(WHITE), hexc(lo), hexc(lo)], [0, 0.55, 0.55, 1])
    p_out = skia.Paint(AntiAlias=True, Color=hexc(INK), Style=skia.Paint.kStroke_Style, StrokeWidth=ow,
                       StrokeJoin=skia.Paint.kRound_Join)
    p_ext = skia.Paint(AntiAlias=True, Color=hexc(INK))
    p_fill = skia.Paint(AntiAlias=True, Shader=two_tone)
    glyphs = []
    for i, ch in enumerate(word):
        gx = x0 + font.measureText(word[:i])
        gy = base + math.sin(i * 1.9 + dt * 16) * size * 0.035 * math.exp(-dt * 2)
        gr = math.sin(i * 2.7 + dt * 13) * 4 * math.exp(-dt * 3)
        glyphs.append((ch, gx, gy, gr, font.measureText(ch)))
    for layer in range(3):
        for ch, gx, gy, gr, gw in glyphs:
            c.save(); c.translate(gx + gw / 2, gy - cap / 2); c.rotate(gr); c.translate(-gw / 2, cap / 2)
            if layer == 0:
                c.save(); c.translate(ext, ext); c.drawString(ch, 0, 0, font, p_out); c.drawString(ch, 0, 0, font, p_ext); c.restore()
            elif layer == 1:
                c.drawString(ch, 0, 0, font, p_out)
            else:
                c.drawString(ch, 0, 0, font, p_fill)
            c.restore()
    c.restore()
    c.restore()


# ------------------------------------------------------------------ 2. screen_crack
def screen_crack(c, x, y, t, t0, life=1.1, seed=1, size=520):
    """Shattered-glass crack radiating from (x, y): jagged main cracks, branches, web rings,
    glassy facets, flying chips; propagates in ~0.1 s, holds, fades over the last 40%."""
    dt = t - t0
    if life <= 0 or dt < 0 or dt > life:
        return
    k = dt / life
    alpha = int(255 * (1 - _clamp((k - 0.6) / 0.4)))
    if alpha <= 0:
        return
    r = _rng(seed)
    n = int(r.integers(8, 15))
    cracks = []  # (pts, base_width)
    mains = []
    for i in range(n):
        a = 2 * math.pi * (i + r.uniform(-0.3, 0.3)) / n
        L = size * r.uniform(0.55, 1.0)
        segs = int(r.integers(4, 7))
        step = L / segs
        hd, px, py = a, math.cos(a) * 7, math.sin(a) * 7
        pts = [(px, py)]
        heads = [hd]
        for _ in range(segs):
            hd = a + r.uniform(-0.16, 0.16)  # glass cracks run straight with small kinks
            st = step * r.uniform(0.7, 1.3)
            px, py = px + math.cos(hd) * st, py + math.sin(hd) * st
            pts.append((px, py)); heads.append(hd)
        mains.append(pts)
        cracks.append((pts, 6.5))
        for _ in range(int(r.integers(1, 4))):
            j = int(r.integers(2, segs))
            bh = heads[j] + r.choice([-1, 1]) * r.uniform(0.4, 0.9)
            bl = L * r.uniform(0.14, 0.36)
            bs = int(r.integers(2, 4))
            bx, by = pts[j]
            bpts = [(bx, by)]
            for _ in range(bs):
                bh += r.uniform(-0.2, 0.2)
                st = bl / bs * r.uniform(0.7, 1.3)
                bx, by = bx + math.cos(bh) * st, by + math.sin(bh) * st
                bpts.append((bx, by))
            cracks.append((bpts, 4.0))
    # concentric "spider-web" rings + facets between neighbouring cracks
    rings, facets = [], []
    for ri, rr0 in enumerate((0.13, 0.3, 0.5)):
        for i in range(n):
            if r.random() > (0.85 - ri * 0.2):
                continue
            rr = size * rr0 * r.uniform(0.85, 1.15)
            pa, pb = _poly_at_radius(mains[i], rr), _poly_at_radius(mains[(i + 1) % n], rr * r.uniform(0.9, 1.1))
            if pa is None or pb is None:
                continue
            mx, my = (pa[0] + pb[0]) / 2, (pa[1] + pb[1]) / 2
            j = r.uniform(-0.12, 0.12) * rr
            mid = (mx + mx / (math.hypot(mx, my) + 1e-6) * j, my + my / (math.hypot(mx, my) + 1e-6) * j)
            rings.append(([pa, mid, pb], 3.2))
            if ri == 0 or (ri == 1 and r.random() < 0.45):
                facets.append((pa, mid, pb, ri, r.uniform(0.0, 1.0)))
    # radial propagation: everything is revealed by a growing clip circle
    grow = _ease_out_cubic(dt / 0.11)
    reach = size * 1.15 * grow
    c.save(); c.translate(x, y)
    c.saveLayerAlpha(None, alpha)
    c.save()
    clip = skia.Path(); clip.addCircle(0, 0, max(1.0, reach)); c.clipPath(clip, doAntiAlias=True)
    # glassy facets (white glint panes near the impact)
    for pa, mid, pb, ri, tone in facets:
        fp = path_poly([(0, 0), pa, mid, pb]) if ri == 0 else None
        if fp is not None:
            c.drawPath(fp, fill(WHITE, int(26 + 40 * tone)))
    for pa, mid, pb, ri, tone in facets:
        if ri == 1 and tone > 0.5:
            c.drawPath(path_poly([pa, mid, pb]), fill(WHITE, 30))
    # shadow pass then white pass, tapered segment by segment
    for passno in range(2):
        for pts, bw in cracks + rings:
            m = len(pts) - 1
            for j in range(m):
                w = bw * (1 - 0.6 * j / max(1, m))
                (x0, y0), (x1, y1) = pts[j], pts[j + 1]
                if passno == 0:
                    c.drawLine(x0 + 2.5, y0 + 3.5, x1 + 2.5, y1 + 3.5, stroke(INK, w + 4, a=190))
                else:
                    c.drawLine(x0, y0, x1, y1, stroke(WHITE, w))
    c.restore()
    # impact point: bright core + glow, plus a first-instant flash
    fl = 1 - _clamp(dt / 0.12)
    g = skia.GradientShader.MakeRadial(skia.Point(0, 0), 70 + 140 * fl,
                                       [hexc(WHITE, 230), hexc(WHITE, int(60 + 120 * fl)), hexc(WHITE, 0)], [0, 0.35, 1])
    c.drawCircle(0, 0, 70 + 140 * fl, skia.Paint(AntiAlias=True, Shader=g))
    core = _star4(26 + 30 * fl, 0.3)
    c.drawPath(core, fill(WHITE)); c.drawPath(core, stroke(INK, 3))
    c.drawCircle(0, 0, 9, fill(WHITE)); c.drawCircle(0, 0, 9, stroke(INK, 3))
    # flying glass chips (first 0.45 s)
    if dt < 0.45:
        kk = dt / 0.45
        rc = _rng(seed + 991)
        for i in range(9):
            a = rc.uniform(0, 2 * math.pi)
            v = rc.uniform(380, 900)
            cx = math.cos(a) * v * dt
            cy = math.sin(a) * v * dt + 0.5 * 2400 * dt * dt
            s = rc.uniform(7, 15) * (1 - kk * 0.6)
            c.save(); c.translate(cx, cy); c.rotate(rc.uniform(0, 360) + dt * rc.uniform(-900, 900))
            chip = path_poly([(-s, -s * 0.5), (s, -s * 0.8), (s * 0.3, s)])
            ca = int(255 * (1 - kk) ** 0.5)
            c.drawPath(chip, fill(WHITE, ca)); c.drawPath(chip, stroke(INK, 3, a=ca))
            c.restore()
    c.restore()
    c.restore()


# ------------------------------------------------------------------ 3. slot_roll
def slot_roll(c, x, y, values, t, t0, dur=0.8, size=110, font="bungee", color=WHITE, outline=INK, box=True):
    """Slot-machine reel centred at (x, y): values scroll down through a clipped window,
    decelerate, clunk onto values[-1] at t0+dur with a bounce, then stay there."""
    if t < t0 or not values:
        return
    values = [str(v) for v in values]
    N = len(values)
    f = skia.Font(TF[font], size)
    cap = _cap(f)
    bw = max(f.measureText(v) for v in values) + size * 0.7
    bh = size * 1.5
    pitch = size * 1.22
    tau = t - t0 - dur
    total = N - 1
    # reel position in items. f(k) = 1 - (1-A)(1-k)^3 - A(1-k): fast start, decelerates, but still
    # carries speed A when it reaches values[-1] exactly at t0+dur, so the clunk lands on time.
    A = 0.4
    if dur > 0 and tau < 0:
        k = _clamp((t - t0) / dur)
        u = 1 - k
        p = total * (1 - (1 - A) * u ** 3 - A * u)
        vel = total * (3 * (1 - A) * u * u + A) / dur  # items / s
    else:
        p, vel = float(total), 0.0
    punch = 1.0
    if tau >= 0:
        w_b = 28.0
        v_arr = total * A / dur if dur > 0 else 0.0
        amp = _clamp(v_arr / w_b, 0.07, 0.2)  # overshoot matches arrival speed, always a visible clunk
        p = total + amp * math.sin(tau * w_b) * math.exp(-tau * 11)
        punch = 1 + 0.09 * math.sin(tau * 26) * math.exp(-tau * 10)
    win = skia.Rect.MakeLTRB(-bw / 2, -bh / 2, bw / 2, bh / 2)
    rad = size * 0.24
    rr = skia.RRect.MakeRectXY(win, rad, rad)
    c.save(); c.translate(x, y); c.scale(punch, punch)
    if box:
        c.drawRRect(skia.RRect.MakeRectXY(win.makeOffset(size * 0.07, size * 0.09), rad, rad), fill(INK))
        c.drawRRect(rr, fill("#1b1b1b"))
    c.save(); c.clipRRect(rr, doAntiAlias=True)
    if not box:  # no drum: fade the rows out at the window edges instead of a hard cut
        c.saveLayer(None, None)
    sig = min(size * 0.1, vel * pitch / 24 / 7)
    if sig > 0.6:
        lp = skia.Paint(ImageFilter=skia.ImageFilters.Blur(0.01, sig))
        c.saveLayer(None, lp)
    p_o = None
    if outline:
        p_o = skia.Paint(AntiAlias=True, Color=hexc(outline), Style=skia.Paint.kStroke_Style,
                         StrokeWidth=max(6.0, size * 0.12), StrokeJoin=skia.Paint.kRound_Join)
    p_f = skia.Paint(AntiAlias=True, Color=hexc(color))
    base_i = int(math.floor(p))
    for i in range(base_i - 2, base_i + 3):
        yc = (p - i) * pitch
        if abs(yc) > bh / 2 + pitch:
            continue
        s = values[i % N]
        sx = -f.measureText(s) / 2
        if p_o is not None:
            c.drawString(s, sx, yc + cap / 2, f, p_o)
        c.drawString(s, sx, yc + cap / 2, f, p_f)
    if sig > 0.6:
        c.restore()
    if not box:
        gm = skia.GradientShader.MakeLinear([skia.Point(0, -bh / 2), skia.Point(0, bh / 2)],
                                            [hexc("#000000", 0), hexc("#000000"), hexc("#000000"), hexc("#000000", 0)],
                                            [0.0, 0.2, 0.8, 1.0])
        c.drawRect(win, skia.Paint(Shader=gm, BlendMode=skia.BlendMode.kDstIn))
        c.restore()
    if box:
        # drum shading: dark top/bottom, glossy highlight band
        g = skia.GradientShader.MakeLinear([skia.Point(0, -bh / 2), skia.Point(0, bh / 2)],
                                           [hexc("#000000", 230), hexc("#000000", 0), hexc("#000000", 0), hexc("#000000", 230)],
                                           [0, 0.3, 0.7, 1])
        c.drawRect(win, skia.Paint(AntiAlias=True, Shader=g))
        c.drawRoundRect(skia.Rect.MakeLTRB(-bw / 2 + size * 0.18, -bh / 2 + size * 0.1, bw / 2 - size * 0.18, -bh / 2 + size * 0.22),
                        size * 0.06, size * 0.06, fill(WHITE, 55))
    c.restore()
    if box:
        c.drawRRect(rr, stroke(INK, max(10.0, size * 0.13)))
        c.drawRRect(rr, stroke(WHITE, max(4.0, size * 0.05)))
        # pointer notches on both sides of the pay line
        for sd in (-1, 1):
            ex = sd * (bw / 2 + size * 0.02)
            tri = path_poly([(ex + sd * size * 0.2, -size * 0.17), (ex - sd * size * 0.08, 0), (ex + sd * size * 0.2, size * 0.17)])
            inked(c, tri, WHITE, max(4.0, size * 0.045))
    c.restore()


# ------------------------------------------------------------------ 4. typewriter
def typewriter(c, s, x, y, t, t0, cps=28, size=40, font="mono", color=INK, align="left", cursor=True):
    """Reveal s char-by-char from t0 at cps chars/s (supports '\\n'); the newest letter
    lands with a tiny pop; block cursor is solid while typing and blinks after.
    Alignment is computed from the full line so text never slides. Returns chars shown."""
    if t < t0:
        return 0
    f = skia.Font(TF[font], size)
    cap = _cap(f)
    lh = size * 1.28
    s = str(s)
    prog = (t - t0) * cps if cps > 0 else float(len(s))
    n = int(_clamp(math.floor(prog), 0, len(s)))
    full_lines = s.split("\n")
    shown_lines = s[:n].split("\n")
    paint = skia.Paint(AntiAlias=True, Color=hexc(color))

    def x0_of(li):
        fw = f.measureText(full_lines[li])
        return x - (fw / 2 if align == "center" else fw if align == "right" else 0)

    typing = n < len(s)
    for li, ln in enumerate(shown_lines):
        bx, by = x0_of(li), y + li * lh
        last = li == len(shown_lines) - 1
        if last and typing and ln and ln[-1] != " ":
            frac = prog - n
            c.drawString(ln[:-1], bx, by, f, paint)
            ch = ln[-1]
            cx = bx + f.measureText(ln[:-1])
            cw = f.measureText(ch)
            sc = 1 + 0.45 * (1 - _clamp(frac * 2.2))
            c.save(); c.translate(cx + cw / 2, by - cap / 2); c.scale(sc, sc); c.translate(-cw / 2, cap / 2)
            c.drawString(ch, 0, 0, f, paint)
            c.restore()
        else:
            c.drawString(ln, bx, by, f, paint)
    if cursor:
        li = len(shown_lines) - 1
        bx, by = x0_of(li), y + li * lh
        cx = bx + f.measureText(shown_lines[-1])
        t_done = t0 + (len(s) / cps if cps > 0 else 0.0)
        on = typing or int((t - t_done) * 3.2) % 2 == 0
        if on:
            c.drawRect(skia.Rect.MakeLTRB(cx + size * 0.06, by - cap * 1.08, cx + size * 0.62, by + size * 0.14), paint)
    return n


# ------------------------------------------------------------------ 5. zoom_lines
def zoom_lines(c, cx, cy, t, strength=1.0, seed=0, inner=380, n=56):
    """Manga focus lines: thin black and white wedges from beyond the screen edges converging
    on (cx, cy) and stopping near radius `inner`; re-jittered every 1/24 s."""
    st = _clamp(strength, 0.0, 1.5)
    if st <= 0:
        return
    r = _rng(seed + int(t * 24))
    R = max(math.hypot(cx - ex, cy - ey) for ex in (0, W) for ey in (0, H)) + 80
    a_ink = int(_clamp(225 * st, 0, 255))
    a_wht = int(_clamp(200 * st, 0, 255))
    for i in range(n):
        a = 2 * math.pi * (i + r.uniform(-0.45, 0.45)) / n
        rin = inner * (r.uniform(1.0, 1.25) if r.random() < 0.6 else r.uniform(1.3, 1.9))
        hw = r.uniform(6, 30) * (0.6 + 0.4 * st)
        ca, sa = math.cos(a), math.sin(a)
        tip = (cx + ca * rin, cy + sa * rin)
        b0 = (cx + ca * R - sa * hw, cy + sa * R + ca * hw)
        b1 = (cx + ca * R + sa * hw, cy + sa * R - ca * hw)
        dark = i % 2 == 0
        c.drawPath(path_poly([tip, b0, b1]), fill(INK if dark else WHITE, a_ink if dark else a_wht))


# ------------------------------------------------------------------ 6. contact_shadow
def contact_shadow(c, x, y, w, alpha=110, squash=0.18):
    """Soft floor shadow (radial gradient ellipse, no hard edge) centred at (x, y), width w."""
    if w <= 0 or alpha <= 0:
        return
    alpha = _clamp(alpha, 0, 255)
    rad = w / 2
    g = skia.GradientShader.MakeRadial(skia.Point(0, 0), rad,
                                       [hexc("#000000", int(alpha)), hexc("#000000", int(alpha * 0.75)),
                                        hexc("#000000", int(alpha * 0.3)), hexc("#000000", 0)], [0, 0.35, 0.7, 1])
    c.save(); c.translate(x, y); c.scale(1, squash)
    c.drawCircle(0, 0, rad, skia.Paint(AntiAlias=True, Shader=g))
    c.restore()


# ------------------------------------------------------------------ 7. halftone_wipe
def halftone_wipe(c, t, t0, dur=0.35, direction=1, color=INK):
    """Transition: hex grid of halftone dots grows in sweeping across the screen (left->right for
    direction=1), covers it completely at the midpoint, then shrinks away in the same direction."""
    dt = t - t0
    if dur <= 0 or dt < 0 or dt > dur:
        return
    k = dt / dur
    g = 64.0
    dy = g * 0.866
    rfull = g * 0.62  # > g/sqrt(3): hex grid fully covered
    band = 0.4
    paint = fill(color)
    rows = int(H / dy) + 3
    cols = int(W / g) + 3
    for j in range(-1, rows):
        yy = j * dy
        off = (g / 2) if j % 2 else 0.0
        for i in range(-1, cols):
            xx = i * g + off
            u = _clamp((xx / W) * 0.82 + (yy / H) * 0.18, 0, 1)
            if direction < 0:
                u = 1 - u
            if k <= 0.5:
                q = _clamp((k * 2 * (1 + band) - u) / band)
            else:
                q = 1 - _clamp(((k - 0.5) * 2 * (1 + band) - u) / band)
            if q <= 0:
                continue
            c.drawCircle(xx, yy, rfull * _ease_in_out(q) if q < 1 else rfull, paint)


# ------------------------------------------------------------------ 8. money_flash
def money_flash(c, t, t0, dur=0.25, alpha=90):
    """Brief full-screen money-green tint: snappy attack, quadratic fade."""
    dt = t - t0
    if dur <= 0 or dt < 0 or dt > dur:
        return
    k = dt / dur
    env = k / 0.12 if k < 0.12 else (1 - (k - 0.12) / 0.88) ** 2
    a = int(_clamp(alpha * env, 0, 255))
    if a > 0:
        c.drawRect(skia.Rect.MakeWH(W, H), fill(MONEY, a))


# ------------------------------------------------------------------ 9. afterimages
def afterimages(c, draw_fn, positions, alpha0=110):
    """Motion trail. positions = [(x, y, extra), ...] oldest->newest. Draws ghosts of all but the
    last entry via draw_fn(c, x, y, extra) inside saveLayerAlpha, newest ghost strongest."""
    ghosts = list(positions)[:-1]
    m = len(ghosts)
    for i, pos in enumerate(ghosts):
        gx, gy = pos[0], pos[1]
        extra = pos[2] if len(pos) > 2 else None
        a = int(_clamp(alpha0 * ((i + 1) / m) ** 1.3, 0, 255))
        if a <= 0:
            continue
        c.saveLayerAlpha(None, a)
        draw_fn(c, gx, gy, extra)
        c.restore()


# ------------------------------------------------------------------ 12. sparkles
def sparkles(c, x, y, t, t0, life=0.8, n=7, seed=2, radius=160):
    """White 4-point stars bursting outward from (x, y), twinkling and spinning, plus a pop ring."""
    dt = t - t0
    if life <= 0 or dt < 0 or dt > life:
        return
    r = _rng(seed)
    if dt < 0.16:
        kk = dt / 0.16
        c.drawCircle(x, y, radius * 0.15 + radius * 0.45 * _ease_out_cubic(kk), stroke(WHITE, 9 * (1 - kk) + 1, a=int(255 * (1 - kk))))
    for i in range(n):
        a = 2 * math.pi * (i + r.uniform(-0.35, 0.35)) / n
        li = life * r.uniform(0.6, 1.0)
        di = r.uniform(0, life - li)
        dist = radius * r.uniform(0.5, 1.05)
        rs = r.uniform(16, 32) * radius / 160
        spin0, spin = r.uniform(0, 45), r.uniform(-260, 260)
        ki = (dt - di) / li
        if ki < 0 or ki > 1:
            continue
        d = dist * _ease_out_cubic(ki)
        tw = 0.72 + 0.28 * math.sin(dt * 40 + i * 2.3)
        s = rs * math.sin(math.pi * ki) ** 0.6 * tw
        if s < 0.8:
            continue
        px, py = x + math.cos(a) * d, y + math.sin(a) * d
        c.save(); c.translate(px, py); c.rotate(spin0 + spin * dt)
        st = _star4(s)
        c.drawPath(st, fill(WHITE)); c.drawPath(st, stroke(INK, max(3.0, s * 0.18)))
        c.restore()
        # little companion dot
        c.drawCircle(px + math.cos(a + 1.3) * s * 0.9, py + math.sin(a + 1.3) * s * 0.9, max(1.5, s * 0.16), fill(WHITE))
