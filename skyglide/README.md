# +1 Sky Glide

A Roblox "+1 simulator" inspired by **+1 Stone Skipping** (Meow Labs). It keeps the reference's structure, UI layout, map and loop:

> train → throw → earn → upgrade → fly farther → new worlds → rebirth

The core action is new. Instead of skipping stones, you **throw paper gliders that ride thermal rings**:

* every ring the glider passes pays **+N Skill**;
* tapping right as it reaches a ring makes a **PERFECT** catch and pays x2;
* the glider lands in a distance zone that pays **Wins**.

Everything is built from code and config (map, props, UI, VFX), so this folder is the whole game.

## Play it in Roblox Studio

**Option A: open the prebuilt place**

1. Open `build/SkyGlide.rbxlx` in Roblox Studio.
2. *Game Settings → Security → Enable Studio Access to API Services*. Without this, data lives in memory only.
3. Press **Play**. Use *Test → Clients and Servers* to try 2 players.

**Option B: build or live-sync with Rojo**

```bash
rokit install                                  # uses ../rokit.toml (rojo, luau-lsp, ...)
rojo build default.project.json -o build/SkyGlide.rbxlx
rojo serve default.project.json                # connect from the Rojo Studio plugin
```

Before publishing:

* Set your pass and product ids in `src/shared/Config/Monetization.luau`. Ids left at 0 are free test grants in Studio and are shown as "SOON" in live games.
* Set your admin user ids in `src/shared/Config/Admin.luau`.

See [docs/CONFIGURATION.md](docs/CONFIGURATION.md).

## How it plays

1. **Train.** Stand on a training pad and tap (or toggle AUTO) for Skill. Pads are 1x, 4x, 10x and 20x, unlocked at 0, 2, 4 and 6 rebirths. The ALL WORLDS pass pads give 3x, 15x and 50x.
2. **Throw.** In the yellow THROW ZONE, hold THROW and release in the gold band for a PERFECT LAUNCH. The camera follows your glider down the river while the meter counter climbs and zone signs fly past.
3. **Ride the thermals.** Tap as the glider reaches each glowing ring. A PERFECT catch pays x2 Skill, and the chime rises with your combo.
4. **Land.** The zone you land in pays Wins. Rare **JET STREAM** (x3) and **SKY TITAN** (x8) throws carry you much farther.
5. **Spend Wins** on better gliders (the pedestal row), eggs (pets that multiply Skill) and trails (+Wins).
6. **Level and rebirth.** Skill fills the level bar. At the cap (20 + 20 per rebirth), Skill stops growing, so you **rebirth** for a bigger permanent multiplier and a higher cap.
7. **New worlds.** A throw that reaches the end of the river (with enough rebirths) opens the portal to the next world:
   * Sunny Isles
   * Ember Crater
   * Buccaneer Bay
   * Frost Peaks

Also included:

* playtime gifts and a 7-day daily streak;
* codes (`LAUNCH`, `THERMAL`, `GLIDE`);
* potions;
* Friend Boost;
* Auto Throw;
* Skill packs, the Starter Pack, a limited Aurora Relic and a Robux egg;
* global leaderboards;
* live events;
* a tutorial.

## Docs

| What | Where |
|---|---|
| Research: screenshot forensics, web report, evidence table, uncertainty register, reconstruction decisions | [docs/RESEARCH.md](docs/RESEARCH.md) |
| Design and module contracts: loop, flight model, progression, server, remotes, map, UI, security | [docs/DESIGN.md](docs/DESIGN.md) |
| Tuning every number and adding content | [docs/CONFIGURATION.md](docs/CONFIGURATION.md) |
| Automated tests and the Studio checklist | [docs/TESTING.md](docs/TESTING.md) |

## Project layout

```
src/shared/   Config (Flight, Economy, Map, Monetization, Audio, Admin, Rarity, Branding)
              Definitions (Gliders, Relics, Pets, Eggs, Zones, Worlds, Training, Trails, Boosts, Rewards, Tutorial)
              Sim (FlightSim, Progression)   Visual (Themes, GliderFactory, PetFactory, EggFactory)
              Net (Remotes)   Util (Format, Rng, Signal, Maid, Validate)
src/server/   Main.server.luau, Services/* (one per system), Data (ProfileStore, Schema, Codes),
              World (MapBuilder), Util (Guard)
src/client/   Main.client.luau, Controllers/* (state, UI, camera, flight, throw, training, world,
              pets, tutorial, audio), UI (Theme, Create, Components, Screens), VFX
tests/        run_tests.py + specs (flight, progression/economy, services end-to-end)
```

## Roadmap

Already in place for live operations: **Sky Festival** events (`Config/Events.luau`). They give server-wide x2 Skill and x2 Wins and make special throws x3 more likely. They run on a UTC schedule or can be started from the Admin panel.

These ideas are not implemented yet:

* More worlds. Each one only needs a definitions entry, a theme and zone names.
* A trading system for pets.
* Uploaded sounds and music in place of the built-in `rbxasset://` sounds.
