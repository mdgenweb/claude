#!/usr/bin/env python3
"""
Erzeugt das Logo-System als reine Vektor-SVGs (Schrift in Pfade umgewandelt).

    pip install fonttools brotli uharfbuzz
    python3 tools/build_brand.py "Firmenname"

Der Firmenname ist Platzhalter. Mit echtem Namen erneut ausführen –
alle Lockups werden neu gesetzt. Symbol-Geometrie: siehe docs/MARKENKONZEPT.md.
"""
import math
import re
import sys
from io import BytesIO
from pathlib import Path

import uharfbuzz as hb
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = Path(__file__).resolve().parent.parent
FONTS = ROOT / "assets" / "fonts"
OUT = ROOT / "assets" / "brand"

NAME = sys.argv[1] if len(sys.argv) > 1 else "Firmenname"
DESCRIPTOR = "GARTENSERVICE"

GREEN = "#1E3A2B"
LINEN = "#F6F2EA"
LEAF = "#B9CF9F"
INK = "#1B201D"

# ---------------------------------------------------------------- Symbol
# "Schnittblatt": Linsenblatt aus zwei Kreisbögen im 64er-Raster, Blattachse 45°
# (Basis unten links, Spitze oben rechts). Rücken (oben links, r = 44) etwas
# voller als der Bauch (unten rechts, r = 50), die Spitze rechtwinklig zur Achse
# gerade geschnitten (Formschnitt), kurzer Stiel, Mittelrippe als sich
# verjüngende Aussparung: Der Stiel läuft als Fläche ins Blatt und setzt sich
# dort als Aussparung fort.
LEAF_GEO = dict(base=(12.0, 53.0), tip=(60.0, 5.0), r_back=44.0, r_belly=50.0, trunc=0.82)


def _unit(v):
    l = math.hypot(*v)
    return v[0] / l, v[1] / l


def _center(b, t, r, side, n):
    """Mittelpunkt des Kreises durch b und t, der zur Seite side (±n) gewölbt ist."""
    half = math.dist(b, t) / 2
    d = math.sqrt(r * r - half * half)
    return ((b[0] + t[0]) / 2 - side * n[0] * d, (b[1] + t[1]) / 2 - side * n[1] * d)


def _hit(o, r, a, v, t1):
    """Schnittpunkt der Geraden a + t·v (0 ≤ t ≤ t1) mit dem Kreis (o, r)."""
    fx, fy = a[0] - o[0], a[1] - o[1]
    qa = v[0] ** 2 + v[1] ** 2
    qb = 2 * (fx * v[0] + fy * v[1])
    qc = fx * fx + fy * fy - r * r
    w = math.sqrt(qb * qb - 4 * qa * qc)
    for t in ((-qb - w) / (2 * qa), (-qb + w) / (2 * qa)):
        if -1e-6 <= t <= t1 + 1e-6:
            return a[0] + t * v[0], a[1] + t * v[1]
    raise ValueError("Blattkontur und Gerade schneiden sich nicht")


def _sweep(o, p, q):
    return 1 if (p[0] - o[0]) * (q[1] - o[1]) - (p[1] - o[1]) * (q[0] - o[0]) > 0 else 0


