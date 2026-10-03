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
# "Schnittblatt": Linsenblatt aus zwei Viertelkreisen (r = 48 im 64er-Raster),
# Spitze rechtwinklig zur Blattachse gerade geschnitten (Formschnitt),
# Mittelrippe als sich verjüngende Aussparung.
R = 48.0
BASE = (8.0, 56.0)
AX = (1 / math.sqrt(2), -1 / math.sqrt(2))   # Blattachse (Basis -> Spitze)
NO = (1 / math.sqrt(2), 1 / math.sqrt(2))    # Normale
LEN = math.hypot(48, 48)


def _arc_hit(cx, cy, a0, a1, k):
    """Schnittpunkt Kreisbogen mit Gerade x - y = k (Bisektion)."""
    f = lambda a: (cx + R * math.cos(a)) - (cy + R * math.sin(a)) - k
    lo, hi = math.radians(a0), math.radians(a1)
    for _ in range(90):
        mid = (lo + hi) / 2
        if f(lo) * f(mid) <= 0:
            hi = mid
        else:
            lo = mid
    a = (lo + hi) / 2
    return cx + R * math.cos(a), cy + R * math.sin(a)


def symbol_path(trunc=0.82, rib=(0.15, 0.70, 1.45, 0.6)):
    c = trunc * LEN
    k = c * math.sqrt(2) - 48
    p1 = _arc_hit(56, 56, 180, 270, k)
    p2 = _arc_hit(8, 8, 0, 90, k)
    outer = (f"M8 56A48 48 0 0 1 {p1[0]:.3f} {p1[1]:.3f}"
             f"L{p2[0]:.3f} {p2[1]:.3f}A48 48 0 0 1 8 56Z")
    if rib is None:
        return outer
    s0, s1, w0, w1 = rib
    pb = (BASE[0] + AX[0] * s0 * LEN, BASE[1] + AX[1] * s0 * LEN)
    pe = (BASE[0] + AX[0] * s1 * LEN, BASE[1] + AX[1] * s1 * LEN)
    a = (pb[0] + NO[0] * w0, pb[1] + NO[1] * w0)
    b = (pe[0] + NO[0] * w1, pe[1] + NO[1] * w1)
    cc = (pe[0] - NO[0] * w1, pe[1] - NO[1] * w1)
    d = (pb[0] - NO[0] * w0, pb[1] - NO[1] * w0)
    inner = (f"M{a[0]:.3f} {a[1]:.3f}L{b[0]:.3f} {b[1]:.3f}"
             f"A{w1} {w1} 0 0 0 {cc[0]:.3f} {cc[1]:.3f}"
             f"L{d[0]:.3f} {d[1]:.3f}A{w0} {w0} 0 0 0 {a[0]:.3f} {a[1]:.3f}Z")
    return outer + inner


SYMBOL = symbol_path()
SYMBOL_BOLD = symbol_path(rib=(0.17, 0.66, 2.6, 1.3))  # für 16–32 px


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
    name_d, name_b, name_w, cap = text_path(
        "bricolage-grotesque-var-latin.woff2", NAME, 100, -0.022, wght=600, opsz=96)
    desc_d, desc_b, desc_w, desc_cap = text_path(
        "instrument-sans-var-latin.woff2", DESCRIPTOR, 25, 0.24, wght=600)

    title = f"{NAME} Gartenservice"
    variants = {
        "": (GREEN, INK, GREEN),
        "-invers": (LINEN, LINEN, LEAF),
        "-schwarz": ("#000", "#000", "#000"),
        "-weiss": ("#fff", "#fff", "#fff"),
    }

    # --- Primärlogo, horizontal
    sym_h = 118.0                       # Symbolhöhe im Lockup
    s = sym_h / 47.6                    # 64er-Raster → Lockup (Blatt ≈ 47,6 hoch)
    gap = 30.0
    name_y = -name_b[1]                 # Grundlinie, Oberkante bei 0
    desc_y = name_y + name_b[3] + 24 + desc_cap
    block_h = desc_y
    sym_x0 = -8 * s
    sym_y0 = -9.2 * s + (block_h - sym_h) / 2
    tx = sym_h + gap
    W = tx + max(name_w, desc_w) + 2
    H = max(sym_h, desc_y) + 2
    for suffix, (c_sym, c_name, c_desc) in variants.items():
        body = (f'<path fill="{c_sym}" fill-rule="evenodd" '
                f'transform="translate({fmt(sym_x0)} {fmt(sym_y0)}) scale({fmt(s)})" d="{SYMBOL}"/>'
                f'<path fill="{c_name}" transform="translate({fmt(tx)} {fmt(name_y)})" d="{name_d}"/>'
                f'<path fill="{c_desc}" transform="translate({fmt(tx + 2)} {fmt(desc_y)})" d="{desc_d}"/>')
        (OUT / f"logo-primaer{suffix}.svg").write_text(svg(W, H, body, title))

    # --- Kompakt (gestapelt)
    s2 = 150 / 47.6
    wmax = max(name_w, desc_w)
    W2 = wmax + 8
    sym_w = 47.4 * s2
    sx = (W2 - sym_w) / 2 - 8.1 * s2
    ny = 150 + 44 - name_b[1]
    dy = ny + name_b[3] + 22 + desc_cap
    for suffix, (c_sym, c_name, c_desc) in variants.items():
        body = (f'<path fill="{c_sym}" fill-rule="evenodd" '
                f'transform="translate({fmt(sx)} {fmt(-8.4 * s2)}) scale({fmt(s2)})" d="{SYMBOL}"/>'
                f'<path fill="{c_name}" transform="translate({fmt((W2 - name_w) / 2)} {fmt(ny)})" d="{name_d}"/>'
                f'<path fill="{c_desc}" transform="translate({fmt((W2 - desc_w) / 2)} {fmt(dy)})" d="{desc_d}"/>')
        (OUT / f"logo-kompakt{suffix}.svg").write_text(svg(W2, dy + 4, body, title))

    # --- Symbol
    for suffix, (c_sym, _, _) in variants.items():
        body = f'<path fill="{c_sym}" fill-rule="evenodd" d="{SYMBOL}"/>'
        (OUT / f"symbol{suffix}.svg").write_text(
            svg(64, 64, body, title).replace('width="64" height="64" ', "", 1))

    # --- Favicon & App-Icon (Symbol auf Waldgrün, kräftigere Rippe)
    fav = (f'<rect width="64" height="64" rx="12" fill="{GREEN}"/>'
           f'<path fill="{LINEN}" fill-rule="evenodd" transform="translate(5.5 5.5) scale(.83)" d="{SYMBOL_BOLD}"/>')
    (ROOT / "favicon.svg").write_text(svg(64, 64, fav, title).replace('width="64" height="64" ', "", 1))
    avatar = (f'<rect width="512" height="512" fill="{GREEN}"/>'
              f'<path fill="{LINEN}" fill-rule="evenodd" transform="translate(126 126) scale(4.06)" d="{SYMBOL}"/>')
    (OUT / "social-avatar.svg").write_text(svg(512, 512, avatar, title))

    print("ok", OUT)


if __name__ == "__main__":
    build()
