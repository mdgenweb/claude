# Research Report: Candy Kingdom Defense and the Roblox / Mobile Tower Defense Genre

> Prepared as the foundation for **Elmore Defense** (a Gumball-themed Roblox tower defense).
> Date: 2026-10-25. Primary inputs: the five in-game screenshots supplied by the client (Shop, Battle Pass,
> Trait odds, x10 summon results, Summon banner) plus public sources listed at the end.
> **Caveat:** roblox.com, YouTube and the fan wikis could not be opened directly from the research
> environment, so everything below comes from the screenshots and from search-engine summaries of those pages.
> Numbers from fan wikis are marked *(wiki)* and should be re-checked in-game.

---

## 1. Executive summary

Candy Kingdom Defense (CKD) did not invent a genre. It took the **proven 2024–2026 "anime TD" systems stack**
(gacha summons, rerollable traits, letter-grade stats, evolutions, battle pass, rotating challenges) from games
like Anime Vanguards, Anime Last Stand and Anime Defenders. It then **re-skinned every system with Adventure Time
fiction and humour**, and shipped it with unusually clean, consistent, mobile-readable UI. Released
**29 Sep 2026** by **Monero Studios** *(wiki)*, it reached roughly **2M visits, ~17k favourites, 3–10k CCU, a
~95% rating and a top-300 rank within about 4 weeks** *(trackers, figures disagree)*.

The five things worth copying (not the assets, the *ideas*):

1. **Familiar systems, new fiction.** Players coming from other anime TDs already know the vocabulary, so the
   learning cost is near zero. The IP supplies the novelty.
2. **Diegetic naming.** Traits are called *Oh My Glob*, *Hero of Ooo*, *Algebraic* and *Mathematical*. The trait shop
   is *Castle Lemongrab*, and the evolution currency is *Enchiridion Pages*. Even promo codes reuse trait names
   (`ALGEBRAIC`, `MATHEMATICAL`), so every system doubles as a joke for fans.
3. **Hourly FOMO with forward visibility.** The featured Mythic rotates every hour, the UI shows a live countdown
   and **"Next up: Princess Bubblegum"**, and the copy says "75% of Mythic summons are Lemongrab". That gives players
   a reason to come back at a specific time.
4. **Visible safety nets.** The UI says "Legendary or better guaranteed in 49 summons" and "the first of every hero
   is always kept". Auto-delete toggles per rarity remove inventory chores.
5. **Generous, legible economy.** You start with 1,000 gems (2 × x10), and a x10 costs 450 because 1 pull is
   free. Odds are listed to two decimals, and Robux prices are low (a 64 R$ starter pack, an 80 R$ backpack).

---

## 2. Candy Kingdom Defense teardown

### 2.1 Core loop

```
Lobby (Tree Fort hub)                Match (story act / infinite / challenge)
 ├─ Summon (Treasure Hoard) ─┐        ├─ place up to 6 equipped heroes
 ├─ Traits (Castle Lemongrab)│        ├─ spend match cash on 4-stage upgrades
 ├─ Stat grades (Recon. Ch.) ├──────► ├─ survive waves → boss
 ├─ Evolve (needs drops)     │        └─ rewards: gems, BP XP, crystals, juice, evolution items
 └─ Battle pass / Shop ──────┘ ◄──────────┘
```

Every reward from a match feeds a lobby system, and every lobby system makes the next match easier or faster.
That is the whole retention engine.

### 2.2 Summoning (screenshot 5)

| Rarity | Pool at launch | Rate |
|---|---|---|
| Secret | ??? (The Lich) | **0.05%** |
| Mythic | Lemongrab, Princess Bubblegum, Billy | **0.5%** (featured = 0.38%, others 0.06%) |
| Legendary | Marceline | **4.5%** |
| Epic | Lady Rainicorn, Flame Princess, BMO | **24.99%** |
| Rare | Jake, Finn | **69.96%** |