def symbol_path(rib=(0.17, 0.66, 1.5, 0.5), stem=(5.5, 3.2, 2.4), outline_only=False):
    """rib = (Beginn, Ende als Anteil der Achse, halbe Breite unten, oben);
    stem = (Länge, Breite am Blatt, Breite am Ende)."""
    b, t = LEAF_GEO["base"], LEAF_GEO["tip"]
    rk, rb = LEAF_GEO["r_back"], LEAF_GEO["r_belly"]
    u = _unit((t[0] - b[0], t[1] - b[1]))
    n = (-u[1], u[0])                                   # zeigt zum Bauch
    length = math.dist(b, t)
    ob, ok = _center(b, t, rb, +1, n), _center(b, t, rk, -1, n)
    c = (b[0] + u[0] * LEAF_GEO["trunc"] * length, b[1] + u[1] * LEAF_GEO["trunc"] * length)
    cut_b = _hit(ob, rb, c, n, length)
    cut_k = _hit(ok, rk, c, (-n[0], -n[1]), length)
    pt = lambda q: f"{q[0]:.3f} {q[1]:.3f}"
    sl, ws, we = stem
    # Stielkanten (parallel zur Achse) bis zur Blattkontur
    eb = _hit(ob, rb, (b[0] + n[0] * ws / 2, b[1] + n[1] * ws / 2), u, length / 2)
    ek = _hit(ok, rk, (b[0] - n[0] * ws / 2, b[1] - n[1] * ws / 2), u, length / 2)
    e = (b[0] - u[0] * sl, b[1] - u[1] * sl)
    sb = (e[0] + n[0] * we / 2, e[1] + n[1] * we / 2)
    sk = (e[0] - n[0] * we / 2, e[1] - n[1] * we / 2)
    outer = (f"M{pt(sb)}L{pt(eb)}A{rb:g} {rb:g} 0 0 {_sweep(ob, eb, cut_b)} {pt(cut_b)}"
             f"L{pt(cut_k)}A{rk:g} {rk:g} 0 0 {_sweep(ok, cut_k, ek)} {pt(ek)}"
             f"L{pt(sk)}A{we / 2:g} {we / 2:g} 0 0 0 {pt(sb)}Z")
    if outline_only or rib is None:
        return outer
    s0, s1, w0, w1 = rib
    pb = (b[0] + u[0] * s0 * length, b[1] + u[1] * s0 * length)
    pe = (b[0] + u[0] * s1 * length, b[1] + u[1] * s1 * length)
    q1 = (pb[0] + n[0] * w0, pb[1] + n[1] * w0)
    q2 = (pe[0] + n[0] * w1, pe[1] + n[1] * w1)
    q3 = (pe[0] - n[0] * w1, pe[1] - n[1] * w1)
    q4 = (pb[0] - n[0] * w0, pb[1] - n[1] * w0)
    inner = (f"M{pt(q1)}L{pt(q2)}A{w1:g} {w1:g} 0 0 0 {pt(q3)}"
             f"L{pt(q4)}A{w0:g} {w0:g} 0 0 0 {pt(q1)}Z")
    return outer + inner


def symbol_bounds(d):
    """Bounding-Box eines Symbolpfads (Bögen abgetastet)."""
    toks = re.findall(r"[MLAZ]|-?\d+(?:\.\d+)?", d)
    pts, i, cur, cmd = [], 0, (0.0, 0.0), None
    while i < len(toks):
        if toks[i] in "MLAZ":
            cmd = toks[i]
            i += 1
            if cmd == "Z":
                continue
        if cmd in "ML":
            cur = (float(toks[i]), float(toks[i + 1]))
            pts.append(cur)
            i += 2
        elif cmd == "A":
            r, sw = float(toks[i]), int(toks[i + 4])
            end = (float(toks[i + 5]), float(toks[i + 6]))
            h = math.dist(cur, end) / 2
            k = math.sqrt(max(0.0, r * r - h * h))
            nx, ny = -(end[1] - cur[1]) / (2 * h), (end[0] - cur[0]) / (2 * h)
            sg = 1 if sw == 0 else -1
            o = ((cur[0] + end[0]) / 2 + sg * nx * k, (cur[1] + end[1]) / 2 + sg * ny * k)
            a0 = math.atan2(cur[1] - o[1], cur[0] - o[0])
            da = (math.atan2(end[1] - o[1], end[0] - o[0]) - a0 + math.pi) % (2 * math.pi) - math.pi
            pts += [(o[0] + r * math.cos(a0 + da * j / 32), o[1] + r * math.sin(a0 + da * j / 32)) for j in range(33)]
            cur = end
            i += 7
    xs, ys = [q[0] for q in pts], [q[1] for q in pts]
    return min(xs), min(ys), max(xs), max(ys)


