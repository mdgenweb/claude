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
# "Heckenigel": flaches, geometrisches Zeichen. Der Rücken ist eine frisch
# geschnittene Hecke – oben gerade (Formschnitt), hinten rund, mit Schuppen-
# reihen wie die Hecke im Hero der Website. Davor ein helles Gesicht mit
# Spitznase, Auge mit Glanzpunkt, zwei kurze Füße. Nur wenige Grundformen
# (Bögen, Geraden, Kreise), flache Farben, keine Verläufe.
# 64er-Raster, Blick nach rechts, Bodenlinie bei y = 45.
TOP, GROUND = 17.0, 45.0
SAND = "#DCC8A4"              # Gesicht auf hellem Grund (nur im Logo)
MOSS = "#2F5A3C"
GRASS = "#4E7F45"
LEAF_GREEN = "#8DB86A"
LEAF_LIGHT = "#A6CA86"
NIGHT = "#0E1D15"


def _f(v):
    return f"{v:.2f}".rstrip("0").rstrip(".")


def igel_parts(top=TOP, g=GROUND):
    """Pfade des Igels: Rücken, Schuppen (Strich), Gesicht, Trennlinie, Auge, Nase, Füße."""
    r = g - top
    x0, xt1 = 5.0, 39.0
    xt0 = x0 + r * 0.55
    back = (f"M{_f(x0)} {_f(g)}C{_f(x0)} {_f(g - r * 0.62)} {_f(xt0 - r * 0.42)} {_f(top)} {_f(xt0)} {_f(top)}"
            f"L{_f(xt1)} {_f(top)}C{_f(xt1 + 8)} {_f(top)} 47.5 {_f(top + 6)} 48.5 {_f(top + 12)}L35 {_f(g)}Z")
    rows, w = [], 7.0
    for k in range(3):
        y, x = top + 8.0 + k * 6.6, 2 - (k % 2) * w / 2
        while x < 50:
            rows.append(f"M{_f(x)} {_f(y)}a{_f(w / 2)} {_f(w / 2)} 0 0 1 {_f(w)} 0")
            x += w
    face = (f"M33.5 {_f(g)}L46.6 {_f(top + 10.2)}C48.8 {_f(top + 6.4)} 52.6 {_f(top + 8.6)} 54 {_f(top + 13)}"
            f"L59.4 {_f(g - 8.6)}C60.4 {_f(g - 6)} 59.6 {_f(g - 3.8)} 57 {_f(g - 3.4)}"
            f"C52 {_f(g - 2.4)} 49 {_f(g)} 45 {_f(g)}Z")
    seam = f"M34.2 {_f(g + 1)}L47.4 {_f(top + 10.6)}"          # Kante Rücken/Gesicht (für einfarbig)
    foot = lambda x: f"M{_f(x)} {_f(g - 1)}h5.2v2.4a2.6 2.6 0 0 1-5.2 0Z"
    return dict(back=back, scales="".join(rows), face=face, seam=seam,
                eye=(51.6, g - 15.6, 2.75), nose=(59.1, g - 7.3, 2.25), feet=foot(13.5) + foot(28.5))


def igel_svg(colors=None, mono=None, uid="i", scales=True):
    """Farbig: colors = (Rücken, Schuppen, Gesicht, Dunkel, Glanz, Füße).
    Einfarbig: mono = Farbe; Details werden per Maske ausgespart."""
    p = igel_parts()
    ex, ey, er = p["eye"]
    nx, ny, nr = p["nose"]
    clip = f'<clipPath id="{uid}-c"><path d="{p["back"]}"/></clipPath>'
    if mono:
        mask = (f'<mask id="{uid}-m" maskUnits="userSpaceOnUse" x="0" y="0" width="64" height="64">'
                f'<rect width="64" height="64" fill="#fff"/>'
                + (f'<path d="{p["scales"]}" clip-path="url(#{uid}-c)" fill="none" stroke="#000" stroke-width="1.6" stroke-linecap="round"/>' if scales else "")
                + f'<path d="{p["seam"]}" fill="none" stroke="#000" stroke-width="1.5"/>'
                f'<circle cx="{_f(ex)}" cy="{_f(ey)}" r="{_f(er)}" fill="#000"/>'
                f'<circle cx="{_f(ex + 1)}" cy="{_f(ey - 1)}" r=".9" fill="#fff"/>'
                f'<circle cx="{_f(nx)}" cy="{_f(ny)}" r="{_f(nr + .5)}" fill="none" stroke="#000" stroke-width=".9"/></mask>')
        return (f"<defs>{clip}{mask}</defs>"
                f'<g fill="{mono}" mask="url(#{uid}-m)"><path d="{p["back"]}"/><path d="{p["face"]}"/>'
                f'<circle cx="{_f(nx)}" cy="{_f(ny)}" r="{_f(nr)}"/><path d="{p["feet"]}"/></g>')
    c_back, c_scale, c_face, c_dark, c_glint, c_feet = colors
    out = f'<defs>{clip}</defs><path fill="{c_feet}" d="{p["feet"]}"/><path fill="{c_back}" d="{p["back"]}"/>'
    if scales:
        out += (f'<path d="{p["scales"]}" clip-path="url(#{uid}-c)" fill="none" stroke="{c_scale}" '
                f'stroke-width="1.6" stroke-linecap="round"/>')
    out += (f'<path fill="{c_face}" d="{p["face"]}"/>'
            f'<circle cx="{_f(ex)}" cy="{_f(ey)}" r="{_f(er)}" fill="{c_dark}"/>'
            f'<circle cx="{_f(ex + 1)}" cy="{_f(ey - 1)}" r=".9" fill="{c_glint}"/>'
            f'<circle cx="{_f(nx)}" cy="{_f(ny)}" r="{_f(nr)}" fill="{c_dark}"/>')
    return out


