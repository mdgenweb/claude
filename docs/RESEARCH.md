# Milestone 1: Research report and reconstruction spec

Project codename: **Orb Clash**. It recreates the structure and feel of the Roblox experience *Ball VS Ball* (group **ATYS 3**) with an original roster of "Orbs". All art, audio, names and assets are original.

Research date: **2026-10-07**.

---

## A. Current version research

### Source access in this environment

The build sandbox's egress proxy blocked direct page fetches (roblox.com, games.gg, allthings.how, progameguides.com, ballvsballgame.com all returned `EGRESS_BLOCKED`), and YouTube footage could not be watched. The evidence therefore comes from three places:

1. **The five attached screenshots.** These are the primary visual ground truth.
2. **Search-engine extracts of the official Roblox listing and current guides.** Extended web searches returned text excerpts from roblox.com, rolimons, sportskeeda, games.gg, progameguides, allthings.how, pcgamesn, pockettactics, beebom, robloxden, destructoid and several fan wikis.
3. **Cross-checking between sources.** Low-reliability SEO "wiki" domains (`ballvsball-wiki.wiki`, `ballvsball.top`, `ballvsball.pro` and similar) were only used when a better source agreed with them.

### Build timeline (from sources)

| Fact | Source(s) | Recency |
|---|---|---|
| Created by **ATYS 3**, place id 96510596525082 | roblox.com listing, rolimons | current |
| Launched **12 Aug 2026**; ~41.8M visits, ~35k CCU by late Sept 2026 | robolibrary / guides | Sept 2026 |
| **Update 8 released 4 Oct 2026**, code `UPD8` = 100 coins | pcgamesn, pockettactics, beebom (Oct 2026 code lists) | 3 days old |
| Codes UPD1–UPD5 = 100 coins each (25 Sept list) | destructoid, progameguides | ~2 weeks old |
| Official description: *"auto-battle PvP, 1v1 and 2v2, choose 1 of 3 random balls each round, or pick any ball from your collection, free once per match, collect 40+ balls each with its own skill, trade balls with other players, join the group for free rewards"* | roblox.com listing excerpt | current |
| "42 balls across Mythic, Legendary, Epic and Rare" | progameguides tier list (Sept 2026) | ~3 weeks old |

### Evidence classification

