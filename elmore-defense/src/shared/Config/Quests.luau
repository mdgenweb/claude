--[[
	Quests, Daily login calendar, Yearbook milestones.
	Quest stats are incremented through ProgressionService.track(player, stat, amount).
]]

local Quests = {}

Quests.Stats = {
	Wins = "Win matches",
	Kills = "Defeat enemies",
	Summons = "Summon units",
	Upgrades = "Upgrade units in matches",
	TraitRolls = "Reroll traits",
	GradeRolls = "Reroll grades",
	Waves = "Clear waves",
	BossKills = "Defeat bosses",
	Placements = "Place units",
	ChallengeWins = "Win challenges",
}

-- Pools; 3 daily + 3 weekly are picked deterministically from the date so everyone shares them.
Quests.DailyPool = {
	{ id = "d_wins", stat = "Wins", goal = 3, reward = { Gumballs = 150, PassXp = 150 } },
	{ id = "d_kills", stat = "Kills", goal = 400, reward = { Gumballs = 120, PassXp = 120 } },
	{ id = "d_summons", stat = "Summons", goal = 10, reward = { VoidShards = 1, PassXp = 100 } },
	{ id = "d_upgrades", stat = "Upgrades", goal = 25, reward = { Gumballs = 100, PassXp = 100 } },
	{ id = "d_waves", stat = "Waves", goal = 40, reward = { ReportCards = 1, PassXp = 120 } },
	{ id = "d_boss", stat = "BossKills", goal = 2, reward = { Gumballs = 150, PassXp = 150 } },
	{ id = "d_place", stat = "Placements", goal = 30, reward = { Gumballs = 80, PassXp = 80 } },
}

Quests.WeeklyPool = {
	{ id = "w_wins", stat = "Wins", goal = 25, reward = { Gumballs = 900, PassXp = 800 } },
	{ id = "w_kills", stat = "Kills", goal = 5000, reward = { VoidShards = 5, PassXp = 700 } },
	{ id = "w_summons", stat = "Summons", goal = 80, reward = { ReportCards = 5, PassXp = 600 } },
	{ id = "w_challenge", stat = "ChallengeWins", goal = 8, reward = { VoidCores = 1, PassXp = 800 } },
	{ id = "w_traits", stat = "TraitRolls", goal = 20, reward = { Gumballs = 600, PassXp = 500 } },
}

Quests.DailyCount = 3
Quests.WeeklyCount = 3

-- 7-day login calendar. Missing a day resets to day 1.
Quests.DailyLogin = {
	{ Gumballs = 100 },
	{ Gumballs = 150 },
	{ VoidShards = 2 },
	{ Gumballs = 250 },
	{ ReportCards = 3 },
	{ Gumballs = 400 },
	{ Gumballs = 750, VoidShards = 5 },
}

-- Yearbook completion milestones (count of unique units discovered).
Quests.YearbookMilestones = {
	{ count = 5, reward = { Gumballs = 300 } },
	{ count = 10, reward = { VoidShards = 5 } },
	{ count = 15, reward = { Gumballs = 1500, ReportCards = 5 } },
	{ count = 20, reward = { VoidShards = 15, StickerPages = 2 } },
}

return Quests
