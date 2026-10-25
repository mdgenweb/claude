--[[
	GameConfig
	Global tuning knobs. Everything a designer is likely to tweak lives here or in the sibling config modules.
]]

local GameConfig = {
	GameName = "Elmore Defense",
	Tagline = "A Wonderfully Weird Tower Defense",
	DataStoreName = "ElmoreDefense_Profiles_v1",
	LeaderboardStoreName = "ElmoreDefense_InfiniteBest_v1",

	-- Studio/testing conveniences
	Dev = {
		-- In Studio, purchases with unconfigured (0) ids are granted instantly so every flow is testable.
		GrantUnconfiguredPurchasesInStudio = true,
		-- Studio-only chat commands (/give, /win, /cash ...). Never active in live servers.
		EnableStudioCommands = true,
		-- Extra user ids allowed to use dev commands in live servers (keep empty for release).
		AdminUserIds = {} :: { number },
	},

	Starting = {
		Gumballs = 1000,
		VoidShards = 3,
		ReportCards = 3,
		StarterUnits = { "Gumball", "Darwin" },
	},

	Inventory = {
		BaseCapacity = 150,
		BigBackpackCapacity = 300,
		TeamSize = 6,
	},

	Summon = {
		SingleCost = 50,
		TenCost = 450, -- 10 pulls for the price of 9
		VipDiscount = 0.2,
		LegendaryPity = 50, -- Legendary-or-better guaranteed within this many pulls
		MythicPity = 400, -- Mythic-or-better guaranteed within this many pulls
		FeaturedShare = 0.75, -- share of Mythic pulls that land on the featured Mythic
		ShinyChance = 1 / 80,
		AutoDeleteRefund = { Rare = 3, Epic = 8, Legendary = 40 },
		BannerRotationSeconds = 3600,
	},

	Traits = {
		RerollCost = 1, -- Void Shards
		MaxAutoRolls = 100,
	},

	Grades = {
		RerollCost = 1, -- Report Cards
		LockedRerollCost = 2,
	},

	Units = {
		MaxLevel = 50,
		DamagePerLevel = 0.02,
		ShinyDamageBonus = 0.05,
		ReleaseRefund = { Rare = 2, Epic = 6, Legendary = 30, Mythic = 150, Secret = 500 },
	},

	Match = {
		MaxPlayers = 4,
		StartCash = 600,
		BaseHealth = 100,
		PrepSeconds = 15,
		IntermissionSeconds = 6,
		WaveBonusBase = 100,
		WaveBonusPerWave = 25,
		SkipBonus = 50,
		SellRefund = 0.6,
		MaxUnitsPerPlayer = 18,
		PlacementRadius = 1.6, -- units can't overlap closer than 2x this
		PathClearance = 3.2, -- distance from path centre where placement is blocked
		SnapshotRate = 10, -- Hz
		ResultReturnSeconds = 25,
		PartyCountdown = 20,
		ArenaSpacing = 900, -- studs between concurrent arenas
		ArenaOrigin = Vector3.new(0, 0, 1200),
		Speeds = { 1, 2, 3 }, -- 3x requires the ThreeXSpeed pass
	},

	Rewards = {
		WinGumballsByWorld = { 60, 80, 100, 120, 150 },
		FirstClearMultiplier = 2,
		LossGumballFraction = 0.25, -- partial reward when you lose, scaled by waves survived
		PlayerXpPerWin = 60,
		PlayerXpPerLoss = 20,
		UnitXpPerWave = 4,
		PassXpPerWin = 120,
		PassXpPerLoss = 35,
		PassXpPerKill = 0.2,
		InfiniteGumballsPer5Waves = 25,
		ChallengeGumballs = 120,
		ItemDropChance = 0.35, -- chance per win to drop a bonus Void Shard / Report Card
	},

	Lobby = {
		Origin = Vector3.new(0, 0, 0),
		SpawnOffset = Vector3.new(0, 4, 38),
	},
}

return GameConfig
