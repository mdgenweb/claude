--[[
	Units
	Every playable defender. Pure data: the server simulates from `tiers` + `moves`; the client builds the
	procedural model from `look` (or an override model in ReplicatedStorage/Assets/Units/<id>).

	tiers[1] is the placement tier; tiers[2..n] are in-match upgrades (the CKD-style ladder:
	base attack -> ability -> upgraded ability -> ultimate). A tier may switch `move`.

	Move kinds:
		single  one target                      splash  target + radius
		circle  everything in range             cone    `angle` degrees toward target
		line    `width` wide beam to max range  chain   jumps `chains` times within `chainRange`
		multi   top `targets` enemies           (support units also carry an `aura` on their tiers)
	Move effects: slow={amount,duration} stun=seconds burn={dps=fractionOfDamage,duration}
	              shred={amount,duration} knockback=studs
	VFX styles: punch, projectile, lob, beam, chain, shockwave, slash, glare, bubble, rift, cloud, stomp
]]

local function T(cost: number, damage: number, range: number, cooldown: number, extra: { [string]: any }?)
	local tier = { cost = cost, damage = damage, range = range, cooldown = cooldown }
	if extra then
		for key, value in extra do
			tier[key] = value
		end
	end
	return tier
end

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local Units = {}

------------------------------------------------------------------------------------------------
-- RARE
------------------------------------------------------------------------------------------------
Units.Gumball = {
	name = "Gumball",
	rarity = "Rare",
	role = "Splash DPS",
	quote = "Dude, what the what?!",
	description = "Elmore's #1 troublemaker. Pranks scale into a screen-wide shockwave.",
	look = {
		archetype = "cat",
		fur = rgb(92, 180, 238),
		shirt = rgb(214, 186, 140),
		trim = rgb(122, 84, 52),
		pants = rgb(140, 140, 150),
	},
	moves = {
		punch = { name = "Dude Punch", kind = "single", vfx = "punch", color = rgb(92, 180, 238) },
		bomb = { name = "Prank Bomb", kind = "splash", radius = 5, vfx = "lob", color = rgb(255, 140, 60) },
		bombPlus = { name = "Prank Bomb+", kind = "splash", radius = 6.5, vfx = "lob", color = rgb(255, 90, 60) },
		wtw = {
			name = "What the What?!",
			kind = "circle",
			stun = 0.5,
			vfx = "shockwave",
			color = rgb(92, 180, 238),
			ultimate = true,
		},
	},
	tiers = {
		T(300, 20, 14, 1.4, { move = "punch" }),
		T(250, 30, 15, 1.35),
		T(500, 42, 16, 1.6, { move = "bomb" }),
		T(900, 75, 17, 1.5, { move = "bombPlus" }),
		T(1600, 130, 18, 1.9, { move = "wtw" }),
	},
	evolvesTo = "GumballPrime",
}

Units.Darwin = {
	name = "Darwin",
	rarity = "Rare",
	role = "Fast DPS / Slow",
	quote = "I'm here for you, buddy!",
	description = "Gumball's loyal brother. Rapid slaps, slowing water spit and a finishing dash.",
	look = { archetype = "fish", body = rgb(255, 138, 31), shoes = rgb(96, 200, 90) },
	moves = {
		slap = { name = "Fish Slap", kind = "single", vfx = "slash", color = rgb(255, 160, 60) },
		spit = {
			name = "Water Spit",
			kind = "splash",
			radius = 4,
			slow = { amount = 0.25, duration = 1.5 },
			vfx = "bubble",
			color = rgb(90, 190, 255),
		},
		barrage = { name = "Bubble Barrage", kind = "multi", targets = 3, vfx = "bubble", color = rgb(130, 210, 255) },
		dash = {
			name = "Darwin Dash",
			kind = "line",
			width = 4,
			vfx = "beam",
			color = rgb(255, 138, 31),
			ultimate = true,
		},
	},
	tiers = {
		T(280, 14, 13, 1.0, { move = "slap" }),
		T(220, 21, 13.5, 0.95),
		T(450, 28, 14.5, 1.0, { move = "spit" }),
		T(850, 40, 15.5, 0.85, { move = "barrage" }),
		T(1500, 95, 17, 1.25, { move = "dash" }),
	},
	evolvesTo = "MechaDarwin",
}

