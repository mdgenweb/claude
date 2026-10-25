--[[
	DevService
	Studio-only testing tools (exposed in the client's Settings > Dev Tools panel).
	Live servers reject every command unless the user id is listed in GameConfig.Dev.AdminUserIds.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Units = require(Shared.Config.Units)
local Items = require(Shared.Config.Items)
local Worlds = require(Shared.Config.Worlds)
local BattlePass = require(Shared.Config.BattlePass)
local ProfileTemplate = require(script.Parent.ProfileTemplate)

local DevService = {}

local registry

local function allowed(player: Player): boolean
	if RunService:IsStudio() and GameConfig.Dev.EnableStudioCommands then
		return true
	end
	return table.find(GameConfig.Dev.AdminUserIds, player.UserId) ~= nil
end

local commands = {}

function commands.give(player, profile, args)
	local id, amount = args[1], tonumber(args[2]) or 1000
	if not Items.get(id) then
		return false, "Unknown item " .. tostring(id)
	end
	registry.EconomyService.grant(player, profile, { [id] = amount })
	return true, string.format("Gave %d %s", amount, id)
end

function commands.rich(player, profile)
	local bundle = {}
	for id in Items.byId do
		bundle[id] = if id == "Gumballs" then 100000 else 200
	end
	registry.EconomyService.grant(player, profile, bundle)
	return true, "You're rich!"
end

function commands.unit(player, profile, args)
	local unitId = args[1]
	if not Units.get(unitId) then
		return false, "Unknown unit " .. tostring(unitId)
	end
	local instance = registry.InventoryService.addUnit(player, profile, unitId, { shiny = args[2] == "shiny", force = true })
	return true, "Added " .. unitId .. " (" .. instance.uid .. ")"
end

function commands.allunits(player, profile)
	for id in Units.byId do
		registry.InventoryService.addUnit(player, profile, id, { force = true })
	end
	return true, "Added one of every unit"
end

function commands.maxlevel(player, profile)
	for _, instance in profile.units do
		instance.level = GameConfig.Units.MaxLevel
	end
	registry.DataService.markDirty(player)
	return true, "All units are max level"
end

function commands.unlockall(player, profile)
	for _, world in Worlds.ordered do
		for act = 1, Worlds.ACTS do
			profile.story[Worlds.stageKey(world.id, act)] = 3
		end
	end
	registry.DataService.markDirty(player)
	return true, "Unlocked every world and act"
end

function commands.pass(player, profile)
	registry.BattlePassService.grantPremium(player, profile)
	registry.BattlePassService.addXp(player, profile, BattlePass.xpPerLevel * 10)
	return true, "Premium + 10 pass levels"
end

function commands.cash(player, _profile, args)
	local match = registry.MatchService.getMatch(player)
	if not match then
		return false, "Not in a match"
	end
	match:devAddCash(player, tonumber(args[1]) or 10000)
	return true, "Cash added"
end

function commands.win(player)
	local match = registry.MatchService.getMatch(player)
	if not match then
		return false, "Not in a match"
	end
	match:devWin()
	return true, "Victory!"
end

function commands.reset(player, profile)
	local fresh = ProfileTemplate.new()
	for key in profile do
		profile[key] = nil
	end
	for key, value in fresh do
		profile[key] = value
	end
	registry.InventoryService.ensureStarter(player, profile)
	registry.DataService.markDirty(player)
	return true, "Profile reset"
end

function DevService.init(services)
	registry = services
end

function DevService.start()
	registry.NetService.handle("Dev", function(player, payload, profile)
		if not allowed(player) then
			return false, "Dev tools are disabled."
		end
		local fn = commands[payload.cmd]
		if not fn then
			return false, "Unknown command"
		end
		local args = if type(payload.args) == "table" then payload.args else {}
		return fn(player, profile, args)
	end, { rate = 4 })

	registry.NetService.addViewDecorator(function(player, _profile, view)
		view.devTools = allowed(player)
	end)
end

return DevService
