"""QA: transcribe every generated line with Whisper tiny.en (sherpa-onnx) and compare to the script."""
import os, sys, json, re, difflib
import numpy as np, soundfile as sf, sherpa_onnx
sys.path.insert(0, os.path.dirname(__file__))
from script import LINES
M = "assets/sherpa-onnx-whisper-tiny.en/"
rec = sherpa_onnx.OfflineRecognizer.from_whisper(encoder=M + "tiny.en-encoder.int8.onnx", decoder=M + "tiny.en-decoder.int8.onnx",
                                                 tokens=M + "tiny.en-tokens.txt", language="en", task="transcribe", num_threads=4)
def norm(s): return re.sub(r"[^a-z0-9 ]", "", s.lower().replace("-", " ")).split()
which = sys.argv[1] if len(sys.argv) > 1 else "raw"
tot = 0
for lid, spk, txt, *_ in LINES:
    a, sr = sf.read(f"audio/lines/{lid}{'_raw' if which=='raw' else ''}.wav")
    if a.ndim > 1: a = a.mean(1)
    if sr != 16000:
        import math
        n = int(len(a) * 16000 / sr); a = np.interp(np.linspace(0, len(a) - 1, n), np.arange(len(a)), a)
    st = rec.create_stream(); st.accept_waveform(16000, a.astype(np.float32)); rec.decode_stream(st)
    hyp = st.result.text.strip()
    r = difflib.SequenceMatcher(None, norm(txt), norm(hyp)).ratio()
    tot += r
    flag = "  " if r > 0.8 else "!!"
    print(f"{flag} {r:.2f} {lid:12s} | {hyp}")
print("mean", round(tot / len(LINES), 3))
