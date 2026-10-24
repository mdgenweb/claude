-- All player-facing UI wording in one place (see docs/DESIGN_SYSTEM.md, "UX copy").
-- Terms are fixed: Scrap (currency), Power (stat), smash (the action), junk (targets),
-- yard (area), lane (your strip). Buttons start with a verb and stay 1-2 words.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Economy = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Economy"))

local Copy = {
	Nav = {
		Shop = "SHOP",
		Upgrade = "UPGRADE",
		Rebirth = "REBIRTH",
		Garage = "GARAGE",
		Daily = "DAILY",
	},
	Hud = {
		Power = "POWER",
		NextUpgrade = "NEXT UPGRADE",
		UpgradeButton = "UPGRADE",
		MaxPower = "MAX POWER!",
		MaxPowerSub = string.format(
			"Rebirth for +%d%% Scrap forever",
			math.floor(Config.Rebirth.BonusPerRebirth * 100 + 0.5)
		),
		SmashTitle = "SMASH THE JUNK!",
		SmashSub = "Walk up to junk in your lane. Your mech hits it for you.",
		Boost = "BOOST",
		BoostNone = "GET",
		Auto = "AUTO",
		On = "ON",
		Off = "OFF",
		Loading = "Loading your mech...",
		MemoryWarning = "Studio: progress won't save (no API access)",
	},
	Goal = {
		Gate = "🔒 %s: ⚡%s + %s Scrap",
		Rebirth = "♻️ Rebirth: smash %d/%d in Crusher Yard",
		RebirthReady = "♻️ Rebirth ready! Visit the Rebirth Pad",
		RebirthFee = "♻️ Rebirth: save %s Scrap",
		AllDone = "🏆 Every rebirth done. You're a legend!",
	},
	Upgrade = {
		Title = "UPGRADES",
		Owned = "OWNED",
		Buy = "BUY",
		NewForm = "NEW FORM",
		Current = "YOUR MECH",
	},
	Shop = {
		Title = "SHOP",
		Owned = "OWNED",
		Buy = "BUY",
		StudioNote = "Studio test mode: offers without an ID are free so you can test them.",
		StarterOwnedShell = "You already own the shell, so this adds 250 Scrap once.",
		BoostHave = "You have %d",
		Featured = "x1 → x2",
	},
	Rebirth = {
		Title = "REBIRTH",
		Resets = "RESETS",
		Keeps = "YOU KEEP",
		ResetList = { "Power back to 1", "Gates lock again", "Crusher smash count" },
		KeepList = { "Leftover Scrap", "Tools & finishes", "Passes & boosts" },
		NeedPower = "Reach Power " .. Economy.format(Economy.powerForLevel(Config.Rebirth.RequiredLevel)),
		NeedSmashes = "Smash %d/%d in Crusher Yard",
		NeedFee = "Have %s Scrap",
		Button = "REBIRTH",
		Confirm = "TAP AGAIN TO CONFIRM",
		Maxed = "ALL DONE!",
		Bonus = "Scrap bonus",
	},
	Garage = {
		Title = "GARAGE",
		Tools = "TOOLS",
		ToolsSub = "Same damage and reach. Pick your style!",
		Finishes = "FINISHES",
		Equip = "EQUIP",
		Equipped = "EQUIPPED",
		Craft = "CRAFT",
		Get = "GET",
		Locked = "LOCKED",
	},
	Daily = {
		Title = "REWARDS",
		Contract = "DAILY CONTRACT",
		ContractTask = "Smash %d junk today",
		ContractReward = string.format("🎁 %d Scrap + 1 stamp", Config.Daily.RewardScrap),
		Stamps = "Stamps: %d/%d · " .. Config.Daily.StampsForFinish .. " unlock Stamped Chrome",
		Claim = "CLAIM",
		Claimed = "DONE TODAY",
		Workshop = "WORKSHOP",
		WorkshopRate = string.format("+%d Scrap an hour, even while you're away", Config.Workshop.RatePerHour),
		WorkshopFull = "Full! Claim it before it stops filling.",
		WorkshopTime = "Full in %s",
	},
	Gate = {
		Title = "UNLOCK %s",
		NeedPower = "⚡ Power %s",
		NeedScrap = "⚙️ %s Scrap",
		NeedPrevious = "Unlock Appliance Row first",
		Button = "UNLOCK",
	},
	Picker = {
		Title = "PICK YOUR MECH!",
		Sub = "Choose a free tool. Same damage and reach, so pick the style you like!",
		Button = "PICK",
	},
}

return Copy
