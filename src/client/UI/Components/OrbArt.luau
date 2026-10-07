--!strict
-- 2D orb renderer used everywhere an orb is shown: UI cards, HUD icons and the in-arena
-- billboards (a camera-facing 2D orb looks like a sphere from any angle and stays crisp).
-- Every orb = shaded base circle + rotating layer (spikes, band, emblem) + gloss + flash.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BallDefinitions = require(ReplicatedStorage:WaitForChild("Shared").Definitions.BallDefinitions)

local UI = script.Parent.Parent
local Create = require(UI.Create)
local Theme = require(UI.Theme)

local OrbArt = {}

-- Container size relative to the orb diameter (room for spikes and rim glow).
OrbArt.Padding = 1.36
local ORB = 1 / OrbArt.Padding

local hex = Color3.fromHex
local WHITE = Color3.new(1, 1, 1)
local INK = hex("#16181F")

export type Handle = {
	Root: Frame,
	Orb: Frame,
	Spin: Frame,
	Flash: Frame,
	Def: BallDefinitions.BallDefinition?,
	SetRotation: (Handle, number) -> (),
	Destroy: (Handle) -> (),
}

type Painter = (e: Frame, base: Color3, accent: Color3) -> ()

local function circle(parent: Instance, cx: number, cy: number, d: number, color: Color3, z: number, transparency: number?): Frame
	local c: Frame = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(cx, cy),
		Size = UDim2.fromScale(d, d),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency or 0,
		ZIndex = z,
		Parent = parent,
	})
	Create.Round(c)
	return c
end

local function oval(parent: Instance, cx: number, cy: number, w: number, h: number, color: Color3, z: number, rot: number?): Frame
	local c = circle(parent, cx, cy, w, color, z)
	c.Size = UDim2.fromScale(w, h)
	c.Rotation = rot or 0
	return c
end

local function rect(parent: Instance, cx: number, cy: number, w: number, h: number, color: Color3, z: number, rot: number?, corner: number?): Frame
	local r: Frame = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(cx, cy),
		Size = UDim2.fromScale(w, h),
		BackgroundColor3 = color,
		Rotation = rot or 0,
		ZIndex = z,
		Parent = parent,
	})
	if corner then
		Create.Corner(UDim.new(corner, 0), r)
	end
	return r
end

-- Ring whose stroke thickness follows the frame's pixel size.
local function ring(parent: Instance, cx: number, cy: number, d: number, frac: number, color: Color3, z: number): Frame
	local c = circle(parent, cx, cy, d, color, z, 1)
	local stroke = Create.Stroke(c, color, 2, 0, true)
	local function fit()
		stroke.Thickness = math.max(1, c.AbsoluteSize.X * frac)
	end
	c:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	return c
end

local function eyes(e: Frame, y: number?, color: Color3?)
	local ey = y or 0.42
	oval(e, 0.36, ey, 0.12, 0.19, color or INK, 6)
	oval(e, 0.64, ey, 0.12, 0.19, color or INK, 6)
	circle(e, 0.38, ey - 0.05, 0.045, WHITE, 7)
	circle(e, 0.66, ey - 0.05, 0.045, WHITE, 7)
end

local function arc(e: Frame, cx: number, cy: number, radius: number, from: number, to: number, dots: number, d: number, color: Color3, z: number)
	for i = 0, dots - 1 do
		local t = from + (to - from) * i / (dots - 1)
		circle(e, cx + math.cos(t) * radius, cy + math.sin(t) * radius, d, color, z)
	end
end