* x1 = 50 gems, **x10 = 450 gems ("1 FREE")**. Gem packs: 450/20 R$ up to 21,000/600 R$ ("BEST VALUE", "POPULAR" tags).
* **Pity:** "Legendary or better guaranteed in 49 summons" (a 50-pull pity with a progress bar).
* **Hourly banner:** "NEW BANNER IN 45:38", "Next up: Princess Bubblegum", "This hour 75% of Mythic summons are Lemongrab!"
* **Auto-delete** hearts for Rare / Epic / Legendary: "Red rarities are deleted right away… the first of every hero is always kept, and Mythics and the SECRET never go."
* **Inventory cap** "HEROES 2/150" drives the *Big Backpack* pass.
* Results screen (screenshot 4): 2 × 5 card grid, duplicates shown as **x2…x7**, a **NEW!** tag, and **three letter grades
  per card** (e.g. `A- B C-`). The title is a random catch-phrase ("ALGEBRAIC!"), so even a bad pull reads like a celebration.

### 2.3 Traits (screenshot 3)

Rerolled one Trait Crystal at a time at Castle Lemongrab. There is **no pity** *(wiki)*. The copy says "The same trait can come again!"

| Trait | Effect | Odds | Tier colour |
|---|---|---|---|
| (hidden top rows) | +8% range… | ~18% | grey |
| Quick | +8% attack speed | 18% | grey |
| Thrifty | costs 12% less | 12% | blue |
| Sugar Rush | +14% attack speed | 12% | blue |
| Brawny | +15% damage | 10% | blue |
| Radical | +10% dmg, +15% range | 5% | purple |
| Mathematical | +25% damage | 4% | purple |
| Algebraic | +8% dmg, +22% atk spd | 2% | purple |
| Hero of Ooo | +30% dmg, +15% rng, +10% spd | **0.8%** | gold |
| Oh My Glob | **+200% dmg**, +20% rng, +20% spd | **0.2%** | rainbow |

Design read: the top trait is **an order of magnitude stronger** than everything else. At 0.2% you need roughly 347
crystals for a 50% chance *(wiki)*. That makes it a status symbol and a long-term sink, and it is the main
reason to buy crystals. A **colour bar per tier** lets players read the whole table at a glance.

### 2.4 Stat grades, evolutions, levels

* **Grades:** each hero rolls a letter grade for Damage / Range / SPA. You reroll them in the *Reconditioning
  Chamber* with *Units of Juice*: all three for 1 Juice, or lock one stat and reroll the rest for 2 *(wiki)*.
  This is a second, independent reroll sink, so one unit can absorb two currencies.
* **Evolutions:** for example Jake → *Alien Jake* (becomes Mythic) using Sandwiches from challenges plus gems. **The unit keeps
  its level and trait** *(wiki)*. Keeping the unit protects the player's earlier investment and makes evolving feel safe.
* **6★ evolutions** such as Marceline Beast cost 10 Hunson's Amulets + 5 Enchiridion Pages + 1,000 gems *(wiki)*.

### 2.5 In-match upgrades

Every hero follows the same **four-stage ladder** *(wiki)*: base attack → first ability → upgraded ability →
**ultimate**. For Jake that is Stretch Punch → Hammer Slam → Hammer Slam+ → *Stretchy Tornado*, going from single target
to a full-area spin. Upgrades are bought from the hero card or with the **Z** hotkey. Because each tier changes
**what the attack looks like**, not only its numbers, every purchase pays off visibly.

### 2.6 Content and modes

* **Story:** 5 worlds × 5 acts at launch, later 7 × 5 = 35 stages *(wiki)*.
* **Infinite Mode:** endless scaling waves that pay gems per wave.
* **Dungeon Train:** 3 challenge "cars" that **rotate every 30 minutes**. Each win pays gems plus an Enchiridion Page
  *(wiki)*. This is the evolution-material faucet and a second timed reason to return.
* **Co-op:** up to 4 players, 24-player public lobbies.
* **Codes:** tied to community milestones (`THANKSFOR200LIKES`, `THANKSFOR100CCU`, `SORRYFORBUGS`) and redeemed
  by talking to an NPC (Jake). Players get rewarded for liking the game, which in turn helps discovery.

### 2.7 Monetisation (screenshots 1 and 2)

