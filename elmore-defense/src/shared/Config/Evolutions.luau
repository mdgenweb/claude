--[[
	Evolutions ("Glow-Ups")
	The evolved unit keeps level, trait, grades and shiny status (protects player investment).
]]

local Evolutions = {
	Gumball = {
		to = "GumballPrime",
		level = 15,
		gumballs = 1500,
		items = { JoyfulCoupons = 20, RainbowSprinkles = 10 },
	},
	Darwin = {
		to = "MechaDarwin",
		level = 15,
		gumballs = 1500,
		items = { JoyfulCoupons = 20, VoidCores = 2 },
	},
	Anais = {
		to = "ProfessorAnais",
		level = 20,
		gumballs = 2500,
		items = { RainbowSprinkles = 25, VoidCores = 3 },
	},
	Nicole = {
		to = "NicoleUnleashed",
		level = 30,
		gumballs = 5000,
		items = { StickerPages = 10, VoidCores = 5 },
	},
}

return Evolutions
