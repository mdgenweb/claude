--!strict
-- Primitive builders for the procedural map (server side): parts, boxes, discs, balls, wedges,
-- floor decals, checker walls, surface/billboard text, proximity prompts, lights, particles and
-- animated beam rings. Every part is anchored. Decoration is non-colliding, non-queryable and
-- non-touchable, and only solid structure casts shadows unless asked. Text uses built-in fonts and
-- emoji only, and textures are built-in rbxasset:// files (no uploaded assets).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Themes = require(Shared.Visual.Themes)
local Worlds = require(Shared.Definitions.Worlds)

local MapKit = {}

export type Palette = {
	FloorA: Color3,
	FloorB: Color3,
	Path: Color3,
	Cliff: Color3,
	CliffAlt: Color3,
	CliffTop: Color3,
	Water: Color3,
	ThrowZone: Color3,
	ThrowZoneText: Color3,
	Accent: Color3,
	Trunk: Color3,
	Leaves: Color3,
	Rock: Color3, -- derived from the prop family
	Stone: Color3, -- light stone for pedestals, pillars and stands
}

export type PartOpts = {
	Material: Enum.Material?,
	Transparency: number?,
	Solid: boolean?, -- collides and can be raycast (default false)
	Shadow: boolean?, -- casts shadows (default = Solid)
	Shape: Enum.PartType?,
	Name: string?,
	Reflectance: number?,
}

export type TextOpts = {
	Font: Font?,
	Stroke: Color3?,
	StrokeThickness: number?,
	XAlign: Enum.TextXAlignment?,
	Transparency: number?,
	Rich: boolean?,
}

export type WallOpts = {
	Thickness: number,
	BlockLength: number, -- target checker block length along the wall
	Rows: number, -- checker rows over the wall height
	Below: number?, -- extra solid depth under the base line (hides gaps)
	ExtendStart: number?, -- base wall extends past `a` by this much (corners)
	ExtendEnd: number?,
	Cap: boolean?, -- grass cap on top
	CapOverhang: number?,
	Drips: Random?, -- when set, grass blocks "drip" down the inner face at random columns
	Solid: boolean?,
	Parity: number?, -- 0/1 flips the checker
}

-- Everything one world build shares (MapBuilder creates it, the section builders read it).
export type Ctx = {
	World: Worlds.World,
	Theme: Themes.Theme,
	Pal: Palette,
	Origin: Vector3, -- Map.Origin(world.Id); every layout coordinate is relative to it
	Model: Model, -- World_<id>
	Rng: Random, -- seeded per world: the same world always builds the same way
}

local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- cylinder axis (local X) -> world up

MapKit.Fonts = {
	Display = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular),
	Numbers = Font.new("rbxasset://fonts/families/LuckiestGuy.json", Enum.FontWeight.Regular),
	Body = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
}
MapKit.StrokeColor = Color3.fromHex("#0B0F24")
MapKit.White = WHITE
MapKit.Black = BLACK

MapKit.SparkTexture = "rbxasset://textures/particles/sparkles_main.dds"
MapKit.SmokeTexture = "rbxasset://textures/particles/smoke_main.dds"

local ROCK: { [string]: string } = {
	Palm = "#A7ADB5",
	Volcano = "#2E2A2A",
	Pirate = "#A39E93",
	Ice = "#B9C7D9",
}

local STONE: { [string]: string } = {
	Palm = "#F3EFE6",
	Volcano = "#4A4040",
	Pirate = "#EADCC0",
	Ice = "#F4FAFF",
}

-- World-local layout coordinates -> world space.
function MapKit.At(ctx: Ctx, x: number, y: number, z: number): Vector3
	return ctx.Origin + Vector3.new(x, y, z)
end

function MapKit.CF(ctx: Ctx, x: number, y: number, z: number): CFrame
	return CFrame.new(ctx.Origin + Vector3.new(x, y, z))
end

