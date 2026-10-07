--!strict
-- Player profile schema: defaults, migrations and sanitisation of loaded data.
-- Bump CURRENT_VERSION and add a migration step whenever the shape changes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local BallDefinitions = require(Shared.Definitions.BallDefinitions)
local CosmeticDefinitions = require(Shared.Definitions.CosmeticDefinitions)
local GachaDefinitions = require(Shared.Definitions.GachaDefinitions)

export type Profile = {
	Version: number,
	Coins: number,
	Gems: number,
	XP: number,
	Level: number,
	Balls: { [string]: number },
	Explosions: { [string]: number },
	Flyers: { [string]: number },
	Equipped: { Explosion: string, Flyer: string },
	Tickets: { [string]: number },
	Stats: {
		Wins: number,
		Losses: number,
		Matches: number,
		RobuxSpent: number,
		Streak: number,
		BestStreak: number,
	},
	Weekly: { Week: number, Wins: number, RobuxSpent: number },
	Quests: { Day: number, Progress: { [string]: number }, Done: { [string]: boolean } },
	Codes: { [string]: boolean },
	Flags: { FirstBattle: boolean, GroupClaimed: boolean, WeeklyPaid: { [string]: boolean } },
	Receipts: { string },
	Created: number,
	LastLogin: number,
}

local Schema = {}

Schema.CURRENT_VERSION = 1

local function countMap(ids: { string }): { [string]: number }
	local map = {}
	for _, id in ids do
		map[id] = (map[id] or 0) + 1
	end
	return map
end

