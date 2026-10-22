"""Mister Markup — Racket #001, v2 edit: fully animated cut.

Smooth 24 fps camera (push-ins, punch zooms, whip-pans, shakes), ~2.5 s average shot length,
characters animated on twos (classic limited animation), animated sets, particle/impact FX,
kinetic word-highlight captions. Also exports SFX_CUES for mix2.py.

python3 build/render2.py              -> out/frames_v2.mp4
python3 build/render2.py --stills a,b -> out/previews/v2_<t>.png
"""
import json, math, os, subprocess, sys
import numpy as np, skia

HERE = os.path.dirname(__file__)
sys.path.insert(0, HERE)
import art, fx
from art import W, H, INK, WHITE, MONEY, MONEY_D, G1, G2, G3, G4, G5, G6, fill, stroke, text, hexc
from script import LINES, RECEIPT, RECEIPT_TOTAL

ROOT = os.path.join(HERE, "..")
TL = json.load(open(os.path.join(ROOT, "audio", "timeline.json")))
LN = {l["id"]: l for l in TL["lines"]}
ENV = {k: np.array(v) for k, v in TL["env"].items()}
FPS = 24
TOTAL = TL["total"]
BEAT = 60 / 116


def S(i): return LN[i]["start"]
def E(i): return LN[i]["end"]
def clamp(x, a=0.0, b=1.0): return max(a, min(b, x))
def ease(x): x = clamp(x); return x * x * (3 - 2 * x)
def ease_out(x): x = clamp(x); return 1 - (1 - x) ** 3
def ease_in(x): x = clamp(x); return x ** 3
def ease_out_back(x, k=1.70158): x = clamp(x) - 1; return 1 + (k + 1) * x ** 3 + k * x ** 2
def prog(t, a, b): return clamp((t - a) / max(1e-6, b - a))
def lerp(a, b, k): return a + (b - a) * k


# ------------------------------------------------------------------ key times
T_PRICE = S("hook2") + 0.42
T_RECEIPT_IN = S("greed") + 0.4
T_TOTAL = E("verdict") + 1.25
T_STAMP = T_TOTAL + 0.35
T_FLAT = T_STAMP + 0.15
T_TEAR = S("steep") + 0.55
FREEZE = (S("poll") + 1.7, S("poll") + 2.6)

# ------------------------------------------------------------------ speech helpers
def speaking(t):
    for l in TL["lines"]:
        if l["start"] <= t <= l["end"]:
            return l
    return None


def env_at(spk, t):
    i = int(t * FPS); a = ENV[spk]
    return float(a[i]) if 0 <= i < len(a) else 0.0


def markup_mouth(t, idle="grin"):
    l = speaking(t)
    if not l or l["spk"] != "M":
        return idle
    e = env_at("M", t)
    if e < 0.07:
        return "closed"
    q = int(t * 12) % 3
    if e < 0.28:
        return ("E", "closed", "E")[q]
    if e < 0.55:
        return ("E", "A", "O")[q]
    return ("A", "O", "A")[q]


def fn_mouth(t):
    l = speaking(t)
    return "open" if (l and l["spk"] == "F" and env_at("F", t) > 0.12 and int(t * 12) % 2 == 0) else "closed"


def blink(t, period=3.3, off=0.0):
    return ((t + off) % period) < 0.09


# ------------------------------------------------------------------ captions (chunked, with line ids)
def caption_chunks():
    out = []
    for lid, spk, tts, cap, gap, fxn in LINES:
        l = LN[lid]
        phrases, cur = [], []
        for w in cap.split():
            cur.append(w)
            if w.rstrip("*").endswith((".", "?", "!", ",", ":")):
                phrases.append(cur); cur = []
        if cur:
            phrases.append(cur)
        chunks = []
        for ph in phrases:
            n = len(ph); parts = max(1, math.ceil(n / 4)); size = math.ceil(n / parts)
            for i in range(0, n, size):
                chunks.append(ph[i:i + size])
        merged = []
        for ch in chunks:
            if merged and len(ch) == 1 and len(merged[-1]) < 4 and not merged[-1][-1].rstrip("*").endswith((".", "?", "!")):
                merged[-1] = merged[-1] + ch
            else:
                merged.append(ch)
        tot = sum(len(" ".join(ch)) for ch in merged)
        t0 = l["start"]; dur = l["end"] - l["start"]
        for ci, ch in enumerate(merged):
            d = dur * len(" ".join(ch)) / tot
            out.append({"a": t0, "b": t0 + d, "words": [(w.strip("*"), w.startswith("*")) for w in ch], "spk": spk, "lid": lid, "ci": ci})
            t0 += d
    return out


CAPS = caption_chunks()


def chunk_at(t):
    last = None
    for ch in CAPS:
        if ch["a"] <= t:
            last = ch
        else:
            break
    return last


# Markup gesture director: (arms, expr) cycled per caption chunk of each line
POSES = {
    "hook1": [("present", "sly"), ("point", "sly")], "hook2": [("wide", "outrage")],
    "hook3": [("shrug", "sly"), ("whisper", "whisper")], "racket": [("whisper", "whisper")],
    "greed": [("shrug", "sly"), ("think", "sly"), ("wave", "proud")], "ticket": [("point", "sly"), ("present", "sly"), ("point", "outrage")],
    "blockbuster": [("wide", "outrage")], "crumbs": [("shrug", "guilty"), ("think", "sly")],
    "counter": [("point", "sly"), ("present", "proud"), ("point", "sly")], "soda": [("present", "sly"), ("point", "sly"), ("shrug", "sly")],
    "twenty": [("point", "sly"), ("present", "proud")], "sneaky": [("whisper", "whisper"), ("point", "sly")],
    "bait": [("point", "sly"), ("shrug", "sly"), ("present", "proud")], "decoy": [("present", "proud")],
    "invented": [("hold", "proud")], "poll": [("shrug", "sly"), ("present", "sly"), ("wave", "proud")],
    "verdict": [("think", "sly")], "steep": [("wide", "outrage"), ("present", "proud")],
    "promove": [("present", "sly"), ("point", "sly")], "racket_out": [("wave", "proud"), ("present", "proud")],
}


def markup_pose(t, **over):
    arms, expr = "hips", "sly"
    ch = chunk_at(t)
    while ch is not None and ch["lid"] not in POSES:
        idx = CAPS.index(ch)
        ch = CAPS[idx - 1] if idx > 0 else None
    if ch is not None:
        seq = POSES[ch["lid"]]
        arms, expr = seq[ch["ci"] % len(seq)]
    l = speaking(t)
    look = (1, 0) if arms in ("point", "present") else ((0, -1) if arms == "wave" else (0, 0))
    p = {"arms": arms, "expr": expr, "mouth": markup_mouth(t), "blink": blink(t), "look": look}
    p.update(over)
    return p


def bob(t, amt=8.0):
    ph = (t % BEAT) / BEAT
    return -abs(math.sin(ph * math.pi)) * amt, 1 + 0.02 * math.cos(ph * 2 * math.pi)


def draw_markup_bob(c, x, y, s, t, pose=None, **kw):
    dy, sq = bob(t, 9 * s)
    pose = dict(pose or markup_pose(t))
    pose.setdefault("squash", sq)
    art.draw_markup(c, x, y + dy, s, pose, t=t, **kw)


# ------------------------------------------------------------------ cached layers
def make_layer(fn, *a, **kw):
    arr = np.zeros((H, W, 4), np.uint8); s = skia.Surface(arr); fn(s.getCanvas(), *a, **kw)
    return s.makeImageSnapshot()


L_BOARD = make_layer(art.bg_counter, part="board")
L_FRONT = make_layer(art.bg_counter, part="front")
L_VAULT = make_layer(art.bg_vault, wheel=False)
L_GRID = make_layer(art.bg_grid)
L_BOARDROOM = make_layer(art.bg_boardroom)


def counter_back(c, t, glow=0.6, chase=True):
    art.bg_counter(c, part="wall", rot=t * 7.0)
    c.drawImage(L_BOARD, 0, 0)
    art.bulb_glow(c, t, speed=8, chase=chase, strength=glow)


def counter_front(c):
    c.drawImage(L_FRONT, 0, 0)


