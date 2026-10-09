--!strict
-- Player profile schema: defaults, migrations and sanitisation of loaded data.
-- Bump CURRENT_VERSION and add a migration step whenever the shape changes.
-- Dictionary keys are always strings (DataStore JSON cannot hold sparse numeric keys).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Gliders = require(Shared.Definitions.Gliders)
local Relics = require(Shared.Definitions.Relics)
local Trails = require(Shared.Definitions.Trails)
local Pets = require(Shared.Definitions.Pets)
local Boosts = require(Shared.Definitions.Boosts)
local Worlds = require(Shared.Definitions.Worlds)
local Zones = require(Shared.Definitions.Zones)
local Tutorial = require(Shared.Definitions.Tutorial)

export type OwnedPet = { Id: string, Locked: boolean }

export type Profile = {
	Version: number,
	Skill: number,
	Wins: number,
	Level: number,
	XP: number,
	Rebirths: number,
	World: number,
	Worlds: { [string]: boolean },
	Glider: string,
	Gliders: { [string]: boolean },
	Relic: string,
	Relics: { [string]: boolean },
	Trail: string,
	Trails: { [string]: boolean },
	Pets: { [string]: OwnedPet },
	EquippedPets: { string },
	NextPetId: number,
	Potions: { [string]: number },
	Boosts: { [string]: number },
	Daily: { Day: number, Streak: number },
	Codes: { [string]: boolean },
	Tutorial: { Step: number, Progress: number, Done: boolean },
	Settings: { AutoTrain: boolean, AutoThrow: boolean, FollowCam: boolean, Sfx: boolean, LowFx: boolean },
	Stats: {
		Throws: number,
		Perfects: number,
		Rings: number,
		BestDistance: number,
		TotalSkill: number,
		TotalWins: number,
		Hatches: number,
		Playtime: number,
		RobuxSpent: number,
	},
	Best: { [string]: number },
	Zones: { [string]: boolean },
	Flags: { StarterPack: boolean },
	TestPasses: { [string]: boolean }, -- Studio-only free test grants (ignored in live servers)
	Receipts: { string },
	Created: number,
	LastLogin: number,
}

local Schema = {}

Schema.CURRENT_VERSION = 1

function Schema.Default(): Profile
	local now = os.time()
	return {
		Version = Schema.CURRENT_VERSION,
		Skill = Economy.Starting.Skill,
		Wins = Economy.Starting.Wins,
		Level = 1,
		XP = 0,
		Rebirths = 0,
		World = 1,
		Worlds = { ["1"] = true },
		Glider = Economy.Starting.Glider,
		Gliders = { [Economy.Starting.Glider] = true },
		Relic = "",
		Relics = {},
		Trail = "",
		Trails = {},
		Pets = {},
		EquippedPets = {},
		NextPetId = 1,
		Potions = {},
		Boosts = {},
		Daily = { Day = 0, Streak = 0 },
		Codes = {},
		Tutorial = { Step = 1, Progress = 0, Done = false },
		Settings = { AutoTrain = false, AutoThrow = false, FollowCam = true, Sfx = true, LowFx = false },
		Stats = {
			Throws = 0,
			Perfects = 0,
			Rings = 0,
			BestDistance = 0,
			TotalSkill = 0,
			TotalWins = 0,
			Hatches = 0,
			Playtime = 0,
			RobuxSpent = 0,
		},
		Best = {},
		Zones = {},
		Flags = { StarterPack = false },
		TestPasses = {},
		Receipts = {},
		Created = now,
		LastLogin = now,
	}
end

-- Migrations: index = version being upgraded FROM.
local Migrations: { [number]: (any) -> any } = {
	-- [1] = function(data) data.NewField = ...; return data end,
}

local function num(v: any, default: number, min: number, max: number): number
	if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
		return default
	end
	return math.clamp(v, min, max)
end

local function int(v: any, default: number, min: number, max: number): number
	return math.floor(num(v, default, min, max))
end

local function boolSet(v: any, isValid: (string) -> boolean): { [string]: boolean }
	local out = {}
	if type(v) ~= "table" then
		return out
	end
	for id, flag in v do
		if type(id) == "string" and flag == true and isValid(id) then
			out[id] = true
		end
	end
	return out
end

