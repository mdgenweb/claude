--!strict
-- Square inventory slot: rarity-coloured border and glow, a lazily built 3D ViewportFrame preview,
-- a name strip, a small stat line, and corner badges (equipped check, lock, quantity).
-- Slots are reused across refreshes (screens key them by uid/id), so previews are built once.
local TweenService = game:GetService("TweenService")

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local Viewport = require(script.Parent.Viewport)
local AudioController = require(UI.Parent.Controllers.AudioController)

export type SlotProps = {
	Parent: Instance,
	Name: string?,
	LayoutOrder: number?,
	Rarity: string,
	Build: () -> Model, -- preview model factory (called once, lazily)
	Title: string?,
	Stat: string?,
	OnClick: (() -> ())?,
	Spin: number?,
}

export type Slot = {
	Instance: TextButton,
	SetTitle: (Slot, string) -> (),
	SetStat: (Slot, string) -> (),
	SetRarity: (Slot, string) -> (),
	SetCorner: (Slot, string?) -> (), -- top-left badge text (e.g. "✅")
	SetTag: (Slot, string?) -> (), -- top-right badge text (e.g. "🔒", "x3")
	SetSelected: (Slot, boolean) -> (),
	SetDimmed: (Slot, boolean) -> (),
	Destroy: (Slot) -> (),
}

local ItemSlot = {}

local POP = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function ItemSlot.new(props: SlotProps): Slot
	local rarityColor = Theme.Rarity(props.Rarity)
	local root: TextButton = Create("TextButton", {
		Name = props.Name or "Slot",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
		LayoutOrder = props.LayoutOrder or 0,
		Selectable = true,
	})
	Create.Corner(14, root)
	local gradient = Create.Gradient(root, Theme.RarityLight(props.Rarity):Lerp(Theme.Colors.Card, 0.55), Theme.Colors.CardDeep, 90)
	local stroke = Create.Stroke(root, rarityColor, 3, 0, true)
	local scale = Instance.new("UIScale")
	scale.Parent = root

	local preview: Frame = Create("Frame", {
		Name = "Preview",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -50),
		Parent = root,
	})
	local title = Create.Text({
		Name = "Title",
		Text = props.Title or "",
		Size = UDim2.new(1, -10, 0, 22),
		Position = UDim2.new(0, 5, 1, -44),
		Font = Theme.Fonts.Display,
		TextSize = 20,
		Scaled = true,
		Stroke = 1.8,
		Parent = root,
	})
	local stat = Create.Text({
		Name = "Stat",
		Text = props.Stat or "",
		Size = UDim2.new(1, -10, 0, 20),
		Position = UDim2.new(0, 5, 1, -22),
		Font = Theme.Fonts.Body,
		TextSize = 18,
		Scaled = true,
		Color = Theme.Colors.Skill,
		Stroke = 1.4,
		Parent = root,
	})
	local corner = Create.Text({
		Name = "Corner",
		Text = "",
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.fromOffset(4, 4),
		TextSize = 26,
		Scaled = true,
		Stroke = 1.5,
		ZIndex = 3,
		Parent = root,
	})
	local tag = Create.Text({
		Name = "Tag",
		Text = "",
		Size = UDim2.fromOffset(44, 28),
		Position = UDim2.new(1, -4, 0, 4),
		AnchorPoint = Vector2.new(1, 0),
		Font = Theme.Fonts.Display,
		TextSize = 22,
		Scaled = true,
		Stroke = 1.8,
		ZIndex = 3,
		Parent = root,
	})

	local built = false
	local function ensurePreview()
		if built then
			return
		end
		built = true
		local ok, model = pcall(props.Build)
		if ok and model then
			Viewport.Model(preview, model, { Spin = props.Spin or 0.6, Yaw = math.pi, Pitch = math.rad(-10), Zoom = 1.1 })
		end
	end
	-- build the preview the first time the slot is actually on screen
	if root.AbsoluteSize.X > 0 then
		ensurePreview()
	else
		local conn: RBXScriptConnection? = nil
		conn = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if root.AbsoluteSize.X > 0 then
				ensurePreview()
				if conn then
					conn:Disconnect()
				end
			end
		end)
	end

	local self = { Instance = root } :: any

	function self.SetTitle(_: any, text: string)
		title.Text = text
	end
	function self.SetStat(_: any, text: string)
		stat.Text = text
	end
	function self.SetRarity(_: any, rarity: string)
		stroke.Color = Theme.Rarity(rarity)
		gradient.Color = ColorSequence.new(Theme.RarityLight(rarity):Lerp(Theme.Colors.Card, 0.55), Theme.Colors.CardDeep)
	end
	function self.SetCorner(_: any, text: string?)
		corner.Text = text or ""
	end
	function self.SetTag(_: any, text: string?)
		tag.Text = text or ""
	end
	function self.SetSelected(_: any, selected: boolean)
		stroke.Thickness = if selected then 6 else 3
		stroke.Color = if selected then Color3.new(1, 1, 1) else rarityColor
	end
	function self.SetDimmed(_: any, dimmed: boolean)
		root.BackgroundTransparency = if dimmed then 0.5 else 0
		title.TextTransparency = if dimmed then 0.4 else 0
	end
	function self.Destroy(_: any)
		root:Destroy()
	end

	root.MouseEnter:Connect(function()
		TweenService:Create(scale, POP, { Scale = 1.05 }):Play()
	end)
	root.MouseLeave:Connect(function()
		TweenService:Create(scale, POP, { Scale = 1 }):Play()
	end)
	root.Activated:Connect(function()
		AudioController.Play("Click")
		if props.OnClick then
			props.OnClick()
		end
	end)
	root.Parent = props.Parent
	return self :: Slot
end

return ItemSlot
