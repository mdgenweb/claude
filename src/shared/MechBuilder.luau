-- Builds the blocky robot from the concept sheet (box head, screen eyes, broad
-- shoulders, block limbs, wrist tool socket) on top of one shared R15 rig.
--
-- Scrap Bot (levels 0-3) -> Crusher (4-6) -> Mega Mech (7-9), with smaller milestone
-- changes in between: bigger forearms, tool, shoulders, upper body, reactor and crest.
-- The same code dresses a live character (parts welded to limbs) and builds anchored
-- statues / UI previews from a virtual rig, so every view of the mech matches.

local Config = require(script.Parent.Config)
local Economy = require(script.Parent.Economy)

local MechBuilder = {}

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

export type Palette = {
	Primary: Color3,
	Secondary: Color3,
	Dark: Color3,
	Eyes: Color3,
	Trim: Color3,
	Glow: Color3,
	Screen: Color3,
	PrimaryMaterial: Enum.Material,
	Reflectance: number,
	Stripes: boolean?,
	Seams: boolean?,
}

local FORM_PALETTES: { [string]: Palette } = {
	ScrapBot = {
		Primary = hex("#B0683C"),
		Secondary = hex("#737A84"),
		Dark = hex("#30353C"),
		Eyes = hex("#45D4FF"),
		Trim = hex("#D9A441"),
		Glow = hex("#FF5A3C"),
		Screen = hex("#0B1A24"),
		PrimaryMaterial = Enum.Material.CorrodedMetal,
		Reflectance = 0,
	},
	Crusher = {
		Primary = hex("#FF8A1F"),
		Secondary = hex("#434A54"),
		Dark = hex("#23272E"),
		Eyes = hex("#45D4FF"),
		Trim = hex("#FFC61A"),
		Glow = hex("#45D4FF"),
		Screen = hex("#0B1A24"),
		PrimaryMaterial = Enum.Material.SmoothPlastic,
		Reflectance = 0,
	},
	MegaMech = {
		Primary = hex("#FF7A00"),
		Secondary = hex("#30353E"),
		Dark = hex("#16191E"),
		Eyes = hex("#3DF0FF"),
		Trim = hex("#FFD23F"),
		Glow = hex("#FF5A1F"),
		Screen = hex("#071018"),
		PrimaryMaterial = Enum.Material.SmoothPlastic,
		Reflectance = 0.05,
	},
}

local FINISH_PALETTES: { [string]: Palette } = {
	Worker = {
		Primary = hex("#FFC61A"),
		Secondary = hex("#2E2E2E"),
		Dark = hex("#161616"),
		Eyes = hex("#FF9F1A"),
		Trim = hex("#111111"),
		Glow = hex("#FF9F1A"),
		Screen = hex("#120C02"),
		PrimaryMaterial = Enum.Material.SmoothPlastic,
		Reflectance = 0,
		Stripes = true,
	},
	Lime = {
		Primary = hex("#7BEA2E"),
		Secondary = hex("#2F3A2A"),
		Dark = hex("#1A2016"),
		Eyes = hex("#E8FF5A"),
		Trim = hex("#FFFFFF"),
		Glow = hex("#C8FF3A"),
		Screen = hex("#0C1406"),
		PrimaryMaterial = Enum.Material.SmoothPlastic,
		Reflectance = 0,
	},
	Chrome = {
		Primary = hex("#D7DEE8"),
		Secondary = hex("#5E6B7D"),
		Dark = hex("#2A3240"),
		Eyes = hex("#4DA6FF"),
		Trim = hex("#2F80FF"),
		Glow = hex("#4DA6FF"),
		Screen = hex("#08101C"),
		PrimaryMaterial = Enum.Material.Metal,
		Reflectance = 0.25,
	},
	Foundry = {
		Primary = hex("#2A2A30"),
		Secondary = hex("#4A4A52"),
		Dark = hex("#101014"),
		Eyes = hex("#FF6A00"),
		Trim = hex("#FFB800"),
		Glow = hex("#FF4D00"),
		Screen = hex("#160800"),
		PrimaryMaterial = Enum.Material.Metal,
		Reflectance = 0.1,
		Seams = true,
	},
}

