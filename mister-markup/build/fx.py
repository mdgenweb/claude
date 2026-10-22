"""Deterministic (stateless) effects: particles, impacts, speed lines, shakes. Everything is a pure function of time."""
import math
import numpy as np, skia
import art
from art import W, H, INK, WHITE, MONEY, MONEY_D, G3, G4, G5, G6, fill, stroke


def _rng(seed):
    return np.random.default_rng(seed)


def money_burst(c, x, y, t, t0, n=16, seed=1, speed=900, life=1.6, scale=0.7, grav=1600):
    dt = t - t0
    if dt < 0 or dt > life:
        return
    r = _rng(seed)
    for i in range(n):
        a = r.uniform(-math.pi * 0.95, -math.pi * 0.05)
        v = r.uniform(0.45, 1.0) * speed
        px = x + math.cos(a) * v * dt
        py = y + math.sin(a) * v * dt + 0.5 * grav * dt * dt
        spin = r.uniform(-720, 720) * dt + r.uniform(0, 360)
        art.draw_bill(c, px, py, scale * r.uniform(0.7, 1.1), ang=spin)


def kernels(c, x, y, t, t_start, t_end, every=0.18, seed=7, spread=1.0):
    """Popcorn kernels popping out of a bucket rim at (x, y)."""
    if t < t_start:
        return
    k_max = int((min(t, t_end) - t_start) / every)
    for k in range(max(0, k_max - 8), k_max + 1):
        t0 = t_start + k * every
        dt = t - t0
        if dt < 0 or dt > 1.0:
            continue
        r = _rng(seed * 1000 + k)
        vx = r.uniform(-260, 260) * spread
        vy = -r.uniform(700, 1050)
        px = x + r.uniform(-80, 80) + vx * dt
        py = y + vy * dt + 0.5 * 2200 * dt * dt
        rad = r.uniform(14, 20)
        pf = skia.Path()
        for q in range(4):
            a = q * math.pi / 2 + dt * 6
            pf.addCircle(px + math.cos(a) * rad * 0.45, py + math.sin(a) * rad * 0.45, rad * 0.6)
        c.drawPath(pf, fill(WHITE)); c.drawPath(pf, stroke(INK, 3))


def shockwave(c, x, y, t, t0, life=0.45, r0=40, r1=520, w=14):
    dt = t - t0
    if dt < 0 or dt > life:
        return
    k = dt / life
    r = r0 + (r1 - r0) * (1 - (1 - k) ** 2)
    c.drawCircle(x, y, r, stroke(WHITE, w * (1 - k) + 1, a=int(230 * (1 - k))))


def impact(c, x, y, t, t0, life=0.35, size=260, seed=3):
    dt = t - t0
    if dt < 0 or dt > life:
        return
    k = dt / life
    r = _rng(seed)
    n = 14
    pts = []
    for i in range(n * 2):
        a = i * math.pi / n
        rr = size * (0.55 + 0.45 * (i % 2 == 0)) * (0.6 + 0.6 * k) * r.uniform(0.85, 1.15)
        pts.append((x + math.cos(a) * rr, y + math.sin(a) * rr))
    p = art.path_poly(pts)
    c.drawPath(p, stroke(WHITE, 10 * (1 - k) + 2, a=int(255 * (1 - k))))
    for i in range(10):
        a = r.uniform(0, 2 * math.pi)
        r0, r1 = size * (0.7 + k), size * (1.1 + 1.2 * k)
        c.drawLine(x + math.cos(a) * r0, y + math.sin(a) * r0, x + math.cos(a) * r1, y + math.sin(a) * r1,
                   stroke(WHITE, 6 * (1 - k) + 1, a=int(255 * (1 - k))))


