--[[
	Enemies
	Things that escaped from the Void. Base numbers are for World 1 / Act 1 / Wave 1;
	WaveGen applies world, act and wave scaling.

	look.archetype: blob, static, sock, bat, splitter, golem, ghost, bug, knight, plus boss looks
	abilities (bosses):
		stunPulse { interval, radius, duration }  stuns placed units near the boss
		summon    { interval, enemy, count }      spawns minions at the boss position
		shield    { interval, duration }          immune to damage while active
		enrage    { threshold, speedMult }        speeds up below hp threshold
	heal (support enemies): { interval, radius, amount = fraction of max hp }
]]

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local Enemies = {
	Glitchling = {
		name = "Glitchling",
		description = "A pixel blob that slipped out of the Void.",
		hp = 40,
		speed = 5.5,
		armor = 0,
		bounty = 6,
		leak = 4,
		size = 1,
		look = { archetype = "blob", color = rgb(150, 90, 230), accent = rgb(80, 255, 200) },
	},
	StaticBlob = {
		name = "Static Blob",
		description = "Pure TV static. Fast and fragile.",
		hp = 28,
		speed = 8.5,
		armor = 0,
		bounty = 6,
		leak = 4,
		size = 0.85,
		look = { archetype = "static", color = rgb(200, 200, 210), accent = rgb(90, 90, 100) },
	},
	LostSock = {
		name = "Lost Sock",
		description = "The Void keeps every sock you ever lost. They want revenge.",
		hp = 90,
		speed = 4.2,
		armor = 0,
		bounty = 10,
		leak = 6,
		size = 1.1,
		look = { archetype = "sock", color = rgb(255, 255, 255), accent = rgb(255, 80, 90) },
	},
	PixelBat = {
		name = "Pixel Bat",
		description = "8-bit and very, very fast.",
		hp = 24,
		speed = 11,
		armor = 0,
		bounty = 7,
		leak = 4,
		size = 0.8,
		look = { archetype = "bat", color = rgb(60, 40, 90), accent = rgb(255, 60, 120) },
	},
	Splitter = {
		name = "Splitter",
		description = "Splits into two Glitchlings when popped.",
		hp = 70,
		speed = 5,
		armor = 0,
		bounty = 9,
		leak = 6,
		size = 1.15,
		splitInto = { enemy = "Glitchling", count = 2 },
		look = { archetype = "splitter", color = rgb(255, 120, 200), accent = rgb(150, 90, 230) },
	},
	FloppyGolem = {
		name = "Floppy Golem",
		description = "Obsolete tech stacked into a tank. Armoured.",
		hp = 200,
		speed = 3.6,
		armor = 0.35,
		bounty = 18,
		leak = 10,
		size = 1.5,
		look = { archetype = "golem", color = rgb(60, 70, 90), accent = rgb(220, 220, 230) },
	},
	GhostPixel = {
		name = "Ghost Pixel",
		description = "Hidden. Only detectors (Bobert, Carrie, Hall Monitor) can hit it.",
		hp = 60,
		speed = 6.5,
		armor = 0,
		bounty = 12,
		leak = 6,
		size = 1,
		hidden = true,
		look = { archetype = "ghost", color = rgb(210, 230, 255), accent = rgb(120, 200, 255) },
	},
	HealerBug = {
		name = "Healer Bug",
		description = "Patches up nearby glitches. Kill it first!",
		hp = 110,
		speed = 5,
		armor = 0,
		bounty = 14,
		leak = 6,
		size = 1,
		heal = { interval = 1.5, radius = 9, amount = 0.04 },
		look = { archetype = "bug", color = rgb(90, 220, 120), accent = rgb(255, 255, 255) },
	},
	VoidKnight = {
		name = "Void Knight",
		description = "Armoured and quick. The Void's elite guard.",
		hp = 320,
		speed = 6.5,
		armor = 0.3,
		bounty = 24,
		leak = 12,
		size = 1.35,
		look = { archetype = "knight", color = rgb(40, 20, 70), accent = rgb(200, 90, 255) },
	},

	-- Bosses ---------------------------------------------------------------------------------
	HallMonster = {
		name = "The Hall Monster",
		description = "A haunted locker that ate the hall passes.",
		hp = 3200,
		speed = 2.8,
		armor = 0.1,
		bounty = 300,
		leak = 100,
		size = 3,
		boss = true,
		abilities = { { type = "stunPulse", interval = 9, radius = 14, duration = 2 } },
		look = { archetype = "locker", color = rgb(70, 130, 200), accent = rgb(255, 230, 80) },
	},
	GnomeKing = {
		name = "Gnome King",
		description = "Rules every lawn on Watterson Street.",
		hp = 3600,
		speed = 3.0,
		armor = 0.1,
		bounty = 350,
		leak = 100,
		size = 2.8,
		boss = true,
		abilities = {
			{ type = "summon", interval = 8, enemy = "Glitchling", count = 4 },
			{ type = "enrage", threshold = 0.3, speedMult = 1.6 },
		},
		look = { archetype = "gnome", color = rgb(220, 50, 60), accent = rgb(80, 140, 255) },
	},
	MallBot = {
		name = "Mall-Bot 3000",
		description = "Security robot running corrupted firmware.",
		hp = 4200,
		speed = 2.6,
		armor = 0.25,
		bounty = 400,
		leak = 100,
		size = 3,
		boss = true,
		abilities = {
			{ type = "shield", interval = 12, duration = 3 },
			{ type = "stunPulse", interval = 14, radius = 12, duration = 1.5 },
		},
		look = { archetype = "mallbot", color = rgb(200, 205, 215), accent = rgb(255, 60, 60) },
	},
	WoodsKraken = {
		name = "Woods Kraken",
		description = "Lives in Elmore Lake. Nobody knows how.",
		hp = 4800,
		speed = 2.7,
		armor = 0.15,
		bounty = 450,
		leak = 100,
		size = 3.2,
		boss = true,
		abilities = {
			{ type = "summon", interval = 10, enemy = "HealerBug", count = 2 },
			{ type = "stunPulse", interval = 11, radius = 15, duration = 2 },
		},
		look = { archetype = "kraken", color = rgb(120, 70, 170), accent = rgb(255, 170, 220) },
	},
	VoidHeart = {
		name = "The Void Heart",
		description = "The core of the Void. Everything forgotten, angry at once.",
		hp = 6500,
		speed = 2.4,
		armor = 0.2,
		bounty = 600,
		leak = 100,
		size = 3.6,
		boss = true,
		abilities = {
			{ type = "stunPulse", interval = 10, radius = 16, duration = 2 },
			{ type = "summon", interval = 9, enemy = "VoidKnight", count = 2 },
			{ type = "shield", interval = 15, duration = 3 },
			{ type = "enrage", threshold = 0.25, speedMult = 1.5 },
		},
		look = { archetype = "voidheart", color = rgb(30, 10, 50), accent = rgb(220, 100, 255) },
	},
}

for id, enemy in Enemies do
	enemy.id = id
end

local module = { byId = Enemies }

function module.get(id: string)
	return Enemies[id]
end

return module