def vault_bg(c, t, spin=40.0):
    c.drawImage(L_VAULT, 0, 0)
    art.draw_vault_wheel(c, t * spin)
    art.draw_pipe(c)


def grid_bg(c, t):
    c.drawImage(L_GRID, 0, 0)
    r = np.random.default_rng(3)
    for i in range(18):  # drifting dust motes
        x = (r.uniform(0, W) + t * r.uniform(10, 30)) % W
        y = (r.uniform(0, 1500) + math.sin(t + i) * 20)
        c.drawCircle(x, y, r.uniform(2, 4), fill(G4, 120))


def pipe_money(c, t, n=9, speed=560, scale=0.55):
    path = art.pipe_path(); pm = skia.PathMeasure(path, False); L = pm.getLength()
    for i in range(n):
        d = (t * speed + i * L / n) % L
        pos, tan = pm.getPosTan(d)
        ang = math.degrees(math.atan2(tan.y(), tan.x()))
        art.draw_bill(c, pos.x(), pos.y(), scale, ang=ang + math.sin(t * 5 + i) * 15)


# ------------------------------------------------------------------ camera, events, shots
class Cam:
    def __init__(self, c, z, cx, cy, rot=0.0):
        self.c, self.z, self.cx, self.cy, self.rot = c, z, cx, cy, rot

    def __enter__(self):
        c = self.c
        c.save(); c.translate(W / 2, H / 2); c.rotate(self.rot); c.scale(self.z, self.z); c.translate(-self.cx, -self.cy)
        return c

    def __exit__(self, *a):
        self.c.restore()


def keycam(t, keys):
    """keys: [(t, z, cx, cy), ...] eased between consecutive keys."""
    if t <= keys[0][0]:
        return keys[0][1:]
    for (t0, z0, x0, y0), (t1, z1, x1, y1) in zip(keys, keys[1:]):
        if t <= t1:
            k = ease(prog(t, t0, t1))
            return lerp(z0, z1, k), lerp(x0, x1, k), lerp(y0, y1, k)
    return keys[-1][1:]


SHAKES = []    # (t0, amp, dur)
PUNCHES = []   # (t0, amount)
FLASHES = []   # (t0, alpha, dur)
SFX_CUES = []  # (name, t, gain)


def shake(t0, amp=26, dur=0.4): SHAKES.append((t0, amp, dur))
def punch(t0, amt=0.12): PUNCHES.append((t0, amt))
def flash(t0, a=200, dur=0.12): FLASHES.append((t0, a, dur))
def sfx(name, t, g=0.5): SFX_CUES.append((name, t, g))


SHOTS = []


def shot(name, a, b, draw, cam, trans="cut", receipt=False, cap_y=1330):
    SHOTS.append(dict(name=name, a=a, b=b, draw=draw, cam=cam, trans=trans, receipt=receipt, cap_y=cap_y))


# ================================================================== SHOT DRAW FUNCTIONS
# signature: draw(c, t, tq) — t = real time (smooth fx), tq = time on twos (characters)

def bucket_drop_y(t):
    d = prog(t, 0.0, 0.3)
    return 1205 - (1 - d * d) * 1400


def draw_counter_hook(c, t, tq):
    counter_back(c, t)
    arms_pose = markup_pose(tq)
    pop = max(0.0, 1 - (t - T_PRICE) / 0.35) if t >= T_PRICE else 0.0
    draw_markup_bob(c, 310, 1650, 1.05, tq, arms_pose, boil=int(tq * 12) % 3 + 1,
                    price="$9.00" if t >= T_PRICE else None, price_pop=pop)
    counter_front(c)
    yy = bucket_drop_y(t)
    sq = 1.0
    if 0.3 <= t < 0.6:
        k = (t - 0.3) / 0.3
        sq = 1 - 0.22 * math.sin(k * math.pi) * (1 - k)
    c.save(); c.translate(800, yy); c.scale(1 / sq ** 0.5, sq); c.translate(-800, -yy)
    art.draw_popcorn(c, 800, yy, 1.1, t=tq, boil=int(tq * 12) % 3 + 1, face=True, dance=1.0 if t > S("hook3") - 0.2 else 0.25,
                     mouth="grin" if t > S("hook3") else "flat", price="$9.00" if t >= T_PRICE else None, tag_side=-1)
    c.restore()
    fx.kernels(c, 800, 870, t, 0.3, 1.2, every=0.09, seed=2)
    fx.dust_puff(c, 800, 1200, t, 0.3, seed=4)
    if t >= T_PRICE:
        fx.money_burst(c, 310, 700, t, T_PRICE, n=9, seed=21, speed=1250, scale=0.6)


def draw_bucket_react(c, t, tq):
    counter_back(c, t)
    counter_front(c)
    art.draw_popcorn(c, 800, 1205, 1.1, t=tq, boil=int(tq * 12) % 3 + 1, face=True, dance=1.0, mouth="grin", price="$9.00", tag_side=-1)
    fx.kernels(c, 800, 870, t, S("hook3"), S("racket"), every=0.22, seed=5)
    fx.sweat(c, 905, 960, t, 1.4)


def draw_whisper_ecu(c, t, tq):
    counter_back(c, t)
    draw_markup_bob(c, 310, 1650, 1.05, tq, markup_pose(tq, lean=-5), boil=int(tq * 12) % 3 + 1, price="$9.00")
    counter_front(c)


def draw_title(c, t, tq):
    a = shot_by("B").get("a")
    lt = t - a
    c.drawRect(skia.Rect.MakeWH(W, H), fill("#0e0e0e"))
    cx, cy = W / 2, 820
    c.drawCircle(cx, cy, 300, stroke(G5, 8)); c.drawCircle(cx, cy, 250, stroke(G5, 4))
    c.drawLine(cx - 420, cy, cx + 420, cy, stroke(G4, 4)); c.drawLine(cx, cy - 420, cx, cy + 420, stroke(G4, 4))
    ang = (lt / 0.48) * 360
    p = skia.Path(); p.moveTo(cx, cy); p.arcTo(skia.Rect.MakeLTRB(cx - 300, cy - 300, cx + 300, cy + 300), -90, ang % 360, False); p.close()
    c.drawPath(p, fill(G3, 120))
    num = max(1, 3 - int(lt / 0.32))
    if lt < 0.85:
        text(c, str(num), cx, cy + 90, 260, "deco", G6)
    else:
        k = ease_out_back(prog(lt, 0.85, 1.1))
        c.save(); c.translate(cx, cy); c.scale(k, k)
        text(c, "A FINE PRINT", 0, -40, 104, "deco", WHITE)
        text(c, "PICTURE", 0, 80, 120, "deco", WHITE)
        c.restore()
        text(c, "MISTER MARKUP in", cx, 1290, 54, "slab", G5, alpha=int(255 * prog(lt, 0.95, 1.15)))
        text(c, "RACKET #001: MOVIE POPCORN", cx, 1380, 56, "anton", MONEY, alpha=int(255 * prog(lt, 1.0, 1.2)))


def draw_stage_markup(c, t, tq, x=540, wally=None, bills_from=None, footnote=None, pose_over=None):
    art.stage_live(c, t, sweep=math.sin(t * 0.8) * 120)
    pose = markup_pose(tq, **(pose_over or {}))
    draw_markup_bob(c, x, 1600, 1.0, tq, pose, boil=int(tq * 12) % 3 + 1)
    if bills_from is not None:
        fx.confetti_bills(c, t, bills_from, n=24, seed=31, life=3.5)
    if wally:
        wx, th, walk = wally
        art.draw_wally(c, wx, 1640, 0.85, thick=th, t=tq, boil=int(tq * 12) % 3 + 1, walk=walk)
    if footnote:
        fxp, fyp, fs = footnote
        art.draw_footnote(c, fxp, fyp, fs, t=tq, mouth="closed", boil=int(tq * 12) % 3 + 1)


def wally_thick(t):
    th = 1.0
    th -= 0.25 * prog(t, S("ticket"), E("blockbuster"))
    th -= 0.2 * prog(t, S("counter"), E("twenty"))
    th -= 0.15 * prog(t, S("bait"), E("decoy"))
    return th


def draw_C1(c, t, tq):
    draw_stage_markup(c, t, tq)


