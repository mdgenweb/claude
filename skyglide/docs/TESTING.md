# Testing

## Automated (no Studio needed)

```bash
# Luau CLI from https://github.com/luau-lang/luau/releases
python3 tests/run_tests.py --luau /path/to/luau
```

The runner bundles the real modules from `src/` into one Luau script with a fake DataModel (`tests/_prelude.luau` adds minimal Roblox API fakes) and runs every `tests/*.spec.luau`.

### `flight.spec.luau` (about 72k checks)

* The distance curve is monotonic and finite for Skill from 0 to 1e300.
* The launch meter stays in range and the perfect threshold holds.
* The render map round-trips with its inverse.
* Zone signs are ordered and stay inside the channel.
* Across 304 plans covering all worlds, Skill levels and launch qualities:
  * plans are deterministic and every value is finite;
  * duration, length and ring count stay within bounds;
  * ring times fall inside the flight and every gap is at least `RingMinGap`;
  * altitude is never negative and the counter never decreases;
  * the flight lands exactly on the plan distance.
* Gust windows: perfect, too early, ignored, the late window extended by ping, and the ping cap.
* A simulated autoclicker tapping at 60 Hz with up to 0.3 s of network delay earns no PERFECTs, while well-timed taps earn all of them.

### `progression.spec.luau`

* The observed anchors hold:
  * level cap 20 at 0 rebirths and 60 at 2;
  * level 50 shows 83%;
  * 4.05K XP at level 50;
  * multipliers of x1 and x5.
* XP and level-ups respect the cap.
* Multiplier composition is correct for pets, passes, potions (including expiry) and friends (capped).
* The relic gives 125% more than the best glider.
* Definition integrity:
  * ids are unique;
  * each world's gliders get better and cost more;
  * pass, product and relic references resolve;
  * egg odds sum to 1 and luck raises rare odds;
  * rewards reference valid content.
* Number formatting is correct.
* Profile sanitisation handles garbage data (NaN, bad ids, duplicates, out-of-range values), never exposes private fields, and is idempotent.
* Pets over the soft inventory cap are never dropped on load (mixed uids sort safely), and the hard limit keeps the oldest uids.
* Pet boosts stop at the slot count.
* An economy simulation of a first session reaches the first rebirth in a sane time window.

### `services.spec.luau`

Drives the **real** server services with stubbed Roblox APIs:

* **Throw state machine:** zone check, a server-timed perfect launch, double-throw rejection, a cooldown after landing.
* **Ring payouts and gust taps:** perfect pays x2; invalid, mismatched and spammed taps are rejected.
* **Landing:** zone Wins, XP, best distance and zone discovery are recorded.
* **Auto throw:** gated by the pass, and it launches for a player who never threw by hand.
* **Quick taps:** a hold shorter than `TapThreshold` launches at `TapLaunchMeter`.
* **Training:** off-pad reps, rebirth-locked pads and pass pads are refused.
* **Shop:** affordability, world lock, duplicates, equipping and trails.
* **Hatching:** cost, auto-equip, the pets attribute mirror, the triple-hatch pass, the Robux egg and world eggs.
* **Pet actions:** lock, delete, equip-best and bad arguments.
* **Rebirth:** what resets and what is kept, plus the multiplier.
* **Worlds:** unlock cost, ordering and travel.
* **Rewards:** daily, codes (case-insensitive, once each) and potions.
* **Monetization:** Studio test grants for passes and products, the one-time starter pack and relic.
* **Tutorial:** only server events advance it, in order.

### `world.spec.luau`

Uses `tests/_rbxmock.luau`, a Roblox API mock with real vector and CFrame math and a generic Instance tree. It:

* builds all four worlds;
* checks the map naming contract the client depends on (`DESIGN.md` §5): every pad, pedestal, relic, egg, portal, leaderboard and zone sign, each with its labels and prompts;
* checks that pad positions match the server's spatial checks;
* checks the per-world part budget (about 2.0–2.4K parts each);
* runs the glider, pet and egg factory self-tests, including held gliders being unanchored and welded.

### `client.spec.luau`

Boots the **real client** the way `Main.client.luau` does: all 13 screens and 7 controllers, against a real World 1 map. `tests/_clientmock.luau` supplies:

* event signals on every instance;
* tweens;
* a virtual-clock task scheduler;
* input, the camera and players;
* remote stubs that record every intent.

It then plays a whole session:

1. The first data packet and live events arrive.
2. The Gifts menu auto-opens because the daily reward is ready.
3. Every menu opens and closes, and data updates while menus are open.
4. The player trains on a pad, including the max-level refusal.
5. The player enters the Throw Zone and charges and releases a throw.
6. A full server flight plays with a gust tap per ring (at most one `RequestGust` per ring), followed by ring payouts and a landing.
7. A Jet Stream special throw and a cancelled flight.
8. A queued 3-pet hatch reveal and a gift reveal, dismissed with gamepad A.
9. Toasts, max level and the Rebirth screen, another player's pet followers, and a world change.

