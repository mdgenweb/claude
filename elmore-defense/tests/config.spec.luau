local Units = require(Shared.Config.Units)
local Rarities = require(Shared.Config.Rarities)
local Traits = require(Shared.Config.Traits)
local Grades = require(Shared.Config.Grades)
local Banners = require(Shared.Config.Banners)
local Enemies = require(Shared.Config.Enemies)
local Worlds = require(Shared.Config.Worlds)
local Items = require(Shared.Config.Items)
local BattlePass = require(Shared.Config.BattlePass)
local Evolutions = require(Shared.Config.Evolutions)
local Shop = require(Shared.Config.Shop)
local Quests = require(Shared.Config.Quests)
local Challenges = require(Shared.Config.Challenges)

local VALID_KINDS = { single = true, splash = true, circle = true, cone = true, line = true, chain = true, multi = true }
local VALID_VFX = {
	punch = true,
	projectile = true,
	lob = true,
	beam = true,
	chain = true,
	shockwave = true,
	slash = true,
	glare = true,
	bubble = true,
	rift = true,
	cloud = true,
	stomp = true,
}

describe("Units", function()
	for id, unit in Units.byId do
		it(id .. " has valid identity", function()
			expect(unit.id).toBe(id)
			expect(Rarities.byId[unit.rarity] ~= nil).toBeTruthy()
			expect(type(unit.name) == "string" and #unit.name > 0).toBeTruthy()
			expect(unit.look and unit.look.archetype ~= nil).toBeTruthy()
		end)
		it(id .. " has a valid upgrade ladder", function()
			expect(#unit.tiers >= 2).toBeTruthy()
			expect(unit.tiers[1].move ~= nil).toBeTruthy()
			for index, tier in unit.tiers do
				expect(tier.cost > 0).toBeTruthy()
				expect(tier.damage > 0).toBeTruthy()
				expect(tier.range > 0).toBeTruthy()
				expect(tier.cooldown > 0).toBeTruthy()
				if tier.move then
					expect(unit.moves[tier.move] ~= nil).toBeTruthy()
				end
				if index > 1 then
					expect(tier.damage).toBeAtLeast(unit.tiers[index - 1].damage)
				end
			end
		end)
		it(id .. " moves are well formed", function()
			for key, move in unit.moves do
				expect(VALID_KINDS[move.kind] == true).toBeTruthy()
				expect(VALID_VFX[move.vfx] == true).toBeTruthy()
				expect(type(move.name) == "string").toBeTruthy()
				if move.kind == "splash" then
					expect((move.radius or 0) > 0).toBeTruthy()
				elseif move.kind == "chain" then
					expect((move.chains or 0) > 0 and (move.chainRange or 0) > 0).toBeTruthy()
				elseif move.kind == "multi" then
					expect((move.targets or 0) > 1).toBeTruthy()
				elseif move.kind == "cone" then
					expect((move.angle or 0) > 0).toBeTruthy()
				elseif move.kind == "line" then
					expect((move.width or 0) > 0).toBeTruthy()
				end
				local used = false
				for _, tier in unit.tiers do
					if tier.move == key then
						used = true
					end
				end
				expect(used).toBeTruthy()
			end
		end)
	end

	it("every summonable rarity has at least one unit", function()
		for _, rarity in Banners.RARITY_ORDER do
			expect(#Units.listByRarity(rarity, true)).toBeGreaterThan(0)
		end
	end)

	it("evolutions point at existing, non-summonable units", function()
		for fromId, evo in Evolutions do
			expect(Units.get(fromId) ~= nil).toBeTruthy()
			local target = Units.get(evo.to)
			expect(target ~= nil).toBeTruthy()
			expect(target.summonable).toBe(false)
			expect(target.evolvedFrom).toBe(fromId)
			for itemId in evo.items do
				expect(Items.get(itemId) ~= nil).toBeTruthy()
			end
		end
	end)
end)

describe("Odds tables", function()
	it("trait weights sum to 100", function()
		local sum = 0
		for _, trait in Traits.list do
			sum += trait.weight
			expect(Traits.Tiers[trait.tier] ~= nil).toBeTruthy()
		end
		expect(sum).toBeNear(100, 1e-9)
	end)
	it("grade weights sum to 100", function()
		local sum = 0
		for _, grade in Grades.list do
			sum += grade.weight
		end
		expect(sum).toBeNear(100, 1e-9)
	end)
	it("banner rarity rates sum to 100", function()
		for id, banner in Banners.byId do
			local sum = 0
			for _, rate in banner.rates do
				sum += rate
			end
			expect(sum).toBeNear(100, 1e-9)
			if banner.featuredRotation then
				for _, unitId in banner.featuredRotation do
					expect(Units.get(unitId).rarity).toBe("Mythic")
				end
			end
			if banner.rateUp then
				for rarity, rateUp in banner.rateUp do
					expect(Units.get(rateUp.unit).rarity).toBe(rarity)
				end
			end
			expect(id).toBe(banner.id)
		end
	end)
end)

describe("Enemies & worlds", function()
	it("every world references valid enemies and a boss", function()
		for _, world in Worlds.ordered do
			for _, enemyId in world.roster do
				expect(Enemies.get(enemyId) ~= nil).toBeTruthy()
			end
			for _, enemyId in world.newEnemies do
				expect(table.find(world.roster, enemyId) ~= nil).toBeTruthy()
			end
			expect(Enemies.get(world.boss).boss).toBe(true)
			expect(#world.path >= 2).toBeTruthy()
		end
	end)
	it("summon/split references are valid", function()
		for _, enemy in Enemies.byId do
			if enemy.splitInto then
				expect(Enemies.get(enemy.splitInto.enemy) ~= nil).toBeTruthy()
			end
			for _, ability in enemy.abilities or {} do
				if ability.type == "summon" then
					expect(Enemies.get(ability.enemy) ~= nil).toBeTruthy()
				end
			end
		end
	end)
end)

describe("Rewards reference real things", function()
	local function checkBundle(bundle)
		for key in bundle do
			if key ~= "PassXp" then
				expect(Items.get(key) ~= nil).toBeTruthy()
			end
		end
	end
	it("battle pass rewards", function()
		for level = 1, BattlePass.levels do
			for _, track in { BattlePass.free, BattlePass.premium } do
				local reward = track[level]
				expect(reward ~= nil).toBeTruthy()
				if reward.kind == "Item" then
					expect(Items.get(reward.id) ~= nil).toBeTruthy()
				else
					expect(Units.get(reward.id) ~= nil).toBeTruthy()
				end
			end
		end
	end)
	it("quests, login calendar, yearbook, challenges, shop", function()
		for _, quest in Quests.DailyPool do
			expect(Quests.Stats[quest.stat] ~= nil).toBeTruthy()
			checkBundle(quest.reward)
		end
		for _, quest in Quests.WeeklyPool do
			expect(Quests.Stats[quest.stat] ~= nil).toBeTruthy()
			checkBundle(quest.reward)
		end
		for _, day in Quests.DailyLogin do
			checkBundle(day)
		end
		for _, milestone in Quests.YearbookMilestones do
			checkBundle(milestone.reward)
		end
		for _, reward in Challenges.Rewards do
			checkBundle(reward)
		end
		for _, product in Shop.Products do
			if product.grant then
				checkBundle(product.grant)
			end
		end
		for _, entry in Shop.GumballItems do
			checkBundle(entry.grant)
		end
	end)
end)