def draw_C2(c, t, tq):
    a = S("greed") + 1.85
    wx = lerp(1250, 800, ease_out(prog(t, a + 0.1, a + 1.0)))
    walk = t * 2.2 if t < a + 1.0 else None
    draw_stage_markup(c, t, tq, wally=(wx, wally_thick(t), walk), bills_from=a)


def draw_vault(c, t, tq):
    vault_bg(c, t, spin=60)
    pipe_money(c, t)
    for i in range(3):  # bills hop from Wally into the booth window
        k = ((t * 1.4 + i / 3) % 1.0)
        art.draw_bill(c, lerp(250, 230, k), 1460 - math.sin(k * math.pi) * 380 - k * 400, 0.5 * (1 - 0.4 * k), ang=k * 300)
    art.draw_wally(c, 240, 1660, 0.85, thick=wally_thick(t), t=tq, boil=int(tq * 12) % 3 + 1)
    t_g = S("ticket") + 1.75
    if t > t_g:
        k = ease_out_back(prog(t, t_g, t_g + 0.3))
        c.save(); c.translate(760, 1060); c.scale(k, k)
        c.drawCircle(0, 0, 130, fill(INK, 235)); c.drawCircle(0, 0, 130, stroke(WHITE, 7))
        text(c, "~50%", 0, 26, 84, "anton", MONEY)
        c.restore()
        fx.shockwave(c, 760, 1060, t, t_g, r1=600)


def draw_board(c, t, tq):
    c.drawImage(L_BOARDROOM, 0, 0)
    a = shot_by("E")["a"]
    for i, x in enumerate((240, 540, 840)):
        laugh = abs(math.sin(tq * 10 + i)) * 18
        art.draw_fat_cat(c, x, 1390 - laugh, 1.0, t=tq, puff=((t - a) * 0.6 + i * 0.3) % 1.0)
    fx.confetti_bills(c, t, a, n=16, seed=41, life=2.5)


def draw_vault_footnote(c, t, tq, card=False):
    vault_bg(c, t, spin=20)
    pipe_money(c, t, n=5, speed=300)
    a = shot_by("F1")["a"]
    k = prog(t, a, a + 0.4)
    fxp = lerp(1250, 540, ease_out(k))
    fyp = 1760 - math.sin(k * math.pi) * 380
    art.draw_footnote(c, fxp, fyp, 1.25, t=tq, mouth=fn_mouth(tq), boil=int(tq * 12) % 3 + 1, blink=blink(tq, 2.7))
    if t >= a + 0.4:
        fx.dust_puff(c, 540, 1760, t, a + 0.4, seed=8, spread=200)
    art.draw_wally(c, 240, 1660, 0.85, thick=wally_thick(t), t=tq, boil=int(tq * 12) % 3 + 1)
    if card:
        b = shot_by("F2")["a"]
        k = ease_out_back(prog(t, b, b + 0.35))
        art.draw_card(c, W / 2, lerp(-400, 690, k), ["*Source: AMC & Cinemark", "2025 annual reports (10-K):", "U.S. film rent = ~51-57%", "of ticket sales"],
                      w=820, size=42)


def draw_F1(c, t, tq): draw_vault_footnote(c, t, tq, card=False)
def draw_F2(c, t, tq): draw_vault_footnote(c, t, tq, card=True)


def draw_G(c, t, tq):
    draw_stage_markup(c, t, tq, wally=(820, wally_thick(t), None))


def draw_counter_main(c, t, tq, soda_in=None, cut=0.0, bucket_tag=None):
    counter_back(c, t)
    draw_markup_bob(c, 250, 1650, 1.05, tq, markup_pose(tq), boil=int(tq * 12) % 3 + 1)
    counter_front(c)
    art.draw_popcorn(c, 840, 1205, 1.0, t=tq, boil=int(tq * 12) % 3 + 1, face=True, dance=0.6)
    fx.kernels(c, 840, 900, t, S("counter"), S("twenty"), every=0.35, seed=12, spread=0.7)
    if bucket_tag:
        t0 = bucket_tag
        k = ease_out_back(prog(t, t0, t0 + 0.3))
        c.save(); c.translate(820, 760); c.rotate(-8); c.scale(k, k)
        c.drawRoundRect(skia.Rect.MakeLTRB(-190, -70, 190, 60), 16, 16, fill("#e3e1da")); c.drawRoundRect(skia.Rect.MakeLTRB(-190, -70, 190, 60), 16, 16, stroke(INK, 6))
        text(c, "COST: ~$1", 0, 18, 70, "marker", MONEY, outline=MONEY_D, ow=3)
        c.restore()
    if soda_in is not None:
        sx = lerp(1350, 600, ease_out(prog(t, soda_in, soda_in + 0.35)))
        art.draw_soda(c, sx, 1205, 0.95, t=tq, boil=int(tq * 12) % 3 + 1, cutaway=cut)
        if t < soda_in + 0.35:
            fx.speed_lines(c, t, radial=False, n=18, strength=0.8, direction=0.0)
        if cut > 0.2:
            fx.bubbles(c, sx - 60, sx + 60, 920, 1180, t)
        return sx
    return None


def draw_H1(c, t, tq): draw_counter_main(c, t, tq)
def draw_H2(c, t, tq): draw_counter_main(c, t, tq, bucket_tag=S("counter") + 2.0)


def draw_H3(c, t, tq):
    draw_counter_main(c, t, tq, soda_in=S("soda") - 0.25)


def draw_H4(c, t, tq):
    cut = prog(t, S("soda") + 1.3, S("soda") + 1.9)
    sx = draw_counter_main(c, t, tq, soda_in=S("soda") - 2.0, cut=cut)
    if cut > 0.5:
        a = int(255 * prog(t, S("soda") + 1.7, S("soda") + 2.0))
        text(c, "5 PARTS WATER", sx + 30, 760, 46, "anton", WHITE, outline=INK, ow=10, alpha=a)
        text(c, "1 PART SYRUP + ICE", sx + 30, 818, 46, "anton", WHITE, outline=INK, ow=10, alpha=a)


def draw_dollar(c, t, tq):
    grid_bg(c, t)
    a = shot_by("I")["a"]
    text(c, "YOUR SNACK DOLLAR", W / 2, 720, 84, "deco", INK)
    k = ease_out_back(prog(t, a, a + 0.4))
    spin = (1 - ease_out(prog(t, a, a + 0.5))) * 540
    c.save(); c.translate(W / 2, 960); c.rotate(spin); c.scale(5.6 * k, 5.6 * k)
    art.draw_bill(c, 0, 0, 1.0)
    split = prog(t, S("twenty") + 2.0, S("twenty") + 2.4)
    c.restore()
    if split > 0:
        # the 20% food chunk snaps off and drops away
        c.save(); c.translate(W / 2, 960)
        drop = ease_in(prog(t, S("twenty") + 2.4, S("twenty") + 3.2))
        c.save(); c.clipRect(skia.Rect.MakeLTRB(-60 * 5.6, -32 * 5.6, -36 * 5.6, 32 * 5.6))
        c.translate(-40 * drop, 420 * drop); c.rotate(-25 * drop)
        c.scale(5.6, 5.6)
        c.drawRect(skia.Rect.MakeLTRB(-62, -32, 62, 32), fill(G3, 240))
        for xx in range(-80, 20, 6):
            c.drawLine(xx, -32, xx + 30, 32, stroke(G2, 1.2))
        c.restore()
        c.restore()
        fx.impact(c, W / 2 - 134, 960, t, S("twenty") + 2.0, size=180, seed=13)
    if split >= 1:
        al = int(255 * prog(t, S("twenty") + 2.5, S("twenty") + 2.8))
        text(c, "FOOD ~20¢", 270, 1222, 62, "anton", INK, alpha=al)
        text(c, "THEATER KEEPS ~80¢", 665, 1222, 62, "anton", MONEY_D, alpha=al)
        text(c, "(before staff & rent)", W / 2, 1284, 40, "mono", G2, alpha=al)


BUCKETS = [(205, 0.58, "$7.25", "SMALL"), (535, 0.78, "$8.75", "MEDIUM"), (865, 0.96, "$9.25", "LARGE")]