Units.BananaJoe = {
	name = "Banana Joe",
	rarity = "Rare",
	role = "Control",
	quote = "Why did the banana go to the doctor?",
	description = "Class clown. Slippery peels slow the horde; his Joke Bomb leaves them stunned.",
	look = { archetype = "banana", peel = rgb(255, 222, 70), tip = rgb(110, 80, 40) },
	moves = {
		peel = {
			name = "Peel Toss",
			kind = "splash",
			radius = 3,
			slow = { amount = 0.3, duration = 1.2 },
			vfx = "lob",
			color = rgb(255, 222, 70),
		},
		slip = {
			name = "Slippery Floor",
			kind = "splash",
			radius = 4.5,
			slow = { amount = 0.4, duration = 1.6 },
			vfx = "lob",
			color = rgb(255, 236, 120),
		},
		jokeBomb = {
			name = "Joke Bomb",
			kind = "splash",
			radius = 7,
			stun = 0.8,
			vfx = "shockwave",
			color = rgb(255, 222, 70),
			ultimate = true,
		},
	},
	tiers = {
		T(260, 10, 15, 1.6, { move = "peel" }),
		T(200, 15, 15.5, 1.55),
		T(420, 22, 16, 1.5, { move = "slip" }),
		T(700, 30, 17, 1.45),
		T(1300, 60, 18, 2.2, { move = "jokeBomb" }),
	},
}

Units.Tobias = {
	name = "Tobias",
	rarity = "Rare",
	role = "Cone DPS",
	quote = "Check out these moves!",
	description = "The self-proclaimed coolest kid. Wide kicks that hit everything in front of him.",
	look = {
		archetype = "kid",
		skin = rgb(255, 120, 120),
		rainbow = true,
		shirt = rgb(255, 255, 255),
		pants = rgb(60, 110, 200),
	},
	moves = {
		kick = { name = "Show-off Kick", kind = "cone", angle = 70, vfx = "slash", color = rgb(255, 120, 120) },
		roundhouse = { name = "Rainbow Roundhouse", kind = "cone", angle = 100, vfx = "slash", color = rgb(255, 200, 80) },
		ego = {
			name = "Ego Blast",
			kind = "cone",
			angle = 140,
			shred = { amount = 0.15, duration = 3 },
			vfx = "shockwave",
			color = rgb(180, 120, 255),
			ultimate = true,
		},
	},
	tiers = {
		T(320, 18, 12, 1.5, { move = "kick" }),
		T(260, 26, 12.5, 1.45),
		T(520, 36, 13.5, 1.4, { move = "roundhouse" }),
		T(900, 58, 14.5, 1.35),
		T(1600, 110, 16, 1.5, { move = "ego" }),
	},
}

Units.Alan = {
	name = "Alan",
	rarity = "Rare",
	role = "Support",
	quote = "Everyone deserves a hug!",
	description = "The nicest balloon in Elmore. Buffs the damage of nearby allies.",
	maxPlaced = 3,
	look = { archetype = "balloon", color = rgb(120, 220, 110) },
	moves = {
		pop = { name = "Static Pop", kind = "single", vfx = "chain", color = rgb(150, 240, 140) },
		vibes = {
			name = "Good Vibes",
			kind = "single",
			vfx = "chain",
			color = rgb(150, 240, 140),
			ultimate = true,
		},
	},
	tiers = {
		T(400, 6, 12, 1.6, { move = "pop", aura = { damage = 0.08 } }),
		T(350, 8, 13, 1.5, { aura = { damage = 0.12 } }),
		T(650, 10, 14, 1.5, { aura = { damage = 0.16, speed = 0.04 } }),
		T(1100, 12, 15, 1.4, { aura = { damage = 0.2, speed = 0.06 } }),
		T(1800, 15, 16, 1.4, { move = "vibes", aura = { damage = 0.25, speed = 0.1 } }),
	},
}

------------------------------------------------------------------------------------------------
-- EPIC
------------------------------------------------------------------------------------------------
Units.Anais = {
	name = "Anais",
	rarity = "Epic",
	role = "Splash / Armour Shred",
	quote = "Statistically, you're all doomed.",
	description = "Elmore's 4-year-old genius. Her chemistry melts armour.",
	look = { archetype = "rabbit", fur = rgb(255, 160, 200), dress = rgb(255, 150, 40), small = true },
	moves = {
		beaker = {
			name = "Science Beaker",
			kind = "splash",
			radius = 4,
			shred = { amount = 0.15, duration = 3 },
			vfx = "lob",
			color = rgb(120, 255, 140),
		},
		acid = {
			name = "Acid Mix",
			kind = "splash",
			radius = 5,
			shred = { amount = 0.25, duration = 4 },
			burn = { dps = 0.2, duration = 3 },
			vfx = "lob",
			color = rgb(170, 255, 80),
		},
		theory = {
			name = "Theory of Everything",
			kind = "line",
			width = 5,
			shred = { amount = 0.3, duration = 4 },
			vfx = "beam",
			color = rgb(255, 150, 220),
			ultimate = true,
		},
	},
	tiers = {
		T(450, 30, 17, 1.6, { move = "beaker" }),
		T(350, 42, 17.5, 1.55),
		T(650, 55, 18, 1.5, { move = "acid" }),
		T(1000, 80, 19, 1.45),
		T(1600, 120, 20, 1.4),
		T(2600, 310, 22, 1.9, { move = "theory" }),
	},
	evolvesTo = "ProfessorAnais",
}

