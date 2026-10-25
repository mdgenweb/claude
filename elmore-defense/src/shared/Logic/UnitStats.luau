--[[
	UnitStats
	The single formula that turns (unit def + owned instance + in-match level + auras) into combat numbers.
	Used by the server simulation and by every UI that previews stats, so the UI never lies.

	instance = { id, level, trait, grades = { Damage, Range, SPA }, shiny }
	auras    = { damage, speed, range } (fractions, already resolved to max-per-stat by the caller)
]]

local Shared = script.Parent.Parent
local Units = require(Shared.Config.Units)
local Traits = require(Shared.Config.Traits)
local Grades = require(Shared.Config.Grades)
local GameConfig = require(Shared.Config.GameConfig)

local UnitStats = {}

export type Stats = {
	damage: number,
	range: number,
	cooldown: number,
	dps: number,
	move: any,
	moveKey: string?,
	detect: boolean,
	bountyMult: number,
	stunChance: number,
	stunTime: number,
	aura: any,
	income: number,
}

local function traitMods(instance)
	local trait = Traits.get(instance and instance.trait)
	return if trait then trait.mods else {}
end

-- Cost of the tier at `level` (0 = placement) after trait discounts.
function UnitStats.tierCost(instance, level: number): number
	local unit = Units.get(instance.id)
	local tier = unit and unit.tiers[level + 1]
	if not tier then
		return math.huge
	end
	local discount = traitMods(instance).cost or 0
	return math.floor(tier.cost * (1 - discount) + 0.5)
end

function UnitStats.placementCost(instance): number
	return UnitStats.tierCost(instance, 0)
end

-- Total cash invested to reach `level` (used for selling refunds).
function UnitStats.totalInvested(instance, level: number): number
	local total = 0
	for index = 0, level do
		total += UnitStats.tierCost(instance, index)
	end
	return total
end

function UnitStats.compute(instance, level: number, auras: { [string]: number }?): Stats
	local unit = Units.get(instance.id)
	assert(unit, "Unknown unit " .. tostring(instance.id))
	level = math.clamp(level, 0, #unit.tiers - 1)
	local tier = unit.tiers[level + 1]
	local mods = traitMods(instance)
	local grades = instance.grades or {}
	auras = auras or {}

	local accountLevel = math.max(1, instance.level or 1)
	local levelBonus = 1 + GameConfig.Units.DamagePerLevel * (accountLevel - 1)
	local shinyBonus = if instance.shiny then 1 + GameConfig.Units.ShinyDamageBonus else 1

	local damage = tier.damage
		* Grades.multiplier(grades.Damage)
		* (1 + (mods.damage or 0))
		* levelBonus
		* shinyBonus
		* (1 + ((auras :: any).damage or 0))

	local rangeGrade = 1 + 0.5 * (Grades.multiplier(grades.Range) - 1)
	local range = tier.range * rangeGrade * (1 + (mods.range or 0)) * (1 + ((auras :: any).range or 0))

	local speed = Grades.multiplier(grades.SPA) * (1 + (mods.speed or 0)) * (1 + ((auras :: any).speed or 0))
	local cooldown = tier.cooldown / speed

	local move, moveKey = Units.moveAt(unit, level)

	return {
		damage = damage,
		range = range,
		cooldown = cooldown,
		dps = damage / cooldown,
		move = move,
		moveKey = moveKey,
		detect = unit.detect == true or mods.detect == true,
		bountyMult = 1 + (mods.bounty or 0),
		stunChance = mods.stunChance or 0,
		stunTime = mods.stunTime or 0,
		aura = Units.auraAt(unit, level),
		income = tier.income or 0,
	}
end

-- Lobby "power" number shown on cards: max-tier DPS with the instance's bonuses.
function UnitStats.power(instance): number
	local unit = Units.get(instance.id)
	if not unit then
		return 0
	end
	local stats = UnitStats.compute(instance, #unit.tiers - 1)
	return math.floor(stats.dps * 10 + stats.range * 5)
end

return UnitStats