def draw_buckets(c, t, tq, focus=None, enter=None, freeze=False, labels=True, faces=False):
    for i, (x, s, p, nm) in enumerate(BUCKETS):
        yoff = 0.0
        if enter is not None:
            k = ease_out_back(prog(t, enter + i * 0.18, enter + i * 0.18 + 0.35))
            yoff = (1 - k) * -1400
        bounce = abs(math.sin(tq * 7)) * 30 if (focus == i and not freeze) else 0.0
        if focus == i:
            g = skia.GradientShader.MakeRadial(skia.Point(x, 1000), 260, [hexc("#ffffff", 200), hexc("#ffffff", 0)])
            c.drawCircle(x, 1000, 260, skia.Paint(AntiAlias=True, Shader=g))
        art.draw_popcorn(c, x, 1120 - bounce + yoff, s, t=tq, boil=int(tq * 12) % 3 + 1, label=False, seed=i + 2,
                         face=(focus == i or faces), mouth="grin")
        if labels:
            text(c, p, x, 1205 + yoff, 64, "marker", MONEY, outline=MONEY_D, ow=3)
    if labels:
        text(c, "example prices", W / 2, 1262, 34, "mono", G2)


def draw_pointer(c, tx, ty, t):
    hx, hy = -10, ty + 140
    ang = math.degrees(math.atan2(ty - hy, tx - hx)) + math.sin(t * 8) * 2
    c.drawLine(-60, hy + 40, hx, hy, stroke(INK, 62)); c.drawLine(-60, hy + 40, hx, hy, stroke(G3, 50))
    a = math.radians(ang)
    sx, sy = hx + math.cos(a) * 40, hy + math.sin(a) * 40
    ex, ey = tx - math.cos(a) * 30, ty - math.sin(a) * 30
    c.drawLine(sx, sy, ex, ey, stroke(INK, 16)); c.drawLine(sx, sy, ex, ey, stroke(G5, 8))
    art.draw_glove(c, hx, hy, ang, "fist", 1.1)


def decoy_set(c, t, tq, focus, hook=False, steal=False, title=False, enter=None, labels=True):
    grid_bg(c, t)
    draw_buckets(c, t, tq, focus=focus, enter=enter, labels=labels)
    if hook:
        t0 = S("bait") + 0.9
        k = ease_out_back(prog(t, t0, t0 + 0.4))
        swing = math.sin((t - t0) * 6) * 18 * (1 - prog(t, t0, t0 + 2))
        hy = lerp(-100, 760, k)
        hx = 535 + swing
        c.drawLine(535, -10, hx, hy, stroke(INK, 4))
        hp = skia.Path(); hp.moveTo(hx, hy); hp.lineTo(hx, hy + 70); hp.cubicTo(hx, hy + 120, hx - 65, hy + 120, hx - 65, hy + 70)
        c.drawPath(hp, stroke(INK, 12)); c.drawPath(hp, stroke(G5, 5))
        if k > 0.8:
            kk = ease_out_back(prog(t, t0 + 0.3, t0 + 0.55))
            c.save(); c.translate(535, 690); c.scale(kk, kk)
            text(c, "BAIT", 0, 0, 92, "bungee", WHITE, outline=INK, ow=14)
            c.restore()
    if steal:
        t0 = S("bait") + 2.6
        k = prog(t, t0, t0 + 0.45)
        ap = skia.Path(); ap.moveTo(600, 840); ap.quadTo(720, 700, lerp(600, 820, k), lerp(840, 820, k))
        c.drawPath(ap, stroke(INK, 16))
        if k >= 1:
            c.drawPath(art.path_poly([(830, 830), (790, 800), (812, 852)]), fill(INK))
            kk = ease_out_back(prog(t, t0 + 0.45, t0 + 0.7))
            c.save(); c.translate(865, 640); c.scale(kk, kk); c.rotate(math.sin(t * 6) * 4)
            text(c, "STEAL!", 0, 0, 80, "bungee", MONEY, outline=INK, ow=12)
            c.restore()
            for i in range(5):
                a = t * 3 + i * 1.26
                fx.star(c, 865 + math.cos(a) * 180, 900 + math.sin(a) * 130, 26 + 8 * math.sin(t * 9 + i))
    tgt = {None: (205, 900), 0: (205, 900), 1: (500, 880), 2: (820, 860)}[focus]
    draw_pointer(c, *tgt, t)
    if title:
        t0 = S("decoy") - 0.05
        k = ease_out_back(prog(t, t0, t0 + 0.3))
        c.save(); c.translate(W / 2, 430); c.scale(k, k)
        text(c, "THE DECOY EFFECT", 0, 0, 92, "deco", INK)
        c.restore()


def draw_J1(c, t, tq):
    focus = 1 if t >= S("sneaky") + 1.1 else None
    decoy_set(c, t, tq, focus, enter=shot_by("J1")["a"])


def draw_J2(c, t, tq): decoy_set(c, t, tq, 1, hook=True, labels=False)
def draw_J3(c, t, tq): decoy_set(c, t, tq, 2, hook=True, steal=True)
def draw_J4(c, t, tq): decoy_set(c, t, tq, 2, hook=True, steal=True, title=True)


def draw_1953(c, t, tq):
    art.stage_live(c, t, sweep=0)
    c.drawRect(skia.Rect.MakeWH(W, H), fill("#000000", 80))
    art.draw_markup(c, 540, 1600 + bob(tq, 9)[0], 1.0, markup_pose(tq, arms="hold", expr="proud"), t=tq, boil=int(tq * 12) % 3 + 1)
    art.draw_popcorn(c, 540, 1080 + bob(tq, 9)[0], 0.62, t=tq, boil=int(tq * 12) % 3 + 1, label=False, seed=3)
    # applauding silhouettes in the foreground
    for i, x in enumerate((140, 400, 680, 940)):
        clap = abs(math.sin(tq * 12 + i)) * 14
        c.drawCircle(x, 1830 - clap, 90, fill("#050505")); c.drawRect(skia.Rect.MakeLTRB(x - 120, 1880 - clap, x + 120, 2000), fill("#050505"))
    text(c, "1953", W / 2, 300, 150, "deco", WHITE, outline=INK, ow=10)
    text(c, "(as he remembers it)", W / 2, 372, 44, "mono", G6)


def draw_L(c, t, tq, card=False):
    grid_bg(c, t)
    a = shot_by("L1")["a"]
    k = ease_out_back(prog(t, a, a + 0.3))
    art.draw_footnote(c, 330, 1770, 1.45 * k, t=tq, mouth=fn_mouth(tq), boil=int(tq * 12) % 3 + 1, blink=blink(tq, 2.7))
    droop = t >= S("fn_1982") + 0.5
    art.draw_markup(c, 820, 1640, 0.62, {"arms": "shrug", "expr": "guilty", "mouth": "guilty" if droop else "grin",
                                         "string": "down" if droop else "up", "blink": blink(tq)}, t=tq, boil=int(tq * 12) % 3 + 1)
    if droop:
        fx.sweat(c, 905, 1010, t, 0.9)
    if card:
        b = shot_by("L2")["a"]
        kk = ease_out_back(prog(t, b, b + 0.3))
        art.draw_card(c, W / 2, 360, ["*Huber, Payne & Puto (1982)", "Journal of Consumer Research"], w=840, size=42, scale=kk)


def draw_L1(c, t, tq): draw_L(c, t, tq, card=False)
def draw_L2(c, t, tq): draw_L(c, t, tq, card=True)


def draw_poll(c, t, tq):
    freeze = FREEZE[0] <= t < FREEZE[1]
    grid_bg(c, t)
    draw_buckets(c, t, tq, focus=None, freeze=freeze, faces=True)
    for i, (x, s, p, nm) in enumerate(BUCKETS):
        k = ease_out_back(prog(t, S("poll") + i * 0.35, S("poll") + i * 0.35 + 0.3))
        c.save(); c.translate(x, 740); c.scale(k, k)
        text(c, nm + "?", 0, 0, 50, "bungee", WHITE, outline=INK, ow=10)
        c.restore()
    if t > S("poll") + 1.4:
        k = ease_out_back(prog(t, S("poll") + 1.4, S("poll") + 1.7))
        c.save(); c.translate(W / 2, 400); c.scale(k, k)
        c.drawRoundRect(skia.Rect.MakeLTRB(-400, -70, 400, 70), 24, 24, fill(INK, 235))
        text(c, "BE HONEST:", 0, -5, 56, "anton", WHITE)
        text(c, "COMMENT BELOW", 0, 55, 56, "anton", MONEY)
        c.restore()