Units.Penny = {
	name = "Penny",
	rarity = "Epic",
	role = "Chain",
	quote = "I can be anything I want!",
	description = "Shape-shifting fairy. Sparks leap between enemies.",
	look = { archetype = "peanut", shell = rgb(240, 196, 130), antlers = rgb(140, 92, 50) },
	moves = {
		antler = { name = "Antler Charge", kind = "line", width = 3, vfx = "beam", color = rgb(240, 196, 130) },
		spark = {
			name = "Fairy Spark",
			kind = "chain",
			chains = 4,
			chainRange = 9,
			vfx = "chain",
			color = rgb(255, 230, 120),
		},
		storm = {
			name = "Shapeshift Storm",
			kind = "chain",
			chains = 7,
			chainRange = 11,
			stun = 0.25,
			vfx = "chain",
			color = rgb(255, 210, 255),
			ultimate = true,
		},
	},
	tiers = {
		T(420, 26, 15, 1.4, { move = "antler" }),
		T(330, 36, 15.5, 1.35),
		T(620, 40, 16, 1.3, { move = "spark" }),
		T(950, 60, 17, 1.25),
		T(1500, 85, 18, 1.2),
		T(2500, 150, 19.5, 1.3, { move = "storm" }),
	},
}

Units.Bobert = {
	name = "Bobert",
	rarity = "Epic",
	role = "Pierce / Detection",
	quote = "Calculating... victory.",
	description = "Robot classmate with built-in scanners: detects hidden enemies.",
	detect = true,
	look = { archetype = "robot", metal = rgb(170, 190, 210), screen = rgb(60, 255, 180) },
	moves = {
		laser = { name = "Laser Eye", kind = "line", width = 2, vfx = "beam", color = rgb(255, 60, 60) },
		twin = { name = "Twin Lasers", kind = "line", width = 3, vfx = "beam", color = rgb(255, 80, 80) },
		overclock = {
			name = "Overclock Beam",
			kind = "line",
			width = 4,
			burn = { dps = 0.25, duration = 3 },
			vfx = "beam",
			color = rgb(255, 40, 120),
			ultimate = true,
		},
	},
	tiers = {
		T(500, 22, 20, 1.2, { move = "laser" }),
		T(380, 30, 21, 1.15),
		T(700, 46, 22, 1.1, { move = "twin" }),
		T(1100, 64, 23, 1.05),
		T(1700, 88, 24, 1.0),
		T(2700, 165, 26, 0.95, { move = "overclock" }),
	},
}

Units.TinaRex = {
	name = "Tina Rex",
	rarity = "Epic",
	role = "Stun AoE",
	quote = "ROOOAR!",
	description = "The school bully dinosaur. Her stomps stun everything around her.",
	look = { archetype = "dino", scales = rgb(150, 170, 110), belly = rgb(220, 220, 170) },
	moves = {
		stomp = { name = "Stomp", kind = "circle", stun = 0.3, vfx = "stomp", color = rgb(190, 160, 110) },
		roar = {
			name = "Roar",
			kind = "circle",
			slow = { amount = 0.35, duration = 2 },
			vfx = "shockwave",
			color = rgb(255, 120, 80),
		},
		extinction = {
			name = "Extinction Stomp",
			kind = "circle",
			stun = 0.8,
			vfx = "stomp",
			color = rgb(255, 90, 40),
			ultimate = true,
		},
	},
	tiers = {
		T(550, 28, 10, 2.2, { move = "stomp" }),
		T(400, 38, 10.5, 2.1),
		T(750, 52, 11, 2.0, { move = "roar" }),
		T(1150, 75, 11.5, 1.95),
		T(1800, 105, 12, 1.9),
		T(2900, 220, 13.5, 2.3, { move = "extinction" }),
	},
}