| Mechanic | Status | Evidence |
|---|---|---|
| Auto-battle: aim once, then no input | **CONFIRMED** | Official listing ("auto-battle"); every guide |
| 1v1 and 2v2 modes | **CONFIRMED** | Official listing; screenshot 5 shows a "2V2" station |
| 3 random balls offered each round | **CONFIRMED** | Official listing |
| Pick from own collection, **free once per match** | **CONFIRMED** | Official listing wording |
| Rerolling the 3 offers costs gems/diamonds | **LIKELY** | Several guides; the diamond currency appears in screenshots |
| Whether the 3 random offers come from your collection or the global pool | **UNKNOWN** | One guide says "from what you own". The official wording ("or pick any ball from your collection") reads as if the random 3 are global. → We draw from the global pool, weighted by rarity, and record this in config. |
| 3 hearts per player, a lost round costs one heart | **CONFIRMED** | Screenshot 4 (3 hearts in the HUD and above each head); multiple guides |
| Winning ball flies at the loser and knocks off a heart | **LIKELY** | Several guides; "Flyers" are described as cosmetics for that animation |
| Ball HP number drawn on the ball | **CONFIRMED** | Screenshot 4 ("74" and "70") |
| Vertical square arena seen front-on, players standing beside it | **CONFIRMED** | Screenshot 4 |
| Collision damage plus ability damage | **LIKELY** | Guides ("drain the HP"). Exact numbers are unpublished; one guide quotes "glass shard = 4 damage". |
| Gravity in the arena | **UNKNOWN** | Screenshot 4's vertical particle trail and floor spikes are consistent with gravity; no source confirms it. → Exposed as a config value (default ON, Earclacks-style arcs with energy conservation). |
| Round timeout or sudden death | **UNKNOWN** | No source. → Our own overtime rule, configurable. |
| Win reward 100 coins | **CONFIRMED** | Screenshots 2 and 3 ("Win 100" on the pads); guides |
| Loss reward 20 coins | **LIKELY** | allthings.how |
| Lobby queue pads ("1/2 PLAYERS", Win 100, press E, Invite and Leave panel) | **CONFIRMED** | Screenshots 2 and 3, plus guide text |
| Green **Play** button | **CONFIRMED** | Screenshots 1 and 3. Its exact behaviour is unknown → quick-join the best open pad. |
| White chevron arrows guiding new players | **CONFIRMED** | Screenshot 5; guide |
| Store tabs: Events, Balls, Explosions, Flyers | **CONFIRMED** | Screenshot 1 |
| Coins and Diamonds (premium, "+" purchase button) | **CONFIRMED** | Screenshots 1 and 3 |
| Flyer crates: Coins (1000 / 10000; Uncommon 87, Rare 10, Epic 2.5, Legendary 0.5) and Diamonds (100 / 1000; Rare 79, Epic 18, Legendary 3) | **CONFIRMED** | Screenshot 1. A guide's "60 gems" price is outdated. |
| Items are "Tradable" | **CONFIRMED** | Screenshot 1 badge; official listing (trading) |
| Ball gacha price | **UNKNOWN** | Guides disagree (150 vs 600 coins) → `Economy.luau`, marked tunable |
| Advanced Ball Gacha granted by Like + Join Group | **CONFIRMED** | Screenshot 5 sign ("Advanced Ball Gacha +1"), guides |
| First-battle Ball Gacha reward | **CONFIRMED** | Screenshot 3 modal |
| Level system: XP bar, "Lv 2 → Lv 3", "10 / 40", level reward is a ball | **CONFIRMED** | Screenshot 3 |
| Daily-style quests (Duel with a friend 0/1, Win 3 times, Play 10 times; ×200 coins) | **CONFIRMED** | Screenshot 3. The daily reset period is **LIKELY**. |
| Emotes button ("R") | **CONFIRMED** | Screenshot 3 |
| Top Spenders and Weekly Top Spenders boards with a rewards column | **CONFIRMED** | Screenshot 5 |
| Timed event display ("Ends in 13d 1h") | **CONFIRMED** | Screenshot 5 |
| Explosions = end-of-round death cosmetic; Flyers = finisher cosmetic | **LIKELY** | Two independent guides |
| Ball families mentioned by guides (S-tier: rails/train, lasers, zones, shackle traps, vampire drain; also webs, glass shards, axe, knives, poison spikes, blades, cannon, chess, dice, cell split) | **LIKELY** | Several tier lists. Used only as *archetype inspiration*. Our roster is original. |
| Codes redeemed through a Gift → Codes menu | **LIKELY** | destructoid |
| Daily login rewards | **UNKNOWN** | No evidence → not implemented |

---

## B. Verified gameplay loop (current build, reconstructed)

1. **Lobby.** The player spawns on a compact navy plaza. White chevrons point toward the duel stations. Each station is a vertical black arena box with two (1v1) or four (2v2) standing pads. A floating label reads `0/2 PLAYERS · Win 100`.
2. **Queue.** The player either presses **E** on a pad or clicks the green **Play** button (quick-join). The player is held on the pad. The label changes to `1/2 PLAYERS`, and a matchmaking panel with **Invite** and **Leave** appears.
3. **Match found.** When the pads fill, a short countdown runs. Characters are locked on their platforms beside the arena, and the camera moves to a front-on view of the arena.
4. **Round start → ball selection.** Each player sees **3 random balls**. They can **reroll** (diamonds) or use the **free collection pick** once per match. The selection timer then expires or everyone confirms.
5. **Aim.** Each chosen ball appears frozen in its half of the arena. The player drags to set a direction, sees a dotted trajectory, and presses **Lock Aim**.
6. **Launch → auto battle.** A 3-2-1 countdown, then both balls launch. They bounce off the walls and each other, collisions deal damage, and abilities fire automatically. HP is drawn on each ball. Players have no further input.
7. **Round result.** A ball reaching 0 HP plays the owner's **Explosion** cosmetic. The winning ball then flies at the losing player (the winner's **Flyer** cosmetic) and a heart breaks.
8. **Next round** until a side reaches 0 hearts (first to take 3 hearts).
9. **Match result.** Victory or defeat presentation, then rewards: 100 coins for a win, 20 for a loss, plus XP and quest progress. On a first battle, the Ball Gacha modal appears.
10. **Return.** Players are released in front of the station and can press Play again.

