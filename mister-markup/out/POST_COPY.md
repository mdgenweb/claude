# Mister Markup — Racket #001: "Why is movie popcorn so expensive?"

**File to upload:** `out/mister_markup_racket001_popcorn.mp4` (1080x1920, 24 fps, 81.8 s, H.264 + AAC, mastered to -14 LUFS)
**Cover:** `out/cover.png` · **Quick preview:** `out/mister_markup_racket001_preview_720p.mp4`

## Title / on-screen keyword
Why is movie theater popcorn so expensive?

## Caption (TikTok / Reels / Shorts)
Why is movie theater popcorn so expensive? 🍿 A whole tub costs the theater about a buck — here's the racket nobody tells you (it's not just greed). Small, medium or large? Be honest 👇

#moviepopcorn #whyisitsoexpensive #economics #moneytok #pricing #movietheater #amc #funfacts #learnontiktok #animation #retrocartoon #mistermarkup

## Pinned comment
Sources (checked Oct 2026):
- AMC Entertainment FY2025 10-K: U.S. film exhibition costs 51.2% of admissions (48.1% worldwide); food & beverage costs 19.6% of F&B revenue
- Cinemark FY2025 10-K: film rentals & advertising 56.8% of admissions; concession supplies 19.6% of concession revenue
- Economist Richard McKenzie (UC Irvine) estimate: ~$0.90 raw cost for a large tub vs ~$8.15 average price (~800% markup)
- Soda: bag-in-box fountain syrup is mixed ~5 parts water to 1 part syrup
- Decoy effect: Huber, Payne & Puto (1982), Journal of Consumer Research
- Refills: AMC Stubs Insider (free large popcorn refill) and Cinemark (XL popcorn same-day refill). Check your own chain's app.
Gross margins are before staff and rent. Example prices in the video are illustrative. General info, not financial advice.

## Posting settings (important)
- TikTok: turn ON "AI-generated content" (voices and some art are AI-made). Instagram: turn on "AI info". YouTube: Altered/synthetic = No (clearly animated) and add to the description: "Original animated characters; voices are AI-generated designs, not clones."
- YouTube audience: "No, it's not made for kids."
- Upload natively to each platform (no watermarks). Shorts and Reels both accept 81 s.

## What's in it / rights
- Characters, art, animation and editing: original, drawn in code for this channel (no third-party characters).
- Voice: fully AI, Kokoro-82M (Apache-2.0, commercial use allowed). Mister Markup = an original blended voice (not a clone of anyone); Footnote = Kokoro "bm_fable".
- Music + all sound effects: synthesized from scratch for this video (no samples, no Content ID risk).
- Fonts: Anton, Bungee, Alfa Slab One, Courier Prime, Limelight, Permanent Marker (all SIL Open Font License).

## Rebuild
```
python3 build/sfx.py      # music + SFX
python3 build/voice.py    # voice lines + timeline
python3 build/render.py   # video (frames.mp4)
python3 build/mix.py      # mix, -14 LUFS, final mp4
```
