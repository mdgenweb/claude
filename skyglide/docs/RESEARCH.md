# Research: +1 Stone Skipping (reference) → Sky Glide (our game)

This document has three parts:

1. **Screenshot forensics** of the 8 reference screenshots supplied with the brief.
2. **The web research report** produced by a multi-agent research pass:
   * 4 topic agents, a completeness critic, 2 follow-up agents and a synthesiser;
   * 277 tool uses, dated 2026-10-08;
   * an evidence table and an uncertainty register.
3. **Reconstruction decisions**: how each finding maps into Sky Glide, and what we deliberately changed.

Confidence labels are used throughout:

| Label | Meaning |
|---|---|
| CONFIRMED | An official page, or two or more independent sources |
| OBSERVED | Visible in the screenshots, or a dated stats snapshot |
| LIKELY | A single or weak source, or a strong inference |
| UNKNOWN | Not established |
| ORIGINAL DESIGN | Our own choice |

Research limits:

* Direct page fetches (roblox.com, Rolimons, Sportskeeda) were blocked by the environment's network proxy, so facts from those pages come from search-result snippets.
* No Roblox client was available to play the game.

Names of the reference's items, zones and pets appear below **only as research references**. Sky Glide uses its own names, art and numbers.

---

## Part 1: Screenshot forensics (OBSERVED)

| # | Frame | What it shows |
|---|---|---|
| 1 | Spawn / training area (World 1) | See "Frame 1" below |
| 2 | World 2 hub | **Lava/volcano theme:** lava falls, a red dragon statue on a pillar, sand-and-stone checker floor, and an orange chevron path. "Hacked Admin Egg" is priced 70 with a Robux-style icon. Neon training strips sit on the left. |
| 3 | World 3 hub | **Pirate/beach theme:** a "WORLD 3" skull flag, a waterfall portal, barrels and palms. The "Hacked Admin Egg 70" appears again. The stone shelves on the right read +62.5K … +2.5M Skill with Wins prices in the hundreds of thousands to millions. |
| 4 | Throw Zone (World 1) | See "Frame 4" below |
| 5 | Training pad close-up | The pad billboard reads "0 (rebirth icon) UNLOCKED 1x SKILL". A small **AUTO** toggle sits on the pad next to the player. The pad is a small brown tiled square beside a pond. |
| 6 | Flight | The camera follows the thrown stone low over the turquoise channel. A yellow **"144 m"** distance counter sits under AUTO THROW, and the "Palm Beach" sign arch with palms is ahead. The character is not in frame. |
| 7 | Stone pedestal shop | See "Frame 7" below |
| 8 | Multiplier pad row | Long coloured strips. 1x SKILL (0 rebirths, UNLOCKED), 4x SKILL (2), 10x SKILL (4) and 20x SKILL (6) are LOCKED. "ALL WORLDS" pads 3x / 15x / 50x SKILL cost R$39 / 99 / 239. |

**Frame 1: spawn / training area (World 1)**

* **Left menu:** 2-column tiles reading Shop, Rebirth "100%", Pets, Trails, Inventory, Gifts (red "1" badge).
* **Top centre:** red "AUTO THROW / ONLY R$10".
* **Right side:** Starter Pack (unicorn-cat pet), "+2x SKILL ONLY 2" and "2x WINS ONLY 25".
* **Bottom HUD:**
  * "⚡241 SKILL" on the left and "x1 Multiplier" on the right;
  * a blue level bar reading "Level 20 / MAX LEVEL";
  * three Skill packs: "+10K" (gold, R$5), "+100K" (red, R$20) and "+1M" (rainbow, R$40).
* **Bottom left:** rebirth icon "0", trophy "1K" (Wins), "Friend Boost +0%" with a green +.
* **World:** pads labelled "0 UNLOCKED 1x SKILL", "2 LOCKED 4x SKILL" and "4 … SKILL". Green checker grass, brown checker cliffs, the turquoise channel at the left, and the "Palm Beach" sign in the distance.

**Frame 4: Throw Zone (World 1)**

* A yellow tiled area with huge "THROW ZONE" letters painted on the floor.
* A green **THROW** button floats above the player.
* A straight channel runs between checker walls, with "Palm Beach" ahead.
* **HUD:** "25.29K SKILL", "x5 Multiplier", "Level 50 3.07K / 4.05K", Rebirth "83%", rebirth counter "2", Wins "12K".

**Frame 7: stone pedestal shop**

* **Front row:** "UNLOCKED +1 Skill 0 Wins" (grey stone), "+3 Skill 2 Wins" (shell), a starfish (partly hidden), and "+30 Skill 150 Wins" (wood slice).
* **Back row:** +75, +200, +500, +1.25K and +3.5K Skill.
* **Phoenix Relic:** on a golden pedestal, labelled "STOCK: 997/1000", "ALWAYS 125% BETTER" and "ONLY R$199".

**Derived from the frames**

These are LIKELY readings, used for tuning:

* The bottom-left pink/blue counter is the **rebirth count**: the same icon appears on the pad gates.
* **Rebirth %** = level / cap: 50/60 = 83%. The cap is 20 at 0 rebirths and 60 at 2.
* **"xN Multiplier"** is x1 at 0 rebirths and x5 at 2. We model it as 1 + 2 x rebirths.
* **Level vs Skill:** Level 50 at 25.29K Skill showing "3.07K/4.05K" fits geometric level thresholds of about 1.18x per level, filled by Skill. That is our `Economy.SkillForLevel`.
* **Visual style:** voxel/checker, saturated primaries, chunky rounded font with heavy dark strokes, large touch-sized tiles. This points to a mobile-first HUD.

---

## Part 2: Web research report


Prepared 2026-10-08. Target: "+1 Stone Skipping" by Meow Labs, place id 111543903102439, https://www.roblox.com/games/111543903102439/1-Stone-Skipping

**How to read this report**
- **Confidence labels:**
  - CONFIRMED: an official page or two or more independent sources.
  - OBSERVED: seen in the 8 user screenshots, or a dated stats snapshot.
  - LIKELY: a single source, a weak source, or a strong inference.
  - UNKNOWN: not established.
- `(E#)` refers to a row in the Evidence Table (section 8).
- **Research limits:**
  - The roblox.com, Rolimons and Sportskeeda pages were known only from search-result snippets. Direct fetches failed with DNS or proxy errors.
  - The shared WebSearch budget ran out during the final verification pass. Claims that rest only on those pages are rated no higher than the snippets support.
- **Fan sites count as one source:** five fan sites (stoneskipping.wiki, stone-skipping.wiki, stoneskippingwiki.top, 1stoneskipping-wiki.wiki, lootwiki.com) appear to be generated from the same YouTube footage and captions. They are treated as one source group. Agreement among them never makes a claim CONFIRMED.
- **Names:** item, zone, pet and product names (Phoenix Relic, Palm Beach, Pebble Pup and so on) belong to the original game. They are recorded only for reference. An inspired game should use its own names, art and numbers.

---

## 1. Game identity & metadata

| Field | Value | Date | Confidence | Ref |
|---|---|---|---|---|
| Title / place id | "+1 Stone Skipping", place 111543903102439 | n/d | CONFIRMED | E1 |
| Publisher | Roblox community "Meow Labs" (id 207366578) | n/d | CONFIRMED | E1 |
| Group owner | iPlayfade | n/d | LIKELY | E2 |
| Group members | about 1,544,386 (community page snippet); about 1,423,572 (older Rolimons listing) | n/d | LIKELY | E2 |
| Universe id | 10765298801 (from a Creator Exchange URL) | n/d | LIKELY | E3 |
| Created / released | Saturday 2026-09-05 | src 2026-10-06 | CONFIRMED | E4 |
| Last updated | 2026-10-06 (Earnaldo, read from the Roblox API). The fan-wiki value "2026-09-30" is a stale snapshot. | 2026-10-06 | LIKELY | E5 |
| Genre | Simulation, sub-genre Incremental Simulator | n/d | CONFIRMED | E11 |
| Max players per server | 10 | n/d | CONFIRMED | E10 |
| Price | Free to play | 2026-10 | LIKELY | E14 |
| Platforms | Not stated anywhere. The HUD looks designed for touch. | n/a | UNKNOWN | E89 |

**Stats snapshots (OBSERVED; each is a single point in time)**

| Date | Source | Playing | Visits | Favorites | Likes | Other |
|---|---|---|---|---|---|---|
| 2026-10-06 | Earnaldo | 30,068 | 15,468,262 | 585,875 | 96.5% | none |
| ~2026-10-01 | Rolimons | 31,388 | 12,584,773 | 483,835 | not given | all-time peak 75,257 CCU |
| n/d | Creator Exchange | 34.69K | not given | not given | 97% | none |

Two figures are left out of the table:
- **RobloxGo snapshot (E9):** labelled 2026-09-28 with 5,284 playing and 679,322 visits. That date cannot be right if Rolimons showed 12.58M visits three days later.
- **Earnaldo's "+171% across 27 checks" (E8):** single source, so UNKNOWN.

**Official description:** the gist is CONFIRMED, the exact wording only LIKELY (E12, E13). It says:
- every bounce gives +1 Skill
- you train and level up to throw farther
- farther zones give more Wins
- you unlock better stones and unusual objects, "even a DONUT"
- you collect pets for boosts
- you rebirth

**Update timeline**

| Date | Event | Confidence | Ref |
|---|---|---|---|
| 2026-09-05 | Launch | CONFIRMED | E4 |
| by 2026-09-26 | WORLD3 code listed as working, so World 3 existed by then | LIKELY | E21 |
| early Oct 2026 | WORLD4 code active | LIKELY | E21, E105 |
| 2026-10-03, 12:00 PM ET | World 5 plus the first Admin Abuse event | LIKELY | E17 |
| ~2026-10-07 | WORLD5 code reported as new | LIKELY | E106 |
| 2026-10-10, 16:00 UTC | World 6 plus Admin Abuse scheduled. Teaser: "Something is brewing beyond the volcano" (cat pet in a witch hat) | LIKELY | E18, E19 |
| 2026-10-17 | "Halloween Event" (Earnaldo only) | UNKNOWN | E20 |

From these dates, the game has added roughly one new world per week since launch (derived, LIKELY). No official patch-note text was found.

Two smaller items:
- Meow Labs reportedly releases codes regularly and points players to its Discord (E16, LIKELY).
- Other "+1" titles credited to Meow Labs are unverified (E15, UNKNOWN).

---

## 2. Core loop as best understood