SYMBOL = symbol_path()
SYMBOL_BOLD = symbol_path(rib=(0.25, 0.62, 2.1, 1.1), stem=(5, 4.4, 3.8))  # für 16–32 px
SYMBOL_OUTLINE = symbol_path(outline_only=True)  # ohne Rippe: Trenner, Aufzählungen


# ---------------------------------------------------------------- Text → Pfade
def load_instance(file, **axes):
    font = TTFont(FONTS / file)
    inst = instancer.instantiateVariableFont(font, axes)
    buf = BytesIO()
    inst.flavor = None
    inst.save(buf)
    data = buf.getvalue()
    return TTFont(BytesIO(data)), data


def text_path(file, text, size, tracking_em=0.0, **axes):
    font, data = load_instance(file, **axes)
    upem = font["head"].unitsPerEm
    face = hb.Face(data)
    hbfont = hb.Font(face)
    buf = hb.Buffer()
    buf.add_str(text)
    buf.guess_segment_properties()
    hb.shape(hbfont, buf, {"kern": True, "liga": True})
    gs = font.getGlyphSet()
    order = font.getGlyphOrder()
    scale = size / upem
    pen = SVGPathPen(gs)
    bpen = BoundsPen(gs)
    x = 0.0
    for info, pos in zip(buf.glyph_infos, buf.glyph_positions):
        name = order[info.codepoint]
        t = (scale, 0, 0, -scale, x + pos.x_offset * scale, -pos.y_offset * scale)
        gs[name].draw(TransformPen(pen, t))
        gs[name].draw(TransformPen(bpen, t))
        x += pos.x_advance * scale + tracking_em * size
    x -= tracking_em * size
    cap = font["OS/2"].sCapHeight * scale
    d = re.sub(r"-?\d+\.\d+", lambda m: fmt(float(m.group(0))), pen.getCommands())
    return d, bpen.bounds, x, cap


def fmt(v):
    return f"{v:.2f}".rstrip("0").rstrip(".")


