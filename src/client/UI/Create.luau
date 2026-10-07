--!strict
-- Tiny declarative instance builder used by every screen.
--   Create("Frame", { Size = ..., Parent = ... , [Create.Children] = {...} })
-- Function values are connected when the key names an event (e.g. Activated = fn).
local Theme = require(script.Parent.Theme)

local Create = {}
Create.Children = newproxy(false)

local function apply(inst: Instance, props: { [any]: any })
	local parent = nil
	for key, value in props do
		if key == Create.Children then
			for _, child in value do
				child.Parent = inst
			end
		elseif key == "Parent" then
			parent = value
		elseif type(value) == "function" then
			local ok, signal = pcall(function()
				return (inst :: any)[key]
			end)
			if ok and typeof(signal) == "RBXScriptSignal" then
				(signal :: RBXScriptSignal):Connect(value)
			else
				error("Create: " .. tostring(key) .. " is not an event of " .. inst.ClassName)
			end
		else
			(inst :: any)[key] = value
		end
	end
	if parent then
		inst.Parent = parent
	end
end

local function new(className: string, props: { [any]: any }?): any
	local inst = Instance.new(className)
	if inst:IsA("GuiObject") then
		(inst :: GuiObject).BorderSizePixel = 0
	end
	if props then
		apply(inst, props)
	end
	return inst
end

setmetatable(Create, {
	__call = function(_, className: string, props: { [any]: any }?): any
		return new(className, props)
	end,
})

Create.New = new
Create.Apply = apply

function Create.Corner(radius: number | UDim, parent: Instance?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = if typeof(radius) == "UDim" then radius :: UDim else UDim.new(0, radius :: number)
	c.Parent = parent
	return c
end

function Create.Round(parent: Instance?): UICorner
	return Create.Corner(UDim.new(0.5, 0), parent)
end

function Create.Stroke(parent: Instance?, color: Color3?, thickness: number?, transparency: number?, border: boolean?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.Colors.Stroke
	s.Thickness = thickness or 2
	s.Transparency = transparency or 0
	s.LineJoinMode = Enum.LineJoinMode.Round
	if border then
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	s.Parent = parent
	return s
end

function Create.Gradient(parent: Instance?, top: Color3, bottom: Color3, rotation: number?): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = rotation or 90
	g.Parent = parent
	return g
end

function Create.Padding(parent: Instance?, px: number, py: number?): UIPadding
	local p = Instance.new("UIPadding")
	local y = py or px
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.PaddingTop = UDim.new(0, y)
	p.PaddingBottom = UDim.new(0, y)
	p.Parent = parent
	return p
end

function Create.List(parent: Instance?, direction: Enum.FillDirection?, padding: number?, hAlign: Enum.HorizontalAlignment?, vAlign: Enum.VerticalAlignment?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.FillDirection = direction or Enum.FillDirection.Vertical
	l.Padding = UDim.new(0, padding or 0)
	l.HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left
	l.VerticalAlignment = vAlign or Enum.VerticalAlignment.Top
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = parent
	return l
end

function Create.Aspect(parent: Instance?, ratio: number): UIAspectRatioConstraint
	local a = Instance.new("UIAspectRatioConstraint")
	a.AspectRatio = ratio
	a.Parent = parent
	return a
end

export type TextProps = {
	Text: string,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Font: Font?,
	TextSize: number?,
	Scaled: boolean?,
	Color: Color3?,
	Stroke: number?,
	StrokeColor: Color3?,
	XAlign: Enum.TextXAlignment?,
	YAlign: Enum.TextYAlignment?,
	Parent: Instance?,
	Name: string?,
	ZIndex: number?,
	LayoutOrder: number?,
	RichText: boolean?,
	Wrapped: boolean?,
}

-- Text in the reference style: bold face, white, dark rounded stroke.
function Create.Text(p: TextProps): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = p.Name or "Text"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Size = p.Size
	label.Position = p.Position or UDim2.new()
	label.AnchorPoint = p.AnchorPoint or Vector2.zero
	label.FontFace = p.Font or Theme.Fonts.Body
	label.Text = p.Text
	label.TextColor3 = p.Color or Theme.Colors.Text
	label.TextXAlignment = p.XAlign or Enum.TextXAlignment.Center
	label.TextYAlignment = p.YAlign or Enum.TextYAlignment.Center
	label.RichText = p.RichText == true
	label.TextWrapped = p.Wrapped == true
	if p.Scaled then
		label.TextScaled = true
		if p.TextSize then
			local c = Instance.new("UITextSizeConstraint")
			c.MaxTextSize = p.TextSize
			c.Parent = label
		end
	else
		label.TextSize = p.TextSize or 24
	end
	if p.ZIndex then
		label.ZIndex = p.ZIndex
	end
	if p.LayoutOrder then
		label.LayoutOrder = p.LayoutOrder
	end
	if (p.Stroke or 0) > 0 then
		Create.Stroke(label, p.StrokeColor, p.Stroke)
	end
	label.Parent = p.Parent
	return label
end

return Create