```
Train Skill (pads / ponds)  ─┐
                             ├─► THROW down the river ─► stone skips (each bounce = +X Skill)
Skill from bounces ◄─────────┘          │
                                        ▼
                         stone sinks ─► Wins by distance / zone reached
                                        │
              ┌─────────────────────────┼──────────────────────────┐
              ▼                         ▼                          ▼
     buy better throwable        buy / hatch pet eggs        level cap reached ─► REBIRTH
     (higher +Skill/bounce)      (xN Skill multipliers)      (reset Level+Skill, permanent mult,
                                                              higher cap, stronger free pads)
                                        │
                                        ▼
               throw reaches river end ─► cutscene + portal ─► NEXT WORLD (new river, stones, eggs)
```

1. **Gain Skill** from two sources:
   - Training areas and pads beside small ponds, where the avatar trains on its own (E40, E41).
   - Every water bounce of a thrown object, which pays that object's "+X Skill" (E27).
2. **Throw.** Stand in the yellow THROW ZONE at the head of the long river and press the on-screen THROW button (E24, OBSERVED). A meter counter runs while the stone flies (E32).
3. **Earn Wins.** When the stone sinks, Wins are paid according to how far it went, i.e. which zone it reached (E35, CONFIRMED).
4. **Spend Wins** on better throwables (higher Skill per bounce) and on pet eggs (Skill multipliers) (E22, E60–E62, E90–E92).
5. **Level up and rebirth.** Skill fills a level bar. At the level cap, Skill stops growing. Rebirth resets Level and Skill to 1 in exchange for a permanent multiplier and a higher cap. More rebirths unlock stronger free training pads (E52, E41).
6. **Unlock the next world.** When a throw reaches the end of the river, a cutscene plays and a portal opens to the next world (E80, CONFIRMED).

**Throws feed both currencies.** Each bounce pays Skill and the distance pays Wins, so a longer throw yields more of both. This is an inference from E27 and E30 (LIKELY).

**Onboarding:** a spawn banner reads "TUTORIAL: REACH LEVEL 20" (OBSERVED, E48), and the level cap at 0 rebirths is 20 (E49). A player anecdote says the tutorial first asks for about 30 Skill; this is unverified (E46).

**Live-ops layer:** about one new world per week, "Admin Abuse" events with server-wide boosts, and codes tied to milestones (E17, E102, E113).

**Genre context:** the loop follows the standard Roblox simulator and Race Clicker pattern: train a stat, turn distance into Wins, spend Wins on eggs and worlds, then rebirth (E118, E119, LIKELY).

---

## 3. Throw / skip / distance mechanics

### Known (CONFIRMED / OBSERVED)
- **Input:** an on-screen THROW button inside a yellow THROW ZONE pad (E24, OBSERVED). No power, charge or timing bar is visible, and there is no "E" prompt (E25).
- **Distance stat:** Skill is the stat that determines throw distance (E29, CONFIRMED).
- **Distance display:** a live counter in meters, for example "144 m", sits under the Auto Throw button (E32, OBSERVED).
- **Skill per bounce:** each bounce pays the equipped object's +X Skill, +1 for the starter Pebble (E27, CONFIRMED).
- **End of throw:** when the stone sinks, the throw ends and Wins are paid. Farther zones pay more (E35, CONFIRMED).
- **Camera:** it follows the stone down the channel, with the avatar out of frame (E33, OBSERVED).
- **Skill is not shown as meters:** mid-flight the HUD showed 25.29K Skill and x5 while the counter read 144 m, with the Palm Beach sign still ahead (E33, OBSERVED).
- **World unlock:** reaching the river's end opens the next world through a cutscene and portal (E80, CONFIRMED).
- **Auto Throw:** sold as an R$10 HUD offer (E117, OBSERVED). What it actually does is undocumented.

### Reported by a single source or source group (LIKELY)
- **Throw input:** a single press with a deterministic, stat-driven result. There is no aim, power or timing (E25).
- **Skill and skips:** more Skill means more skips before sinking, so the stone goes farther. The outcome is computed from the equipped stone and total Skill (E30).
- **Observed distances:** World 1 throws of 212 m to 1,776 m were recorded (E34). Later zones pay disproportionately more (E36).
- **Secret Throw (E38):**
  - about 1 in 100, rolled at launch
  - plays an anime-style cutscene
  - goes about 3x a normal throw
  - any object can trigger it, including the relic
- **Colossus Throw (E39):**
  - about 1 in 1000
  - a golden giant blesses the avatar, which gains a red aura
  - the object becomes a giant golden coin and can reach the river's end, unlocking the next world
  - Admin Abuse events raise the odds
- **Multipliers on Skill gain:** level, rebirth, pads, pets, Friend Boost and potions (E28).

### Not known (UNKNOWN)
- **The distance function:** how (Skill, stone) maps to bounce count and meters, and how far apart bounces land (E31).
- **Mid-throw Skill:** whether Skill earned during a throw lengthens that same throw.
- **Zones:** Wins per zone or per meter, the meter threshold of each zone, and the river length of each world (E31, E37).
- **Not reported anywhere:**
  - the throw cooldown
  - whether flight is physics-simulated or scripted
  - what Auto Throw does
- **The "1,404 m paid +200 Wins" data point:** it cannot be traced to a specific page (E37).
- **Controls:** anything beyond the THROW button (E26).

### Inferred implementation shape (an inference about the original, not a fact)
There is no player-skill input, and special throws are "rolled at launch". So the original very likely decides the outcome on the server at launch and plays it back as an animation (LIKELY, from E25 and E38). The rebuild will work the same way: the server picks distance, bounce count and the special-throw roll, and the client animates the result.

---

## 4. Progression: Skill, Wins, levels, rebirths, multipliers, training pads

### Currencies and counters

| Item | Role | Confidence | Ref |
|---|---|---|---|
| Skill | Core stat that drives distance. Earned per bounce and on pads. Fills the level bar. Reset to 1 on rebirth. | CONFIRMED | E27, E29, E52 |
| Wins | Spendable currency. Paid when a throw sinks, scaled by distance. Buys stones and eggs. Robux Wins packs exist. | CONFIRMED (packs LIKELY) | E35, E116 |
| Rebirth count | Bottom-left counter. The screenshot notes first read it as "gems". | OBSERVED | E51 |
| Gems | Not mentioned by any web source. The counter seen in screenshots is the rebirth counter. | UNKNOWN | E51 |

### Levels
- A level bar at the bottom, for example "Level 50 3.07K/4.05K" (E47, OBSERVED).
- Tutorial goal "REACH LEVEL 20" (E48, OBSERVED).
- There is a level cap. Skill stops growing at the cap ("Level 20 MAX LEVEL") (E52, CONFIRMED).
- A fan series of level multipliers (x1.1 at L6 up to x111 at L115) conflicts with the HUD showing x1 at L20 (E58, UNKNOWN).

### Observed HUD data points (OBSERVED, E49, E50)

| Frame | Rebirths | Level | Rebirth button | HUD multiplier | Skill | Wins |
|---|---|---|---|---|---|---|
| A | 0 | 20 (MAX LEVEL) | 100% | x1 | 241 | ~1K |
| B | 2 | 50 (3.07K / 4.05K) | 83% | x5 | 25.29K | ~12K |

The two readings come from different frames, which explains the apparent "241 Skill vs a 3.07K bar" conflict. The frames may also come from different sessions.

### Rebirth
- **Effects:** resets Level and Skill to 1, grants a permanent Skill multiplier and raises the level cap. The Rebirth button shows a percentage of progress toward the cap (E52, CONFIRMED).
- **What is kept:** stones and pets. Rebirth, pet and stone multipliers stack multiplicatively (E53, LIKELY; Sportskeeda only).
- **Meaning of the percentage:** it is current level divided by required level. 50/60 = 83.3% matches the 83% button, while the XP fraction (75.8%) does not, so rebirth #3 is at L60 (E54, LIKELY, derived).
- **Level requirement schedule (E55):**
  - L20: OBSERVED
  - L40 and L60: LIKELY
  - L80, L100 and L125: UNKNOWN (one unreliable fan site)
  - The pattern 20 x (rebirths + 1) fits the first three.
- **Not known:**
  - the multiplier each rebirth grants (E56, UNKNOWN)
  - whether Wins survive rebirth (E57, UNKNOWN)
  - what the HUD "xN Multiplier" includes: rebirth, level, relic or purchases (E59, UNKNOWN)

### Training
- Training areas sit beside small ponds, where the avatar builds Skill on its own. More rebirths unlock better areas (E40, CONFIRMED).

| Pad | Multiplier | Unlock | Notes | Confidence |
|---|---|---|---|---|
| Free | 1x SKILL | 0 rebirths | "UNLOCKED", with an AUTO toggle | OBSERVED (E41) |
| Free | 4x SKILL | 2 rebirths | badge uses the rebirth icon | OBSERVED (E41) |
| Free | 10x SKILL | 4 rebirths | | OBSERVED (E41) |
| Free | 20x SKILL | 6 rebirths | the fan wiki could not read this value | OBSERVED (E41) |
| "ALL WORLDS" | 3x SKILL | R$39 | owned per pad | OBSERVED (E42) |
| "ALL WORLDS" | 15x SKILL | R$99 | shown LOCKED while 3x and 50x showed UNLOCKED | OBSERVED (E42) |
| "ALL WORLDS" | 50x SKILL | R$239 | | OBSERVED (E42) |

- Rolimons instead lists Golden Training Zone (R$249), Admin Training Zone (R$599) and Koi Training Zone. How these relate to the pads above is unclear (E43, LIKELY).
- The pad Skill rate is not visible anywhere. The "+N Skill" labels on stone pedestals hint that the stone sets the base gain (E45, UNKNOWN).
- Admin Abuse events may add an admin-only treadmill (E44, LIKELY).

### Multipliers known to exist
- Level: shape UNKNOWN
- Rebirth: exists, value UNKNOWN
- Training pads: 1x–20x free, 3x–50x paid
- Equipped stone: +X Skill per bounce
- Pets: xN multipliers
- Phoenix Relic: "125% better" than the best stone
- Friend Boost: LIKELY +10% per friend
- Potions: LIKELY 2x for 10 minutes
- Admin Abuse server boosts
- Robux offers: "2x WINS", "+2x SKILL" and Skill Multiplier products

Only rebirth x pet x stone is reported to stack multiplicatively (E53, LIKELY). How the others combine is unknown.

### Derived XP-curve fit (for tuning only; our own arithmetic, not a reported fact)
Assume the Skill earned since the last rebirth is also the cumulative level XP:
- Frame B: L50 costs 4.05K, and about 25.29K − 3.07K = 22.2K was spent reaching L50.
- Frame A: 241 Skill at the L20 cap.