function Schema.Default(): Profile
	local now = os.time()
	return {
		Version = Schema.CURRENT_VERSION,
		Coins = Economy.Starting.Coins,
		Gems = Economy.Starting.Gems,
		XP = 0,
		Level = 1,
		Balls = countMap(Economy.Starting.Balls),
		Explosions = countMap(Economy.Starting.Explosions),
		Flyers = countMap(Economy.Starting.Flyers),
		Equipped = { Explosion = Economy.Starting.Explosions[1], Flyer = Economy.Starting.Flyers[1] },
		Tickets = {},
		Stats = { Wins = 0, Losses = 0, Matches = 0, RobuxSpent = 0, Streak = 0, BestStreak = 0 },
		Weekly = { Week = 0, Wins = 0, RobuxSpent = 0 },
		Quests = { Day = 0, Progress = {}, Done = {} },
		Codes = {},
		Flags = { FirstBattle = false, GroupClaimed = false, WeeklyPaid = {} },
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
	if type(v) ~= "number" or v ~= v then
		return default
	end
	return math.clamp(math.floor(v), min, max)
end

local function sanitizeCounts(v: any, isValid: (string) -> boolean): { [string]: number }
	local out = {}
	if type(v) ~= "table" then
		return out
	end
	for id, count in v do
		if type(id) == "string" and isValid(id) then
			local n = num(count, 0, 0, Economy.Limits.MaxItemCount)
			if n > 0 then
				out[id] = n
			end
		end
	end
	return out
end

-- Repairs a loaded record so the rest of the server can trust its shape.
function Schema.Sanitize(raw: any): Profile
	local data = if type(raw) == "table" then raw else {}
	local version = num(data.Version, 0, 0, 1000)
	while version < Schema.CURRENT_VERSION and Migrations[version] do
		data = Migrations[version](data)
		version += 1
	end

	local p = Schema.Default()
	if version == 0 and data.Coins == nil then
		return p -- brand new player
	end

	p.Coins = num(data.Coins, p.Coins, 0, Economy.Limits.MaxCoins)
	p.Gems = num(data.Gems, p.Gems, 0, Economy.Limits.MaxGems)
	p.XP = num(data.XP, 0, 0, 1e12)
	p.Level = num(data.Level, 1, 1, Economy.MaxLevel)
	p.Balls = sanitizeCounts(data.Balls, BallDefinitions.Exists)
	p.Explosions = sanitizeCounts(data.Explosions, function(id)
		return CosmeticDefinitions.Exists("Explosion", id)
	end)
	p.Flyers = sanitizeCounts(data.Flyers, function(id)
		return CosmeticDefinitions.Exists("Flyer", id)
	end)
	-- defaults are always owned
	for _, def in CosmeticDefinitions.All() do
		if def.Default then
			local bag = if def.Kind == "Explosion" then p.Explosions else p.Flyers
			bag[def.Id] = math.max(bag[def.Id] or 0, 1)
		end
	end
	p.Tickets = sanitizeCounts(data.Tickets, function(id)
		return GachaDefinitions.Get(id) ~= nil
	end)

	local equipped = if type(data.Equipped) == "table" then data.Equipped else {}
	if type(equipped.Explosion) == "string" and (p.Explosions[equipped.Explosion] or 0) > 0 then
		p.Equipped.Explosion = equipped.Explosion
	end
	if type(equipped.Flyer) == "string" and (p.Flyers[equipped.Flyer] or 0) > 0 then
		p.Equipped.Flyer = equipped.Flyer
	end

	local stats = if type(data.Stats) == "table" then data.Stats else {}
	for key, default in p.Stats :: any do
		(p.Stats :: any)[key] = num(stats[key], default, 0, 1e12)
	end
	local weekly = if type(data.Weekly) == "table" then data.Weekly else {}
	p.Weekly.Week = num(weekly.Week, 0, 0, 1e9)
	p.Weekly.Wins = num(weekly.Wins, 0, 0, 1e12)
	p.Weekly.RobuxSpent = num(weekly.RobuxSpent, 0, 0, 1e12)

	local quests = if type(data.Quests) == "table" then data.Quests else {}
	p.Quests.Day = num(quests.Day, 0, 0, 1e9)
	if type(quests.Progress) == "table" then
		for id, v in quests.Progress do
			if type(id) == "string" and #id <= 32 then
				p.Quests.Progress[id] = num(v, 0, 0, 1e6)
			end
		end
	end
	if type(quests.Done) == "table" then
		for id, v in quests.Done do
			if type(id) == "string" and #id <= 32 and v == true then
				p.Quests.Done[id] = true
			end
		end
	end

	if type(data.Codes) == "table" then
		for code, v in data.Codes do
			if type(code) == "string" and #code <= 32 and v == true then
				p.Codes[code] = true
			end
		end
	end

	local flags = if type(data.Flags) == "table" then data.Flags else {}
	p.Flags.FirstBattle = flags.FirstBattle == true
	p.Flags.GroupClaimed = flags.GroupClaimed == true
	if type(flags.WeeklyPaid) == "table" then
		for week, v in flags.WeeklyPaid do
			if type(week) == "string" and v == true then
				p.Flags.WeeklyPaid[week] = true
			end
		end
	end

	if type(data.Receipts) == "table" then
		for _, id in data.Receipts do
			if type(id) == "string" and #id <= 64 then
				table.insert(p.Receipts, id)
			end
		end
		while #p.Receipts > 50 do
			table.remove(p.Receipts, 1)
		end
	end

	p.Created = num(data.Created, os.time(), 0, 1e11)
	p.LastLogin = os.time()
	return p
end

-- What the owning client is allowed to see.
function Schema.PublicView(p: Profile): { [string]: any }
	return {
		Coins = p.Coins,
		Gems = p.Gems,
		XP = p.XP,
		Level = p.Level,
		Balls = table.clone(p.Balls),
		Explosions = table.clone(p.Explosions),
		Flyers = table.clone(p.Flyers),
		Equipped = table.clone(p.Equipped),
		Tickets = table.clone(p.Tickets),
		Stats = table.clone(p.Stats),
		Quests = { Day = p.Quests.Day, Progress = table.clone(p.Quests.Progress), Done = table.clone(p.Quests.Done) },
		Flags = { FirstBattle = p.Flags.FirstBattle, GroupClaimed = p.Flags.GroupClaimed },
	}
end

return Schema
