--!strict
-- Part-built pets (no meshes, no uploaded assets). Shared: the client builds followers, hatch
-- reveals and ViewportFrame cards; the server may build displays.
--
-- Contract: anchored Model, PrimaryPart = "Root" (invisible) at the body centre, the pet faces
-- Root's LookVector (local -Z), +Y is up and the overall height is about `size` studs (long ears
-- and wings add a little). Templates are authored in units of `size`, feet at y = -0.5.
-- ViewportFrame cameras that sit on +Z must yaw the model by math.pi to show the face.
local Pets = require(script.Parent.Parent.Definitions.Pets)
local Kit = require(script.Parent.FactoryKit)

local PetFactory = {}

type Ctx = {
	b: Kit.Builder,
	U: number, -- studs per unit (= size)
	Body: Color3,
	Accent: Color3,
	Glow: boolean,
	Mat: Enum.Material, -- accent material (Neon when glowing)
	V: Pets.PetVisual,
}

local Sides = Kit.Sides
local WHITE = Color3.fromRGB(255, 255, 255)
local PUPIL = Color3.fromRGB(24, 24, 32)
local NOSE = Color3.fromRGB(46, 38, 44)
local BLUSH = Color3.fromRGB(255, 140, 170)
local BEAK = Color3.fromRGB(255, 176, 32)

local DEFAULT_VISUAL: Pets.PetVisual = { Template = "Critter", Body = "#C9D3E0", Accent = "#FFFFFF", Ears = "Round" }

local function at(c: Ctx, x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z) * c.U
end

local function ball(c: Ctx, d: number, x: number, y: number, z: number, color: Color3, material: Enum.Material?): BasePart
	return Kit.Ball(c.b, d * c.U, at(c, x, y, z), color, material)
end

local function tri(c: Ctx, p1: Vector3, p2: Vector3, p3: Vector3, thick: number, color: Color3, material: Enum.Material?)
	Kit.Tri(c.b, p1, p2, p3, thick * c.U, color, material)
end

