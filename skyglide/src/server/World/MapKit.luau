--!strict
-- Primitive builders for the procedural map (server side): parts, discs, balls, wedges, floor
-- decals, surface/billboard text and proximity prompts. Every part is anchored. Decoration is
-- non-colliding, non-queryable and non-touchable, and only solid structure casts shadows unless
-- asked. Text uses built-in fonts and emoji only (no uploaded assets).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Themes = require(ReplicatedStorage:WaitForChild("Shared").Visual.Themes)

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

local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local ROCK: { [string]: string } = {
	Palm = "#A7ADB5",
	Volcano = "#2E2A2A",
	Pirate = "#A39E93",
	Ice = "#B9C7D9",
}

function MapKit.Palette(theme: Themes.Theme): Palette
	local h = Color3.fromHex
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
	}
end

function MapKit.Shade(c: Color3, amount: number): Color3
	return c:Lerp(BLACK, amount)
end

function MapKit.Tint(c: Color3, amount: number): Color3
	return c:Lerp(WHITE, amount)
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
	p.Size = size
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

function MapKit.Ball(parent: Instance, diameter: number, cf: CFrame, color: Color3, opts: PartOpts?): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	finish(p, parent, Vector3.new(diameter, diameter, diameter), cf, color, opts)
	return p
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
	label.RichText = false
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
	pe.Texture = SPARK_TEXTURE
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
	pe.Texture = SMOKE_TEXTURE
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

return MapKit
