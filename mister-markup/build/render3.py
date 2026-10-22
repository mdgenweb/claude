"""Mister Markup — Racket #001, v3: story-driven, hands-on edit.

Story: Wally (your wallet) wants popcorn. Mister Markup walks him through where the money goes; Wally gets drained,
hooked by the decoy, flattened by the verdict and refilled by the pro-move. Every reveal is physically handled by a
character's hand (tag flip, slot rolls, tearing the dollar, pouring soda, stamping, light switch, phone, journal whack).

python3 build/render3.py               -> out/frames_v3.mp4
python3 build/render3.py --stills a,b  -> out/previews/v3_<t>.png
"""
import math, os, subprocess, sys
import numpy as np, skia

HERE = os.path.dirname(__file__)
sys.path.insert(0, HERE)
import art, fx, fx2, art_props as P
import render2 as R2
from art import W, H, INK, WHITE, MONEY, MONEY_D, G1, G2, G3, G4, G5, G6, fill, stroke, text, hexc
from render2 import (S, E, TL, TOTAL, FPS, CAPS, clamp, ease, ease_out, ease_in, ease_out_back, prog, lerp, keycam, Cam,
                     markup_mouth, fn_mouth, blink, bob, counter_back, counter_front, vault_bg, grid_bg, pipe_money,
                     receipt_shown, iris, BUCKETS, draw_pointer, L_BOARDROOM, chunk_at, speaking, draw_captions)
from script import RECEIPT, RECEIPT_TOTAL

ROOT = os.path.join(HERE, "..")

# ------------------------------------------------------------------ key moments (seconds)
T_LAND = 0.22
T_GRAB = 1.25
T_XRAY = (2.15, 3.9)
T_BUCK = S("hook1") + 3.55          # "...about a BUCK"
T_NINE = S("hook2") + 0.42          # "You pay NINE"
T_ARM = S("hook3") + 0.1
T_FOLLOW = S("greed") + 1.85
T_BOOTH = S("ticket") + 0.2
T_GAUGE = S("ticket") + 2.6
T_VAC = S("blockbuster") + 0.15
T_FN_IN = S("fn_half") - 0.15
T_LENS = S("fn_half") + 1.6
T_LIFT = S("counter") + 1.9
T_POUR = S("soda") + 0.35
T_SYRUP = S("soda") + 1.75
T_ICE = S("soda") + 2.6
T_RIP = S("twenty") + 2.35
T_REG = S("twenty") + 3.6
T_BAIT = S("bait") + 0.9
T_CATCH = S("bait") + 1.6
T_SWING = S("bait") + 2.7
T_DSTAMP = S("decoy") - 0.05
T_WHACK = S("fn_1982") + 0.35
FREEZE = (S("poll") + 1.7, S("poll") + 2.6)
T_TOTAL = E("verdict") + 1.25
T_STAMP = T_TOTAL + 0.35
T_FLAT = T_STAMP + 0.12
T_TEAR = S("steep") + 0.55
T_SWITCH = S("steep") + 1.85
T_PHONE = S("promove") + 1.2
T_REFILL = S("promove") + 3.0


def boil_of(tq):
    return int(tq * 12) % 3 + 1


# ------------------------------------------------------------------ Markup acting: blended poses per caption chunk
POSES = dict(R2.POSES)
POSES.update({
    "hook1": [("present", "sly"), ("point", "sly"), ("present", "proud")],
    "hook2": [("wide", "outrage")],
    "hook3": [("arm_around", "sly"), ("arm_around", "proud")],
    "racket": [("whisper", "whisper")],
    "counter": [("point", "sly"), ("hold_up", "proud"), ("hold_up", "sly")],
    "soda": [("pour", "sly"), ("pour", "proud"), ("pour", "sly")],
    "twenty": [("tear", "sly"), ("tear", "proud"), ("tear", "sly")],
    "steep": [("slam", "outrage"), ("switch", "proud")],
    "promove": [("phone", "sly"), ("phone", "proud"), ("present", "proud")],
    "racket_out": [("wave", "proud"), ("present", "proud")],
})


def _pose_for_chunk(ch):
    seq = POSES.get(ch["lid"]) if ch else None
    if not seq:
        return ("hips", "sly")
    return seq[ch["ci"] % len(seq)]


def markup_pose3(tq, **over):
    ch = chunk_at(tq)
    while ch is not None and ch["lid"] not in POSES:
        i = CAPS.index(ch); ch = CAPS[i - 1] if i > 0 else None
    arms, expr = _pose_for_chunk(ch)
    if "arms" in over:
        arms = over.pop("arms")
    if "expr" in over:
        expr = over.pop("expr")
    # blend from the previous chunk's arms for a smooth pose-to-pose move (classic in-betweens)
    prev_arms = None
    if ch is not None:
        i = CAPS.index(ch)
        if i > 0:
            pc = CAPS[i - 1]
            prev_arms = _pose_for_chunk(pc if pc["lid"] in POSES else None)[0]
    pose = {"arms": arms, "expr": expr, "mouth": markup_mouth(tq), "blink": blink(tq)}
    k = ease_out(prog(tq, ch["a"], ch["a"] + 0.2)) if ch else 1.0
    if prev_arms and prev_arms != arms and k < 1 and arms != "walk":
        A = art.markup_arm_targets(prev_arms); B = art.markup_arm_targets(arms)
        pose["armL"] = art.blend_arm(A[0], B[0], k); pose["armR"] = art.blend_arm(A[1], B[1], k)
        pose["stick"] = False
    # accent: little head tilt toward the camera on the first beat of each phrase + brow raise on money words
    pose["tilt"] = math.sin(tq * 2.3) * 3 + (6 * (1 - k) if ch else 0)
    if ch and any(m for _, m in ch["words"]):
        pose["brow"] = 8
    pose["look"] = (1, 0) if arms in ("point", "present", "switch", "slam") else ((0, -1) if arms in ("wave", "cheer") else (0, 0))
    pose.update(over)
    return pose


def markup(c, x, y, s, tq, pose=None, **kw):
    dy, sq = bob(tq, 9 * s)
    pose = dict(pose if pose is not None else markup_pose3(tq))
    pose.setdefault("squash", sq)
    fx2.contact_shadow(c, x, y + 6, 300 * s, alpha=90)
    art.draw_markup(c, x, y + dy, s, pose, t=tq, boil=boil_of(tq), **kw)


def wally(c, x, y, s, tq, **kw):
    fx2.contact_shadow(c, x, y + 4, 240 * s, alpha=80)
    art.draw_wally(c, x, y, s, t=tq, boil=boil_of(tq), **kw)


def footnote(c, x, y, s, tq, **kw):
    fx2.contact_shadow(c, x, y + 4, 220 * s, alpha=80)
    kw.setdefault("mouth", fn_mouth(tq)); kw.setdefault("blink", blink(tq, 2.7))
    art.draw_footnote(c, x, y, s, t=tq, boil=boil_of(tq), **kw)


def wally_thick(t):
    th = 1.0
    th -= 0.22 * prog(t, T_BOOTH, T_BOOTH + 1.5)
    th -= 0.18 * prog(t, T_REG - 0.5, T_REG + 0.5)
    th -= 0.2 * prog(t, T_SWING, T_SWING + 1.0)
    th += 0.55 * prog(t, T_REFILL, T_REFILL + 0.6)
    return clamp(th, 0.2, 1.0)


# ------------------------------------------------------------------ shots
SHOTS, SHAKES, PUNCHES, FLASHES, SFX_CUES, WORDS = [], [], [], [], [], []


def shot(name, a, b, draw, cam, trans="cut", receipt=False, cap_y=1330):
    SHOTS.append(dict(name=name, a=a, b=b, draw=draw, cam=cam, trans=trans, receipt=receipt, cap_y=cap_y))


def shake(t0, amp=24, dur=0.4): SHAKES.append((t0, amp, dur))
def punch(t0, amt=0.12): PUNCHES.append((t0, amt))
def flash(t0, a=190, dur=0.12): FLASHES.append((t0, a, dur))
def sfx(name, t, g=0.5): SFX_CUES.append((name, t, g))
def word(t0, w, x, y, size=120, money=False, ang=-8, life=0.75, seed=1): WORDS.append((t0, w, x, y, size, money, ang, life, seed))


def shot_by(n):
    return next(s for s in SHOTS if s["name"] == n)


# ================================================================== DRAW FUNCTIONS (c, t, tq)

def tag_label(t):
    if t < T_BUCK - 0.6:
        return "$9.00"
    return None


