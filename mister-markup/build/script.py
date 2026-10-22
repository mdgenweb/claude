"""Episode 001 — "Why is movie theater popcorn so expensive?" (fact-checked 2026-10-22).

Each line: id, speaker (M = Mister Markup, F = Footnote), spoken text (written for TTS),
caption text (what appears on screen; money words wrapped in *asterisks* render green),
gap = silence before the line (s), fx = voice treatment.
Sources: AMC Entertainment FY2025 10-K (film exhibition costs 48.1% of admissions; F&B costs 19.6% of
F&B revenue), Cinemark FY2025 10-K (film rentals & advertising 56.8%; concession supplies 19.6%),
Richard McKenzie (UC Irvine) ~$0.90 raw cost vs $8.15 avg large popcorn (~800% markup),
Huber, Payne & Puto (1982) J. Consumer Research (decoy effect),
AMC Stubs Insider (free large popcorn refill, same day).
"""

LINES = [
    # id, spk, tts text, caption, gap, fx
    ("hook1", "M", "This whole tub of popcorn, bucket and all, costs the theater about a buck.", "THIS WHOLE TUB, BUCKET AND ALL, COSTS THE THEATER ABOUT A *BUCK.*", 0.25, "main"),
    ("hook2", "M", "You pay nine!", "YOU PAY *NINE!*", 0.12, "main"),
    ("hook3", "M", "And pal... it ain't even the popcorn's fault.", "AND PAL... IT AIN'T EVEN THE POPCORN'S FAULT.", 0.2, "main"),
    ("racket", "M", "Lemme let ya in on a little racket.", "LEMME LET YA IN ON A LITTLE RACKET.", 0.15, "main"),
    ("greed", "M", "You figure it's greed? Sure, a little. But follow the green.", "YOU FIGURE IT'S GREED? SURE, A LITTLE. BUT FOLLOW THE *GREEN.*", 1.45, "main"),
    ("ticket", "M", "Your ticket money? In the U.S., about half goes straight back to the studio.", "YOUR *TICKET* *MONEY?* IN THE U.S., ABOUT *HALF* GOES STRAIGHT BACK TO THE STUDIO.", 0.2, "main"),
    ("blockbuster", "M", "Blockbusters? Even more.", "BLOCKBUSTERS? EVEN *MORE.*", 0.15, "main"),
    ("fn_half", "F", "Ahem. About half. It's in the chains' own annual reports.", "AHEM. ABOUT HALF. IT'S IN THE CHAINS' OWN ANNUAL REPORTS.", 0.2, "main"),
    ("crumbs", "M", "Fine, fine. So where does the theater make its real dough?", "FINE, FINE. SO WHERE DOES THE THEATER MAKE ITS REAL *DOUGH?*", 0.15, "main"),
    ("counter", "M", "Right here. The snack bar. That tub? About a buck to make.", "RIGHT HERE. THE SNACK BAR. THAT TUB? ABOUT A *BUCK* TO MAKE.", 0.25, "main"),
    ("soda", "M", "The soda? Five parts fizzy water, one part syrup, over ice.", "THE SODA? FIVE PARTS FIZZY WATER, ONE PART SYRUP, OVER ICE.", 0.15, "main"),
    ("twenty", "M", "At AMC and Cinemark, the snacks cost 'em about twenty cents of every snack dollar.", "AT AMC & CINEMARK, THE SNACKS COST 'EM ABOUT *20¢* OF EVERY SNACK *DOLLAR.*", 0.15, "main"),
    ("sneaky", "M", "Now, the sneaky part. See the medium?", "NOW, THE SNEAKY PART. SEE THE MEDIUM?", 0.3, "main"),
    ("bait", "M", "That one ain't for you. It's bait. It's just a little cheaper than the large, so the large feels like a steal.", "THAT ONE AIN'T FOR YOU. IT'S BAIT. JUST A LITTLE CHEAPER THAN THE LARGE...", 0.15, "main"),
    ("decoy", "M", "Researchers call it the decoy effect.", "RESEARCHERS CALL IT THE DECOY EFFECT.", 0.1, "main"),
    ("invented", "M", "I invented that trick, back in nineteen fifty-three.", "I INVENTED THAT TRICK, BACK IN 1953.", 0.35, "radio"),
    ("fn_1982", "F", "He did not. Researchers described it in nineteen eighty-two.", "HE DID NOT. RESEARCHERS DESCRIBED IT IN 1982.", 0.25, "main"),
    ("poll", "M", "Small, medium, or large? Be honest. Comments.", "SMALL, MEDIUM, OR LARGE? BE HONEST. COMMENTS.", 0.35, "main"),
    ("verdict", "M", "So... what's the verdict?", "SO... WHAT'S THE VERDICT?", 0.5, "main"),
    ("steep", "M", "Steep! But that snack counter keeps a lot of theaters' lights on.", "STEEP! BUT THAT SNACK COUNTER KEEPS A LOT OF THEATERS' LIGHTS ON.", 1.9, "main"),
    ("promove", "M", "Pro move: check your theater's app. Some chains do free refills on big popcorns.", "PRO MOVE: CHECK YOUR THEATER'S APP. SOME CHAINS DO FREE REFILLS ON BIG POPCORNS.", 0.25, "main"),
    ("racket_out", "M", "Now ya know the racket. Read the fine print, pal.", "NOW YA KNOW THE RACKET. READ THE FINE PRINT, PAL.", 0.3, "main"),
    ("next", "F", "Next reel: why hotel check-in is at three.", "NEXT REEL: WHY HOTEL CHECK-IN IS AT 3.", 0.2, "main"),
]

RECEIPT = [
    # (line, value, line id it appears during, seconds after that line starts)
    ("TICKET $ > STUDIO", "~50%", "ticket", 1.4),
    ("POPCORN TUB COST", "~$1", "counter", 1.6),
    ("SODA (5:1 + ICE)", "<$1", "soda", 1.0),
    ("FOOD COST / $1", "~$0.20", "twenty", 2.2),
    ("DECOY MEDIUM", "BAIT", "bait", 1.0),
]
RECEIPT_TOTAL = "~800%"

SOURCES_PINNED = """Sources (checked Oct 2026):
- AMC Entertainment FY2025 10-K: U.S. film exhibition costs 51.2% of admissions (48.1% worldwide); food & beverage costs 19.6% of F&B revenue
- Cinemark FY2025 10-K: film rentals & advertising 56.8% of admissions; concession supplies 19.6% of concession revenue
- Economist Richard McKenzie (UC Irvine) estimate: ~$0.90 raw cost for a large tub vs ~$8.15 average price (~800% markup)
- Soda: bag-in-box fountain syrup is mixed ~5 parts water to 1 part syrup
- Decoy effect: Huber, Payne & Puto (1982), Journal of Consumer Research
- Refills: AMC Stubs Insider (free large popcorn refill) and Cinemark (XL popcorn same-day refill). Check your own chain's app.
Gross margins are before staff and rent. Example prices in the video are illustrative. General info, not financial advice."""
