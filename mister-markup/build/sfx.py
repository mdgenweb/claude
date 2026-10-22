"""Synthesize original music + SFX for Mister Markup (no samples, no copyright)."""
import numpy as np, soundfile as sf, os

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "audio", "sfx")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def t_(dur):
    return np.arange(int(dur * SR)) / SR


def env_exp(n, tau):
    return np.exp(-np.arange(n) / (tau * SR))


def adsr(n, a=0.005, d=0.05, s=0.6, r=0.05):
    e = np.ones(n) * s
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    na = min(na, n); e[:na] = np.linspace(0, 1, na)
    nd = min(nd, n - na); e[na:na + nd] = np.linspace(1, s, nd)
    if nr > 0 and nr < n:
        e[-nr:] *= np.linspace(1, 0, nr)
    return e


def onepole_lp(x, fc):
    a = np.exp(-2 * np.pi * fc / SR)
    y = np.zeros_like(x); acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def lp(x, fc):  # fast FFT lowpass
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1 / np.sqrt(1 + (f / fc) ** 4)
    return np.fft.irfft(X, len(x))


def hp(x, fc):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= (f / fc) ** 2 / np.sqrt(1 + (f / fc) ** 4)
    return np.fft.irfft(X, len(x))


def bp(x, lo, hi):
    return lp(hp(x, lo), hi)


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def save(name, x, peak=0.9):
    x = norm(x, peak)
    sf.write(os.path.join(OUT, name + ".wav"), x.astype(np.float32), SR)


# ---------------------------------------------------------------- SFX
def kaching():
    d = 1.6; t = t_(d); n = len(t)
    # mechanical lever clunk
    clunk = bp(rng.standard_normal(n), 300, 2500) * env_exp(n, 0.02)
    # drawer slide
    slide = bp(rng.standard_normal(n), 1500, 6000) * np.clip((t - 0.03) / 0.02, 0, 1) * env_exp(n, 0.06) * 0.4
    # bell (inharmonic partials) starting at 0.07s
    bell = np.zeros(n); tb = np.clip(t - 0.07, 0, None); on = (t >= 0.07)
    for f, a, tau in [(2093, 1.0, 0.55), (2637, 0.5, 0.4), (4186, 0.35, 0.25), (5274, 0.2, 0.18), (3136, 0.3, 0.35)]:
        bell += a * np.sin(2 * np.pi * f * tb) * np.exp(-tb / tau) * on
    # second bell hit ("ching")
    tb2 = np.clip(t - 0.16, 0, None); on2 = t >= 0.16
    for f, a, tau in [(2349, 0.8, 0.6), (3520, 0.4, 0.35), (4699, 0.25, 0.2)]:
        bell += a * np.sin(2 * np.pi * f * tb2) * np.exp(-tb2 / tau) * on2
    save("kaching", clunk * 0.9 + slide + bell * 0.6)


def stamp():
    d = 0.7; t = t_(d); n = len(t)
    f = 140 * np.exp(-t / 0.05) + 45
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(n, 0.12)
    slap = bp(rng.standard_normal(n), 200, 4000) * env_exp(n, 0.015)
    save("stamp", body * 1.0 + slap * 0.7)


def printer(dur=0.55):
    t = t_(dur); n = len(t)
    x = np.zeros(n)
    k = 0.0
    while k < dur - 0.02:
        i = int(k * SR); m = int(0.012 * SR)
        click = bp(rng.standard_normal(m), 1200, 7000) * env_exp(m, 0.003)
        x[i:i + m] += click[: n - i]
        k += 0.022 + rng.random() * 0.01
    buzz = np.sign(np.sin(2 * np.pi * 95 * t)) * 0.08
    motor = lp(buzz + rng.standard_normal(n) * 0.05, 900)
    e = np.clip(t / 0.02, 0, 1) * np.clip((dur - t) / 0.03, 0, 1)
    save("printer", (x + motor) * e, 0.7)