def draw_s01(c, t, tq):
    """Cold open: tub slams down, Wally's eyes pop at $9, Markup's hand grabs the tag, X-ray, tag rolls to ~$1."""
    counter_back(c, t)
    counter_front(c)
    # Wally on the countertop, left
    pop = ease_out_back(prog(t, 0.32, 0.55)) * (1 - prog(t, 1.6, 2.0))
    wally(c, 230, 1190, 0.9, tq, thick=1.0, expr="shock" if t < 2.0 else "nervous", eye_pop=pop, arms="grab" if t < 2.0 else "down",
          look=(1, 0))
    # tub drops in with squash
    d = prog(t, 0.0, T_LAND)
    yy = 1205 - (1 - d * d) * 1400
    sq = 1.0
    if T_LAND <= t < T_LAND + 0.3:
        k = (t - T_LAND) / 0.3; sq = 1 - 0.22 * math.sin(k * math.pi) * (1 - k)
    xr = prog(t, *T_XRAY) if t < T_XRAY[1] + 0.25 else 0.0
    c.save(); c.translate(740, yy); c.scale(1 / sq ** 0.5, sq); c.translate(-740, -yy)
    if 0 < xr < 1 or (T_XRAY[0] <= t < T_XRAY[1] + 0.25):
        P.draw_tub_xray(c, 740, yy, 1.15, t=tq, reveal=prog(t, T_XRAY[0] + 0.15, T_XRAY[1] - 0.2))
    else:
        art.draw_popcorn(c, 740, yy, 1.15, t=tq, boil=boil_of(tq), face=True, mouth="flat", dance=0.2)
    c.restore()
    fx.kernels(c, 740, 860, t, T_LAND, T_LAND + 0.9, every=0.08, seed=2)
    fx.dust_puff(c, 740, 1200, t, T_LAND, seed=4)
    # the price tag: hangs from the rim; Markup's glove grabs it and the price slot-rolls down to ~$1
    tx, ty = 600, 880
    hand_in = ease_out(prog(t, T_GRAB - 0.35, T_GRAB))
    tug = math.sin(max(0, t - T_GRAB) * 9) * 6 * (1 - prog(t, T_GRAB, T_GRAB + 0.8))
    c.save(); c.translate(tx, ty + tug); c.rotate(-10 + math.sin(t * 4) * 3 * (1 - hand_in))
    c.drawRoundRect(skia.Rect.MakeLTRB(-150, -64, 150, 64), 14, 14, fill("#e3e1da")); c.drawRoundRect(skia.Rect.MakeLTRB(-150, -64, 150, 64), 14, 14, stroke(INK, 7))
    c.drawCircle(130, 0, 10, fill(G1))
    if t < T_BUCK:
        text(c, "$9.00", -6, 26, 76, "marker", MONEY, outline=MONEY_D, ow=3)
    else:
        fx2.slot_roll(c, -6, 0, ["$9.00", "$7.00", "$5.00", "$3.00", "~$1"], t, T_BUCK, dur=0.6, size=74, font="marker",
                      color=MONEY, outline=MONEY_D, box=False)
    c.restore()
    c.drawLine(tx + 140, ty, 740 - 150, 1205 - 300 * 1.15 + 40, stroke(INK, 4))
    if hand_in > 0:  # Markup's arm reaching in from the left edge
        hx = lerp(-200, tx - 170, hand_in); hy = ty + 10 + tug
        c.drawLine(-60, hy - 330, hx - 20, hy - 6, stroke(INK, 64)); c.drawLine(-60, hy - 330, hx - 20, hy - 6, stroke(G3, 50))
        art.draw_glove(c, hx, hy, -10, "fist", 1.25)


def draw_s02(c, t, tq):
    """Punch-in on Markup: forehead price rolls to $9.00, money bursts, Wally eye-pop again."""
    counter_back(c, t)
    pose = markup_pose3(tq)
    roll = t >= T_NINE
    markup(c, 330, 1650, 1.05, tq, pose, price=None)
    # forehead price slot-roll (drawn on top of the tag at Markup's forehead)
    fy = 1650 + bob(tq, 9)[0] - (755 + 232) * 1.05
    c.save(); c.translate(330, fy); c.rotate(-4)
    if roll:
        fx2.slot_roll(c, 0, 0, ["$1", "$3", "$5", "$7", "$9.00"], t, T_NINE, dur=0.45, size=64, font="marker", color=MONEY, outline=MONEY_D, box=False)
    c.restore()
    counter_front(c)
    wally(c, 800, 1190, 0.95, tq, thick=1.0, expr="shock", eye_pop=ease_out_back(prog(t, T_NINE + 0.05, T_NINE + 0.25)), arms="cheer" if roll else "down")
    if roll:
        fx.money_burst(c, 330, 640, t, T_NINE + 0.1, n=10, seed=21, speed=1250, scale=0.6)


def draw_s03(c, t, tq):
    """Arm around the innocent tub."""
    counter_back(c, t)
    markup(c, 600, 1650, 1.05, tq, markup_pose3(tq), price="$9.00")
    counter_front(c)
    art.draw_popcorn(c, 250, 1205, 1.1, t=tq, boil=boil_of(tq), face=True, mouth="grin", dance=0.5)
    fx2.sparkles(c, 250, 900, t, S("hook3") + 0.8, life=1.2, n=7, seed=3, radius=180)
    fx.sweat(c, 350, 960, t, 1.3)


def draw_s04(c, t, tq):
    """Whisper: Markup pulls Wally in close."""
    counter_back(c, t)
    markup(c, 360, 1650, 1.05, tq, markup_pose3(tq, lean=-6), price="$9.00")
    counter_front(c)
    lean = ease_out(prog(t, S("racket"), S("racket") + 0.4))
    wally(c, lerp(820, 640, lean), 1190, 0.95, tq, thick=1.0, expr="nervous", arms="shield", squash=1 - 0.08 * lean)
    fx2.zoom_lines(c, 420, 820, t, strength=0.5 * lean, seed=4)


def draw_title(c, t, tq):
    a = shot_by("S05")["a"]; lt = t - a
    c.drawRect(skia.Rect.MakeWH(W, H), fill("#0e0e0e"))
    cx, cy = W / 2, 820
    c.drawCircle(cx, cy, 300, stroke(G5, 8)); c.drawCircle(cx, cy, 250, stroke(G5, 4))
    c.drawLine(cx - 420, cy, cx + 420, cy, stroke(G4, 4)); c.drawLine(cx, cy - 420, cx, cy + 420, stroke(G4, 4))
    p = skia.Path(); p.moveTo(cx, cy)
    p.arcTo(skia.Rect.MakeLTRB(cx - 300, cy - 300, cx + 300, cy + 300), -90, (lt / 0.32 * 360) % 360, False); p.close()
    c.drawPath(p, fill(G3, 120))
    if lt < 0.85:
        text(c, str(max(1, 3 - int(lt / 0.3))), cx, cy + 90, 260, "deco", G6)
    else:
        k = fx2.pop_in(t, a + 0.85, 0.25)
        c.save(); c.translate(cx, cy); c.scale(k, k)
        text(c, "A FINE PRINT", 0, -40, 104, "deco", WHITE); text(c, "PICTURE", 0, 80, 120, "deco", WHITE)
        c.restore()
        fx2.typewriter(c, "MISTER MARKUP in", cx, 1290, t, a + 0.9, cps=40, size=50, font="slab", color=G5, align="center", cursor=False)
        fx2.typewriter(c, "RACKET #001: MOVIE POPCORN", cx, 1380, t, a + 1.0, cps=50, size=54, font="anton", color=MONEY, align="center", cursor=False)


def draw_s06(c, t, tq):
    """Follow the green: bills float away like footprints, Wally chases."""
    art.stage_live(c, t, sweep=math.sin(t * 0.8) * 140)
    markup(c, 420, 1600, 1.0, tq)
    if t >= T_FOLLOW:
        for i in range(8):
            k = t - T_FOLLOW - i * 0.12
            if k < 0:
                continue
            x = 520 + i * 90 + k * 260; y = 1300 - i * 40 - math.sin(k * 3 + i) * 30
            art.draw_bill(c, x, y, 0.7, ang=math.sin(k * 4 + i) * 30)
        run = prog(t, T_FOLLOW + 0.5, T_FOLLOW + 1.4)
        wally(c, lerp(760, 1200, ease_in(run)), 1640, 0.85, tq, thick=1.0, expr="happy", arms="cheer", walk=t * 3)
        if run > 0:
            fx2.afterimages(c, lambda cc, x, y, e: art.draw_wally(cc, x, y, 0.85, t=tq, arms="cheer"),
                            [(lerp(760, 1200, ease_in(max(0, run - d))), 1640, None) for d in (0.3, 0.2, 0.1, 0.0)])
    else:
        wally(c, 790, 1640, 0.85, tq, thick=1.0, expr="nervous", arms="down", look=(-1, 0))


