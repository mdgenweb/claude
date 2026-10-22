"""Mix voice + original music + SFX + projector bed, master to -14 LUFS, mux with the rendered video."""
import json, os, subprocess, sys
import numpy as np, soundfile as sf

HERE = os.path.dirname(__file__)
sys.path.insert(0, HERE)
import render3 as R
from script import RECEIPT

ROOT = os.path.join(HERE, "..")
SR = 44100
A = lambda p: os.path.join(ROOT, "audio", p)
N = int(R.TOTAL * SR)


def load(p):
    x, sr = sf.read(p)
    if x.ndim > 1:
        x = x.mean(1)
    assert sr == SR, (p, sr)
    return x


def lp(x, fc):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1 / np.sqrt(1 + (f / fc) ** 4)
    return np.fft.irfft(X, len(x))


voice = np.zeros(N); v = load(A("voice.wav"))[:N]; voice[:len(v)] = v

# ---- music with ducking, flashback muffle, drumroll dip and a fade at the end
mus = load(A("sfx/music.wav"))
reps = int(np.ceil(N / len(mus))) + 1
music = np.tile(mus, reps)[:N]
gain = np.full(N, 0.25)
for l in R.TL["lines"]:
    a, b = int((l["start"] - 0.08) * SR), int((l["end"] + 0.12) * SR)
    gain[max(0, a):b] = 0.06
# smooth the gain curve (~120 ms)
k = int(0.12 * SR)
gain = np.convolve(gain, np.ones(k) / k, mode="same")
ka, kb = int(R.S("invented") * SR) - 4000, int(R.E("invented") * SR) + 4000
music[ka:kb] = lp(music[ka:kb], 900) * 1.6
dip_a, dip_b = int((R.T_TOTAL - 1.4) * SR), int((R.T_STAMP + 0.2) * SR)
gain[dip_a:dip_b] *= 0.25
fade = int(0.9 * SR)
gain[-fade:] *= np.linspace(1, 0, fade)
gain[: int(0.3 * SR)] *= np.linspace(0, 1, int(0.3 * SR))
music *= gain
# ---- SFX cues (exported by the v2 edit)
sfx = np.zeros(N)
CACHE = {}


def cue(name, t, g=0.6):
    if name not in CACHE:
        CACHE[name] = load(A(f"sfx/{name}.wav"))
    x = CACHE[name] * g
    i = int(t * SR)
    if i < 0 or i >= N:
        return
    sfx[i:i + len(x)] += x[: N - i]


for name, t, g in R.SFX_CUES:
    cue(name, t, g)


bed = load(A("sfx/crackle_bed.wav"))
bed = np.tile(bed, 2)[:N] * 0.15

mix = voice * 1.0 + music + sfx * 0.55 + bed
mix /= max(1.0, np.max(np.abs(mix)) / 0.95)
pre = A("mix_pre.wav")
sf.write(pre, mix.astype(np.float32), SR)

# ---- two-pass loudnorm to -14 LUFS / -1.5 dBTP
r = subprocess.run(["ffmpeg", "-v", "info", "-i", pre, "-af", "loudnorm=I=-14:TP=-1.5:LRA=11:print_format=json", "-f", "null", "-"],
                   capture_output=True, text=True)
js = r.stderr[r.stderr.rindex("{"): r.stderr.rindex("}") + 1]
m = json.loads(js)
af = (f"loudnorm=I=-14:TP=-1.5:LRA=11:measured_I={m['input_i']}:measured_TP={m['input_tp']}:measured_LRA={m['input_lra']}:"
      f"measured_thresh={m['input_thresh']}:offset={m['target_offset']}:linear=true,aresample=48000")
final_wav = A("mix_final_v3.wav")
subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", pre, "-af", af, "-ar", "48000", final_wav], check=True)
print("measured input", m["input_i"], "LUFS")

out = os.path.join(ROOT, "out", "MisterMarkup_Racket001_Popcorn_v3_FINAL_9x16.mp4")
subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", os.path.join(ROOT, "out", "frames_v3.mp4"), "-i", final_wav, "-map", "0:v", "-map", "1:a",
                "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart", out], check=True)
print("wrote", out)