def tear():
    d = 0.45; t = t_(d); n = len(t)
    x = bp(rng.standard_normal(n), 800, 9000)
    am = 0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 38 * t + rng.random() * 3))
    e = np.clip(t / 0.01, 0, 1) * np.exp(-t / 0.25)
    save("tear", x * am * e, 0.7)


def whoosh(d=0.5, up=True):
    t = t_(d); n = len(t)
    x = rng.standard_normal(n)
    out = np.zeros(n)
    seg = 512
    for s in range(0, n, seg):
        frac = s / n if up else 1 - s / n
        fc = 400 + 3500 * frac
        chunk = x[s:s + seg]
        out[s:s + seg] = chunk
    out = bp(out, 300, 4500)
    e = np.sin(np.pi * t / d) ** 2
    save("whoosh", out * e, 0.6)


def slide_whistle(d=0.6, up=True, name="slide_up"):
    t = t_(d)
    f0, f1 = (500, 1500) if up else (1500, 450)
    f = f0 + (f1 - f0) * (t / d) ** 0.8
    f *= 1 + 0.012 * np.sin(2 * np.pi * 6 * t)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.05 * rng.standard_normal(len(t))
    e = adsr(len(t), 0.02, 0.05, 0.9, 0.08)
    save(name, x * e, 0.55)


def honk(name="honk", f0=420, d=0.32):
    t = t_(d)
    f = f0 * (1 + 0.15 * np.exp(-t / 0.05))
    ph = 2 * np.pi * np.cumsum(f) / SR
    saw = 2 * ((ph / (2 * np.pi)) % 1) - 1
    x = bp(saw, 400, 3000)
    save(name, x * adsr(len(t), 0.01, 0.05, 0.8, 0.06), 0.6)


def squeak():
    d = 0.18; t = t_(d)
    f = 1800 + 900 * np.sin(np.pi * t / d)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR)
    save("squeak", x * adsr(len(t), 0.01, 0.03, 0.8, 0.04), 0.5)


def pop():
    d = 0.18; t = t_(d)
    f = 300 + 1400 * (t / d)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(len(t), 0.05)
    save("pop", x, 0.6)


def drumroll(d=1.6):
    t = t_(d); n = len(t)
    x = np.zeros(n)
    k = 0.0
    while k < d - 0.25:
        i = int(k * SR); m = int(0.05 * SR)
        hit = bp(rng.standard_normal(m), 1500, 8000) * env_exp(m, 0.02)
        amp = 0.3 + 0.7 * (k / d)
        x[i:i + m] += hit[: n - i] * amp
        k += 0.034
    # final crash
    i = int((d - 0.25) * SR); m = n - i
    crash = hp(rng.standard_normal(m), 3000) * env_exp(m, 0.18)
    x[i:] += crash * 1.2
    save("drumroll", x, 0.7)


def iris():
    d = 0.35; t = t_(d)
    f = 900 - 500 * (t / d)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.5 + bp(rng.standard_normal(len(t)), 2000, 6000) * 0.3
    save("iris", x * np.sin(np.pi * t / d), 0.4)


def boing():
    d = 0.5; t = t_(d)
    f = 180 + 120 * np.sin(2 * np.pi * 9 * t) * np.exp(-t / 0.2)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(len(t), 0.18)
    save("boing", x, 0.6)


def sting():
    """3-note brass-ish title sting (G C E->) """
    d = 1.1; t = t_(d); n = len(t)
    x = np.zeros(n)
    for start, f, ln in [(0.0, 392.0, 0.16), (0.17, 523.25, 0.16), (0.34, 659.25, 0.7)]:
        i0 = int(start * SR); m = int(ln * SR)
        tt = np.arange(m) / SR
        vib = 1 + 0.006 * np.sin(2 * np.pi * 5.5 * tt) * np.clip(tt / 0.2, 0, 1)
        ph = 2 * np.pi * np.cumsum(f * vib) / SR
        tone = sum((1 / k) * np.sin(k * ph) for k in range(1, 9))
        tone = lp(tone, 2400)
        x[i0:i0 + m] += tone * adsr(m, 0.02, 0.06, 0.8, 0.08)
    save("sting", x, 0.7)