Both frames fit a per-level XP cost that grows about **16–18% per level**.

---

## 5. Throwables & relics

### World 1 pedestal shop (E60–E62, E64, E65)

| # | Original name | Skill per bounce | Wins cost | Screenshot | Confidence |
|---|---|---|---|---|---|
| 1 | Pebble | +1 | 0 | +1 / 0 (UNLOCKED) | CONFIRMED |
| 2 | Scallop Shell | +3 | 2 | +3 / 2 | CONFIRMED |
| 3 | Ammonite Fossil | +5 | 10 | not seen | LIKELY |
| 4 | Starfish | +12 | 40 | one pedestal reads "+?2 Skill / ?0 Wins" (40 or 60) | LIKELY |
| 5 | Wood Slice | +30 | 150 | +30 / 150 | CONFIRMED |
| 6 | Roof Tile | +75 | 500 | +75, price unreadable | Skill CONFIRMED, price LIKELY |
| 7 | Bottle Cap | +200 | 1,500 | +200, price unreadable | Skill CONFIRMED, price LIKELY |
| 8 | Lucky Coin | +500 | 4,500 | +500 | Skill CONFIRMED, price LIKELY |
| 9 | Hockey Puck | +1,250 | 14,000 | +1.25K | Skill CONFIRMED, price LIKELY |
| 10 | Frisbee | +3,500 | 40,000 | +3.5K | Skill CONFIRMED, price LIKELY |
| R | Phoenix Relic | "Always 125% better than your best Stone" | R$199 | "STOCK 997/1000", "ALWAYS 125% BETTER", "ONLY R$199" | CONFIRMED (stock OBSERVED) |

The screenshot's front row shows only four pedestals (+1, +3, +?2, +30), so the 10-stone list may have been rebalanced (E62, UNKNOWN).

### World 2 ("Pirate World" per Sportskeeda) shop (E66, E67)

| Original name | Skill per bounce | Wins cost | Pirate-hub screenshot |
|---|---|---|---|
| Playing Card | +25K | 60K | not seen |
| Cookie | +37.5K | 150K | not seen |
| Waffle | +62.5K | 400K | faint +62.5K |
| Donut | +100K | 1M | +100K / 1M (match) |
| Watermelon | +150K | 2.5M | +150K / 2.5M (match) |
| Shuriken | +200K | 6M | not seen |
| Runic Tablet | +275K | 20M | faint +275K |
| Meteorite | +375K | 60M | faint +375K |
| Turtle Shell | +500K | 175M | +500K |
| Flying Saucer | +1M | 500M | +1M |
| Phoenix Relic | (relative) | R$199 | not seen |

- **Confidence:** the list itself is LIKELY (Sportskeeda only).
- **Screenshot match:** the pirate-hub frame (the one with the "WORLD 3" flag) independently shows matching Skill/Wins pairs for Donut and Watermelon, and matching Skill values for five more (OBSERVED).
- **Correction:** the earlier note "+50K..+2.5M Skill" most likely misread a Wins price.
- **World order:** the match supports the pirate hub being Sportskeeda's World 2 (LIKELY).

### Other throwable facts
- Stones from earlier worlds stay usable in later worlds (E66, LIKELY).
- The Phoenix Relic is sold in every world (E64, CONFIRMED). No web source mentions its "STOCK 997/1000" cap. Whether the stock is global, per server or decorative is UNKNOWN (E65). "125% better" could mean x1.25 or x2.25 (UNKNOWN).
- **Guide advice (E63, LIKELY):**
  - Frisbee is the best free World 1 item, and Flying Saucer the best free World 2 item.
  - Buy the best stone you can afford before pets.
  - Bottle Cap is the first power spike (it reaches the Mushroom zone).
- A fan wiki mentions "stone cards" shown over their own zone water: a basic stone, a glowing lava rock and a UFO (E68, LIKELY).

### Derived curve shape (our arithmetic from the tables, for tuning)

| | Skill growth per tier | Wins cost growth per tier | Wins per +1 Skill |
|---|---|---|---|
| World 1 | about x2.5 (range x1.7–x3) | about x3 (range x2.9–x5) | rises from ~0.7 to ~11 |
| World 2 | about x1.5 (last step x2) | about x2.4–x3.3 | rises from 2.4 to 500 |

The first World 2 stone (+25K) is about 7x the last World 1 stone (+3.5K).

---

## 6. Map, worlds, zones, UI

### Art & layout (World 1)
- Voxel/checker style with green grass and brown checker cliffs. A long, straight turquoise channel runs from a yellow THROW ZONE, with zone signs hung over the channel (E69, OBSERVED).
- The hub has small ponds for training and the big river for throwing (E23, CONFIRMED).
- **Near spawn:**
  - the stone pedestal shop
  - a Phoenix Relic pedestal with a banner
  - the training pad row (E41, E60, E64)

### Worlds

| World | Theme / identity | Evidence | Confidence |
|---|---|---|---|
| 1 | Grass/voxel river. The fan wiki calls it "Starting river"; no official name. | E69, E73 | theme OBSERVED, name LIKELY |
| 2 | "Pirate World" per Sportskeeda and a fan wiki ("Pirate World unlocked"), with a Robux Pirate Egg | E72 | LIKELY |
| ? | Pirate/beach hub with a "WORLD 3" skull flag, a waterfall portal and barrels. Its stone shop matches Sportskeeda's World 2 list. | E71, E67 | theme OBSERVED |
| ? | Lava/volcano hub with a red dragon statue and lava falls; the Hacked Admin Egg is sold here | E70, E94 | theme OBSERVED, number UNKNOWN |
| 3–5 | Themes and unlock requirements are not documented | none | UNKNOWN |
| 6 | Scheduled for 2026-10-10. Halloween hints; teaser says "beyond the volcano". | E18, E19 | LIKELY |

**World-order conflict.**
- The screenshot notes labelled lava as World 2 and pirate as World 3.
- The web sources say pirate is World 2.
- **Leading hypothesis (LIKELY at best, unverified):**
  - pirate is World 2
  - the "WORLD 3" flag and waterfall mark the portal onward
  - lava/volcano is a later world; the World 6 teaser ("beyond the volcano") suggests it is the latest world before World 6, possibly World 5

The order should not be treated as settled. Five worlds are live as of 2026-10-08 (E17, LIKELY). One fan site claims World 4 is only a zone tier (E84, UNKNOWN).

### World unlock
- A throw that reaches the river's end triggers a cutscene and opens a portal (E80, CONFIRMED). No source reports a Wins or Robux price, or a rebirth gate, for a portal (E83, UNKNOWN).
- **Thresholds:** about 100M Skill for World 2 and about 400B Skill for World 3 (E81, LIKELY, Sportskeeda only). The same source also says "100 million distance mark".
- **Unit:** the game counts Skill in K/M units and shows distance on a separate meter counter, so "100M" most plausibly means Skill (E82, LIKELY).
- A Colossus Throw can also carry the object to the river's end (E39, LIKELY).

### Zones (World 1)

| Order | Zone | Evidence | Confidence |
|---|---|---|---|
| 1 | Palm Beach | Sign over the channel, visible from spawn and the THROW ZONE; subtitle unreadable | OBSERVED (E74) |
| 2 | Cactus Desert | Sign with cactus icons over sand (low-resolution reading); fan wiki | sign OBSERVED, name LIKELY (E75, E76) |
| 3 | Autumn Woods | Fan wiki | LIKELY (E76) |
| 4 | Mushroom Marsh | Fan wiki; Bottle Cap reaches it | LIKELY (E76, E63) |
| 5 | Frost Lake | Fan wiki; about 35K Skill (unverified) | LIKELY (E76, E77) |
| late | Crystal Valley | Crossed just before the Pirate World unlock | LIKELY (E79) |

- A pirate-world zone called "Ember River" is mentioned (E79, LIKELY). A conflicting fan site uses the names "Starting Water" and "Mid Lake" (E78, UNKNOWN).
- Zones are distance bands, and farther bands pay more (E35).
- At 144 m the Palm Beach sign was still ahead (E33). Whether signs mark the start of a band or sit mid-band is unknown.
- There are no meter thresholds or Wins tables for any zone (E31).

### UI
- **Left 2-column menu:** Shop, Rebirth (% progress), Pets, Trails, Inventory, Gifts (red badge) (E85, OBSERVED).
- **Codes:** the code box is at the bottom of the Shop window (E86, CONFIRMED).

| Position | Elements | Confidence |
|---|---|---|
| Top center | "AUTO THROW – ONLY R$10"; a live "NNN m" counter during flight | OBSERVED (E87, E32) |
| Right | Starter Pack (unicorn-cat pet); "+2x SKILL ONLY 2" (reads "+5x SKILL … 8" at 2 rebirths); "2x WINS ONLY R$25" | OBSERVED readings (E87, E88) |
| Bottom center | SKILL counter (lightning icon); "xN Multiplier"; level bar; +10K / +100K / +1M Skill buttons (R$5 / 20 / 40) | OBSERVED (E87) |
| Bottom left | Trophy Wins counter; rebirth counter; "Friend Boost +0%" with a green "+" invite button | OBSERVED (E87, E51) |
| In world | Yellow THROW ZONE with a green THROW button; banner "TUTORIAL: REACH LEVEL 20" | OBSERVED (E24, E48) |

Platforms are UNKNOWN. The touch-sized buttons suggest the game was designed mobile-first (E89).

---

## 7. Pets, eggs, gifts, daily, codes, friend boost, monetization

### Pets
- Pets give boosts; this is in the official description (E90, CONFIRMED).
- Eggs are bought with Wins and pets give xN Skill. Pets are kept through rebirth, there are 3 equip slots, and hatches are weighted by chance and luck (E91, LIKELY).

**World 1 eggs (Sportskeeda, LIKELY, E92)**

| Egg | Price | Contents (chance, multiplier) |
|---|---|---|
| Common | 50 Wins | Pebble Pup 40% x2; Clover Bun 30% x2.5; Ripple Drake 10% (Rare) x4; a 4th pet was not seen |
| Uncommon | 500 Wins | Fern Fawn 40% x5 … up to Suncrest Owl 10% (Epic) x8 |
| Rare | 4,000 Wins | Top pet is Legendary x19 |
| Rainbow | R$20 | 5 pets |

**World 2 eggs (Sportskeeda, LIKELY, E93)**

