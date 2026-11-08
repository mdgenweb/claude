--!strict
-- Redeemable codes (server-only so unreleased codes stay secret). Keys are matched case-insensitively.
-- Ship new codes on milestones ("1KLIKES", "1MVISITS"...) and announce them in the game description.

export type CodeReward = {
	coins: number?,
	spins: number?,
	ingredients: { [string]: number }?,
	skin: string?,
	expires: number?, -- os.time() after which the code stops working
}

local Codes: { [string]: CodeReward } = {
	FIRSTBREW = { coins = 150, ingredients = { ember_root = 3, frost_lotus = 3 } },
	KABOOM = { spins = 1, ingredients = { boom_spore = 3 } },
	BUBBLES = { coins = 200, ingredients = { slime_gel = 4, moon_dew = 2 } },
	GOLEMGANG = { skin = "moss", coins = 100 },
	STORMY = { ingredients = { storm_moss = 3, gale_feather = 3 } },
}

return Codes
