# Mister Markup — faceless AI-cartoon channel

Episode 001: "Why is movie theater popcorn so expensive?" — 1950s black-and-white cartoon where only money is green.

- `out/mister_markup_racket001_preview_720p.mp4` — preview (the 1080x1920 master is >100 MB, so it is not in git; rebuild below)
- `out/cover.png` — cover / thumbnail
- `out/POST_COPY.md` — caption, hashtags, pinned sources comment, posting settings, rights notes
- `build/` — everything that makes the video: `script.py` (fact-checked script + sources), `art.py` (vector characters, props, sets),
  `render.py` (animation timeline), `voice.py` (fully-AI voice), `sfx.py` (original music + SFX), `mix.py` (mix + -14 LUFS master),
  `asr_check.py` / `asr_final.py` (speech-recognition QA), `cover.py`

## Rebuild
```
pip install kokoro-onnx soundfile skia-python fonttools brotli sherpa-onnx pillow numpy
apt-get install -y libegl1 libgl1 ffmpeg            # Skia needs EGL
# voice model (Apache-2.0)
curl -L -o assets/kokoro-v1.0.onnx https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx
curl -L -o assets/voices-v1.0.bin  https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin
# optional QA model
curl -L https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-whisper-tiny.en.tar.bz2 | tar xj -C assets
python3 build/sfx.py && python3 build/voice.py && python3 build/render.py && python3 build/mix.py && python3 build/cover.py
```
Fonts (SIL OFL) are in `assets/fonts/*.ttf`.