def receipt_shown(t):
    n = 0.0
    for i, (_, _, lid, off) in enumerate(RECEIPT):
        if t >= S(lid) + off:
            n = i + 1
    return n


def draw_receipt(c, t, center=False):
    if t < T_RECEIPT_IN:
        return
    sl = ease_out_back(prog(t, T_RECEIPT_IN, T_RECEIPT_IN + 0.45))
    if not center:
        sl *= 1 - ease(prog(t, S("decoy") - 0.3, S("decoy")))
        if sl <= 0.01:
            return
    else:
        sl = 1.0
    x, y, sc = 44, lerp(-700, 150, sl), 1.0
    if center:
        k = ease(prog(t, S("verdict") - 0.1, S("verdict") + 0.5))
        x = lerp(44, W / 2 - 390 * 1.6 / 2, k); y = lerp(150, 330, k); sc = lerp(1.0, 1.6, k)
    torn = ease(prog(t, T_TEAR, T_TEAR + 0.75)) ** 2
    reveal = prog(t, T_TOTAL, T_TOTAL + 0.3) if t >= T_TOTAL else 0.0
    # little print "jiggle" when a new line arrives
    jig = 0.0
    for _, _, lid, off in RECEIPT:
        dt = t - (S(lid) + off)
        if 0 <= dt < 0.3:
            jig = math.sin(dt * 60) * 4 * (1 - dt / 0.3)
    art.draw_receipt(c, x + jig, y, [(a, b) for a, b, _, _ in RECEIPT], receipt_shown(t), total=RECEIPT_TOTAL if t >= T_TOTAL else None,
                     total_reveal=reveal, torn=torn, scale=sc)


def draw_verdict(c, t, tq):
    art.stage_live(c, t, sweep=math.sin(t * 2.2) * 260 if t < T_TOTAL else 0)
    c.drawRect(skia.Rect.MakeWH(W, H), fill("#000000", 70))
    flat = ease(prog(t, T_FLAT, T_FLAT + 0.15))
    shiver = math.sin(t * 60) * 4 if T_TOTAL - 1.35 < t < T_FLAT else 0
    art.draw_wally(c, 540 + shiver, 1720, 1.1, thick=wally_thick(t), t=tq, boil=int(tq * 12) % 3 + 1, flat=flat)
    fx.dust_puff(c, 540, 1720, t, T_FLAT, seed=17, spread=320)
    draw_receipt(c, t, center=True)
    if t >= T_TOTAL:
        fx.money_burst(c, 120, 1150, t, T_TOTAL, n=9, seed=51, speed=1100)
        fx.money_burst(c, 960, 1150, t, T_TOTAL, n=9, seed=52, speed=1100)
    if t >= T_STAMP:
        art.draw_stamp(c, W / 2, 1090, "STEEP", prog(t, T_STAMP, T_STAMP + 0.6), sub="BUT IT KEEPS THE LIGHTS ON")
        fx.impact(c, W / 2, 1090, t, T_STAMP + 0.08, size=420, seed=19)
        fx.shockwave(c, W / 2, 1090, t, T_STAMP + 0.08, r1=900, w=20)


def draw_lights(c, t, tq):
    counter_back(c, t, glow=1.0, chase=True)
    draw_markup_bob(c, 300, 1650, 1.05, tq, markup_pose(tq, look=(1, -1)), boil=int(tq * 12) % 3 + 1)
    counter_front(c)
    art.draw_popcorn(c, 820, 1205, 1.05, t=tq, boil=int(tq * 12) % 3 + 1, face=True, dance=1.0)
    fx.kernels(c, 820, 890, t, shot_by("N5")["a"], TOTAL, every=0.15, seed=23)
    draw_receipt(c, t, center=True)


def draw_promove(c, t, tq):
    art.stage_live(c, t, sweep=-150)
    a = shot_by("O")["a"]
    k = prog(t, a, a + 1.0)
    x = lerp(-250, 250, ease_out(k))
    walking = k < 1.0
    pose = markup_pose(tq, arms="walk", walk=tq * 2.2) if walking else markup_pose(tq)
    draw_markup_bob(c, x, 1600, 0.95, tq, pose, boil=int(tq * 12) % 3 + 1)
    if t > a + 0.6:
        kk = prog(t, a + 0.6, a + 1.6)
        swing = math.sin(kk * 12) * 14 * (1 - kk)
        c.save(); c.translate(675, 300); c.rotate(swing)
        c.drawLine(-150, -300, -150, 100, stroke(INK, 5)); c.drawLine(150, -300, 150, 100, stroke(INK, 5))
        art.draw_card(c, 0, 100, ["PRO MOVE:", "check your", "theater's app", "*free refills", "*member deals"], w=490, size=50)
        c.restore()


def draw_outro(c, t, tq):
    art.stage_live(c, t, sweep=math.sin(t * 1.5) * 200)
    a = shot_by("P")["a"]
    draw_markup_bob(c, 540, 1600, 1.0, tq, markup_pose(tq), boil=int(tq * 12) % 3 + 1)
    inflate = ease_out_back(prog(t, a + 0.4, a + 0.9))
    art.draw_wally(c, 860, 1640, 0.85, thick=lerp(0.25, 0.8, inflate), t=tq, boil=int(tq * 12) % 3 + 1, flat=lerp(1.0, 0.0, inflate))
    hop = abs(math.sin(tq * 6)) * 40
    art.draw_footnote(c, 200, 1660 - hop, 0.8, t=tq, mouth="closed", boil=int(tq * 12) % 3 + 1)
    fx.confetti_bills(c, t, a + 0.2, n=26, seed=61, life=3.2)
    rows = [["NOW", "YA", "KNOW"], ["THE", "RACKET."]]
    sz = 100
    i = 0
    for ri, row in enumerate(rows):
        ws_ = [art.text_width(w, sz, "bungee") for w in row]
        sp = art.text_width(" ", sz, "bungee")
        x = W / 2 - (sum(ws_) + sp * (len(row) - 1)) / 2
        for w, wd in zip(row, ws_):
            k = ease_out_back(prog(t, a + 0.1 + i * 0.12, a + 0.35 + i * 0.12))
            if k > 0:
                c.save(); c.translate(x + wd / 2, 360 + ri * 118 + math.sin(t * 6 + i) * 6); c.scale(k, k)
                text(c, w, 0, 0, sz, "bungee", WHITE, outline=INK, ow=14)
                c.restore()
            x += wd + sp
            i += 1


def draw_next(c, t, tq):
    art.stage_live(c, t)
    a = shot_by("Q")["a"]
    k = prog(t, a, a + 0.4)
    art.draw_footnote(c, 540, 1720 - math.sin(k * math.pi) * 300, 1.35 * max(0.2, ease_out_back(k)), t=tq, mouth=fn_mouth(tq),
                      boil=int(tq * 12) % 3 + 1, blink=blink(tq, 2.7))
    if t > a + 0.3:
        flip = prog(t, a + 0.3, a + 0.6)
        sx = abs(math.cos(flip * math.pi)) if flip < 1 else 1.0
        c.save(); c.translate(W / 2, 480); c.scale(max(0.02, sx), 1)
        if flip < 0.5:
            c.drawRoundRect(skia.Rect.MakeLTRB(-320, 0, 320, 260), 14, 14, fill(G2)); c.drawRoundRect(skia.Rect.MakeLTRB(-320, 0, 320, 260), 14, 14, stroke(INK, 6))
        else:
            art.draw_card(c, 0, 0, ["NEXT REEL:", "Why is hotel", "check-in at 3?"], w=640, size=60)
        c.restore()
        text(c, "@mistermarkup", W / 2, 1000, 56, "anton", WHITE, outline=INK, ow=10)


# ================================================================== EDIT DECISION LIST
def shot_by(name):
    for s in SHOTS:
        if s["name"] == name:
            return s
    raise KeyError(name)


hx, hy = 310, 1650 - 860  # Markup head (counter shots)
shot("A1", 0.0, T_PRICE, draw_counter_hook, lambda t: keycam(t, [(0, 1.0, W / 2, H / 2), (T_PRICE, 1.07, W / 2, H / 2 - 20)]))
shot("A2", T_PRICE, S("hook3") - 0.05, draw_counter_hook,
     lambda t: keycam(t, [(T_PRICE, 1.65, 330, 800), (S("hook3"), 1.75, 330, 790)]))
