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
LEAF_GREEN = "#8DB86A"        # Passerebene auf hellem Grund
GRASS = "#4E7F45"             # Passerebene auf dunklem Grund

# ---------------------------------------------------------------- Symbol
# "Schnittblatt", gezeichnet: ein Blatt in einem Zug – geschwungener Stiel, der
# ohne Absatz in die Blattfläche übergeht, voller Rücken (oben links), flacherer
# Bauch (unten rechts). Die Mittelrippe ist ein leicht gebogener Schlitz, der
# spitz beginnt und sich zur Spitze hin öffnet; die Spitze selbst ist mit einer
# geraden Linie abgeschnitten (der Schnitt des Gärtners). Die Form ist bewusst
# von Hand gesetzt (Stützpunkte unten), nicht aus Kreisen konstruiert.
#
# Lokale Koordinaten: x entlang der Blattachse (0 = Blattgrund, 1 = gedachte
# Spitze), y quer dazu (+ = Bauchseite). Die Achse steht im Logo unter 45°.
CUT = 0.82                    # Schnitt bei 82 % der Achse
BEND = 0.05                   # Krümmung der Mittelrippe
SLIT = (0.11, 0.016)          # Rippe: Beginn auf der Achse, halbe Breite am Schnitt
BACK = [(0.03, -0.024), (0.075, -0.080), (0.155, -0.160), (0.27, -0.233), (0.40, -0.272),
        (0.52, -0.276), (0.63, -0.251), (0.73, -0.206), (CUT, -0.152)]
BELLY = [(CUT, 0.128), (0.72, 0.176), (0.60, 0.208), (0.47, 0.222), (0.34, 0.212),
         (0.22, 0.172), (0.12, 0.108), (0.05, 0.045)]
STEM = [(0.0, 0.004), (-0.06, 0.018), (-0.11, 0.040), (-0.15, 0.072)]
ECHO = (-1.4, -1.4)           # Passerversatz der hellen Druckebene (64er-Raster)


def _catmull(pts):
    """Punktfolge → kubische Bézier-Segmente (Catmull-Rom, offene Kette)."""
    a, b, y, z = pts[0], pts[1], pts[-2], pts[-1]
    ext = [(2 * a[0] - b[0], 2 * a[1] - b[1])] + list(pts) + [(2 * z[0] - y[0], 2 * z[1] - y[1])]
    segs = []
    for i in range(len(pts) - 1):
        p0, p1, p2, p3 = ext[i:i + 4]
        segs.append((p1, (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6),
                     (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6), p2))
    return segs


def _chains(slit=SLIT[1], stem_w=(0.042, 0.012)):
    spine = lambda x: -BEND * math.sin(math.pi * x)
    x0 = SLIT[0]
    half = lambda x: slit * max((x - x0) / (CUT - x0), 0) ** 0.75
    # Stielkanten: Mittellinie mit abnehmender Breite, Spitze leicht verlängert
    sp = [(0.05, spine(0.05))] + STEM
    back, belly = [], []
    for i, p in enumerate(sp):
        q, o = sp[min(i + 1, len(sp) - 1)], sp[max(i - 1, 0)]
        dx, dy = q[0] - o[0], q[1] - o[1]
        ln = math.hypot(dx, dy)
        nx, ny = dy / ln, -dx / ln
        if ny < 0:
            nx, ny = -nx, -ny
        w = (stem_w[0] + (stem_w[1] - stem_w[0]) * (i / (len(sp) - 1)) ** 1.2) / 2
        back.append((p[0] - nx * w, p[1] - ny * w))
        belly.append((p[0] + nx * w, p[1] + ny * w))
    (ex, ey), (px, py) = sp[-1], sp[-2]
    ln = math.hypot(ex - px, ey - py)
    tip = (ex + (ex - px) / ln * stem_w[1] * 0.9, ey + (ey - py) / ln * stem_w[1] * 0.9)
    xs = [CUT - (CUT - x0) * k / 12 for k in range(13)]
    return [
        [tip] + back[1:][::-1] + BACK,                          # Stiel → Rücken → Schnitt
        [(x, spine(x) - half(x)) for x in xs],                  # Rippe, Rückenseite abwärts
        [(x, spine(x) + half(x)) for x in xs[::-1]],            # Rippe, Bauchseite aufwärts
        BELLY + belly[1:] + [tip],                              # Bauch → Stiel → Spitze
    ]