2v2 uses the same flow. Four balls share one larger arena, hearts are per team, and friendly balls bounce off each other without damage. The friendly-fire and team-heart rules are **UNKNOWN** in the source and live in config.

---

## C. UI reconstruction (screenshot forensics)

Coordinates are pixels in each screenshot. The "design units" are what the implementation uses under `UIScale`.

### Screenshot 1: Store, Flyers tab (1222×892 crop)

* **Panel**: about 1135×810 px, background `#151B2C` at roughly 4% transparency, 2 px border `#3A6FD6`. The panel nearly fills the window.
* **Title** "Store": top-left, about 55 px cap height. Geometric display font, white, with a thin dark stroke. → `Theme.Fonts.Display` (Michroma) at 54 px.
* **Currency bars** (top-right):
  * Coin bar 245×44: orange gradient `#FFB300→#F08C00`, dark 2 px border. A 76 px coin icon overlaps its left end. Value right-aligned in the display font with a black stroke.
  * Diamond bar 255×44: blue gradient `#4DA0FF→#2C6FE0`, with an 80 px gem icon.
  * "+" button: 50×50 square, `#2F7BF5`, white plus sign.
* **Close button**: 62×95 light-grey block `#D9DCE1` sitting on the panel's top-right corner, with a heavy "X" in a dark stroke.
* **Tabs** (y 138–232): Events 125 wide (blue `#3F8FF0`), then Balls, Explosions and Flyers at 260 wide each (`#FFA600`, `#A64BF4`, `#FF4F7B`). Each tab has a 2 px dark border and a 6 px corner. The label is bold white with a dark stroke, about 38 px. A large icon sits behind or above the label and breaks out of the top of the tab.
* **Sub-bar**: y 250–300, empty dark strip `#1A2134`.
* **Crate cards**: two visible, 555×535 each, 10 px gap, background `#1B2236`, 2 px border `#3A6FD6`, plus a blue square **">"** pager button on the right.
  * Header: currency glyph + crate name (display font, 24 px) and "🤝 Tradable" (green `#4CD420`, 26 px bold).
  * Crate art: 250×195 framed image. Dark navy for the coin crate; magenta→violet gradient with pink border for the diamond crate.
  * Odds list: 4 rows at 33 px pitch. Label in the rarity colour, value right-aligned white, 26 px bold body font.
  * "Prize Preview" (30 px bold) and "View All >" (24 px).
  * Prize strip: 158×155 cards with a 2 px rarity border, item art, and a name bar at the bottom (22 px bold, white with stroke). The strip clips the fourth card.
  * Buttons: "Open 1" and "Open 10", 241×68 each. Light-grey gradient `#D5D8DE→#9CA2AB`, dark 2 px border. Label 26 px and price 34 px display font, plus a 40 px currency icon.
* **Rarity colours**: Uncommon `#5CCF1A`, Rare `#5AAAF0`, Epic `#B24DFF`, Legendary `#FFA000`, plus our Mythic `#FF3D6E`.

### Screenshot 2: Reward reveal "Reforge Ball" (652×596 crop)

* Square panel about 290×290, `#151B2C`, with a soft cyan outer glow and a sunburst of about 14 light rays (white→transparent cyan) radiating behind the art.
* Title at the top, bold white body font with stroke, about 30 px.
* Art: the main item, with a secondary smaller item overlapping top-left. Balls are flat-shaded spheres with a bold pictogram.
* **"Receive"** button: 220×58, green `#6FE01E→#3EAA00`, dark 2 px border, display font about 40 px, white with dark stroke.
* Background world: "1/2 PLAYERS" and "in 100" in floating world text, a "VS" screen on the station, and other players walking around the pads.

