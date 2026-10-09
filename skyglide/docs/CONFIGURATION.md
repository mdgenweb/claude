# Configuration

Every tunable value lives in `src/shared/Config` (rules and numbers) or `src/shared/Definitions` (content). No gameplay numbers are hard-coded in services.

## Before publishing

| Setting | File | What to set |
|---|---|---|
| Game passes | `Config/Monetization.luau → Passes[].Id` | Your pass ids. With `0`, the pass is a free test grant in Studio and is shown as "SOON" (disabled) in live games. |
| Developer products | `Config/Monetization.luau → Products[].Id` | Your product ids. `0` behaves the same as for passes. |
| Admins | `Config/Admin.luau → UserIds` | Your user id(s). `StudioAll = true` gives everyone the admin panel in Studio only. |
| Codes | `src/server/Data/Codes.luau` | Server-only list. It is never replicated to clients. |
| Relic stock | `Definitions/Relics.luau → Stock` | The global limit. Sales are counted in the `SkyGlide_Global_v1` DataStore. |
| Live events | `Config/Events.luau` | `Schedule` windows (unix seconds, UTC) for Sky Festival boosts. Admins can also start or stop one from the Admin panel. |
| Audio | `Config/Audio.luau` | Defaults use built-in `rbxasset://sounds`. Swap in your own uploaded ids. |

Enable *Game Settings → Security → Studio Access to API Services* to test persistence in Studio. Without it, DataService falls back to an in-memory mock and prints a warning.

## Flight feel (`Config/Flight.luau`)

| Group | Knobs |
|---|---|
| Distance from Skill | `DistanceBase`, `DistanceScale`, `DistanceExponent` |
| Launch meter | `MeterPeriod`, the `LaunchMin..LaunchMax` band, `PerfectLaunchAt`, `PerfectLaunchMultiplier` |
| Rendering | `RenderScale`, `RenderD0`, `RenderMaxZ` (bounded channel length) |
| Timing | `Time*`, `EaseExponent` |
| Rings | `Ring*`. `RingMinGap` must stay at or above `GustEarly + GustLate + GustMaxLatency` (0.72 s), or spam-tapping starts to work |
| Gust taps | `GustEarly`, `GustLate`, `GustMaxLatency`, `GustTooEarly`, `PerfectMultiplier`, `GustTapSlack` |
| XP per throw | `XPBase`, `XPPerRing`, `XPZoneBonus` |

Re-run `python3 tests/run_tests.py` after any change. The flight spec checks the ring gaps and the anti-spam property.

## Progression (`Config/Economy.luau`)

| Setting | What it controls |
|---|---|
| `LevelCapBase` / `LevelCapPerRebirth` | Level cap, which gates rebirth |
| `XPBase` / `XPQuad` | XP curve |
| `RebirthStep` | Multiplier per rebirth |
| `TrainManualRate`, `TrainAutoInterval` | Training rates |
| `PetSlots`, `PetSlotsPass`, `PetInventory` | Pet limits |
| `FriendBoostPer` / `FriendBoostMax` | Friend boost |

## Content (`src/shared/Definitions`)

| What | How to add or change it |
|---|---|
| Glider | Add an `add(world, id, name, price, skillPerRing, rarity, shape, primary, secondary, glow)` line in `Gliders.luau`. Shapes: Dart, Wide, Leaf, Feather, Kite, Crane, Jet, Bat, Star. Its pedestal appears automatically in its world. |
| Pet | `add(...)` in `Pets.luau`, then reference it from an egg in `Eggs.luau` with a weight. |
| Egg | Add an entry to `Eggs.luau` with a `World`. It is placed on the egg row automatically. A Robux egg uses `ProductKey` and `World = nil` and appears in every world. |
| World | Add an entry to `Worlds.luau` (`DistanceScale`, unlock gates, `Theme`), plus a palette in `Visual/Themes.luau` and zone names in `Zones.luau`. Pads come from the `ROWS` table in `Training.luau`. |
| Zone | Edit the `BASE` (meters and wins) table or `NAMES` in `Zones.luau`. Signs are rebuilt from it. |
| Trail | `Trails.luau` |
| Potion | `Boosts.luau` |
| Gifts and daily rewards | `Rewards.luau` |
| Tutorial | `Tutorial.luau`. Steps complete on server events: Train, EnterThrowZone, Throw, Ring, BuyGlider, Hatch. |
