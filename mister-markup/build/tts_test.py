import numpy as np, soundfile as sf, time
from kokoro_onnx import Kokoro
k = Kokoro("assets/kokoro-v1.0.onnx", "assets/voices-v1.0.bin")
print([v for v in k.get_voices() if v.startswith(('am_','bm_'))])
line = "Lemme let ya in on a little racket, pal. This popcorn costs the theater well under a dollar. They charge you NINE."
def blend(spec):
    return sum(w * k.get_voice_style(v) for v, w in spec)
t=time.time()
style = blend([("am_michael",0.6),("am_fenrir",0.25),("bm_george",0.15)])
a, sr = k.create(line, voice=style, speed=1.08, lang="en-us")
sf.write("audio/test_markup.wav", a, sr); print("markup", len(a)/sr, "s", time.time()-t)
a, sr = k.create("Ahem. It varies by film, and by week. Source is on screen.", voice="bm_fable", speed=1.05, lang="en-gb")
sf.write("audio/test_footnote.wav", a, sr); print("footnote", len(a)/sr, "s", sr)