| Egg | Price | Contents |
|---|---|---|
| Epic | 100K Wins | Ember Bat x25 (40%), Frost Ray x30 (30%), Bloom Kitsune x35 (20%), Astral Hydra x45 (10%) |
| Legendary | 2.5M Wins | Royal Griffin x60, Jade Scarab x70, Aurora Qilin x80, Solar Phoenix x100 |
| Mythical | 75M Wins | Nebula Whale x150, Velvet Manticore x175, then x200 and x250 |
| Pirate (Robux) | R$25 / 50 / 115 for 1 / 3 / 8 hatches | Captain Claw 40%, Ruby Corsair 30%, Doubloon Mimic 20%, Abyssal Kraken 8% (Legendary), Phantom Admiral 2% (Rainbow). Reported multipliers include x400, x650 and x1000; which pet has which is not given. |

**Hacked Admin Egg**
- It is priced "70" with the same Robux-style icon as Auto Throw, and appears in both the lava hub and the pirate hub (E94, OBSERVED).
- A fan wiki gives 70 / 185 / 459 for 1 / 3 / 8 hatches, with five pets (E95, LIKELY).
- The earlier "World 1 egg prices 70/185/459 Wins" claim is a mislabel of this egg.
- Its odds are UNKNOWN.

**Other egg facts**
- Codes grant a Common Egg, and possibly an Uncommon Egg (disputed). A fan wiki shows Common and Rare egg stands in the hub (E96, LIKELY).
- **Our reading of the egg tables:**
  - pet multipliers climb from x2–x19 (World 1) to x25–x250 (World 2), then to x400–x1000 (Robux Pirate Egg)
  - each world's Robux egg sits about one tier above its best Wins egg

### Boosts

| Boost | Effect | Confidence | Ref |
|---|---|---|---|
| Skill / Win / Luck Potion | They exist and are granted by codes | CONFIRMED | E97 |
| Potion strength | 2x Skill, Wins or hatch luck for 10 minutes | LIKELY | E98 |
| Friend Boost | HUD reads "+0%" when solo, with an invite "+" (OBSERVED). +10% per friend in the server (LIKELY). | OBSERVED / LIKELY | E87, E99 |
| Admin Abuse | Server-wide Skill and Wins boosts, including private servers; a golden giant that raises Colossus odds; an admin treadmill | LIKELY | E102, E44 |

### Gifts, daily rewards, trails
- **Gifts:** the menu button carries a red badge (OBSERVED, E85). Fan sites describe:
  - a time-gated wall of Skill and Wins tiers that unlock while you play
  - claimable gifts or chests around the maps containing Wins, eggs or potions (E100, LIKELY)
- **Daily rewards:** no source mentions daily login rewards or streaks (UNKNOWN).
- **Trails:** the menu exists, but no source documents an effect. One fan guide says cosmetics have no gameplay effect (E101, UNKNOWN).

### Codes
Codes are redeemed at Shop → bottom of the window → "Enter Code Here" → Redeem, and are case-sensitive (E86, CONFIRMED).

| Code | Reward | Status (Oct 2026) | Confidence |
|---|---|---|---|
| 10KCCU | Skill + Win + Luck Potion, 3 Wins, 1.31K Skill | active on 3 sites | LIKELY (E103) |
| SECRET | Luck Potion + Common Egg | active on 3 sites | LIKELY (E104) |
| WORLD4 | Skill Potion + 1.31K Skill | active on 3 sites | LIKELY (E105) |
| WORLD5 | Skill Potion + 1.31K Skill + Common Egg | new, ~2026-10-07 | LIKELY (E106) |
| WELCOME | Skill Potion + Win Potion | disputed | LIKELY (E107) |
| 5KCCU | Potions + Wins | TryHardGuides only | LIKELY (E108) |
| WORLD3 | Skill Potion + Common or Uncommon Egg | likely expired | LIKELY (E109) |
| THANKYOU | Win Potion + 20 or 4 Wins | expired or disputed | LIKELY (E110) |
| 10MVISITS, 50KCCU, 40KCCU, 10KLIKES, 500KFAV, SECRET2 | not given | unverified | UNKNOWN (E111) |

- Earnaldo claims no codes work at all (E112, UNKNOWN).
- Code names follow CCU milestones, world launches and generic words (E21, E113, LIKELY).
- Code rewards are small: potions, an egg, and a little Skill or Wins.

### Monetization

| Product | Price | Kind / notes | Confidence | Ref |
|---|---|---|---|---|
| Auto Throw | R$10 | HUD offer; not on the Rolimons pass list | OBSERVED | E117 |
| 2x Wins | R$25 | HUD offer; same price as the Rolimons "Auto Wins" pass | OBSERVED | E87, E115 |
| +2x Skill | reads "2" (later "+5x … 8") | HUD offer; may scale with progress | UNKNOWN | E88 |
| Starter Pack | not visible | HUD offer showing a unicorn-cat pet | OBSERVED | E87 |
| Skill packs +10K / +100K / +1M | R$5 / 20 / 40 | Repeatable, probably developer products | OBSERVED | E87 |
| ALL WORLDS pads 3x / 15x / 50x | R$39 / 99 / 239 | Owned per pad | OBSERVED | E42 |
| Phoenix Relic | R$199 | Shows a limited-stock sign | CONFIRMED | E64, E65 |
| Hacked Admin Egg | 70 / 185 / 459 for 1 / 3 / 8 | Robux egg | OBSERVED (70) / LIKELY (bundle prices) | E94, E95 |
| Pirate Egg | R$25 / 50 / 115 | Robux egg | LIKELY | E93 |
| Rainbow Egg | R$20 | Robux egg | LIKELY | E92 |
| Game passes listed on Rolimons | Auto Wins 25, Auto Rebirth 149, Golden Training Zone 249, Admin Training Zone 599, Koi Training Zone (price not seen), Hatch +3 Eggs 25 | Game passes | LIKELY | E115 |
| LootWiki pass count and developer products | 11 passes in total (including pet passes and gift versions). Developer products: 10 Skill Multiplier tiers, Skill packs, Wins packs, permanent 2x/5x/10x Wins, potions. | Mixed | LIKELY | E114, E116 |

Two monetization questions are unresolved:
- Are Auto Throw (R$10 in the HUD) and Auto Wins (R$25 pass) the same product (E117, UNKNOWN)?
- How do the ALL WORLDS pads relate to the Training Zone passes (E43, UNKNOWN)?

---

## 8. EVIDENCE TABLE

"n/d" means the source is undated. Screenshot capture dates are unknown; the notes were read on 2026-10-08.