def draw_s07(c, t, tq):
    """Ticket booth: Wally pays, money gets sucked in, he gets a ticket."""
    vault_bg(c, t, spin=30)
    a = shot_by("S07")["a"]
    k = prog(t, a, a + 0.6)
    wx = lerp(-150, 250, ease_out(k))
    holding_ticket = t > T_BOOTH + 1.0
    hold = (lambda cc: P.draw_ticket(cc, 10, -10, 0.8, ang=-25, t=tq)) if holding_ticket else (lambda cc: art.draw_bill(cc, 20, -30, 0.6, ang=-20))
    wally(c, wx, 1660, 0.95, tq, thick=wally_thick(t), expr="happy" if holding_ticket else "nervous", arms="hold", hold=hold,
          walk=t * 2.4 if k < 1 else None)
    for i in range(4):  # bills sucked into the booth window
        kk = ((t - T_BOOTH) * 1.6 + i / 4) % 1.0
        if t > T_BOOTH:
            art.draw_bill(c, lerp(330, 230, kk), lerp(1450, 1000, kk) - math.sin(kk * math.pi) * 200, 0.55 * (1 - 0.5 * kk), ang=kk * 400)
    pipe_money(c, t, n=6, speed=420)


def draw_s08(c, t, tq):
    """Down the pipe into the STUDIO vault; Markup's hand slaps the ~50% gauge on."""
    vault_bg(c, t, spin=80)
    pipe_money(c, t, n=10, speed=640)
    wally(c, 240, 1660, 0.85, tq, thick=wally_thick(t), expr="worried", arms="down")
    if t >= T_GAUGE - 0.35:
        hand = ease_out(prog(t, T_GAUGE - 0.35, T_GAUGE))
        back = ease_in(prog(t, T_GAUGE + 0.35, T_GAUGE + 0.7))
        gx, gy = 760, 1060
        if t >= T_GAUGE:
            k = fx2.pop_in(t, T_GAUGE, 0.25)
            c.save(); c.translate(gx, gy); c.scale(k, k)
            c.drawCircle(0, 0, 140, fill(INK, 240)); c.drawCircle(0, 0, 140, stroke(WHITE, 8))
            fx2.slot_roll(c, 0, 0, ["0%", "10%", "20%", "30%", "40%", "~50%"], t, T_GAUGE, dur=0.55, size=86, font="anton", color=MONEY, outline=INK, box=False)
            c.restore()
            fx.shockwave(c, gx, gy, t, T_GAUGE, r1=620)
        hx = lerp(1300, gx + 120, hand) + back * 500; hy = gy + 160
        c.drawLine(1300, hy + 120, hx + 30, hy + 10, stroke(INK, 64)); c.drawLine(1300, hy + 120, hx + 30, hy + 10, stroke(G3, 50))
        art.draw_glove(c, hx, hy, 200, "open", 1.3, flip=1)


def draw_s09(c, t, tq):
    """Blockbusters: the Fat Cats vacuum the money up."""
    c.drawImage(L_BOARDROOM, 0, 0)
    for i, x in enumerate((220, 540, 860)):
        laugh = abs(math.sin(tq * 10 + i)) * 18
        art.draw_fat_cat(c, x, 1390 - laugh, 1.0, t=tq, puff=((t - T_VAC) * 0.6 + i * 0.3) % 1.0)
    nx, ny = 540, 760
    for i in range(12):  # bills streaming into the nozzle
        k = ((t - T_VAC) * 1.8 + i / 12) % 1.0
        sx = 100 + (i * 173) % 880
        x = lerp(sx, nx, ease_in(k)); y = lerp(-80, ny + 20, ease_in(k))
        art.draw_bill(c, x, y, 0.7 * (1 - 0.6 * k), ang=k * 500 + i * 30)
    P.draw_vacuum_nozzle(c, nx, ny, 1.2, ang=0, t=t, hose_to=(540, 1250), suck=1.0)


def doc_content(cc):
    """Annual-report page (world coords) — used both on the card and inside the magnifier."""
    art.draw_card(cc, W / 2, 640, ["*Source: AMC & Cinemark", "2025 annual reports (10-K):", "U.S. film rent = ~51-57%", "of ticket sales"],
                  w=820, size=42)


def draw_s10(c, t, tq):
    """Footnote hops in with the 10-K; his magnifier blows up the key number."""
    vault_bg(c, t, spin=20)
    pipe_money(c, t, n=5, speed=300)
    a = shot_by("S10")["a"]
    k = prog(t, a, a + 0.45)
    dy, sx_, sy_ = fx2.squash_hop(t, a + 0.45, height=0, dur=0.3)
    fxp = lerp(1250, 600, ease_out(k)); fyp = 1760 - math.sin(k * math.pi) * 420
    holding = (lambda cc: P.draw_report(cc, 40, -70, 0.75, ang=-12, t=tq)) if t < T_LENS - 0.3 else None
    footnote(c, fxp, fyp, 1.25, tq, hold=holding, squash=sy_, glass=t < T_LENS)
    if t >= a + 0.45:
        fx.dust_puff(c, 600, 1760, t, a + 0.45, seed=8, spread=200)
    wally(c, 240, 1660, 0.85, tq, thick=wally_thick(t), expr="worried", arms="down", look=(1, -1))
    if t >= S("fn_half") + 0.6:
        kk = ease_out_back(prog(t, S("fn_half") + 0.6, S("fn_half") + 0.95))
        c.save(); c.translate(0, lerp(-500, 0, kk)); doc_content(c); c.restore()
    if t >= T_LENS:
        kk = ease_out_back(prog(t, T_LENS, T_LENS + 0.4))
        fx_, fy_ = 752, 802                     # "~51-57%" on the card
        gx, gy = fx_ + 0.5 * 315, fy_ + 0.866 * 315
        gx, gy = lerp(1250, gx, kk), lerp(1700, gy, kk)
        c.drawLine(fxp + 60, fyp - 300, gx, gy, stroke(INK, 34)); c.drawLine(fxp + 60, fyp - 300, gx, gy, stroke(G1, 22))
        cxl, cyl, _ = P.magnifier_lens_center(gx, gy, 1.3, -30, 110)
        P.draw_magnifier(c, gx, gy, 1.3, ang=-30, t=t, lens_r=110, content=doc_content, zoom=1.8, focus=(fx_, fy_))
        art.draw_glove(c, gx, gy, -120, "fist", 0.9)
        if t >= T_LENS + 0.45:
            fx2.sparkles(c, cxl, cyl, t, T_LENS + 0.45, life=0.7, n=6, seed=10, radius=190)


def draw_s11(c, t, tq):
    art.stage_live(c, t, sweep=lerp(0, 380, ease(prog(t, S("crumbs") + 1.4, S("crumbs") + 3.0))))
    roll = t < S("crumbs") + 1.0
    markup(c, 480, 1600, 1.0, tq, markup_pose3(tq, look=(0, -1) if roll else (1, 0)))
    wally(c, 860, 1640, 0.85, tq, thick=wally_thick(t), expr="worried", arms="down", look=(1, 0))


def draw_s12(c, t, tq):
    """Snack bar: Markup lifts the tub in his hand, 'COST ~$1' tag pops."""
    counter_back(c, t, glow=0.8)
    lifting = t >= T_LIFT - 0.3
    holdR = (lambda cc: art.draw_popcorn(cc, 0, 70, 0.72, t=tq, face=True, dance=0.3)) if lifting else None
    markup(c, 330, 1650, 1.05, tq, markup_pose3(tq, holdR=holdR) if lifting else markup_pose3(tq))
    counter_front(c)
    if not lifting:
        art.draw_popcorn(c, 800, 1205, 1.0, t=tq, boil=boil_of(tq), face=True, dance=0.6)
    if t >= T_LIFT:
        k = fx2.pop_in(t, T_LIFT, 0.3)
        c.save(); c.translate(760, 540); c.rotate(-8); c.scale(k, k)
        c.drawRoundRect(skia.Rect.MakeLTRB(-210, -75, 210, 65), 16, 16, fill("#e3e1da")); c.drawRoundRect(skia.Rect.MakeLTRB(-210, -75, 210, 65), 16, 16, stroke(INK, 7))
        text(c, "COST: ~$1", 0, 20, 76, "marker", MONEY, outline=MONEY_D, ow=3)
        c.restore()
        fx2.sparkles(c, 760, 540, t, T_LIFT, life=0.9, n=8, seed=12, radius=260)