def svg(w, h, body, title):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {fmt(w)} {fmt(h)}" '
            f'width="{fmt(w)}" height="{fmt(h)}" role="img" aria-label="{title}">'
            f"<title>{title}</title>{body}</svg>\n")


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    # Wortmarke: Bricolage Grotesque leicht schmal und kräftig – dieselbe Familie
    # wie die Display-Schrift der Website, aber in normaler Schreibweise
    name_d, name_b, name_w, cap = text_path(
        "bricolage-grotesque-wdth-latin.woff2", NAME, 100, -0.006, wght=740, wdth=82)
    desc_d, desc_b, desc_w, desc_cap = text_path(
        "instrument-sans-var-latin.woff2", DESCRIPTOR, 25, 0.24, wght=600)

    title = f"{NAME} Gartenservice"
    variants = {
        "": (GREEN, INK, GREEN),
        "-invers": (LINEN, LINEN, LEAF),
        "-schwarz": ("#000", "#000", "#000"),
        "-weiss": ("#fff", "#fff", "#fff"),
    }
    bx0, by0, bx1, by1 = symbol_bounds(SYMBOL)
    bw, bh = bx1 - bx0, by1 - by0

    # --- Primärlogo, horizontal
    name_y = -name_b[1]                 # Grundlinie, Oberkante bei 0
    desc_y = name_y + name_b[3] + 24 + desc_cap
    block_h = desc_y
    sym_h = 124.0                       # Symbolhöhe im Lockup (Stiel bis Spitze)
    s = sym_h / bh
    sym_x0 = -bx0 * s
    sym_y0 = -by0 * s + (block_h - sym_h) / 2
    tx = bw * s + 26
    top = min(0.0, (block_h - sym_h) / 2)
    W = tx + max(name_w, desc_w) + 2
    H = max(sym_h, block_h) + 2
    for suffix, (c_sym, c_name, c_desc) in variants.items():
        body = (f'<g transform="translate(0 {fmt(-top)})">'
                f'<path fill="{c_sym}" fill-rule="evenodd" '
                f'transform="translate({fmt(sym_x0)} {fmt(sym_y0)}) scale({fmt(s)})" d="{SYMBOL}"/>'
                f'<path fill="{c_name}" transform="translate({fmt(tx)} {fmt(name_y)})" d="{name_d}"/>'
                f'<path fill="{c_desc}" transform="translate({fmt(tx + 2)} {fmt(desc_y)})" d="{desc_d}"/></g>')
        (OUT / f"logo-primaer{suffix}.svg").write_text(svg(W, H, body, title))

    # --- Kompakt (gestapelt)
    s2 = 150 / bh
    wmax = max(name_w, desc_w)
    W2 = wmax + 8
    sx = (W2 - bw * s2) / 2 - bx0 * s2
    ny = 150 + 40 - name_b[1]
    dy = ny + name_b[3] + 22 + desc_cap
    for suffix, (c_sym, c_name, c_desc) in variants.items():
        body = (f'<path fill="{c_sym}" fill-rule="evenodd" '
                f'transform="translate({fmt(sx)} {fmt(-by0 * s2)}) scale({fmt(s2)})" d="{SYMBOL}"/>'
                f'<path fill="{c_name}" transform="translate({fmt((W2 - name_w) / 2)} {fmt(ny)})" d="{name_d}"/>'
                f'<path fill="{c_desc}" transform="translate({fmt((W2 - desc_w) / 2)} {fmt(dy)})" d="{desc_d}"/>')
        (OUT / f"logo-kompakt{suffix}.svg").write_text(svg(W2, dy + 4, body, title))

    # --- Symbol
    for suffix, (c_sym, _, _) in variants.items():
        body = f'<path fill="{c_sym}" fill-rule="evenodd" d="{SYMBOL}"/>'
        (OUT / f"symbol{suffix}.svg").write_text(
            svg(64, 64, body, title).replace('width="64" height="64" ', "", 1))

    # --- Favicon & App-Icon (Symbol auf Waldgrün, kräftigere Rippe und Stiel)
    fx0, fy0, fx1, fy1 = symbol_bounds(SYMBOL_BOLD)
    fs = 46 / max(fx1 - fx0, fy1 - fy0)
    ftx, fty = 32 - (fx0 + fx1) / 2 * fs, 32 - (fy0 + fy1) / 2 * fs
    fav = (f'<rect width="64" height="64" rx="12" fill="{GREEN}"/>'
           f'<path fill="{LINEN}" fill-rule="evenodd" transform="translate({fmt(ftx)} {fmt(fty)}) scale({fmt(fs)})" d="{SYMBOL_BOLD}"/>')
    (ROOT / "favicon.svg").write_text(svg(64, 64, fav, title).replace('width="64" height="64" ', "", 1))
    a_s = 270 / max(bw, bh)
    avatar = (f'<rect width="512" height="512" fill="{GREEN}"/>'
              f'<path fill="{LINEN}" fill-rule="evenodd" transform="translate({fmt(256 - (bx0 + bx1) / 2 * a_s)} '
              f'{fmt(256 - (by0 + by1) / 2 * a_s)}) scale({fmt(a_s)})" d="{SYMBOL}"/>')
    (OUT / "social-avatar.svg").write_text(svg(512, 512, avatar, title))

    print("ok", OUT, f"Primärlogo {fmt(W)} × {fmt(H)}")
    print("Blatt ohne Rippe (Sprite #i-leaf):", SYMBOL_OUTLINE)


if __name__ == "__main__":
    build()
