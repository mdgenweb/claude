--[[
	InventoryService
	Owned unit instances: create, release, lock, team (hotbar of 6), unit XP.
	Each copy is its own instance with its own grades, trait and level (like CKD / Anime Vanguards).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Units = require(Shared.Config.Units)
local Levels = require(Shared.Logic.Levels)
local RerollLogic = require(Shared.Logic.RerollLogic)

local InventoryService = {}

local registry
local rng = Random.new()

function InventoryService.capacity(player: Player): number
	if registry.ShopService.hasPass(player, "BigBackpack") then
		return GameConfig.Inventory.BigBackpackCapacity
	end
	return GameConfig.Inventory.BaseCapacity
end

function InventoryService.count(profile): number
	local n = 0
	for _ in profile.units do
		n += 1
	end
	return n
end

function InventoryService.freeSlots(player: Player, profile): number
	return InventoryService.capacity(player) - InventoryService.count(profile)
end

-- Creates a unit instance. `force` ignores capacity (rewards must never be lost).
function InventoryService.addUnit(player: Player, profile, unitId: string, options: { shiny: boolean?, force: boolean? }?)
	local unit = Units.get(unitId)
	if not unit then
		return nil, "Unknown unit"
	end
	if not (options and options.force) and InventoryService.freeSlots(player, profile) <= 0 then
		return nil, "Your backpack is full!"
	end
	local uid = "u" .. profile.nextUid
	profile.nextUid += 1
	local instance = {
		uid = uid,
		id = unitId,
		level = 1,
		xp = 0,
		trait = nil,
		grades = RerollLogic.rollGrades(rng, nil, nil),
		shiny = (options and options.shiny == true) or unit.alwaysShiny == true,
		locked = false,
		at = os.time(),
	}
	profile.units[uid] = instance
	local isNew = not profile.discovered[unitId]
	profile.discovered[unitId] = true
	-- Auto-fill an empty team slot so new players immediately use what they pull.
	if #profile.team < GameConfig.Inventory.TeamSize and isNew then
		table.insert(profile.team, uid)
	end
	registry.DataService.markDirty(player)
	return instance, nil, isNew
end

function InventoryService.get(profile, uid: any)
	if type(uid) ~= "string" then
		return nil
	end
	return profile.units[uid]
end

function InventoryService.removeUnit(player: Player, profile, uid: string)
	profile.units[uid] = nil
	local index = table.find(profile.team, uid)
	if index then
		table.remove(profile.team, index)
	end
	registry.DataService.markDirty(player)
end

function InventoryService.grantUnitXp(player: Player, profile, uids: { string }, xp: number)
	for _, uid in uids do
		local instance = profile.units[uid]
		if instance then
			instance.level, instance.xp = Levels.applyUnitXp(instance.level, instance.xp, xp)
		end
	end
	registry.DataService.markDirty(player)
end

function InventoryService.ensureStarter(player: Player, profile)
	if profile.nextUid > 1 then
		return
	end
	for _, unitId in GameConfig.Starting.StarterUnits do
		InventoryService.addUnit(player, profile, unitId, { force = true })
	end
end

function InventoryService.init(services)
	registry = services
end

function InventoryService.start()
	local NetService = registry.NetService

	registry.DataService.ProfileLoaded:Connect(function(player, profile)
		InventoryService.ensureStarter(player, profile)
		-- Drop dangling team references (e.g. after a release in another server).
		for index = #profile.team, 1, -1 do
			if not profile.units[profile.team[index]] then
				table.remove(profile.team, index)
			end
		end
	end)

	NetService.addViewDecorator(function(player, _profile, view)
		view.capacity = InventoryService.capacity(player)
	end)

	NetService.handle("SetTeamSlot", function(player, payload, profile)
		if registry.MatchService.isInMatch(player) then
			return false, "Can't change your team during a match."
		end
		local uid = payload.uid
		local slot = tonumber(payload.slot)
		if uid ~= nil and not InventoryService.get(profile, uid) then
			return false, "Unit not found."
		end
		-- Remove from current slot first.
		if uid then
			local existing = table.find(profile.team, uid)
			if existing then
				table.remove(profile.team, existing)
			end
		end
		if slot and slot >= 1 and slot <= GameConfig.Inventory.TeamSize then
			slot = math.floor(slot)
			if uid then
				-- Prevent two copies of the same unit type on the hotbar.
				for index, otherUid in profile.team do
					local other = profile.units[otherUid]
					if other and other.id == profile.units[uid].id then
						table.remove(profile.team, index)
						break
					end
				end
				table.insert(profile.team, math.min(slot, #profile.team + 1), uid)
			else
				table.remove(profile.team, slot)
			end
		elseif uid then
			if #profile.team >= GameConfig.Inventory.TeamSize then
				return false, "Your team is full (6). Unequip someone first."
			end
			for index, otherUid in profile.team do
				local other = profile.units[otherUid]
				if other and other.id == profile.units[uid].id then
					table.remove(profile.team, index)
					break
				end
			end
			table.insert(profile.team, uid)
		end
		while #profile.team > GameConfig.Inventory.TeamSize do
			table.remove(profile.team)
		end
		return true, profile.team
	end, { rate = 8 })

	NetService.handle("UnequipUnit", function(player, payload, profile)
		if registry.MatchService.isInMatch(player) then
			return false, "Can't change your team during a match."
		end
		local index = table.find(profile.team, payload.uid)
		if index then
			table.remove(profile.team, index)
		end
		return true, profile.team
	end, { rate = 8 })

	NetService.handle("LockUnit", function(_player, payload, profile)
		local instance = InventoryService.get(profile, payload.uid)
		if not instance then
			return false, "Unit not found."
		end
		instance.locked = payload.locked == true
		return true, instance.locked
	end, { rate = 8 })

	NetService.handle("ReleaseUnits", function(player, payload, profile)
		if type(payload.uids) ~= "table" or #payload.uids == 0 or #payload.uids > 200 then
			return false, "Pick some units to release."
		end
		local refund = 0
		local released = 0
		for _, uid in payload.uids do
			local instance = InventoryService.get(profile, uid)
			if instance and not instance.locked and not table.find(profile.team, uid) then
				local unit = Units.get(instance.id)
				refund += GameConfig.Units.ReleaseRefund[unit.rarity] or 0
				InventoryService.removeUnit(player, profile, uid)
				released += 1
			end
		end
		if released == 0 then
			return false, "Locked or equipped units can't be released."
		end
		registry.EconomyService.grant(player, profile, { Gumballs = refund })
		return true, { released = released, refund = refund }
	end, { rate = 2 })
end

return InventoryService