### Screenshot 3: Lobby HUD with first-battle modal (1795×914)

* **Left rail**:
  * "Store" tile 115×115 at (20, 140): dark translucent `#0E1220` at about 35% transparency, 2 px blue border, icon (gacha machine) on top, label "Store" in the display font with stroke at the bottom.
  * "Inventory" tile at (20, 288), same style, box icon.
  * "Emotes [R]" pill 173×58 at (20, 437) with a key-cap chip.
* **Currencies** (bottom-left):
  * Coin icon 76 px at (12, 715), "200" in gold `#FFC72C` display font 58 px with a 3 px dark stroke.
  * Gem icon 84 px with a "+" badge at (8, 795), "0" in pale blue `#D8ECFF` 58 px.
  * A faint dark horizontal gradient strip behind each row.
* **Level bar** (top centre):
  * "Lv 2" (26 px display font, grey `#C9C9C9` with stroke), then a 380×15 track `#2B2B2B` with a light border and grey fill `#9C9C9C`, then "Lv 3".
  * "10 / 40" centred below at 20 px.
  * To the right: a "Lv3 Reward" micro-label above the reward ball's icon and its name in the display font.
* **Quests** (top-right, about 215 wide, 60 px rows):
  * Title (26 px bold body font, white), progress "0/1" (18 px display font, grey), reward "🪙 X200" (gold, 20 px display font).
  * Dark right-to-left gradient backdrop.
* **Play** button: 288×63 at bottom centre, green `#4CAF12→#3A8F0A`, dark border, "Play" in the display font at 44 px.
* **Next level reward pill** above Play: "Lv 3 Reward" plus the item icon, dark translucent.
* **Modal**:
  * 808×454, `#121729` at about 8% transparency, 2 px border `#3366CC`.
  * Title (30 px bold body font).
  * Art card 180×232 with a pink 2 px border and a magenta→purple vertical gradient.
  * **Claim** button 272×68, blue `#2F6CF5`, display font 40 px with stroke.

### Screenshot 4: Battle (1867×890)

