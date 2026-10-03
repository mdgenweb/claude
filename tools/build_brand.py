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
# "Schnittblatt", flach illustriert: ein Blatt aus zwei Kreisbögen mit Licht-
# und Schattenhälfte (die Grenze ist die Mittelrippe), drei gebogenen Adern auf
# der Schattenseite, eingerolltem Stiel und gerade geschnittener Spitze. Von der
# Schnittkante fällt ein Tautropfen mit Glanzpunkt – frisch geschnitten,
# gepflegt. Nur Grundformen, flache Farben, keine Verläufe.
# 64er-Raster, Blattachse 45° (Basis unten links, Spitze oben rechts).
LEAF_B, LEAF_T, LEAF_R, CUT = (15.0, 49.0), (57.0, 7.0), 34.0, 0.8
VEINS = (0.25, 0.41, 0.57)         # Ansatz der Adern auf der Achse
MOSS, GRASS = "#2F5A3C", "#4E7F45"
LEAF_GREEN, LEAF_LIGHT = "#8DB86A", "#A6CA86"
DEW, DEW_DARK = "#BFE0D4", "#CFEADF"   # Tautropfen auf hellem / dunklem Grund


def _f(v):
    return f"{v:.2f}".rstrip("0").rstrip(".")


def _pt(p):
    return f"{_f(p[0])} {_f(p[1])}"


def _unit(v):
    ln = math.hypot(*v)
    return v[0] / ln, v[1] / ln


def _center(b, t, r, side, n):
    half = math.dist(b, t) / 2
    d = math.sqrt(r * r - half * half)
    return ((b[0] + t[0]) / 2 - side * n[0] * d, (b[1] + t[1]) / 2 - side * n[1] * d)


def _hit(o, r, a, v, t1):
    fx, fy = a[0] - o[0], a[1] - o[1]
    qa, qb, qc = v[0] ** 2 + v[1] ** 2, 2 * (fx * v[0] + fy * v[1]), fx * fx + fy * fy - r * r
    w = math.sqrt(qb * qb - 4 * qa * qc)
    for t in ((-qb - w) / (2 * qa), (-qb + w) / (2 * qa)):
        if -1e-6 <= t <= t1 + 1e-6:
            return a[0] + t * v[0], a[1] + t * v[1]
    raise ValueError("kein Schnittpunkt")


def _sweep(o, p, q):
    return 1 if (p[0] - o[0]) * (q[1] - o[1]) - (p[1] - o[1]) * (q[0] - o[0]) > 0 else 0


