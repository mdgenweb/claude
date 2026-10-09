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
* An economy simulation of a first session reaches the first rebirth in a sane time window.

### `services.spec.luau`

Drives the **real** server services with stubbed Roblox APIs:

* **Throw state machine:** zone check, a server-timed perfect launch, double-throw rejection, a cooldown after landing.
* **Ring payouts and gust taps:** perfect pays x2; invalid, mismatched and spammed taps are rejected.
* **Landing:** zone Wins, XP, best distance and zone discovery are recorded.
* **Auto throw:** gated by the pass.
* **Training:** off-pad reps, rebirth-locked pads and pass pads are refused.
* **Shop:** affordability, world lock, duplicates, equipping and trails.
* **Hatching:** cost, auto-equip, the pets attribute mirror, the triple-hatch pass, the Robux egg and world eggs.
* **Pet actions:** lock, delete, equip-best and bad arguments.
* **Rebirth:** what resets and what is kept, plus the multiplier.
* **Worlds:** unlock cost, ordering and travel.
* **Rewards:** daily, codes (case-insensitive, once each) and potions.
* **Monetization:** Studio test grants for passes and products, the one-time starter pack and relic.
* **Tutorial:** only server events advance it, in order.

### Static checks

```bash
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --sourcemap=sourcemap.json --definitions=@roblox=globalTypes.d.luau --platform=roblox src
rojo build default.project.json -o build/SkyGlide.rbxlx
```

## Studio acceptance checklist (manual)

Use *Test → Clients and Servers* with 2 players, and enable API access for persistence.

1. **Join.** You spawn in Sunny Isles. The HUD shows the left menu (Shop, Rebirth %, Pets, Trails, Inventory, Gifts), the bottom Skill/multiplier/level bar with three Skill packs, AUTO THROW at the top and offers on the right. The tutorial hint points at the 1x pad.
2. **Train.** Stand on the 1x SKILL pad and tap (or press TRAIN). "+N" popups appear and Skill rises. Toggle AUTO. The 4x pad shows LOCKED (2 rebirths).
3. **Throw.** Walk into the THROW ZONE and hold THROW. The meter sweeps; release in the gold band for PERFECT LAUNCH. The camera follows the glider down the channel with a distance counter.
4. **Rings.** Thermal rings approach. "TAP!" pulses and tapping on time shows PERFECT (x2). The chime rises with each ring.
5. **Landing.** The glider splashes in a zone (the banner names it). The result card shows Wins, Skill and XP. The camera returns.
6. **Shop.** Buy the Notebook Glider (2 Wins) at the pedestals. It shows OWNED/EQUIPPED, and the held glider changes.
7. **Eggs.** Hatch a Beach Egg (25 Wins). The reveal plays and the pet follows you. Check that the Pets menu equip and lock work.
8. **Gifts.** Claim the 1-minute gift and the daily reward. The badge count updates.
9. **Codes.** `LAUNCH` gives Wins and a potion once. Use the potion from Inventory and confirm the multiplier doubles.
10. **Rebirth.** Use Admin → Max Level, then Rebirth. Skill resets, the multiplier goes x1→x3 and the level cap rises to 40.
11. **Worlds.** At the portal, unlock Ember Crater (1 rebirth + 600 Wins). Lighting changes and the world 2 pads and gliders appear.
12. **Studio purchases.** The Auto Throw pass is a test grant; AUTO THROW then throws by itself in the zone. Skill packs add Skill. The relic shows its stock.
13. **Rejoin.** Everything persists (API access on).
14. **Mobile emulator.** The UI scales, THROW is easy to press, and tapping anywhere counts as a gust tap.
15. **Gamepad.** R2 throws, A taps, and menus are navigable.

## Known limits of this verification

Logic is verified headlessly (above), and the code type-checks in strict mode. It has **not** been run in a Roblox client from this environment, so these still need an in-Studio pass:

* Visual polish: map proportions, UI spacing, VFX intensity.
* Camera feel.
* Device performance.
