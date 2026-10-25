--[[
	BattlePass ("Elmore Pass")
	Season 1: "Halloweenie". 50 levels, free + premium tracks.
	Reward shape: { kind = "Item", id = "Gumballs", amount = 150 } or { kind = "Unit", id = "PumpkinDarwin", shiny = bool }
]]

local LEVELS = 50
local XP_PER_LEVEL = 500

local function item(id: string, amount: number)
	return { kind = "Item", id = id, amount = amount }
end

local function unit(id: string, shiny: boolean?)
	return { kind = "Unit", id = id, shiny = shiny == true }
end

local free = {}
local premium = {}

for level = 1, LEVELS do
	-- Free track: small but steady, a spike every 5 levels.
	if level % 10 == 0 then
		free[level] = item("VoidShards", 3)
	elseif level % 5 == 0 then
		free[level] = item("ReportCards", 2)
	elseif level % 3 == 0 then
		free[level] = item("JoyfulCoupons", 2)
	else
		free[level] = item("Gumballs", 100 + level * 5)
	end
	-- Premium track: roughly 4x value per level.
	if level % 10 == 0 then
		premium[level] = item("VoidShards", 10)
	elseif level % 5 == 0 then
		premium[level] = item("VoidCores", 1)
	elseif level % 4 == 0 then
		premium[level] = item("RainbowSprinkles", 4)
	elseif level % 3 == 0 then
		premium[level] = item("ReportCards", 3)
	else
		premium[level] = item("Gumballs", 300 + level * 15)
	end
end

-- Headline rewards
premium[1] = item("Gumballs", 5000)
free[25] = item("StickerPages", 1)
premium[25] = item("StickerPages", 3)
free[LEVELS] = unit("PumpkinDarwin", false)
premium[LEVELS] = unit("VampireGumball", true)

return {
	seasonId = "S1",
	name = "Halloweenie",
	levels = LEVELS,
	xpPerLevel = XP_PER_LEVEL,
	endsAt = 1794268800, -- 2026-11-10 UTC
	free = free,
	premium = premium,
	headline = {
		free = "PumpkinDarwin",
		premium = "VampireGumball",
	},
}