Units.Carrie = {
	name = "Carrie",
	rarity = "Epic",
	role = "Burn / Detection",
	quote = "Ugh. Fine. I'll haunt them.",
	description = "Emo ghost. Sees hidden enemies and curses them with burning hexes.",
	detect = true,
	look = { archetype = "ghost", body = rgb(200, 200, 215), hair = rgb(30, 30, 40) },
	moves = {
		hex = {
			name = "Spooky Hex",
			kind = "single",
			burn = { dps = 0.3, duration = 3 },
			vfx = "projectile",
			color = rgb(160, 90, 255),
		},
		possession = {
			name = "Possession",
			kind = "multi",
			targets = 2,
			burn = { dps = 0.35, duration = 3 },
			vfx = "projectile",
			color = rgb(180, 110, 255),
		},
		poltergeist = {
			name = "Poltergeist",
			kind = "chain",
			chains = 5,
			chainRange = 10,
			burn = { dps = 0.4, duration = 4 },
			vfx = "chain",
			color = rgb(200, 120, 255),
			ultimate = true,
		},
	},
	tiers = {
		T(480, 18, 18, 1.3, { move = "hex" }),
		T(360, 26, 18.5, 1.25),
		T(650, 34, 19, 1.2, { move = "possession" }),
		T(1000, 48, 20, 1.15),
		T(1550, 70, 21, 1.1),
		T(2500, 120, 23, 1.1, { move = "poltergeist" }),
	},
}

------------------------------------------------------------------------------------------------
-- LEGENDARY
------------------------------------------------------------------------------------------------
Units.Masami = {
	name = "Masami",
	rarity = "Legendary",
	role = "Chain Lightning",
	quote = "You'll regret making me rain.",
	description = "A literal storm cloud. Lightning chains through the whole path.",
	look = { archetype = "cloud", color = rgb(255, 230, 245), storm = rgb(90, 90, 130) },
	moves = {
		drizzle = {
			name = "Drizzle",
			kind = "splash",
			radius = 4,
			slow = { amount = 0.15, duration = 1.5 },
			vfx = "cloud",
			color = rgb(130, 190, 255),
		},
		thunder = {
			name = "Thunderstorm",
			kind = "chain",
			chains = 5,
			chainRange = 12,
			vfx = "chain",
			color = rgb(255, 245, 120),
		},
		cat5 = {
			name = "Category 5",
			kind = "circle",
			stun = 0.6,
			vfx = "shockwave",
			color = rgb(160, 200, 255),
			ultimate = true,
		},
	},
	tiers = {
		T(800, 40, 18, 1.8, { move = "drizzle" }),
		T(600, 55, 18.5, 1.75),
		T(1000, 70, 19, 1.7, { move = "thunder" }),
		T(1500, 100, 20, 1.6),
		T(2200, 140, 21, 1.55),
		T(3200, 190, 22, 1.5),
		T(4500, 380, 24, 2.0, { move = "cat5" }),
	},
}

Units.MissSimian = {
	name = "Miss Simian",
	rarity = "Legendary",
	role = "Stun Control",
	quote = "DETENTION!",
	description = "The strictest teacher alive. Stuns, mass detention and an expulsion knock-back.",
	look = { archetype = "baboon", fur = rgb(150, 120, 100), dress = rgb(150, 110, 190) },
	moves = {
		detention = {
			name = "Detention",
			kind = "single",
			stun = 0.6,
			vfx = "glare",
			color = rgb(255, 80, 80),
		},
		popQuiz = {
			name = "Pop Quiz",
			kind = "multi",
			targets = 4,
			stun = 0.4,
			vfx = "projectile",
			color = rgb(255, 255, 255),
		},
		expelled = {
			name = "Expelled!",
			kind = "splash",
			radius = 6,
			stun = 0.5,
			knockback = 5,
			vfx = "shockwave",
			color = rgb(255, 60, 60),
			ultimate = true,
		},
	},
	tiers = {
		T(850, 45, 16, 1.9, { move = "detention" }),
		T(620, 62, 16.5, 1.85),
		T(1050, 70, 17, 1.8, { move = "popQuiz" }),
		T(1550, 100, 18, 1.75),
		T(2300, 135, 19, 1.7),
		T(3300, 175, 20, 1.65),
		T(4700, 320, 21, 2.0, { move = "expelled" }),
	},
}

