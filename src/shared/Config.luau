--!strict
-- Central tunables. Everything a designer might want to tweak lives here.

local Config = {}

Config.GameName = "Flask Fiasco"
Config.Version = "1.0.0"

-- ── Monetization (create these on the Creator Dashboard, then paste the IDs). 0 = hidden. ──
Config.GamePasses = {
	VIP = 0, -- 2x coins & XP, Gold Golem skin, gold name
	Satchel = 0, -- +2 bottles per brew
	LabExpansion = 0, -- 12 golems per lab
	MasterKey = 0, -- unlock every lab
}

Config.Products = {
	-- [productId] = reward
	-- [123456] = { coins = 500 },
	-- [123457] = { spins = 5 },
} :: { [number]: { coins: number?, spins: number? } }

-- Shown in the shop; productId must match Config.Products keys.
export type CatalogEntry = { productId: number, name: string, robux: number, coins: number?, spins: number? }

Config.ProductCatalog = {
	{ productId = 0, name = "Pouch of Coins", coins = 500, robux = 49 },
	{ productId = 0, name = "Chest of Coins", coins = 2000, robux = 149 },
	{ productId = 0, name = "Mystery Flask x5", spins = 5, robux = 99 },
} :: { CatalogEntry }

Config.BadgeIds = {
	Welcome = 0,
	FirstDiscovery = 0,
	HalfCodex = 0,
	FullCodex = 0,
	GrandAlchemist = 0,
}

-- Optional audio. Built-in rbxasset sounds are always used as fallbacks.
Config.MusicIds = {} :: { string } -- e.g. { "rbxassetid://1234567890" }

-- ── Server / labs ──
Config.MaxLabs = 6
Config.LabSpacing = 1200 -- studs between labs (along X); all labs share the Z = 0 plane
Config.DefaultMap = "lab"
Config.MaxGolems = 8
Config.MaxGolemsExpanded = 12
Config.MaxProps = 25
Config.MaxPuddles = 10
Config.MaxProjectiles = 12

-- ── Physics ──
Config.Physics = {
	Gravity = 196.2,
	MaxSpeed = 420, -- hard clamp to avoid tunneling through walls
	SlowMoScale = 0.3,
	GrabMaxForcePerMass = 2400,
	GrabResponsiveness = 45,
	GrabMaxVelocity = 320,
	FlingBoost = 1.25,
	OwnershipReturnDelay = 1.25,
	GolemDensity = 1.0,
	JointFrictionPerMass = 26, -- motor friction torque per unit golem mass
	UprightTorquePerMass = 900,
	LegServoTorquePerMass = 520,
	ArmServoTorquePerMass = 60,
	ImpactThreshold = 30, -- Δv (studs/s) before damage starts
	ImpactDamageScale = 0.55,
	KnockdownThreshold = 38,
	StunTime = 1.6,
	GetUpTime = 0.7,
}

Config.Golem = {
	MaxHealth = 100,
	Height = 8.2,
}

-- ── Potions ──
Config.Potions = {
	BottlesPerBrew = 3,
	SatchelBonus = 2,
	MasteryBrews = 5, -- brews needed for ∞ uses
	MasteryPotency = 1.25,
	FeedDurationMultiplier = 1.5,
	ThrowCooldown = 0.22,
	SplashRadius = 11,
	PuddleLifetime = 14,
}

-- ── Economy ──
Config.Economy = {
	StartingCoins = 150,
	ChaosPerCoin = 40,
	ChaosPerXp = 100,
	ChaosAttributionWindow = 12, -- seconds after a player's action that chaos still counts
	ChaosPerMinuteCap = 6000,
	ComboWindow = 3,
	ComboMax = 5,
	ComboStep = 400, -- chaos needed per combo level
	VipMultiplier = 2,
	RackRegrowSeconds = 240,
	RackCapacity = 6,
	GoldShatterCoins = 15,
	LevelUpCoinsPerLevel = 20,
	MaxLevel = 50,
}

Config.StartingIngredients = {
	ember_root = 4,
	frost_lotus = 4,
	gale_feather = 4,
	slime_gel = 4,
	moon_dew = 2,
}

Config.Ranks = {
	{ level = 1, name = "Apprentice" },
	{ level = 5, name = "Brewer" },
	{ level = 10, name = "Alchemist" },
	{ level = 15, name = "Adept" },
	{ level = 20, name = "Master Alchemist" },
	{ level = 30, name = "Archmage" },
	{ level = 40, name = "Grand Alchemist" },
}

Config.DailyStreakRewards = {
	{ coins = 100 },
	{ coins = 150, ingredients = { moon_dew = 2 } },
	{ coins = 200, ingredients = { boom_spore = 2 } },
	{ coins = 250, spins = 1 },
	{ coins = 300, ingredients = { pixie_dust = 2 } },
	{ coins = 400, ingredients = { storm_moss = 3 } },
	{ coins = 500, spins = 2, ingredients = { void_salt = 1 } },
}

Config.TrialStarsForMagnumOpus = 20

function Config.xpForLevel(level: number): number
	-- XP required to go from `level` to `level + 1`.
	return math.floor(100 + 55 * (level - 1) ^ 1.3)
end

function Config.rankForLevel(level: number): string
	local name = Config.Ranks[1].name
	for _, rank in Config.Ranks do
		if level >= rank.level then
			name = rank.name
		end
	end
	return name
end

return Config
