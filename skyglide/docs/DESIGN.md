# Sky Glide: design and module contracts

This document is the **single source of truth** for how the game plays and how modules talk to each other. Every value it mentions lives in `src/shared/Config` or `src/shared/Definitions`. Each section is labelled CONFIRMED, OBSERVED, LIKELY, UNKNOWN or ORIGINAL DESIGN (see `RESEARCH.md`).

## 1. Core loop

The structure mirrors the reference genre loop; the core action is new (ORIGINAL DESIGN).

```
Train on pads (+Skill) ─► Throw a glider from the Throw Zone ─► glider rides thermal rings (+N Skill each,
   ▲                                                                  x2 on PERFECT tap)
   │                                                                ─► lands in a distance zone (+Wins, +XP)
   │                                                                          │
   └── Rebirth at max level (x multiplier, reset Skill/Level) ◄── buy gliders / eggs / trails / worlds with Wins
```

**Core action: thermal gliding (replaces stone skipping).**

1. **Launch.** The player holds **THROW**. A launch meter ping-pongs 0→1→0 every 1.3 s, and releasing sets the launch multiplier:
   * 0.85–1.15 normally;
   * **PERFECT LAUNCH** (x1.25) when the meter is at 0.9 or higher.

   The server times the meter from its own clock: it measures from the charge-start intent to the release intent.
2. **Flight.** The glider flies down the channel and passes through glowing thermal rings. Ring spacing tightens geometrically, which creates an accelerating rhythm. Each ring pays `+N Skill` (the glider stat) x the Skill multiplier.
3. **Gust tap.** Tapping (click, tap, Space or gamepad A) within 0.3 s before to 0.12 s after a ring (plus a ping allowance of up to 0.3 s) makes that ring **PERFECT**, which pays x2 Skill and plays a bigger effect.
   * Tapping more than 0.3 s and up to 0.9 s early spends that ring as a miss, so spam-tapping never works.
4. **Landing.** The glider splashes into the water. The zone it lands in pays `zone.Wins x Wins multiplier`, plus XP.

Distance is computed from Skill: `D = (6 + 4.5 * Skill^0.4) * launchMultiplier` meters. Flight time, ring count and apex height grow logarithmically with D (`Config/Flight`).

**Special throws (LIKELY in the reference: a 1/100 "secret" x3 throw and a 1/1000 giant throw; ours are original).**

* JET STREAM: 1% chance, x3 distance.
* SKY TITAN: 0.1% chance, x8 distance.

Both are rolled from the server seed. `plan.Special` carries the id; the server announces it to everyone and the client shows a cinematic banner.

**World unlock (CONFIRMED rule).** A throw that lands in a world's **last zone** opens the next world. We add a rebirth gate on top (W2: 5 rebirths, W3: 7, W4: 9) so that a lucky special throw can't skip a world. If the end is reached before the gate is met, the portal unlocks later, once the rebirths are there.

### Why it hooks like the reference

* Every ring is a small, predictable "+N" reward with a rising chime, like bounces.
* PERFECT taps add a skill layer that the reference doesn't have.
* Long throws create anticipation: the distance counter keeps climbing while zone signs fly past.

## 2. Flight model (`Sim/FlightSim`, pure and shared)

`FlightSim.Build{...}` returns a **Plan**:

```
{ Id, UserId, World, Seed, Distance (m), Duration (s), Length (studs), Height (studs),
  Rings = {u1..uK} (fractions of the path), RingTimes = {t1..tK}, Sway, SwayFreq,
  Glider (glider id or "relic:<id>"), Trail (id or nil), Launch (0..1), PerfectLaunch,
  Special ("JetStream" | "SkyTitan" | nil), Start (server time) }
```

* **Logical vs. rendered.** Logical meters are unbounded. The rendered path is `Z(d) = 900 * ln(1 + d / (40 * world.DistanceScale))` studs, capped at 8000. Very long throws therefore never leave the channel and never hit float-precision trouble.
  * Zone signs are built at `Z(zone.Distance)`, so flights and signs line up exactly.