# Begrenzung im 64er-Raster (Rücken hinten bis Nase, Oberkante bis Fußsohle)
IGEL_BOX = (5.0, TOP, 61.35, GROUND + 4.0)


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
    # zum Igel, dieselbe Familie wie die Display-Schrift der Website
    name_d, name_b, name_w, cap = text_path(
        "bricolage-grotesque-wdth-latin.woff2", NAME, 100, -0.006, wght=740, wdth=82)
    desc_d, desc_b, desc_w, desc_cap = text_path(
        "instrument-sans-var-latin.woff2", DESCRIPTOR, 25, 0.24, wght=600)

    title = f"{NAME} Gartenservice"
    LIGHT = (MOSS, GRASS, SAND, NIGHT, LINEN, NIGHT)              # auf hellem Grund
    DARK = (LEAF_GREEN, LEAF_LIGHT, LINEN, NIGHT, LINEN, LINEN)   # auf dunklem Grund
    # Variante: (Igel farbig | einfarbig, Name, Zusatz)
    variants = {
        "": (dict(colors=LIGHT), INK, GREEN),
        "-invers": (dict(colors=DARK), LINEN, LEAF),
        # einfarbig ohne Schuppen: ruhig genug für Stick, Stempel und Folie
        "-einfarbig": (dict(mono=GREEN, scales=False), GREEN, GREEN),
        "-schwarz": (dict(mono="#000", scales=False), "#000", "#000"),
        "-weiss": (dict(mono="#fff", scales=False), "#fff", "#fff"),
    }
    bx0, by0, bx1, by1 = IGEL_BOX
    bw = bx1 - bx0

    # --- Primärlogo, horizontal: Rückenkante auf Höhe der Versalien, Bodenlinie
    #     auf der Grundlinie von „GARTENSERVICE“
    name_y = -name_b[1]
    desc_y = name_y + name_b[3] + 24 + desc_cap
    s = desc_y / (GROUND - TOP)
    tx = bw * s + 22
    W = tx + max(name_w, desc_w) + 2
    H = (by1 - TOP) * s + 2
    for suffix, (igel, c_name, c_desc) in variants.items():
        body = (f'<g transform="translate({fmt(-bx0 * s)} {fmt(-TOP * s)}) scale({fmt(s)})">{igel_svg(uid="ip", **igel)}</g>'
                f'<path fill="{c_name}" transform="translate({fmt(tx)} {fmt(name_y)})" d="{name_d}"/>'
                f'<path fill="{c_desc}" transform="translate({fmt(tx + 2)} {fmt(desc_y)})" d="{desc_d}"/>')
        (OUT / f"logo-primaer{suffix}.svg").write_text(svg(W, H, body, title))

    # --- Kompakt (gestapelt)
    wmax = max(name_w, desc_w)
    s2 = wmax * 0.62 / bw
    W2 = wmax + 8
    ih = (by1 - by0) * s2
    ny = ih + 34 - name_b[1]
    dy = ny + name_b[3] + 22 + desc_cap
    for suffix, (igel, c_name, c_desc) in variants.items():
        body = (f'<g transform="translate({fmt((W2 - bw * s2) / 2 - bx0 * s2)} {fmt(-by0 * s2)}) scale({fmt(s2)})">{igel_svg(uid="ik", **igel)}</g>'
                f'<path fill="{c_name}" transform="translate({fmt((W2 - name_w) / 2)} {fmt(ny)})" d="{name_d}"/>'
                f'<path fill="{c_desc}" transform="translate({fmt((W2 - desc_w) / 2)} {fmt(dy)})" d="{desc_d}"/>')
        (OUT / f"logo-kompakt{suffix}.svg").write_text(svg(W2, dy + 4, body, title))

    # --- Symbol (64er-Raster)
    for suffix, (igel, _, _) in variants.items():
        (OUT / f"symbol{suffix}.svg").write_text(
            svg(64, 64, igel_svg(uid="is", **igel), title).replace('width="64" height="64" ', "", 1))

    # --- Favicon & App-Icon: Igel auf Waldgrün, ohne Schuppen (16–32 px)
    cx, cy = (bx0 + bx1) / 2, (by0 + by1) / 2
    k = 54 / bw
    fav = (f'<rect width="64" height="64" rx="12" fill="{GREEN}"/>'
           f'<g transform="translate({fmt(32 - cx * k)} {fmt(33 - cy * k)}) scale({fmt(k)})">{igel_svg(DARK, uid="if", scales=False)}</g>')
    (ROOT / "favicon.svg").write_text(svg(64, 64, fav, title).replace('width="64" height="64" ', "", 1))
    k = 330 / bw
    avatar = (f'<rect width="512" height="512" fill="{GREEN}"/>'
              f'<g transform="translate({fmt(256 - cx * k)} {fmt(262 - cy * k)}) scale({fmt(k)})">{igel_svg(DARK, uid="ia")}</g>')
    (OUT / "social-avatar.svg").write_text(svg(512, 512, avatar, title))

    print("ok", OUT, f"Primärlogo {fmt(W)} × {fmt(H)}")


if __name__ == "__main__":
    build()