* **Camera**: front-on with roughly zero pitch, FOV about 70°. The arena's outer frame fills about 97% of the screen height. Each player stands on a raised side ledge with a blue edge band.
* **Arena**:
  * Black interior with a visible shallow depth: the inner side faces are lighter grey trapezoids.
  * Outer frame dark grey, about 1/17 of the arena width.
  * Spikes (grey pyramids) grow from all four walls (that ball's ability).
* **Balls**: "74" (Big Spike Ball, white, about 0.22 of the interior width) and "70" (Thief Ball, dark indigo with a band and a dagger glyph, about 0.19). HP is a bold white number with a black stroke at about 25% of the ball diameter. A dotted particle trail follows the moving ball, and a thrown dagger is visible.
* **HUD** (mirrored left and right):
  * 105 px circular avatar with a 3 px team ring (red `#FF2B2B` left, cyan `#19B6FF` right).
  * Name in the display font at 30 px, in the team colour.
  * Three 45 px hearts `#EF2B3C`.
  * Ball name (26 px bold body font, white with stroke).
  * 115 px circular ball icon.
* **World**: three hearts above each character's head (BillboardGui). Characters face the camera.

### Screenshot 5: Lobby overview (1147×689)

* Raised navy plaza (`#1E2A45` floor, `#3D7BE0` edge trim) over a flat light-grey void (atmospheric fog). A floating giant decorative ball with goggles sits top-left.
* Top Spenders and Weekly Top Spenders boards at the north edge: rank, flag, name, amount, and a rewards column on the weekly board. The local player's own rank row is pinned at the bottom (#51).
* **2V2** sign over a glowing cyan cube station in the centre-north, with pads on both sides.
* **Balls** gacha machine (red base, glass dome full of balls) on the east side. A smaller purple-glow machine behind it.
* **Flyers** display (UFO with a light cone over a pedestal) on the west side, and a timed-event pedestal ("Ends in 13d 1h") with a glowing winged item.
* "Like + Join Group / Advanced Ball Gacha +1" sign on a black pedestal, front-centre.
* White chevron arrows from the spawn flowing south-east toward the duel area.
* Quest list visible top-right (same HUD).

---

## D. Map reconstruction (studs)

Scale reference: R15 character ≈ 5.3 studs tall.

### Arena station (1v1)

| Element | Size / position (station local, +Z faces the viewer) |
|---|---|
| Interior (simulation plane) | 16 × 16 studs (half-extent 8), centred at the station origin |
| Frame | 1 stud thick, 4.5 studs deep, dark grey; outer size 18 × 18 |
| Back wall | 0.5 stud black, 3.5 studs behind the front |
| Ball plane | z = −1.5 (inside the box) |
| Default ball radius | 1.5 (diameter 3 ≈ 0.19 of the interior, matching screenshot 4) |
| Arena base | Interior bottom 1 stud above the floor, so the station origin is 9 studs above the floor |
| Side ledges | 7 × 6 studs, top 4.2 studs above the floor (feet 4.8 below the arena centre, matching screenshot 4), centred at x = ±12.5. Blue edge band and steps. |
| Pads | Neon ring of radius 2.2 on each ledge |
| Battle camera | (0, 0, +13.3) for 16:9, FOV 70. Distance auto-fits the aspect ratio (shows ledges and players when aspect ≥ 1.5). |
| Status label | Billboard above the arena: "VS", `n/2 PLAYERS`, "Win 100 🪙" |

### 2v2 station

Interior 20 × 20, frame 1, outer 22 × 22. Ledges are 12 wide with two pads each, at x = ±13 and ±18.

### Lobby layout (top-down, +X east, +Z south)

```
            N (z = -80)
  [Top Wins board]          [2V2 STATION]          [Weekly board]
       (-60,-70)              (0,-62)                 (60,-70)

 [Flyers display]                                [Orb Gacha machine]
     (-70,-20)          [giant decor orb]           (70,-20)
 [Explosions display]                            [Advanced machine]
     (-70, 10)                                      (70, 10)
 [Event pedestal]        [Group pedestal]
     (-45, 35)              (0, 25)
                       SPAWN (0, 55)  ──►►►►► chevrons ►►►►►  bridge (x 100..130, z 40)
                                                                   │
                                    DUEL HALL (x 130..330, z 0..80) │
                                    4 stations on the north wall, facing south
                                    4 stations on the south wall, facing north
```

* Plaza: 200 × 150, floor top at y = 0, raised 6 studs above the void baseplate, cyan trim.
* Duel hall: 200 × 80 floor, 8 × 1v1 stations at 46-stud pitch. Stations face into a 30-stud centre aisle that doubles as the spectator area.
* The bridge carries the chevron path, so the arenas are visible from spawn within a few seconds.

---

## E. System architecture

See `docs/ARCHITECTURE.md` for the full tree. In summary:

* **Rojo** project. Everything in the world, including lobby geometry, stations, props and UI, is generated from code and config, so the repository is the single source of truth and builds to a playable `.rbxlx`.
* **Server-authoritative deterministic battle simulation** (`Server/Battle/World.luau`): a pure 2D fixed-step (60 Hz) simulation with its own seeded PRNG. It does not use Roblox physics, so results do not depend on ping or network ownership, and it can be unit-tested headlessly with the Luau CLI.
* **Replication**:
  * 20 Hz binary snapshots (`buffer`, under 800 bytes) over `UnreliableRemoteEvent`, only to clients within viewing range.
  * Discrete events (hits, spawns, deaths, ability FX) over a reliable `RemoteEvent`.
  * Clients interpolate with a 100 ms buffer and render the balls, hazards, VFX and audio locally.
* **Ability framework**: `BallDefinitions` holds the data. Each `Abilities/<Id>.luau` module implements optional hooks (`Init`, `OnLaunch`, `OnWallHit`, `OnBallHit`, `OnDamageTaken`, `OnDamageDealt`, `OnTick`, `OnHealthChanged` / thresholds, `OnDeath`, `OnKill`) through a safe `AbilityContext`. Adding a ball means adding a definition, an optional ability module, and a visual spec. The match loop is never touched.
* **Services**: Data (session-locked DataStore profiles with migration), Economy, Gacha, Quest, Level, Code, Reward, Monetization, Leaderboard, Trading, Queue, Arena, Match, Ball, Ability, Lobby, BattleReplicator.
* **Client controllers**: State, UI (screens built from a design-token system), Camera, Aim, BattleRenderer, VFX, Audio, Lobby, Emote.
* **Security**: no client→server remote carries currency, damage or results. Every remote is rate-limited and type- and bounds-checked, and every action is state-checked against the server's match, queue or trade state.

---

## F. Differences and uncertainties

1. **Gravity** (UNKNOWN). Default ON with energy conservation (`Config/Physics.luau → Gravity`). Set it to 0 for pure billiard motion.
2. **Source of the 3 random balls** (conflict between the official wording and a guide). Default: the global roster weighted by rarity (`Config/Game.luau → Selection.OfferSource = "Global"`); `"Owned"` is supported.
3. **Reroll and extra collection-pick costs** (UNKNOWN). 10 💎 reroll and 25 💎 for extra collection picks, both tunable.
4. **Ball gacha prices** (sources conflict). 600 coins / 100 💎, tunable. Cosmetic crate prices and odds are taken directly from screenshot 1.
5. **Round timeout** (UNKNOWN). Overtime begins at 40 s: damage +25% every 5 s plus 1 HP/s attrition, with a hard cap at 120 s.
6. **2v2 specifics** (UNKNOWN). One shared arena, 4 balls, team hearts, no friendly damage.
7. **Leaderboards**. The original ranks Robux spending. Ours ranks wins by default; `Config/Lobby.luau → Leaderboards.Stat = "RobuxSpent"` switches back.
8. **Exact fonts**. The original's display face is approximated with Michroma (wide geometric) plus a UIStroke. The body face is Source Sans Pro Bold, which matches.
9. **Audio**. Uses Roblox built-in `rbxasset://sounds/*` effects with pitch variation. Every ID lives in `Config/Audio.luau`, ready to swap for uploaded original audio.
10. **Practice bot** (our addition, clearly labelled). Lets solo testers play in Studio and fills empty servers. Rewards are reduced.
11. **Roster**. Per the brief ("make them slightly different"), the 26 collectible **Orbs** are original designs. They cover the same archetypes as the original (wall hazards, projectiles, lasers, drain, traps, splitting, zones, rails), but every name, look and rule is different.

## G. Implementation plan and status

"Implemented" means the code exists, type-checks against the Roblox API, and (where marked) passes the headless specs. Visual tuning inside a running Roblox client is still required (see TESTING.md).

| # | Milestone | Status |
|---|---|---|
| 1 | Research and reconstruction spec (this file, ARCHITECTURE.md) | done |
| 2 | Lobby and arena builders with the measured proportions | implemented |
| 3 | 1v1 vertical slice: pads, Play, selection, aim, launch, simulation, damage, hearts, rounds, victory | implemented and spec-tested (match.spec) |
| 4 | Ability framework and prototype orbs (contact, projectile/laser, arena hazard) | implemented and spec-tested (battle.spec) |
| 5 | Battle UI, camera, VFX and audio | implemented |
| 6 | 2v2 on the same framework | implemented and spec-tested |
| 7 | Inventory and session-locked persistence | implemented |
| 8 | Coins, rewards, gacha, levels, quests, codes, group reward | implemented |
| 9 | Secure trading | implemented |
| 10 | Full roster (26 orbs, 10 explosions, 11 flyers) | implemented, balance-tested (25–66% win rates) |
| 11 | Lobby polish: leaderboards, event display, chevrons, props | implemented |
| 12 | Mobile and console input, safe areas, exploit hardening | implemented; device testing pending |