def draw_s13(c, t, tq):
    """Soda demo: pour 5 parts water, 1 part syrup, drop ice."""
    counter_back(c, t, glow=0.6)
    def prop(cc):
        cc.scale(-1, 1)   # mirror: spout faces +x, toward the cup
        if t < T_SYRUP:
            tip = ease(prog(t, T_POUR - 0.25, T_POUR + 0.15)) * (1 - ease(prog(t, T_SYRUP - 0.35, T_SYRUP - 0.1)))
            P.draw_pitcher(cc, 0, 0, 0.9, ang=-40 * tip, t=tq, fill=0.8 - 0.45 * prog(t, T_POUR, T_SYRUP), pour_len=280,
                           pour=(tip > 0.6))
        else:
            P.draw_syrup_bottle(cc, -10, 0, 0.95, ang=-95 * ease(prog(t, T_SYRUP - 0.1, T_SYRUP + 0.2))
                                * (1 - ease(prog(t, T_SYRUP + 0.75, T_SYRUP + 0.95))), t=tq)
    markup(c, 300, 1650, 1.05, tq, markup_pose3(tq, arms="pour", holdR=prop, armR=((143, -832), -60, "fist", -60)))
    counter_front(c)
    cx = 700
    lvl = 0.62 * prog(t, T_POUR, T_SYRUP - 0.1) + 0.12 * prog(t, T_SYRUP, T_SYRUP + 0.6)
    # glass cup (cutaway) with liquid level marks
    cup = art.path_poly([(cx - 85, 1205), (cx + 85, 1205), (cx + 115, 870), (cx - 115, 870)])
    c.drawPath(cup, fill(WHITE, 90))
    c.save(); c.clipPath(cup, doAntiAlias=True)
    top = 1205 - 335 * lvl
    c.drawRect(skia.Rect.MakeLTRB(cx - 130, top, cx + 130, 1205), fill(G5, 200))
    sy = 1205 - 335 * 0.62
    if t >= T_SYRUP:
        c.drawRect(skia.Rect.MakeLTRB(cx - 130, top, cx + 130, sy), fill(G2, 230))
    fx.bubbles(c, cx - 70, cx + 70, top + 10, 1195, t, n=10)
    c.restore()
    c.drawPath(cup, stroke(INK, 7))
    if T_SYRUP + 0.15 < t < T_SYRUP + 0.75:  # syrup stream
        sp_ = skia.Path(); sp_.moveTo(578, 792); sp_.quadTo(668, 800, cx - 15, top)
        c.drawPath(sp_, stroke(INK, 14)); c.drawPath(sp_, stroke(G1, 8))
    for i in range(3):  # ice cubes drop in
        t0 = T_ICE + i * 0.22
        if t >= t0:
            k = ease_in(prog(t, t0, t0 + 0.25))
            P.draw_ice_cube(c, cx - 40 + i * 40, lerp(300, top + 30 + i * 18, k), 0.8, ang=i * 25 + k * 60, t=tq)
    if t >= T_POUR + 0.3:
        text(c, "5 PARTS WATER", 915, 1110, 38, "anton", WHITE, outline=INK, ow=9, alpha=int(255 * prog(t, T_POUR + 0.3, T_POUR + 0.5)))
    if t >= T_SYRUP + 0.2:
        text(c, "1 PART SYRUP", 915, 1170, 38, "anton", WHITE, outline=INK, ow=9, alpha=int(255 * prog(t, T_SYRUP + 0.2, T_SYRUP + 0.4)))


def draw_s14(c, t, tq):
    """The snack dollar: Markup tears off the 20% food part; the 80% goes into the register."""
    grid_bg(c, t)
    torn = t >= T_RIP
    drop = ease_in(prog(t, T_RIP, T_RIP + 0.9))
    feed = ease_in(prog(t, T_REG - 0.4, T_REG))

    def bill_in_hands(cc):  # drawn relative to the right hand (Markup local coords)
        pass

    pose = markup_pose3(tq)
    markup(c, 300, 1700, 1.0, tq, pose)
    # giant bill held between both hands at chest height (Markup at x=300,y=1700,s=1 -> hands at y~1060)
    bx, by = 300, 1040
    if feed < 1:
        c.save(); c.translate(bx + feed * 420, by - feed * 160); c.scale(3.2 * (1 - 0.7 * feed), 3.2 * (1 - 0.7 * feed))
        if torn:
            c.save(); c.clipRect(skia.Rect.MakeLTRB(-36, -40, 70, 40)); art.draw_bill(c, 0, 0, 1.0); c.restore()
            c.drawLine(-36, -32, -36, 32, stroke(INK, 2))
        else:
            art.draw_bill(c, 0, 0, 1.0)
        c.restore()
    if torn:
        c.save(); c.translate(bx - 30 * 3.2 - drop * 120, by + drop * 560); c.rotate(-40 * drop); c.scale(3.2, 3.2)
        c.save(); c.clipRect(skia.Rect.MakeLTRB(-62, -40, -36, 40)); art.draw_bill(c, 0, 0, 1.0)
        c.drawRect(skia.Rect.MakeLTRB(-62, -32, 62, 32), fill(G3, 200)); c.restore()
        c.restore()
        text(c, "FOOD ~20¢", 150 - drop * 60, 1250 + drop * 330, 54, "anton", WHITE, outline=INK, ow=10)
    P.draw_register(c, 820, 1520, 1.0, t=tq, drawer=ease_out(prog(t, T_REG, T_REG + 0.3)), display="$0.80" if t >= T_REG else "$0.00")
    if t >= T_REG:
        text(c, "THEATER KEEPS ~80¢", 700, 1000, 60, "anton", MONEY_D, outline=WHITE, ow=8)
        text(c, "(before staff & rent)", 700, 1052, 36, "mono", G2)


DECOY_X = {0: 205, 1: 535, 2: 865}


def draw_buckets3(c, t, tq, focus=None, enter=None, labels=True, faces=False, freeze=False):
    for i, (x, s, p, nm) in enumerate(BUCKETS):
        yoff = 0.0
        if enter is not None:
            k = ease_out_back(prog(t, enter + i * 0.18, enter + i * 0.18 + 0.35)); yoff = (1 - k) * -1400
        bounce = abs(math.sin(tq * 7)) * 30 if (focus == i and not freeze) else 0.0
        art.draw_popcorn(c, x, 1120 - bounce + yoff, s, t=tq, boil=boil_of(tq), label=False, seed=i + 2, face=(focus == i or faces), mouth="grin")
        if labels:
            text(c, p, x, 1205 + yoff, 64, "marker", MONEY, outline=MONEY_D, ow=3)
    if labels:
        text(c, "example prices", W / 2, 1262, 34, "mono", G2)


def hooked_wally_pos(t):
    """Wally walks toward the medium, gets hooked, swung over to the large."""
    if t < T_CATCH:
        k = prog(t, S("bait"), T_CATCH)
        return lerp(-120, 470, ease_out(k)), 1520, False
    if t < T_SWING:
        lift = ease_out(prog(t, T_CATCH, T_CATCH + 0.4))
        return 470 + math.sin((t - T_CATCH) * 7) * 20, lerp(1520, 1240, lift), True
    k = ease(prog(t, T_SWING, T_SWING + 0.7))
    return lerp(470, 860, k), lerp(1240, 1420, k) - math.sin(k * math.pi) * 200, k < 1


def draw_s15(c, t, tq):
    grid_bg(c, t)
    focus = 1 if t >= S("sneaky") + 1.1 else None
    draw_buckets3(c, t, tq, focus=focus, enter=shot_by("S15")["a"])
    if focus == 1:
        fx2.zoom_lines(c, 535, 980, t, strength=0.7, seed=9, inner=330)
    draw_pointer(c, *(DECOY_X[1] - 35, 880) if focus == 1 else (205, 900), t)


def draw_s16_17(c, t, tq):
    grid_bg(c, t)
    focus = 2 if t >= T_SWING else 1
    draw_buckets3(c, t, tq, focus=focus, labels=t >= T_SWING - 0.2)
    # fishing line + hook baited with the medium
    if t >= T_BAIT:
        k = ease_out_back(prog(t, T_BAIT, T_BAIT + 0.4))
        wx, wy, hooked = hooked_wally_pos(t)
        hx = wx if hooked else 535
        hy = (wy - 210) if hooked else lerp(-100, 760, k)
        P.draw_hook(c, hx, hy, 1.1, ang=math.sin(t * 5) * 8, t=tq, line_to=(535 if not hooked else hx, -20))
        if t < T_CATCH + 0.2:
            fx2.action_word(c, 535, 640, "BAIT!", t, T_BAIT + 0.25, life=1.0, size=110, seed=5)
    wx, wy, hooked = hooked_wally_pos(t)
    if t >= S("bait"):
        wally(c, wx, wy, 0.8, tq, thick=wally_thick(t), expr="worried" if hooked else "happy", arms="up" if hooked else "grab",
              walk=t * 2.5 if not hooked and t < T_CATCH else None, eye_pop=0.6 if (T_CATCH <= t < T_CATCH + 0.6) else 0.0)
    if t >= T_SWING + 0.7:
        fx2.action_word(c, 865, 640, "STEAL!", t, T_SWING + 0.7, life=1.4, size=110, money=True, seed=6)
        fx.money_burst(c, 860, 1300, t, T_SWING + 0.75, n=8, seed=61, speed=900, scale=0.55)