def _bezier_points(segs, n=12):
    out = []
    for p0, c1, c2, p1 in segs:
        for j in range(n + 1):
            t = j / n
            mt = 1 - t
            out.append((mt ** 3 * p0[0] + 3 * mt * mt * t * c1[0] + 3 * mt * t * t * c2[0] + t ** 3 * p1[0],
                        mt ** 3 * p0[1] + 3 * mt * mt * t * c1[1] + 3 * mt * t * t * c2[1] + t ** 3 * p1[1]))
    return out


def symbol_path(slit=SLIT[1], stem_w=(0.042, 0.012), size=64.0, margin=6.0):
    """Blatt als ein geschlossener Pfad, eingepasst in size × size (Rand margin)."""
    r = 1 / math.sqrt(2)
    world = lambda p: ((p[0] + p[1]) * r, (p[1] - p[0]) * r)     # Achse 45° nach oben rechts
    chains = [[world(p) for p in ch] for ch in _chains(slit, stem_w)]
    segs = [_catmull(ch) for ch in chains]
    pts = [q for sg in segs for q in _bezier_points(sg)]
    x0, y0 = min(q[0] for q in pts), min(q[1] for q in pts)
    x1, y1 = max(q[0] for q in pts), max(q[1] for q in pts)
    k = (size - 2 * margin) / max(x1 - x0, y1 - y0)
    ox, oy = size / 2 - (x0 + x1) / 2 * k, size / 2 - (y0 + y1) / 2 * k
    pt = lambda q: f"{fmt(q[0] * k + ox)} {fmt(q[1] * k + oy)}"
    d = ""
    for i, sg in enumerate(segs):
        d += ("M" if i == 0 else "L") + pt(sg[0][0])
        d += "".join(f"C{pt(c1)} {pt(c2)} {pt(p1)}" for _, c1, c2, p1 in sg)
    return d + "Z"


def symbol_bounds(d):
    """Bounding-Box eines Symbolpfads aus M/L/C-Befehlen (Kurven abgetastet)."""
    toks = re.findall(r"[MLCZ]|-?\d+(?:\.\d+)?", d)
    pts, i, cur, cmd = [], 0, (0.0, 0.0), None
    while i < len(toks):
        if toks[i] in "MLCZ":
            cmd = toks[i]
            i += 1
            continue
        if cmd in "ML":
            cur = (float(toks[i]), float(toks[i + 1]))
            pts.append(cur)
            i += 2
        elif cmd == "C":
            v = [float(t) for t in toks[i:i + 6]]
            seg = (cur, (v[0], v[1]), (v[2], v[3]), (v[4], v[5]))
            pts += _bezier_points([seg])
            cur = (v[4], v[5])
            i += 6
    xs, ys = [q[0] for q in pts], [q[1] for q in pts]
    return min(xs), min(ys), max(xs), max(ys)


def symbol_layers(c_leaf, c_echo=None, transform=""):
    """Blatt, optional mit heller, versetzter Druckebene darunter (Passerversatz)."""
    t = f' transform="{transform}"' if transform else ""
    out = f"<g{t}>"
    if c_echo:
        out += f'<path fill="{c_echo}" transform="translate({fmt(ECHO[0])} {fmt(ECHO[1])})" d="{SYMBOL}"/>'
    return out + f'<path fill="{c_leaf}" d="{SYMBOL}"/></g>'


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


SYMBOL = symbol_path()
SYMBOL_BOLD = symbol_path(slit=0.028, stem_w=(0.062, 0.022))  # Favicon, 16–32 px