-- Rough colour distance, used to keep beaks and noses readable on similar bodies.
local function near(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.45
end

-- One cute eye: white ball, big pupil pushed forward, small highlight. `white` is the eye centre in
-- studs, `dir` the unit direction it looks, `d` the white's diameter in units.
local function eye(c: Ctx, white: Vector3, dir: Vector3, d: number, side: number)
	local rw = d * c.U / 2
	Kit.Ball(c.b, rw * 2, white, WHITE)
	local rp = rw * 0.64
	local pupil = white + dir * (rw - rp * 0.5)
	Kit.Ball(c.b, rp * 2, pupil, PUPIL)
	local glint = (dir * 0.7 + Vector3.new(-0.3 * side, 0.55, 0)).Unit
	Kit.Ball(c.b, rp * 0.62, pupil + glint * rp * 0.82, WHITE)
end

-- A pair of eyes on a sphere (centre in units, radius in units).
local function eyesOnSphere(c: Ctx, cx: number, cy: number, cz: number, radius: number, d: number, spread: number, lift: number)
	local center = at(c, cx, cy, cz)
	for _, s in Sides do
		local dir = Vector3.new(spread * s, lift, -1).Unit
		eye(c, center + dir * (radius - d * 0.18) * c.U, dir, d, s)
	end
end

-- Blush spots under the eyes.
local function cheeks(c: Ctx, cx: number, cy: number, cz: number, radius: number, spread: number, lift: number)
	local center = at(c, cx, cy, cz)
	for _, s in Sides do
		local dir = Vector3.new(spread * s, lift, -1).Unit
		local p = Kit.Ball(c.b, 0.08 * c.U, center + dir * (radius - 0.025) * c.U, BLUSH)
		p.Transparency = 0.25
	end
end

-- Two small cone horns sweeping back from (x, y, z).
local function horns(c: Ctx, x: number, y: number, z: number, len: number, color: Color3)
	for _, s in Sides do
		Kit.Spike(c.b, at(c, x * s, y, z), at(c, (x + len * 0.35) * s, y + len, z + len * 0.45), 0.05 * c.U, color, c.Mat)
	end
end

local function ears(c: Ctx, kind: string?, hx: number, hy: number, hz: number, hr: number)
	local body, accent = c.Body, c.Accent
	local top = hy + hr
	if kind == "Pointy" then
		for _, s in Sides do
			tri(c, at(c, 0.06 * s, top - 0.07, hz + 0.02), at(c, 0.27 * s, top - 0.15, hz + 0.04), at(c, 0.22 * s, top + 0.14, hz + 0.06), 0.07, body)
			tri(c, at(c, 0.11 * s, top - 0.06, hz - 0.02), at(c, 0.23 * s, top - 0.1, hz - 0.01), at(c, 0.205 * s, top + 0.08, hz + 0.02), 0.04, accent, c.Mat)
		end
	elseif kind == "Round" then
		for _, s in Sides do
			ball(c, 0.2, 0.2 * s, top - 0.04, hz + 0.04, body)
			ball(c, 0.12, 0.205 * s, top - 0.04, hz - 0.02, accent, c.Mat)
		end
	elseif kind == "Long" then
		for _, s in Sides do
			local base, tip = at(c, 0.1 * s, top - 0.06, hz + 0.04), at(c, 0.16 * s, top + 0.22, hz + 0.08)
			Kit.Rod(c.b, base, tip, 0.13 * c.U, body)
			Kit.Ball(c.b, 0.13 * c.U, tip, body)
			Kit.Bar(c.b, base + at(c, 0, 0.04, -0.06), tip + at(c, 0, -0.02, -0.055), 0.06 * c.U, 0.02 * c.U, accent, c.Mat, Vector3.zAxis)
		end
	end
end

-- Round critter: big head, belly, muzzle, ears by type, little feet, tail.
local function critter(c: Ctx)
	local V, body, accent = c.V, c.Body, c.Accent
	ball(c, 0.52, 0, -0.2, 0.04, body)
	ball(c, 0.36, 0, -0.22, -0.1, accent)
	for _, s in Sides do
		ball(c, 0.16, 0.13 * s, -0.42, -0.1, Kit.Shade(body, -0.08))
	end
	ball(c, 0.6, 0, 0.12, -0.04, body) -- head
	ball(c, 0.22, 0, 0.03, -0.3, accent) -- muzzle
	ball(c, 0.07, 0, 0.09, -0.4, if near(accent, NOSE) then Kit.Shade(body, -0.6) else NOSE)
	eyesOnSphere(c, 0, 0.12, -0.04, 0.3, 0.17, 0.4, 0.22)
	cheeks(c, 0, 0.12, -0.04, 0.3, 0.62, -0.05)
	ears(c, V.Ears, 0, 0.12, -0.04, 0.3)
	if V.Ears == "Pointy" then
		Kit.Rod(c.b, at(c, 0, -0.27, 0.24), at(c, 0, -0.02, 0.44), 0.12 * c.U, body)
		ball(c, 0.16, 0, 0.0, 0.45, accent, c.Mat)
	else
		ball(c, 0.18, 0, -0.25, 0.3, accent, c.Mat)
	end
	if V.Horns then
		Kit.Spike(c.b, at(c, 0, 0.36, -0.16), at(c, 0, 0.6, -0.24), 0.055 * c.U, Kit.Shade(accent, 0.25), c.Mat)
	end
	if V.Wings then
		for _, s in Sides do
			tri(c, at(c, 0.1 * s, -0.08, 0.24), at(c, 0.52 * s, 0.18, 0.34), at(c, 0.22 * s, -0.3, 0.32), 0.04, accent, c.Mat)
		end
	end
end

-- Round bird: body + belly, head with a two-piece beak, spread or folded wings, tail fan.
local function bird(c: Ctx)
	local V, body, accent = c.V, c.Body, c.Accent
	local beak = if near(body, BEAK) then Kit.Shade(body, -0.5) else BEAK
	ball(c, 0.62, 0, -0.16, 0.03, body)
	ball(c, 0.44, 0, -0.2, -0.1, accent)
	ball(c, 0.5, 0, 0.19, -0.04, body) -- head
	local upper = Vector3.new(0.11, 0.065, 0.15) * c.U
	local lower = Vector3.new(0.09, 0.045, 0.12) * c.U
	Kit.Part(c.b, "Wedge", upper, CFrame.new(at(c, 0, 0.17, -0.33) + Vector3.yAxis * upper.Y / 2), beak)
	Kit.Part(c.b, "Wedge", lower, CFrame.new(at(c, 0, 0.17, -0.32) - Vector3.yAxis * lower.Y / 2) * CFrame.Angles(0, 0, math.pi), Kit.Shade(beak, -0.12))
	eyesOnSphere(c, 0, 0.19, -0.04, 0.25, 0.16, 0.48, 0.2)
	cheeks(c, 0, 0.19, -0.04, 0.25, 0.75, -0.12)
	for _, s in Sides do
		ball(c, 0.1, 0.11 * s, -0.46, -0.04, beak)
		if V.Wings then
			tri(c, at(c, 0.2 * s, -0.02, 0.0), at(c, 0.64 * s, 0.26, 0.16), at(c, 0.26 * s, -0.22, 0.2), 0.05, Kit.Shade(body, -0.06))
			tri(c, at(c, 0.24 * s, -0.04, 0.07), at(c, 0.52 * s, 0.1, 0.22), at(c, 0.28 * s, -0.22, 0.22), 0.06, accent, c.Mat)
		else
			tri(c, at(c, 0.27 * s, 0.0, -0.08), at(c, 0.3 * s, -0.12, 0.3), at(c, 0.28 * s, -0.3, 0.06), 0.06, Kit.Shade(body, -0.12))
		end
		if V.Ears == "Pointy" then
			tri(c, at(c, 0.07 * s, 0.38, -0.02), at(c, 0.2 * s, 0.33, 0.0), at(c, 0.2 * s, 0.54, 0.03), 0.05, Kit.Shade(body, -0.15))
		end
	end
	tri(c, at(c, -0.13, -0.06, 0.46), at(c, 0.13, -0.06, 0.46), at(c, 0, -0.16, 0.24), 0.05, accent, c.Mat) -- tail fan
	if c.Glow then
		tri(c, at(c, 0, 0.36, -0.12), at(c, 0, 0.4, 0.12), at(c, 0, 0.62, 0.06), 0.05, accent, c.Mat) -- flame crest
	end
end

-- Dome blob (slime / turtle): squashy dome on a puddle, shell spots, big eyes, optional horns.
local function blob(c: Ctx)
	local V, body, accent = c.V, c.Body, c.Accent
	ball(c, 0.88, 0, -0.06, 0, body)
	ball(c, 0.46, 0, 0.2, 0.05, body) -- soft peak
	Kit.Disc(c.b, at(c, 0, -0.465, 0.02), Vector3.yAxis, 0.98 * c.U, 0.07 * c.U, Kit.Shade(body, -0.06))
	eyesOnSphere(c, 0, -0.06, 0, 0.44, 0.22, 0.36, 0.24)
	cheeks(c, 0, -0.06, 0, 0.44, 0.6, -0.04)
	ball(c, 0.08, 0, -0.17, -0.425, NOSE) -- little "o" mouth
	for _, dir in { Vector3.new(0.6, 0.55, 0.35), Vector3.new(-0.6, 0.55, 0.35), Vector3.new(0.35, 0.5, 0.8), Vector3.new(-0.35, 0.5, 0.8), Vector3.new(0, 0.3, 1) } do
		local p = Vector3.new(0, -0.06, 0) + dir.Unit * 0.4
		ball(c, 0.2, p.X, p.Y, p.Z, accent, c.Mat)
	end
	local gloss = ball(c, 0.11, -0.2, 0.2, -0.26, WHITE)
	gloss.Transparency = 0.35
	if V.Horns then
		horns(c, 0.14, 0.34, 0.04, 0.18, accent)
	end
end

-- Floating sea critter (ray / whale / shark): tapered body, belly, fins, flukes.
local function fish(c: Ctx)
	local V, body, accent = c.V, c.Body, c.Accent
	ball(c, 0.64, 0, 0, -0.08, body)
	ball(c, 0.46, 0, 0.0, 0.2, body)
	ball(c, 0.26, 0, 0.02, 0.38, body)
	ball(c, 0.52, 0, -0.12, -0.12, accent)
	eyesOnSphere(c, 0, 0, -0.08, 0.32, 0.17, 0.62, 0.18)
	cheeks(c, 0, 0, -0.08, 0.32, 0.9, -0.1)
	ball(c, 0.06, 0, -0.08, -0.395, NOSE)
	for _, s in Sides do
		tri(c, at(c, 0.25 * s, -0.08, -0.12), at(c, 0.3 * s, -0.1, 0.14), at(c, 0.56 * s, -0.24, 0.12), 0.05, accent, c.Mat)
		tri(c, at(c, 0, 0.03, 0.4), at(c, 0.3 * s, 0.11, 0.62), at(c, 0, 0.03, 0.56), 0.05, Kit.Shade(body, -0.08))
	end
	tri(c, at(c, 0, 0.26, -0.1), at(c, 0, 0.2, 0.24), at(c, 0, 0.5, 0.2), 0.05, accent, c.Mat) -- dorsal fin
	if V.Horns then
		horns(c, 0.1, 0.25, -0.18, 0.2, accent)
	end
end

-- Dragon: critter body with a snout, cone horns, membrane wings, back spikes and a spade tail.
local function dragon(c: Ctx)
	local body, accent = c.Body, c.Accent
	ball(c, 0.52, 0, -0.22, 0.06, body)
	ball(c, 0.36, 0, -0.24, -0.07, accent)
	for _, s in Sides do
		ball(c, 0.16, 0.13 * s, -0.43, -0.08, Kit.Shade(body, -0.1))
	end
	ball(c, 0.5, 0, 0.12, -0.06, body) -- head
	ball(c, 0.27, 0, 0.04, -0.3, Kit.Shade(body, 0.12)) -- snout
	for _, s in Sides do
		ball(c, 0.04, 0.05 * s, 0.1, -0.43, NOSE) -- nostrils
	end
	eyesOnSphere(c, 0, 0.12, -0.06, 0.25, 0.16, 0.42, 0.3)
	horns(c, 0.12, 0.3, 0.0, 0.2, Kit.Shade(accent, 0.2))
	for _, s in Sides do
		local shoulder = at(c, 0.14 * s, -0.04, 0.18)
		tri(c, shoulder, at(c, 0.58 * s, 0.32, 0.3), at(c, 0.44 * s, 0.02, 0.4), 0.04, accent, c.Mat)
		tri(c, shoulder, at(c, 0.44 * s, 0.02, 0.4), at(c, 0.26 * s, -0.16, 0.36), 0.04, Kit.Shade(accent, -0.15), c.Mat)
	end
	for i, a in { 0.7, 1.1, 1.5 } do
		local y, z = -0.22 + math.cos(a) * 0.25, 0.06 + math.sin(a) * 0.25
		local h = 0.11 - i * 0.015
		tri(c, at(c, 0, y, z - 0.04), at(c, 0, y, z + h), at(c, 0, y + h, z + h), 0.04, accent, c.Mat)
	end
	local tailEnd = at(c, 0, -0.22, 0.52)
	Kit.Rod(c.b, at(c, 0, -0.34, 0.24), tailEnd, 0.11 * c.U, body)
	Kit.Diamond(c.b, tailEnd + at(c, 0, 0.02, 0.04), Vector3.xAxis, 0.15 * c.U, 0.04 * c.U, accent, c.Mat)
end

-- Crab: wide shell, eye stalks, two big claws, little legs.
local function crab(c: Ctx)
	local body, accent = c.Body, c.Accent
	ball(c, 0.56, 0, -0.14, 0.02, body)
	for _, s in Sides do
		ball(c, 0.42, 0.2 * s, -0.18, 0.05, body)
		-- eye stalk + eye looking forward
		local top = at(c, 0.13 * s, 0.3, -0.12)
		Kit.Rod(c.b, at(c, 0.09 * s, 0.0, -0.08), top, 0.05 * c.U, Kit.Shade(body, -0.1))
		eye(c, top + at(c, 0, 0.04, 0), Vector3.new(0.15 * s, 0.1, -1).Unit, 0.17, s)
		-- claw: arm, round claw, upper pincer
		local claw = at(c, 0.45 * s, -0.04, -0.3)
		Kit.Rod(c.b, at(c, 0.3 * s, -0.16, -0.06), claw, 0.08 * c.U, body)
		Kit.Ball(c.b, 0.25 * c.U, claw, Kit.Shade(body, 0.05))
		tri(c, claw + at(c, -0.05 * s, 0.06, -0.06), claw + at(c, 0.07 * s, 0.06, -0.06), claw + at(c, 0.02 * s, 0.1, -0.22), 0.06, accent, c.Mat)
		-- legs
		for _, z in { 0.06, 0.2 } do
			Kit.Rod(c.b, at(c, 0.28 * s, -0.26, z), at(c, 0.46 * s, -0.46, z + 0.06), 0.06 * c.U, Kit.Shade(body, -0.15))
		end
	end
	ball(c, 0.12, 0.12, 0.1, 0.06, accent, c.Mat)
	ball(c, 0.09, -0.1, 0.11, 0.12, accent, c.Mat)
	ball(c, 0.06, 0, -0.12, -0.26, NOSE) -- mouth
end

-- Blocky bot (golem / treasure mimic): box body with a trim band, lid head over a dark mouth with
-- teeth, big eyes, arms with fists, glowing core.
local function bot(c: Ctx)
	local body, accent = c.Body, c.Accent
	local dark = Kit.Shade(body, -0.25)
	Kit.Block(c.b, at(c, 0.6, 0.44, 0.5), CFrame.new(at(c, 0, -0.2, 0.02)), body)
	Kit.Block(c.b, at(c, 0.62, 0.06, 0.52), CFrame.new(at(c, 0, -0.1, 0.02)), accent, c.Mat)
	Kit.Block(c.b, at(c, 0.52, 0.1, 0.44), CFrame.new(at(c, 0, 0.05, 0.03)), Color3.fromRGB(40, 20, 24)) -- mouth
	local hinge = CFrame.new(at(c, 0, 0.07, 0.29)) * CFrame.Angles(math.rad(10), 0, 0)
	local head = hinge * CFrame.new(at(c, 0, 0.16, -0.27))
	Kit.Block(c.b, at(c, 0.64, 0.3, 0.54), head, body)
	Kit.Block(c.b, at(c, 0.66, 0.06, 0.56), head * CFrame.new(at(c, 0, -0.1, 0)), accent, c.Mat)
	for _, s in Sides do
		eye(c, head * at(c, 0.14 * s, 0.04, -0.27), head.LookVector, 0.17, s)
		Kit.Block(c.b, at(c, 0.14, 0.28, 0.16), CFrame.new(at(c, 0.37 * s, -0.2, 0.0)), dark)
		Kit.Block(c.b, at(c, 0.18, 0.14, 0.2), CFrame.new(at(c, 0.38 * s, -0.37, -0.02)), accent, c.Mat)
		Kit.Block(c.b, at(c, 0.18, 0.08, 0.24), CFrame.new(at(c, 0.16 * s, -0.46, 0.0)), dark)
	end
	for i = -1, 1 do
		local x = i * 0.14
		local p = head * at(c, x - 0.04, -0.15, -0.255)
		tri(c, p, head * at(c, x + 0.04, -0.15, -0.255), head * at(c, x - 0.04, -0.23, -0.255), 0.03, WHITE)
	end
	Kit.Ball(c.b, 0.12 * c.U, at(c, 0, -0.24, -0.23), accent, Enum.Material.Neon) -- core / lock
end

local TEMPLATES: { [string]: (Ctx) -> () } = {
	Critter = critter,
	Bird = bird,
	Blob = blob,
	Fish = fish,
	Dragon = dragon,
	Crab = crab,
	Bot = bot,
}
PetFactory.Templates = { "Critter", "Bird", "Blob", "Fish", "Dragon", "Crab", "Bot" }

function PetFactory.Build(visual: Pets.PetVisual, size: number): Model
	local template = if TEMPLATES[visual.Template] then visual.Template else "Critter"
	local glow = visual.Glow == true
	local b = Kit.New("Pet_" .. template, size * 0.1)
	local c: Ctx = {
		b = b,
		U = math.max(0.1, size),
		Body = Kit.Color(visual.Body, Color3.fromRGB(201, 211, 224)),
		Accent = Kit.Color(visual.Accent, WHITE),
		Glow = glow,
		Mat = Kit.Mat(glow),
		V = visual,
	}
	TEMPLATES[template](c)
	if glow then
		Kit.Light(b, c.Accent, 1.2, size * 3)
		Kit.Sparkles(b, Kit.Shade(c.Accent, 0.3), 2, size * 0.12)
	end
	b.Model:SetAttribute("Template", template)
	return Kit.Finish(b, true)
end

local cache = Kit.NewCache(96)

-- Built once per (id, size) and cloned afterwards. Unknown ids get a plain grey critter.
function PetFactory.ForId(petId: string, size: number): Model
	local key = string.format("%s|%.2f", petId, size)
	local model = Kit.Cached(cache, key, function()
		local pet = Pets.Get(petId)
		return PetFactory.Build(if pet then pet.Visual else DEFAULT_VISUAL, size)
	end)
	model.Name = petId
	return model
end

-- Builds every pet and every template/flag combination once, destroys them, returns true.
-- Studio command bar: require(game.ReplicatedStorage.Shared.Visual.PetFactory).Validate()
function PetFactory.Validate(): boolean
	local visuals: { Pets.PetVisual } = {}
	for _, pet in Pets.List do
		table.insert(visuals, pet.Visual)
	end
	for _, template in PetFactory.Templates do
		for _, ear in { "Pointy", "Round", "Long", "None" } do
			table.insert(visuals, { Template = template, Body = "#FFFFFF", Accent = "#3FA9FF", Ears = ear, Wings = true, Horns = true, Glow = true })
		end
	end
	table.insert(visuals, { Template = "NoSuchTemplate", Body = "oops", Accent = "#000000" })
	for _, visual in visuals do
		local model = PetFactory.Build(visual, 3)
		assert(model.PrimaryPart and model.PrimaryPart.Name == "Root", "pet without Root")
		assert(Kit.PartCount(model) >= 5, "pet " .. visual.Template .. " has too few parts")
		model:Destroy()
	end
	PetFactory.ForId("no_such_pet", 2):Destroy()
	return true
end

return PetFactory
