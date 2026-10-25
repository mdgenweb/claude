--[[
	RerollService
	Traits (Void Rift, Void Shards) and stat grades (Principal Brown's Office, Report Cards).
	Auto-roll keeps rolling server-side until a target trait hits, so players don't click 100 times.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Traits = require(Shared.Config.Traits)
local Grades = require(Shared.Config.Grades)
local RerollLogic = require(Shared.Logic.RerollLogic)

local RerollService = {}

local registry
local rng = Random.new()

function RerollService.init(services)
	registry = services
end

function RerollService.start()
	local NetService = registry.NetService
	local EconomyService = registry.EconomyService

	NetService.handle("RerollTrait", function(player, payload, profile)
		local instance = registry.InventoryService.get(profile, payload.uid)
		if not instance then
			return false, "Unit not found."
		end
		if registry.MatchService.isInMatch(player) then
			return false, "Finish your match first!"
		end
		local targets = {}
		if type(payload.targets) == "table" then
			for _, id in payload.targets do
				if Traits.get(id) then
					targets[id] = true
				end
			end
		end
		local auto = next(targets) ~= nil
		local maxRolls = if auto then math.clamp(tonumber(payload.maxRolls) or 25, 1, GameConfig.Traits.MaxAutoRolls) else 1
		local vip = registry.ShopService.hasPass(player, "VIP")
		local cost = GameConfig.Traits.RerollCost

		local rolls = 0
		local history = {}
		local previous = instance.trait
		while rolls < maxRolls do
			local ok, err = EconomyService.spend(player, profile, { VoidShards = cost }, true)
			if not ok then
				if rolls == 0 then
					return false, err
				end
				break
			end
			rolls += 1
			instance.trait = RerollLogic.rollTrait(rng, vip)
			table.insert(history, instance.trait)
			if #history > 12 then
				table.remove(history, 1)
			end
			if not auto or targets[instance.trait] then
				break
			end
		end
		registry.ProgressionService.track(player, profile, "TraitRolls", rolls)
		return true, {
			uid = instance.uid,
			trait = instance.trait,
			previous = previous,
			rolls = rolls,
			history = history,
			hit = auto and targets[instance.trait] == true,
		}
	end, { rate = 3, burst = 4 })

	NetService.handle("RerollGrades", function(player, payload, profile)
		local instance = registry.InventoryService.get(profile, payload.uid)
		if not instance then
			return false, "Unit not found."
		end
		if registry.MatchService.isInMatch(player) then
			return false, "Finish your match first!"
		end
		local lock = payload.lock
		if lock ~= nil and not table.find(Grades.STATS, lock) then
			return false, "Bad stat."
		end
		local cost = if lock then GameConfig.Grades.LockedRerollCost else GameConfig.Grades.RerollCost
		local ok, err = EconomyService.spend(player, profile, { ReportCards = cost }, true)
		if not ok then
			return false, err
		end
		local previous = table.clone(instance.grades)
		instance.grades = RerollLogic.rollGrades(rng, instance.grades, lock)
		registry.ProgressionService.track(player, profile, "GradeRolls", 1)
		return true, { uid = instance.uid, grades = instance.grades, previous = previous }
	end, { rate = 4 })
end

return RerollService
