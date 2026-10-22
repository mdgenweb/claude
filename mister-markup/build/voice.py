"""Generate the fully-AI voice track with Kokoro (Apache-2.0, commercial use OK).

Mister Markup = an original blended voice (not a clone of anyone); Footnote = a dry British voice.
Writes audio/lines/<id>.wav (44.1 kHz, processed), audio/voice.wav (full track) and audio/timeline.json
(start/end per line + per-frame mouth envelope at 24 fps).
"""
import json, os, subprocess, sys
import numpy as np, soundfile as sf
from kokoro_onnx import Kokoro

HERE = os.path.dirname(__file__)
sys.path.insert(0, HERE)
from script import LINES

ROOT = os.path.join(HERE, "..")
LDIR = os.path.join(ROOT, "audio", "lines")
os.makedirs(LDIR, exist_ok=True)
SR = 44100
FPS = 24
LEAD_IN = 0.35  # seconds of room tone before first word

k = Kokoro(os.path.join(ROOT, "assets/kokoro-v1.0.onnx"), os.path.join(ROOT, "assets/voices-v1.0.bin"))
MARKUP = 0.6 * k.get_voice_style("am_michael") + 0.25 * k.get_voice_style("am_fenrir") + 0.15 * k.get_voice_style("bm_george")
VOICES = {"M": dict(voice=MARKUP, speed=1.12, lang="en-us"), "F": dict(voice="bm_fable", speed=1.06, lang="en-gb")}

# vintage optical-soundtrack chain (light) — and a heavier "1953 radio" chain for the flashback line
CHAIN = {
    "main": "highpass=f=95,lowpass=f=7800,equalizer=f=300:t=q:w=1.2:g=-2,equalizer=f=3000:t=q:w=1.0:g=2,"
            "acompressor=threshold=-20dB:ratio=3:attack=8:release=120:makeup=2,asoftclip=type=tanh:output=0.95,"
            "aecho=0.85:0.6:23|41:0.12|0.07",
    "radio": "highpass=f=350,lowpass=f=3200,equalizer=f=1500:t=q:w=1.0:g=4,"
             "acompressor=threshold=-24dB:ratio=5:attack=5:release=80:makeup=4,asoftclip=type=hard:output=0.8,"
             "aecho=0.8:0.5:30:0.2",
}


def ff_process(src, dst, chain):
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", src, "-af", chain + f",aresample={SR}", "-ac", "1", dst], check=True)


def trim_silence(a, sr, thr=0.012, pad=0.04):
    idx = np.where(np.abs(a) > thr)[0]
    if len(idx) == 0:
        return a
    s = max(0, idx[0] - int(pad * sr)); e = min(len(a), idx[-1] + int(pad * sr * 2))
    return a[s:e]


def main():
    timeline, pieces, t = [], [], LEAD_IN
    for lid, spk, txt, cap, gap, fx in LINES:
        v = VOICES[spk]
        audio, sr = k.create(txt, **v)
        audio = trim_silence(audio, sr)
        raw = os.path.join(LDIR, f"{lid}_raw.wav")
        out = os.path.join(LDIR, f"{lid}.wav")
        sf.write(raw, audio, sr)
        ff_process(raw, out, CHAIN[fx])
        a, _ = sf.read(out)
        t += gap
        timeline.append({"id": lid, "spk": spk, "start": round(t, 3), "end": round(t + len(a) / SR, 3), "caption": cap, "fx": fx})
        pieces.append((t, a))
        t += len(a) / SR
    total = t + 0.6
    track = np.zeros(int(total * SR) + SR)
    for st, a in pieces:
        i = int(st * SR); track[i:i + len(a)] += a
    track = track[: int(total * SR)]
    sf.write(os.path.join(ROOT, "audio", "voice.wav"), track.astype(np.float32), SR)
    # mouth envelopes per speaker at FPS
    nfr = int(total * FPS) + 1
    env = {"M": np.zeros(nfr), "F": np.zeros(nfr)}
    hop = SR // FPS
    for (st, a), ln in zip(pieces, timeline):
        for f in range(int(st * FPS), int((st + len(a) / SR) * FPS) + 1):
            seg = track[f * hop:(f + 1) * hop]
            if len(seg):
                env[ln["spk"]][f] = float(np.sqrt(np.mean(seg ** 2)))
    for s in env:
        m = env[s].max() or 1
        env[s] = (env[s] / m).round(3).tolist()
    json.dump({"total": round(total, 3), "lines": timeline, "env": env, "fps": FPS},
              open(os.path.join(ROOT, "audio", "timeline.json"), "w"))
    for ln in timeline:
        print(f'{ln["start"]:6.2f}-{ln["end"]:6.2f} {ln["spk"]} {ln["id"]}')
    print("TOTAL", round(total, 2), "s")


if __name__ == "__main__":
    main()