def svg(w, h, body, title):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {fmt(w)} {fmt(h)}" '
            f'width="{fmt(w)}" height="{fmt(h)}" role="img" aria-label="{title}">'
            f"<title>{title}</title>{body}</svg>\n")


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    # Wortmarke: Bricolage Grotesque leicht schmal und kräftig – ruhiger Gegenpol
    # zum gezeichneten Blatt, dieselbe Familie wie die Display-Schrift der Website
    name_d, name_b, name_w, cap = text_path(
        "bricolage-grotesque-wdth-latin.woff2", NAME, 100, -0.006, wght=740, wdth=82)
    desc_d, desc_b, desc_w, desc_cap = text_path(
        "instrument-sans-var-latin.woff2", DESCRIPTOR, 25, 0.24, wght=600)

    title = f"{NAME} Gartenservice"
    # Variante: (Blatt, Passerebene oder None, Name, Zusatz)
    variants = {
        "": (GREEN, LEAF_GREEN, INK, GREEN),
        "-invers": (LINEN, GRASS, LINEN, LEAF),
        "-einfarbig": (GREEN, None, GREEN, GREEN),
        "-schwarz": ("#000", None, "#000", "#000"),
        "-weiss": ("#fff", None, "#fff", "#fff"),
    }
    bx0, by0, bx1, by1 = symbol_bounds(SYMBOL)
    bx0, by0 = bx0 + min(ECHO[0], 0), by0 + min(ECHO[1], 0)   # Platz für die Passerebene
    bw, bh = bx1 - bx0, by1 - by0

    # --- Primärlogo, horizontal
    name_y = -name_b[1]                 # Grundlinie, Oberkante bei 0
    desc_y = name_y + name_b[3] + 24 + desc_cap
    block_h = desc_y
    sym_h = 150.0                       # Symbolhöhe im Lockup (Stielende bis Blattrücken)
    s = sym_h / bh
    sym_y0 = (block_h - sym_h) / 2
    tx = bw * s + 16
    top = min(0.0, sym_y0)
    W = tx + max(name_w, desc_w) + 2
    H = max(sym_y0 + sym_h, block_h) - top + 2
    for suffix, (c_leaf, c_echo, c_name, c_desc) in variants.items():
        body = (f'<g transform="translate(0 {fmt(-top)})">'
                + symbol_layers(c_leaf, c_echo, f"translate({fmt(-bx0 * s)} {fmt(sym_y0 - by0 * s)}) scale({fmt(s)})")
                + f'<path fill="{c_name}" transform="translate({fmt(tx)} {fmt(name_y)})" d="{name_d}"/>'
                f'<path fill="{c_desc}" transform="translate({fmt(tx + 2)} {fmt(desc_y)})" d="{desc_d}"/></g>')
        (OUT / f"logo-primaer{suffix}.svg").write_text(svg(W, H, body, title))

    # --- Kompakt (gestapelt)
    s2 = 170 / bh
    wmax = max(name_w, desc_w)
    W2 = max(wmax, bw * s2) + 8
    sx = (W2 - bw * s2) / 2 - bx0 * s2
    ny = 170 + 36 - name_b[1]
    dy = ny + name_b[3] + 22 + desc_cap
    for suffix, (c_leaf, c_echo, c_name, c_desc) in variants.items():
        body = (symbol_layers(c_leaf, c_echo, f"translate({fmt(sx)} {fmt(-by0 * s2)}) scale({fmt(s2)})")
                + f'<path fill="{c_name}" transform="translate({fmt((W2 - name_w) / 2)} {fmt(ny)})" d="{name_d}"/>'
                f'<path fill="{c_desc}" transform="translate({fmt((W2 - desc_w) / 2)} {fmt(dy)})" d="{desc_d}"/>')
        (OUT / f"logo-kompakt{suffix}.svg").write_text(svg(W2, dy + 4, body, title))

    # --- Symbol (64er-Raster)
    for suffix, (c_leaf, c_echo, _, _) in variants.items():
        (OUT / f"symbol{suffix}.svg").write_text(
            svg(64, 64, symbol_layers(c_leaf, c_echo), title).replace('width="64" height="64" ', "", 1))

    # --- Favicon & App-Icon: Blatt auf Waldgrün, breitere Rippe, kräftigerer Stiel
    fav = (f'<rect width="64" height="64" rx="12" fill="{GREEN}"/>'
           f'<path fill="{LINEN}" transform="translate(5 5) scale(.84)" d="{SYMBOL_BOLD}"/>')
    (ROOT / "favicon.svg").write_text(svg(64, 64, fav, title).replace('width="64" height="64" ', "", 1))
    avatar = (f'<rect width="512" height="512" fill="{GREEN}"/>'
              + symbol_layers(LINEN, LEAF_GREEN, "translate(106 106) scale(4.69)"))
    (OUT / "social-avatar.svg").write_text(svg(512, 512, avatar, title))

    print("ok", OUT, f"Primärlogo {fmt(W)} × {fmt(H)}")
    print("Blatt (Sprite #i-leaf):", SYMBOL)


if __name__ == "__main__":
    build()
