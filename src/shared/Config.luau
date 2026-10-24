--!strict
-- Every tunable number for Pick Your Mech! lives here. Values come straight from the
-- concept document (Oct 2026) and are starting proposals to playtest, not final tuning.

local Config = {}

Config.GameName = "Pick Your Mech!"
Config.Tagline = "Start tiny. Smash junk. Build a giant."

-- Combat: one hit every 0.5 s for current Power damage, first hit lands after one interval.
Config.Combat = {
	HitInterval = 0.5,
	Reach = 6.5, -- studs from the mech's root to the target's nearest surface (kept stable as the mech grows)
	TickRate = 0.1, -- server combat loop granularity
}

export type Area = {
	Id: string,
	Name: string,
	HP: number,
	Scrap: number,
	GatePower: number,
	GateScrap: number,
	Respawn: number,
	Blurb: string,
}

Config.Areas = {
	{
		Id = "Starter",
		Name = "Starter Yard",
		HP = 10,
		Scrap = 4,
		GatePower = 0,
		GateScrap = 0,
		Respawn = 3,
		Blurb = "Small scrap",
	},
	{
		Id = "Appliance",
		Name = "Appliance Row",
		HP = 100,
		Scrap = 40,
		GatePower = 10,
		GateScrap = 100,
		Respawn = 4,
		Blurb = "Washers & fridges",
	},
	{
		Id = "Crusher",
		Name = "Crusher Yard",
		HP = 1000,
		Scrap = 250,
		GatePower = 250,
		GateScrap = 1000,
		Respawn = 5,
		Blurb = "Big scrap & ore",
	},
} :: { Area }

export type Upgrade = { Power: number, Cost: number, Milestone: string }

-- Index = upgrade level reached. Level 0 (no upgrades) is Power 1.
Config.StartPower = 1
Config.Upgrades = {
	{ Power = 2, Cost = 5, Milestone = "Stronger hit effect" },
	{ Power = 5, Cost = 20, Milestone = "Larger forearms" },
	{ Power = 10, Cost = 60, Milestone = "Larger tool" },
	{ Power = 25, Cost = 150, Milestone = "Crusher form" },
	{ Power = 50, Cost = 400, Milestone = "Broader shoulders" },
	{ Power = 100, Cost = 1000, Milestone = "Larger upper body" },
	{ Power = 250, Cost = 2500, Milestone = "Mega Mech form" },
	{ Power = 500, Cost = 6000, Milestone = "Larger tool & reactor" },
	{ Power = 1000, Cost = 15000, Milestone = "Final giant silhouette" },
} :: { Upgrade }

Config.Forms = {
	{ Id = "ScrapBot", Name = "Scrap Bot", FromLevel = 0 },
	{ Id = "Crusher", Name = "Crusher", FromLevel = 4 },
	{ Id = "MegaMech", Name = "Mega Mech", FromLevel = 7 },
}

-- Whole-body scale per upgrade level 0..9. Most growth is visual armor; the body itself
-- grows modestly so reach, collisions and the camera stay comfortable.
Config.BodyScale = {
	[0] = 1,
	[1] = 1,
	[2] = 1,
	[3] = 1.05,
	[4] = 1.2,
	[5] = 1.25,
	[6] = 1.3,
	[7] = 1.45,
	[8] = 1.5,
	[9] = 1.65,
} :: { [number]: number }

Config.Rebirth = {
	RequiredLevel = 9, -- Power 1,000
	RequiredCrusherDestroys = 20,
	Fees = { 10000, 20000, 40000, 80000, 160000 },
	BonusPerRebirth = 0.25, -- cumulative base-Scrap bonus per milestone
}

Config.Workshop = { RatePerHour = 40, Cap = 240 }
Config.Daily = { Goal = 30, RewardScrap = 100, StampsForFinish = 5 }
Config.Boost = { SecondsPerCharge = 600, Multiplier = 2 }
Config.DoubleScrapMultiplier = 2

Config.WorkerShellCraftCost = 500
Config.StarterPackScrap = 250
Config.ScrapPackAmount = 600