def draw_s18(c, t, tq):
    """THE DECOY EFFECT stamped by Markup's rubber-stamp hand."""
    draw_s16_17(c, t, tq)
    if t >= T_DSTAMP - 0.25:
        k = prog(t, T_DSTAMP - 0.25, T_DSTAMP)
        up = ease_in(prog(t, T_DSTAMP + 0.25, T_DSTAMP + 0.6))
        sy = lerp(-200, 330, ease_in(k)) - up * 600
        if t >= T_DSTAMP:
            kk = fx2.pop_in(t, T_DSTAMP, 0.2)
            c.save(); c.translate(W / 2, 470); c.scale(kk, kk); c.rotate(-3)
            text(c, "THE DECOY EFFECT", 0, 0, 92, "deco", INK)
            c.restore()
        c.save(); c.translate(*fx2.impact_text_shake(t, T_DSTAMP, amp=10, dur=0.25))
        P.draw_rubber_stamp(c, W / 2, sy, 1.4, ang=0, t=tq)
        c.drawLine(W / 2 + 40, sy - 60, W / 2 + 200, -100, stroke(INK, 62)); c.drawLine(W / 2 + 40, sy - 60, W / 2 + 200, -100, stroke(G3, 50))
        art.draw_glove(c, W / 2 + 20, sy - 70, -60, "fist", 1.3)
        c.restore()


def draw_s19(c, t, tq):
    art.stage_live(c, t, sweep=0)
    c.drawRect(skia.Rect.MakeWH(W, H), fill("#000000", 80))
    yb = bob(tq, 9)[0]
    markup(c, 540, 1600, 1.0, tq, markup_pose3(tq, arms="hold", expr="proud",
                                               holdR=lambda cc: art.draw_popcorn(cc, -90, 60, 0.6, t=tq, label=False, seed=3)))
    for i, x in enumerate((140, 400, 680, 940)):
        clap = abs(math.sin(tq * 12 + i)) * 14
        c.drawCircle(x, 1830 - clap, 90, fill("#050505")); c.drawRect(skia.Rect.MakeLTRB(x - 120, 1880 - clap, x + 120, 2000), fill("#050505"))
    text(c, "1953", W / 2, 300, 150, "deco", WHITE, outline=INK, ow=10)
    text(c, "(as he remembers it)", W / 2, 372, 44, "mono", G6)


def draw_s20_21(c, t, tq):
    """Footnote whacks Markup with the 1982 journal; dizzy stars."""
    grid_bg(c, t)
    swing = 0.0
    if T_WHACK - 0.25 <= t < T_WHACK + 0.2:
        swing = lerp(-70, 60, ease_in(prog(t, T_WHACK - 0.25, T_WHACK)))
    elif t >= T_WHACK + 0.2:
        swing = lerp(60, -10, ease(prog(t, T_WHACK + 0.2, T_WHACK + 0.6)))
    hit = t >= T_WHACK
    dazed = hit and t < T_WHACK + 3.5
    sq = 1.0
    if hit and t < T_WHACK + 0.35:
        sq = 1 - 0.25 * math.sin(prog(t, T_WHACK, T_WHACK + 0.35) * math.pi)
    markup(c, 700, 1650, 0.8, tq, markup_pose3(tq, arms="shrug", expr="guilty" if hit else "proud",
                                               mouth="guilty" if hit else markup_mouth(tq), string="knot" if dazed else "up",
                                               squash=sq, look=(-1, -1) if dazed else (0, 0)))
    if dazed:
        for i in range(4):
            a = t * 5 + i * math.pi / 2
            fx.star(c, 700 + math.cos(a) * 150, 1650 - 0.8 * 1110 - 40 + math.sin(a) * 40, 22)
    footnote(c, 330, 1700, 1.35, tq,
             hold=lambda cc: P.draw_journal(cc, 30, -110, 0.8, ang=10, t=tq), swing=swing)
    if hit:
        fx2.action_word(c, 620, 820, "WHACK!", t, T_WHACK + 0.02, life=0.8, size=120, seed=7)
    if t >= S("fn_1982") + 1.5:
        art.draw_card(c, W / 2, 300, ["*Huber, Payne & Puto (1982)", "Journal of Consumer Research"], w=840, size=42,
                      scale=fx2.pop_in(t, S("fn_1982") + 1.5, 0.3))


def draw_s22(c, t, tq):
    freeze = FREEZE[0] <= t < FREEZE[1]
    grid_bg(c, t)
    draw_buckets3(c, t, tq, faces=True, freeze=freeze)
    for i, (x, s, p, nm) in enumerate(BUCKETS):
        k = fx2.pop_in(t, S("poll") + i * 0.35, 0.3)
        c.save(); c.translate(x, 740); c.scale(k, k)
        text(c, nm + "?", 0, 0, 50, "bungee", WHITE, outline=INK, ow=10)
        c.restore()
    if t > S("poll") + 1.4:
        k = fx2.pop_in(t, S("poll") + 1.4, 0.3)
        c.save(); c.translate(W / 2, 400); c.scale(k, k)
        c.drawRoundRect(skia.Rect.MakeLTRB(-400, -70, 400, 70), 24, 24, fill(INK, 235))
        text(c, "BE HONEST:", 0, -5, 56, "anton", WHITE); text(c, "COMMENT BELOW", 0, 55, 56, "anton", MONEY)
        c.restore()
        P.draw_comment_bubble(c, 880, 1580, 1.2, t=t)
        # Markup's pointing glove aims at the comment button (bottom-right, where the app's comment icon sits)
        k2 = ease_out(prog(t, S("poll") + 1.6, S("poll") + 1.9))
        gx, gy = lerp(1300, 760, k2), lerp(1300, 1480, k2)
        art.draw_glove(c, gx, gy, 45, "point", 1.6)


def draw_receipt3(c, t, center=False):
    R2.draw_receipt(c, t, center=center)


def draw_s23_24(c, t, tq):
    """Drumroll, total reveal, Markup's hand slams the STEEP stamp, screen cracks, Wally goes flat."""
    art.stage_live(c, t, sweep=math.sin(t * 2.2) * 260 if t < T_TOTAL else 0)
    c.drawRect(skia.Rect.MakeWH(W, H), fill("#000000", 70))
    flat = ease(prog(t, T_FLAT, T_FLAT + 0.15))
    shiver = math.sin(t * 60) * 4 if T_TOTAL - 1.35 < t < T_FLAT else 0
    wally(c, 540 + shiver, 1720, 1.1, tq, thick=wally_thick(t), flat=flat, expr="x" if flat > 0.5 else "shock",
          arms="shield" if flat < 0.5 else None, hold=None)
    fx.dust_puff(c, 540, 1720, t, T_FLAT, seed=17, spread=320)
    draw_receipt3(c, t, center=True)
    if t >= T_TOTAL:
        fx.money_burst(c, 120, 1150, t, T_TOTAL, n=9, seed=51, speed=1100)
        fx.money_burst(c, 960, 1150, t, T_TOTAL, n=9, seed=52, speed=1100)
    if t >= T_STAMP - 0.3:
        k = ease_in(prog(t, T_STAMP - 0.3, T_STAMP))
        up = ease_in(prog(t, T_STAMP + 0.3, T_STAMP + 0.7))
        sy = lerp(-150, 1000, k) - up * 1300
        if t >= T_STAMP:
            art.draw_stamp(c, W / 2, 1090, "STEEP", prog(t, T_STAMP, T_STAMP + 0.6), sub="BUT IT KEEPS THE LIGHTS ON")
            fx.impact(c, W / 2, 1090, t, T_STAMP + 0.05, size=420, seed=19)
            fx.shockwave(c, W / 2, 1090, t, T_STAMP + 0.05, r1=900, w=20)
        if sy > -300:
            P.draw_rubber_stamp(c, W / 2, sy, 1.8, ang=0, t=tq)
            c.drawLine(W / 2 + 60, sy - 80, W / 2 + 260, sy - 900, stroke(INK, 70)); c.drawLine(W / 2 + 60, sy - 80, W / 2 + 260, sy - 900, stroke(G3, 56))
            art.draw_glove(c, W / 2 + 30, sy - 90, -70, "fist", 1.6)


def draw_s25(c, t, tq):
    """Light switch: Markup flips it, the snack bar blazes."""
    on = t >= T_SWITCH
    counter_back(c, t, glow=1.0 if on else 0.15, chase=on)
    if not on:
        c.drawRect(skia.Rect.MakeWH(W, H), fill("#000000", 110))
    markup(c, 360, 1650, 1.05, tq, markup_pose3(tq, arms="switch" if t > T_SWITCH - 0.6 else None) if t > T_SWITCH - 0.6 else markup_pose3(tq))
    counter_front(c)
    P.draw_light_switch(c, 800, 960, 1.3, on=on, t=tq)
    art.draw_popcorn(c, 860, 1205, 0.9, t=tq, boil=boil_of(tq), face=True, dance=1.0 if on else 0.0)
    if on:
        fx.kernels(c, 860, 940, t, T_SWITCH, TOTAL, every=0.14, seed=23)
        fx2.sparkles(c, 800, 960, t, T_SWITCH, life=0.8, n=8, seed=24, radius=200)
    draw_receipt3(c, t, center=True)