Any error inside a handler, tween, render step or scheduled task fails the spec.

### `playthrough.spec.luau` (end to end, 178 checks)

Boots the **real server** (`Main.server.luau`) and the **real client** (`Main.client.luau`) in one VM. They talk through loopback remotes with 60 ms of latency each way, and the player only acts through the GUI: buttons, proximity prompts, keys, touch and gamepad. `tests/_servermock.luau` supplies:

* in-memory DataStores that enforce Roblox's value rules (no NaN, mixed or sparse tables, 4 MB per key) and can inject failures;
* a virtual clock (`os.clock` / `os.time`), purchase prompts and receipts, BindToClose;
* joining, leaving and rejoining players;
* a check of every remote payload against Roblox's network rules;
* remote events queued until the client listens, as Roblox does.

It plays the Studio checklist below, step by step. Each checklist step names the automated step that covers it. Two more stages:

* **16. A second player:** the Friend Boost, their pets and their flight on our screen, the global leaderboards (OrderedDataStores), and leaving.
* **17. An exploiter:** admin tools are refused for normal players, out-of-order intents grant nothing, and every remote is fuzzed with NaN, infinities, huge strings, nested tables and Instances. There are no handler errors, numbers stay finite, and the profile still saves.

It also checks the UI feedback:

* tiles are raised keys;
* the Gifts tile shakes while a reward waits;
* Wins fly into the counter, which rolls up to the server's total;
* a new best lights the sunburst;
* a refused code shows a red toast;
* a first hatch shows NEW! and lands in the Index, on the server and the client;
* the Index (opened from Pets) shows the pet, and "???" for pets not found yet.

Any client error, network-rule violation or unexpected server warning fails the spec.

### UI on every device: `tests/ui_render.py`

```bash
python3 tests/ui_render.py --luau /path/to/luau   # PNGs and report.txt in tests/.ui/
```

`tests/ui_layout.luau` drives the real client and server into 22 screen states, including the HUD, the throw meter, a flight, the landing card, every menu (the Index too), the hatch reveal, toasts and a hover tooltip. It dumps the GUI tree on six devices:

* PC 1920×1080;
* laptop 1366×768;
* tablet 1024×768;
* phone 844×390 with notch insets;
* small phone 667×375;
* console (ten-foot UI).

The script lays the dumps out like Roblox does: UDim2, AnchorPoint, UIScale, UIPadding, list and grid layouts, aspect constraints, text-size constraints, ScrollingFrame canvases, clipping, ZIndex and safe-area insets.

It draws a PNG for each state and device. The drawing covers:

* UIGradients with colour and transparency keypoints, Rotation and Offset (so shine bands and fading ribbons look as they do in game);
* rotated objects together with their descendants (sunburst rays, tilted badges).

It reports:

* **offscreen:** a button that is not fully on screen;
* **overlap:** buttons on the same layer that cover each other;
* **collide:** HUD groups that run into each other. The landing card, its sunburst and `Fx*` effect frames are left out because they only show briefly;
* **small-touch:** a touch target under 28 px, or under 32 px and narrower than 48 px;
* **tiny-text:** text under 9 px;
* **cut-off:** fixed-size text wider than its box.

It also reports any client error raised while driving the screens. The current result is 128 screens and 0 issues.

### Maps: `tests/map_render.py`

Builds every world with the real MapBuilder and draws a top-down PNG of each hub and each whole world. It checks that station footprints never overlap (pads, pedestals, eggs, portals, boards, throw zone) and that no solid part is buried under the ground (the river bed is meant to be). The current result is 4 worlds, 8,937 parts and 0 issues.

### Performance budget: `tests/perf.py`

The scenario has 10 players (9 on Auto Throw, plus the local player), 30 pet followers and up to 10 flights at once, run for 30 s at 60 fps. Every RunService callback is timed and attributed to its module. Server → client traffic is sized per player, including a full 60-pet profile on Auto Throw.

| Measurement | Result |
|---|---|
| All scripts, client + server | avg 2.6 ms, p95 4.1 ms per frame |
| Pet followers | 1.2 ms (was 15.3 before `FactoryKit.Rig`) |
| Flight rendering | 0.7 ms |
| Spinning shop displays | 0.5 ms (was 2.1) |
| Server flight logic | 0.02 ms |
| Traffic, typical | about 1–3 KB/s per player |
| Traffic, full 60-pet profile on Auto Throw | 4.1 KB/s |

These numbers come from the Luau interpreter with mock instances, where CFrame math is plain Lua. Read them as a regression budget, not as device numbers: real Roblox does that math natively and is faster. The script fails above 6 ms p95 or 20 KB/s.