Units.MrSmall = {
	name = "Mr. Small",
	rarity = "Legendary",
	role = "Support / Slow Aura",
	quote = "Let's all find our inner peace, man.",
	description = "School counsellor. Allies nearby attack faster and see further; enemies nearby crawl.",
	maxPlaced = 2,
	look = {
		archetype = "hippie",
		skin = rgb(255, 196, 80),
		hair = rgb(230, 120, 40),
		shirt = rgb(180, 90, 220),
	},
	moves = {
		calm = {
			name = "Calm Wave",
			kind = "circle",
			slow = { amount = 0.2, duration = 1 },
			vfx = "shockwave",
			color = rgb(200, 160, 255),
		},
		nirvana = {
			name = "Total Nirvana",
			kind = "circle",
			slow = { amount = 0.35, duration = 1.5 },
			vfx = "shockwave",
			color = rgb(255, 210, 120),
			ultimate = true,
		},
	},
	tiers = {
		T(900, 12, 14, 2.0, { move = "calm", aura = { speed = 0.08, range = 0.05, enemySlow = 0.10 } }),
		T(700, 16, 15, 2.0, { aura = { speed = 0.10, range = 0.06, enemySlow = 0.12 } }),
		T(1100, 20, 16, 1.9, { aura = { speed = 0.12, range = 0.08, enemySlow = 0.15 } }),
		T(1600, 24, 17, 1.9, { aura = { speed = 0.15, range = 0.09, enemySlow = 0.18 } }),
		T(2300, 30, 18, 1.8, { aura = { speed = 0.18, range = 0.10, enemySlow = 0.22 } }),
		T(3200, 36, 19, 1.8, { aura = { speed = 0.21, range = 0.11, enemySlow = 0.26 } }),
		T(4500, 48, 20, 1.7, { move = "nirvana", aura = { speed = 0.25, range = 0.12, enemySlow = 0.30 } }),
	},
}

------------------------------------------------------------------------------------------------
-- MYTHIC
------------------------------------------------------------------------------------------------
Units.Nicole = {
	name = "Nicole",
	rarity = "Mythic",
	role = "Boss Killer",
	quote = "NOBODY messes with my family.",
	description = "The scariest mom in Elmore. Colossal single-target damage.",
	look = {
		archetype = "cat",
		fur = rgb(60, 140, 220),
		shirt = rgb(250, 250, 250),
		trim = rgb(255, 170, 40),
		skirt = rgb(170, 170, 180),
		tall = true,
	},
	moves = {
		glare = { name = "Mom Glare", kind = "single", vfx = "glare", color = rgb(255, 60, 60) },
		keys = { name = "Car Keys of Doom", kind = "multi", targets = 2, vfx = "projectile", color = rgb(255, 220, 90) },
		fury = {
			name = "Watterson Fury",
			kind = "line",
			width = 5,
			stun = 0.5,
			vfx = "beam",
			color = rgb(255, 50, 50),
			ultimate = true,
		},
	},
	tiers = {
		T(1100, 120, 18, 2.0, { move = "glare" }),
		T(800, 170, 18.5, 1.95),
		T(1300, 240, 19, 1.9, { move = "keys" }),
		T(2000, 340, 20, 1.85),
		T(3000, 480, 21, 1.8),
		T(4300, 650, 22, 1.75),
		T(6000, 1500, 24, 2.2, { move = "fury" }),
	},
	evolvesTo = "NicoleUnleashed",
}

Units.Richard = {
	name = "Richard",
	rarity = "Mythic",
	role = "Farm",
	quote = "Is it lunchtime yet?",
	description = "Professional couch expert. Earns cash every wave doing pizza runs. Occasionally belly-flops.",
	maxPlaced = 3,
	farm = true,
	look = { archetype = "rabbit", fur = rgb(255, 170, 200), shirt = rgb(250, 250, 250), big = true },
	moves = {
		flop = { name = "Belly Flop", kind = "splash", radius = 5, vfx = "stomp", color = rgb(255, 170, 200) },
		pizza = {
			name = "Pizza Party",
			kind = "splash",
			radius = 7,
			stun = 0.4,
			vfx = "lob",
			color = rgb(255, 200, 80),
			ultimate = true,
		},
	},
	tiers = {
		T(900, 25, 12, 2.2, { move = "flop", income = 150 }),
		T(900, 30, 12, 2.1, { income = 300 }),
		T(1500, 40, 12.5, 2.0, { income = 550 }),
		T(2200, 55, 13, 2.0, { income = 850 }),
		T(3200, 70, 13.5, 1.9, { income = 1250 }),
		T(4500, 90, 14, 1.9, { move = "pizza", income = 1800 }),
	},
}

