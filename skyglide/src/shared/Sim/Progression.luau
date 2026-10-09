--!strict
-- Pure progression math shared by server (authoritative), client (display) and tests:
-- multipliers, XP/levels, rebirth rules and reward sizes. No Roblox APIs, no side effects except
-- the documented profile mutation in SyncLevel.
local Shared = script.Parent.Parent
local Economy = require(Shared.Config.Economy)
local Pets = require(Shared.Definitions.Pets)
local Trails = require(Shared.Definitions.Trails)
local Boosts = require(Shared.Definitions.Boosts)
local Gliders = require(Shared.Definitions.Gliders)
local Relics = require(Shared.Definitions.Relics)

local Progression = {}

-- Minimal profile shape these functions read (the server profile and the client view both fit).
export type ProfileLike = {
	Skill: number,
	Rebirths: number,
	Level: number,
	XP: number,
	Pets: { [string]: { Id: string, Locked: boolean? } },
	EquippedPets: { string },
	Boosts: { [string]: number }, -- boost id -> unix expiry
	Trail: string,
	Glider: string,
	Gliders: { [string]: boolean },
	Relic: string, -- equipped relic id or ""
	Relics: { [string]: boolean },
}

export type Context = {
	Passes: { [string]: boolean },
	Friends: number,
	Premium: boolean,
	Now: number,
	EventSkill: number?, -- live event multipliers (1 when no event)
	EventWins: number?,
}

function Progression.FriendBoost(friends: number): number
	return math.min(Economy.FriendBoostMax, Economy.FriendBoostPer * math.max(0, friends))
end

function Progression.PetBoosts(p: ProfileLike): (number, number)
	local skill, wins = 0, 0
	for _, uid in p.EquippedPets do
		local owned = p.Pets[uid]
		local def = if owned then Pets.Get(owned.Id) else nil
		if def then
			skill += def.SkillBoost
			wins += def.WinsBoost
		end
	end
	return skill, wins
end

function Progression.BoostActive(p: ProfileLike, stat: string, now: number): number
	local mult = 1
	for id, expiry in p.Boosts do
		local def = Boosts.Get(id)
		if def and def.Stat == stat and expiry > now then
			mult *= def.Multiplier
		end
	end
	return mult
end

export type Breakdown = {
	Rebirth: number,
	Pets: number,
	Pass: number,
	Potion: number,
	Friends: number,
	Premium: number,
	Event: number,
	Total: number,
}

-- Multiplier applied to every Skill gain (training reps and thermal rings).
function Progression.SkillBreakdown(p: ProfileLike, ctx: Context): Breakdown
	local rebirth = Economy.RebirthMultiplier(p.Rebirths)
	local petSkill = Progression.PetBoosts(p)
	local pets = 1 + petSkill
	local pass = if ctx.Passes.DoubleSkill then 2 else 1
	local potion = Progression.BoostActive(p, "Skill", ctx.Now)
	local friends = 1 + Progression.FriendBoost(ctx.Friends)
	local premium = if ctx.Premium then 1 + Economy.PremiumSkillBonus else 1
	local event = ctx.EventSkill or 1
	return {
		Rebirth = rebirth,
		Pets = pets,
		Pass = pass,
		Potion = potion,
		Friends = friends,
		Premium = premium,
		Event = event,
		Total = rebirth * pets * pass * potion * friends * premium * event,
	}
end

function Progression.SkillMultiplier(p: ProfileLike, ctx: Context): number
	return Progression.SkillBreakdown(p, ctx).Total
end

function Progression.WinsMultiplier(p: ProfileLike, ctx: Context): number
	local _, petWins = Progression.PetBoosts(p)
	local trail = Trails.Get(p.Trail)
	local trailBoost = if trail then trail.WinsBoost else 0
	local pass = if ctx.Passes.DoubleWins then 2 else 1
	local potion = Progression.BoostActive(p, "Wins", ctx.Now)
	return (1 + petWins) * (1 + trailBoost) * pass * potion * (ctx.EventWins or 1)
end

function Progression.Luck(p: ProfileLike, ctx: Context): number
	return Progression.BoostActive(p, "Luck", ctx.Now)
end

-- "+N Skill" per thermal ring for the equipped glider (or relic: 125% better than the best glider).
function Progression.SkillPerRing(p: ProfileLike): number
	if p.Relic ~= "" and p.Relics[p.Relic] then
		local relic = Relics.Get(p.Relic)
		if relic then
			local best = Gliders.BestOwned(p.Gliders)
			return best.SkillPerRing * (1 + relic.BonusOverBest)
		end
	end
	local glider = Gliders.Get(p.Glider) or Gliders.Get(Gliders.Default)
	return if glider then glider.SkillPerRing else 1
end

function Progression.LevelCap(p: ProfileLike): number
	return Economy.LevelCap(p.Rebirths)
end

function Progression.IsMaxLevel(p: ProfileLike): boolean
	return p.Level >= Progression.LevelCap(p)
end

-- Rebirth button percentage (OBSERVED "Rebirth 83%" / "100%"): level progress toward the cap.
function Progression.RebirthProgress(p: ProfileLike): number
	return math.clamp(p.Level / Progression.LevelCap(p), 0, 1)
end

function Progression.CanRebirth(p: ProfileLike): boolean
	return Progression.IsMaxLevel(p) and p.Rebirths < Economy.MaxRebirths
end

-- Recomputes Level and XP (progress inside the level, in Skill) from Skill and the cap.
-- Mutates p.Level / p.XP and returns the number of levels gained.
function Progression.SyncLevel(p: ProfileLike): number
	local cap = Progression.LevelCap(p)
	local before = p.Level
	local level = Economy.LevelForSkill(p.Skill, cap)
	p.Level = level
	if level >= cap then
		p.XP = Economy.XPToNext(level)
	else
		p.XP = math.max(0, p.Skill - Economy.SkillForLevel(level))
	end
	return math.max(0, level - before)
end

-- Does this Skill source still pay right now? (Training and rings stop at the level cap.)
function Progression.SourcePays(p: ProfileLike, source: string): boolean
	if Economy.CappedSources[source] and Progression.IsMaxLevel(p) then
		return false
	end
	return true
end

-- Number of pet slots.
function Progression.PetSlots(ctx: Context): number
	return Economy.PetSlots + (if ctx.Passes.PetSlots then Economy.PetSlotsPass else 0)
end

return Progression