shot("A3", S("hook3") - 0.05, S("racket") - 0.05, draw_bucket_react,
     lambda t: keycam(t, [(S("hook3"), 1.55, 760, 1000), (S("racket"), 1.7, 770, 990)]), trans="whipR")
shot("A4", S("racket") - 0.05, E("racket") + 0.05, draw_whisper_ecu,
     lambda t: keycam(t, [(S("racket"), 1.8, 330, 800), (E("racket"), 2.15, 330, 780)]), trans="whipL")
shot("B", E("racket") + 0.05, S("greed") - 0.05, draw_title, lambda t: (1.0 + 0.02 * math.sin(t * 40), W / 2, H / 2), trans="burn", cap_y=None)
shot("C1", S("greed") - 0.05, S("greed") + 1.85, draw_C1,
     lambda t: keycam(t, [(S("greed"), 1.45, 540, 900), (S("greed") + 1.85, 1.55, 540, 880)]), trans="burn", receipt=True)
shot("C2", S("greed") + 1.85, S("ticket") - 0.1, draw_C2,
     lambda t: keycam(t, [(S("greed") + 1.85, 1.0, W / 2, H / 2), (S("ticket"), 1.05, W / 2, H / 2)]), receipt=True)
shot("D1", S("ticket") - 0.1, S("ticket") + 1.7, draw_vault,
     lambda t: keycam(t, [(S("ticket") - 0.1, 1.35, 300, 1150), (S("ticket") + 1.7, 1.3, 600, 900)]), trans="whipR", receipt=True)
shot("D2", S("ticket") + 1.7, S("blockbuster") - 0.05, draw_vault,
     lambda t: keycam(t, [(S("ticket") + 1.7, 1.25, 700, 1000), (S("blockbuster"), 1.45, 740, 1040)]), receipt=True)
shot("E", S("blockbuster") - 0.05, S("fn_half") - 0.15, draw_board,
     lambda t: keycam(t, [(S("blockbuster"), 1.0, W / 2, H / 2), (S("fn_half"), 1.12, W / 2, 1100)]), trans="whipU", receipt=True)
shot("F1", S("fn_half") - 0.15, S("fn_half") + 0.9, draw_F1,
     lambda t: keycam(t, [(S("fn_half") - 0.15, 1.25, 540, 1350), (S("fn_half") + 0.9, 1.4, 540, 1420)]), trans="whipL", receipt=True)
shot("F2", S("fn_half") + 0.9, S("crumbs") - 0.05, draw_F2,
     lambda t: keycam(t, [(S("fn_half") + 0.9, 1.0, W / 2, H / 2), (S("crumbs"), 1.04, W / 2, H / 2)]), receipt=True)
shot("G1", S("crumbs") - 0.05, S("crumbs") + 1.0, draw_G,
     lambda t: keycam(t, [(S("crumbs"), 1.0, W / 2, H / 2), (S("crumbs") + 1.0, 1.04, W / 2, H / 2)]), trans="whipR", receipt=True)
shot("G2", S("crumbs") + 1.0, S("counter") - 0.2, draw_G,
     lambda t: keycam(t, [(S("crumbs") + 1.0, 1.5, 540, 820), (S("counter"), 1.85, 540, 760)]), receipt=True)
shot("H1", S("counter") - 0.2, S("counter") + 1.6, draw_H1,
     lambda t: keycam(t, [(S("counter") - 0.2, 1.25, W / 2, 560), (S("counter") + 1.4, 1.0, W / 2, H / 2)]), trans="iris", receipt=True)
shot("H2", S("counter") + 1.6, S("soda") - 0.25, draw_H2,
     lambda t: keycam(t, [(S("counter") + 1.6, 1.5, 800, 950), (S("soda"), 1.62, 810, 940)]), receipt=True)
shot("H3", S("soda") - 0.25, S("soda") + 1.3, draw_H3,
     lambda t: keycam(t, [(S("soda") - 0.25, 1.0, W / 2, H / 2), (S("soda") + 1.3, 1.08, 600, 960)]), trans="whipL", receipt=True)
shot("H4", S("soda") + 1.3, S("twenty") - 0.1, draw_H4,
     lambda t: keycam(t, [(S("soda") + 1.3, 1.45, 620, 930), (S("twenty"), 1.55, 620, 900)]), receipt=True)
shot("I", S("twenty") - 0.1, S("sneaky") - 0.15, draw_dollar,
     lambda t: keycam(t, [(S("twenty") - 0.1, 1.0, W / 2, H / 2), (S("sneaky"), 1.08, W / 2, 1000)]), trans="whipR", receipt=True, cap_y=1380)
shot("J1", S("sneaky") - 0.15, S("bait") - 0.05, draw_J1,
     lambda t: keycam(t, [(S("sneaky") - 0.15, 1.0, W / 2, H / 2), (S("sneaky") + 1.0, 1.0, W / 2, H / 2), (S("sneaky") + 1.4, 1.3, 535, 1000)]),
     trans="whipL", receipt=True, cap_y=1400)
shot("J2", S("bait") - 0.05, S("bait") + 2.5, draw_J2,
     lambda t: keycam(t, [(S("bait"), 1.45, 535, 900), (S("bait") + 2.5, 1.55, 535, 880)]), receipt=False, cap_y=1400)
shot("J3", S("bait") + 2.5, S("decoy") - 0.1, draw_J3,
     lambda t: keycam(t, [(S("bait") + 2.5, 1.0, W / 2, H / 2), (S("decoy"), 1.1, 640, 980)]), receipt=True, cap_y=1400)
shot("J4", S("decoy") - 0.1, S("invented") - 0.2, draw_J4,
     lambda t: keycam(t, [(S("decoy") - 0.1, 1.0, W / 2, H / 2), (S("invented"), 1.04, W / 2, H / 2)]), trans="flash", receipt=True, cap_y=1400)
shot("K", S("invented") - 0.2, S("fn_1982") - 0.1, draw_1953,
     lambda t: keycam(t, [(S("invented") - 0.2, 1.0, W / 2, H / 2), (S("fn_1982"), 1.15, W / 2, 900)]), trans="burn")
shot("L1", S("fn_1982") - 0.1, S("fn_1982") + 1.2, draw_L1,
     lambda t: keycam(t, [(S("fn_1982") - 0.1, 1.45, 340, 1380), (S("fn_1982") + 1.2, 1.55, 340, 1400)]), trans="flash", cap_y=560)
shot("L2", S("fn_1982") + 1.2, S("poll") - 0.2, draw_L2,
     lambda t: keycam(t, [(S("fn_1982") + 1.2, 1.0, W / 2, H / 2), (S("poll"), 1.04, W / 2, H / 2)]), cap_y=1060)
shot("M", S("poll") - 0.2, S("verdict") - 0.2, draw_poll,
     lambda t: keycam(t, [(S("poll") - 0.2, 1.0, W / 2, H / 2), (FREEZE[0], 1.04, W / 2, H / 2), (FREEZE[1], 1.12, W / 2, 1000)]),
     trans="whipR", cap_y=1400)
shot("N1", S("verdict") - 0.2, T_TOTAL - 1.35, draw_verdict,
     lambda t: keycam(t, [(S("verdict") - 0.2, 1.0, W / 2, H / 2), (T_TOTAL - 1.35, 1.06, W / 2, H / 2)]), trans="whipL", cap_y=1405)
shot("N2", T_TOTAL - 1.35, T_TOTAL, draw_verdict,
     lambda t: keycam(t, [(T_TOTAL - 1.35, 1.1, W / 2, 800), (T_TOTAL, 1.55, 720, 880)]), cap_y=1405)
shot("N3", T_TOTAL, T_TEAR, draw_verdict,
     lambda t: keycam(t, [(T_TOTAL, 1.0, W / 2, H / 2), (T_TEAR, 1.03, W / 2, H / 2)]), cap_y=1405)
shot("N4", T_TEAR, S("steep") + 1.3, draw_verdict,
     lambda t: keycam(t, [(T_TEAR, 1.03, W / 2, H / 2), (S("steep") + 1.3, 1.15, W / 2, 1250)]), cap_y=1405)
