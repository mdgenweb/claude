#!/usr/bin/env python3
"""Renders and lints Sky Glide's real GUI on several devices, without Roblox.

tests/ui_layout.luau boots the real client and server (headless mocks) and dumps the PlayerGui
tree in every screen state on every device. This script lays those dumps out the way Roblox does
(UDim2 + AnchorPoint, UIScale, UIPadding, UIListLayout, UIGridLayout, UIAspectRatioConstraint,
ScrollingFrame canvases, ClipsDescendants, ZIndex, safe-area insets), draws PNGs and reports:

  * offscreen   - a visible button that is not fully on the screen
  * overlap     - two visible buttons on the same layer covering each other
  * collide     - two HUD groups (children of a layer root) drawn on top of each other
  * small-touch - a touch-device button under 28 px, or under 32 px and narrower than 48 px
                  (wide pills are easy to hit; the developer-only Admin panel is excluded)
  * tiny-text   - text drawn under 9 px
  * cut-off     - fixed-size text wider than its box

usage: python3 tests/ui_render.py --luau PATH [--out DIR] [--only state,state] [--no-png]
Exit code 1 when anything is reported.
"""
import argparse
import json
import pathlib
import re
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import run_tests  # noqa: E402

FONT_PATH = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
EMOJI_PATH = "/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf"
GUI_CLASSES = {"Frame", "TextLabel", "TextButton", "TextBox", "ImageLabel", "ImageButton",
               "ScrollingFrame", "ViewportFrame", "CanvasGroup", "VideoFrame"}
TEXT_CLASSES = {"TextLabel", "TextButton", "TextBox"}
BUTTON_CLASSES = {"TextButton", "ImageButton", "TextBox"}
DEFAULT_SIZE = {"TextLabel": (0, 200, 0, 50), "TextButton": (0, 200, 0, 50), "TextBox": (0, 200, 0, 50)}


# ---------------------------------------------------------------------------------------------
# dump parsing

RUN_ERRORS = []  # client/network errors raised while driving the screens


def run_dump(luau):
    script = HERE / "ui_layout.luau"
    out_dir = HERE / ".bundle"
    out_dir.mkdir(exist_ok=True)
    bundled = out_dir / "ui_layout.bundle.luau"
    bundled.write_text(run_tests.bundle(script))
    result = subprocess.run([luau, str(bundled)], capture_output=True, text=True)
    if result.returncode != 0:
        sys.stderr.write(result.stdout[-4000:] + result.stderr[-4000:])
        raise SystemExit("ui_layout.luau failed")
    dumps, current = [], None
    RUN_ERRORS.clear()
    for line in result.stdout.splitlines():
        if line.startswith("DUMP\t"):
            current = {"meta": json.loads(line[5:]), "nodes": {}, "children": {0: []}}
        elif line.startswith("NODE\t") and current is not None:
            node = json.loads(line[5:])
            current["nodes"][node["id"]] = node
            current["children"].setdefault(node["parent"], []).append(node["id"])
            current["children"].setdefault(node["id"], [])
        elif line == "END" and current is not None:
            dumps.append(current)
            current = None
        elif "ERROR" in line or line.startswith("WARN"):
            print("ui_layout:", line)
            if "ERROR" in line:
                RUN_ERRORS.append(line)
    return dumps


# ---------------------------------------------------------------------------------------------
# value helpers

def udim2(v, default=(0, 0, 0, 0)):
    if isinstance(v, dict) and v.get("_t") == "UDim2":
        return v["xs"] or 0, v["xo"] or 0, v["ys"] or 0, v["yo"] or 0
    return default


def udim(v, default=(0, 0)):
    if isinstance(v, dict) and v.get("_t") == "UDim":
        return v["s"] or 0, v["o"] or 0
    return default


def vec2(v, default=(0, 0)):
    if isinstance(v, dict) and v.get("_t") == "V2":
        return v["x"] or 0, v["y"] or 0
    return default


def color(v, default=(163, 162, 165)):
    if isinstance(v, dict) and v.get("_t") == "C3":
        return (int(max(0, min(1, v["r"])) * 255), int(max(0, min(1, v["g"])) * 255), int(max(0, min(1, v["b"])) * 255))
    return default