Config.Tools = {
	{ Id = "Hammer", Name = "Hammer", Blurb = "Big swings. Big dents." },
	{ Id = "Saw", Name = "Saw", Blurb = "Sparks on every cut." },
	{ Id = "Drill", Name = "Drill", Blurb = "Spins right through." },
}

-- Cosmetic finishes. None of them change stats.
Config.Finishes = {
	{ Id = "Default", Name = "Factory", HowToGet = "Free" },
	{ Id = "Worker", Name = "Worker Shell", HowToGet = "Craft for 500 Scrap or Starter Pack" },
	{ Id = "Lime", Name = "Lime Paint", HowToGet = "Lime Paint pass" },
	{ Id = "Chrome", Name = "Stamped Chrome", HowToGet = "Collect 5 daily stamps" },
	{ Id = "Foundry", Name = "Foundry", HowToGet = "Foundry VIP pass" },
}

-- Monetization. Create the passes/products in the Creator Dashboard and paste the IDs.
-- Prices are the concept's proposed defaults; the live UI shows the player's real price.
export type Offer = {
	Key: string,
	Kind: "Pass" | "Product",
	Id: number,
	Price: number,
	Name: string,
	Benefit: string,
	Icon: string,
	Color: string,
}

Config.Offers = {
	{
		Key = "DoubleScrap",
		Kind = "Pass",
		Id = 0,
		Price = 49,
		Name = "Double Scrap",
		Benefit = "Permanent 2x Scrap from every smash.",
		Icon = "⚙️",
		Color = "Green",
	},
	{
		Key = "ScrapBoost",
		Kind = "Product",
		Id = 0,
		Price = 19,
		Name = "Scrap Boost",
		Benefit = "1 charge: 2x smash Scrap for 10 min of yard time.",
		Icon = "🚀",
		Color = "Orange",
	},
	{
		Key = "AutoFarm",
		Kind = "Pass",
		Id = 0,
		Price = 79,
		Name = "Auto Farm",
		Benefit = "Your mech walks to the next junk in your lane.",
		Icon = "🤖",
		Color = "Blue",
	},
	{
		Key = "FoundryVIP",
		Kind = "Pass",
		Id = 0,
		Price = 99,
		Name = "Foundry VIP",
		Benefit = "Molten Foundry finish, [VIP] chat tag, gold lane sign.",
		Icon = "👑",
		Color = "Purple",
	},
	{
		Key = "WorkerStarter",
		Kind = "Pass",
		Id = 0,
		Price = 19,
		Name = "Worker Starter Pack",
		Benefit = "Worker Shell finish + 250 Scrap once.",
		Icon = "🦺",
		Color = "Yellow",
	},
	{
		Key = "LimePaint",
		Kind = "Pass",
		Id = 0,
		Price = 9,
		Name = "Lime Paint",
		Benefit = "Permanent Lime finish. Looks only.",
		Icon = "🎨",
		Color = "Lime",
	},
	{
		Key = "Scrap600",
		Kind = "Product",
		Id = 0,
		Price = 29,
		Name = "600 Scrap",
		Benefit = "Exactly 600 Scrap. Never multiplied.",
		Icon = "🔩",
		Color = "Yellow",
	},
} :: { Offer }

-- In Studio, offers whose Id is still 0 are granted for free so every flow can be tested.
Config.StudioTestPurchases = true

-- Badge IDs (0 = not created yet, skipped).
Config.Badges = {
	FirstSmash = 0,
	CrusherForm = 0,
	MegaMech = 0,
	Rebirth = { 0, 0, 0, 0, 0 },
}

-- Sound asset IDs. Built-in sounds are used until you swap in library sounds you like.
Config.Sounds = {
	Swing = "rbxasset://sounds/swordslash.wav",
	Hit = "rbxasset://sounds/swordlunge.wav",
	Break = "rbxasset://sounds/collide.wav",
	Coin = "rbxasset://sounds/electronicpingshort.wav",
	Click = "rbxasset://sounds/electronicpingshort.wav",
	Upgrade = "rbxasset://sounds/electronicpingshort.wav",
}

Config.DataStoreName = "PickYourMech_v1"
Config.AutosaveSeconds = 60

return Config