local METAL = hex("#C9CED6")

-- Growth per upgrade level 0..9: {armor, forearm, tool, shoulder, chest}
local GROWTH = {
	[0] = { 0.9, 1.0, 1.0, 1.0, 1.0 },
	[1] = { 0.9, 1.0, 1.0, 1.0, 1.0 },
	[2] = { 0.95, 1.25, 1.0, 1.0, 1.0 },
	[3] = { 0.95, 1.25, 1.25, 1.0, 1.0 },
	[4] = { 1.0, 1.3, 1.25, 1.1, 1.05 },
	[5] = { 1.0, 1.3, 1.25, 1.3, 1.05 },
	[6] = { 1.03, 1.32, 1.3, 1.32, 1.2 },
	[7] = { 1.06, 1.4, 1.35, 1.4, 1.25 },
	[8] = { 1.06, 1.4, 1.6, 1.4, 1.25 },
	[9] = { 1.12, 1.45, 1.7, 1.5, 1.32 },
}

function MechBuilder.palette(level: number, finishId: string?): Palette
	local finish = finishId and FINISH_PALETTES[finishId]
	if finish then
		return finish
	end
	return FORM_PALETTES[Economy.formFor(level).Id]
end

function MechBuilder.growth(level: number)
	local g = GROWTH[math.clamp(level, 0, 9)]
	return { armor = g[1], forearm = g[2], tool = g[3], shoulder = g[4], chest = g[5] }
end

-- Rig slots -------------------------------------------------------------------

local SLOTS = {
	"Head",
	"UpperTorso",
	"LowerTorso",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
}

-- R6 fallback: which R6 part (and offset inside it) stands in for each R15 slot.
local R6_MAP = {
	Head = { "Head", Vector3.new(0, 0, 0) },
	UpperTorso = { "Torso", Vector3.new(0, 0.3, 0) },
	LowerTorso = { "Torso", Vector3.new(0, -0.8, 0) },
	LeftUpperArm = { "Left Arm", Vector3.new(0, 0.45, 0) },
	LeftLowerArm = { "Left Arm", Vector3.new(0, -0.45, 0) },
	LeftHand = { "Left Arm", Vector3.new(0, -0.9, 0) },
	RightUpperArm = { "Right Arm", Vector3.new(0, 0.45, 0) },
	RightLowerArm = { "Right Arm", Vector3.new(0, -0.45, 0) },
	RightHand = { "Right Arm", Vector3.new(0, -0.9, 0) },
	LeftUpperLeg = { "Left Leg", Vector3.new(0, 0.5, 0) },
	LeftLowerLeg = { "Left Leg", Vector3.new(0, -0.35, 0) },
	LeftFoot = { "Left Leg", Vector3.new(0, -0.85, 0) },
	RightUpperLeg = { "Right Leg", Vector3.new(0, 0.5, 0) },
	RightLowerLeg = { "Right Leg", Vector3.new(0, -0.35, 0) },
	RightFoot = { "Right Leg", Vector3.new(0, -0.85, 0) },
}

