--!strict
-- Redeemable codes (server only, so they cannot be data-mined from the client).
-- Expires is unix seconds or nil. Codes are case-insensitive.
export type Code = {
	Code: string,
	Coins: number?,
	Gems: number?,
	Ticket: string?,
	Expires: number?,
}

return {
	{ Code = "LAUNCH", Coins = 150 },
	{ Code = "ORBCLASH", Coins = 100 },
	{ Code = "FIRSTORB", Ticket = "OrbGacha" },
	{ Code = "HARVEST", Gems = 15, Expires = 1793491200 },
} :: { Code }
