import os, sys, json, re, difflib, subprocess
import numpy as np, soundfile as sf, sherpa_onnx
sys.path.insert(0, os.path.dirname(__file__))
from script import LINES
TL = json.load(open("audio/timeline.json")); LN = {l["id"]: l for l in TL["lines"]}
subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", "out/MisterMarkup_Racket001_Popcorn_v3_FINAL_9x16.mp4", "-ac", "1", "-ar", "16000", "audio/final16k.wav"], check=True)
a, sr = sf.read("audio/final16k.wav")
M = "assets/sherpa-onnx-whisper-tiny.en/"
rec = sherpa_onnx.OfflineRecognizer.from_whisper(encoder=M + "tiny.en-encoder.int8.onnx", decoder=M + "tiny.en-decoder.int8.onnx", tokens=M + "tiny.en-tokens.txt", num_threads=4)
norm = lambda s: re.sub(r"[^a-z0-9 ]", "", s.lower().replace("-", " ")).split()
tot = 0
for lid, spk, txt, *_ in LINES:
    l = LN[lid]; seg = a[int((l["start"] - 0.05) * sr): int((l["end"] + 0.1) * sr)].astype(np.float32)
    st = rec.create_stream(); st.accept_waveform(sr, seg); rec.decode_stream(st)
    r = difflib.SequenceMatcher(None, norm(txt), norm(st.result.text)).ratio(); tot += r
    if r < 0.85: print(f"{r:.2f} {lid}: {st.result.text}")
print("mean intelligibility vs script:", round(tot / len(LINES), 3))
