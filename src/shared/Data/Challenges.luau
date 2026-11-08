--!strict
-- Daily challenge templates and handcrafted Trials.
--
-- Events emitted by the server (Systems/ChallengeTracker):
--   damage(amount)  brew(potionId)  discover(potionId)  status(statusId, golemId)  shatter(golemId)
--   goldshatter(golemId)  height(studs)  airtime(seconds)  reaction(reactionId)  ko(golemId)
--   fling(speed)  zone(zoneId, golemId)

export type DailyTemplate = {
	id: string,
	text: string, -- "%d" is replaced by the target
	event: string,
	filter: string?,
	mode: "sum" | "count" | "max",
	targets: { number }, -- easy, medium, hard
	minLevel: number,
	icon: string,
}

export type Objective = {
	event: string,
	filter: string?,
	target: number,
	mode: "sum" | "count" | "max",
	unique: boolean?, -- count each golem only once
	text: string,
}

export type TrialGolem = { x: number, y: number?, skin: string? }
export type TrialProp = { id: string, x: number, y: number? }
export type TrialZone = { id: string, x: number, y: number, w: number, h: number, visual: string }

export type Trial = {
	id: string,
	name: string,
	icon: string,
	description: string,
	order: number,
	map: string,
	golems: { TrialGolem },
	props: { TrialProp },
	zones: { TrialZone },
	potions: { [string]: number }, -- provided free for the trial (math.huge = infinite)
	objective: Objective,
	timeLimit: number,
	stars: { number }, -- {limit for 1★, ≤ for 2★, ≤ for 3★}
	reward: { coins: number, xp: number, ingredients: { [string]: number }?, skin: string? },
	requiresStars: number?,
	final: boolean?,
}

local INF = math.huge

local Daily: { DailyTemplate } = {
	{
		id = "damage",
		text = "Deal %d damage",
		event = "damage",
		mode = "sum",
		targets = { 1500, 3500, 7000 },
		minLevel = 1,
		icon = "💥",
	},
	{
		id = "brew",
		text = "Brew %d potions",
		event = "brew",
		mode = "count",
		targets = { 3, 6, 10 },
		minLevel = 1,
		icon = "🧪",
	},
	{
		id = "burn",
		text = "Set %d golems on fire",
		event = "status",
		filter = "burning",
		mode = "count",
		targets = { 3, 6, 10 },
		minLevel = 1,
		icon = "🔥",
	},
	{
		id = "freeze",
		text = "Freeze %d golems",
		event = "status",
		filter = "frozen",
		mode = "count",
		targets = { 3, 6, 10 },
		minLevel = 1,
		icon = "❄️",
	},
	{
		id = "float",
		text = "Make %d golems levitate",
		event = "status",
		filter = "levitating",
		mode = "count",
		targets = { 3, 5, 8 },
		minLevel = 1,
		icon = "🎈",
	},
	{
		id = "shatter",
		text = "Shatter %d frozen golems",
		event = "shatter",
		mode = "count",
		targets = { 1, 3, 5 },
		minLevel = 1,
		icon = "🧊",
	},
	{
		id = "height",
		text = "Launch a golem %d studs high",
		event = "height",
		mode = "max",
		targets = { 30, 45, 120 },
		minLevel = 1,
		icon = "🚀",
	},
	{
		id = "airtime",
		text = "Keep a golem airborne for %d seconds",
		event = "airtime",
		mode = "max",
		targets = { 3, 5, 8 },
		minLevel = 1,
		icon = "🪂",
	},
	{
		id = "fling",
		text = "Fling a golem at %d studs/s",
		event = "fling",
		mode = "max",
		targets = { 110, 170, 240 },
		minLevel = 1,
		icon = "🤾",
	},
	{
		id = "ko",
		text = "Knock out %d golems",
		event = "ko",
		mode = "count",
		targets = { 2, 4, 8 },
		minLevel = 1,
		icon = "😵",
	},
	{
		id = "reaction",
		text = "Trigger %d potion reactions",
		event = "reaction",
		mode = "count",
		targets = { 1, 3, 6 },
		minLevel = 3,
		icon = "⚗️",
	},
	{
		id = "shock",
		text = "Shock %d golems",
		event = "status",
		filter = "shocked",
		mode = "count",
		targets = { 3, 6, 10 },
		minLevel = 4,
		icon = "⚡",
	},
	{
		id = "giant",
		text = "Grow %d giant golems",
		event = "status",
		filter = "giant",
		mode = "count",
		targets = { 2, 4, 6 },
		minLevel = 5,
		icon = "🌱",
	},
	{
		id = "zombie",
		text = "Zombify %d golems",
		event = "status",
		filter = "zombie",
		mode = "count",
		targets = { 2, 4, 8 },
		minLevel = 9,
		icon = "🧟",
	},
	{
		id = "golden",
		text = "Turn %d golems to gold",
		event = "status",
		filter = "golden",
		mode = "count",
		targets = { 2, 4, 6 },
		minLevel = 11,
		icon = "💰",
	},
}

