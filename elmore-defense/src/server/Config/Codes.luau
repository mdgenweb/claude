--[[
	Codes (server-only so clients can't datamine them)
	Keys are matched case-insensitively. `expires` is a Unix timestamp (optional).
	Add milestone codes as the game grows: THANKSFOR1KLIKES, THANKSFOR500CCU, SORRYFORBUGS ...
]]

return {
	RELEASE = { reward = { Gumballs = 500, VoidShards = 5 } },
	DUDE = { reward = { Gumballs = 250 } },
	WHATTHEWHAT = { reward = { VoidShards = 3, ReportCards = 3 } },
	AMAZING = { reward = { Gumballs = 300, RainbowSprinkles = 3 } },
	HALLOWEENIE = { reward = { Gumballs = 400, JoyfulCoupons = 5 }, expires = 1794268800 },
}