| # | Claim | Source (URL) | Source date | Confidence |
|---|---|---|---|---|
| 1 | "+1 Stone Skipping" (place 111543903102439) is published by Roblox community Meow Labs (id 207366578). | https://www.roblox.com/games/111543903102439/1-Stone-Skipping ; https://www.roblox.com/communities/207366578/Meow-Labs ; https://www.rolimons.com/game/111543903102439 | n/d | CONFIRMED |
| 2 | The Meow Labs owner is iPlayfade. Members: about 1,544,386 (community page snippet) or about 1,423,572 (older Rolimons listing). | https://www.roblox.com/communities/207366578/Meow-Labs ; https://creatorexchange.io/roblox-game/10765298801/1-stone-skipping ; https://www.rolimons.com/groups | n/d | LIKELY |
| 3 | The universe id is probably 10765298801 (from the Creator Exchange URL). | https://creatorexchange.io/roblox-game/10765298801/1-stone-skipping | n/d | LIKELY |
| 4 | Created / released Saturday 2026-09-05. | https://www.rolimons.com/game/111543903102439 ; https://earnaldo.com/blog/1-stone-skipping-codes ; https://stoneskipping.wiki/ | 2026-10-06 | CONFIRMED |
| 5 | Last updated 2026-10-06 per Earnaldo (Roblox API). The fan wiki's "2026-09-30" is an older snapshot. | https://earnaldo.com/blog/1-stone-skipping-codes ; https://stoneskipping.wiki/ ; https://lootwiki.com/stone-skipping/beginner/ | 2026-10-06 | LIKELY |
| 6 | 30,068 playing, 15,468,262 visits, 585,875 favorites, 96.5% likes. | https://earnaldo.com/blog/1-stone-skipping-codes | 2026-10-06 | OBSERVED |
| 7 | Rolimons: 31,388 playing, 12,584,773 visits, 483,835 favorites, all-time peak 75,257 CCU. Creator Exchange: 34.69K CCU, 97% likes. | https://www.rolimons.com/game/111543903102439 ; https://creatorexchange.io/roblox-game/10765298801/1-stone-skipping | ~2026-10-01 (Rolimons); n/d (CE) | OBSERVED |
| 8 | Players up 171% across 27 checks (median 11,958 to 32,361). | https://earnaldo.com/blog/1-stone-skipping-codes | 2026-10-06 | UNKNOWN |
| 9 | A RobloxGo snapshot (5,284 playing, 679,322 visits) is labelled 2026-09-28; the date is inconsistent with Rolimons. | https://www.robloxgo.com/game/111543903102439/1-Stone-Skipping | labelled 2026-09-28 (doubtful) | UNKNOWN |
| 10 | Max server size is 10. | https://www.rolimons.com/game/111543903102439 ; https://stoneskipping.wiki/ | n/d | CONFIRMED |
| 11 | Genre Simulation, sub-genre Incremental Simulator. | https://creatorexchange.io/roblox-game/10765298801/1-stone-skipping ; https://www.robloxgo.com/game/111543903102439/1-Stone-Skipping | n/d | CONFIRMED |
| 12 | Official description: every bounce gives +1 Skill; train and level up to throw farther; farther zones give more Wins; unlock better stones and unusual objects (even a donut); collect pets for boosts; rebirth. | https://www.roblox.com/games/111543903102439/1-Stone-Skipping ; https://tryhardguides.com/1-stone-skipping-codes/ ; https://www.dexerto.fr/roblox/codes-1-stone-skipping-1660518/ | 2026-10 | CONFIRMED (gist) |
| 13 | The exact description wording and order were never fetched. "Rebirth to grow stronger and beat your longest throw!" is quoted only by aggregators. | https://www.robloxgo.com/game/111543903102439/1-Stone-Skipping ; https://robloxden.com/game-codes/1-stone-skipping ; https://www.roblox.com/games/111543903102439/1-Stone-Skipping | 2026-10 | LIKELY |
| 14 | Free to play. | https://stone-skipping.wiki/ ; https://stoneskippingwiki.top/ ; https://www.robloxgo.com/game/111543903102439/1-Stone-Skipping | 2026-10 | LIKELY |
| 15 | Other Meow Labs "+1" titles: "+1 Drain Water per Click" and "+1 Speed Monkey Escape". | https://www.dexerto.com/roblox/1-stone-skipping-codes-3416218/ | n/d | UNKNOWN |
| 16 | Meow Labs releases codes regularly; its official Discord is where new codes appear. | https://www.dexerto.fr/roblox/codes-1-stone-skipping-1660518/ | 2026-10 | LIKELY |
| 17 | World 5 launched with the first Admin Abuse event on Saturday 2026-10-03 at 12:00 PM ET; five worlds are live as of 2026-10-08. | https://stealthygaming.com/1-stone-skipping-world-5-update/ ; https://lootwiki.com/stone-skipping/beginner/ ; https://www.sportskeeda.com/roblox-news/when-is-the-next-update-1-stone-skipping | 2026-10-02 to 2026-10-07 | LIKELY |
| 18 | World 6 and an Admin Abuse event are scheduled for 2026-10-10 16:00 UTC (12 PM EDT / 9 AM PDT), adding eggs, throwables and training areas. | https://www.sportskeeda.com/roblox-news/when-is-the-next-update-1-stone-skipping ; https://www.sportskeeda.com/roblox-news/when-next-admin-abuse-1-stone-skipping | 2026-10-07 | LIKELY |
| 19 | World 6 teaser: "Something is brewing beyond the volcano", with a black cat pet in a witch hat holding a potion; read as Halloween seasonal pets. | https://www.sportskeeda.com/roblox-news/when-is-the-next-update-1-stone-skipping | 2026-10-07 | LIKELY |
| 20 | A "Halloween Event" dated 2026-10-17. | https://earnaldo.com/blog/1-stone-skipping-codes | 2026-10-06 | UNKNOWN |
| 21 | Each world launch gets a code: WORLD3 (listed as working 2026-09-26, later expired), WORLD4 (active), WORLD5 (new). | https://www.mrguider.org/roblox/1-stone-skipping-codes/ ; https://tryhardguides.com/1-stone-skipping-codes/ ; https://robloxden.com/game-codes/1-stone-skipping ; https://creatorexchange.io/roblox-game/10765298801/1-stone-skipping ; https://www.dexerto.com/roblox/1-stone-skipping-codes-3416218/ | 2026-09-26 to 2026-10-07 | LIKELY |
| 22 | Core loop: build Skill (training and bounces), throw down the big river, the stone skips and sinks, earn Wins, buy better stones and eggs, reach the river's end, move to the next world. | https://www.sportskeeda.com/roblox-news/1-stone-skipping-a-beginner-s-guide ; https://www.roblox.com/games/111543903102439/1-Stone-Skipping | n/d | CONFIRMED |
| 23 | The hub has small water bodies for auto-training and a massive river for throwing. | https://www.sportskeeda.com/roblox-news/1-stone-skipping-a-beginner-s-guide ; screenshot | 2026-09/10 | CONFIRMED |
| 24 | You throw by standing at the river's throw spot (yellow THROW ZONE) and pressing an on-screen green THROW button. | https://www.sportskeeda.com/roblox-news/1-stone-skipping-a-beginner-s-guide ; screenshot | n/d | OBSERVED |
| 25 | No power, charge, aim or timing mechanic is documented, and none is visible in the throw-zone frame. Distance is capped by equipment and Skill, not timing. | https://stone-skipping.wiki/progression/1-stone-skipping-throwing-guide ; https://stoneskippingwiki.top/guides/1-stone-skipping-tips-and-tricks/ ; screenshot | n/d | LIKELY |
| 26 | PC controls: WASD to move, Space to jump, E to interact. | https://www.sportskeeda.com/roblox-news/1-stone-skipping-a-beginner-s-guide | n/d | UNKNOWN |
| 27 | Each bounce pays Skill: +1 with the starter Pebble, and each throwable has its own +X (Frisbee: 3,500 per water touch). | https://www.roblox.com/games/111543903102439/1-Stone-Skipping ; https://www.sportskeeda.com/roblox-news/all-stones-1-stone-skipping-world-1 ; https://stone-skipping.wiki/progression/1-stone-skipping-throwing-guide | n/d | CONFIRMED |
| 28 | Level, rebirth and pad multipliers, pets, Friend Boost and potions scale Skill gain. | https://stone-skipping.wiki/progression/1-stone-skipping-throwing-guide ; https://stoneskipping.wiki/ ; https://www.sportskeeda.com/roblox-news/1-stone-skipping-rebirth-guide | n/d | LIKELY |
| 29 | Skill is the stat that determines throw distance. | https://www.sportskeeda.com/roblox-news/1-stone-skipping-a-beginner-s-guide ; https://www.roblox.com/games/111543903102439/1-Stone-Skipping | n/d | CONFIRMED |
| 30 | Higher Skill means more skips before sinking and so a longer distance; the outcome is computed from the equipped stone and total Skill. | https://stoneskippingwiki.top/zones/1-stone-skipping-zone-rewards/ ; https://stone-skipping.wiki/progression/1-stone-skipping-throwing-guide | n/d | LIKELY |
| 31 | No source gives a Skill-to-meters formula, a Wins-per-distance formula or a per-zone payout table. | https://stoneskippingwiki.top/zones/1-stone-skipping-zone-rewards/ ; https://www.sportskeeda.com/roblox-news/1-stone-skipping-a-beginner-s-guide | n/d | UNKNOWN |
| 32 | Distance is shown in meters; a live yellow counter (for example "144 m") sits under AUTO THROW during flight. | screenshot | n/d | OBSERVED |
| 33 | During flight the camera follows the stone down the channel with the avatar out of frame. At 144 m the HUD shows 25.29K Skill and x5, with the Palm Beach sign still ahead. | screenshot | n/d | OBSERVED |
| 34 | Fan-recorded World 1 throws ranged from 212 m to 1,776 m. | https://stone-skipping.wiki/progression/1-stone-skipping-throwing-guide | n/d | LIKELY |
| 35 | When the stone sinks, the throw ends, the distance is reported and Wins are paid; farther zones pay more. | https://www.sportskeeda.com/roblox-news/1-stone-skipping-a-beginner-s-guide ; https://www.roblox.com/games/111543903102439/1-Stone-Skipping ; https://stone-skipping.wiki/progression/1-stone-skipping-throwing-guide | n/d | CONFIRMED |
| 36 | Later zones pay disproportionately more Wins. | https://stone-skipping.wiki/progression/1-stone-skipping-throwing-guide ; https://stoneskippingwiki.top/zones/1-stone-skipping-zone-rewards/ | n/d | LIKELY |
| 37 | A 1,404 m throw paid +200 Wins (from a search summary; the page could not be identified). | https://stoneskippingwiki.top/zones/1-stone-skipping-zone-rewards/ | n/d | UNKNOWN |
| 38 | Secret Throw: about 1 in 100, rolled at launch, anime-style cutscene, about 3x a normal throw, any object including the Phoenix Relic; odds cannot be changed. One fan wiki says the trigger is unknown. | https://www.sportskeeda.com/roblox-news/how-get-secret-colossus-throws-1-stone-skipping ; https://stone-skipping.wiki/ ; https://gamerant.com/stone-skipping-codes-roblox/ | n/d | LIKELY |
| 39 | Colossus Throw: about 1 in 1000. A golden giant blesses the avatar (red aura) and the object becomes a giant golden coin that can reach the river's end and unlock the next world. The Admin Abuse giant raises the odds. | https://www.sportskeeda.com/roblox-news/how-get-secret-colossus-throws-1-stone-skipping | n/d | LIKELY |
| 40 | Training areas beside smaller ponds: the avatar builds Skill on its own, and more rebirths unlock better auto-training areas. | https://www.sportskeeda.com/roblox-news/1-stone-skipping-a-beginner-s-guide ; screenshot | n/d | CONFIRMED |
| 41 | Rebirth-gated pads: 1x SKILL (0 rebirths, UNLOCKED, AUTO toggle), 4x (2), 10x (4), 20x (6). The badge uses the rebirth icon. The fan wiki lists teal 1x / green 4x / purple 10x at 0/2/4. | screenshot ; https://stoneskipping.wiki/rebirth-guide/ | n/d | OBSERVED |
| 42 | "ALL WORLDS" pads 3x / 15x / 50x SKILL cost R$39 / 99 / 239 and are owned individually. | screenshot | n/d | OBSERVED |
| 43 | Training-zone passes: Golden R$249, Admin R$599, Koi (price not seen). LootWiki counts three. Their relation to the ALL WORLDS pads is unclear. | https://www.rolimons.com/game/111543903102439 ; https://lootwiki.com/stone-skipping/author/ | ~2026-10-02 | LIKELY |
| 44 | Admin Abuse may spawn an admin-only treadmill that quickly raises everyone's Skill. | https://www.sportskeeda.com/roblox-news/when-next-admin-abuse-1-stone-skipping | 2026-10-07 | LIKELY |
| 45 | The pad Skill rate is not visible; "+N Skill" pedestal labels hint that the stone sets base training gain. | screenshot | n/d | UNKNOWN |
| 46 | The tutorial first asks for about 30 Skill through a training action (player anecdote). | https://www.sportskeeda.com/roblox-news/1-stone-skipping-a-beginner-s-guide ; https://stone-skipping.wiki/progression/1-stone-skipping-throwing-guide | n/d | UNKNOWN |
| 47 | A level bar at the bottom shows progress, for example "Level 50 3.07K/4.05K". | screenshot | n/d | OBSERVED |
| 48 | The tutorial banner goal is "REACH LEVEL 20". | screenshot ; https://stoneskipping.wiki/ | n/d | OBSERVED |
| 49 | At 0 rebirths: "Level 20 MAX LEVEL", Rebirth 100%, "x1 Multiplier", 241 Skill, about 1K Wins. | screenshot | n/d | OBSERVED |
| 50 | At 2 rebirths: "Level 50 3.07K/4.05K", Rebirth 83%, "x5 Multiplier", 25.29K Skill, about 12K Wins. | screenshot | n/d | OBSERVED |
| 51 | The bottom-left counter first noted as "gems" is the rebirth count (rebirth icon; values 0 and 2). No web source mentions gems. | screenshot | n/d | OBSERVED |
| 52 | There is a level cap and Skill stops growing at it. The Rebirth button shows % to the cap. Rebirth resets Level and Skill to 1, grants a permanent Skill multiplier and raises the cap. The panel lists only Level and Skill as reset items. | https://www.sportskeeda.com/roblox-news/1-stone-skipping-rebirth-guide ; https://stoneskipping.wiki/rebirth-guide/ ; screenshot | 2026-09-30 | CONFIRMED |
| 53 | Stones and pets are kept through rebirth; rebirth, pet and stone multipliers stack multiplicatively. | https://www.sportskeeda.com/roblox-news/1-stone-skipping-rebirth-guide | 2026-09-30 | LIKELY |
| 54 | Rebirth % = level ÷ required level (50/60 = 83.3%; the XP fraction of 75.8% does not match), which puts rebirth #3 at L60. | screenshot (derived) | n/d | LIKELY |
| 55 | Rebirth level requirements are 20 / 40 / 60 / 80 / 100 / 125, and the 6th is hard without an upgraded stone. | https://stoneskippingwiki.top/guides/1-stone-skipping-tips-and-tricks/ ; https://stoneskippingwiki.top/tier-list/1-stone-skipping-what-to-unlock-first/ ; screenshot | n/d | OBSERVED (L20); LIKELY (L40–L60); UNKNOWN (L80–L125) |
| 56 | The per-rebirth multiplier value is not published. | https://www.sportskeeda.com/roblox-news/1-stone-skipping-rebirth-guide ; https://stoneskipping.wiki/rebirth-guide/ | n/d | UNKNOWN |
| 57 | Whether Wins are kept on rebirth is not stated. Wins of about 1K at 0 rebirths and about 12K at 2 rebirths are inconclusive. | https://www.sportskeeda.com/roblox-news/1-stone-skipping-rebirth-guide ; screenshot | n/d | UNKNOWN |
| 58 | Fan-observed level multipliers run from x1.1 at L6 to x111 at L115 (22.34M Skill, 5 rebirths); this conflicts with the HUD's x1 at L20. | https://stone-skipping.wiki/progression/1-stone-skipping-throwing-guide ; https://stoneskipping.wiki/ ; screenshot | n/d | UNKNOWN |
| 59 | What the HUD "xN Multiplier" includes (level, rebirth, relic, purchases) cannot be separated from two data points. | screenshot | n/d | UNKNOWN |
| 60 | World 1: Pebble +1 / 0 Wins, Scallop Shell +3 / 2, Wood Slice +30 / 150 (Skill per bounce / Wins), matching the pedestals. | https://www.sportskeeda.com/roblox-news/all-stones-1-stone-skipping-world-1 ; screenshot | n/d | CONFIRMED |
| 61 | World 1: Roof Tile +75 / 500, Bottle Cap +200 / 1,500, Lucky Coin +500 / 4,500, Hockey Puck +1,250 / 14,000, Frisbee +3,500 / 40,000. Skill values match the back-row pedestals; prices are unreadable there. | https://www.sportskeeda.com/roblox-news/all-stones-1-stone-skipping-world-1 ; screenshot | n/d | CONFIRMED (Skill); LIKELY (prices) |
| 62 | World 1: Ammonite Fossil +5 / 10 and Starfish +12 / 40 (Sportskeeda). The screenshot shows a single pedestal between +3 and +30 reading "+?2 Skill / ?0 Wins" (40 or 60). | https://www.sportskeeda.com/roblox-news/all-stones-1-stone-skipping-world-1 ; screenshot | n/d | LIKELY; discrepancy UNKNOWN |
| 63 | Frisbee is the best free World 1 throwable and Flying Saucer the best free World 2 one. Buy the best affordable stone before pets. Bottle Cap is the first power spike (it reaches the Mushroom zone). | https://www.sportskeeda.com/roblox-news/all-stones-1-stone-skipping-world-1 ; https://www.sportskeeda.com/roblox-news/all-world-2-stones-1-stone-skipping ; https://stoneskippingwiki.top/tier-list/1-stone-skipping-what-to-unlock-first/ | n/d to 2026-10-08 | LIKELY |
| 64 | Phoenix Relic: the only Robux throwable, R$199, "Always 125% better than your best Stone", sold in every world. | https://www.sportskeeda.com/roblox-news/all-stones-1-stone-skipping-world-1 ; https://www.sportskeeda.com/roblox-news/all-world-2-stones-1-stone-skipping ; screenshot | 2026-10-08 | CONFIRMED |
| 65 | The Phoenix Relic sign reads "STOCK: 997/1000"; no web source mentions a stock cap. | screenshot | n/d | OBSERVED |
| 66 | World 2 ("Pirate World") throwables run from Playing Card (+25K / 60K) to Flying Saucer (+1M / 500M), 10 items plus the Phoenix Relic. Earlier stones remain usable. | https://www.sportskeeda.com/roblox-news/all-world-2-stones-1-stone-skipping | 2026-10-08 | LIKELY |
| 67 | The pirate-hub frame (with the "WORLD 3" flag) has a stone shop reading +100K Skill / 1M Wins, +150K / 2.5M Wins, +500K and +1M, with fainter +62.5K, +275K and +375K. The earlier "+50K..+2.5M Skill" note likely misread a Wins price. | screenshot | n/d | OBSERVED |
| 68 | Stone cards are shown over their own zone water: a basic stone, a glowing lava rock and a UFO. | https://1stoneskipping-wiki.wiki/wiki/equipment/stone-cards/ | n/d | LIKELY |
| 69 | World 1 art: voxel/checker style, green grass, brown checker cliffs, a long straight turquoise channel from a yellow THROW ZONE, zone signs over the channel. | screenshot | n/d | OBSERVED |
| 70 | A lava/volcano hub with a red dragon statue and lava falls (the screenshot notes call it World 2). | screenshot | n/d | OBSERVED (theme); world number UNKNOWN |
| 71 | A pirate/beach hub with a "WORLD 3" skull flag, a waterfall portal and barrels. | screenshot | n/d | OBSERVED |
| 72 | World 2 is the "Pirate World" (message "Pirate World unlocked"; a Robux Pirate Egg). | https://www.sportskeeda.com/roblox-news/all-world-2-stones-1-stone-skipping ; https://www.sportskeeda.com/roblox-news/all-world-2-eggs-1-stone-skipping ; https://1stoneskipping-wiki.wiki/wiki/worlds/pirate-world/ | 2026-10-03 to 2026-10-08 | LIKELY |
| 73 | The first world has no official name in the sources; a fan wiki calls it "Starting river". | https://1stoneskipping-wiki.wiki/wiki/worlds/starting-river/ | 2026-10-05 | LIKELY |
| 74 | "Palm Beach" is the first zone sign over the World 1 channel, visible from spawn and the THROW ZONE; its subtitle is unreadable. | screenshot ; https://stone-skipping.wiki/ | n/d | OBSERVED |
| 75 | A second sign with cactus icons over sand plausibly reads "Cactus Desert" (low resolution). | screenshot | n/d | OBSERVED (sign); LIKELY (text) |
| 76 | World 1 zone order: Palm Beach, Cactus Desert, Autumn Woods, Mushroom Marsh, Frost Lake. | https://stone-skipping.wiki/ ; https://stoneskipping.wiki/ | 2026-10 | LIKELY |
| 77 | Frost Lake reportedly unlocks at about 35,000 Skill (from video captions; the site calls it unverified). | https://stoneskipping.wiki/ | n/d | LIKELY |
| 78 | Conflicting fan site: zone names "Starting Water" and "Mid Lake"; Frost reachable from the 3rd rebirth; Frost tied to a ~500-Win stone and Mushroom to a ~1,500-Win stone. | https://stoneskippingwiki.top/guides/1-stone-skipping-tips-and-tricks/ | n/d | UNKNOWN |
| 79 | "Crystal Valley" is crossed just before the Pirate World unlock; "Ember River" is a target zone in the pirate world. | https://1stoneskipping-wiki.wiki/wiki/worlds/pirate-world/ | 2026-10-03 | LIKELY |
| 80 | A throw that reaches the river's end triggers a cutscene and opens the next world through a portal, with a "Pirate World unlocked" message. | https://www.sportskeeda.com/roblox-news/1-stone-skipping-a-beginner-s-guide ; https://1stoneskipping-wiki.wiki/wiki/worlds/starting-river/ ; https://1stoneskipping-wiki.wiki/wiki/worlds/pirate-world/ ; https://www.sportskeeda.com/roblox-news/when-is-the-next-update-1-stone-skipping | 2026-09/10 | CONFIRMED |
| 81 | World 2 needs a throw with about 100M Skill in World 1 (also worded "100 million distance mark"); World 3 needs about 400B Skill with World 2 stones. | https://www.sportskeeda.com/roblox-news/all-world-2-stones-1-stone-skipping ; https://www.sportskeeda.com/roblox-news/all-stones-1-stone-skipping-world-1 | 2026-10-08 | LIKELY |
| 82 | "100M" most plausibly means Skill: Skill is counted in K/M units, while distance is on a separate meter counter. | screenshot | n/d | LIKELY |
| 83 | No source mentions a Wins or Robux price, or a rebirth requirement, for a world portal. | https://www.sportskeeda.com/roblox-news/1-stone-skipping-a-beginner-s-guide | n/d | UNKNOWN |
| 84 | World 3 is rated "Moderate" (about 1 rebirth) and World 4 "High" (1+ rebirth, an upgraded stone, an active pet); the same site calls World 4 a zone tier. | https://stoneskippingwiki.top/zones/1-stone-skipping-world-4-guide/ | n/d | UNKNOWN |
| 85 | Left 2-column menu: Shop, Rebirth (% progress), Pets, Trails, Inventory, Gifts (red badge). | screenshot | n/d | OBSERVED |
| 86 | Codes: Shop (left menu), bottom of the window, "Enter Code Here", Redeem; case-sensitive. | https://robloxden.com/game-codes/1-stone-skipping ; https://tryhardguides.com/1-stone-skipping-codes/ ; https://www.mrguider.org/roblox/1-stone-skipping-codes/ | 2026-09-26 to 2026-10 | CONFIRMED |
| 87 | HUD: top "AUTO THROW – ONLY R$10"; right Starter Pack (unicorn-cat pet) and "2x WINS ONLY R$25"; bottom SKILL counter, "xN Multiplier", level bar, +10K/+100K/+1M Skill for R$5/20/40; bottom-left Wins trophy, rebirth counter, "Friend Boost +0%" with a green "+". | screenshot | n/d | OBSERVED |
| 88 | The "+2x SKILL" offer reads "ONLY 2" in two 0-rebirth frames and "+5x SKILL … 8" in a 2-rebirth frame; its meaning and true price are unclear. | screenshot | n/d | OBSERVED (digits); UNKNOWN (meaning) |
| 89 | No source states mobile, console or VR support; large touch-style buttons suggest mobile-first. | screenshot | n/d | UNKNOWN |
| 90 | Pets give boosts (official description). | https://www.roblox.com/games/111543903102439/1-Stone-Skipping | 2026-10 | CONFIRMED |
| 91 | Pets hatch from Wins eggs (weighted by chance and luck), give xN Skill, are kept through rebirth, and have 3 equip slots. | https://www.sportskeeda.com/roblox-news/all-eggs-1-stone-skipping-world-1 ; https://www.sportskeeda.com/roblox-news/1-stone-skipping-rebirth-guide | n/d | LIKELY |
| 92 | World 1 eggs: Common 50 Wins (Pebble Pup 40% x2, Clover Bun 30% x2.5, Ripple Drake 10% x4); Uncommon 500 (Fern Fawn 40% x5 to Suncrest Owl 10% x8); Rare 4,000 (top Legendary x19); Rainbow R$20 (5 pets). | https://www.sportskeeda.com/roblox-news/all-eggs-1-stone-skipping-world-1 | n/d | LIKELY |
| 93 | World 2 eggs: Epic 100K Wins (x25/x30/x35/x45 at 40/30/20/10%); Legendary 2.5M (x60–x100); Mythical 75M (x150–x250); Pirate Egg R$25/50/115 for 1/3/8 hatches (Abyssal Kraken 8%, Phantom Admiral 2%; multipliers up to x1000). | https://www.sportskeeda.com/roblox-news/all-world-2-eggs-1-stone-skipping | 2026-10 | LIKELY |
| 94 | The "Hacked Admin Egg" is priced 70 with the same Robux-style icon as AUTO THROW and appears in the lava and pirate hubs. | screenshot | n/d | OBSERVED |
| 95 | The Hacked Admin egg machine costs 70 / 185 / 459 for 1 / 3 / 8 hatches, with five pets and odds; an earlier claim mislabelled these as "World 1 egg prices in Wins". | https://stone-skipping.wiki/ ; screenshot | n/d | LIKELY |
| 96 | Common and Rare egg stands sit in the hub; codes grant a Common Egg (SECRET) or an Uncommon Egg (WORLD3 per MrGuider). | https://1stoneskipping-wiki.wiki/wiki/materials/rare-egg/ ; https://robloxden.com/game-codes/1-stone-skipping ; https://www.mrguider.org/roblox/1-stone-skipping-codes/ | 2026-09-26 to 2026-10 | LIKELY |
| 97 | Skill, Win and Luck Potions exist and are granted by codes. | https://robloxden.com/game-codes/1-stone-skipping ; https://www.dexerto.fr/roblox/codes-1-stone-skipping-1660518/ ; https://tryhardguides.com/1-stone-skipping-codes/ | 2026-10 | CONFIRMED |
| 98 | Potions give 2x Skill gain, Wins gain or hatch luck for 10 minutes and come from codes, gifts and Robux. | https://gamerant.com/stone-skipping-codes-roblox/ ; https://1stoneskipping-wiki.wiki/wiki/potions/luck-potion/ | n/d | LIKELY |
| 99 | Friend Boost gives +10% while a friend is in the server. | https://stoneskipping.wiki/ ; https://stone-skipping.wiki/ | n/d | LIKELY |
| 100 | Gifts: a time-gated wall of Skill and Wins tiers unlocks during play, plus claimable gifts or chests around the maps with Wins, eggs or potions. | https://stone-skipping.wiki/ ; https://stoneskippingwiki.top/zones/1-stone-skipping-world-4-guide/ ; screenshot | n/d | LIKELY |
| 101 | A Trails menu exists; no source documents an effect, and one fan guide says cosmetics have no gameplay effect. | screenshot ; https://stoneskippingwiki.top/tier-list/1-stone-skipping-what-to-unlock-first/ | n/d | UNKNOWN |
| 102 | Admin Abuse: server-wide Skill and Wins boosts (including private servers) and a golden giant that walks every world raising Colossus odds; events coincide with world updates. | https://www.sportskeeda.com/roblox-news/when-next-admin-abuse-1-stone-skipping ; https://www.sportskeeda.com/roblox-news/how-get-secret-colossus-throws-1-stone-skipping ; https://lootwiki.com/stone-skipping/beginner/ | 2026-10-07 | LIKELY |
| 103 | 10KCCU: Skill, Win and Luck Potion, 3 Wins, 1.31K Skill; active. | https://robloxden.com/game-codes/1-stone-skipping ; https://www.dexerto.fr/roblox/codes-1-stone-skipping-1660518/ ; https://tryhardguides.com/1-stone-skipping-codes/ | 2026-10 | LIKELY |
| 104 | SECRET: Luck Potion and Common Egg; active. | https://robloxden.com/game-codes/1-stone-skipping ; https://www.dexerto.fr/roblox/codes-1-stone-skipping-1660518/ ; https://tryhardguides.com/1-stone-skipping-codes/ | 2026-10 | LIKELY |
| 105 | WORLD4: Skill Potion and 1.31K Skill; active. | https://www.dexerto.fr/roblox/codes-1-stone-skipping-1660518/ ; https://robloxden.com/game-codes/1-stone-skipping ; https://tryhardguides.com/1-stone-skipping-codes/ | 2026-10 | LIKELY |
| 106 | WORLD5: Skill Potion, 1.31K Skill and a Common Egg; new around 2026-10-07 (attributed to Dexerto in one finding and to Creator Exchange alone in another). | https://www.dexerto.com/roblox/1-stone-skipping-codes-3416218/ ; https://creatorexchange.io/roblox-game/10765298801/1-stone-skipping | 2026-10-07 | LIKELY |
| 107 | WELCOME: Skill Potion and Win Potion; active per MrGuider and TryHardGuides, "Check" per RobloxDen. | https://www.mrguider.org/roblox/1-stone-skipping-codes/ ; https://tryhardguides.com/1-stone-skipping-codes/ ; https://robloxden.com/game-codes/1-stone-skipping | 2026-09-26 | LIKELY |
| 108 | 5KCCU: potions and Wins; listed only by TryHardGuides. | https://tryhardguides.com/1-stone-skipping-codes/ | 2026-10 | LIKELY |
| 109 | WORLD3: likely expired; reward is a Skill Potion plus an Uncommon Egg (MrGuider) or a Common Egg (RobloxDen). | https://www.mrguider.org/roblox/1-stone-skipping-codes/ ; https://robloxden.com/game-codes/1-stone-skipping ; https://tryhardguides.com/1-stone-skipping-codes/ | 2026-09-26 / 2026-10 | LIKELY |
| 110 | THANKYOU: expired (TryHardGuides), "Check" (RobloxDen), working on 2026-09-26 (MrGuider); reward is a Win Potion plus 20 or 4 Wins. | https://robloxden.com/game-codes/1-stone-skipping ; https://www.mrguider.org/roblox/1-stone-skipping-codes/ ; https://tryhardguides.com/1-stone-skipping-codes/ | 2026-09-26 / 2026-10 | LIKELY |
| 111 | Codes 10MVISITS, 50KCCU, 40KCCU, 10KLIKES, 500KFAV and SECRET2 (no rewards given; missing from the other dated lists). | https://robloxden.com/game-codes/1-stone-skipping ; https://www.dexerto.fr/roblox/codes-1-stone-skipping-1660518/ ; https://www.mrguider.org/roblox/1-stone-skipping-codes/ ; https://gamerant.com/stone-skipping-codes-roblox/ | 2026-10-06 | UNKNOWN |
| 112 | No working codes as of 2026-10-06 (not checked in game). | https://earnaldo.com/blog/1-stone-skipping-codes | 2026-10-06 | UNKNOWN |
| 113 | Code names follow CCU milestones (5KCCU, 10KCCU) and generic words (WELCOME, THANKYOU, SECRET). | https://tryhardguides.com/1-stone-skipping-codes/ | 2026-10 | LIKELY |
| 114 | There are 11 game passes (Auto Wins, Auto Rebirth, three Training Zones, pet passes, Hatch passes, gift versions); the developer wrote no store descriptions. | https://lootwiki.com/stone-skipping/author/ ; https://lootwiki.com/stone-skipping/beginner/ | 2026-09-30 | LIKELY |
| 115 | Rolimons pass prices: Auto Wins R$25, Auto Rebirth R$149, Golden Training Zone R$249, Admin Training Zone R$599, Hatch +3 Eggs R$25. | https://www.rolimons.com/game/111543903102439 | 2026-10-02 | LIKELY |
| 116 | Developer products: ten Skill Multiplier tiers, Skill Packs, Wins Packs, permanent 2x/5x/10x Wins, potions. | https://lootwiki.com/stone-skipping/author/ ; https://www.rolimons.com/game/111543903102439 ; https://gamerant.com/stone-skipping-codes-roblox/ | 2026-10-02 | LIKELY |
| 117 | "AUTO THROW – ONLY R$10" appears in every World 1 frame, and a fan site also says about R$10. Rolimons lists no Auto Throw pass, and the feature's behavior is undocumented. | screenshot ; https://stoneskippingwiki.top/guides/1-stone-skipping-tips-and-tricks/ ; https://www.rolimons.com/game/111543903102439 | n/d | OBSERVED (price); UNKNOWN (behavior) |
| 118 | Simulator convention: a gain action adds currency; upgrades multiply gains; currency unlocks zones and pets; rebirth gives a permanent multiplier; pet rarities are tiered. | https://www.creation.dev/blog/roblox-simulator-game-guide | n/d | LIKELY |
| 119 | Race Clicker analogue: train a stat, a race turns distance into Wins, Wins buy eggs and worlds; equip the best 3 pets; rebirth multipliers; longer distances in each world. | https://www.gfinityesports.com/roblox/race-clicker-codes | n/d | LIKELY |
| 120 | "+1 Speed Keyboard Escape" rebirths at L15, 25, 40, 60, 75, 100, 125, 150, 175 and 200, with a permanent multiplier rising from x1.5 to x10. | https://bloxodes.com/wiki/1-speed-keyboard-escape/rebirths ; https://techwiser.com/1-speed-keyboard-escape-rebirth/ | n/d | LIKELY |

