--!strict
-- Horizontal tab bar for menus: one chunky Button per tab, the selected tab lights up in the
-- active style and grows slightly. Select() fires OnChanged; Cycle() steps left/right (used by
-- the shell's L1/R1 and Q/E bindings). Every tab is gamepad-selectable and >= 60 px tall.
local TweenService = game:GetService("TweenService")

local Components = script.Parent
local Create = require(Components.Parent.Create)
local Button = require(Components.Button)

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
		local b = Button.new({
			Parent = holder,
			Name = "Tab",
			Size = UDim2.fromScale(1, 1),
			Style = "Dark",
			Text = (if spec.Icon then spec.Icon .. " " else "") .. spec.Text,
			TextSize = 30,
			Corner = 12,
			OnClick = function()
				self:Select(key)
			end,
		})
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