-- Repairs a loaded record so the rest of the server can trust its shape.
function Schema.Sanitize(raw: any): Profile
	local data = if type(raw) == "table" then raw else {}
	local version = int(data.Version, 0, 0, 1000)
	while version < Schema.CURRENT_VERSION and Migrations[version] do
		data = Migrations[version](data)
		version += 1
	end

	local p = Schema.Default()
	if version == 0 and data.Skill == nil then
		return p -- brand new player
	end

	p.Skill = num(data.Skill, 0, 0, Economy.Limits.MaxSkill)
	p.Wins = num(data.Wins, 0, 0, Economy.Limits.MaxWins)
	p.Rebirths = int(data.Rebirths, 0, 0, Economy.MaxRebirths)
	-- Level and XP are derived from Skill (never trusted from storage)
	local cap = Economy.LevelCap(p.Rebirths)
	p.Level = Economy.LevelForSkill(p.Skill, cap)
	p.XP = if p.Level >= cap then Economy.XPToNext(p.Level) else math.max(0, p.Skill - Economy.SkillForLevel(p.Level))

	p.Worlds = boolSet(data.Worlds, function(id)
		return Worlds.Exists(tonumber(id))
	end)
	p.Worlds["1"] = true
	local world = int(data.World, 1, 1, Worlds.Count)
	p.World = if p.Worlds[tostring(world)] then world else 1

	p.Gliders = boolSet(data.Gliders, Gliders.Exists)
	p.Gliders[Gliders.Default] = true
	p.Glider = if type(data.Glider) == "string" and p.Gliders[data.Glider] then data.Glider else Gliders.Default

	p.Relics = boolSet(data.Relics, Relics.Exists)
	p.Relic = if type(data.Relic) == "string" and p.Relics[data.Relic] then data.Relic else ""

	p.Trails = boolSet(data.Trails, Trails.Exists)
	p.Trail = if type(data.Trail) == "string" and p.Trails[data.Trail] then data.Trail else ""

	local count = 0
	if type(data.Pets) == "table" then
		for uid, pet in data.Pets do
			if count >= Economy.PetInventory + 20 then
				break
			end
			if type(uid) == "string" and #uid <= 16 and type(pet) == "table" and Pets.Exists(pet.Id) then
				p.Pets[uid] = { Id = pet.Id, Locked = pet.Locked == true }
				count += 1
			end
		end
	end
	if type(data.EquippedPets) == "table" then
		local seen = {}
		for _, uid in data.EquippedPets do
			if type(uid) == "string" and p.Pets[uid] and not seen[uid] and #p.EquippedPets < Economy.PetSlots + Economy.PetSlotsPass then
				seen[uid] = true
				table.insert(p.EquippedPets, uid)
			end
		end
	end
	p.NextPetId = int(data.NextPetId, 1, 1, 1e12)

	if type(data.Potions) == "table" then
		for id, n in data.Potions do
			if Boosts.Exists(id) then
				local c = int(n, 0, 0, Economy.Limits.MaxPotions)
				if c > 0 then
					p.Potions[id] = c
				end
			end
		end
	end
	if type(data.Boosts) == "table" then
		local now = os.time()
		for id, expiry in data.Boosts do
			if Boosts.Exists(id) then
				local e = num(expiry, 0, 0, now + Boosts.MaxStackSeconds)
				if e > now then
					p.Boosts[id] = e
				end
			end
		end
	end

	local daily = if type(data.Daily) == "table" then data.Daily else {}
	p.Daily.Day = int(daily.Day, 0, 0, 1e9)
	p.Daily.Streak = int(daily.Streak, 0, 0, 1e6)

	p.Codes = boolSet(data.Codes, function(code)
		return #code <= 32
	end)

	local tut = if type(data.Tutorial) == "table" then data.Tutorial else {}
	p.Tutorial.Done = tut.Done == true
	p.Tutorial.Step = int(tut.Step, 1, 1, #Tutorial.Steps + 1)
	p.Tutorial.Progress = int(tut.Progress, 0, 0, 1e6)
	if p.Tutorial.Step > #Tutorial.Steps then
		p.Tutorial.Done = true
	end

	local settings = if type(data.Settings) == "table" then data.Settings else {}
	for key, default in p.Settings :: any do
		local v = settings[key]
		if type(v) == "boolean" then
			(p.Settings :: any)[key] = v
		else
			(p.Settings :: any)[key] = default
		end
	end

	local stats = if type(data.Stats) == "table" then data.Stats else {}
	for key, default in p.Stats :: any do
		(p.Stats :: any)[key] = num(stats[key], default, 0, 1e300)
	end

	if type(data.Best) == "table" then
		for id, v in data.Best do
			if type(id) == "string" and Worlds.Exists(tonumber(id)) then
				p.Best[id] = num(v, 0, 0, 1e300)
			end
		end
	end
	p.Zones = boolSet(data.Zones, function(id)
		return Zones.Get(id) ~= nil
	end)

	local flags = if type(data.Flags) == "table" then data.Flags else {}
	p.Flags.StarterPack = flags.StarterPack == true

	p.TestPasses = boolSet(data.TestPasses, function(key)
		return #key <= 32
	end)

	if type(data.Receipts) == "table" then
		for _, id in data.Receipts do
			if type(id) == "string" and #id <= 64 then
				table.insert(p.Receipts, id)
			end
		end
		while #p.Receipts > 100 do
			table.remove(p.Receipts, 1)
		end
	end

	p.Created = int(data.Created, os.time(), 0, 1e11)
	p.LastLogin = os.time()
	return p
end

local function clonePets(pets: { [string]: OwnedPet }): { [string]: OwnedPet }
	local out = {}
	for uid, pet in pets do
		out[uid] = { Id = pet.Id, Locked = pet.Locked }
	end
	return out
end

-- What the owning client is allowed to see (everything except receipts and test flags).
function Schema.PublicView(p: Profile): { [string]: any }
	return {
		Skill = p.Skill,
		Wins = p.Wins,
		Level = p.Level,
		XP = p.XP,
		Rebirths = p.Rebirths,
		World = p.World,
		Worlds = table.clone(p.Worlds),
		Glider = p.Glider,
		Gliders = table.clone(p.Gliders),
		Relic = p.Relic,
		Relics = table.clone(p.Relics),
		Trail = p.Trail,
		Trails = table.clone(p.Trails),
		Pets = clonePets(p.Pets),
		EquippedPets = table.clone(p.EquippedPets),
		Potions = table.clone(p.Potions),
		Boosts = table.clone(p.Boosts),
		Daily = table.clone(p.Daily),
		Tutorial = table.clone(p.Tutorial),
		Settings = table.clone(p.Settings),
		Stats = table.clone(p.Stats),
		Best = table.clone(p.Best),
		Zones = table.clone(p.Zones),
		Flags = table.clone(p.Flags),
	}
end

return Schema