def leaf_parts():
    b, t, r = LEAF_B, LEAF_T, LEAF_R
    u = _unit((t[0] - b[0], t[1] - b[1]))
    n = (-u[1], u[0])                                   # zur Schattenseite (unten rechts)
    ln = math.dist(b, t)
    at = lambda s, off=0.0: (b[0] + u[0] * s * ln + n[0] * off, b[1] + u[1] * s * ln + n[1] * off)
    ob, ok = _center(b, t, r, +1, n), _center(b, t, r, -1, n)
    c = at(CUT)
    cb, ck = _hit(ob, r, c, n, ln), _hit(ok, r, c, (-n[0], -n[1]), ln)
    body = (f"M{_pt(b)}A{_f(r)} {_f(r)} 0 0 {_sweep(ob, b, cb)} {_pt(cb)}L{_pt(ck)}"
            f"A{_f(r)} {_f(r)} 0 0 {_sweep(ok, ck, b)} {_pt(b)}Z")
    shade = f"M{_pt(b)}L{_pt(c)}L{_pt(cb)}A{_f(r)} {_f(r)} 0 0 {_sweep(ob, cb, b)} {_pt(b)}Z"
    veins = ""
    a = math.radians(34)
    for s0 in VEINS:
        p0 = at(s0, 1.6)
        dx, dy = u[0] * math.cos(a) + n[0] * math.sin(a), u[1] * math.cos(a) + n[1] * math.sin(a)
        p1 = (p0[0] + dx * 10.5, p0[1] + dy * 10.5)
        mid = ((p0[0] + p1[0]) / 2 + u[0] * 1.6, (p0[1] + p1[1]) / 2 + u[1] * 1.6)
        veins += f"M{_pt(p0)}Q{_pt(mid)} {_pt(p1)}"
    # Stiel: kurz in Achsrichtung, dann eingerollt (Kreisbogen r = 5,5, 100°)
    p0, p1 = at(0.05), (b[0] - u[0] * 3, b[1] - u[1] * 3)
    rs = 5.5
    d0 = (-u[0], -u[1])
    n0 = (-d0[1], d0[0])
    cs = (p1[0] + n0[0] * rs, p1[1] + n0[1] * rs)
    a0 = math.atan2(p1[1] - cs[1], p1[0] - cs[0]) + math.radians(100)
    p2 = (cs[0] + rs * math.cos(a0), cs[1] + rs * math.sin(a0))
    stem = f"M{_pt(p0)}L{_pt(p1)}A{_f(rs)} {_f(rs)} 0 0 1 {_pt(p2)}"
    # Tautropfen unter der Bauchecke der Schnittkante
    x, y, rr = cb[0] + 0.6, cb[1] + 9.6, 3.6
    top = (x, y - rr * 2.05)
    drop = (f"M{_pt(top)}C{_f(x + rr * .35)} {_f(y - rr * 1.25)} {_f(x + rr)} {_f(y - rr * .75)} {_f(x + rr)} {_f(y)}"
            f"A{_f(rr)} {_f(rr)} 0 0 1 {_f(x - rr)} {_f(y)}C{_f(x - rr)} {_f(y - rr * .75)} {_f(x - rr * .35)} "
            f"{_f(y - rr * 1.25)} {_pt(top)}Z")
    glint = (x + rr * .38, y - rr * .15, rr * .3)
    rib = f"M{_pt(at(0.04))}L{_pt(c)}"
    # Begrenzung (abgetastet): Blatt, Stiel (mit halber Strichbreite), Tropfen
    pts = [b, cb, ck]
    for o, p, q in ((ob, b, cb), (ok, ck, b)):
        a1, a2 = math.atan2(p[1] - o[1], p[0] - o[0]), math.atan2(q[1] - o[1], q[0] - o[0])
        da = (a2 - a1 + math.pi) % (2 * math.pi) - math.pi
        pts += [(o[0] + r * math.cos(a1 + da * k / 24), o[1] + r * math.sin(a1 + da * k / 24)) for k in range(25)]
    a1 = math.atan2(p1[1] - cs[1], p1[0] - cs[0])
    pts += [(cs[0] + (rs + 2.2) * math.cos(a1 + math.radians(100) * k / 12),
             cs[1] + (rs + 2.2) * math.sin(a1 + math.radians(100) * k / 12)) for k in range(13)]
    pts += [(x - rr, y), (x + rr, y), (x, y + rr), top]
    box = (min(q[0] for q in pts), min(q[1] for q in pts), max(q[0] for q in pts), max(q[1] for q in pts))
    return dict(body=body, shade=shade, veins=veins, stem=stem, drop=drop, glint=glint, rib=rib, box=box)


LEAF_SHAPE = leaf_parts()


def leaf_silhouette():
    """Einfarbige Silhouette (Blatt + Stiel als Fläche), mittig im 64er-Raster –
    für das Sprite #i-leaf (Trenner im Laufband, Ablauf), das per CSS-fill färbt."""
    b, t = LEAF_B, LEAF_T
    u = _unit((t[0] - b[0], t[1] - b[1]))
    ln = math.dist(b, t)
    p0 = (b[0] + u[0] * 0.05 * ln, b[1] + u[1] * 0.05 * ln)
    p1 = (b[0] - u[0] * 3, b[1] - u[1] * 3)
    rs, w = 5.5, 2.2
    n0 = (u[1], -u[0])                           # +90° zur Laufrichtung (−u)
    cs = (p1[0] + n0[0] * rs, p1[1] + n0[1] * rs)
    a0 = math.atan2(p1[1] - cs[1], p1[0] - cs[0])
    line = [(p0[0] + (p1[0] - p0[0]) * k / 4, p0[1] + (p1[1] - p0[1]) * k / 4) for k in range(5)]
    arc = [(cs[0] + rs * math.cos(a0 + math.radians(100) * k / 10), cs[1] + rs * math.sin(a0 + math.radians(100) * k / 10)) for k in range(1, 11)]
    cl = line + arc
    left, right = [], []
    for i, q in enumerate(cl):
        a, c = cl[max(i - 1, 0)], cl[min(i + 1, len(cl) - 1)]
        dx, dy = c[0] - a[0], c[1] - a[1]
        dl = math.hypot(dx, dy)
        nx, ny = -dy / dl, dx / dl
        left.append((q[0] + nx * w, q[1] + ny * w))
        right.append((q[0] - nx * w, q[1] - ny * w))
    stem = (f"M{_pt(left[0])}" + "".join(f"L{_pt(q)}" for q in left[1:])
            + f"A{_f(w)} {_f(w)} 0 0 0 {_pt(right[-1])}" + "".join(f"L{_pt(q)}" for q in right[-2::-1])
            + f"A{_f(w)} {_f(w)} 0 0 1 {_pt(left[0])}Z")
    bx0, by0, bx1, by1 = LEAF_SHAPE["box"]
    dx, dy = 32 - (bx0 + bx1) / 2, 32 - (by0 + by1) / 2
    shift = lambda d: re.sub(r"(-?\d+(?:\.\d+)?) (-?\d+(?:\.\d+)?)(?=[A-Za-z]|$)",
                             lambda m: f"{_f(float(m.group(1)) + dx)} {_f(float(m.group(2)) + dy)}", d)
    return shift(LEAF_SHAPE["body"]), shift(stem)