shot("N5", S("steep") + 1.3, S("promove") - 0.1, draw_lights,
     lambda t: keycam(t, [(S("steep") + 1.3, 1.25, W / 2, 600), (S("promove"), 1.0, W / 2, H / 2)]), trans="whipR")
shot("O", S("promove") - 0.1, S("racket_out") - 0.1, draw_promove,
     lambda t: keycam(t, [(S("promove") - 0.1, 1.0, W / 2, H / 2), (S("racket_out"), 1.05, W / 2, H / 2)]), trans="whipL")
shot("P", S("racket_out") - 0.1, S("next") - 0.1, draw_outro,
     lambda t: keycam(t, [(S("racket_out") - 0.1, 1.15, W / 2, 800), (S("next"), 1.0, W / 2, H / 2)]), trans="flash")
shot("Q", S("next") - 0.1, TOTAL, draw_next,
     lambda t: keycam(t, [(S("next") - 0.1, 1.0, W / 2, H / 2), (TOTAL, 1.08, W / 2, 1000)]), trans="whipR")

# ---- events (camera punches, shakes, flashes) + their sounds
shake(0.3, 22, 0.35); sfx("whoosh", 0.0, 0.45); sfx("stamp", 0.3, 0.5); sfx("pop", 0.42, 0.25)
punch(T_PRICE, 0.18); shake(T_PRICE, 18, 0.3); flash(T_PRICE, 170); sfx("kaching", T_PRICE + 0.1, 0.5)
punch(S("hook3") + 0.9, 0.06)
sfx("sting", shot_by("B")["a"] + 0.05, 0.7)
for k in range(3):
    sfx("pop", shot_by("B")["a"] + 0.05 + k * 0.32, 0.18)
sfx("printer", T_RECEIPT_IN + 0.1, 0.45)
for _, _, lid, off in RECEIPT:
    sfx("printer", S(lid) + off, 0.45)
punch(S("greed") + 1.85, 0.08); sfx("whoosh", S("greed") + 1.85, 0.2)
for i in range(3):
    sfx("squeak", S("greed") + 2.0 + i * 0.3, 0.22)
shake(S("ticket") + 1.75, 14, 0.3); sfx("pop", S("ticket") + 1.75, 0.45)
sfx("slide_up", shot_by("E")["a"] + 0.05, 0.4); punch(shot_by("E")["a"] + 0.1, 0.08)
sfx("boing", shot_by("F1")["a"] + 0.4, 0.35); shake(shot_by("F1")["a"] + 0.4, 10, 0.25)
sfx("pop", shot_by("F2")["a"], 0.35)
sfx("iris", shot_by("G2")["b"] - 0.35, 0.45); sfx("iris", shot_by("H1")["a"], 0.3)
punch(S("counter") + 2.0, 0.1); sfx("pop", S("counter") + 2.0, 0.3)
sfx("whoosh", S("soda") - 0.3, 0.22)
sfx("whoosh", shot_by("I")["a"], 0.25); sfx("tear", S("twenty") + 2.0, 0.35); shake(S("twenty") + 2.0, 12, 0.25)
for i in range(3):
    sfx("pop", shot_by("J1")["a"] + i * 0.18 + 0.25, 0.2)
punch(S("sneaky") + 1.1, 0.08); sfx("boing", S("sneaky") + 1.1, 0.22)
sfx("slide_down", S("bait") + 0.9, 0.22); sfx("boing", S("bait") + 1.3, 0.2)
sfx("slide_up", S("bait") + 2.6, 0.2); sfx("kaching", S("bait") + 3.1, 0.2)
sfx("stamp", S("decoy") - 0.12, 0.35); shake(S("decoy") - 0.05, 16, 0.3)
sfx("pop", shot_by("L1")["a"], 0.5); punch(shot_by("L1")["a"], 0.08)
sfx("slide_down", S("fn_1982") + 0.5, 0.25)
for i in range(3):
    sfx("pop", S("poll") + i * 0.35, 0.15)
flash(FREEZE[0], 120, 0.08); sfx("iris", FREEZE[0], 0.2)
sfx("whoosh", S("verdict") - 0.1, 0.35)
sfx("drumroll", T_TOTAL - 1.35, 0.7)
shake(T_TOTAL - 1.0, 6, 1.0)
punch(T_TOTAL, 0.12); flash(T_TOTAL, 160); sfx("kaching", T_TOTAL, 0.8)
punch(T_STAMP + 0.08, 0.2); shake(T_STAMP + 0.08, 40, 0.5); flash(T_STAMP + 0.08, 140, 0.08); sfx("stamp", T_STAMP, 1.0)
sfx("honk", T_FLAT, 0.6)
sfx("tear", T_TEAR, 0.7)
sfx("kaching", shot_by("N5")["a"] + 0.1, 0.3)
for i in range(4):
    sfx("squeak", shot_by("O")["a"] + i * 0.25, 0.15)
sfx("pop", shot_by("O")["a"] + 0.6, 0.25)
sfx("sting", S("racket_out") - 0.05, 0.25); sfx("boing", shot_by("P")["a"] + 0.45, 0.3)
sfx("pop", S("next") - 0.3, 0.3)
sfx("iris", TOTAL - 0.9, 0.5)
for s_ in SHOTS:
    if s_["trans"].startswith("whip"):
        sfx("whoosh", s_["a"] - 0.12, 0.28)
    if s_["trans"] == "burn":
        sfx("slide_up", s_["a"] - 0.05, 0.08)

WHIP = 0.13


def cam_for(t):
    sh = next((s for s in SHOTS if s["a"] <= t < s["b"]), SHOTS[-1])
    z, cx, cy = sh["cam"](t)
    # punches
    for t0, amt in PUNCHES:
        dt = t - t0
        if 0 <= dt < 0.8:
            z *= 1 + amt * min(1, dt / 0.04) * math.exp(-dt * 7)
    # whip transitions: slide out at the end of the previous shot / in at the start of this one
    ox = oy = 0.0
    nxt = next((s for s in SHOTS if s["a"] >= sh["b"] - 1e-6), None)
    if nxt and nxt["trans"].startswith("whip") and t > sh["b"] - WHIP:
        k = ease_in(prog(t, sh["b"] - WHIP, sh["b"]))
        d = {"whipR": (-1, 0), "whipL": (1, 0), "whipU": (0, 1)}[nxt["trans"]]
        ox, oy = d[0] * 260 * k, d[1] * 420 * k
        z *= 1 + 0.25 * k
    if sh["trans"].startswith("whip") and t < sh["a"] + WHIP:
        k = 1 - ease_out(prog(t, sh["a"], sh["a"] + WHIP))
        d = {"whipR": (1, 0), "whipL": (-1, 0), "whipU": (0, -1)}[sh["trans"]]
        ox, oy = d[0] * 260 * k, d[1] * 420 * k
        z *= 1 + 0.25 * k
    # shakes
    sx = sy = rot = 0.0
    for t0, amp, dur in SHAKES:
        dt = t - t0
        if 0 <= dt < dur:
            a = amp * (1 - dt / dur) ** 2
            r = np.random.default_rng(int(t * 240) + int(t0 * 100))
            sx += r.uniform(-a, a); sy += r.uniform(-a, a); rot += r.uniform(-a, a) * 0.04
    # 6% overscan + clamp so the camera never shows outside the drawn world
    zr = z * 1.06
    cx = cx + ox / zr + sx / zr
    cy = cy + oy / zr + sy / zr
    hw, hh = W / (2 * zr), H / (2 * zr)
    cx = min(max(cx, hw), W - hw)
    cy = min(max(cy, hh), H - hh)
    return sh, zr, cx, cy, rot


def whip_strength(t):
    for s in SHOTS:
        if s["trans"].startswith("whip") and abs(t - s["a"]) < WHIP:
            return 1 - abs(t - s["a"]) / WHIP, s["trans"]
    return 0.0, None


