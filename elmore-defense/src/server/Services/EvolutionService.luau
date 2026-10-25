--[[
	EvolutionService ("Glow-Ups" at Joyful Burger)
	Evolution keeps level, trait, grades, shiny and lock state.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Evolutions = require(Shared.Config.Evolutions)
local Units = require(Shared.Config.Units)

local EvolutionService = {}

local registry

function EvolutionService.init(services)
	registry = services
end

function EvolutionService.start()
	registry.NetService.handle("Evolve", function(player, payload, profile)
		local instance = registry.InventoryService.get(profile, payload.uid)
		if not instance then
			return false, "Unit not found."
		end
		if registry.MatchService.isInMatch(player) then
			return false, "Finish your match first!"
		end
		local recipe = Evolutions[instance.id]
		if not recipe then
			return false, "This unit has no Glow-Up."
		end
		if (instance.level or 1) < recipe.level then
			return false, string.format("Reach level %d first.", recipe.level)
		end
		local costs = table.clone(recipe.items)
		costs.Gumballs = recipe.gumballs
		local ok, err = registry.EconomyService.spend(player, profile, costs, false)
		if not ok then
			return false, err
		end
		local fromId = instance.id
		instance.id = recipe.to
		profile.discovered[recipe.to] = true
		registry.NetService.notifyAll(
			string.format("%s glowed up %s into %s!", player.DisplayName, Units.get(fromId).name, Units.get(recipe.to).name),
			"broadcast"
		)
		return true, { uid = instance.uid, from = fromId, to = recipe.to }
	end, { rate = 2 })
end

return EvolutionService