def crackle_bed(d=90.0):
    t = t_(d); n = len(t)
    hum = 0.02 * np.sin(2 * np.pi * 60 * t) + 0.01 * np.sin(2 * np.pi * 120 * t)
    hiss = lp(rng.standard_normal(n), 5000) * 0.03
    clicks = np.zeros(n)
    idx = rng.integers(0, n - 200, int(d * 9))
    for i in idx:
        m = int(rng.integers(20, 120))
        clicks[i:i + m] += rng.standard_normal(m) * env_exp(m, 0.0007) * rng.uniform(0.2, 1.0)
    whir = lp(rng.standard_normal(n), 300) * 0.04 * (1 + 0.3 * np.sin(2 * np.pi * 24 * t))
    save("crackle_bed", hum + hiss + clicks * 0.5 + whir, 0.5)


# ---------------------------------------------------------------- MUSIC
NOTE = {n: i for i, n in enumerate(["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}


def mid(name):  # "C4"
    p, o = name[:-1], int(name[-1])
    return 12 * (o + 1) + NOTE[p]


def hz(m):
    return 440 * 2 ** ((m - 69) / 12)


def piano_tone(f, d, vel=1.0):
    t = t_(d)
    x = sum((0.6 ** (k - 1)) * np.sin(2 * np.pi * f * k * t * (1 + 0.0004 * k * k)) for k in range(1, 7))
    e = np.exp(-t / (0.35 + 120 / f)) * np.clip(t / 0.004, 0, 1)
    return x * e * vel


def tuba_tone(f, d, vel=1.0):
    t = t_(d)
    ph = 2 * np.pi * f * t
    x = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.25 * np.sin(3 * ph) + 0.12 * np.sin(4 * ph)
    return x * adsr(len(t), 0.02, 0.08, 0.7, 0.06) * vel


def clarinet_tone(f, d, vel=1.0):
    t = t_(d)
    vib = 1 + 0.008 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t / 0.15, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    x = np.sin(ph) + 0.33 * np.sin(3 * ph) + 0.2 * np.sin(5 * ph) + 0.1 * np.sin(7 * ph)
    return lp(x, 3000) * adsr(len(t), 0.03, 0.05, 0.85, 0.05) * vel


def brush(d):
    t = t_(d); n = len(t)
    return bp(rng.standard_normal(n), 2500, 9000) * env_exp(n, 0.05)


def music(total=95.0, bpm=116):
    beat = 60 / bpm
    # 8-bar ragtime-ish progression (one chord per bar), loops
    prog = [("C", [0, 4, 7]), ("A", [0, 4, 7, 10]), ("D", [0, 4, 7, 10]), ("G", [0, 4, 7, 10]),
            ("C", [0, 4, 7]), ("F", [0, 4, 9]), ("G", [0, 4, 7, 10]), ("C", [0, 4, 7])]
    # simple syncopated melody per bar (beat offset, semitone above C5, dur beats)
    mel = [
        [(0, 4, .5), (.5, 7, .5), (1.5, 9, .5), (2, 7, 1), (3, 4, .5), (3.5, 2, .5)],
        [(0, 1, .5), (.5, 4, .5), (1, 9, 1), (2.5, 7, .5), (3, 4, 1)],
        [(0, 2, .5), (.5, 6, .5), (1.5, 9, .5), (2, 12, 1), (3, 9, .5), (3.5, 6, .5)],
        [(0, 7, 1.5), (1.5, 5, .5), (2, 2, .5), (2.5, -1, .5), (3, 2, 1)],
        [(0, 4, .5), (.5, 7, .5), (1.5, 12, .5), (2, 11, .5), (2.5, 12, .5), (3, 7, 1)],
        [(0, 9, .5), (.5, 5, .5), (1.5, 0, .5), (2, 5, 1), (3, 9, 1)],
        [(0, 7, .5), (.5, 5, .5), (1, 2, .5), (1.5, 11, .5), (2, 7, 1), (3, 5, .5), (3.5, 2, .5)],
        [(0, 0, 1.5), (2, 7, .5), (2.5, 4, .5), (3, 0, 1)],
    ]
    n = int(total * SR)
    bass = np.zeros(n); keys = np.zeros(n); lead = np.zeros(n); drums = np.zeros(n)
    bar = 0
    tpos = 0.0
    while tpos < total:
        root, ints = prog[bar % 8]
        rm = mid(root + "2")
        for b in range(4):
            st = tpos + b * beat
            i = int(st * SR)
            if i >= n: break
            if b in (0, 2):
                f = hz(rm if b == 0 else rm + 7)
                x = tuba_tone(f, beat * 0.9, 0.9)
                bass[i:i + len(x)] += x[: n - i]
            else:
                for iv in ints:
                    f = hz(mid(root + "4") + iv - (12 if iv > 7 else 0))
                    x = piano_tone(f, beat * 0.8, 0.35)
                    keys[i:i + len(x)] += x[: n - i]
            x = brush(0.12) * (0.5 if b % 2 else 0.25)
            drums[i:i + len(x)] += x[: n - i]
            # swing off-beat brush
            j = int((st + beat * 0.66) * SR)
            x = brush(0.06) * 0.15
            drums[j:j + len(x)] += x[: max(0, n - j)]
        for off, semi, dur in mel[bar % 8]:
            st = tpos + off * beat
            i = int(st * SR)
            if i >= n: continue
            f = hz(mid("C5") + semi)
            x = clarinet_tone(f, dur * beat * 0.95, 0.5)
            lead[i:i + len(x)] += x[: n - i]
        bar += 1
        tpos += 4 * beat
    mix = bass * 0.55 + keys * 0.45 + lead * 0.35 + drums * 0.3
    # old-record band-limit
    mix = lp(hp(mix, 120), 5500)
    sf.write(os.path.join(OUT, "music.wav"), norm(mix, 0.8).astype(np.float32), SR)


if __name__ == "__main__" and "--v3" not in __import__("sys").argv:
    kaching(); stamp(); printer(); tear(); whoosh(); slide_whistle(); slide_whistle(up=False, name="slide_down")
    honk(); squeak(); pop(); drumroll(); iris(); boing(); sting(); crackle_bed(); music()
    print(sorted(os.listdir(OUT)))


# ---------------------------------------------------------------- v3 extra SFX
def pour(d=1.2):
    t = t_(d); n = len(t)
    x = np.zeros(n)
    k = 0.0
    while k < d - 0.05:
        i = int(k * SR); m = int(0.04 * SR)
        f = rng.uniform(500, 1400)
        tt = np.arange(m) / SR
        x[i:i + m] += np.sin(2 * np.pi * f * (1 + 2 * tt) * tt) * np.exp(-tt / 0.012) * rng.uniform(0.3, 1)
        k += rng.uniform(0.015, 0.04)
    x += bp(rng.standard_normal(n), 300, 2500) * 0.25
    save("pour", x * np.clip(t / 0.05, 0, 1) * np.clip((d - t) / 0.15, 0, 1), 0.6)


def clink():
    d = 0.5; t = t_(d)
    x = sum(a * np.sin(2 * np.pi * f * t) * np.exp(-t / tau) for f, a, tau in [(3200, 1, .08), (4700, .6, .05), (6100, .4, .04)])
    save("clink", x, 0.5)


def vacuum(d=1.4):
    t = t_(d); n = len(t)
    f = 90 + 60 * np.clip(t / 0.3, 0, 1)
    motor = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.3
    air = bp(rng.standard_normal(n), 800, 6000) * (0.4 + 0.3 * np.sin(2 * np.pi * 3 * t))
    x = lp(motor, 1200) + air
    save("vacuum", x * np.clip(t / 0.1, 0, 1) * np.clip((d - t) / 0.2, 0, 1), 0.55)


def click():
    d = 0.12; t = t_(d); n = len(t)
    x = bp(rng.standard_normal(n), 1500, 8000) * np.exp(-t / 0.004) + np.sin(2 * np.pi * 1800 * t) * np.exp(-t / 0.01) * 0.5
    save("click", x, 0.7)


def whack():
    d = 0.45; t = t_(d); n = len(t)
    body = np.sin(2 * np.pi * np.cumsum(220 * np.exp(-t / 0.08) + 70) / SR) * np.exp(-t / 0.1)
    slap = bp(rng.standard_normal(n), 400, 7000) * np.exp(-t / 0.02)
    save("whack", body + slap * 1.2, 0.9)


def ahooga():
    d = 0.9; t = t_(d)
    f = np.where(t < 0.38, 240 + 160 * (t / 0.38), 420 - 200 * ((t - 0.38) / 0.52))
    ph = 2 * np.pi * np.cumsum(f) / SR
    saw = 2 * ((ph / (2 * np.pi)) % 1) - 1
    x = bp(saw, 300, 2600) * (1 - 0.6 * (np.abs(t - 0.38) < 0.04))
    save("ahooga", x * adsr(len(t), 0.02, 0.05, 0.9, 0.1), 0.6)


def ding():
    d = 0.9; t = t_(d)
    x = np.sin(2 * np.pi * 1318.5 * t) * np.exp(-t / 0.3) + 0.5 * np.sin(2 * np.pi * 1975.5 * np.clip(t - 0.12, 0, None)) * np.exp(-np.clip(t - 0.12, 0, None) / 0.35) * (t > 0.12)
    save("ding", x, 0.5)


def shatter(d=1.0):
    t = t_(d); n = len(t)
    x = hp(rng.standard_normal(n), 2500) * np.exp(-t / 0.15)
    for _ in range(40):
        i = int(rng.uniform(0, 0.6) * SR); m = int(0.03 * SR)
        x[i:i + m] += sum(np.sin(2 * np.pi * rng.uniform(2500, 7000) * np.arange(m) / SR) for _ in range(2)) * np.exp(-np.arange(m) / SR / 0.008) * 0.4
    save("shatter", x, 0.7)


def slot(d=0.8):
    t = t_(d); n = len(t)
    x = np.zeros(n); k = 0.0; step = 0.03
    while k < d - 0.05:
        i = int(k * SR); m = int(0.01 * SR)
        x[i:i + m] += np.sin(2 * np.pi * 2400 * np.arange(m) / SR) * np.exp(-np.arange(m) / SR / 0.003)
        k += step; step *= 1.08
    save("slot", x, 0.5)


def typewriter(d=1.2):
    t = t_(d); n = len(t)
    x = np.zeros(n); k = 0.0
    while k < d - 0.03:
        i = int(k * SR); m = int(0.02 * SR)
        x[i:i + m] += bp(rng.standard_normal(m), 1500, 6000) * np.exp(-np.arange(m) / SR / 0.004)
        k += rng.uniform(0.035, 0.07)
    save("typewriter", x, 0.55)


def zip_(d=0.25):
    t = t_(d)
    f = 400 + 2400 * (t / d)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.4 + bp(rng.standard_normal(len(t)), 2000, 8000) * 0.4
    save("zip", x * np.sin(np.pi * t / d), 0.5)


def gulp():
    d = 0.35; t = t_(d)
    f = 300 * np.exp(-t / 0.1) + 120
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.12)
    save("gulp", x, 0.6)


if __name__ == "__main__" and "--v3" in __import__("sys").argv:
    pour(); clink(); vacuum(); click(); whack(); ahooga(); ding(); shatter(); slot(); typewriter(); zip_(); gulp()
    print(sorted(os.listdir(OUT)))