* **Motion.** Rendered progress is `u(t) = 1 - (1 - t/T)^1.5`, which gives a fast launch and a soft landing.
* **Sampling.** `FlightSim.Sample(plan, t, worldScale)` returns `{Progress, Z, X, Y, Distance, Landed}`. Distance is the counter value in meters.
  * `Map.ChannelPoint(world, X, Y, Z)` converts a sample to a world position.
* **Clock.** Clients compute `t = workspace:GetServerTimeNow() - plan.Start`. This is the same clock the server uses to pay rings.

## 3. Progression (`Sim/Progression`, `Config/Economy`)

| Thing | Rule | Label |
|---|---|---|
| Level | **derived from Skill**. Level L starts at 1.2 x (1.18^(L-1) - 1) / 0.18 Skill. The bar shows Skill progress inside the level (`Data.XP` / `Derived.XPToNext`) | LIKELY. It is fitted to the OBSERVED HUD: Level 50 at 25.29K Skill showing "3.07K / 4.05K" |
| Level cap | 20 + 20 x rebirths. At the cap, **training and rings stop paying Skill** (purchases, gifts and codes still pay) | Cap: LIKELY. Skill stopping at the cap: CONFIRMED |
| Rebirth % | level / cap | LIKELY |
| Rebirth multiplier | 1 + 2 x rebirths | LIKELY (x1 at 0, x5 at 2) |
| Skill multiplier | rebirth x (1 + Σpet skill) x 2x pass x potion x (1 + friend boost) x premium 1.1 | ORIGINAL composition |
| Wins multiplier | (1 + Σpet wins) x (1 + trail) x 2x pass x potion | ORIGINAL |
| Friend boost | +10% Skill per friend in the server, max +50% | OBSERVED HUD label; values ORIGINAL |
| Training rep | pad multiplier x Skill multiplier. Manual tap rate is up to 6/s; AUTO gives 1 rep per 0.8 s | ORIGINAL |
| Pads | world 1: 1x / 4x / 10x / 20x needing 0 / 2 / 4 / 6 rebirths; ALL WORLDS pass pads 3x / 15x / 50x | OBSERVED |
| Rebirth resets | Skill and Level. Wins, gliders, pets, trails and worlds are kept | CONFIRMED for Skill and Level. Wins being kept is LIKELY |
| Pets | Shown as "xN Skill" (SkillBoost = N - 1); equipped pets add up | LIKELY |
| Potions | 2x Skill / Wins / Luck for 10 minutes | LIKELY |
| Pacing (`tests/progression.spec.luau` simulation) | First rebirth in about 1 min (the tutorial goal). World 1 river end at about 2.3 h, World 2 at about 4.9 h, World 3 at about 9.2 h, World 4 at about 23 h | ORIGINAL tuning |

## 4. Server (authoritative)

Services are listed in `Main.server.luau` ORDER. Each one exposes `Init(registry)` and `Start()`.

| Service | Owns |
|---|---|
| DataService | Session-locked profiles (ProfileStore), view sync (with decorators) and autosave |
| StatService | **All** Skill/Wins/XP grants, multipliers, friend boost, and the `Derived` view block |
| FlightService | Throw state machine, plans, ring payouts, gust judging, landing, auto throw |
| TrainingService | Pad reps (manual and auto) and pad lock checks |
| ShopService | Gliders (buy/equip), relic equip, trails |
| PetService | Hatching (server RNG), pet actions, and the `Pets` player attribute for followers |
| WorldService | Unlock and teleport between worlds, respawn in the current world |
| RebirthService | Rebirth |
| RewardService | Playtime gifts, daily streak, codes (`Data/Codes.luau`, server-only), potions |
| MonetizationService | Passes, products, idempotent ProcessReceipt, global relic stock |
| TutorialService | Steps advanced only from server events |
| LeaderboardService | Leaderstats and global top-10 boards (log-encoded OrderedDataStore) |
| AdminService | Diagnostics for allow-listed admins only |
| MapService / World/MapBuilder | Procedural worlds; spatial queries (pad under player, throw zone) |
| CharacterService | Held glider model, trail and player collision group |

