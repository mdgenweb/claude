# Configuration

Every tunable number lives in `src/shared/Config` or `src/shared/Definitions`. Values marked *(TUNABLE)* in code are not publicly documented for the reference game (see `docs/RESEARCH.md` §F).

## Before publishing

| Setting | File | What to set |
|---|---|---|
| Group reward | `Config/Economy.luau → Group.Id` | Your Roblox group id. `0` means the reward is claimable only in Studio. |
| Gem packs | `Config/Economy.luau → GemProducts[].ProductId` | Developer product ids. `0` means the pack is a free test grant in Studio and "Soon" in live games. |
| Codes | `src/server/Data/Codes.luau` | Server-only list (never replicated). |
| Event end | `Definitions/GachaDefinitions.luau → HarvestCrate.EndsAt` | Unix seconds. |
| Audio | `Config/Audio.luau` | Defaults use built-in `rbxasset://sounds`. Swap in uploaded ids for a richer mix. |
| Leaderboard stat | `Config/Lobby.luau → Leaderboards.Stat` | `"Wins"` (default) or `"RobuxSpent"`, which mirrors the reference's spender boards. |

## Battle feel (`Config/Physics.luau`)

* `Gravity`: 0 gives pure billiard motion. The default of 14 gives arcing bounces.
* `CruiseSpeed`, `GovernorRate`: how fast orbs move, and how quickly lost energy is restored.
* `ContactCooldown`, `SpawnImmunity`, `WallJitterDegrees`.
* Overtime: `OvertimeStart`, `OvertimeStep`, `OvertimeDamageBonus`, `OvertimeAttrition`, `RoundHardCap`.

Re-run the balance matrix after any change:

```bash
python3 tests/run_tests.py --luau <path-to-luau>
```

## Match rules (`Config/Game.luau`)

* `Hearts`.
* `Timings`: selection, aim, countdown, resolution and so on.
* `Selection`:
  * `OfferSource`: `"Global"` or `"Owned"`.
  * `RerollCost` and `MaxRerollsPerRound`.
  * `FreeCollectionPicksPerMatch` and `ExtraCollectionPickCost`.
* `SpawnLayout` per mode, `FriendlyFire`.
* `Bots`: practice bot toggle and reward multiplier.

## Economy (`Config/Economy.luau`)

* Starting coins, gems, orbs and cosmetics.
* Match rewards (win 100 / loss 20 coins).
* XP curve (`XPToNext`), weekly leaderboard rewards and limits.

Crate prices and odds are in `Definitions/GachaDefinitions.luau`. The Flyer crates copy the reference store exactly: 1000 coins with odds 87 / 10 / 2.5 / 0.5, and 100 gems with odds 79 / 18 / 3.

## Content

* **New orb**: add a `define(...)` entry in `BallDefinitions.luau` (stats, `AbilityParams`, `Visual`).
  * If it needs new behaviour, add `src/server/Battle/Abilities/<AbilityId>.luau` with any hooks.
  * If it needs new art, add an emblem painter in `src/client/UI/Components/OrbArt.luau`.
  * List its gacha source in `Obtain`.
* **New cosmetic**: add a `define(...)` in `CosmeticDefinitions.luau`. Its `Style` must exist in `VFX/Explosions.luau` or `VFX/CosmeticModels.luau`.
* **New crate**: add it to `GachaDefinitions.luau`. It appears automatically in its store tab.
* **Lobby layout**: `Config/Lobby.luau` (stations, props, chevron path). Arena proportions are in `Visual/ArenaGeometry.luau`.