def enum(v, default=None):
    if isinstance(v, dict) and v.get("_t") == "Enum":
        return v["n"]
    return default


def num(v, default=0.0):
    return v if isinstance(v, (int, float)) else default


# ---------------------------------------------------------------------------------------------
# layout

class Laid:
    __slots__ = ("id", "cls", "name", "props", "x", "y", "w", "h", "scale", "clip", "z", "path", "shown", "max_text")

    def __init__(self, nid, props):
        self.id = nid
        self.props = props
        self.cls = props.get("ClassName", "?")
        self.name = props.get("Name", "?")


def modifiers(dump, nid):
    mods = {}
    for cid in dump["children"].get(nid, []):
        p = dump["nodes"][cid]["props"]
        cls = p.get("ClassName")
        if cls in ("UIScale", "UIPadding", "UIListLayout", "UIGridLayout", "UICorner", "UIStroke",
                   "UIGradient", "UIAspectRatioConstraint", "UISizeConstraint", "UITextSizeConstraint"):
            mods.setdefault(cls, p)
    return mods


def layout(dump):
    meta = dump["meta"]
    W, H = meta["w"], meta["h"]
    nodes, children = dump["nodes"], dump["children"]
    laid = []

    def place(nid, frame, clip, path, order_key):
        props = nodes[nid]["props"]
        cls = props.get("ClassName")
        if cls not in GUI_CLASSES:
            return
        if props.get("Visible") is False:
            return
        ox, oy, cw, ch, S = frame
        mods = modifiers(dump, nid)
        k = num(mods.get("UIScale", {}).get("Scale"), 1.0)
        xs, xo, ys, yo = udim2(props.get("Size"), DEFAULT_SIZE.get(cls, (0, 100, 0, 100)))
        w, h = cw * xs + xo, ch * ys + yo
        override = props.get("__slot")
        if override and override.get("size"):
            w, h = override["size"]
        if "UIAspectRatioConstraint" in mods:
            ratio = num(mods["UIAspectRatioConstraint"].get("AspectRatio"), 1) or 1
            if w / max(h, 1e-6) > ratio:
                w = h * ratio
            else:
                h = w / ratio
        if "UISizeConstraint" in mods:
            mn = vec2(mods["UISizeConstraint"].get("MinSize"), (0, 0))
            mx = vec2(mods["UISizeConstraint"].get("MaxSize"), (1e9, 1e9))
            w = max(mn[0], min(mx[0], w))
            h = max(mn[1], min(mx[1], h))
        ax, ay = vec2(props.get("AnchorPoint"), (0, 0))
        if override:
            # layouts place the top-left corner
            px, py = override["pos"]
            left_units, top_units = px, py
            anchor_x, anchor_y = ox + px * S, oy + py * S
            ax = ay = 0
        else:
            pxs, pxo, pys, pyo = udim2(props.get("Position"))
            anchor_x = ox + (cw * pxs + pxo) * S
            anchor_y = oy + (ch * pys + pyo) * S
        rw, rh = w * S * k, h * S * k
        x = anchor_x - ax * rw
        y = anchor_y - ay * rh
        node = Laid(nid, props)
        node.x, node.y, node.w, node.h, node.scale = x, y, rw, rh, S * k
        node.max_text = num(mods.get("UITextSizeConstraint", {}).get("MaxTextSize"), 0) or None
        node.clip = clip
        node.z = order_key
        node.path = path + "/" + node.name
        laid.append(node)
        # children content box
        pad = mods.get("UIPadding")
        pl = pr = pt = pb = 0.0
        if pad:
            pl = sum(a * b for a, b in zip(udim(pad.get("PaddingLeft")), (w, 1)))
            pr = sum(a * b for a, b in zip(udim(pad.get("PaddingRight")), (w, 1)))
            pt = sum(a * b for a, b in zip(udim(pad.get("PaddingTop")), (h, 1)))
            pb = sum(a * b for a, b in zip(udim(pad.get("PaddingBottom")), (h, 1)))
        inner = (x + pl * S * k, y + pt * S * k, w - pl - pr, h - pt - pb, S * k)
        child_clip = clip
        if props.get("ClipsDescendants") or cls == "ScrollingFrame":
            child_clip = intersect(clip, (x, y, rw, rh))
        if cls == "ScrollingFrame":
            cxs, cxo, cys, cyo = udim2(props.get("CanvasSize"), (0, 0, 0, 0))
            cv_w, cv_h = w * cxs + cxo, h * cys + cyo
            cpx, cpy = vec2(props.get("CanvasPosition"), (0, 0))
            inner = (inner[0] - cpx * S * k, inner[1] - cpy * S * k, max(inner[2], cv_w) if cv_w > 0 else inner[2], max(inner[3], cv_h), S * k)
        arrange(nid, mods, inner)
        kids = [c for c in children.get(nid, [])]
        kids.sort(key=lambda c: num(nodes[c]["props"].get("ZIndex"), 1))
        for i, c in enumerate(kids):
            place(c, inner, child_clip, node.path, order_key + (num(nodes[c]["props"].get("ZIndex"), 1), i))

    def arrange(nid, mods, inner):
        _, _, cw, ch, _ = inner
        kids = [c for c in children.get(nid, []) if nodes[c]["props"].get("ClassName") in GUI_CLASSES and nodes[c]["props"].get("Visible") is not False]
        for c in kids:
            nodes[c]["props"].pop("__slot", None)
        if "UIListLayout" in mods and kids:
            lay = mods["UIListLayout"]
            horizontal = enum(lay.get("FillDirection"), "Vertical") == "Horizontal"
            ps, po = udim(lay.get("Padding"))
            padding = (cw if horizontal else ch) * ps + po
            kids.sort(key=lambda c: num(nodes[c]["props"].get("LayoutOrder"), 0))
            sizes = []
            for c in kids:
                p = nodes[c]["props"]
                xs, xo, ys, yo = udim2(p.get("Size"), DEFAULT_SIZE.get(p.get("ClassName"), (0, 100, 0, 100)))
                sizes.append((cw * xs + xo, ch * ys + yo))
            total = sum(s[0 if horizontal else 1] for s in sizes) + padding * (len(kids) - 1)
            ha = enum(lay.get("HorizontalAlignment"), "Left")
            va = enum(lay.get("VerticalAlignment"), "Top")
            if horizontal:
                start = {"Left": 0, "Center": (cw - total) / 2, "Right": cw - total}.get(ha, 0)
            else:
                start = {"Top": 0, "Center": (ch - total) / 2, "Bottom": ch - total}.get(va, 0)
            cursor = start
            for c, (sw, sh) in zip(kids, sizes):
                if horizontal:
                    cy = {"Top": 0, "Center": (ch - sh) / 2, "Bottom": ch - sh}.get(va, 0)
                    nodes[c]["props"]["__slot"] = {"pos": (cursor, cy)}
                    cursor += sw + padding
                else:
                    cx = {"Left": 0, "Center": (cw - sw) / 2, "Right": cw - sw}.get(ha, 0)
                    nodes[c]["props"]["__slot"] = {"pos": (cx, cursor)}
                    cursor += sh + padding
        elif "UIGridLayout" in mods and kids:
            lay = mods["UIGridLayout"]
            cxs, cxo, cys, cyo = udim2(lay.get("CellSize"), (0, 100, 0, 100))
            pxs, pxo, pys, pyo = udim2(lay.get("CellPadding"), (0, 5, 0, 5))
            cell_w, cell_h = cw * cxs + cxo, ch * cys + cyo
            pad_x, pad_y = cw * pxs + pxo, ch * pys + pyo
            max_cells = int(num(lay.get("FillDirectionMaxCells"), 0))
            cols = max(1, int((cw + pad_x) // max(1, cell_w + pad_x)))
            if max_cells > 0:
                cols = min(cols, max_cells)
            kids.sort(key=lambda c: num(nodes[c]["props"].get("LayoutOrder"), 0))
            used_cols = min(cols, len(kids))
            block_w = used_cols * cell_w + (used_cols - 1) * pad_x
            ha = enum(lay.get("HorizontalAlignment"), "Left")
            start_x = {"Left": 0, "Center": (cw - block_w) / 2, "Right": cw - block_w}.get(ha, 0)
            for i, c in enumerate(kids):
                r, col = divmod(i, cols)
                nodes[c]["props"]["__slot"] = {"pos": (start_x + col * (cell_w + pad_x), r * (cell_h + pad_y)), "size": (cell_w, cell_h)}

    top = meta["top"]
    guis = [c for c in children.get(0, []) if nodes[c]["props"].get("ClassName") == "ScreenGui"]
    guis.sort(key=lambda c: num(nodes[c]["props"].get("DisplayOrder"), 0))
    for gi, g in enumerate(guis):
        p = nodes[g]["props"]
        if p.get("Enabled") is False:
            continue
        if p.get("IgnoreGuiInset"):
            frame = (0, 0, W, H, 1.0)
        else:
            frame = (meta["left"], top, W - meta["left"] - meta["right"], H - top - meta["bottom"], 1.0)
        mods = modifiers(dump, g)
        arrange(g, mods, frame)
        for i, c in enumerate(children.get(g, [])):
            place(c, frame, (0, 0, W, H), p.get("Name", "Gui"), (gi, num(nodes[c]["props"].get("ZIndex"), 1), i))
    return laid


def intersect(a, b):
    x1, y1 = max(a[0], b[0]), max(a[1], b[1])
    x2, y2 = min(a[0] + a[2], b[0] + b[2]), min(a[1] + a[3], b[1] + b[3])
    return (x1, y1, max(0, x2 - x1), max(0, y2 - y1))


def area(r):
    return max(0, r[2]) * max(0, r[3])


# ---------------------------------------------------------------------------------------------
# text

_fonts = {}


def font(size):
    size = max(4, int(round(size)))
    if size not in _fonts:
        _fonts[size] = ImageFont.truetype(FONT_PATH, size)
    return _fonts[size]


_emoji_font = None


def emoji_font():
    global _emoji_font
    if _emoji_font is None:
        try:
            _emoji_font = ImageFont.truetype(EMOJI_PATH, 109)
        except OSError:
            _emoji_font = False
    return _emoji_font


def is_emoji(ch):
    o = ord(ch)
    return o >= 0x1F000 or 0x2600 <= o <= 0x27BF or 0x2B00 <= o <= 0x2BFF or o in (0x2122, 0x2139, 0x231A, 0x231B, 0x23F0, 0x23F3)


def plain(text):
    return re.sub(r"<[^>]+>", "", text).replace("️", "")


def text_width(text, size):
    f = font(size)
    width = 0.0
    for ch in text:
        width += size * 1.05 if is_emoji(ch) else f.getlength(ch)
    return width


def wrap(text, size, max_w):
    lines = []
    for para in text.split("\n"):
        words, line = para.split(" "), ""
        for word in words:
            trial = word if not line else line + " " + word
            if text_width(trial, size) <= max_w or not line:
                line = trial
            else:
                lines.append(line)
                line = word
        lines.append(line)
    return lines


def text_metrics(node):
    """Returns (pixel size, lines, overflow)."""
    p = node.props
    text = plain(str(p.get("Text", "")))
    if not text:
        return 0, [], False
    wrapped = bool(p.get("TextWrapped"))
    if p.get("TextScaled"):
        cap = 100.0
        if node.max_text:
            cap = min(cap, node.max_text * node.scale)
        lo, hi, best = 1.0, min(cap, node.h), 1.0
        while hi - lo > 0.5:
            mid = (lo + hi) / 2
            lines = wrap(text, mid, node.w) if wrapped else text.split("\n")
            fits = max(text_width(l, mid) for l in lines) <= node.w and len(lines) * mid * 1.15 <= node.h + 0.5
            if fits:
                best, lo = mid, mid
            else:
                hi = mid
        size = best
        lines = wrap(text, size, node.w) if wrapped else text.split("\n")
        return size, lines, False
    size = num(p.get("TextSize"), 14) * node.scale
    lines = wrap(text, size, node.w) if wrapped else text.split("\n")
    overflow = (not wrapped) and max(text_width(l, size) for l in lines) > node.w + 2
    return size, lines, overflow


# ---------------------------------------------------------------------------------------------
# drawing

def rgba(c, transparency):
    return (c[0], c[1], c[2], int(255 * (1 - max(0.0, min(1.0, transparency)))))


def draw_dump(dump, laid, path, nodes_by_id):
    meta = dump["meta"]
    W, H = int(meta["w"]), int(meta["h"])
    img = Image.new("RGBA", (W, H), (118, 178, 228, 255))
    base = ImageDraw.Draw(img)
    # sky + ground backdrop so translucent panels read like in game
    base.rectangle((0, int(H * 0.62), W, H), fill=(96, 170, 84, 255))
    if meta["top"]:
        base.rectangle((0, 0, W, meta["top"]), fill=(30, 30, 36, 255))
        base.text((12, meta["top"] / 2 - 7), "Roblox top bar (inset)", fill=(200, 200, 200, 255), font=font(14))
    for side, x0 in (("left", 0), ("right", W - meta["right"])):
        if meta[side]:
            base.rectangle((x0, 0, x0 + meta[side], H), fill=(20, 20, 20, 255))
    ordered = sorted(laid, key=lambda n: n.z)
    for node in ordered:
        p = node.props
        clip = node.clip
        vis = intersect((node.x, node.y, node.w, node.h), clip)
        if area(vis) <= 0:
            continue
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        mods = modifiers(dump, node.id)
        radius = 0
        if "UICorner" in mods:
            cs, co = udim(mods["UICorner"].get("CornerRadius"), (0, 8))
            radius = max(0, min(node.w, node.h) * cs + co * node.scale)
            radius = min(radius, min(node.w, node.h) / 2)
        box = (node.x, node.y, node.x + node.w, node.y + node.h)
        bt = num(p.get("BackgroundTransparency"), 0)
        if node.cls in ("ImageLabel", "ImageButton") and bt >= 1:
            pass
        if bt < 1 and node.w >= 1 and node.h >= 1:
            fill = color(p.get("BackgroundColor3"))
            grad = mods.get("UIGradient")
            if grad and grad.get("Enabled") is not False and isinstance(grad.get("Color"), dict):
                args = grad["Color"].get("a", [])
                cols = [color(a) for a in args if isinstance(a, dict) and a.get("_t") == "C3"]
                if len(cols) >= 2:
                    g = gradient_image(int(node.w) + 1, int(node.h) + 1, cols[0], cols[1], num(grad.get("Rotation"), 0), fill, bt)
                    mask = Image.new("L", g.size, 0)
                    ImageDraw.Draw(mask).rounded_rectangle((0, 0, g.size[0] - 1, g.size[1] - 1), radius=radius, fill=255)
                    layer.paste(g, (int(node.x), int(node.y)), mask)
                else:
                    d.rounded_rectangle(box, radius=radius, fill=rgba(fill, bt))
            else:
                d.rounded_rectangle(box, radius=radius, fill=rgba(fill, bt))
        if node.cls in ("ImageLabel", "ImageButton") and num(p.get("ImageTransparency"), 0) < 1 and p.get("Image"):
            d.rounded_rectangle(box, radius=radius, outline=(255, 255, 255, 120), width=1)
        if node.cls == "ViewportFrame":
            d.rounded_rectangle(box, radius=radius, outline=(255, 255, 255, 90), width=2)
            d.text((node.x + 4, node.y + 4), "3D", fill=(255, 255, 255, 140), font=font(max(8, min(18, node.h / 5))))
        stroke = mods.get("UIStroke")
        if stroke and enum(stroke.get("ApplyStrokeMode"), "Contextual") == "Border" and stroke.get("Enabled") is not False:
            t = max(1, int(round(num(stroke.get("Thickness"), 1) * node.scale)))
            d.rounded_rectangle(box, radius=radius, outline=rgba(color(stroke.get("Color"), (0, 0, 0)), num(stroke.get("Transparency"), 0)), width=t)
        if node.cls in TEXT_CLASSES:
            draw_text(d, layer, node, mods)
        if clip != (0, 0, W, H):
            mask = Image.new("L", (W, H), 0)
            ImageDraw.Draw(mask).rectangle((clip[0], clip[1], clip[0] + clip[2], clip[1] + clip[3]), fill=255)
            layer.putalpha(Image.composite(layer.getchannel("A"), Image.new("L", (W, H), 0), mask))
        img.alpha_composite(layer)
    img.convert("RGB").save(path)


def gradient_image(w, h, c0, c1, rotation, tint, transparency):
    g = Image.new("RGBA", (w, h))
    px = g.load()
    vertical = 45 < (rotation % 180) < 135
    flip = 90 < (rotation % 360) < 270
    for i in range(h if vertical else w):
        t = i / max(1, (h if vertical else w) - 1)
        if flip:
            t = 1 - t
        c = tuple(int((c0[j] + (c1[j] - c0[j]) * t) * tint[j] / 255) for j in range(3)) + (int(255 * (1 - transparency)),)
        if vertical:
            for x in range(w):
                px[x, i] = c
        else:
            for y in range(h):
                px[i, y] = c
    return g


def draw_text(d, layer, node, mods):
    p = node.props
    size, lines, _ = text_metrics(node)
    if not lines or size < 1:
        return
    tc = rgba(color(p.get("TextColor3"), (27, 42, 53)), num(p.get("TextTransparency"), 0))
    stroke = mods.get("UIStroke")
    stroke_w, stroke_c = 0, None
    if stroke and enum(stroke.get("ApplyStrokeMode"), "Contextual") != "Border":
        stroke_w = max(1, int(round(num(stroke.get("Thickness"), 1) * node.scale)))
        stroke_c = rgba(color(stroke.get("Color"), (0, 0, 0)), num(stroke.get("Transparency"), 0))
    line_h = size * 1.15
    total_h = line_h * len(lines)
    ya = enum(p.get("TextYAlignment"), "Center")
    xa = enum(p.get("TextXAlignment"), "Center")
    y = node.y + {"Top": 0, "Center": (node.h - total_h) / 2, "Bottom": node.h - total_h}.get(ya, (node.h - total_h) / 2)
    f = font(size)
    for line in lines:
        lw = text_width(line, size)
        x = node.x + {"Left": 0, "Center": (node.w - lw) / 2, "Right": node.w - lw}.get(xa, (node.w - lw) / 2)
        for ch in line:
            if is_emoji(ch):
                ef = emoji_font()
                if ef:
                    glyph = Image.new("RGBA", (136, 128), (0, 0, 0, 0))
                    ImageDraw.Draw(glyph).text((0, 0), ch, font=ef, embedded_color=True)
                    gs = max(1, int(size))
                    glyph = glyph.resize((int(gs * 136 / 128), gs))
                    layer.alpha_composite(glyph, (int(x), int(y + (line_h - gs) / 2)))
                x += size * 1.05
            else:
                d.text((x, y + (line_h - size) / 2), ch, font=f, fill=tc, stroke_width=stroke_w, stroke_fill=stroke_c)
                x += f.getlength(ch)
        y += line_h


# ---------------------------------------------------------------------------------------------
# lint

def ancestors(dump, nid):
    out = set()
    nodes = dump["nodes"]
    while nid in nodes:
        nid = nodes[nid]["parent"]
        out.add(nid)
    return out


def solid(n):
    p = n.props
    if num(p.get("BackgroundTransparency"), 0) < 0.95 and n.w > 2 and n.h > 2:
        return True
    return n.cls in TEXT_CLASSES and str(p.get("Text", "")).strip() != "" and num(p.get("TextTransparency"), 0) < 1


def lint(dump, laid):
    meta = dump["meta"]
    W, H = meta["w"], meta["h"]
    screen = (0, 0, W, H)
    gui_area = (meta["left"], meta["top"], W - meta["left"] - meta["right"], H - meta["top"] - meta["bottom"])
    issues = []
    buttons = [n for n in laid if n.cls in BUTTON_CLASSES and n.props.get("Active") is not False and area(intersect((n.x, n.y, n.w, n.h), n.clip)) > 0]
    for n in buttons:
        vis = intersect((n.x, n.y, n.w, n.h), n.clip)
        on = intersect(vis, screen)
        full_screen = n.w >= gui_area[2] * 0.9 and n.h >= gui_area[3] * 0.9
        if area(on) < area(vis) - 1 and not full_screen:
            issues.append(("offscreen", n.path, f"{n.w:.0f}x{n.h:.0f} at ({n.x:.0f},{n.y:.0f})"))
        short, long = min(n.w, n.h), max(n.w, n.h)
        too_small = short < 28 or (short < 32 and long < 48)
        if meta["touch"] and too_small and not full_screen and "/Admin/" not in n.path and area(vis) >= area((0, 0, n.w, n.h)) * 0.9:
            issues.append(("small-touch", n.path, f"{n.w:.0f}x{n.h:.0f} px"))
    # overlapping buttons (not nested, not full-screen catchers)
    rects = [(n, intersect((n.x, n.y, n.w, n.h), n.clip)) for n in buttons if not (n.w >= gui_area[2] * 0.9 and n.h >= gui_area[3] * 0.9)]
    anc = {n.id: ancestors(dump, n.id) for n, _ in rects}
    for i in range(len(rects)):
        a, ra = rects[i]
        for j in range(i + 1, len(rects)):
            b, rb = rects[j]
            if a.id in anc[b.id] or b.id in anc[a.id]:
                continue
            if a.path.split("/")[0] != b.path.split("/")[0]:
                continue  # different ScreenGuis: the upper layer's Active root takes the input
            ov = area(intersect(ra, rb))
            if ov > 0.15 * min(area(ra), area(rb)) and ov > 40:
                issues.append(("overlap", a.path + "  <>  " + b.path, f"{ov:.0f} px2"))
    # HUD groups that run into each other (each group = the solid things drawn inside it)
    groups = {}
    for n in laid:
        parts = n.path.split("/")
        if len(parts) >= 3 and parts[1] == "Root" and solid(n):
            r = intersect((n.x, n.y, n.w, n.h), n.clip)
            if area(r) <= 0:
                continue
            key = "/".join(parts[:3])
            g = groups.get(key)
            groups[key] = r if g is None else (min(g[0], r[0]), min(g[1], r[1]), max(g[0] + g[2], r[0] + r[2]) - min(g[0], r[0]), max(g[1] + g[3], r[1] + r[3]) - min(g[1], r[1]))
    # the landing card is a 2.6 s overlay that also hides when the next throw starts
    keys = [k for k, r in groups.items() if area(r) < 0.5 * area(gui_area) and not k.endswith("/LandingCard")]
    for i in range(len(keys)):
        for j in range(i + 1, len(keys)):
            a, b = keys[i], keys[j]
            if a.split("/")[0] != b.split("/")[0]:
                continue
            ov = area(intersect(groups[a], groups[b]))
            if ov > 60:
                issues.append(("collide", a + "  <>  " + b, f"{ov:.0f} px2"))
    for n in laid:
        if n.cls not in TEXT_CLASSES or not str(n.props.get("Text", "")).strip():
            continue
        if area(intersect((n.x, n.y, n.w, n.h), n.clip)) <= 0 or num(n.props.get("TextTransparency"), 0) >= 1:
            continue
        size, lines, overflow = text_metrics(n)
        if 0 < size < 9 and n.h >= 4:
            issues.append(("tiny-text", n.path, f"{size:.1f}px '{plain(str(n.props.get('Text')))[:30]}'"))
        if overflow:
            issues.append(("cut-off", n.path, f"'{plain(str(n.props.get('Text')))[:40]}' in {n.w:.0f}px"))
    return issues


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--luau", default="luau")
    parser.add_argument("--out", default=str(HERE / ".ui"))
    parser.add_argument("--only", default="")
    parser.add_argument("--no-png", action="store_true")
    args = parser.parse_args()
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    dumps = run_dump(args.luau)
    only = set(filter(None, args.only.split(",")))
    total = 0
    report = []
    for dump in dumps:
        meta = dump["meta"]
        if only and meta["label"] not in only:
            continue
        laid = layout(dump)
        issues = lint(dump, laid)
        name = f"{meta['label']}__{meta['device']}"
        if not args.no_png:
            draw_dump(dump, laid, out / f"{name}.png", dump["nodes"])
        for kind, where, detail in issues:
            report.append(f"{name}: {kind}: {where} ({detail})")
        total += len(issues)
    for err in RUN_ERRORS:
        report.append("run: error: " + err)
    total += len(RUN_ERRORS)
    (out / "report.txt").write_text("\n".join(report) + "\n")
    for line in report:
        print(line)
    print(f"ui_render: {len(dumps)} screens, {total} issues, images in {out}")
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
