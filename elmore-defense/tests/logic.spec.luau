local GameConfig = require(Shared.Config.GameConfig)
local Banners = require(Shared.Config.Banners)
local Units = require(Shared.Config.Units)
local Traits = require(Shared.Config.Traits)
local Worlds = require(Shared.Config.Worlds)
local SummonLogic = require(Shared.Logic.SummonLogic)
local RerollLogic = require(Shared.Logic.RerollLogic)
local UnitStats = require(Shared.Logic.UnitStats)
local WaveGen = require(Shared.Logic.WaveGen)
local Rotation = require(Shared.Logic.Rotation)
local Levels = require(Shared.Logic.Levels)
local WeightedRandom = require(Shared.Util.WeightedRandom)

local NOW = 1793000000

describe("SummonLogic", function()
	local banner = Banners.byId.Standard

	it("display odds sum to 100 (normal and lucky)", function()
		for _, lucky in { false, true } do
			local total = 0
			for _, row in SummonLogic.displayOdds(banner, { lucky = lucky, now = NOW }) do
				local unitTotal = 0
				for _, unitRow in row.units do
					unitTotal += unitRow.percent
				end
				expect(unitTotal).toBeNear(row.percent, 1e-6)
				total += row.percent
			end
			expect(total).toBeNear(100, 1e-6)
		end
	end)

	it("lucky pass doubles Mythic and takes from Rare", function()
		local normal = WeightedRandom.toPercentages(SummonLogic.rarityEntries(banner, {}))
		local lucky = WeightedRandom.toPercentages(SummonLogic.rarityEntries(banner, { lucky = true }))
		expect(lucky.Mythic).toBeNear(normal.Mythic * 2, 1e-6)
		expect(lucky.Legendary).toBeNear(normal.Legendary * 1.5, 1e-6)
		expect(lucky.Rare < normal.Rare).toBeTruthy()
		expect(lucky.Epic).toBeNear(normal.Epic, 1e-6)
	end)

	it("featured Mythic rotates hourly and gets 75% of Mythic odds", function()
		local first, nextUp, left = SummonLogic.featured(banner, NOW)
		local later = SummonLogic.featured(banner, NOW + GameConfig.Summon.BannerRotationSeconds)
		expect(first ~= nil).toBeTruthy()
		expect(later).toBe(nextUp)
		expect(left > 0 and left <= 3600).toBeTruthy()
		local odds = SummonLogic.displayOdds(banner, { now = NOW })
		for _, row in odds do
			if row.rarity == "Mythic" then
				expect(row.units[1].id).toBe(first)
				expect(row.units[1].percent).toBeNear(row.percent * 0.75, 1e-6)
			end
		end
	end)

	it("pity guarantees Legendary+ within 50 and Mythic+ within 400", function()
		local rng = Random.new(42)
		local pity = { legendary = 0, mythic = 0 }
		local sinceLegendary, sinceMythic = 0, 0
		local worstLegendary, worstMythic = 0, 0
		local counts = { Rare = 0, Epic = 0, Legendary = 0, Mythic = 0, Secret = 0 }
		local N = 60000
		for _ = 1, N do
			local result
			result, pity = SummonLogic.roll(banner, pity, rng, { now = NOW })
			counts[result.rarity] += 1
			local rank = SummonLogic.RARITY_RANK[result.rarity]
			sinceLegendary += 1
			sinceMythic += 1
			if rank >= 3 then
				worstLegendary = math.max(worstLegendary, sinceLegendary)
				sinceLegendary = 0
			end
			if rank >= 4 then
				worstMythic = math.max(worstMythic, sinceMythic)
				sinceMythic = 0
			end
			expect(Units.get(result.unitId).rarity).toBe(result.rarity)
		end
		expect(worstLegendary).toBeAtMost(GameConfig.Summon.LegendaryPity)
		expect(worstMythic).toBeAtMost(GameConfig.Summon.MythicPity)
		-- With pity, effective Legendary+ rate must be at least the base rate.
		local legendaryPlus = (counts.Legendary + counts.Mythic + counts.Secret) / N * 100
		expect(legendaryPlus).toBeAtLeast(4.5 + 0.6 + 0.05 - 0.3)
		expect(counts.Rare / N * 100).toBeNear(69.85, 2.5)
	end)

	it("x10 costs 450, VIP gets 20% off", function()
		expect(SummonLogic.cost(10, false)).toBe(450)
		expect(SummonLogic.cost(1, false)).toBe(50)
		expect(SummonLogic.cost(10, true)).toBe(360)
	end)

	it("event banner is only active inside its window", function()
		local spooky = Banners.byId.Spooky
		expect(SummonLogic.isActive(spooky, spooky.startsAt + 10)).toBe(true)
		expect(SummonLogic.isActive(spooky, spooky.endsAt + 10)).toBe(false)
		expect(SummonLogic.isActive(banner, 0)).toBe(true)
	end)
end)