local Trials: { Trial } = {
	{
		id = "first_flight",
		name = "First Flight",
		icon = "🧺",
		description = "Grab Clayton and fling him into the basket.",
		order = 1,
		map = "lab",
		golems = { { x = -30 } },
		props = {},
		zones = { { id = "basket", x = 34, y = 5, w = 9, h = 8, visual = "basket" } },
		potions = {},
		objective = { event = "zone", filter = "basket", target = 1, mode = "count", text = "Golem in the basket" },
		timeLimit = 90,
		stars = { 90, 30, 12 },
		reward = { coins = 120, xp = 150, ingredients = { boom_spore = 2 } },
	},
	{
		id = "hot_potato",
		name = "Hot Potato",
		icon = "🔥",
		description = "Set three different golems on fire.",
		order = 2,
		map = "lab",
		golems = { { x = -32 }, { x = 0 }, { x = 32 } },
		props = { { id = "crate", x = -16 }, { id = "crate", x = 16 } },
		zones = {},
		potions = { inferno_brew = 2 },
		objective = {
			event = "status",
			filter = "burning",
			target = 3,
			mode = "count",
			unique = true,
			text = "Golems set on fire",
		},
		timeLimit = 90,
		stars = { 90, 35, 15 },
		reward = { coins = 150, xp = 180, ingredients = { storm_moss = 2 } },
	},
	{
		id = "ice_breaker",
		name = "Ice Breaker",
		icon = "🧊",
		description = "Freeze a golem, then smash it to pieces.",
		order = 3,
		map = "lab",
		golems = { { x = 0 } },
		props = {},
		zones = {},
		potions = { frost_tonic = INF },
		objective = { event = "shatter", target = 1, mode = "count", text = "Golems shattered" },
		timeLimit = 120,
		stars = { 120, 40, 15 },
		reward = { coins = 180, xp = 220, ingredients = { giant_bean = 2 } },
	},
	{
		id = "lift_off",
		name = "Lift Off",
		icon = "🚀",
		description = "Get a golem up to the golden ring near the ceiling.",
		order = 4,
		map = "lab",
		golems = { { x = -20 } },
		props = {},
		zones = { { id = "ring", x = 20, y = 50, w = 10, h = 10, visual = "ring" } },
		potions = { rocket_fuel = INF, levitation_elixir = INF },
		objective = { event = "zone", filter = "ring", target = 1, mode = "count", text = "Golem through the ring" },
		timeLimit = 120,
		stars = { 120, 40, 15 },
		reward = { coins = 200, xp = 260, ingredients = { pixie_dust = 2 } },
	},
	{
		id = "bullseye",
		name = "Bullseye",
		icon = "🎯",
		description = "Slam a golem into the target on the far wall.",
		order = 5,
		map = "lab",
		golems = { { x = -36 } },
		props = { { id = "plank", x = -5, y = 0 } },
		zones = { { id = "target", x = 52, y = 28, w = 6, h = 12, visual = "target" } },
		potions = { kaboom_cocktail = 3 },
		objective = { event = "zone", filter = "target", target = 1, mode = "count", text = "Bullseye hits" },
		timeLimit = 120,
		stars = { 120, 35, 12 },
		reward = { coins = 220, xp = 300, ingredients = { bone_dust = 2 } },
	},
	{
		id = "pinball",
		name = "Pinball Wizard",
		icon = "🕹️",
		description = "Rack up 1,500 damage in the Bounce Castle.",
		order = 6,
		map = "bounce",
		golems = { { x = -10 }, { x = 10 } },
		props = {},
		zones = {},
		potions = { bouncy_goo = INF, kaboom_cocktail = 4 },
		objective = { event = "damage", target = 1500, mode = "sum", text = "Damage dealt" },
		timeLimit = 120,
		stars = { 120, 50, 25 },
		reward = { coins = 260, xp = 340, ingredients = { gold_nugget = 2 } },
		requiresStars = 8,
	},
	{
		id = "gold_rush",
		name = "Gold Rush",
		icon = "💰",
		description = "Turn a golem to gold and shatter it into coins.",
		order = 7,
		map = "lab",
		golems = { { x = 0 } },
		props = { { id = "anvil", x = -20 } },
		zones = {},
		potions = { midas_touch = 2, kaboom_cocktail = 2 },
		objective = { event = "goldshatter", target = 1, mode = "count", text = "Gold golems shattered" },
		timeLimit = 120,
		stars = { 120, 40, 18 },
		reward = { coins = 320, xp = 400, ingredients = { void_salt = 1 } },
		requiresStars = 10,
	},
	{
		id = "outbreak",
		name = "Outbreak",
		icon = "🧟",
		description = "One bottle of Reanimation Serum. Zombify all four golems.",
		order = 8,
		map = "lab",
		golems = { { x = -36 }, { x = -12 }, { x = 12 }, { x = 36 } },
		props = {},
		zones = {},
		potions = { reanimation_serum = 1 },
		objective = {
			event = "status",
			filter = "zombie",
			target = 4,
			mode = "count",
			unique = true,
			text = "Golems zombified",
		},
		timeLimit = 150,
		stars = { 150, 70, 35 },
		reward = { coins = 380, xp = 480, ingredients = { dragon_scale = 1 } },
		requiresStars = 13,
	},
	{
		id = "sky_high",
		name = "Sky High",
		icon = "🗼",
		description = "Launch a golem 150 studs up the Sky Shaft.",
		order = 9,
		map = "sky",
		golems = { { x = 0 } },
		props = {},
		zones = {},
		potions = { rocket_fuel = INF, kaboom_cocktail = INF, gravity_flip = 2 },
		objective = { event = "height", target = 150, mode = "max", text = "Height reached" },
		timeLimit = 120,
		stars = { 120, 40, 15 },
		reward = { coins = 450, xp = 560, ingredients = { star_shard = 1 } },
		requiresStars = 16,
	},
	{
		id = "domino",
		name = "Domino Lab",
		icon = "🏭",
		description = "Knock out six golems in the Crusher Works.",
		order = 10,
		map = "crusher",
		golems = { { x = -40 }, { x = -24 }, { x = -8 }, { x = 8 }, { x = 24 }, { x = 40 } },
		props = {},
		zones = {},
		potions = { kaboom_cocktail = INF, storm_bottle = INF, tornado_tonic = 1 },
		objective = { event = "ko", target = 6, mode = "count", unique = true, text = "Golems knocked out" },
		timeLimit = 150,
		stars = { 150, 70, 35 },
		reward = { coins = 520, xp = 650, ingredients = { void_salt = 2 } },
		requiresStars = 18,
	},
	{
		id = "magnum_opus",
		name = "Magnum Opus",
		icon = "💎",
		description = "The final trial. Trigger 5 reactions to forge the Philosopher's Stone.",
		order = 11,
		map = "lab",
		golems = { { x = -30 }, { x = -10 }, { x = 10 }, { x = 30 } },
		props = {},
		zones = {},
		potions = {
			inferno_brew = INF,
			frost_tonic = INF,
			storm_bottle = INF,
			sticky_slime = INF,
			balloon_brew = INF,
			giants_draught = INF,
			kaboom_cocktail = INF,
			healing_elixir = INF,
			reanimation_serum = INF,
			rocket_fuel = INF,
			ghost_essence = INF,
		},
		objective = { event = "reaction", target = 5, mode = "count", text = "Reactions triggered" },
		timeLimit = 240,
		stars = { 240, 120, 60 },
		reward = {
			coins = 1000,
			xp = 1500,
			ingredients = { philosophers_stone = 1, star_shard = 1, dragon_scale = 1 },
		},
		requiresStars = 20,
		final = true,
	},
}

local Challenges = {
	Daily = Daily,
	DailyById = {} :: { [string]: DailyTemplate },
	Trials = Trials,
	TrialsById = {} :: { [string]: Trial },
	DailyCount = 3,
	DailyRewards = {
		coins = { 60, 110, 180 },
		xp = { 50, 90, 150 },
	},
}

for _, template in Daily do
	Challenges.DailyById[template.id] = template
end
for _, trial in Trials do
	Challenges.TrialsById[trial.id] = trial
end
table.sort(Trials, function(a, b)
	return a.order < b.order
end)

-- Stars earned for a completion time (0 if over the limit).
function Challenges.starsFor(trial: Trial, seconds: number): number
	if seconds > trial.timeLimit then
		return 0
	end
	local stars = 1
	if seconds <= trial.stars[2] then
		stars = 2
	end
	if seconds <= trial.stars[3] then
		stars = 3
	end
	return stars
end

return Challenges