Units.Hector = {
	name = "Hector",
	rarity = "Mythic",
	role = "Giant AoE",
	quote = "...sorry, did I step on something?",
	description = "A gentle giant. Every step is an earthquake.",
	look = { archetype = "giant", skin = rgb(230, 190, 160), fur = rgb(120, 80, 50), pants = rgb(70, 90, 140) },
	moves = {
		step = { name = "Giant Step", kind = "circle", vfx = "stomp", color = rgb(160, 120, 80) },
		quake = {
			name = "Earthquake",
			kind = "circle",
			stun = 0.5,
			slow = { amount = 0.3, duration = 2 },
			vfx = "stomp",
			color = rgb(200, 150, 90),
		},
		mountain = {
			name = "Mountain Fall",
			kind = "circle",
			stun = 1.0,
			vfx = "stomp",
			color = rgb(255, 170, 90),
			ultimate = true,
		},
	},
	tiers = {
		T(1300, 150, 13, 3.0, { move = "step" }),
		T(950, 210, 13.5, 2.9),
		T(1500, 290, 14, 2.8, { move = "quake" }),
		T(2300, 400, 15, 2.7),
		T(3400, 560, 16, 2.6),
		T(4800, 760, 17, 2.5),
		T(6500, 1600, 19, 3.0, { move = "mountain" }),
	},
}

------------------------------------------------------------------------------------------------
-- SECRET
------------------------------------------------------------------------------------------------
Units.Rob = {
	name = "Rob",
	rarity = "Secret",
	role = "Knock-back / Shred",
	quote = "I came back from the Void... for THIS?",
	description = "Escaped the Void. Opens rifts that hurl enemies back down the path.",
	look = { archetype = "void", body = rgb(70, 130, 170), glow = rgb(190, 90, 255) },
	moves = {
		rift = {
			name = "Void Rift",
			kind = "splash",
			radius = 6,
			knockback = 4,
			shred = { amount = 0.2, duration = 4 },
			vfx = "rift",
			color = rgb(190, 90, 255),
		},
		collapse = {
			name = "Void Collapse",
			kind = "circle",
			knockback = 8,
			stun = 0.3,
			shred = { amount = 0.35, duration = 5 },
			vfx = "rift",
			color = rgb(230, 120, 255),
			ultimate = true,
		},
	},
	tiers = {
		T(1600, 180, 17, 2.0, { move = "rift" }),
		T(1100, 240, 17.5, 1.95),
		T(1700, 320, 18, 1.9),
		T(2600, 430, 19, 1.85),
		T(3700, 580, 20, 1.8),
		T(5000, 780, 21, 1.75),
		T(6800, 1000, 22, 1.7),
		T(9000, 2000, 24, 2.0, { move = "collapse" }),
	},
}

------------------------------------------------------------------------------------------------
-- LIMITED (Elmore Pass Season 1 "Halloweenie")
------------------------------------------------------------------------------------------------
Units.PumpkinDarwin = {
	name = "Pumpkin Darwin",
	rarity = "Legendary",
	role = "Burn Splash",
	quote = "Trick OR treat, buddy!",
	description = "Limited Halloween Darwin. Flaming pumpkins burn crowds.",
	limited = true,
	summonable = false,
	look = { archetype = "fish", body = rgb(255, 138, 31), shoes = rgb(60, 60, 60), extras = { "pumpkinHead" } },
	moves = {
		toss = {
			name = "Pumpkin Toss",
			kind = "splash",
			radius = 4.5,
			burn = { dps = 0.3, duration = 3 },
			vfx = "lob",
			color = rgb(255, 130, 20),
		},
		jackBlast = {
			name = "Jack-o'-Blast",
			kind = "splash",
			radius = 7,
			burn = { dps = 0.45, duration = 4 },
			vfx = "shockwave",
			color = rgb(255, 100, 0),
			ultimate = true,
		},
	},
	tiers = {
		T(800, 45, 16, 1.6, { move = "toss" }),
		T(600, 62, 16.5, 1.55),
		T(950, 80, 17, 1.5),
		T(1450, 110, 18, 1.45),
		T(2100, 150, 19, 1.4),
		T(3000, 200, 20, 1.35),
		T(4300, 420, 21, 1.6, { move = "jackBlast" }),
	},
}

