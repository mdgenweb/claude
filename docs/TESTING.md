# Testing

## Automated (no Studio needed)

```bash
# Luau CLI from https://github.com/luau-lang/luau/releases
python3 tests/run_tests.py --luau /path/to/luau
```

* `tests/battle.spec.luau` runs **every 1v1 orb matchup** (26 × 25 × 2 seeds) plus 150 random 2v2 battles on the real `World` and ability modules. It checks that:
  * every battle terminates;
  * no non-finite state appears;
  * orbs never escape the arena;
  * HP stays in bounds;
  * snapshots fit under 850 bytes;
  * the simulation is deterministic per seed;
  * the snapshot codec round-trips;
  * no ability hook errors.

  It also prints a win-rate / duration balance table.
* `tests/match.spec.luau` drives complete matches through the real `Match` state machine with stubbed services and a fake clock:
  * bots vs bots;
  * human vs bot, including a reroll, the free collection pick, and rejection of invalid or duplicate input and NaN aims;
  * forfeit on disconnect;
  * 2v2.

Static checks:

```bash
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --sourcemap=sourcemap.json --definitions=@roblox=globalTypes.d.luau --platform=roblox src
rojo build default.project.json -o build/OrbClash.rbxlx
```

State at commit time: all specs pass, `luau-lsp analyze` reports 0 type errors, and `rojo build` succeeds.

## Studio acceptance checklist (manual)

Use *Test → Clients and Servers* with 2 players (4 for 2v2), and enable API access for persistence.

1. Join: you spawn on the plaza and the white chevrons lead to the battle arenas.
2. Press **Play** (or **E** on a pad). The pad label changes to `1/2 PLAYERS` and the queue panel shows Invite / Practice Bot / Leave.
3. The second player joins, `STARTING IN 3..1` counts down, characters lock beside the arena, and the camera swoops to the front-on view with a "BATTLE!" banner.
4. Three orb cards appear with rarity, ability text and stats. The timer counts down. Reroll costs gems. Collection is FREE once per match, then costs gems.
5. Aim: drag to rotate the dotted trajectory, then **Lock Aim** or Space. The opponent's LOCKED tag appears.
6. 3-2-1-GO. Orbs bounce with HP numbers, damage popups, hit sparks, wall bounces and ability effects.
7. A round ends with the loser's explosion cosmetic, then the winner's orb flies at the loser (flyer cosmetic) and a heart breaks in the HUD and above the head.
8. The next round starts. At 0 hearts: VICTORY/DEFEAT banner, results (coins, XP, level bar), then **Play Again** or **Lobby**.
9. First battle only: the "You got an Orb Gacha for finishing your first battle" modal appears. **Claim** shows the reveal, then **Receive**.
10. Store: open both Orb crates and both Flyer crates (Open 1 and Open 10). Check that coins and gems decrease and the reveal plays.
11. Inventory: the new orb shows as owned, and equipping an explosion or flyer works.
12. Rejoin: coins, orbs and level persist (API access on).
13. In a later match, use the Collection pick to choose the new orb.
14. 2v2 on the plaza station (4 clients or practice bots): 4 orbs in the larger arena, shared team hearts.
15. Trade: request, accept, add items, both Ready, countdown, items swapped. Changing an offer resets Ready and shows a warning. Leaving cancels.
16. Codes: `LAUNCH` gives +150 coins once, and a second redeem is rejected.
17. Mobile emulator (iPhone landscape): UI scales up, drag-to-aim works with touch, and the safe areas are respected.

## Known limits of this verification

The game logic was verified headlessly. It has **not** yet been played in a running Roblox client, so the following still need an in-Studio pass:

* Visual tuning against the reference screenshots: framing, colours, sizes, VFX intensity.
* Sound choices.
* Device performance.