function MapKit.Folder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function MapKit.Group(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

-- "#RRGGBB" -> Color3 with a fallback for malformed strings (definitions are data).
function MapKit.Hex(hex: string?, fallback: Color3?): Color3
	if type(hex) == "string" then
		local ok, color = pcall(Color3.fromHex, hex)
		if ok then
			return color
		end
	end
	return fallback or WHITE
end

function MapKit.Palette(theme: Themes.Theme): Palette
	local h = MapKit.Hex
	return {
		FloorA = h(theme.FloorA),
		FloorB = h(theme.FloorB),
		Path = h(theme.Path),
		Cliff = h(theme.Cliff),
		CliffAlt = h(theme.CliffAlt),
		CliffTop = h(theme.CliffTop),
		Water = h(theme.Water),
		ThrowZone = h(theme.ThrowZone),
		ThrowZoneText = h(theme.ThrowZoneText),
		Accent = h(theme.Accent),
		Trunk = h(theme.Trunk),
		Leaves = h(theme.Leaves),
		Rock = h(ROCK[theme.Props] or ROCK.Palm),
		Stone = h(STONE[theme.Props] or STONE.Palm),
	}
end

function MapKit.Shade(c: Color3, amount: number): Color3
	return c:Lerp(BLACK, amount)
end

function MapKit.Tint(c: Color3, amount: number): Color3
	return c:Lerp(WHITE, amount)
end

-- Perceived brightness 0..1.
function MapKit.Luminance(c: Color3): number
	return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end

-- Readable outline for text of colour `c`: dark for light text, white for dark text.
function MapKit.StrokeFor(c: Color3): Color3
	return if MapKit.Luminance(c) > 0.45 then MapKit.StrokeColor else WHITE
end

function MapKit.Material(name: string): Enum.Material
	if name == "Neon" then
		return Enum.Material.Neon
	elseif name == "Glass" then
		return Enum.Material.Glass
	elseif name == "Ice" then
		return Enum.Material.Ice
	end
	return Enum.Material.SmoothPlastic
end

local function finish(p: BasePart, parent: Instance, size: Vector3, cf: CFrame, color: Color3, opts: PartOpts?)
	p.Anchored = true
	p.Size = Vector3.new(math.max(size.X, 0.05), math.max(size.Y, 0.05), math.max(size.Z, 0.05))
	p.CFrame = cf
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local solid = false
	local shadow = false
	p.Material = Enum.Material.SmoothPlastic
	if opts then
		solid = opts.Solid == true
		shadow = if opts.Shadow ~= nil then opts.Shadow else solid
		if opts.Material then
			p.Material = opts.Material
		end
		if opts.Transparency then
			p.Transparency = opts.Transparency
		end
		if opts.Reflectance then
			p.Reflectance = opts.Reflectance
		end
		if opts.Name then
			p.Name = opts.Name
		end
	end
	p.CanCollide = solid
	p.CanQuery = solid -- CanQuery may only be off when CanCollide is off
	p.CanTouch = false
	p.CastShadow = shadow
	p.Parent = parent
end

-- Block (or opts.Shape) centred on `cf`.
function MapKit.Part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, opts: PartOpts?): Part
	local p = Instance.new("Part")
	if opts and opts.Shape then
		p.Shape = opts.Shape
	end
	finish(p, parent, size, cf, color, opts)
	return p
end

-- Axis-aligned block spanning two opposite corners (world coordinates).
function MapKit.Box(parent: Instance, a: Vector3, b: Vector3, color: Color3, opts: PartOpts?): Part
	local lo = a:Min(b)
	local hi = a:Max(b)
	return MapKit.Part(parent, hi - lo, CFrame.new((lo + hi) / 2), color, opts)
end

-- Wedge: full height at local +Z, sloping down to local -Z.
function MapKit.Wedge(parent: Instance, size: Vector3, cf: CFrame, color: Color3, opts: PartOpts?): WedgePart
	local p = Instance.new("WedgePart")
	finish(p, parent, size, cf, color, opts)
	return p
end

-- Upright cylinder (axis = world up of `cf`), centred on `cf`.
function MapKit.Disc(parent: Instance, diameter: number, height: number, cf: CFrame, color: Color3, opts: PartOpts?): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	finish(p, parent, Vector3.new(height, diameter, diameter), cf * UPRIGHT, color, opts)
	return p
end

-- Cylinder whose flat faces point along `cf`'s look vector (portals, wheels, signs).
function MapKit.FacingDisc(parent: Instance, diameter: number, thickness: number, cf: CFrame, color: Color3, opts: PartOpts?): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	finish(p, parent, Vector3.new(thickness, diameter, diameter), cf * CFrame.Angles(0, math.pi / 2, 0), color, opts)
	return p
end

function MapKit.Ball(parent: Instance, diameter: number, cf: CFrame, color: Color3, opts: PartOpts?): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	finish(p, parent, Vector3.new(diameter, diameter, diameter), cf, color, opts)
	return p
end