def draw_s26(c, t, tq):
    """Pro move: the phone shows FREE REFILL!, Wally gets refilled and pops back up."""
    art.stage_live(c, t, sweep=-150)
    glow = ease_out(prog(t, T_PHONE, T_PHONE + 0.4))
    phone = lambda cc: P.draw_phone(cc, 0, -125, 1.0 + 0.55 * ease_out_back(prog(t, T_PHONE - 0.3, T_PHONE + 0.1)), ang=-8, t=t,
                                    lines=("FREE", "REFILL!"), header="THEATER APP", glow=glow)
    markup(c, 300, 1600, 0.95, tq, markup_pose3(tq, arms="phone", holdR=phone))
    refill = prog(t, T_REFILL, T_REFILL + 0.6)
    flat = 1.0 - ease_out_back(refill) if t < T_REFILL + 0.6 else 0.0
    dy, sx_, sy_ = fx2.squash_hop(t, T_REFILL + 0.55, height=120, dur=0.45)
    wally(c, 820, 1650 + dy, 0.95, tq, thick=wally_thick(t), flat=clamp(flat, 0, 1), expr="happy" if refill >= 1 else ("x" if flat > 0.5 else "worried"),
          arms="cheer" if refill >= 1 else None, squash=sy_)
    if T_REFILL - 0.4 <= t < T_REFILL + 0.6:
        fx.kernels(c, 820, 1100, t, T_REFILL - 0.4, T_REFILL + 0.5, every=0.05, seed=31, spread=0.4)
    if t >= T_REFILL + 0.6:
        fx.money_burst(c, 820, 1500, t, T_REFILL + 0.6, n=8, seed=71, speed=900, scale=0.55)


def draw_s27(c, t, tq):
    art.stage_live(c, t, sweep=math.sin(t * 1.5) * 200)
    a = shot_by("S27")["a"]
    markup(c, 540, 1600, 1.0, tq, markup_pose3(tq))
    wally(c, 860, 1640 - abs(math.sin(tq * 6 + 1)) * 30, 0.85, tq, thick=0.8, expr="happy", arms="cheer")
    hop = abs(math.sin(tq * 6)) * 40
    footnote(c, 200, 1660 - hop, 0.8, tq, mouth="closed")
    fx.confetti_bills(c, t, a + 0.2, n=26, seed=61, life=3.2)
    rows = [["NOW", "YA", "KNOW"], ["THE", "RACKET."]]
    i = 0
    for ri, row in enumerate(rows):
        ws_ = [art.text_width(w, 100, "bungee") for w in row]; sp = art.text_width(" ", 100, "bungee")
        x = W / 2 - (sum(ws_) + sp * (len(row) - 1)) / 2
        for w_, wd in zip(row, ws_):
            k = fx2.pop_in(t, a + 0.1 + i * 0.12, 0.25)
            if k > 0:
                c.save(); c.translate(x + wd / 2, 360 + ri * 118 + math.sin(t * 6 + i) * 6); c.scale(k, k)
                text(c, w_, 0, 0, 100, "bungee", WHITE, outline=INK, ow=14); c.restore()
            x += wd + sp; i += 1


def draw_s28(c, t, tq):
    art.stage_live(c, t)
    a = shot_by("S28")["a"]
    k = prog(t, a, a + 0.4)
    footnote(c, 540, 1720 - math.sin(k * math.pi) * 300, 1.3 * max(0.2, ease_out_back(k)), tq,
             hold=lambda cc: P.draw_keycard(cc, 30, -60, 0.8, ang=-15, t=tq, label="ROOM 3"))
    P.draw_clock(c, 860, 1180, 1.0, t=t, hour=3, minute=int((t - a) * 40) % 60 if t < a + 1.5 else 0)
    if t > a + 0.3:
        flip = prog(t, a + 0.3, a + 0.6)
        sx = abs(math.cos(flip * math.pi)) if flip < 1 else 1.0
        c.save(); c.translate(W / 2, 480); c.scale(max(0.02, sx), 1)
        if flip < 0.5:
            c.drawRoundRect(skia.Rect.MakeLTRB(-320, 0, 320, 260), 14, 14, fill(G2)); c.drawRoundRect(skia.Rect.MakeLTRB(-320, 0, 320, 260), 14, 14, stroke(INK, 6))
        else:
            art.draw_card(c, 0, 0, ["NEXT REEL:", "Why is hotel", "check-in at 3?"], w=640, size=60)
        c.restore()
        text(c, "@mistermarkup", W / 2, 960, 56, "anton", WHITE, outline=INK, ow=10)


# ================================================================== EDIT DECISION LIST
shot("S01", 0.0, S("hook2") - 0.12, draw_s01, lambda t: keycam(t, [(0, 1.25, 560, 1060), (T_GRAB, 1.15, 540, 1040), (T_BUCK, 1.32, 620, 1000)]))
shot("S02", S("hook2") - 0.12, S("hook3") - 0.05, draw_s02, lambda t: keycam(t, [(S("hook2"), 1.45, 420, 900), (S("hook3"), 1.6, 400, 860)]))
shot("S03", S("hook3") - 0.05, S("racket") - 0.08, draw_s03, lambda t: keycam(t, [(S("hook3"), 1.0, W / 2, H / 2), (S("racket"), 1.1, 460, 1000)]), trans="whipL")
shot("S04", S("racket") - 0.08, E("racket") + 0.05, draw_s04, lambda t: keycam(t, [(S("racket"), 1.35, 480, 940), (E("racket"), 1.9, 430, 820)]))
shot("S05", E("racket") + 0.05, S("greed") - 0.05, draw_title, lambda t: (1.0 + 0.02 * math.sin(t * 40), W / 2, H / 2), trans="burn", cap_y=None)
shot("S06", S("greed") - 0.05, S("ticket") - 0.1, draw_s06,
     lambda t: keycam(t, [(S("greed"), 1.35, 460, 900), (T_FOLLOW - 0.1, 1.45, 460, 880), (T_FOLLOW + 0.3, 1.0, W / 2, H / 2)]), trans="burn", receipt=True)
shot("S07", S("ticket") - 0.1, S("ticket") + 2.2, draw_s07, lambda t: keycam(t, [(S("ticket"), 1.3, 330, 1250), (S("ticket") + 2.2, 1.2, 380, 1150)]), trans="whipR", receipt=True)
shot("S08", S("ticket") + 2.2, S("blockbuster") - 0.05, draw_s08, lambda t: keycam(t, [(S("ticket") + 2.2, 1.0, W / 2, H / 2), (S("blockbuster"), 1.2, 700, 1050)]), receipt=True)
shot("S09", S("blockbuster") - 0.05, S("fn_half") - 0.15, draw_s09, lambda t: keycam(t, [(S("blockbuster"), 1.0, W / 2, H / 2), (S("fn_half"), 1.15, W / 2, 900)]), trans="whipU", receipt=True)
shot("S10", S("fn_half") - 0.15, S("crumbs") - 0.05, draw_s10,
     lambda t: keycam(t, [(S("fn_half") - 0.15, 1.2, 560, 1300), (S("fn_half") + 0.7, 1.0, W / 2, H / 2), (S("crumbs"), 1.05, W / 2, H / 2)]), trans="whipL", receipt=True)
shot("S11", S("crumbs") - 0.05, S("counter") - 0.2, draw_s11, lambda t: keycam(t, [(S("crumbs"), 1.0, W / 2, H / 2), (S("crumbs") + 1.2, 1.4, 500, 850), (S("counter"), 1.8, 520, 760)]), trans="whipR", receipt=True)
shot("S12", S("counter") - 0.2, S("soda") - 0.15, draw_s12, lambda t: keycam(t, [(S("counter") - 0.2, 1.25, W / 2, 560), (S("counter") + 1.2, 1.0, W / 2, H / 2), (T_LIFT + 0.3, 1.12, 560, 920)]), trans="iris", receipt=True)
shot("S13", S("soda") - 0.15, S("twenty") - 0.1, draw_s13, lambda t: keycam(t, [(S("soda"), 1.05, W / 2, H / 2), (S("twenty"), 1.2, 600, 980)]), trans="whipL", receipt=True)
shot("S14", S("twenty") - 0.1, S("sneaky") - 0.15, draw_s14, lambda t: keycam(t, [(S("twenty"), 1.0, W / 2, H / 2), (T_RIP, 1.1, 440, 1020), (T_REG, 1.0, W / 2, H / 2)]), trans="whipR", receipt=True, cap_y=1380)
shot("S15", S("sneaky") - 0.15, S("bait") - 0.05, draw_s15,
     lambda t: keycam(t, [(S("sneaky") - 0.15, 1.0, W / 2, H / 2), (S("sneaky") + 1.0, 1.0, W / 2, H / 2), (S("sneaky") + 1.4, 1.3, 535, 1000)]), trans="whipL", receipt=True, cap_y=1400)