| Product | Price | Effect |
|---|---|---|
| Starter Pack (one time) | 64 R$ | 3,000 gems, 20 Trait Crystals, 10 Juice, 3 Pages |
| VIP | 280 R$ | 20% off summons, 2× Legendary traits, 2× Mythic traits, 1.5× Epic traits, VIP tag |
| 2× Gems | 480 R$ | 2× gems from wins, challenges, infinite |
| Lucky Summons | 320 R$ | 2× Mythic odds, 1.5× Legendary odds |
| 2× Drops | 480 R$ | 2× items, evolution items, portal drops |
| Big Backpack | 80 R$ | 300 hero slots |
| Battle Pass Premium | 799 R$ | Premium track plus a shiny Limited unit at level 50 |
| +1 Tier | 29 R$ | Skip a pass level |

Two patterns stand out:

* **Value stacking:** each pass is a *multiplier on a loop the player already does*, not a power spike.
* **Price anchoring:** a 64 R$ starter pack converts first-time payers, and once someone has paid
  they are much more likely to pay again.

The Battle Pass UI (screenshot 2) shows the **free and premium tracks side by side**, with the premium rewards
locked but visible (5,000 gems at level 1). The **level 50 prize panel** contrasts a free *Ice King* with a premium
**SHINY** *Fire King*, both tagged LIMITED.

### 2.8 Art and UI language (what makes it look "professional")

* **One consistent visual grammar:** chunky rounded display font with a dark outline, candy-stripe diagonal panel
  fills, a pastel colour per feature (pink starter, gold VIP, blue gems, green luck, purple drops, red backpack),
  green pill CTAs with a dark stroke, and a red X close button in the corner.
* **Rarity colour language** on every surface: blue Rare, purple Epic, gold Legendary, rainbow Mythic, black
  Secret, plus star counts (3★–7★).
* **Information density with hierarchy:** cards always read name → rarity → grades → count, in the same place.
* **Tags as micro-copy:** NEW!, POPULAR, BEST VALUE, 1 FREE, ONE TIME ONLY, LIMITED and SHINY drive attention at no cost.
* **Characters** are stylised, low-poly, flat-shaded models that read well at TD camera distance. Low triangle count
  and bold silhouettes matter more than detail.

### 2.9 Was it "made by Claude"? What tools were used?

* **Unverified.** Every listing found credits **Monero Studios** (one credits HaruWorld Studio). No source links CKD
  to Claude or Anthropic. A YouTube video, *"Can AI Make an Entire Roblox Tower Defense Game? (3D Models, VFX, Code)"*,
  shows Claude Code driving a full Roblox pipeline, but the search summary did not name CKD.
* **What a Claude-driven Roblox pipeline looks like in 2026** (documented publicly):
  * Roblox Studio's **built-in MCP server**. In Studio: Assistant → *Manage MCP Servers* → *Enable Studio as MCP
    server* → Quick-connect *Claude Code*. Also available as Roblox's official `roblox-studio-agent-plugin`.
  * **Rojo** for syncing files on disk into Studio (what this project uses).
  * **Mesh generation:** Roblox Cube 3D / `GenerationService:GenerateModelAsync` (textured meshes from text, with a
    triangle cap, exposed as an MCP `generate_mesh` tool), or external generators like Meshy, cleaned up in Blender.
  * Community MCP servers (WEPPY, robloxstudio-mcp, BloxForge) and skills (`roblox-game-skill`).
* **Known weak spot:** AI agents have little visual feedback. Practitioners report that placement and decoration
  still need a human pass in Studio. Plan for one art-direction pass even with an AI pipeline.

---

## 3. The Roblox TD landscape: what each leader teaches