def leaf_svg(colors=None, mono=None, uid="b"):
    """Farbig: colors = (Licht, Schatten, Tropfen, Glanz). Einfarbig: mono = Farbe,
    Mittelrippe, Adern und Glanz werden per Maske ausgespart."""
    p = LEAF_SHAPE
    gx, gy, gr = p["glint"]
    if mono:
        mask = (f'<mask id="{uid}-m" maskUnits="userSpaceOnUse" x="-8" y="-8" width="80" height="80">'
                f'<rect x="-8" y="-8" width="80" height="80" fill="#fff"/>'
                f'<path d="{p["rib"]}" stroke="#000" stroke-width="1.6" stroke-linecap="round"/>'
                f'<path d="{p["veins"]}" fill="none" stroke="#000" stroke-width="2" stroke-linecap="round"/>'
                f'<circle cx="{_f(gx)}" cy="{_f(gy)}" r="{_f(gr)}" fill="#000"/></mask>')
        return (f"<defs>{mask}</defs><g mask=\"url(#{uid}-m)\">"
                f'<path d="{p["stem"]}" fill="none" stroke="{mono}" stroke-width="4.4" stroke-linecap="round"/>'
                f'<path fill="{mono}" d="{p["body"]}"/><path fill="{mono}" d="{p["drop"]}"/></g>')
    c_light, c_dark, c_drop, c_glint = colors
    return (f'<defs><clipPath id="{uid}-c"><path d="{p["shade"]}"/></clipPath></defs>'
            f'<path d="{p["stem"]}" fill="none" stroke="{c_dark}" stroke-width="4.4" stroke-linecap="round"/>'
            f'<path fill="{c_light}" d="{p["body"]}"/><path fill="{c_dark}" d="{p["shade"]}"/>'
            f'<path d="{p["veins"]}" clip-path="url(#{uid}-c)" fill="none" stroke="{c_light}" stroke-width="2.3" stroke-linecap="round"/>'
            f'<path fill="{c_drop}" d="{p["drop"]}"/><circle cx="{_f(gx)}" cy="{_f(gy)}" r="{_f(gr)}" fill="{c_glint}"/>')


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
    # Wortmarke: Bricolage Grotesque leicht schmal und kräftig – ruhiger Gegenpol
    # zum illustrierten Blatt, dieselbe Familie wie die Display-Schrift der Website
    name_d, name_b, name_w, cap = text_path(
        "bricolage-grotesque-wdth-latin.woff2", NAME, 100, -0.006, wght=740, wdth=82)
    desc_d, desc_b, desc_w, desc_cap = text_path(
        "instrument-sans-var-latin.woff2", DESCRIPTOR, 25, 0.24, wght=600)

    title = f"{NAME} Gartenservice"
    LIGHT = (LEAF_GREEN, MOSS, DEW, "#fff")          # auf hellem Grund
    DARK = (LEAF_LIGHT, GRASS, DEW_DARK, "#fff")     # auf dunklem Grund
    # Variante: (Blatt farbig | einfarbig, Name, Zusatz)
    variants = {
        "": (dict(colors=LIGHT), INK, GREEN),
        "-invers": (dict(colors=DARK), LINEN, LEAF),
        "-einfarbig": (dict(mono=GREEN), GREEN, GREEN),
        "-schwarz": (dict(mono="#000"), "#000", "#000"),
        "-weiss": (dict(mono="#fff"), "#fff", "#fff"),
    }
    bx0, by0, bx1, by1 = LEAF_SHAPE["box"]
    bw, bh = bx1 - bx0, by1 - by0

    # --- Primärlogo, horizontal (Blatt mittig zum Textblock)
    name_y = -name_b[1]
    desc_y = name_y + name_b[3] + 24 + desc_cap
    sym_h = desc_y * 1.12
    s = sym_h / bh
    sy = (desc_y - sym_h) / 2
    tx = bw * s + 26
    W = tx + max(name_w, desc_w) + 2
    H = sym_h + 2
    for suffix, (leaf, c_name, c_desc) in variants.items():
        body = (f'<g transform="translate(0 {fmt(-sy)})">'
                f'<g transform="translate({fmt(-bx0 * s)} {fmt(sy - by0 * s)}) scale({fmt(s)})">{leaf_svg(uid="bp", **leaf)}</g>'
                f'<path fill="{c_name}" transform="translate({fmt(tx)} {fmt(name_y)})" d="{name_d}"/>'
                f'<path fill="{c_desc}" transform="translate({fmt(tx + 2)} {fmt(desc_y)})" d="{desc_d}"/></g>')
        (OUT / f"logo-primaer{suffix}.svg").write_text(svg(W, H, body, title))

    # --- Kompakt (gestapelt)
    wmax = max(name_w, desc_w)
    s2 = 170 / bh
    W2 = max(wmax, bw * s2) + 8
    ny = 170 + 34 - name_b[1]
    dy = ny + name_b[3] + 22 + desc_cap
    for suffix, (leaf, c_name, c_desc) in variants.items():
        body = (f'<g transform="translate({fmt((W2 - bw * s2) / 2 - bx0 * s2)} {fmt(-by0 * s2)}) scale({fmt(s2)})">{leaf_svg(uid="bk", **leaf)}</g>'
                f'<path fill="{c_name}" transform="translate({fmt((W2 - name_w) / 2)} {fmt(ny)})" d="{name_d}"/>'
                f'<path fill="{c_desc}" transform="translate({fmt((W2 - desc_w) / 2)} {fmt(dy)})" d="{desc_d}"/>')
        (OUT / f"logo-kompakt{suffix}.svg").write_text(svg(W2, dy + 4, body, title))

    # --- Symbol (64er-Raster, mittig)
    cx, cy = (bx0 + bx1) / 2, (by0 + by1) / 2
    center = f'<g transform="translate({fmt(32 - cx)} {fmt(32 - cy)})">'
    for suffix, (leaf, _, _) in variants.items():
        (OUT / f"symbol{suffix}.svg").write_text(
            svg(64, 64, center + leaf_svg(uid="bs", **leaf) + "</g>", title).replace('width="64" height="64" ', "", 1))

    # --- Favicon & App-Icon: Blatt auf Waldgrün
    k = 52 / max(bw, bh)
    fav = (f'<rect width="64" height="64" rx="12" fill="{GREEN}"/>'
           f'<g transform="translate({fmt(32 - cx * k)} {fmt(32 - cy * k)}) scale({fmt(k)})">{leaf_svg(DARK, uid="bf")}</g>')
    (ROOT / "favicon.svg").write_text(svg(64, 64, fav, title).replace('width="64" height="64" ', "", 1))
    k = 300 / max(bw, bh)
    avatar = (f'<rect width="512" height="512" fill="{GREEN}"/>'
              f'<g transform="translate({fmt(256 - cx * k)} {fmt(256 - cy * k)}) scale({fmt(k)})">{leaf_svg(DARK, uid="ba")}</g>')
    (OUT / "social-avatar.svg").write_text(svg(512, 512, avatar, title))

    print("ok", OUT, f"Primärlogo {fmt(W)} × {fmt(H)}")
    body, stem = leaf_silhouette()
    print("Sprite #i-leaf:", body + stem)


if __name__ == "__main__":
    build()
