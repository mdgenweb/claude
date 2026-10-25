--[[
	Worlds
	Five Elmore locations x five acts. Paths are local to the arena origin (map spans roughly x -70..70, z -50..50).
	Each act raises wave count and HP; the final wave is the world boss.
]]

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function path(points: { { number } }): { Vector3 }
	local out = {}
	for _, point in points do
		table.insert(out, Vector3.new(point[1], 0.6, point[2]))
	end
	return out
end

local Worlds = {
	{
		id = "ElmoreJuniorHigh",
		name = "Elmore Junior High",
		subtitle = "Something escaped detention.",
		hpMult = 1,
		roster = { "Glitchling", "StaticBlob", "LostSock" },
		newEnemies = { "Glitchling", "StaticBlob", "LostSock" },
		boss = "HallMonster",
		theme = {
			ground = rgb(118, 200, 92),
			groundMaterial = Enum.Material.Grass,
			path = rgb(214, 200, 180),
			pathMaterial = Enum.Material.Concrete,
			pathEdge = rgb(170, 150, 130),
			accent = rgb(255, 214, 70),
			sky = rgb(150, 210, 255),
			props = "school",
		},
		path = path({ { -66, 30 }, { -30, 30 }, { -30, -10 }, { 10, -10 }, { 10, 30 }, { 45, 30 }, { 45, -30 }, { 66, -30 } }),
	},
	{
		id = "WattersonStreet",
		name = "Watterson Street",
		subtitle = "The neighbourhood is getting weird(er).",
		hpMult = 2.2,
		roster = { "Glitchling", "StaticBlob", "LostSock", "PixelBat", "Splitter" },
		newEnemies = { "PixelBat", "Splitter" },
		boss = "GnomeKing",
		theme = {
			ground = rgb(104, 190, 96),
			groundMaterial = Enum.Material.Grass,
			path = rgb(80, 82, 92),
			pathMaterial = Enum.Material.Asphalt,
			pathEdge = rgb(230, 230, 230),
			accent = rgb(255, 120, 120),
			sky = rgb(170, 220, 255),
			props = "suburb",
		},
		path = path({
			{ -66, -35 },
			{ -40, -35 },
			{ -40, 35 },
			{ -5, 35 },
			{ -5, -25 },
			{ 30, -25 },
			{ 30, 25 },
			{ 66, 25 },
		}),
	},
	{
		id = "ElmoreMall",
		name = "Elmore Mall",
		subtitle = "Clearance sale on chaos.",
		hpMult = 4.5,
		roster = { "Glitchling", "StaticBlob", "PixelBat", "Splitter", "FloppyGolem", "GhostPixel" },
		newEnemies = { "FloppyGolem", "GhostPixel" },
		boss = "MallBot",
		theme = {
			ground = rgb(236, 226, 214),
			groundMaterial = Enum.Material.CeramicTiles,
			path = rgb(255, 200, 120),
			pathMaterial = Enum.Material.SmoothPlastic,
			pathEdge = rgb(220, 150, 80),
			accent = rgb(120, 200, 255),
			sky = rgb(255, 230, 200),
			props = "mall",
		},
		path = path({
			{ -66, 0 },
			{ -45, 0 },
			{ -45, -35 },
			{ -15, -35 },
			{ -15, 35 },
			{ 20, 35 },
			{ 20, -15 },
			{ 50, -15 },
			{ 50, 20 },
			{ 66, 20 },
		}),
	},
	{
		id = "ElmoreWoods",
		name = "Elmore Woods",
		subtitle = "Don't go near the lake.",
		hpMult = 8,
		roster = { "Glitchling", "LostSock", "PixelBat", "Splitter", "FloppyGolem", "GhostPixel", "HealerBug" },
		newEnemies = { "HealerBug" },
		boss = "WoodsKraken",
		theme = {
			ground = rgb(86, 160, 80),
			groundMaterial = Enum.Material.LeafyGrass,
			path = rgb(150, 110, 70),
			pathMaterial = Enum.Material.Ground,
			pathEdge = rgb(110, 80, 50),
			accent = rgb(120, 255, 160),
			sky = rgb(200, 240, 210),
			props = "woods",
		},
		path = path({
			{ -66, 40 },
			{ -20, 40 },
			{ -20, 10 },
			{ -50, 10 },
			{ -50, -30 },
			{ 0, -30 },
			{ 0, 5 },
			{ 35, 5 },
			{ 35, -35 },
			{ 66, -35 },
		}),
	},
	{
		id = "TheVoid",
		name = "The Void",
		subtitle = "Where Elmore's mistakes go. Including you.",
		hpMult = 14,
		roster = {
			"Glitchling",
			"StaticBlob",
			"LostSock",
			"PixelBat",
			"Splitter",
			"FloppyGolem",
			"GhostPixel",
			"HealerBug",
			"VoidKnight",
		},
		newEnemies = { "VoidKnight" },
		boss = "VoidHeart",
		theme = {
			ground = rgb(48, 22, 78),
			groundMaterial = Enum.Material.SmoothPlastic,
			path = rgb(120, 70, 190),
			pathMaterial = Enum.Material.Neon,
			pathEdge = rgb(200, 120, 255),
			accent = rgb(220, 100, 255),
			sky = rgb(30, 10, 50),
			props = "void",
			dark = true,
		},
		path = path({
			{ -66, -40 },
			{ 50, -40 },
			{ 50, 30 },
			{ -40, 30 },
			{ -40, -15 },
			{ 25, -15 },
			{ 25, 8 },
			{ -10, 8 },
		}),
	},
}

local byId = {}
for index, world in Worlds do
	world.order = index
	byId[world.id] = world
end

local module = {
	ordered = Worlds,
	byId = byId,
	ACTS = 5,
}

function module.get(id: string)
	return byId[id]
end

function module.wavesForAct(act: number): number
	return 8 + 2 * act
end

function module.actHpMult(act: number): number
	return 1 + 0.35 * (act - 1)
end

-- Story key used in profile progress, e.g. "ElmoreMall:3"
function module.stageKey(worldId: string, act: number): string
	return worldId .. ":" .. act
end

return module