shot("S16", S("bait") - 0.05, T_DSTAMP - 0.3, draw_s16_17, lambda t: keycam(t, [(S("bait"), 1.0, W / 2, H / 2), (T_CATCH, 1.15, 520, 1050), (T_SWING + 0.8, 1.05, 680, 1000)]), cap_y=1400)
shot("S18", T_DSTAMP - 0.3, S("invented") - 0.2, draw_s18, lambda t: keycam(t, [(T_DSTAMP - 0.3, 1.0, W / 2, H / 2), (S("invented"), 1.04, W / 2, H / 2)]), cap_y=1400)
shot("S19", S("invented") - 0.2, S("fn_1982") - 0.1, draw_s19, lambda t: keycam(t, [(S("invented") - 0.2, 1.0, W / 2, H / 2), (S("fn_1982"), 1.15, W / 2, 900)]), trans="burn")
shot("S20", S("fn_1982") - 0.1, S("poll") - 0.2, draw_s20_21,
     lambda t: keycam(t, [(S("fn_1982") - 0.1, 1.25, 520, 1150), (T_WHACK + 0.5, 1.15, 560, 1100), (S("fn_1982") + 1.5, 1.0, W / 2, H / 2)]), trans="flash", cap_y=1360)
shot("S22", S("poll") - 0.2, S("verdict") - 0.2, draw_s22, lambda t: keycam(t, [(S("poll") - 0.2, 1.0, W / 2, H / 2), (FREEZE[0], 1.04, W / 2, H / 2), (FREEZE[1], 1.1, W / 2, 1000)]), trans="whipR", cap_y=1330)
shot("S23", S("verdict") - 0.2, T_TOTAL, draw_s23_24, lambda t: keycam(t, [(S("verdict") - 0.2, 1.0, W / 2, H / 2), (T_TOTAL - 1.35, 1.06, W / 2, H / 2), (T_TOTAL, 1.5, 720, 880)]), trans="whipL", cap_y=1405)
shot("S24", T_TOTAL, S("steep") + 1.3, draw_s23_24, lambda t: keycam(t, [(T_TOTAL, 1.0, W / 2, H / 2), (T_TEAR, 1.03, W / 2, H / 2), (S("steep") + 1.3, 1.12, W / 2, 1250)]), cap_y=1405)
shot("S25", S("steep") + 1.3, S("promove") - 0.1, draw_s25, lambda t: keycam(t, [(S("steep") + 1.3, 1.2, 600, 1000), (S("promove"), 1.0, W / 2, H / 2)]), trans="whipR")
shot("S26", S("promove") - 0.1, S("racket_out") - 0.1, draw_s26, lambda t: keycam(t, [(S("promove") - 0.1, 1.2, 380, 900), (T_PHONE + 0.5, 1.0, W / 2, H / 2), (S("racket_out"), 1.06, 600, 1000)]), trans="whipL")
shot("S27", S("racket_out") - 0.1, S("next") - 0.1, draw_s27, lambda t: keycam(t, [(S("racket_out") - 0.1, 1.15, W / 2, 800), (S("next"), 1.0, W / 2, H / 2)]), trans="flash")
shot("S28", S("next") - 0.1, TOTAL, draw_s28, lambda t: keycam(t, [(S("next") - 0.1, 1.0, W / 2, H / 2), (TOTAL, 1.08, W / 2, 1000)]), trans="whipR")

# ---- events: camera, comic words and their sounds
sfx("whoosh", 0.0, 0.45); sfx("stamp", T_LAND, 0.6); shake(T_LAND, 26, 0.35); punch(T_LAND, 0.1)
sfx("ahooga", 0.34, 0.5); word(0.38, "$9?!", 300, 520, size=120, money=True, seed=1)
sfx("zip", T_GRAB - 0.35, 0.35); sfx("squeak", T_GRAB, 0.25)
sfx("zip", T_XRAY[0], 0.3); flash(T_XRAY[0], 120, 0.1)
sfx("slot", T_BUCK, 0.5); sfx("kaching", T_BUCK + 0.6, 0.45); punch(T_BUCK + 0.6, 0.08)
word(T_BUCK + 0.62, "~$1!", 760, 700, size=110, money=True, seed=2)
punch(T_NINE, 0.18); shake(T_NINE, 22, 0.35); flash(T_NINE, 170); sfx("slot", T_NINE - 0.02, 0.35); sfx("kaching", T_NINE + 0.45, 0.45)
sfx("ahooga", T_NINE + 0.75, 0.3); word(T_NINE + 0.45, "NINE?!", 780, 620, size=120, money=True, seed=3)
sfx("pop", S("hook3") + 0.8, 0.2)
sfx("sting", shot_by("S05")["a"] + 0.05, 0.7)
for k in range(3):
    sfx("pop", shot_by("S05")["a"] + 0.05 + k * 0.3, 0.18)
sfx("typewriter", shot_by("S05")["a"] + 0.9, 0.35)
sfx("printer", R2.T_RECEIPT_IN + 0.1, 0.45)
for _, _, lid, off in RECEIPT:
    sfx("printer", S(lid) + off, 0.45)
punch(T_FOLLOW, 0.08); sfx("zip", T_FOLLOW + 0.45, 0.35)
for i in range(4):
    sfx("squeak", T_FOLLOW + 0.5 + i * 0.18, 0.2)
sfx("vacuum", T_BOOTH, 0.25); sfx("squeak", T_BOOTH + 1.0, 0.2)
sfx("zip", T_GAUGE - 0.35, 0.3); sfx("whack", T_GAUGE, 0.45); sfx("slot", T_GAUGE, 0.3); shake(T_GAUGE, 16, 0.3)
word(T_GAUGE + 0.55, "HALF!", 760, 820, size=100, money=False, seed=4)
sfx("vacuum", T_VAC, 0.55); word(T_VAC + 0.3, "SLURP!", 540, 520, size=120, seed=5); punch(T_VAC + 0.1, 0.08)
sfx("boing", T_FN_IN + 0.3, 0.18); shake(T_FN_IN + 0.45, 10, 0.25)
sfx("typewriter", S("fn_half") + 0.6, 0.1); sfx("zip", T_LENS, 0.3)
sfx("iris", shot_by("S11")["b"] - 0.35, 0.45); sfx("iris", shot_by("S12")["a"], 0.3)
sfx("zip", T_LIFT - 0.3, 0.3); sfx("pop", T_LIFT, 0.4); punch(T_LIFT, 0.1)
sfx("pour", T_POUR, 0.22); sfx("gulp", T_SYRUP + 0.1, 0.2)
for i in range(3):
    sfx("clink", T_ICE + i * 0.22 + 0.25, 0.22)
sfx("tear", T_RIP, 0.65); word(T_RIP + 0.05, "RIP!", 640, 760, size=120, seed=6); shake(T_RIP, 14, 0.25)
sfx("kaching", T_REG, 0.6); word(T_REG + 0.05, "KA-CHING!", 790, 650, size=92, money=True, seed=7); punch(T_REG, 0.08)
for i in range(3):
    sfx("stamp", shot_by("S15")["a"] + i * 0.18 + 0.3, 0.25)
punch(S("sneaky") + 1.1, 0.08); sfx("boing", S("sneaky") + 1.1, 0.22)
sfx("slide_down", T_BAIT, 0.25); sfx("boing", T_BAIT + 0.4, 0.2)
for i in range(5):
    sfx("squeak", S("bait") + i * 0.2, 0.15)
sfx("zip", T_CATCH, 0.4); sfx("ahooga", T_CATCH + 0.05, 0.3); shake(T_CATCH, 12, 0.25)
sfx("whoosh", T_SWING, 0.35); sfx("kaching", T_SWING + 0.75, 0.3)
sfx("zip", T_DSTAMP - 0.25, 0.3); sfx("stamp", T_DSTAMP, 0.7); shake(T_DSTAMP, 22, 0.35); flash(T_DSTAMP, 120, 0.08)
sfx("whack", T_WHACK, 0.9); shake(T_WHACK, 28, 0.35); flash(T_WHACK, 140, 0.08); punch(T_WHACK, 0.12)
sfx("slide_down", T_WHACK + 0.4, 0.25)
sfx("pop", S("fn_1982") + 1.5, 0.3)
for i in range(3):
    sfx("pop", S("poll") + i * 0.35, 0.15)