describe("RerollLogic", function()
	it("VIP odds still sum to 100 and boost top traits", function()
		local normal = RerollLogic.traitOdds(false)
		local vip = RerollLogic.traitOdds(true)
		local total = 0
		for _, pct in vip do
			total += pct
		end
		expect(total).toBeNear(100, 1e-6)
		expect(vip.Amazing).toBeNear(normal.Amazing * 2, 1e-6)
		expect(vip.ElmoreLegend).toBeNear(normal.ElmoreLegend * 2, 1e-6)
		expect(vip.Snappy < normal.Snappy).toBeTruthy()
	end)
	it("empirical trait odds match the table", function()
		local rng = Random.new(7)
		local counts = {}
		local N = 50000
		for _ = 1, N do
			local id = RerollLogic.rollTrait(rng, false)
			counts[id] = (counts[id] or 0) + 1
		end
		for _, trait in Traits.list do
			local pct = (counts[trait.id] or 0) / N * 100
			expect(pct).toBeNear(trait.weight, math.max(0.6, trait.weight * 0.2))
		end
	end)
	it("locked grade is preserved", function()
		local rng = Random.new(3)
		local current = { Damage = "S", Range = "D", SPA = "C" }
		for _ = 1, 50 do
			local rolled = RerollLogic.rollGrades(rng, current, "Damage")
			expect(rolled.Damage).toBe("S")
		end
	end)
end)

describe("UnitStats", function()
	it("grades, traits and level all increase damage", function()
		local base = { id = "Gumball", level = 1, grades = { Damage = "C", Range = "C", SPA = "C" } }
		local better = { id = "Gumball", level = 10, trait = "Amazing", grades = { Damage = "S", Range = "S", SPA = "S" } }
		local a = UnitStats.compute(base, 0)
		local b = UnitStats.compute(better, 0)
		expect(b.damage > a.damage * 3).toBeTruthy()
		expect(b.range > a.range).toBeTruthy()
		expect(b.cooldown < a.cooldown).toBeTruthy()
	end)
	it("Penny Pincher discounts costs and invested total adds up", function()
		local plain = { id = "Nicole", level = 1 }
		local cheap = { id = "Nicole", level = 1, trait = "PennyPincher" }
		expect(UnitStats.placementCost(cheap) < UnitStats.placementCost(plain)).toBeTruthy()
		local total = 0
		for level = 0, Units.maxLevel("Nicole") do
			total += UnitStats.tierCost(plain, level)
		end
		expect(UnitStats.totalInvested(plain, Units.maxLevel("Nicole"))).toBe(total)
	end)
	it("detection comes from unit or trait", function()
		expect(UnitStats.compute({ id = "Bobert", level = 1 }, 0).detect).toBe(true)
		expect(UnitStats.compute({ id = "Gumball", level = 1 }, 0).detect).toBe(false)
		expect(UnitStats.compute({ id = "Gumball", level = 1, trait = "HallMonitor" }, 0).detect).toBe(true)
	end)
	it("moves switch on ability tiers", function()
		local stats0 = UnitStats.compute({ id = "Gumball", level = 1 }, 0)
		local stats4 = UnitStats.compute({ id = "Gumball", level = 1 }, 4)
		expect(stats0.moveKey).toBe("punch")
		expect(stats4.moveKey).toBe("wtw")
		expect(stats4.move.ultimate).toBe(true)
	end)
end)