local Painters: { [string]: Painter } = {
	grin = function(e)
		eyes(e)
		rect(e, 0.5, 0.67, 0.44, 0.17, INK, 6, 0, 0.5)
		rect(e, 0.5, 0.635, 0.34, 0.06, WHITE, 7, 0, 0.3)
	end,
	angry = function(e)
		eyes(e, 0.46)
		rect(e, 0.34, 0.31, 0.22, 0.07, INK, 6, 22, 0.4)
		rect(e, 0.66, 0.31, 0.22, 0.07, INK, 6, -22, 0.4)
		arc(e, 0.5, 0.86, 0.17, math.rad(-150), math.rad(-30), 7, 0.06, INK, 6)
	end,
	smile = function(e)
		eyes(e)
		arc(e, 0.5, 0.5, 0.22, math.rad(25), math.rad(155), 9, 0.075, INK, 6)
	end,
	heavy = function(e)
		rect(e, 0.5, 0.33, 0.56, 0.1, INK, 6, 0, 0.3)
		oval(e, 0.37, 0.45, 0.1, 0.12, INK, 6)
		oval(e, 0.63, 0.45, 0.1, 0.12, INK, 6)
		rect(e, 0.5, 0.68, 0.3, 0.07, INK, 6, 0, 0.5)
	end,
	spring = function(e, _base, accent)
		for i = 0, 3 do
			rect(e, 0.32 + i * 0.12, 0.5, 0.06, 0.42, accent, 6, if i % 2 == 0 then 28 else -28, 0.5)
		end
		eyes(e, 0.28)
	end,
	boomerang = function(e, _base, accent)
		rect(e, 0.4, 0.46, 0.14, 0.5, accent, 6, -38, 0.5)
		rect(e, 0.6, 0.46, 0.14, 0.5, accent, 6, 38, 0.5)
		circle(e, 0.5, 0.64, 0.16, accent, 6)
	end,
	ring = function(e, _base, accent)
		ring(e, 0.5, 0.5, 0.56, 0.07, accent, 6)
		circle(e, 0.5, 0.5, 0.2, accent, 6)
		circle(e, 0.73, 0.27, 0.15, WHITE, 7)
	end,
	fangs = function(e, _base, accent)
		oval(e, 0.36, 0.4, 0.13, 0.13, accent, 6, 0)
		oval(e, 0.64, 0.4, 0.13, 0.13, accent, 6, 0)
		arc(e, 0.5, 0.48, 0.2, math.rad(30), math.rad(150), 8, 0.06, INK, 6)
		rect(e, 0.41, 0.69, 0.08, 0.08, WHITE, 7, 45)
		rect(e, 0.59, 0.69, 0.08, 0.08, WHITE, 7, 45)
	end,
	drip = function(e, _base, accent)
		eyes(e, 0.38)
		for i, x in { 0.32, 0.5, 0.68 } do
			local len = if i == 2 then 0.2 else 0.13
			rect(e, x, 0.68 + len / 2, 0.09, len, accent, 6, 0, 0.5)
			circle(e, x, 0.68 + len, 0.12, accent, 6)
		end
	end,
	magnet = function(e, _base, accent)
		rect(e, 0.34, 0.47, 0.14, 0.38, accent, 6, 0, 0.2)
		rect(e, 0.66, 0.47, 0.14, 0.38, accent, 6, 0, 0.2)
		rect(e, 0.5, 0.67, 0.46, 0.14, accent, 6, 0, 0.5)
		rect(e, 0.34, 0.28, 0.14, 0.1, hex("#9CA2AB"), 7)
		rect(e, 0.66, 0.28, 0.14, 0.1, hex("#9CA2AB"), 7)
	end,
	barrel = function(e, _base, accent)
		circle(e, 0.5, 0.5, 0.48, accent, 6)
		circle(e, 0.5, 0.5, 0.34, INK, 7)
		circle(e, 0.44, 0.44, 0.08, hex("#4A4F59"), 8)
	end,
	snowflake = function(e, _base, accent)
		for k = 0, 2 do
			rect(e, 0.5, 0.5, 0.08, 0.66, accent, 6, k * 60, 0.5)
		end
		for k = 0, 5 do
			local a = math.rad(k * 60 - 90)
			rect(e, 0.5 + math.cos(a) * 0.25, 0.5 + math.sin(a) * 0.25, 0.1, 0.1, accent, 6, 45)
		end
		circle(e, 0.5, 0.5, 0.14, WHITE, 7)
	end,
	mine = function(e, _base, accent)
		rect(e, 0.5, 0.5, 0.1, 0.62, INK, 6, 45, 0.4)
		rect(e, 0.5, 0.5, 0.1, 0.62, INK, 6, -45, 0.4)
		circle(e, 0.5, 0.5, 0.26, INK, 6)
		circle(e, 0.5, 0.5, 0.13, accent, 7)
	end,
	prism = function(e, _base, accent)
		rect(e, 0.5, 0.66, 0.46, 0.07, accent, 6, 0, 0.5)
		rect(e, 0.385, 0.47, 0.07, 0.44, accent, 6, 28, 0.5)
		rect(e, 0.615, 0.47, 0.07, 0.44, accent, 6, -28, 0.5)
		rect(e, 0.82, 0.42, 0.26, 0.035, hex("#FF4F7B"), 5, -12)
		rect(e, 0.82, 0.48, 0.26, 0.035, hex("#FFE14D"), 5, -4)
		rect(e, 0.82, 0.54, 0.26, 0.035, hex("#4FC3FF"), 5, 4)
	end,
	dice = function(e, _base, accent)
		local face = rect(e, 0.5, 0.5, 0.56, 0.56, WHITE, 6, 12, 0.18)
		Create.Stroke(face, accent, 2, 0, true)
		for _, p in { { 0.32, 0.32 }, { 0.68, 0.32 }, { 0.5, 0.5 }, { 0.32, 0.68 }, { 0.68, 0.68 } } do
			circle(face, p[1], p[2], 0.17, accent, 7)
		end
	end,
	ghost = function(e)
		oval(e, 0.37, 0.42, 0.15, 0.23, INK, 6)
		oval(e, 0.63, 0.42, 0.15, 0.23, INK, 6)
		oval(e, 0.5, 0.7, 0.11, 0.14, INK, 6)
	end,
	serpent = function(e, _base, accent)
		for i = 0, 10 do
			local t = i / 10
			circle(e, 0.22 + t * 0.56, 0.5 + math.sin(t * math.pi * 2) * 0.16, 0.12, accent, 6)
		end
		circle(e, 0.8, 0.5, 0.05, INK, 7)
		rect(e, 0.88, 0.5, 0.12, 0.03, hex("#FF3D4F"), 7)
	end,
	hammer = function(e, _base, accent)
		rect(e, 0.46, 0.56, 0.1, 0.56, hex("#8B5A2B"), 6, 40, 0.3)
		rect(e, 0.62, 0.38, 0.4, 0.2, accent, 7, 40, 0.15)
	end,
	gem = function(e, _base, accent)
		rect(e, 0.5, 0.5, 0.42, 0.42, accent, 6, 45, 0.08)
		rect(e, 0.5, 0.5, 0.24, 0.24, WHITE, 7, 45, 0.08).BackgroundTransparency = 0.35
		circle(e, 0.43, 0.4, 0.08, WHITE, 8)
	end,
	bolt = function(e, _base, accent)
		rect(e, 0.56, 0.34, 0.12, 0.36, accent, 6, 25)
		rect(e, 0.5, 0.5, 0.3, 0.1, accent, 6, -15)
		rect(e, 0.44, 0.66, 0.12, 0.36, accent, 6, 25)
	end,
	cell = function(e, _base, accent)
		circle(e, 0.47, 0.48, 0.38, accent, 6)
		circle(e, 0.42, 0.43, 0.12, WHITE, 7, 0.4)
		circle(e, 0.72, 0.7, 0.14, accent, 6)
		circle(e, 0.27, 0.72, 0.09, accent, 6)
	end,
	rook = function(e, _base, accent)
		rect(e, 0.5, 0.74, 0.48, 0.1, accent, 6, 0, 0.2)
		rect(e, 0.5, 0.52, 0.3, 0.36, accent, 6)
		rect(e, 0.5, 0.33, 0.42, 0.1, accent, 6)
		for _, x in { 0.33, 0.5, 0.67 } do
			rect(e, x, 0.25, 0.1, 0.1, accent, 6)
		end
	end,
	rail = function(e, _base, accent)
		rect(e, 0.5, 0.4, 0.74, 0.06, accent, 7)
		rect(e, 0.5, 0.6, 0.74, 0.06, accent, 7)
		for _, x in { 0.24, 0.41, 0.59, 0.76 } do
			rect(e, x, 0.5, 0.07, 0.34, hex("#8B5A2B"), 6)
		end
	end,
	chain = function(e, _base, accent)
		ring(e, 0.32, 0.62, 0.3, 0.09, accent, 6)
		ring(e, 0.5, 0.5, 0.3, 0.09, accent, 7)
		ring(e, 0.68, 0.38, 0.3, 0.09, accent, 6)
	end,
	eye = function(e, _base, accent)
		oval(e, 0.5, 0.5, 0.66, 0.42, WHITE, 6)
		circle(e, 0.5, 0.5, 0.3, accent, 7)
		circle(e, 0.5, 0.5, 0.15, INK, 8)
		circle(e, 0.45, 0.45, 0.06, WHITE, 9)
	end,
	pumpkin = function(e, _base, accent)
		rect(e, 0.36, 0.4, 0.15, 0.15, accent, 6, 45)
		rect(e, 0.64, 0.4, 0.15, 0.15, accent, 6, 45)
		rect(e, 0.5, 0.66, 0.5, 0.13, accent, 6, 0, 0.3)
		rect(e, 0.42, 0.61, 0.06, 0.06, hex("#FF8C1A"), 7)
		rect(e, 0.58, 0.71, 0.06, 0.06, hex("#FF8C1A"), 7)
		rect(e, 0.5, 0.04, 0.08, 0.12, hex("#3E8E1E"), 4)
	end,
}