-- Default R15 block-rig limb centres relative to HumanoidRootPart (scale 1).
local VIRTUAL_RIG = {
	Head = Vector3.new(0, 1.55, 0),
	UpperTorso = Vector3.new(0, 0.2, 0),
	LowerTorso = Vector3.new(0, -0.8, 0),
	LeftUpperArm = Vector3.new(-1.5, 0.42, 0),
	LeftLowerArm = Vector3.new(-1.5, -0.62, 0),
	LeftHand = Vector3.new(-1.5, -1.3, 0),
	RightUpperArm = Vector3.new(1.5, 0.42, 0),
	RightLowerArm = Vector3.new(1.5, -0.62, 0),
	RightHand = Vector3.new(1.5, -1.3, 0),
	LeftUpperLeg = Vector3.new(-0.5, -1.6, 0),
	LeftLowerLeg = Vector3.new(-0.5, -2.45, 0),
	LeftFoot = Vector3.new(-0.5, -2.85, 0),
	RightUpperLeg = Vector3.new(0.5, -1.6, 0),
	RightLowerLeg = Vector3.new(0.5, -2.45, 0),
	RightFoot = Vector3.new(0.5, -2.85, 0),
}
MechBuilder.RootHeight = 3 -- root centre above the ground at scale 1

type Limb = { part: BasePart?, cframe: CFrame }
type Ctx = {
	parent: Instance,
	scale: number,
	palette: Palette,
	level: number,
	growth: { armor: number, forearm: number, tool: number, shoulder: number, chest: number },
}