### Static checks

```bash
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --sourcemap=sourcemap.json --definitions=@roblox=globalTypes.d.luau --platform=roblox src
python3 tests/api_lint.py --defs globalTypes.d.luau src
python3 tests/ui_render.py --luau /path/to/luau
python3 tests/map_render.py --luau /path/to/luau
python3 tests/perf.py --luau /path/to/luau
rojo build default.project.json -o build/SkyGlide.rbxlx
```

`tests/api_lint.py` covers what luau-lsp cannot see:

* every `Instance.new` / `Create("Class", {...})` class is creatable, and every key of a `Create` property table is a real property or event of that class (from the Roblox definitions file);
* every key of a table literal passed to a typed helper (`Create.Text`, `Button.new`, `MapKit.Part`, the menu components...) is a field of its declared type. Luau accepts unknown keys silently, so a typo there would be ignored at runtime.

## Studio acceptance checklist (manual)

Every step below is also played automatically by `playthrough.spec.luau` (step numbers match), so in Studio this is a look-and-feel pass. Use *Test → Clients and Servers* with 2 players, and enable API access for persistence.

1. **Join.** You spawn in Sunny Isles. The HUD shows the left menu (Shop, Rebirth %, Pets, Trails, Items, Gifts), the bottom Skill/multiplier/level bar with three Skill packs, AUTO THROW at the top and offers on the right. The tutorial hint points at the 1x pad, and the Gifts menu opens by itself when the daily reward is ready.
2. **Train.** Stand on the 1x SKILL pad and tap (or press TRAIN). "+N" popups appear and Skill rises. Toggle AUTO. The 4x pad shows LOCKED (2 rebirths).
3. **Throw.** Walk into the THROW ZONE and hold THROW. The meter sweeps; release in the gold band for PERFECT LAUNCH. The camera follows the glider down the channel with a distance counter.
4. **Rings.** Thermal rings approach. "TAP!" pulses and tapping on time shows PERFECT (x2). The chime rises with each ring.
5. **Landing.** The glider splashes in a zone (the banner names it). The result card shows Wins, Skill and XP, and goes away when you start the next throw. Trophies fly into the Wins counter, which rolls up. A new best spins a sunburst behind the card. The camera returns.
6. **Shop.** Buy the Notebook Glider (2 Wins) at the pedestals. It shows EQUIPPED, the held glider changes, and Items lists it.
7. **Eggs.** Hatch a Beach Egg (50 Wins). The reveal plays (NEW! on a first-time pet) and the pet follows you. Check that the Pets menu equip and lock work, and that INDEX shows the pet while the others are "???" silhouettes.
8. **Gifts.** Claim the 1-minute gift and the daily reward. The badge count updates.
9. **Codes.** `LAUNCH` gives Wins and a potion once. Use the potion from Items → Potions and confirm the multiplier doubles.
10. **Rebirth.** Use Admin → Max Level, then Rebirth. Skill resets, the multiplier goes x1→x3 and the level cap rises to 40.
11. **Worlds.** Rebirth 5 times (Admin → Max Level each time), then throw at max level. Reaching the Edge of the Map (the river end) unlocks Ember Crater. Take the portal: the lighting changes and the world 2 pads and gliders appear.
12. **Studio purchases.** The Auto Throw pass is a test grant; AUTO THROW then throws by itself in the zone. Skill packs add Skill. The relic shows its stock and counts down when bought.
13. **Rejoin.** Everything persists (API access on).
14. **Mobile emulator.** The UI scales, menus stay readable, THROW is easy to press (the hint says HOLD), and tapping anywhere counts as a gust tap.
15. **Gamepad.** R2 throws, A taps, menus are navigable and B closes them.

## Known limits of this verification

Verified without Roblox:

* the logic and the server–client flows (all specs, including the end-to-end playthrough);
* the GUI layout on six devices (rendered and linted);
* the map layout;
* the per-frame cost and network traffic.

The code type-checks in strict mode, and misspelled Roblox properties are caught by `tests/api_lint.py`.

The game has **not** been run in a Roblox client from this environment. These still need a person in Studio or on a device:

* **3D look:** materials, lighting, particles, the glider and pet models. The renders above show layout, not Roblox's renderer; fonts and emoji differ.
* **Feel:** camera feel, the meter and tap timing feel, sound mix (built-in `rbxasset://` sounds), and the timing of the UI motion: press-down, shine sweeps, reward fly-in, count-up. The renders show one frame of each.
* **Hardware:** real device frame rate and memory, especially low-end phones (4 worlds of about 2–2.4K parts each are loaded at once).
* **Live services:** real Robux purchases with your own pass and product ids, and DataStore budgets and throttling on live servers.