-- Block running from `from` to `to` (trunks, rails, lava falls); `width` x `depth` cross-section.
function MapKit.Beam(parent: Instance, from: Vector3, to: Vector3, width: number, depth: number, color: Color3, opts: PartOpts?): Part
	local length = (to - from).Magnitude
	local mid = (from + to) / 2
	local dir = to - from
	local cf: CFrame
	if length < 1e-4 then
		cf = CFrame.new(mid)
	else
		local up = if math.abs(dir.Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
		cf = CFrame.lookAt(mid, to, up)
	end
	return MapKit.Part(parent, Vector3.new(width, depth, length), cf, color, opts)
end

-- CFrame whose Front face (local -Z) points along `dir`, so a Front SurfaceGui faces that way.
function MapKit.Facing(position: Vector3, dir: Vector3): CFrame
	return CFrame.lookAt(position, position + dir)
end

-- Invisible flat part lying on the ground with its Front face pointing up. A Front SurfaceGui on
-- it reads upright for someone looking along `up` (horizontal unit vector = the text's top).
function MapKit.FloorDecal(parent: Instance, center: Vector3, up: Vector3, width: number, height: number): Part
	local y = up.Unit
	local z = Vector3.new(0, -1, 0)
	local x = y:Cross(z)
	return MapKit.Part(parent, Vector3.new(width, height, 0.05), CFrame.fromMatrix(center, x, y, z), WHITE, {
		Transparency = 1,
		Name = "Decal",
	})
end

-- Checker wall whose inner face runs along the line a -> b (both at the wall's base height),
-- facing `inward`. One solid base slab plus alternate-colour blocks that stand 0.6 studs proud of
-- the inner face, so it reads as voxel blocks with a handful of parts.
function MapKit.CheckerWall(parent: Instance, a: Vector3, b: Vector3, inward: Vector3, height: number, colorA: Color3, colorB: Color3, top: Color3, o: WallOpts)
	local along = b - a
	local length = along.Magnitude
	if length < 0.5 or height <= 0 then
		return
	end
	local dir = along.Unit
	local up = Vector3.yAxis
	local n = inward.Unit
	local thickness = o.Thickness
	local below = o.Below or 0
	local e0 = o.ExtendStart or 0
	local e1 = o.ExtendEnd or 0
	local solid = if o.Solid == nil then true else o.Solid
	-- base slab
	local baseStart = a - dir * e0
	local baseEnd = b + dir * e1
	local baseLen = length + e0 + e1
	local mid = (baseStart + baseEnd) / 2 - n * (thickness / 2) + up * ((height - below) / 2)
	MapKit.Part(parent, Vector3.new(baseLen, height + below, thickness), CFrame.lookAt(mid, mid + n), colorA, {
		Solid = solid,
		Shadow = true,
		Name = "Wall",
	})
	-- checker blocks on the inner face
	local columns = math.max(1, math.floor(length / o.BlockLength + 0.5))
	local rows = math.max(1, o.Rows)
	local bl = length / columns
	local rh = height / rows
	local parity = o.Parity or 0
	for c = 0, columns - 1 do
		for r = 0, rows - 1 do
			if (c + r + parity) % 2 == 1 then
				local center = a + dir * (bl * (c + 0.5)) + up * (rh * (r + 0.5))
				MapKit.Part(parent, Vector3.new(bl, rh, 1.2), CFrame.lookAt(center, center + n), colorB, { Name = "Block" })
			end
		end
	end
	if o.Cap then
		local over = o.CapOverhang or 1
		local capMid = (baseStart + baseEnd) / 2 + n * (over / 2) - n * (thickness / 2) + up * (height + 0.75)
		MapKit.Part(parent, Vector3.new(baseLen, 2.5, thickness + over), CFrame.lookAt(capMid, capMid + n), top, {
			Solid = solid,
			Shadow = true,
			Name = "Cap",
		})
		local rng = o.Drips
		if rng then
			for c = 0, columns - 1 do
				if rng:NextNumber() < 0.35 then
					local drop = rh * rng:NextNumber(0.25, 0.55)
					local center = a + dir * (bl * (c + 0.5)) + up * (height - drop / 2) + n * 0.5
					MapKit.Part(parent, Vector3.new(bl * rng:NextNumber(0.4, 0.9), drop, 1.4), CFrame.lookAt(center, center + n), top, {
						Name = "Drip",
					})
				end
			end
		end
	end
end

-- SurfaceGui sized in pixels per stud (crisp at any part size), unlit so colours stay bright.
function MapKit.Surface(part: BasePart, name: string, face: Enum.NormalId, pixelsPerStud: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud
	gui.LightInfluence = 0
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ClipsDescendants = true
	gui.Parent = part
	return gui
end

-- World-sized billboard (Scale sizes are studs, so text shrinks with distance like real signs).
function MapKit.Billboard(part: BasePart, name: string, width: number, height: number, offsetY: number, maxDistance: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = UDim2.fromScale(width, height)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = maxDistance
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.ClipsDescendants = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = part
	return gui
end

-- Scaled, stroked TextLabel. Position/size are fractions of the parent.
function MapKit.Text(parent: Instance, name: string, text: string, y: number, height: number, color: Color3, opts: TextOpts?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Position = UDim2.fromScale(0, y)
	label.Size = UDim2.fromScale(1, height)
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextWrapped = true
	label.RichText = opts ~= nil and opts.Rich == true
	label.FontFace = (opts and opts.Font) or MapKit.Fonts.Display
	label.TextXAlignment = (opts and opts.XAlign) or Enum.TextXAlignment.Center
	label.TextTransparency = (opts and opts.Transparency) or 0
	local stroke = Instance.new("UIStroke")
	stroke.Color = (opts and opts.Stroke) or MapKit.StrokeColor
	stroke.Thickness = (opts and opts.StrokeThickness) or 2
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Transparency = (opts and opts.Transparency) or 0
	stroke.Parent = label
	label.Parent = parent
	return label
end

function MapKit.Corner(gui: GuiObject, scale: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(scale, 0)
	corner.Parent = gui
end

-- Horizontal colour gradient over a GuiObject (rainbow titles, sign panels).
function MapKit.Gradient(gui: GuiObject, colors: { Color3 }): UIGradient
	local keys = {}
	local count = #colors
	for i, c in colors do
		local t = if count > 1 then (i - 1) / (count - 1) else 0
		table.insert(keys, ColorSequenceKeypoint.new(t, c))
	end
	if count == 1 then
		table.insert(keys, ColorSequenceKeypoint.new(1, colors[1]))
	end
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(keys)
	gradient.Parent = gui
	return gradient
end

MapKit.Rainbow = {
	Color3.fromHex("#FF4F4F"),
	Color3.fromHex("#FFB13D"),
	Color3.fromHex("#FFF05A"),
	Color3.fromHex("#5BE05B"),
	Color3.fromHex("#3FA9FF"),
	Color3.fromHex("#B65CFF"),
}

-- Interaction prompt shared by pedestals, eggs and portals (E / gamepad X, instant).
function MapKit.Prompt(parent: Instance, name: string, objectText: string, actionText: string, distance: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ObjectText = objectText
	prompt.ActionText = actionText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = distance
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Parent = parent
	return prompt
end

function MapKit.Light(part: BasePart, color: Color3, range: number, brightness: number): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = part
	return light
end

-- Soft rising sparkles (pedestal glows, portals, treasure).
function MapKit.Sparkles(part: BasePart, color: Color3, rate: number, speed: number): ParticleEmitter
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Sparkles"
	pe.Texture = MapKit.SparkTexture
	pe.Color = ColorSequence.new(color, WHITE)
	pe.LightEmission = 1
	pe.LightInfluence = 0
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe.Lifetime = NumberRange.new(1, 1.8)
	pe.Rate = rate
	pe.Speed = NumberRange.new(speed * 0.6, speed)
	pe.SpreadAngle = Vector2.new(25, 25)
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(-90, 90)
	pe.Parent = part
	return pe
end

-- Slow dark smoke plume (volcano craters, lava vents).
function MapKit.Smoke(part: BasePart, color: Color3, size: number, rate: number): ParticleEmitter
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Smoke"
	pe.Texture = MapKit.SmokeTexture
	pe.Color = ColorSequence.new(color)
	pe.LightEmission = 0
	pe.LightInfluence = 1
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size * 0.4),
		NumberSequenceKeypoint.new(1, size),
	})
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe.Lifetime = NumberRange.new(5, 8)
	pe.Rate = rate
	pe.Speed = NumberRange.new(size * 0.15, size * 0.3)
	pe.SpreadAngle = Vector2.new(12, 12)
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(-20, 20)
	pe.Parent = part
	return pe
end

local function ringAttachment(part: BasePart, name: string, x: number): Attachment
	local att = Instance.new("Attachment")
	att.Name = name
	-- attachment X axis (the beam's curve direction) = the part's up vector
	att.CFrame = CFrame.fromMatrix(Vector3.new(x, 0, 0), Vector3.yAxis, -Vector3.xAxis)
	att.Parent = part
	return att
end

-- Animated glowing ring in `part`'s local XY plane, centred on the part: two semicircular beams
-- whose sparkle texture scrolls around the circle natively (no scripts). Positive `speed` runs
-- clockwise seen from the part's front.
function MapKit.BeamRing(part: BasePart, radius: number, width: number, color: Color3, speed: number, transparency: number?)
	local left = ringAttachment(part, "RingL" .. radius, -radius)
	local right = ringAttachment(part, "RingR" .. radius, radius)
	local k = radius * 4 / 3 -- cubic Bezier control distance for a semicircle
	local function beam(a0: Attachment, a1: Attachment, c0: number, c1: number)
		local b = Instance.new("Beam")
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.CurveSize0 = c0
		b.CurveSize1 = c1
		b.Segments = 24
		b.Width0 = width
		b.Width1 = width
		b.FaceCamera = true
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Color = ColorSequence.new(color)
		b.Transparency = NumberSequence.new(transparency or 0.1)
		b.Texture = MapKit.SparkTexture
		b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = math.max(2, width * 1.5)
		b.TextureSpeed = speed
		b.Parent = part
	end
	beam(left, right, k, -k) -- over the top
	beam(right, left, -k, k) -- back underneath
end

return MapKit