describe("WaveGen", function()
	it("every story act ends with its world boss and scales up", function()
		for _, world in Worlds.ordered do
			for act = 1, Worlds.ACTS do
				local total = Worlds.wavesForAct(act)
				local previousScale = 0
				for wave = 1, total do
					local entries = WaveGen.storyWave(world.id, act, wave)
					expect(#entries > 0).toBeTruthy()
					local scale = WaveGen.hpScale(world, act, wave)
					expect(scale > previousScale).toBeTruthy()
					previousScale = scale
					local last = entries[#entries]
					if wave == total then
						expect(last.boss).toBe(true)
						expect(last.enemy).toBe(world.boss)
					end
					for index = 2, #entries do
						expect(entries[index].delay >= entries[index - 1].delay).toBeTruthy()
					end
				end
			end
		end
	end)
	it("is deterministic", function()
		local a = WaveGen.storyWave("ElmoreMall", 3, 5)
		local b = WaveGen.storyWave("ElmoreMall", 3, 5)
		expect(#a).toBe(#b)
		for index = 1, #a do
			expect(a[index].enemy).toBe(b[index].enemy)
		end
	end)
	it("infinite spawns a boss every 10 waves", function()
		local wave10 = WaveGen.infiniteWave("ElmoreJuniorHigh", 10)
		expect(wave10[#wave10].boss).toBe(true)
		local wave9 = WaveGen.infiniteWave("ElmoreJuniorHigh", 9)
		expect(wave9[#wave9].boss).toBe(false)
	end)
end)

describe("Rotation", function()
	it("challenges are deterministic with distinct modifiers", function()
		local a = Rotation.challenges(NOW)
		local b = Rotation.challenges(NOW + 5)
		expect(#a).toBe(3)
		local seen = {}
		for index, slot in a do
			expect(slot.id).toBe(b[index].id)
			expect(seen[slot.modifier]).toBe(nil)
			seen[slot.modifier] = true
			expect(Worlds.get(slot.worldId) ~= nil).toBeTruthy()
			expect(slot.act >= 1 and slot.act <= 5).toBeTruthy()
		end
	end)
	it("daily and weekly quests pick distinct entries", function()
		local daily = Rotation.dailyQuests(Rotation.dayIndex(NOW))
		expect(#daily).toBe(3)
		expect(daily[1].id ~= daily[2].id and daily[2].id ~= daily[3].id and daily[1].id ~= daily[3].id).toBeTruthy()
		local weekly = Rotation.weeklyQuests(Rotation.weekIndex(NOW))
		expect(#weekly).toBe(3)
	end)
	it("week index rolls over on Monday", function()
		-- 2026-10-26 is a Monday (UTC)
		local monday = 1792972800
		expect(Rotation.weekIndex(monday) - Rotation.weekIndex(monday - 1)).toBe(1)
	end)
end)

describe("Levels", function()
	it("applies xp with carry-over and caps", function()
		local level, xp, gained = Levels.applyUnitXp(1, 0, 1000)
		expect(level > 1).toBeTruthy()
		expect(gained).toBe(level - 1)
		local capped = Levels.applyUnitXp(GameConfig.Units.MaxLevel, 0, 999999)
		expect(capped).toBe(GameConfig.Units.MaxLevel)
		expect(xp >= 0).toBeTruthy()
	end)
end)