---

## 9. UNCERTAINTY REGISTER

| Unknown | Why it matters | Assumption we will use |
|---|---|---|
| Formula from Skill and stone to bounces and meters (E31) | Sets the feel and pacing of every throw, and when zones and the river end are reached | Distance grows with the log of effective throw power (Skill × stone value × multipliers), clamped to the river length. It is tuned so the river end is reached near the world-unlock threshold. Bounce count and spacing derive from the distance, with spacing shrinking each bounce. **ORIGINAL DESIGN** |
| Whether bounce Skill extends the same throw | Affects the feedback loop and how exploitable it is | Distance is fixed at launch. Skill from bounces is credited live (the counter ticks each bounce) but affects only later throws. **ORIGINAL DESIGN** |
| Throw input: tap vs charge or timing (E25) | Decides whether player skill matters, and the mobile UX | A single tap on the THROW button with no timing. The server decides the result at launch and the client animates it. **LIKELY** |
| Throw cooldown and flight duration | Sets Wins and Skill earned per minute, and how valuable Auto Throw is | One active throw per player. Flight is capped at a short duration, sped up on long throws, and the next throw unlocks on landing. **ORIGINAL DESIGN** |
| What Auto Throw does (E117) | Store value and AFK design | Throws again automatically on landing while the player stands in the THROW ZONE. **ORIGINAL DESIGN** |
| Zone meter thresholds and Wins per zone (E31, E36, E37) | The whole Wins economy | 6–8 named zones per world, with Wins per zone rising steeply (exponentially). Payout = zone base × Wins multipliers. **ORIGINAL DESIGN** |
| River length per world | When world unlocks happen | A config value per world, set so the end is reached near that world's unlock Skill. **ORIGINAL DESIGN** |
| World unlock thresholds and unit (100M / 400B) (E81, E82) | Pacing of the whole game | Skill-based thresholds, configurable per world. Seed values: about 100M for World 2 and about 4,000x more per world (400B ÷ 100M), retuned in playtests. **LIKELY** |
| World order and themes (E70–E72) | Content roadmap | Our own themes. Structure only: a starter river world, then distinct themed worlds, each with a new river, stone shop, eggs and pads. **ORIGINAL DESIGN** |
| Per-rebirth multiplier (E56) | Long-term pacing | A rising ladder in the style of the +1 Speed family (for example x1.5 → x10 over the first ten rebirths). **ORIGINAL DESIGN** |
| Rebirth level schedule beyond L60 (E55) | Pacing and level-cap growth | L20 / L40 / L60 for rebirths 1–3 (20 × (n+1)). Later steps are configurable. **LIKELY** |
| Whether Wins survive rebirth (E57) | Economy balance | Rebirth resets Level and Skill only. Wins, stones and pets are kept. **LIKELY** |
| What the HUD multiplier includes (E59) | Clarity for players | Show the total multiplier with a breakdown tooltip (level, rebirth, pad, pets, boosts). **ORIGINAL DESIGN** |
| Level XP curve (E47, E49, E50) | Rebirth timing | XP = Skill earned since the last rebirth. Per-level cost grows about 16–18% per level, anchored near L50 ≈ 4K, which roughly fits both observed frames. **ORIGINAL DESIGN** |
| Level-to-multiplier mapping (E58) | Pacing | Each level adds a small additive Skill multiplier; we do not copy the fan series. **ORIGINAL DESIGN** |
| Training pad Skill rate (E45) | Balance between AFK and active play | Pad Skill per second = base (scaled from the best owned stone) × pad multiplier × other multipliers. The AUTO toggle trains without clicking. **ORIGINAL DESIGN** |
| Secret and Colossus odds and effects (E38, E39) | Excitement; a way to bypass unlocks | Secret: 1/100, about 3x distance. Colossus: 1/1000, reaches the river end. Rolled on the server, configurable, and boosted during events. **LIKELY** |
| Premium throwable: what "125% better" means and the stock (E64, E65) | Fairness and clarity of the store | If included, the premium throwable is 2.25x the best owned stone, and the store states this exactly. A stock counter is shown only if stock is actually enforced. **ORIGINAL DESIGN** |
| Pet equip slots and egg odds (E91–E93) | Economy and the Robux egg ladder | 3 equip slots (**LIKELY**). Our own egg odds and multipliers, tiered per world, with Robux eggs about one tier above that world's best Wins egg. **ORIGINAL DESIGN** |
| Potion strength and duration (E98) | Value of code and gift rewards | 2x for 10 minutes. **LIKELY** |
| Friend Boost value and cap (E99) | Social growth | +10% per friend in the server, with a cap we set (for example +50%). **LIKELY** |
| Gift schedule and contents (E100) | Retention | Playtime gifts on rising timers, paying Skill, Wins, potions and eggs. **ORIGINAL DESIGN** |
| Daily rewards (no source) | Retention | A simple daily login streak. **ORIGINAL DESIGN** |
| Trails effect (E101) | Scope | Cosmetic only. **ORIGINAL DESIGN** |
| Gems currency (E51) | Scope | No gems; the bottom-left counter shows rebirths. **ORIGINAL DESIGN** |
| Admin-style Robux egg odds and pricing (E94, E95) | Monetization | A Robux egg with 1 / 3 / 8 hatch bundles at a discount, priced to roughly match the 70 / 185 / 459 pattern. Our own odds. **LIKELY** |
| "+2x SKILL" offer; Auto Wins vs Auto Throw vs 2x Wins (E88, E115, E117) | Store layout | Three clear passes: Auto Throw, 2x Wins and 2x Skill. No progress-scaled mystery pricing. **ORIGINAL DESIGN** |
| ALL WORLDS pads vs Training Zone passes (E42, E43) | Store design | Paid pads are game passes that work in every world, each sold separately. **ORIGINAL DESIGN** |
| Platforms (E89) | UI sizing and input | Mobile-first HUD with large touch buttons; PC and gamepad also supported. **ORIGINAL DESIGN** |
| Camera during throws (E33) | Feel | The camera follows the stone and returns to the avatar on landing, with speed-up on long flights. **LIKELY** |
| Admin Abuse mechanics (E44, E102) | Live-ops | A scheduled, server-wide event flag that applies Skill and Wins multipliers and higher special-throw odds. **ORIGINAL DESIGN** |
| How stones are bought and equipped | UX | Touching a pedestal or a prompt opens a buy dialog; the best owned stone is equipped automatically. **ORIGINAL DESIGN** |
| Tutorial flow (E46, E48) | Onboarding | Guided steps: train, throw, buy the first stone, reach Level 20, rebirth. Anchored to the observed "REACH LEVEL 20" goal. **ORIGINAL DESIGN** |
| Zone sign placement (E33) | Readability of progress | A sign marks the start of each distance band, and the HUD shows the zone currently reached. **ORIGINAL DESIGN** |
| Whether Skill is ever spent | Economy | Skill is never spent; Wins are the only soft currency for purchases. **LIKELY** |