def dust_puff(c, x, y, t, t0, life=0.6, n=9, seed=5, spread=260):
    dt = t - t0
    if dt < 0 or dt > life:
        return
    k = dt / life
    r = _rng(seed)
    for i in range(n):
        a = r.uniform(math.pi, 2 * math.pi) if i % 2 else r.uniform(-0.3, math.pi + 0.3)
        d = spread * r.uniform(0.4, 1.0) * (1 - (1 - k) ** 3)
        rad = r.uniform(26, 50) * (0.6 + k)
        c.drawCircle(x + math.cos(a) * d, y + math.sin(a) * d * 0.4, rad, fill(G5, int(200 * (1 - k))))


def speed_lines(c, t, cx=W / 2, cy=H / 2, n=40, strength=1.0, seed=0, radial=True, direction=0.0):
    r = _rng(int(t * 24) + seed)
    for i in range(int(n * strength)):
        if radial:
            a = r.uniform(0, 2 * math.pi)
            r0 = r.uniform(520, 760); r1 = r0 + r.uniform(300, 900)
            c.drawLine(cx + math.cos(a) * r0, cy + math.sin(a) * r0, cx + math.cos(a) * r1, cy + math.sin(a) * r1,
                       stroke(WHITE, r.uniform(2, 7), a=int(180 * strength)))
        else:
            y = r.uniform(0, H); x = r.uniform(-200, W)
            L = r.uniform(250, 900)
            dx, dy = math.cos(direction) * L, math.sin(direction) * L
            c.drawLine(x, y, x + dx, y + dy, stroke(WHITE, r.uniform(2, 9), a=int(200 * strength)))


def bubbles(c, x0, x1, ytop, ybot, t, n=14, seed=9):
    r = _rng(seed)
    for i in range(n):
        x = r.uniform(x0, x1)
        sp = r.uniform(120, 260)
        ph = r.uniform(0, 1)
        y = ybot - ((t * sp / (ybot - ytop) + ph) % 1.0) * (ybot - ytop)
        rad = r.uniform(5, 11)
        c.drawCircle(x + math.sin(t * 4 + i) * 5, y, rad, stroke(WHITE, 3, a=210))


def confetti_bills(c, t, t0, n=22, seed=11, life=3.0):
    dt = t - t0
    if dt < 0 or dt > life:
        return
    r = _rng(seed)
    for i in range(n):
        st = r.uniform(0, 0.8)
        k = dt - st
        if k < 0:
            continue
        x = r.uniform(40, W - 40) + math.sin(k * 3 + i) * 50
        y = -100 + k * r.uniform(450, 700)
        art.draw_bill(c, x, y, r.uniform(0.6, 0.95), ang=math.sin(k * 4 + i) * 50 + i * 30)


def sweat(c, x, y, t, s=1.0):
    k = (t * 1.6) % 1.0
    d = skia.Path()
    yy = y + k * 60 * s
    d.moveTo(x, yy - 22 * s); d.quadTo(x + 14 * s, yy, x, yy + 8 * s); d.quadTo(x - 14 * s, yy, x, yy - 22 * s)
    c.drawPath(d, fill(WHITE, int(255 * (1 - k)))); c.drawPath(d, stroke(INK, 3, a=int(255 * (1 - k))))


def light_leak(c, t, t0, life=0.5, x0=-300, x1=W + 300):
    dt = t - t0
    if dt < 0 or dt > life:
        return
    k = dt / life
    x = x0 + (x1 - x0) * k
    g = skia.GradientShader.MakeRadial(skia.Point(x, H * 0.4), 900, [art.hexc("#ffffff", int(170 * math.sin(k * math.pi))), art.hexc("#ffffff", 0)])
    c.drawRect(skia.Rect.MakeWH(W, H), skia.Paint(AntiAlias=True, Shader=g))


def star(c, x, y, r, a=255):
    p = art.path_poly([(x, y - r), (x + r * 0.27, y - r * 0.27), (x + r, y), (x + r * 0.27, y + r * 0.27), (x, y + r),
                       (x - r * 0.27, y + r * 0.27), (x - r, y), (x - r * 0.27, y - r * 0.27)])
    c.drawPath(p, fill(WHITE, a)); c.drawPath(p, stroke(INK, 3, a=a))