sfx("zip", S("poll") + 1.6, 0.3)
flash(FREEZE[0], 120, 0.08); sfx("iris", FREEZE[0], 0.2)
sfx("whoosh", S("verdict") - 0.1, 0.35)
sfx("drumroll", T_TOTAL - 1.35, 0.7); shake(T_TOTAL - 1.0, 6, 1.0)
punch(T_TOTAL, 0.12); flash(T_TOTAL, 160); sfx("kaching", T_TOTAL, 0.8)
sfx("zip", T_STAMP - 0.3, 0.35)
punch(T_STAMP + 0.05, 0.22); shake(T_STAMP + 0.05, 42, 0.55); flash(T_STAMP + 0.05, 150, 0.08); sfx("stamp", T_STAMP, 1.0); sfx("shatter", T_STAMP + 0.03, 0.55)
sfx("honk", T_FLAT, 0.6)
sfx("tear", T_TEAR, 0.7)
sfx("click", T_SWITCH, 0.8); flash(T_SWITCH, 200, 0.12); punch(T_SWITCH, 0.1); sfx("kaching", T_SWITCH + 0.1, 0.3)
word(T_SWITCH + 0.1, "CLICK!", 820, 760, size=100, seed=8)
sfx("ding", T_PHONE, 0.6); punch(T_PHONE, 0.06)
sfx("pour", T_REFILL - 0.4, 0.3); sfx("boing", T_REFILL + 0.55, 0.45); word(T_REFILL + 0.6, "REFILL!", 820, 1080, size=110, money=False, seed=9)
sfx("sting", S("racket_out") - 0.05, 0.25)
sfx("pop", S("next") - 0.3, 0.3); sfx("ding", S("next") + 0.4, 0.3)
sfx("iris", TOTAL - 0.9, 0.5)
for s_ in SHOTS:
    if s_["trans"].startswith("whip"):
        sfx("whoosh", s_["a"] - 0.12, 0.28)

WHIP = 0.13


def cam_for(t):
    sh = next((s for s in SHOTS if s["a"] <= t < s["b"]), SHOTS[-1])
    z, cx, cy = sh["cam"](t)
    for t0, amt in PUNCHES:
        dt = t - t0
        if 0 <= dt < 0.8:
            z *= 1 + amt * min(1, dt / 0.04) * math.exp(-dt * 7)
    ox = oy = 0.0
    nxt = next((s for s in SHOTS if s["a"] >= sh["b"] - 1e-6), None)
    dirs = {"whipR": (-1, 0), "whipL": (1, 0), "whipU": (0, 1)}
    if nxt and nxt["trans"].startswith("whip") and t > sh["b"] - WHIP:
        k = ease_in(prog(t, sh["b"] - WHIP, sh["b"])); d = dirs[nxt["trans"]]
        ox, oy = d[0] * 260 * k, d[1] * 420 * k; z *= 1 + 0.25 * k
    if sh["trans"].startswith("whip") and t < sh["a"] + WHIP:
        k = 1 - ease_out(prog(t, sh["a"], sh["a"] + WHIP)); d = dirs[sh["trans"]]
        ox, oy = -d[0] * 260 * k, -d[1] * 420 * k; z *= 1 + 0.25 * k
    sx = sy = rot = 0.0
    for t0, amp, dur in SHAKES:
        dt = t - t0
        if 0 <= dt < dur:
            a = amp * (1 - dt / dur) ** 2
            r = np.random.default_rng(int(t * 240) + int(t0 * 100))
            sx += r.uniform(-a, a); sy += r.uniform(-a, a); rot += r.uniform(-a, a) * 0.04
    zr = z * 1.06
    cx = cx + ox / zr + sx / zr; cy = cy + oy / zr + sy / zr
    hw, hh = W / (2 * zr), H / (2 * zr)
    cx = min(max(cx, hw), W - hw); cy = min(max(cy, hh), H - hh)
    return sh, zr, cx, cy, rot


def whip_strength(t):
    for s in SHOTS:
        if s["trans"].startswith("whip") and abs(t - s["a"]) < WHIP:
            return 1 - abs(t - s["a"]) / WHIP, s["trans"]
    return 0.0, None


VIG = art.vignette_paint()


def render_frame(arr, t):
    s = skia.Surface(arr); c = s.getCanvas(); c.clear(hexc("#000000"))
    frozen = FREEZE[0] <= t < FREEZE[1]
    if frozen:
        t = FREEZE[0]
    tq = math.floor(t * 12) / 12.0
    q = int(t * 12)
    rnd = np.random.default_rng(q * 7919 + 13)
    sh, z, cx, cy, rot = cam_for(t)
    c.save(); c.translate(rnd.uniform(-1.5, 1.5), rnd.uniform(-1.1, 1.1))
    ws, wt = whip_strength(t)
    if ws > 0.05:
        sxg, syg = (2, ws * 60) if wt == "whipU" else (ws * 60, 2)
        c.saveLayer(None, skia.Paint(ImageFilter=skia.ImageFilters.Blur(sxg, syg)))
    with Cam(c, z, cx, cy, rot):
        sh["draw"](c, t, tq)
    if ws > 0.05:
        c.restore()
    if sh["receipt"]:
        draw_receipt3(c, t)
    c.restore()
    # opening question title
    if 0.5 <= t < S("hook2") - 0.12:
        k = fx2.pop_in(t, 0.5, 0.3)
        c.save(); c.translate(W / 2, 300); c.scale(k, k); c.rotate(math.sin(t * 3) * 1.2)
        c.drawRoundRect(skia.Rect.MakeLTRB(-470, -170, 470, 150), 26, 26, fill(INK, 232)); c.drawRoundRect(skia.Rect.MakeLTRB(-470, -170, 470, 150), 26, 26, stroke(WHITE, 6))
        text(c, "WHY IS MOVIE", 0, -80, 82, "bungee", WHITE); text(c, "POPCORN SO", 0, 10, 82, "bungee", WHITE)
        text(c, "EXPENSIVE?", 0, 104, 92, "bungee", MONEY)
        c.restore()
    # comic action words (screen space)
    for (t0, w_, x, y, size, money, ang, life, seed) in WORDS:
        if t0 <= t < t0 + life:
            fx2.action_word(c, x, y, w_, t, t0, life=life, size=size, seed=seed, money=money, ang=ang)
    if T_STAMP <= t < T_STAMP + 1.2:
        fx2.screen_crack(c, W / 2, 1090, t, T_STAMP + 0.03, life=1.15, seed=3, size=620)
    if T_NINE <= t < T_NINE + 0.9:
        fx2.screen_crack(c, 330, 560, t, T_NINE + 0.02, life=0.85, seed=5, size=420)
    if T_TOTAL <= t < T_TOTAL + 0.3:
        fx2.money_flash(c, t, T_TOTAL, dur=0.25, alpha=70)
    if T_REG <= t < T_REG + 0.3:
        fx2.money_flash(c, t, T_REG, dur=0.25, alpha=55)
    draw_captions(c, t, sh["cap_y"])
    if ws > 0:
        fx.speed_lines(c, t, radial=False, n=46, strength=ws, direction=0.0 if wt != "whipU" else math.pi / 2)
    if sh["trans"] == "iris" and t < sh["a"] + 0.35:
        iris(c, lerp(0, 1400, prog(t, sh["a"], sh["a"] + 0.35)))
    nxt = next((s_ for s_ in SHOTS if s_["a"] >= sh["b"] - 1e-6), None)
    if nxt and nxt["trans"] == "iris" and t > sh["b"] - 0.35:
        iris(c, lerp(1400, 0, prog(t, sh["b"] - 0.35, sh["b"])))
    if sh["name"] == "S28" and t > TOTAL - 0.9:
        iris(c, lerp(1400, 0, prog(t, TOTAL - 0.9, TOTAL - 0.45)))
    if sh["trans"] in ("burn", "flash") and t - sh["a"] < 0.14:
        c.drawRect(skia.Rect.MakeWH(W, H), fill("#ffffff", int(210 * (1 - (t - sh["a"]) / 0.14))))
    if sh["trans"] == "burn":
        fx.light_leak(c, t, sh["a"] - 0.05, life=0.5)
    for t0, a, dur in FLASHES:
        if 0 <= t - t0 < dur:
            c.drawRect(skia.Rect.MakeWH(W, H), fill("#ffffff", int(a * (1 - (t - t0) / dur))))
    if frozen:
        text(c, "II", 980, 230, 70, "bungee", WHITE, outline=INK, ow=8)
    fl = rnd.uniform(-1, 1)
    c.drawRect(skia.Rect.MakeWH(W, H), fill("#ffffff" if fl > 0 else "#000000", int(abs(fl) * 14)))
    art.film_frame_fx(c, q, rnd, strength=2.4 if sh["name"] == "S19" else 1.0)
    c.drawRect(skia.Rect.MakeWH(W, H), VIG)
    if sh["name"] == "S19":
        c.drawRect(skia.Rect.MakeWH(W, H), art.vignette_paint())


def main():
    if len(sys.argv) > 2 and sys.argv[1] == "--stills":
        from PIL import Image
        os.makedirs(os.path.join(ROOT, "out", "previews"), exist_ok=True)
        for ts in sys.argv[2].split(","):
            t = float(ts); arr = np.zeros((H, W, 4), np.uint8); render_frame(arr, t)
            Image.fromarray(arr[..., :3]).save(os.path.join(ROOT, "out", "previews", f"v3_{t:05.2f}.png"))
        return
    nfr = int(TOTAL * FPS)
    outp = os.path.join(ROOT, "out", "frames_v3.mp4")
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