### Remotes (`Net/Remotes.luau`)

Client to server traffic is intents only. Server to client events:

| Event | Payload |
|---|---|
| `PlayerData` | Owner view (below) |
| `Notify` | `{Text, Kind}`; Kind is Info, Success, Error, Level or Rare |
| `FlightStarted` | Plan (broadcast) |
| `FlightRing` | Owner only: `{Id, Index, Perfect, Amount}` |
| `FlightLanded` | Broadcast `{Id, UserId, World, Distance, Zone}`. The owner gets more: `{Wins, Skill, Perfects, Rings, NewBest, NewZone, Special?, UnlockedWorld?, Owner = true}`. A cancelled flight sends `{Id, UserId, Cancelled = true}` |
| `ChargeState` | `{Charging, StartedAt (server time), Reason?}`. Reason is NotInZone, Flying, Cooldown, Loading, Dead or Launched |
| `TrainResult` | `{Amount, Pad}` |
| `HatchResult` | `{Egg, Pets = {{Uid, Id}}, Source?}` |
| `ServerInfo` | `{Kind = "Relics", Relics = {[id] = {Sold, Stock}}}` or `{Kind = "Leaderboards", Boards = {[stat] = {{Name, Value}}}}`; stat is Wins, BestDistance or Rebirths |
| `WorldChanged` | worldId |

### Player data view

`StateController.Data` is built from `Schema.PublicView` plus decorators. It contains these profile fields:

* **Stats and progress:** `Skill, Wins, Level, XP, Rebirths, World`
* **Worlds:** `Worlds{["1"]=true}`
* **Gear:** `Glider, Gliders{[id]=true}, Relic ("" or id), Relics{}, Trail ("" or id), Trails{}`
* **Pets:** `Pets{[uid]={Id,Locked}}, EquippedPets{uid}`
* **Potions and boosts:** `Potions{[id]=count}, Boosts{[id]=unixExpiry}`
* **Daily and tutorial:** `Daily{Day,Streak}, Tutorial{Step,Progress,Done}`
* **Settings:** `Settings{AutoTrain,AutoThrow,FollowCam,Sfx,LowFx}`
* **Records:** `Stats{...}, Best{["1"]=meters}, Zones{[zoneId]=true}, Flags{StarterPack}`

Decorators add these blocks:

* `Derived = {SkillMultiplier, Breakdown{Rebirth,Pets,Pass,Potion,Friends,Premium,Total}, WinsMultiplier, Luck, FriendBoost, Friends, LevelCap, XPToNext, RebirthProgress, CanRebirth, NextRebirthMultiplier, SkillPerRing, PetSlots, Passes{[key]=true}, ServerTime}`
* `Session = {Playtime, GiftsClaimed{index}}`
* `DailyReady`
* `IsAdmin`

## 5. Map layout (`Config/Map`, world-local studs; +Z = back toward spawn)

World N's origin is `((N-1) * 3200, 0, 0)`, and every world uses the same layout.

| Element | Placement |
|---|---|
| Hub floor | X -160..160, Z -40..230. Floor top is Y = 0, and it is surrounded by checker cliff walls 34 studs high |
| Spawn | (0, 3, 190), facing -Z |
| Throw Zone | X -36..36, Z -40..4. Yellow tiles with "THROW ZONE" painted on the floor |
| Channel | Starts at Z = -40 and runs toward -Z for 8000+ studs. Water surface Y = -7, half width 44. Grass banks 26 wide, then checker cliffs 26 high. Zone sign arches stand at Z = -40 - FlightSim.RenderZ(zone.Distance) |
| Training pads | A column on the left at `Map.PadPosition(slot)`, size 24 x 1 x 24 |
| Glider pedestals | Two columns on the right at `Map.PedestalPosition(i)`. The relic pedestal is at `Map.RelicSpot` |
| Eggs | A back-right row at `Map.EggPosition(i)` (`Eggs.ForWorld(world)` order) |
| Portals | Next world at `Map.PortalNext`, previous world at `Map.PortalPrev` |
| Leaderboards | Left wall, `Map.Leaderboards` |

