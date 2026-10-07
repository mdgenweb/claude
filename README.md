# Orb Clash

A Roblox auto-battler that recreates the structure, pacing and presentation of *Ball VS Ball* (by ATYS 3) with an **original roster of 26 "Orbs"** and original art, audio and names.

The loop: pick 1 of 3 random orbs (or use your free collection pick), drag to aim, lock in, then watch the physics fight. A round costs the loser a heart; three hearts lose the match. Coins from wins buy gachas for more orbs and cosmetics, and everything is tradable.

Everything in the world is built from code and config, so the repository is the whole game: lobby, arenas, props, lighting and every UI screen.

## Play it in Roblox Studio

**Option A: open the prebuilt place (no tools needed)**

1. Open `build/OrbClash.rbxlx` in Roblox Studio.
2. *Game Settings → Security → Enable Studio Access to API Services*. Without this, data is kept in memory for the session only.
3. Press **Play**. To test real matches, use *Test → Clients and Servers → 2 players*, or click **Practice Bot** on a battle pad when playing solo.

**Option B: live-sync the source with Rojo**

```bash
rokit install                    # installs rojo / selene / stylua / luau-lsp (see rokit.toml)
rojo build -o build/OrbClash.rbxlx
rojo serve                       # then connect from the Rojo Studio plugin
```

Before publishing, set your own IDs in `src/shared/Config/Economy.luau` (group id, gem developer products). See [docs/CONFIGURATION.md](docs/CONFIGURATION.md).

## What's inside

| Area | Where |
|---|---|
| Research, screenshot forensics, map plan, uncertainties | [docs/RESEARCH.md](docs/RESEARCH.md) |
| Architecture and networking model | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| Tuning every number (economy, physics, timings, audio) | [docs/CONFIGURATION.md](docs/CONFIGURATION.md) |
| Automated tests and the Studio acceptance checklist | [docs/TESTING.md](docs/TESTING.md) |

### Features

* **Battle**:
  * Deterministic, server-authoritative 2D simulation at 60 Hz, with gravity arcs, an energy governor and contact damage.
  * 26 orbs with distinct abilities: wall thorns, boomerangs, moons, leech, goo, magnet pulls, cannons, freeze, mines, prism beams, dice, ghost phasing, venom tails, forge smash, crystal shards, chain lightning, mitosis split, rook charges, rail trains, shackle traps, auras and pumpkin lobs.
  * Overtime rule so every round ends.
* **Flow**:
  * Lobby pads ("1/2 PLAYERS · Win 100", press **E**), a green **Play** quick-join button, invites and practice bots.
  * Match intro, then 3 random offers with reroll and the free collection pick, then drag-to-aim and **Lock Aim**, then 3-2-1, then the fight.
  * Each round ends with the death explosion cosmetic, the flyer finisher hitting the loser, and a heart break. Matches end with victory/defeat, rewards and **Play Again**.
* **1v1 and 2v2**, both on the same framework. Several arenas run at once per server, with nearby players spectating live.
* **Meta**:
  * Coins and gems, plus the Orb, Advanced, Explosion, Flyer and event gachas, with odds shown.
  * Inventory with search, filters and equip.
  * Levels with level rewards, daily quests, codes, the group reward, and all-time and weekly leaderboards with a weekly reward payout.
  * Secure two-party trading.
* **Persistence**: session-locked DataStore profiles with retries, autosave, `BindToClose`, schema migration and sanitisation.
* **Security**: no client remote can grant currency, deal damage or decide results. Every request is rate-limited, type- and bounds-checked, and state-checked.
* **UI**: responsive design-token system scaled from the reference resolution, with safe-area insets, touch scaling and keyboard/gamepad aiming.

### Interpretation note

The brief asked for the balls to be "slightly different". The collectibles are therefore **Orbs**: original designs that cover the same kinds of abilities as the reference roster, but with different names, looks and rules. To rename the fighter noun, edit `src/shared/Config/Branding.luau` and the `DisplayName` fields in `src/shared/Definitions/BallDefinitions.luau`.

## Project layout

```
src/shared   -> ReplicatedStorage.Shared   (config, definitions, net, visual geometry, utils)
src/server   -> ServerScriptService.Server (services, battle simulation, abilities, data)
src/client   -> StarterPlayerScripts.Client(controllers, UI screens/components, VFX)
tests/       -> headless Luau specs (battle matrix, match state machine)
build/       -> generated OrbClash.rbxlx
```
