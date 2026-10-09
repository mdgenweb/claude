--!strict
-- Part-built eggs (no meshes, no uploaded assets) for the egg row, hatch animations and shop cards.
--
-- Contract: anchored Model, PrimaryPart = "Root" (invisible) at the egg's centre, +Y up, overall
-- height = `height` studs and width about 0.76 x height. Ball parts are always round in Roblox, so
-- the egg silhouette is a stack of six balls fitted to an egg profile (wider below the middle);
-- decorations sit on the analytic profile. Each egg gets a deterministic pattern of egg.Accent
-- (spots, bands, or a band with dots); Robux eggs (egg.ProductKey) add a Neon rim, floating Neon
-- sparkles, a PointLight and sparkle particles.
local Eggs = require(script.Parent.Parent.Definitions.Eggs)
local Kit = require(script.Parent.FactoryKit)

local EggFactory = {}

-- (centre y, radius) per ball in units of the egg height; fitted offline to PROFILE below.
local STACK = {
	{ -0.128, 0.371 },
	{ -0.048, 0.378 },
	{ 0.051, 0.354 },
	{ 0.151, 0.309 },
	{ 0.249, 0.245 },
	{ 0.409, 0.091 },
}

EggFactory.WidthRatio = 0.76

-- Egg radius at height y (units, -0.5..0.5): an ellipse squeezed toward the top.
local function profile(y: number): number
	local t = math.clamp(y / 0.5, -1, 1)
	return 0.375 * math.sqrt(1 - t * t) * (1 - 0.16 * t)
end

-- Point on the egg surface and its outward normal, for height y and angle a (a = 0 faces -Z).
local function surface(y: number, a: number): (Vector3, Vector3)
	local r = profile(y)
	local slope = (profile(y + 0.005) - profile(y - 0.005)) / 0.01
	local radial = Vector3.new(math.sin(a), 0, -math.cos(a))
	local normal = (radial - Vector3.yAxis * slope).Unit
	return radial * r + Vector3.yAxis * y, normal
end

type Ctx = { b: Kit.Builder, H: number, Accent: Color3, Mat: Enum.Material }

local function spot(c: Ctx, y: number, a: number, diameter: number)
	local p, n = surface(y, a)
	local thick = 0.035
	Kit.Disc(c.b, (p - n * (thick / 2 - 0.006)) * c.H, n, diameter * c.H, thick * c.H, c.Accent, c.Mat)
end

local function band(c: Ctx, y: number, thick: number, color: Color3, material: Enum.Material?)
	local r = math.max(profile(y - thick / 2), profile(y + thick / 2)) + 0.004
	Kit.Disc(c.b, Vector3.new(0, y, 0) * c.H, Vector3.yAxis, r * 2 * c.H, thick * c.H, color, material)
end

-- Golden-angle spiral of spots between two heights.
local function spots(c: Ctx, count: number, y0: number, y1: number, offset: number, diameter: number)
	for i = 0, count - 1 do
		local y = y0 + (y1 - y0) * (i + 0.5) / count
		spot(c, y, offset + i * 2.39996, diameter * (profile(y) / 0.375) ^ 0.5)
	end
end

function EggFactory.Build(egg: Eggs.Egg, height: number): Model
	local H = math.max(0.2, height)
	local b = Kit.New("Egg_" .. egg.Id, H * 0.1)
	local robux = egg.ProductKey ~= nil
	local base = Kit.Color(egg.Color, Color3.fromRGB(255, 240, 210))
	local c: Ctx = {
		b = b,
		H = H,
		Accent = Kit.Color(egg.Accent, Color3.fromRGB(80, 170, 255)),
		Mat = if robux then Enum.Material.Neon else Enum.Material.SmoothPlastic,
	}
	for _, ball in STACK do
		Kit.Ball(b, ball[2] * 2 * H, Vector3.new(0, ball[1] * H, 0), base)
	end
	local hash = Kit.Hash(egg.Id)
	local offset = (hash % 628) / 100
	local pattern = hash % 3
	if robux then
		spots(c, 7, -0.34, 0.36, offset, 0.15)
		band(c, -0.05, 0.06, c.Accent, Enum.Material.Neon)
		for i = 0, 3 do
			local a = offset + i * math.pi / 2 + math.pi / 4
			local y = if i % 2 == 0 then 0.32 else -0.2
			local p, n = surface(y, a)
			Kit.Diamond(b, (p + n * 0.11) * H, n, 0.07 * H, 0.02 * H, Kit.Shade(c.Accent, 0.35), Enum.Material.Neon)
		end
		Kit.Light(b, c.Accent, 1.5, H * 2.5)
		Kit.Sparkles(b, Kit.Shade(c.Accent, 0.4), 4, H * 0.12)
	elseif pattern == 0 then
		spots(c, 8, -0.36, 0.36, offset, 0.17)
	elseif pattern == 1 then
		band(c, 0.1, 0.05, c.Accent)
		band(c, -0.05, 0.035, Kit.Shade(c.Accent, 0.25))
		band(c, -0.2, 0.05, c.Accent)
	else
		band(c, -0.05, 0.08, c.Accent)
		for i = 0, 3 do
			spot(c, 0.2, offset + i * math.pi / 2, 0.14)
			spot(c, -0.3, offset + (i + 0.5) * math.pi / 2, 0.13)
		end
	end
	b.Model:SetAttribute("EggId", egg.Id)
	return Kit.Finish(b, true)
end

local cache = Kit.NewCache(32)

-- Built once per (id, height) and cloned afterwards. Unknown ids get the first egg's look.
function EggFactory.ForId(eggId: string, height: number): Model
	local key = string.format("%s|%.2f", eggId, height)
	local model = Kit.Cached(cache, key, function()
		local egg = Eggs.Get(eggId) or Eggs.List[1]
		return EggFactory.Build(egg, height)
	end)
	model.Name = eggId
	return model
end

-- Builds every egg once, destroys them, returns true.
-- Studio command bar: require(game.ReplicatedStorage.Shared.Visual.EggFactory).Validate()
function EggFactory.Validate(): boolean
	for _, egg in Eggs.List do
		local model = EggFactory.Build(egg, 5)
		assert(model.PrimaryPart and model.PrimaryPart.Name == "Root", "egg without Root")
		assert(Kit.PartCount(model) >= #STACK, "egg " .. egg.Id .. " has too few parts")
		model:Destroy()
	end
	EggFactory.ForId("no_such_egg", 3):Destroy()
	return true
end

return EggFactory