| Game | What it does best | Lesson for us |
|---|---|---|
| **Tower Defense Simulator** (Paradoxum) | Skill-based, no gacha. Towers bought with coins, cosmetic skins, event cadence every few weeks, hardcore modes. | Content cadence and polish keep players for years. Cosmetics can monetise without pay-to-win. |
| **Anime Vanguards** | Units are *mechanically* unique, not just numerically. Strong VFX on abilities, boss mechanics, per-unit passives, evolutions. | Each unit needs a signature move, and bosses need mechanics, not just HP. |
| **Anime Last Stand** | Two banners: an hourly rotation at XX:00 and a **progression-gated Banner 2**. Pity at 60 (Legendary) / 250 (Mythic), plus ultra-rare traits (0.03%). | Gate a second banner behind progress. Show two pity bars. |
| **Anime Defenders** | Trait Crystals mostly from challenges, a separate *Rank Reroll* machine, an **AFK area** that farms gems, and hourly challenges. | An AFK zone raises session time and counts toward CCU, which feeds discovery. |
| **Toilet Tower Defense** | A player-driven **trading economy** with crates and value lists. | Trading builds community but invites scams and dupes. Ship it later, carefully. |
| **SpongeBob Tower Defense** | Highest-earning *IP-based* Roblox game, later **officially licensed by Paramount**: 633M visits, ~98% rating, 113k CCU peak after a big update. | IP + TD works. The route to safety is a licence or original characters. |
| **Five Nights TD** | Seasonal events with a Halloween pass, event banner, event endless mode and modifiers. | Seasonal events give the strongest re-engagement spike. Today is Oct 25, so ship a Halloween banner. |

**Shared genre conventions players expect (table stakes):** a 6-slot hotbar; placement ghost with a range circle;
click a unit to open a panel with upgrade / sell / targeting (First, Last, Strongest, Weakest, Closest); Z / X
hotkeys; vote-skip waves; 1× / 2× / 3× speed; boss HP bar; per-unit placement limits; a money/farm unit;
hidden enemies that need detection; a victory screen with a sequential reward reveal; codes; daily rewards; quests;
an index/collection; a battle pass; and odds shown in-game.

---

## 4. Mobile TD lessons (Bloons TD 6, Kingdom Rush, PvZ, Arknights, Rush Royale)

* **BTD6: choice inside upgrades.** Three paths, of which only two can be selected, cap the build space and create real
  trade-offs. *Paragons* are a spectacular capstone. Some tiers are "stepping stones" that are weak alone but unlock
  power, which teaches delayed gratification. **Our version:** keep the CKD four-stage ladder for readability, and add
  a *Specialisation* choice at the last tier on Legendary+ units (two ultimates, pick one).
* **Kingdom Rush: humour, heroes, stars.** Cute fantasy visuals over a hard strategy core. Barracks block enemies.
  Heroes are a controllable centrepiece. **3-star ratings per level** drive replay, and the enemy encyclopedia rewards
  curiosity. **Our version:** 3-star grades per act from base HP left, plus a "Yearbook" index of units and enemies.
* **Plants vs Zombies: one new toy per level.** Every level introduces exactly one new mechanic or enemy, and the almanac
  explains it. **Our version:** each act's preview lists the "new enemy" before you start.
* **Arknights: deployment cost and roles.** Clear roles (DPS, support, control, farm) make team building
  interesting. **Our version:** role tags on every unit, and supports and farms are first-class.
* **Rush Royale: merge and the dopamine of upgrades.** Constant small upgrades with loud feedback. **Our version:** every
  upgrade fires a level-up burst, a sound and a stat diff popup.

---

## 5. Why players stay: the psychology, applied

| Driver | Mechanism | Where it lives in Elmore Defense |
|---|---|---|
| **Competence / flow** | Difficulty ramps across acts, boss as an exam | 5 acts per world, boss on the last wave, star grades |
| **Variable reward** | Uncertain high-value outcomes | Summons, trait rolls, grade rolls, shiny chance, drop tables |
| **Goal gradient** | Motivation rises as a goal gets close | Pity bars, BP XP bar, index completion %, quest bars |
| **Endowment / sunk cost** | Investment you don't want to lose | Traits and grades persist through evolution, and each unit is its own instance |
| **Collection** | Completing sets | Yearbook index with rewards per discovery, plus shiny variants |
| **Status / display** | Showing off rare things | Rainbow trait auras visible to everyone in co-op, VIP tag, shiny sparkles |
| **Appointment mechanics** | Return at a known time | Hourly banner + "next up", 30-min challenge rotation, daily login streak |
| **Social** | Players with friends retain better | 4-player co-op, shared wins, invite button |
| **Loss aversion** | Don't break the streak | 7-day login calendar with an escalating day-7 reward |

