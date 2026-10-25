--[[
	Banners
	Rates are percentages that must sum to 100 (validated by tests). Pools default to every summonable unit
	of that rarity. The Standard banner rotates its featured Mythic every hour (deterministic from UTC time),
	so every server shows the same banner and the same "Next up".
]]

local Banners = {
	Standard = {
		id = "Standard",
		name = "The Gumball Machine",
		description = "Every defender in Elmore. Featured Mythic changes every hour!",
		order = 1,
		rates = { Rare = 69.85, Epic = 25, Legendary = 4.5, Mythic = 0.6, Secret = 0.05 },
		featuredRotation = { "Nicole", "Richard", "Hector" },
		featuredShare = 0.75, -- of Mythic pulls
	},
	Spooky = {
		id = "Spooky",
		name = "Spooky Machine",
		description = "Halloween rate-up! 50% of Epic pulls are Carrie and Nicole is the featured Mythic.",
		order = 2,
		event = true,
		-- Unix seconds (UTC). Outside this window the banner is hidden and summons are rejected.
		startsAt = 1760918400, -- 2025-10-20 (kept open; tune for your season)
		endsAt = 1794268800, -- 2026-11-10
		rates = { Rare = 69.85, Epic = 25, Legendary = 4.5, Mythic = 0.6, Secret = 0.05 },
		featuredFixed = "Nicole",
		featuredShare = 0.75,
		rateUp = { Epic = { unit = "Carrie", share = 0.5 } },
		theme = "spooky",
	},
}

local ordered = {}
for _, banner in Banners do
	table.insert(ordered, banner)
end
table.sort(ordered, function(a, b)
	return a.order < b.order
end)

return {
	byId = Banners,
	ordered = ordered,
	RARITY_ORDER = { "Rare", "Epic", "Legendary", "Mythic", "Secret" },
}