Units.VampireGumball = {
	name = "Vampire Gumball",
	rarity = "Mythic",
	role = "Multi-target Burn",
	quote = "I vant to prank your neck!",
	description = "Limited premium-pass Gumball. Always Shiny. Bat swarms drain the horde.",
	limited = true,
	summonable = false,
	alwaysShiny = true,
	look = {
		archetype = "cat",
		fur = rgb(150, 200, 255),
		shirt = rgb(40, 20, 40),
		trim = rgb(200, 20, 40),
		pants = rgb(30, 30, 30),
		extras = { "vampireCape" },
	},
	moves = {
		bats = {
			name = "Bat Swarm",
			kind = "multi",
			targets = 3,
			burn = { dps = 0.3, duration = 3 },
			vfx = "projectile",
			color = rgb(200, 30, 60),
		},
		prankula = {
			name = "Count Prankula",
			kind = "chain",
			chains = 6,
			chainRange = 12,
			burn = { dps = 0.5, duration = 4 },
			vfx = "chain",
			color = rgb(255, 40, 80),
			ultimate = true,
		},
	},
	tiers = {
		T(1200, 110, 18, 1.8, { move = "bats" }),
		T(850, 155, 18.5, 1.75),
		T(1350, 210, 19, 1.7),
		T(2050, 290, 20, 1.65),
		T(3100, 400, 21, 1.6),
		T(4400, 550, 22, 1.55),
		T(6200, 1250, 24, 1.9, { move = "prankula" }),
	},
}

------------------------------------------------------------------------------------------------
-- GLOW-UPS (evolutions; never summoned directly)
------------------------------------------------------------------------------------------------
Units.GumballPrime = {
	name = "Gumball Prime",
	rarity = "Mythic",
	role = "Splash DPS",
	quote = "Prepare for the ULTIMATE prank.",
	description = "Glow-Up of Gumball. Keeps level, trait and grades.",
	summonable = false,
	evolvedFrom = "Gumball",
	look = {
		archetype = "cat",
		fur = rgb(70, 170, 255),
		shirt = rgb(255, 214, 70),
		trim = rgb(220, 60, 60),
		pants = rgb(60, 60, 80),
		extras = { "cape", "crown" },
	},
	moves = {
		primePunch = { name = "Prime Punch", kind = "splash", radius = 4, vfx = "punch", color = rgb(255, 214, 70) },
		primeBomb = { name = "Mega Prank Bomb", kind = "splash", radius = 7, vfx = "lob", color = rgb(255, 120, 40) },
		chaos = {
			name = "Chaos Prank",
			kind = "circle",
			stun = 0.8,
			vfx = "shockwave",
			color = rgb(255, 214, 70),
			ultimate = true,
		},
	},
	tiers = {
		T(1000, 110, 17, 1.6, { move = "primePunch" }),
		T(750, 150, 17.5, 1.55),
		T(1200, 210, 18, 1.5),
		T(1850, 290, 19, 1.45, { move = "primeBomb" }),
		T(2800, 400, 20, 1.4),
		T(4000, 540, 21, 1.35),
		T(5600, 1200, 23, 1.8, { move = "chaos" }),
	},
}

Units.MechaDarwin = {
	name = "Mecha Darwin",
	rarity = "Mythic",
	role = "Rapid Multi",
	quote = "Upgrade complete, buddy!",
	description = "Glow-Up of Darwin. Rocket fins and a hydro cannon.",
	summonable = false,
	evolvedFrom = "Darwin",
	look = { archetype = "fish", body = rgb(255, 150, 40), shoes = rgb(120, 130, 150), extras = { "mechArmor" } },
	moves = {
		rocketFin = { name = "Rocket Fin", kind = "multi", targets = 3, vfx = "projectile", color = rgb(255, 160, 60) },
		hydro = { name = "Hydro Cannon", kind = "line", width = 5, vfx = "beam", color = rgb(80, 180, 255) },
		megaSplash = {
			name = "Mega Splash",
			kind = "splash",
			radius = 9,
			slow = { amount = 0.4, duration = 2 },
			vfx = "bubble",
			color = rgb(80, 200, 255),
			ultimate = true,
		},
	},
	tiers = {
		T(1000, 80, 18, 1.1, { move = "rocketFin" }),
		T(750, 110, 18.5, 1.05),
		T(1200, 150, 19, 1.0),
		T(1850, 200, 20, 0.95, { move = "hydro" }),
		T(2800, 280, 21, 0.9),
		T(4000, 380, 22, 0.85),
		T(5600, 800, 24, 1.1, { move = "megaSplash" }),
	},
}