### "Beating something" must *feel* good: our feedback checklist

* **Every hit:** a damage number pops (bigger and yellow on crits), the enemy flashes white, and the enemy squashes.
* **Every kill:** a scale-pop then a poof of confetti in the enemy colour, a "+$" cash popup and a soft coin sound.
* **Every upgrade:** a level-up burst ring, a hop and spin on the unit, a stat-diff toast, and the attack visibly changes at ability tiers.
* **Boss:** a banner slides in ("BOSS INCOMING"), a short camera shake, a big top-centre HP bar with the boss name,
  boss abilities (stun pulse, minion spawns) that force reaction, and on the kill a big burst, a slow-mo flash and confetti.
* **Victory:** a stamp animation, then rewards revealed one at a time (each with a pop), star rating and BP XP bar fill.
* **Restraint:** no screen shake on ordinary hits. TD towers fire many times per second, so shake is reserved for
  bosses, ultimates and wins. Hit-stop is never used on regular hits.

---

## 6. Compliance, risk and ethics (non-negotiable for a professional release)

1. **Paid random items:** Roblox requires **every outcome and its exact odds** shown before purchase, summing to 100%.
   This also applies when Robux buys the currency spent on the random item (gems → summons, crystals → trait
   rolls). Users that `PolicyService:GetPolicyInfoForPlayerAsync(...).ArePaidRandomItemsRestricted` flags must not
   be able to spend *Robux-purchased* currency on random outcomes. **Implemented** (see `PolicyServer`).
2. **IP:** *The Amazing World of Gumball* belongs to Cartoon Network / Warner Bros. Discovery. CKD (Adventure Time)
   is in the same unlicensed position. Monetising an unlicensed IP game can lead to **DMCA takedowns and loss of
   revenue**. SpongeBob TD is the success story *because* it later secured an official licence. **Mitigation built in:** all
   character names, colours and models are **data in one config file** (`UnitsConfig`) and can be re-themed to
   original characters without code changes.
3. **Assets:** do **not** rip models or animations from other games. That is copyright infringement, gets games taken
   down, and Roblox treats it as a ToS violation. Free Creator Store models are allowed but are a known backdoor
   vector, so use the `Sandboxed` property and capability restrictions and read every script. This project therefore builds
   **all characters, enemies, maps and VFX procedurally in code** and provides an **asset-override folder** for
   swapping in properly licensed meshes later (see the GDD, §12).

---

## 7. Sources