### MapBuilder naming contract (server-built, read by clients)

Under `Workspace.Worlds`:

```
World_<id> (Model)
  ThrowZone (Part)
  Pads/Pad_<padId> (Part)       BillboardGui "Label" with TextLabels "Gate", "Status", "Mult"
  Pedestals/Pedestal_<gliderId> (Model, PrimaryPart "Base")
       Base: ProximityPrompt "BuyPrompt"; BillboardGui "Label" with TextLabels "Status", "Skill", "Price"
       Display (Model): glider model; attribute Spin = true (the client spins it)
  Pedestals/Relic_<relicId> (Model, PrimaryPart "Base")
       Base: ProximityPrompt "BuyPrompt"; BillboardGui "Label" with "Stock", "Title", "Bonus", "Price"
  Eggs/Egg_<eggId> (Model, PrimaryPart "Base")
       Base: ProximityPrompt "HatchPrompt"; BillboardGui "Label" with "Name", "Price"
  Portals/Portal_<targetWorldId> (Model, PrimaryPart "Frame")
       Frame: ProximityPrompt "PortalPrompt"; BillboardGui "Label" with "Name", "Requirement"
  Boards/Board_<Stat> (Part): SurfaceGui "Board" with TextLabel "Title" and Frame "List" (UIListLayout)
  Zones/ZoneSign_<zoneId> (Model)
```

Clients update labels and prompt text locally from their own data (LOCKED / UNLOCKED / EQUIPPED, prices). The server never trusts prompts alone: shop and egg handlers re-check distance and price.

## 6. Client

* **Controllers** (`Start()`):
  * StateController
  * UIController (layers HUD, World, Menus, Overlay and Toasts; `Toast(text, kind)`)
  * AudioController (`Play`, `PlayPitched`, `Loop`, `SetEnabled`)
  * Bus (signals)
  * Net (`Invoke(name, quiet, ...)`, `Fire(name, ...)`)
  * CameraController, WorldController, TrainingController, ThrowController, FlightRenderer, PetFollowController, TutorialController
* **Screens** (`Init()`, registered by name with UIController): Notifications, HUD, Shop, Rebirth, Pets, Egg, Trails, Inventory, Gifts, World, Settings, Admin.
* **HUD layout** (OBSERVED from the reference, original art):
  * Left: a 2-column tile grid. Rows: Shop, Rebirth (with % badge); Pets, Trails; Inventory, Gifts (with red count badge).
  * Bottom-left: Rebirths counter, Wins counter, and "Friend Boost +X%" with a green +.
  * Bottom-centre: "⚡ N SKILL" on the left and "xM Multiplier" on the right, above a wide blue level bar ("Level L", then "x/y" or "MAX LEVEL"). Below it are three Skill pack buttons (+10K gold, +100K red, +1M rainbow) with Robux prices.
  * Top-centre: a red "AUTO THROW" button showing "ONLY R$10", or ON/OFF once owned. During a flight, a big distance counter "144 m" appears under it.
  * Right: offer tiles for Starter Pack, 2x Skill and 2x Wins.
  * Contextual: a big green THROW button and launch meter while in the Throw Zone; a pad panel ("UNLOCKED 1x SKILL", AUTO toggle, TRAIN button) while on a pad.
* **Camera phases:** Hub → Charge (over-shoulder toward the channel) → Launch (pull back) → Follow (behind/above the glider, FOV widens with speed) → Land (hold on the splash for 0.8 s) → Return (tween back, then restore the Custom camera).

## 7. Security rules (enforced)

* No remote grants Skill or Wins, or sets distance, worlds, rebirths or rarity. Every reward is computed by server services.
* Rate limits via `Util/Guard` apply on every endpoint. All arguments are validated with `Util/Validate`.
* Spatial checks happen on the server: pads, throw zone, pedestal and egg reach.
* Robux: receipts are idempotent and confirmed only after the save. Unconfigured ids (0) are free test grants in Studio only and are refused in live servers.
* Admin tools require the allow-list (`Config/Admin`). Normal players never see the panel.
