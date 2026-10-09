--!strict
-- Eggs and pets. Hatches are rolled on the server (weighted, Luck boosts Rare+ tiers).
-- Equipped pet ids are mirrored to a player attribute so every client can draw followers.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Map = require(Shared.Config.Map)
local Rarity = require(Shared.Config.Rarity)
local Pets = require(Shared.Definitions.Pets)
local Eggs = require(Shared.Definitions.Eggs)
local Progression = require(Shared.Sim.Progression)
local Remotes = require(Shared.Net.Remotes)
local Validate = require(Shared.Util.Validate)
local Format = require(Shared.Util.Format)

local Server = script.Parent.Parent
local Guard = require(Server.Util.Guard)
local DataService = require(script.Parent.DataService)
local StatService = require(script.Parent.StatService)
local MapService = require(script.Parent.MapService)

local PetService = {}

local registry: { [string]: any } = {}
local hatchResult: RemoteEvent
local rng = Random.new()

local EGG_REACH = 30

local function petCount(p: DataService.Profile): number
	local n = 0
	for _ in p.Pets do
		n += 1
	end
	return n
end

local function slots(player: Player): number
	return Progression.PetSlots(StatService.Context(player))
end

local function mirror(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local ids = {}
	for _, uid in profile.EquippedPets do
		local pet = profile.Pets[uid]
		if pet then
			table.insert(ids, pet.Id)
		end
	end
	player:SetAttribute("Pets", table.concat(ids, ","))
end
PetService.Mirror = mirror

local function score(id: string): number
	local def = Pets.Get(id)
	return if def then def.SkillBoost * 1000 + def.WinsBoost else 0
end

-- Adds a pet, auto-equipping it when a slot is free or it beats the weakest equipped pet.
local function addPet(player: Player, petId: string): string?
	local maxSlots = slots(player)
	local uid = DataService.Update(player, function(p)
		local id = tostring(p.NextPetId)
		p.NextPetId += 1
		p.Pets[id] = { Id = petId, Locked = false }
		if #p.EquippedPets < maxSlots then
			table.insert(p.EquippedPets, id)
		else
			local weakestIndex, weakestScore = 0, math.huge
			for i, eq in p.EquippedPets do
				local owned = p.Pets[eq]
				local s = if owned then score(owned.Id) else -1
				if s < weakestScore then
					weakestIndex, weakestScore = i, s
				end
			end
			if weakestIndex > 0 and score(petId) > weakestScore then
				p.EquippedPets[weakestIndex] = id
			end
		end
		return id
	end)
	return uid
end

local function roll(egg: Eggs.Egg, luck: number): string
	local odds = Eggs.Odds(egg, luck)
	local r = rng:NextNumber()
	for _, entry in odds do
		r -= entry.Chance
		if r <= 0 then
			return entry.Pet
		end
	end
	return odds[#odds].Pet
end

local function announce(player: Player, petId: string)
	local def = Pets.Get(petId)
	if def and Rarity.Order(def.Rarity) >= Rarity.Order("Legendary") then
		local notify = registry.NotifyService
		if notify then
			notify.All(string.format("%s hatched a %s %s!", player.DisplayName, def.Rarity, def.Name), "Rare")
		end
	end
end

local function hatch(player: Player, egg: Eggs.Egg, count: number): { { Uid: string, Id: string } }
	local luck = StatService.Luck(player)
	local results = {}
	for _ = 1, count do
		local petId = roll(egg, luck)
		local uid = addPet(player, petId)
		if uid then
			table.insert(results, { Uid = uid, Id = petId })
			announce(player, petId)
		end
	end
	DataService.Update(player, function(p)
		p.Stats.Hatches += #results
		return true
	end)
	mirror(player)
	hatchResult:FireClient(player, { Egg = egg.Id, Pets = results })
	local tutorial = registry.TutorialService
	if tutorial then
		tutorial.Event(player, "Hatch")
	end
	return results
end

-- Robux egg / rewards: hatch without paying Wins (inventory cap is not enforced on paid hatches).
function PetService.HatchFree(player: Player, eggId: string, count: number)
	local egg = Eggs.Get(eggId)
	if egg then
		hatch(player, egg, math.clamp(count, 1, 3))
	end
end

function PetService.GivePet(player: Player, petId: string, source: string)
	if not Pets.Exists(petId) then
		return
	end
	addPet(player, petId)
	mirror(player)
	local def = Pets.Get(petId) :: Pets.Pet
	local notify = registry.NotifyService
	if notify then
		notify.Toast(player, string.format("%s: you got %s!", source, def.Name), "Success")
	end
	hatchResult:FireClient(player, { Egg = "", Pets = { { Uid = "", Id = petId } }, Source = source })
end

local function eggPosition(egg: Eggs.Egg, worldId: number): Vector3?
	for i, e in Eggs.ForWorld(worldId) do
		if e.Id == egg.Id then
			return Map.Origin(worldId) + Map.EggPosition(i)
		end
	end
	return nil
end

local function requestHatch(player: Player, eggId: any, count: any): { [string]: any }
	if not Eggs.Exists(eggId) or not Validate.Integer(count, 1, 3) then
		return { ok = false, error = "Unknown egg." }
	end
	local egg = Eggs.Get(eggId) :: Eggs.Egg
	local profile = DataService.Get(player)
	if not profile then
		return { ok = false, error = "Still loading..." }
	end
	if egg.ProductKey then
		return { ok = false, error = "This egg is bought with Robux.", product = egg.ProductKey }
	end
	if count == 3 then
		local monetization = registry.MonetizationService
		if not (monetization and monetization.HasPass(player, "TripleHatch")) then
			return { ok = false, error = "Triple Hatch needs the Triple Hatch pass!", pass = "TripleHatch" }
		end
	elseif count ~= 1 then
		return { ok = false, error = "Hatch 1 or 3." }
	end
	local worldId = egg.World or profile.World
	if not profile.Worlds[tostring(worldId)] or profile.World ~= worldId then
		return { ok = false, error = "Go to this egg's world first!" }
	end
	local pos = eggPosition(egg, worldId)
	if not pos or not MapService.Near(player, pos, EGG_REACH) then
		return { ok = false, error = "Walk up to the egg to hatch it." }
	end
	if petCount(profile) + count > Economy.PetInventory then
		return { ok = false, error = "Your pet inventory is full! Delete some pets." }
	end
	local cost = egg.Price * count
	if not StatService.SpendWins(player, cost) then
		return { ok = false, error = string.format("You need %s Wins!", Format.Short(cost)) }
	end
	local results = hatch(player, egg, count)
	return { ok = true, pets = results }
end

local function petAction(player: Player, action: any, arg: any): { [string]: any }
	local profile = DataService.Get(player)
	if not profile then
		return { ok = false, error = "Still loading..." }
	end
	local maxSlots = slots(player)
	if action == "Equip" then
		if type(arg) ~= "string" or not profile.Pets[arg] then
			return { ok = false, error = "Unknown pet." }
		end
		if table.find(profile.EquippedPets, arg) then
			return { ok = true }
		end
		if #profile.EquippedPets >= maxSlots then
			return { ok = false, error = string.format("All %d slots are full!", maxSlots) }
		end
		DataService.Update(player, function(p)
			table.insert(p.EquippedPets, arg)
			return true
		end)
	elseif action == "Unequip" then
		if type(arg) ~= "string" then
			return { ok = false, error = "Unknown pet." }
		end
		DataService.Update(player, function(p)
			local i = table.find(p.EquippedPets, arg)
			if i then
				table.remove(p.EquippedPets, i)
			end
			return true
		end)
	elseif action == "EquipBest" then
		DataService.Update(player, function(p)
			local uids = {}
			for uid in p.Pets do
				table.insert(uids, uid)
			end
			table.sort(uids, function(a, b)
				local sa, sb = score(p.Pets[a].Id), score(p.Pets[b].Id)
				if sa == sb then
					return a < b
				end
				return sa > sb
			end)
			p.EquippedPets = {}
			for i = 1, math.min(maxSlots, #uids) do
				table.insert(p.EquippedPets, uids[i])
			end
			return true
		end)
	elseif action == "UnequipAll" then
		DataService.Update(player, function(p)
			p.EquippedPets = {}
			return true
		end)
	elseif action == "Lock" or action == "Unlock" then
		if type(arg) ~= "string" or not profile.Pets[arg] then
			return { ok = false, error = "Unknown pet." }
		end
		DataService.Update(player, function(p)
			p.Pets[arg].Locked = action == "Lock"
			return true
		end)
	elseif action == "Delete" then
		if type(arg) ~= "table" or #arg == 0 or #arg > Economy.PetInventory + 20 then
			return { ok = false, error = "Pick pets to delete." }
		end
		local deleted = 0
		DataService.Update(player, function(p)
			for _, uid in arg do
				if type(uid) == "string" and p.Pets[uid] and not p.Pets[uid].Locked then
					p.Pets[uid] = nil
					local i = table.find(p.EquippedPets, uid)
					if i then
						table.remove(p.EquippedPets, i)
					end
					deleted += 1
				end
			end
			return true
		end)
		mirror(player)
		return { ok = true, message = string.format("Deleted %d pet%s.", deleted, if deleted == 1 then "" else "s") }
	else
		return { ok = false, error = "Unknown action." }
	end
	mirror(player)
	return { ok = true }
end

function PetService.Init(reg: { [string]: any })
	registry = reg
	hatchResult = Remotes.Event("HatchResult")
	DataService.Loaded:Connect(function(player)
		-- trim to the current slot count (a pass may have been refunded)
		local maxSlots = slots(player)
		DataService.Update(player, function(p)
			while #p.EquippedPets > maxSlots do
				table.remove(p.EquippedPets)
			end
			return true
		end)
		mirror(player)
	end)
end

function PetService.Start()
	Guard.OnInvoke(Remotes.Function("RequestHatchEgg"), 2, 4, requestHatch)
	Guard.OnInvoke(Remotes.Function("RequestPetAction"), 5, 10, petAction)
	local _ = Players
end

return PetService
