--!strict
-- Vector-style icons built from frames (no image assets): coin, gem, heart, check, lock, swap.
-- Every icon fills its returned square Frame, so callers only set Size/Position.
local UI = script.Parent.Parent
local Create = require(UI.Create)

local Icons = {}

local hex = Color3.fromHex

local function box(name: string, size: UDim2?, parent: Instance?): Frame
	local f: Frame = Create("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = size or UDim2.fromOffset(40, 40),
		Parent = parent,
	})
	Create.Aspect(f, 1)
	return f
end

local function circle(parent: Instance, cx: number, cy: number, d: number, color: Color3, transparency: number?, z: number?): Frame
	local c: Frame = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(cx, cy),
		Size = UDim2.fromScale(d, d),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency or 0,
		ZIndex = z or 1,
		Parent = parent,
	})
	Create.Round(c)
	return c
end
Icons.Circle = circle

local function rect(parent: Instance, cx: number, cy: number, w: number, h: number, color: Color3, rotation: number?, corner: number?, z: number?): Frame
	local r: Frame = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(cx, cy),
		Size = UDim2.fromScale(w, h),
		BackgroundColor3 = color,
		Rotation = rotation or 0,
		ZIndex = z or 1,
		Parent = parent,
	})
	if corner then
		Create.Corner(UDim.new(corner, 0), r)
	end
	return r
end
Icons.Rect = rect

function Icons.Coin(size: UDim2?, parent: Instance?): Frame
	local f = box("Coin", size, parent)
	circle(f, 0.5, 0.53, 0.98, hex("#B86E00"))
	local face = circle(f, 0.5, 0.5, 0.94, hex("#FFC21A"), 0, 2)
	Create.Gradient(face, hex("#FFE27A"), hex("#FFA800"), 120)
	local inner = circle(f, 0.5, 0.5, 0.66, hex("#FFB300"), 0, 3)
	Create.Gradient(inner, hex("#FFB300"), hex("#FFD54A"), 120)
	circle(f, 0.36, 0.32, 0.18, Color3.new(1, 1, 1), 0.35, 4)
	return f
end

function Icons.Gem(size: UDim2?, parent: Instance?): Frame
	local f = box("Gem", size, parent)
	local shadow = rect(f, 0.5, 0.54, 0.66, 0.66, hex("#0D3C9E"), 45, 0.12, 1)
	shadow.BackgroundTransparency = 0.2
	local body = rect(f, 0.5, 0.5, 0.66, 0.66, hex("#3B8BFF"), 45, 0.12, 2)
	Create.Gradient(body, hex("#8FD0FF"), hex("#1C5FD6"), 0)
	local facet = rect(f, 0.5, 0.5, 0.36, 0.36, hex("#BDE6FF"), 45, 0.1, 3)
	facet.BackgroundTransparency = 0.25
	circle(f, 0.4, 0.33, 0.12, Color3.new(1, 1, 1), 0.1, 4)
	return f
end

-- Heart from a rotated square + two circles. `filled = false` renders the lost-heart state.
function Icons.Heart(size: UDim2?, parent: Instance?, filled: boolean?): Frame
	local f = box("Heart", size, parent)
	local color = if filled == false then hex("#3A3F52") else hex("#EF2B3C")
	local s = 1 / 1.707
	local cy = 0.854 * s * 1.0 + 0.04
	rect(f, 0.5, cy, s, s, color, 45, nil, 1)
	circle(f, 0.5 - 0.354 * s, cy - 0.354 * s, s, color, 0, 1)
	circle(f, 0.5 + 0.354 * s, cy - 0.354 * s, s, color, 0, 1)
	if filled ~= false then
		local gloss = circle(f, 0.3, 0.3, 0.2, Color3.new(1, 1, 1), 0.45, 2)
		gloss.Size = UDim2.fromScale(0.22, 0.16)
	end
	return f
end

function Icons.SetHeart(heart: Frame, filled: boolean)
	local color = if filled then hex("#EF2B3C") else hex("#3A3F52")
	for _, child in heart:GetChildren() do
		if child:IsA("Frame") and child.ZIndex == 1 then
			child.BackgroundColor3 = color
		elseif child:IsA("Frame") and child.ZIndex == 2 then
			child.Visible = filled
		end
	end
end

function Icons.Check(size: UDim2?, parent: Instance?, color: Color3?): Frame
	local f = box("Check", size, parent)
	local c = color or hex("#4CD420")
	rect(f, 0.36, 0.62, 0.16, 0.42, c, -45, 0.4, 1)
	rect(f, 0.6, 0.47, 0.16, 0.72, c, 40, 0.4, 1)
	return f
end

function Icons.Lock(size: UDim2?, parent: Instance?, color: Color3?): Frame
	local f = box("Lock", size, parent)
	local c = color or hex("#C9CCD3")
	local shackle = circle(f, 0.5, 0.36, 0.46, Color3.new(), 1, 1)
	Create.Stroke(shackle, c, 4, 0, true)
	rect(f, 0.5, 0.66, 0.64, 0.46, c, 0, 0.18, 2)
	rect(f, 0.5, 0.66, 0.1, 0.18, hex("#2A2F3D"), 0, 0.5, 3)
	return f
end

-- Two opposing arrows (used for the green "Tradable" badge).
function Icons.Swap(size: UDim2?, parent: Instance?, color: Color3?): Frame
	local f = box("Swap", size, parent)
	local c = color or hex("#4CD420")
	rect(f, 0.45, 0.32, 0.62, 0.14, c, 0, 0.5, 1)
	rect(f, 0.76, 0.32, 0.26, 0.26, c, 45, 0.15, 1)
	rect(f, 0.55, 0.68, 0.62, 0.14, c, 0, 0.5, 1)
	rect(f, 0.24, 0.68, 0.26, 0.26, c, 45, 0.15, 1)
	return f
end

function Icons.Plus(size: UDim2?, parent: Instance?, color: Color3?): Frame
	local f = box("Plus", size, parent)
	local c = color or Color3.new(1, 1, 1)
	rect(f, 0.5, 0.5, 0.64, 0.18, c, 0, 0.3, 1)
	rect(f, 0.5, 0.5, 0.18, 0.64, c, 0, 0.3, 1)
	return f
end

function Icons.Currency(currency: string, size: UDim2?, parent: Instance?): Frame
	if currency == "Gems" then
		return Icons.Gem(size, parent)
	end
	return Icons.Coin(size, parent)
end

return Icons
