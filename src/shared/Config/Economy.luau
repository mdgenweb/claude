--!strict
-- Every economy number lives here. Values from the reference screenshots are marked
-- CONFIRMED; everything else is (TUNABLE). Crate prices/odds live in Definitions/GachaDefinitions.
local Economy = {}

Economy.Starting = {
	Coins = 100,
	Gems = 0,
	Balls = { "bumper", "thorn" }, -- starter collection
	Explosions = { "classic" },
	Flyers = { "basic" },
}

Economy.MatchRewards = {
	Win = { Coins = 100, XP = 15 }, -- Coins CONFIRMED ("Win 100" on pads)
	Loss = { Coins = 20, XP = 10 }, -- Coins LIKELY (guides)
	ForfeitWin = { Coins = 100, XP = 15 },
}

-- XP needed to go from `level` to `level + 1`. Reference shows "Lv 2 ... 10 / 40" → 20 * level.
function Economy.XPToNext(level: number): number
	return 20 * level
end

Economy.MaxLevel = 200

-- First completed battle grants a ticket (CONFIRMED: "You got a Ball Gacha for finishing your first battle").
Economy.FirstBattleTicket = "OrbGacha"

-- Like + Join Group reward (CONFIRMED: "Advanced Ball Gacha +1" sign in the lobby).
Economy.Group = {
	Id = 0, -- set to your Roblox group id. 0 = no group configured (claimable in Studio only).
	RewardTicket = "AdvancedOrbGacha",
}

-- Gem packs sold through the "+" button. Set ProductId to your developer product ids.
-- ProductId = 0 → the pack is only purchasable as a free test grant inside Studio.
Economy.GemProducts = {
	{ Key = "Gems100", ProductId = 0, Gems = 100, Robux = 99, Badge = nil :: string? },
	{ Key = "Gems550", ProductId = 0, Gems = 550, Robux = 449, Badge = "+10%" :: string? },
	{ Key = "Gems1200", ProductId = 0, Gems = 1200, Robux = 899, Badge = "+20%" :: string? },
	{ Key = "Gems3000", ProductId = 0, Gems = 3000, Robux = 1999, Badge = "BEST" :: string? },
}

Economy.Limits = {
	MaxCoins = 1e12,
	MaxGems = 1e9,
	MaxItemCount = 9999,
	MaxBulkOpen = 10,
}

-- Weekly leaderboard reward for top 3 of the previous week (paid on next join).
Economy.WeeklyRewards = {
	[1] = { Ticket = "AdvancedOrbGacha", Count = 3 },
	[2] = { Ticket = "AdvancedOrbGacha", Count = 2 },
	[3] = { Ticket = "AdvancedOrbGacha", Count = 1 },
}

return Economy