# ------------------------------------------------------------------ kinetic captions (active-word highlight)
def draw_captions(c, t, y):
    if y is None:
        return
    ch = next((ch for ch in CAPS if ch["a"] <= t < ch["b"]), None)
    if ch is None:
        return
    words = ch["words"]
    lens = [len(w) + 1 for w, _ in words]
    tot = sum(lens)
    k = (t - ch["a"]) / max(1e-6, ch["b"] - ch["a"])
    acc, active = 0, len(words) - 1
    for i, L in enumerate(lens):
        acc += L
        if k * tot < acc:
            active = i
            break
    size = 76
    font = skia.Font(art.TF["anton"], size)
    space = font.measureText(" ")
    widths = [font.measureText(w) * (1.12 if i == active else 1.0) for i, (w, _) in enumerate(words)]
    # wrap to <= 900 px
    lines, cur, cw = [], [], 0
    for i, wd in enumerate(widths):
        if cur and cw + space + wd > 900:
            lines.append((cur, cw)); cur, cw = [], 0
        cur.append(i); cw += (space if len(cur) > 1 else 0) + wd
    if cur:
        lines.append((cur, cw))
    pop = ease_out_back(prog(t, ch["a"], ch["a"] + 0.14))
    tilt = (-2.5 if ch["ci"] % 2 else 2.5) * (1 - prog(t, ch["a"], ch["a"] + 0.2))
    c.save(); c.translate(W / 2, y); c.rotate(tilt); c.scale(0.8 + 0.2 * pop, 0.8 + 0.2 * pop)
    y0 = -(len(lines) - 1) * size * 0.55
    for li, (idxs, lw) in enumerate(lines):
        x = -lw / 2
        yy = y0 + li * size * 1.12
        for i in idxs:
            w, money = words[i]
            sc = 1.12 if i == active else 1.0
            c.save(); c.translate(x, yy + (-6 if i == active else 0)); c.scale(sc, sc)
            c.drawString(w, 0, 0, font, skia.Paint(AntiAlias=True, Color=hexc(INK), Style=skia.Paint.kStroke_Style, StrokeWidth=15,
                                                   StrokeJoin=skia.Paint.kRound_Join))
            col = MONEY if money else (WHITE if i <= active else "#c9c9c9")
            c.drawString(w, 0, 0, font, skia.Paint(AntiAlias=True, Color=hexc(col)))
            c.restore()
            x += widths[i] + space
    c.restore()


# ------------------------------------------------------------------ frame renderer
def iris(c, r, cy=H / 2 - 100):
    p = skia.Path(); p.addRect(skia.Rect.MakeWH(W, H)); p.addCircle(W / 2, cy, max(0.0, r))
    p.setFillType(skia.PathFillType.kEvenOdd)
    c.drawPath(p, fill("#050505"))


VIG = art.vignette_paint()
RECEIPT_CENTER_SHOTS = {"N1", "N2", "N3", "N4", "N5"}


def render_frame(arr, t):
    s = skia.Surface(arr); c = s.getCanvas(); c.clear(hexc("#000000"))
    frozen = FREEZE[0] <= t < FREEZE[1]
    if frozen:
        t = FREEZE[0]
    tq = math.floor(t * 12) / 12.0
    q = int(t * 12)
    rnd = np.random.default_rng(q * 7919 + 13)
    sh, z, cx, cy, rot = cam_for(t)
    c.save(); c.translate(rnd.uniform(-1.5, 1.5), rnd.uniform(-1.1, 1.1))  # gate weave (on twos)
    ws, wt = whip_strength(t)
    if ws > 0.05:
        sxg, syg = (2, ws * 60) if wt == "whipU" else (ws * 60, 2)
        c.saveLayer(None, skia.Paint(ImageFilter=skia.ImageFilters.Blur(sxg, syg)))
    with Cam(c, z, cx, cy, rot):
        sh["draw"](c, t, tq)
    if ws > 0.05:
        c.restore()
    if sh["receipt"]:
        draw_receipt(c, t)
    c.restore()
    # opening question title (search keyword on screen in the first seconds)
    if 0.25 <= t < S("hook3") - 0.05:
        k = ease_out_back(prog(t, 0.25, 0.55))
        c.save(); c.translate(W / 2, 330); c.scale(k, k); c.rotate(math.sin(t * 3) * 1.2)
        c.drawRoundRect(skia.Rect.MakeLTRB(-470, -170, 470, 150), 26, 26, fill(INK, 230))
        c.drawRoundRect(skia.Rect.MakeLTRB(-470, -170, 470, 150), 26, 26, stroke(WHITE, 6))
        text(c, "WHY IS MOVIE", 0, -80, 82, "bungee", WHITE)
        text(c, "POPCORN SO", 0, 10, 82, "bungee", WHITE)
        text(c, "EXPENSIVE?", 0, 104, 92, "bungee", MONEY)
        c.restore()
    draw_captions(c, t, sh["cap_y"])
    # transitions / overlays
    if ws > 0:
        fx.speed_lines(c, t, radial=False, n=46, strength=ws, direction=0.0 if wt != "whipU" else math.pi / 2)
    if sh["trans"] == "iris" and t < sh["a"] + 0.35:
        iris(c, lerp(0, 1400, prog(t, sh["a"], sh["a"] + 0.35)))
    nxt = next((s_ for s_ in SHOTS if s_["a"] >= sh["b"] - 1e-6), None)
    if nxt and nxt["trans"] == "iris" and t > sh["b"] - 0.35:
        iris(c, lerp(1400, 0, prog(t, sh["b"] - 0.35, sh["b"])))
    if sh["name"] == "Q" and t > TOTAL - 0.9:
        iris(c, lerp(1400, 0, prog(t, TOTAL - 0.9, TOTAL - 0.45)))
    if sh["trans"] in ("burn", "flash") and t - sh["a"] < 0.14:
        c.drawRect(skia.Rect.MakeWH(W, H), fill("#ffffff", int(210 * (1 - (t - sh["a"]) / 0.14))))
    if sh["trans"] == "burn":
        fx.light_leak(c, t, sh["a"] - 0.05, life=0.5)
    for t0, a, dur in FLASHES:
        if 0 <= t - t0 < dur:
            c.drawRect(skia.Rect.MakeWH(W, H), fill("#ffffff", int(a * (1 - (t - t0) / dur))))
    if t < 1 / 12:
        c.drawRect(skia.Rect.MakeWH(W, H), fill("#ffffff", 170))
    if S("decoy") + 1.2 <= t < S("decoy") + 1.45:
        c.drawCircle(940, 180, 34, fill("#f5f5f5", 220))
    if frozen:
        text(c, "II", 980, 230, 70, "bungee", WHITE, outline=INK, ow=8)
    fl = rnd.uniform(-1, 1)
    c.drawRect(skia.Rect.MakeWH(W, H), fill("#ffffff" if fl > 0 else "#000000", int(abs(fl) * 14)))
    art.film_frame_fx(c, q, rnd, strength=2.4 if sh["name"] == "K" else 1.0)
    c.drawRect(skia.Rect.MakeWH(W, H), VIG)
    if sh["name"] == "K":
        c.drawRect(skia.Rect.MakeWH(W, H), art.vignette_paint())


def main():
    if len(sys.argv) > 2 and sys.argv[1] == "--stills":
        from PIL import Image
        os.makedirs(os.path.join(ROOT, "out", "previews"), exist_ok=True)
        for ts in sys.argv[2].split(","):
            t = float(ts); arr = np.zeros((H, W, 4), np.uint8); render_frame(arr, t)
            Image.fromarray(arr[..., :3]).save(os.path.join(ROOT, "out", "previews", f"v2_{t:05.2f}.png"))
        return
    nfr = int(TOTAL * FPS)
    outp = os.path.join(ROOT, "out", "frames_v2.mp4")
    ff = subprocess.Popen(["ffmpeg", "-y", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgba", "-s", f"{W}x{H}", "-r", str(FPS),
                           "-i", "-", "-vf", "format=yuv420p,noise=c0s=8:c0f=t", "-c:v", "libx264", "-preset", "slow", "-crf", "21",
                           "-maxrate", "14M", "-bufsize", "28M", "-pix_fmt", "yuv420p", outp], stdin=subprocess.PIPE)
    arr = np.zeros((H, W, 4), np.uint8)
    for f in range(nfr):
        render_frame(arr, f / FPS)
        ff.stdin.write(arr.tobytes())
        if f % 240 == 0:
            print(f"frame {f}/{nfr}", flush=True)
    ff.stdin.close(); ff.wait()
    print("wrote", outp)


if __name__ == "__main__":
    main()