* Candy Kingdom Defense: [Roblox page](https://www.roblox.com/games/111053011787075/Candy-Kingdom-Defense) ·
  [PCGamesN codes](https://www.pcgamesn.com/roblox/candy-kingdom-defense-codes) ·
  [Dexerto codes](https://www.dexerto.com/roblox/candy-kingdom-defense-codes-3421371/) ·
  [Sportskeeda traits](https://www.sportskeeda.com/roblox-news/candy-kingdom-defense-traits-guide) ·
  [Robolibrary units](https://robolibrary.org/wikis/candy-kingdom-defense/units) ·
  [Beginner guide](https://candykingdomdefense.wiki/guide/candy-kingdom-defense-beginner-guide) ·
  [Strategy/evolution guide](https://candykingdomdefense.wiki/guide/candy-kingdom-defense-strategy) ·
  [Jake guide](https://candykingdomdefense.wiki/units/candy-kingdom-defense-jake) ·
  [Worlds](https://candykingdomdefense.wiki/modes/candy-kingdom-defense-worlds) ·
  [Tier list (Phrasemaker)](https://thephrasemaker.com/2026/10/21/candy-kingdom-defense-tier-list-best-heroes/) ·
  [Tier list (Ofzen)](https://www.ofzenandcomputing.com/candy-kingdom-defense-tier-list/) ·
  [Creator Exchange release listing](https://creatorexchange.io/roblox-game/10768556372/candy-kingdom-defense) ·
  [Robipedia stats](https://robipedia.com/game/candy-kingdom-defense-10506381811)
* AI pipeline: [YouTube: Can AI make an entire Roblox TD?](https://www.youtube.com/watch?v=WIYBh_kkKN8) ·
  [Roblox official agent plugin](https://github.com/Roblox/roblox-studio-agent-plugin) ·
  [Roblox studio-rust-mcp-server](https://github.com/Roblox/studio-rust-mcp-server) ·
  [DevForum: Studio MCP + external LLMs](https://devforum.roblox.com/t/studio-mcp-server-updates-and-external-llm-support-for-assistant/4415631) ·
  [DevForum: Assistant mesh generation + MCP tools](https://devforum.roblox.com/t/assistant-updates-mesh-generation-new-mcp-server-tools-screenshot-tool-and-more/4527258) ·
  [GenerationService docs](https://create.roblox.com/docs/reference/engine/classes/GenerationService#GenerateModelAsync) ·
  [Roblox Cube announcement](https://about.roblox.com/newsroom/2025/03/introducing-roblox-cube) ·
  [sozai.app tutorial summary](https://sozai.app/transcript/make-roblox-game-ai-tutorial/) ·
  [Medium: Roblox game with only AI agents](https://medium.com/@andy.a.g/i-built-a-roblox-game-using-only-ai-agents-heres-what-happened-ed57b553facc) ·
  [Thrixel AI 3D assets](https://thrixel.com/learn/roblox-game-ai)
* Genre: [Anime Last Stand pity](https://www.ginx.tv/en/anime-last-stand-summon-chances-pity-system) ·
  [ALS banners wiki](https://alsroblox.fandom.com/wiki/Summoning_Banners) ·
  [Anime Vanguards traits](https://deltiasgaming.com/roblox-anime-vanguards-traits-guide/) ·
  [Anime Vanguards overview](https://www.exitlag.com/blog/anime-vanguard-roblox/) ·
  [Anime Defenders beginner guide](https://itemlevel.net/anime-defenders-complete-beginners-guide/) ·
  [TTD value list](https://mobilematters.gg/guides/roblox/toilet-tower-defense-units-value-list) ·
  [SpongeBob TD 113k CCU](https://games.gg/news/spongebob-tower-defense-on-roblox-hits-113k-ccu/) ·
  [SpongeBob TD 2.0 / Paramount](https://www.theatdb.com/news/spongebob-tower-defense-highest-earning-ip-based-game-on-roblox-launches-20-version-in-partnership-with-paramount-exclusive) ·
  [Five Nights TD Halloween update](https://destructoid.com/?p=617238) ·
  [RoWatcher top earners 2026](https://rowatcher.com/news/the-10-highest-earning-roblox-games-in-2026-and-what-they-mean-for-the-platform)
* Design: [BTD6 crosspathing](https://www.bloonswiki.com/Upgrade) ·
  [BTD6 paragons](https://www.bloonswiki.com/Paragon) ·
  [Kingdom Rush level design](https://gamedeveloper.com/design/kingdom-rush---the-wonderful-campaign-level-design) ·
  [TouchArcade Kingdom Rush](https://toucharcade.com/2013/03/21/ta-plays-rewind-kingdom-rush-an-awesome-tower-defense-game) ·
  [Game feel: flash, shake, floating text](https://eastondev.com/blog/en/posts/dev/20260521-game-feedback-feel/) ·
  [Roblox retention docs](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/analytics/retention.md) ·
  [DevForum D1 retention](https://devforum.roblox.com/t/suggestions-on-how-to-improve-d1-retention/4369566) ·
  [Korean mobile monetisation/retention study](https://arxiv.org/pdf/2504.10714)
* Policy and safety: [Roblox paid random items policy](https://create.roblox.com/docs/production/monetization/paid-random-items) ·
  [Third-party asset vulnerabilities](https://create.roblox.com/docs/scripting/security/third-party-vulnerabilities) ·
  [Gumball on Roblox (License Global)](https://www.licenseglobal.com/video-games/-the-amazing-world-of-gumball-comes-to-roblox)