local function newPart(
	ctx: Ctx,
	limb: Limb,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local s = ctx.scale
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = size * s
	local o = offset
	p.CFrame = limb.cframe * CFrame.new(o.Position * s) * o.Rotation
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	if material == Enum.Material.Neon then
		p.CastShadow = false
	end
	if limb.part then
		p.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = limb.part
		weld.Part1 = p
		weld.Parent = p
	else
		p.Anchored = true
	end
	p.Parent = ctx.parent
	return p
end

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

local function primary(ctx: Ctx, limb: Limb, name: string, size: Vector3, offset: CFrame)
	local p = newPart(ctx, limb, name, size, offset, ctx.palette.Primary, ctx.palette.PrimaryMaterial)
	p.Reflectance = ctx.palette.Reflectance
	return p
end

local function stripes(ctx: Ctx, limb: Limb, width: number, height: number, frontZ: number)
	-- Diagonal hazard stripes for the Worker shell.
	for i = -1, 1 do
		newPart(
			ctx,
			limb,
			"Stripe",
			Vector3.new(0.16, height, 0.05),
			at(i * width * 0.3, 0, frontZ) * CFrame.Angles(0, 0, math.rad(35)),
			ctx.palette.Trim
		)
	end
end

-- Body parts ------------------------------------------------------------------

local function buildHead(ctx: Ctx, limb: Limb)
	local form = Economy.formFor(ctx.level).Id
	local pal = ctx.palette
	local k = if form == "ScrapBot" then 0.9 elseif form == "Crusher" then 1 elseif ctx.level >= 9 then 1.16 else 1.1
	local w, h, d = 1.7 * k, 1.25 * k, 1.4 * k
	primary(ctx, limb, "HeadBox", Vector3.new(w, h, d), at(0, 0.12, 0))
	newPart(ctx, limb, "Screen", Vector3.new(w * 0.8, h * 0.62, 0.1), at(0, 0.14, -d / 2 - 0.03), pal.Screen)
	for side = -1, 1, 2 do
		newPart(
			ctx,
			limb,
			"Eye",
			Vector3.new(0.3 * k, 0.3 * k, 0.08),
			at(side * 0.32 * k, 0.18, -d / 2 - 0.09),
			pal.Eyes,
			Enum.Material.Neon
		)
		newPart(
			ctx,
			limb,
			"EarBolt",
			Vector3.new(0.22, 0.5 * k, 0.5 * k),
			at(side * (w / 2 + 0.08), 0.1, 0),
			pal.Secondary,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
	end
	newPart(ctx, limb, "Chin", Vector3.new(w * 0.6, 0.18, 0.12), at(0, 0.12 - h * 0.4, -d / 2 - 0.02), pal.Secondary)
	if form == "ScrapBot" then
		newPart(ctx, limb, "Antenna", Vector3.new(0.08, 0.7, 0.08), at(0.35, 0.12 + h / 2 + 0.35, 0), pal.Secondary)
		newPart(
			ctx,
			limb,
			"AntennaTip",
			Vector3.new(0.26, 0.26, 0.26),
			at(0.35, 0.12 + h / 2 + 0.72, 0),
			pal.Glow,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		newPart(
			ctx,
			limb,
			"Patch",
			Vector3.new(0.45, 0.35, 0.05),
			at(-0.45, 0.12 + h / 2 - 0.2, -d / 2 - 0.01) * CFrame.Angles(0, 0, 0.2),
			pal.Secondary
		)
	elseif form == "Crusher" then
		newPart(
			ctx,
			limb,
			"TopVent",
			Vector3.new(w * 0.55, 0.18, d * 0.6),
			at(0, 0.12 + h / 2 + 0.09, 0),
			pal.Secondary
		)
	else
		newPart(ctx, limb, "Crest", Vector3.new(0.25, 0.45, d * 0.85), at(0, 0.12 + h / 2 + 0.22, 0), pal.Trim)
		if ctx.level >= 9 then
			for side = -1, 1, 2 do
				newPart(
					ctx,
					limb,
					"Horn",
					Vector3.new(0.22, 0.75, 0.22),
					at(side * w * 0.38, 0.12 + h / 2 + 0.3, -0.1) * CFrame.Angles(0, 0, math.rad(-side * 28)),
					pal.Trim
				)
			end
		end
	end
end

local function buildUpperTorso(ctx: Ctx, limb: Limb)
	local g = ctx.growth
	local pal = ctx.palette
	local form = Economy.formFor(ctx.level).Id
	local cx = 1 + (g.chest - 1) * 0.5
	local w, h, d = 2.3 * cx * g.armor, 1.75 * g.chest * g.armor, 1.35 * g.chest * g.armor
	primary(ctx, limb, "Chest", Vector3.new(w, h, d), at(0, 0.05, 0))
	newPart(
		ctx,
		limb,
		"ChestPlate",
		Vector3.new(w * 0.65, h * 0.48, 0.16),
		at(0, 0.25, -d / 2 - 0.06),
		pal.Secondary,
		Enum.Material.Metal
	)
	if ctx.level >= 7 then
		local r = if ctx.level >= 8 then 0.95 else 0.75
		newPart(
			ctx,
			limb,
			"Reactor",
			Vector3.new(r, r, r),
			at(0, 0.22, -d / 2 - 0.12),
			pal.Glow,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		newPart(
			ctx,
			limb,
			"ReactorRing",
			Vector3.new(0.2, r * 1.35, r * 1.35),
			at(0, 0.22, -d / 2 - 0.12) * CFrame.Angles(0, math.rad(90), 0),
			pal.Trim,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
	else
		newPart(
			ctx,
			limb,
			"ChestLight",
			Vector3.new(0.55, 0.22, 0.08),
			at(0, 0.32, -d / 2 - 0.15),
			pal.Eyes,
			Enum.Material.Neon
		)
	end
	-- Back pack (and thrusters on the Mega Mech)
	newPart(
		ctx,
		limb,
		"BackPack",
		Vector3.new(w * 0.7, h * 0.78, 0.55),
		at(0, 0.05, d / 2 + 0.2),
		pal.Secondary,
		Enum.Material.Metal
	)
	if form == "MegaMech" then
		for side = -1, 1, 2 do
			newPart(
				ctx,
				limb,
				"Thruster",
				Vector3.new(1.0, 0.55, 0.55),
				at(side * w * 0.2, -0.1, d / 2 + 0.6) * CFrame.Angles(0, 0, math.rad(90)),
				pal.Dark,
				Enum.Material.Metal,
				Enum.PartType.Cylinder
			)
			newPart(
				ctx,
				limb,
				"ThrusterGlow",
				Vector3.new(0.08, 0.42, 0.42),
				at(side * w * 0.2, -0.62, d / 2 + 0.6) * CFrame.Angles(0, 0, math.rad(90)),
				pal.Glow,
				Enum.Material.Neon,
				Enum.PartType.Cylinder
			)
		end
	end
	if form == "ScrapBot" then
		newPart(
			ctx,
			limb,
			"Patch",
			Vector3.new(0.5, 0.45, 0.05),
			at(w * 0.3, -0.3, -d / 2 - 0.02) * CFrame.Angles(0, 0, -0.25),
			pal.Secondary
		)
		newPart(
			ctx,
			limb,
			"Rivet",
			Vector3.new(0.12, 0.12, 0.12),
			at(-w * 0.32, -0.45, -d / 2 - 0.03),
			pal.Trim,
			Enum.Material.Metal,
			Enum.PartType.Ball
		)
	end
	if pal.Stripes then
		stripes(ctx, limb, w, h * 0.5, -d / 2 - 0.04)
	end
	if pal.Seams then
		for i = 0, 1 do
			newPart(
				ctx,
				limb,
				"Seam",
				Vector3.new(w + 0.02, 0.06, d + 0.02),
				at(0, -0.35 + i * 0.7, 0),
				pal.Glow,
				Enum.Material.Neon
			)
		end
	end
end

local function buildLowerTorso(ctx: Ctx, limb: Limb)
	local a = ctx.growth.armor
	local pal = ctx.palette
	newPart(ctx, limb, "Waist", Vector3.new(1.7 * a, 0.6, 1.1 * a), at(0, -0.05, 0), pal.Dark, Enum.Material.Metal)
	newPart(ctx, limb, "Belt", Vector3.new(1.9 * a, 0.25, 1.2 * a), at(0, 0.18, 0), pal.Secondary, Enum.Material.Metal)
	for side = -1, 1, 2 do
		primary(ctx, limb, "HipPlate", Vector3.new(0.42, 0.6, 0.95 * a), at(side * 0.98 * a, -0.2, 0))
	end
end

local function buildUpperArm(ctx: Ctx, limb: Limb, side: number)
	local g = ctx.growth
	local pal = ctx.palette
	local form = Economy.formFor(ctx.level).Id
	local sh = g.shoulder * g.armor
	local pw, ph, pd = 1.3 * sh, 0.9 * sh, 1.3 * sh
	-- Pads sit out from the chest with a visible gap, so the silhouette keeps its joints.
	local ox = side * (0.22 + (sh - 1) * 0.62)
	local pad = primary(ctx, limb, "ShoulderPad", Vector3.new(pw, ph, pd), at(ox, 0.36, 0))
	if form == "ScrapBot" and side < 0 then
		pad.Color = pal.Secondary -- mismatched salvage plate
	end
	newPart(ctx, limb, "ShoulderStripe", Vector3.new(pw + 0.04, 0.18, pd * 0.45), at(ox, 0.36 + ph * 0.28, 0), pal.Trim)
	newPart(ctx, limb, "UpperArmCore", Vector3.new(0.8, 1.0, 0.8), at(0, -0.15, 0), pal.Dark, Enum.Material.Metal)
	if form == "MegaMech" then
		newPart(
			ctx,
			limb,
			"ShoulderVent",
			Vector3.new(0.08, ph * 0.45, pd * 0.6),
			at(ox + side * (pw / 2 + 0.02), 0.25, 0),
			pal.Glow,
			Enum.Material.Neon
		)
	end
end

local function buildLowerArm(ctx: Ctx, limb: Limb)
	local g = ctx.growth
	local pal = ctx.palette
	local f = g.forearm * g.armor
	primary(ctx, limb, "Forearm", Vector3.new(1.15 * f, 1.15 * math.sqrt(f), 1.2 * f), at(0, -0.08, 0))
	newPart(
		ctx,
		limb,
		"Elbow",
		Vector3.new(0.95, 0.7, 0.7),
		at(0, 0.5, 0),
		pal.Dark,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	newPart(ctx, limb, "ForearmStripe", Vector3.new(1.15 * f + 0.04, 0.15, 1.2 * f + 0.04), at(0, -0.35, 0), pal.Trim)
end

local function buildHand(ctx: Ctx, limb: Limb)
	local g = ctx.growth
	local pal = ctx.palette
	local f = math.max(1, g.forearm * 0.85) * g.armor
	newPart(
		ctx,
		limb,
		"Fist",
		Vector3.new(1.05 * f, 0.8, 1.05 * f),
		at(0, -0.28, 0),
		pal.Secondary,
		Enum.Material.Metal
	)
	newPart(
		ctx,
		limb,
		"Knuckles",
		Vector3.new(0.95 * f, 0.22, 0.25),
		at(0, -0.4, -0.5 * f - 0.05),
		pal.Dark,
		Enum.Material.Metal
	)
end

local function buildUpperLeg(ctx: Ctx, limb: Limb)
	local a = ctx.growth.armor
	primary(ctx, limb, "Thigh", Vector3.new(0.92 * a, 1.05, 1.05 * a), at(0, -0.02, 0))
	newPart(ctx, limb, "HipJoint", Vector3.new(0.7, 0.4, 0.7), at(0, 0.55, 0), ctx.palette.Dark, Enum.Material.Metal)
end

local function buildLowerLeg(ctx: Ctx, limb: Limb)
	local a = ctx.growth.armor
	local pal = ctx.palette
	local d = 1.12 * a
	primary(ctx, limb, "Shin", Vector3.new(1.0 * a, 0.95, d), at(0, 0.08, -0.04))
	newPart(
		ctx,
		limb,
		"KneeHinge",
		Vector3.new(0.86 * a, 0.56, 0.56),
		at(0, 0.62, -0.04),
		pal.Dark,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	newPart(
		ctx,
		limb,
		"KneeCap",
		Vector3.new(0.5, 0.4, 0.22),
		at(0, 0.56, -d / 2 - 0.1),
		pal.Secondary,
		Enum.Material.Metal
	)
	if pal.Stripes then
		stripes(ctx, limb, 1.0 * a, 0.6, -d / 2 - 0.03)
	end
end

local function buildFoot(ctx: Ctx, limb: Limb)
	local a = ctx.growth.armor
	local pal = ctx.palette
	newPart(ctx, limb, "Boot", Vector3.new(1.12 * a, 0.5, 1.6 * a), at(0, 0.1, -0.2), pal.Dark, Enum.Material.Metal)
	newPart(
		ctx,
		limb,
		"ToeCap",
		Vector3.new(1.14 * a, 0.3, 0.4),
		at(0, 0.02, -0.2 - 0.8 * a + 0.19),
		pal.Secondary,
		Enum.Material.Metal
	)
end

-- Tools -------------------------------------------------------------------------

-- Tool frame: grip at the fist, the tool extends along -Y, tilted forward/down at rest.
local function toolFrame(hand: Limb, scale: number): Limb
	return {
		part = hand.part,
		cframe = hand.cframe * CFrame.new(0, -0.32 * scale, 0) * CFrame.Angles(math.rad(40), 0, 0),
	}
end

local function buildHammer(ctx: Ctx, t: Limb)
	local pal = ctx.palette
	newPart(ctx, t, "Handle", Vector3.new(0.28, 1.9, 0.28), at(0, -0.85, 0), pal.Dark, Enum.Material.Metal)
	newPart(ctx, t, "Grip", Vector3.new(0.38, 0.5, 0.38), at(0, -0.12, 0), pal.Trim)
	newPart(ctx, t, "HammerHead", Vector3.new(0.82, 0.82, 1.45), at(0, -1.9, 0), METAL, Enum.Material.Metal)
	newPart(ctx, t, "HammerBand", Vector3.new(0.9, 0.3, 0.9), at(0, -1.9, 0), pal.Primary)
	for side = -1, 1, 2 do
		newPart(ctx, t, "Face", Vector3.new(0.92, 0.92, 0.18), at(0, -1.9, side * 0.74), pal.Dark, Enum.Material.Metal)
	end
end

local function buildSaw(ctx: Ctx, t: Limb)
	local pal = ctx.palette
	newPart(ctx, t, "Housing", Vector3.new(0.6, 1.0, 0.65), at(0, -0.42, 0), pal.Dark, Enum.Material.Metal)
	newPart(ctx, t, "Arm", Vector3.new(0.26, 0.8, 0.26), at(0, -1.15, 0), pal.Secondary, Enum.Material.Metal)
	newPart(
		ctx,
		t,
		"Blade",
		Vector3.new(0.12, 2.0, 2.0),
		at(0, -1.95, 0),
		METAL,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	newPart(
		ctx,
		t,
		"Teeth",
		Vector3.new(0.06, 2.14, 2.14),
		at(0, -1.95, 0),
		pal.Dark,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	newPart(
		ctx,
		t,
		"BladeHub",
		Vector3.new(0.3, 0.5, 0.5),
		at(0, -1.95, 0),
		pal.Trim,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	newPart(ctx, t, "Guard", Vector3.new(0.3, 0.45, 2.2), at(0, -1.05, 0), pal.Primary)
end

local function buildDrill(ctx: Ctx, t: Limb)
	local pal = ctx.palette
	local upright = CFrame.Angles(0, 0, math.rad(90))
	newPart(
		ctx,
		t,
		"DrillBody",
		Vector3.new(1.4, 0.95, 0.95),
		at(0, -0.7, 0) * upright,
		pal.Primary,
		nil,
		Enum.PartType.Cylinder
	)
	newPart(
		ctx,
		t,
		"DrillBand",
		Vector3.new(0.25, 1.0, 1.0),
		at(0, -0.4, 0) * upright,
		pal.Trim,
		nil,
		Enum.PartType.Cylinder
	)
	newPart(
		ctx,
		t,
		"Collar",
		Vector3.new(0.32, 1.05, 1.05),
		at(0, -1.5, 0) * upright,
		pal.Dark,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	local diameters = { 0.72, 0.56, 0.42, 0.28, 0.14 }
	for i, dia in diameters do
		newPart(
			ctx,
			t,
			"Bit",
			Vector3.new(0.36, dia, dia),
			at(0, -1.82 - (i - 1) * 0.34, 0) * upright,
			METAL,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
	end
end

local TOOL_BUILDERS = { Hammer = buildHammer, Saw = buildSaw, Drill = buildDrill }

local function buildTool(ctx: Ctx, hand: Limb, toolId: string)
	local toolScale = ctx.growth.tool
	local toolCtx = table.clone(ctx)
	toolCtx.scale = ctx.scale * toolScale
	local builder = TOOL_BUILDERS[toolId] or buildHammer
	builder(toolCtx, toolFrame(hand, ctx.scale))
end

-- Assembly ----------------------------------------------------------------------

local function dress(
	limbs: { [string]: Limb },
	parent: Instance,
	level: number,
	toolId: string,
	finishId: string?,
	scale: number
)
	local ctx: Ctx = {
		parent = parent,
		scale = scale,
		palette = MechBuilder.palette(level, finishId),
		level = level,
		growth = MechBuilder.growth(level),
	}
	local function each(name: string, fn: (Ctx, Limb, ...any) -> (), ...)
		local limb = limbs[name]
		if limb then
			fn(ctx, limb, ...)
		end
	end
	each("Head", buildHead)
	each("UpperTorso", buildUpperTorso)
	each("LowerTorso", buildLowerTorso)
	each("LeftUpperArm", buildUpperArm, -1)
	each("RightUpperArm", buildUpperArm, 1)
	each("LeftLowerArm", buildLowerArm)
	each("RightLowerArm", buildLowerArm)
	each("LeftHand", buildHand)
	each("RightHand", buildHand)
	each("LeftUpperLeg", buildUpperLeg)
	each("RightUpperLeg", buildUpperLeg)
	each("LeftLowerLeg", buildLowerLeg)
	each("RightLowerLeg", buildLowerLeg)
	each("LeftFoot", buildFoot)
	each("RightFoot", buildFoot)
	if limbs.RightHand then
		buildTool(ctx, limbs.RightHand, toolId)
	end
end

-- Dress a live character. Parts are massless, non-colliding and welded to the limbs,
-- so the default animations move them and gameplay collision stays unchanged.
function MechBuilder.apply(character: Model, level: number, toolId: string, finishId: string?): Folder
	local old = character:FindFirstChild("Mech")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Mech"
	local scale = character:GetScale()
	local limbs: { [string]: Limb } = {}
	for _, slot in SLOTS do
		local part = character:FindFirstChild(slot)
		if part and part:IsA("BasePart") then
			limbs[slot] = { part = part, cframe = part.CFrame }
		else
			local map = R6_MAP[slot]
			local r6 = map and character:FindFirstChild(map[1])
			if r6 and r6:IsA("BasePart") then
				limbs[slot] = { part = r6, cframe = r6.CFrame * CFrame.new(map[2] * scale) }
			end
		end
	end
	dress(limbs, folder, level, toolId, finishId, scale)
	folder.Parent = character
	return folder
end

-- Hide the default avatar under the armor (keeps HumanoidRootPart and joints intact).
function MechBuilder.hideAvatar(character: Model)
	for _, d in character:GetDescendants() do
		local isBody = d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and not d:FindFirstAncestor("Mech")
		local isFace = d:IsA("Decal") and d.Parent ~= nil and d.Parent.Name == "Head"
		if isBody or isFace then
			(d :: any).Transparency = 1
		elseif d:IsA("Accessory") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
			d:Destroy()
		end
	end
end

-- Anchored statue / preview from a virtual rig. `pose` raises the tool arm (degrees).
function MechBuilder.buildStatue(
	level: number,
	toolId: string,
	finishId: string?,
	scale: number,
	rootCFrame: CFrame,
	pose: number?
): Model
	local model = Instance.new("Model")
	model.Name = "MechStatue"
	local limbs: { [string]: Limb } = {}
	local raise = math.rad(pose or 0)
	local shoulder = CFrame.new(1.5 * scale, 1.0 * scale, 0)
	for slot, offset in VIRTUAL_RIG do
		local local_ = CFrame.new(offset * scale)
		if raise ~= 0 and (slot == "RightUpperArm" or slot == "RightLowerArm" or slot == "RightHand") then
			local_ = shoulder * CFrame.Angles(raise, 0, 0) * shoulder:Inverse() * local_
		end
		limbs[slot] = { part = nil, cframe = rootCFrame * local_ }
	end
	dress(limbs, model, level, toolId, finishId, scale)
	return model
end

-- Just a tool, for garage previews.
function MechBuilder.buildToolPreview(toolId: string, finishId: string?, level: number, cframe: CFrame): Model
	local model = Instance.new("Model")
	model.Name = toolId
	local ctx: Ctx = {
		parent = model,
		scale = 1,
		palette = MechBuilder.palette(level, finishId),
		level = level,
		growth = MechBuilder.growth(level),
	}
	ctx.growth.tool = 1
	local builder = TOOL_BUILDERS[toolId] or buildHammer
	builder(ctx, { part = nil, cframe = cframe })
	return model
end

function MechBuilder.toolIds(): { string }
	local ids = {}
	for _, tool in Config.Tools do
		table.insert(ids, tool.Id)
	end
	return ids
end

return MechBuilder