Units.ProfessorAnais = {
	name = "Professor Anais",
	rarity = "Mythic",
	role = "Shred / Control",
	quote = "Physics is on my side.",
	description = "Glow-Up of Anais. Quantum chemistry and a black-hole singularity.",
	summonable = false,
	evolvedFrom = "Anais",
	look = {
		archetype = "rabbit",
		fur = rgb(255, 170, 210),
		dress = rgb(255, 150, 40),
		small = true,
		extras = { "labCoat", "goggles" },
	},
	moves = {
		quantum = {
			name = "Quantum Beaker",
			kind = "splash",
			radius = 5,
			shred = { amount = 0.3, duration = 4 },
			vfx = "lob",
			color = rgb(120, 255, 200),
		},
		singularity = {
			name = "Singularity",
			kind = "circle",
			stun = 1.0,
			shred = { amount = 0.4, duration = 5 },
			knockback = 3,
			vfx = "rift",
			color = rgb(255, 150, 230),
			ultimate = true,
		},
	},
	tiers = {
		T(1100, 100, 19, 1.6, { move = "quantum" }),
		T(800, 140, 19.5, 1.55),
		T(1300, 190, 20, 1.5),
		T(2000, 260, 21, 1.45),
		T(3000, 350, 22, 1.4),
		T(4300, 480, 23, 1.35),
		T(6000, 1100, 25, 1.8, { move = "singularity" }),
	},
}

Units.NicoleUnleashed = {
	name = "Nicole Unleashed",
	rarity = "Mythic",
	role = "Boss Annihilator",
	quote = "You woke the WRONG mom.",
	description = "Glow-Up of Nicole. The strongest single-target unit in Elmore.",
	summonable = false,
	evolvedFrom = "Nicole",
	look = {
		archetype = "cat",
		fur = rgb(40, 120, 220),
		shirt = rgb(255, 255, 255),
		trim = rgb(255, 60, 60),
		skirt = rgb(60, 60, 70),
		tall = true,
		extras = { "fireAura", "headband" },
	},
	moves = {
		uglare = { name = "Unleashed Glare", kind = "single", vfx = "glare", color = rgb(255, 40, 40) },
		combo = { name = "Supermom Combo", kind = "multi", targets = 4, stun = 0.3, vfx = "punch", color = rgb(255, 90, 60) },
		wrath = {
			name = "Watterson Wrath",
			kind = "line",
			width = 6,
			stun = 1.0,
			vfx = "beam",
			color = rgb(255, 30, 30),
			ultimate = true,
		},
	},
	tiers = {
		T(1500, 260, 20, 1.9, { move = "uglare" }),
		T(1100, 360, 20.5, 1.85),
		T(1700, 480, 21, 1.8, { move = "combo" }),
		T(2600, 650, 22, 1.75),
		T(3800, 880, 23, 1.7),
		T(5300, 1200, 24, 1.65),
		T(7500, 3200, 26, 2.1, { move = "wrath" }),
	},
}

------------------------------------------------------------------------------------------------
-- Finalise: ids, defaults, ordering
------------------------------------------------------------------------------------------------
local ordered = {}
for id, unit in Units do
	unit.id = id
	if unit.summonable == nil then
		unit.summonable = true
	end
	table.insert(ordered, unit)
end

local RARITY_ORDER = { Rare = 1, Epic = 2, Legendary = 3, Mythic = 4, Secret = 5 }
table.sort(ordered, function(a, b)
	local ra, rb = RARITY_ORDER[a.rarity] or 0, RARITY_ORDER[b.rarity] or 0
	if ra ~= rb then
		return ra < rb
	end
	return a.name < b.name
end)

local module = {
	byId = Units,
	ordered = ordered,
}

function module.get(id: string)
	return Units[id]
end

function module.maxLevel(id: string): number
	local unit = Units[id]
	return if unit then #unit.tiers - 1 else 0
end

-- Returns the move active at a given in-match upgrade level (0-based).
function module.moveAt(unit, level: number)
	local moveKey = nil
	for index = 1, math.min(level + 1, #unit.tiers) do
		local tier = unit.tiers[index]
		if tier.move then
			moveKey = tier.move
		end
	end
	return unit.moves[moveKey], moveKey
end

-- Returns the aura active at a given level (auras are specified per tier, latest wins).
function module.auraAt(unit, level: number)
	local tier = unit.tiers[math.clamp(level + 1, 1, #unit.tiers)]
	return tier and tier.aura
end

function module.listByRarity(rarity: string, summonableOnly: boolean?)
	local list = {}
	for _, unit in ordered do
		if unit.rarity == rarity and (not summonableOnly or unit.summonable) then
			table.insert(list, unit)
		end
	end
	return list
end

return module