function OrbArt.Exists(emblem: string): boolean
	return Painters[emblem] ~= nil
end

-- Draws an orb into `parent` (fills it, square). `defId` may be any BallDefinitions id.
-- `stretchable` skips the square constraint so the caller can squash/stretch the art.
function OrbArt.Draw(parent: Instance, defId: string, zBase: number?, stretchable: boolean?): Handle
	local def = BallDefinitions.Get(defId)
	local visual = if def then def.Visual else { Base = "#C9CCD3", Accent = "#3D4450", Emblem = "smile" }
	local base = hex(visual.Base)
	local accent = hex(visual.Accent)
	local z = zBase or 1

	local root: Frame = Create("Frame", {
		Name = "Orb_" .. defId,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = z,
		Parent = parent,
	})
	if not stretchable then
		Create.Aspect(root, 1)
	end

	-- rarity rim glow (legendary / mythic)
	local rim = (visual :: any).Rim
	if rim then
		circle(root, 0.5, 0.5, ORB * 1.22, hex(rim), z, 0.82)
		circle(root, 0.5, 0.5, ORB * 1.11, hex(rim), z, 0.6)
	end

	-- spin layer (rotates when the orb rolls)
	local spin: Frame = Create("Frame", {
		Name = "Spin",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		ZIndex = z + 1,
		Parent = root,
	})
	local spikes = (visual :: any).Spikes or 0
	for k = 1, spikes do
		local a = (k - 1) * (2 * math.pi / spikes)
		local d = ORB * 0.5
		rect(spin, 0.5 + math.cos(a) * d, 0.5 + math.sin(a) * d, ORB * 0.27, ORB * 0.27, base:Lerp(Color3.new(), 0.18), z + 1, math.deg(a) + 45)
	end

	-- outline + shaded body
	circle(root, 0.5, 0.5, ORB * 1.05, base:Lerp(Color3.new(), 0.55), z + 2)
	local body = circle(root, 0.5, 0.5, ORB, base, z + 3)
	local light = base:Lerp(WHITE, 0.38)
	local dark = base:Lerp(Color3.new(), 0.32)
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, light),
		ColorSequenceKeypoint.new(0.45, base),
		ColorSequenceKeypoint.new(1, dark),
	})
	grad.Rotation = 50
	grad.Parent = body

	-- emblem layer (inside the spin so it rolls)
	local emblemLayer: Frame = Create("Frame", {
		Name = "EmblemLayer",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(ORB, ORB),
		ZIndex = z + 4,
		Parent = root,
	})
	local emblemSpin: Frame = Create("Frame", {
		Name = "Emblem",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z + 4,
		Parent = emblemLayer,
	})
	if (visual :: any).Band then
		rect(emblemSpin, 0.5, 0.5, 1.0, 0.26, accent, 1, 0, 0.5)
	end
	local painter = Painters[visual.Emblem] or Painters.smile
	painter(emblemSpin, base, accent)
	-- painters use small relative ZIndex values; lift them above the body
	for _, child in emblemSpin:GetDescendants() do
		if child:IsA("GuiObject") then
			child.ZIndex = z + 4 + child.ZIndex
		end
	end

	-- gloss (fixed light from top-left)
	local gloss = oval(root, 0.36, 0.3, ORB * 0.32, ORB * 0.18, WHITE, z + 16, -35)
	gloss.BackgroundTransparency = 0.55

	local flash = circle(root, 0.5, 0.5, ORB * 1.02, WHITE, z + 17, 1)
	flash.Name = "Flash"

	local handle = {
		Root = root,
		Orb = body,
		Spin = spin,
		Flash = flash,
		Def = def,
	} :: any
	function handle.SetRotation(_: any, degrees: number)
		spin.Rotation = degrees
		emblemLayer.Rotation = degrees
	end
	function handle.Destroy(_: any)
		root:Destroy()
	end
	return handle :: Handle
end

-- Small helper for rarity-tinted card backgrounds.
function OrbArt.RarityBackground(frame: GuiObject, rarity: string)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Theme.RarityLight(rarity):Lerp(Theme.Rarity(rarity), 0.55), Theme.RarityDark(rarity))
	g.Rotation = 90
	g.Parent = frame
end

return OrbArt
