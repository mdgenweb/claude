--!strict
-- Progression & economy tuning. Values marked (OBSERVED) come from the reference screenshots,
-- (LIKELY) are inferred from them, everything else is ORIGINAL DESIGN (see docs/RESEARCH.md).
local Economy = {}

Economy.Starting = {
	Skill = 0,
	Wins = 0,
	Glider = "paper_dart",
}

-- Levels are derived from Skill (LIKELY: "Skill fills a level bar"). Level L starts at
--   SkillForLevel(L) = LevelBase * (LevelGrowth^(L-1) - 1) / (LevelGrowth - 1)
-- so each level is ~18% wider than the last. Fitted to the reference HUD: Level 50 with 25.29K
-- Skill showing "3.07K / 4.05K" (OBSERVED). At the level cap Skill from training and rings stops
-- (CONFIRMED: "the game stops raising your Skill"), so the player must rebirth.
-- Cap = 20 + 20 x rebirths (LIKELY: "Level 20 MAX LEVEL" at 0 rebirths, Level 50 = 83% at 2).
Economy.LevelCapBase = 20
Economy.LevelCapPerRebirth = 20
Economy.LevelBase = 1.2
Economy.LevelGrowth = 1.18

-- Rebirth multiplier = 1 + RebirthStep x rebirths (LIKELY: x1 at 0, x5 at 2 rebirths).
Economy.RebirthStep = 2
Economy.MaxRebirths = 1000

-- Training
Economy.TrainManualRate = 4 -- max manual reps per second accepted
-- Sources that stop paying at the level cap (purchases, gifts and codes always pay).
Economy.CappedSources = { Train = true, Ring = true }
Economy.TrainAutoInterval = 1 -- seconds between AUTO reps
Economy.TrainRepBase = 1

-- Pets
Economy.PetSlots = 3
Economy.PetSlotsPass = 2 -- extra slots with the "PetSlots" pass
Economy.PetInventory = 60
Economy.HatchMulti = 3 -- "TripleHatch" pass

-- Friend boost: +10% Skill per friend in the server, up to +50% (OBSERVED HUD "Friend Boost +0%").
Economy.FriendBoostPer = 0.1
Economy.FriendBoostMax = 0.5

-- Premium (Roblox Premium members) small perk.
Economy.PremiumSkillBonus = 0.1

Economy.Limits = {
	MaxSkill = 1e300,
	MaxWins = 1e300,
	MaxPotions = 999,
}

function Economy.LevelCap(rebirths: number): number
	return Economy.LevelCapBase + Economy.LevelCapPerRebirth * math.max(0, rebirths)
end

-- Skill at which `level` starts.
function Economy.SkillForLevel(level: number): number
	local g = Economy.LevelGrowth
	return Economy.LevelBase * (g ^ (math.max(1, level) - 1) - 1) / (g - 1)
end

-- Width of `level` in Skill (shown as the level bar's "x / y").
function Economy.XPToNext(level: number): number
	return Economy.LevelBase * Economy.LevelGrowth ^ (math.max(1, level) - 1)
end

-- Level reached with `skill` Skill, clamped to `cap`.
function Economy.LevelForSkill(skill: number, cap: number): number
	if skill <= 0 or skill ~= skill then
		return 1
	end
	local g = Economy.LevelGrowth
	local level = math.floor(math.log(skill * (g - 1) / Economy.LevelBase + 1) / math.log(g)) + 1
	-- guard against float edge cases at exact boundaries
	if Economy.SkillForLevel(level + 1) <= skill then
		level += 1
	elseif Economy.SkillForLevel(level) > skill then
		level -= 1
	end
	return math.clamp(level, 1, cap)
end

function Economy.RebirthMultiplier(rebirths: number): number
	return 1 + Economy.RebirthStep * math.max(0, rebirths)
end

return Economy
