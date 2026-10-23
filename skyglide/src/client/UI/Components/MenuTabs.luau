--!strict
-- Horizontal tab bar for menus: one chunky Button per tab, the selected tab lights up in the
-- active style and grows slightly. Select() fires OnChanged; Cycle() steps left/right (used by
-- the shell's L1/R1 and Q/E bindings). Every tab is gamepad-selectable and >= 60 px tall.
local TweenService = game:GetService("TweenService")

local Components = script.Parent
local Create = require(Components.Parent.Create)
local Button = require(Components.Button)
local Icon = require(Components.Icon)

export type TabSpec = { Key: string, Text: string, Icon: string?, Style: string? }

export type TabsProps = {
	Parent: Instance,
	Tabs: { TabSpec },
	Size: UDim2,
	Position: UDim2?,
	TabWidth: number?,
	OnChanged: (key: string) -> (),
}

export type Tabs = {
	Instance: Frame,
	Selected: string,
	Buttons: { [string]: Button.Button },
	Select: (Tabs, key: string, silent: boolean?) -> (),
	Cycle: (Tabs, direction: number) -> (),
}

local MenuTabs = {}

local GROW = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

function MenuTabs.new(props: TabsProps): Tabs
	local bar: Frame = Create("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		Parent = props.Parent,
	})
	Create.List(bar, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

	local self = {
		Instance = bar,
		Selected = "",
		Buttons = {},
	} :: any
	local order: { string } = {}
	local scales: { [string]: UIScale } = {}

	for i, spec in props.Tabs do
		local key = spec.Key
		table.insert(order, key)
		local holder: Frame = Create("Frame", {
			Name = key,
			BackgroundTransparency = 1,
			Size = UDim2.new(0, props.TabWidth or 210, 1, 0),
			LayoutOrder = i,
			Parent = bar,
		})
		local scale = Instance.new("UIScale")
		scale.Scale = 0.94
		scale.Parent = holder
		scales[key] = scale
		-- an uploaded icon image sits left of the text; an emoji icon stays inline
		local image = if spec.Icon then Icon.Image(spec.Icon) else nil
		local b = Button.new({
			Parent = holder,
			Name = "Tab",
			Size = UDim2.fromScale(1, 1),
			Style = "Dark",
			Text = (if spec.Icon and not image then spec.Icon .. " " else "") .. spec.Text,
			TextSize = 30,
			Corner = 12,
			OnClick = function()
				self:Select(key)
			end,
		})
		if spec.Icon and image then
			Icon.new({
				Icon = spec.Icon,
				Size = UDim2.fromScale(0.78, 0.78),
				Position = UDim2.new(0, 10, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				ZIndex = b.Label.ZIndex,
				Parent = b.Content,
			})
			local aspect = Instance.new("UIAspectRatioConstraint")
			aspect.Parent = b.Content:FindFirstChild("Icon")
			b.Label.Size = UDim2.new(1, -66, 1, -6)
			b.Label.Position = UDim2.new(0.5, 26, 0.5, 0)
		end
		self.Buttons[key] = b
	end

	local styles: { [string]: string } = {}
	for _, spec in props.Tabs do
		styles[spec.Key] = spec.Style or "Blue"
	end

	function self.Select(this: any, key: string, silent: boolean?)
		if this.Buttons[key] == nil then
			return
		end
		local changed = this.Selected ~= key
		this.Selected = key
		for k, b in this.Buttons :: { [string]: Button.Button } do
			local on = k == key
			b:SetStyle(if on then styles[k] else "Dark")
			TweenService:Create(scales[k], GROW, { Scale = if on then 1 else 0.94 }):Play()
		end
		if changed and not silent then
			props.OnChanged(key)
		end
	end

	function self.Cycle(this: any, direction: number)
		local index = table.find(order, this.Selected) or 1
		local nextIndex = (index - 1 + direction) % #order + 1
		this:Select(order[nextIndex])
	end

	return self :: Tabs
end

return MenuTabs