---

## Part 3: Reconstruction decisions (reference → Sky Glide)

| Reference element | Status | Sky Glide | Label |
|---|---|---|---|
| Skip a stone; each bounce +1 Skill (x stone value) | CONFIRMED | **Throw a glider; each thermal ring it rides pays +N Skill** (glider value). A **PERFECT gust tap** in the ring's window pays x2. Rings are spaced in time (≥0.75 s) so spam-tapping never works | ORIGINAL DESIGN (the user asked for a non-skipping core) |
| On-screen THROW in a yellow THROW ZONE | OBSERVED | Same placement. Holding THROW runs a launch meter (gold band = PERFECT LAUNCH x1.25), timed by the server clock | ORIGINAL addition |
| Skill drives distance; zones pay Wins | CONFIRMED | `D = (6 + 4.5·Skill^0.4) x launch`. 12 zones per world pay Wins x multiplier | ORIGINAL numbers |
| Distance counter "144 m" | OBSERVED | The same "N m" counter under AUTO THROW. Logical meters are mapped to rendered studs on a log curve so huge throws stay in the channel | ORIGINAL implementation |
| Level bar filled by Skill; Skill stops at the cap; rebirth resets Skill and Level | CONFIRMED / LIKELY | The same rules. Thresholds are fitted to the HUD. Cap = 20 + 20 x rebirths. Multiplier = 1 + 2 x rebirths | LIKELY |
| Pads 1x/4x/10x/20x at 0/2/4/6 rebirths; ALL WORLDS 3x/15x/50x for Robux; AUTO toggle | OBSERVED | Identical structure, with stronger pads in later worlds. Pass pads are game passes | OBSERVED structure, ORIGINAL art |
| World 1 stone table (+1/0 … +3.5K/40K) | CONFIRMED | 10 original gliders on the same curve shape, with slightly different values | ORIGINAL items |
| Phoenix Relic: R$199, limited stock, "always 125% better" | OBSERVED / CONFIRMED | **Aurora Relic** with the same rule and a global stock counter in a DataStore | ORIGINAL name and art |
| Next world opens when a throw reaches the end of the river | CONFIRMED | The same, plus a rebirth gate (5/7/9) so a lucky special throw can't skip a world | CONFIRMED + ORIGINAL gate |
| Secret Throw (1/100, about x3) and Colossus (1/1000) | LIKELY | **Jet Stream** (1%, x3) and **Sky Titan** (0.1%, x8), with a cinematic banner | ORIGINAL |
| Pets as "xN Skill"; 3 slots; eggs bought with Wins; a Robux egg (70) | LIKELY / OBSERVED | The same structure: 3 slots (+2 with a pass), 9 Wins eggs, and a Robux **Overlord Egg** | ORIGINAL roster |
| Potions 2x for 10 minutes; Friend Boost +10% | LIKELY | The same values. Friend Boost is capped at +50% | LIKELY |
| Gifts (red badge), Trails, Inventory, Codes in the Shop | OBSERVED / CONFIRMED | 12 playtime gifts plus a 7-day daily track. Trails give +Wins. Codes box at the bottom of the Shop | ORIGINAL contents |
| Gems counter | Misread | Not a currency. That counter is rebirths | OBSERVED correction |
| Worlds: lava (W2), pirate (W3) | OBSERVED | Sunny Isles → Ember Crater → Buccaneer Bay → Frost Peaks | ORIGINAL names |
| Max 10 players per server | CONFIRMED | Recommended in the docs. It is set in Studio, not in code | Note |

### First-response sections A–J (the brief's required format)

| Section | Topic | Where it lives |
|---|---|---|
| A | Research | Parts 1–2 above |
| B | Gameplay loop | `DESIGN.md` §1 |
| C | Physics reconstruction | `DESIGN.md` §2 and `Sim/FlightSim.luau`. The original stone physics are UNKNOWN (no source documents them), so our flight model is ORIGINAL |
| D | Map | `DESIGN.md` §5 and `server/World/MapBuilder.luau` |
| E | UI | `DESIGN.md` §6 and `client/UI` |
| F | Economy | `DESIGN.md` §3, `Config/Economy.luau`, `Definitions/*`, and the pacing simulation in `tests/progression.spec.luau` |
| G | Architecture | `DESIGN.md` §4 |
| H | Creative differences | Part 3 above |
| I | Roadmap | `README.md` |
| J | Development | the code |
