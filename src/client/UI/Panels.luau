-- Panel manager: one panel at a time, springy open/close, dimmed backdrop.
-- "Blocking" panels tell the server, which pauses salvage and boost time meanwhile.

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Theme)

local UIKit = require(script.Parent.UIKit)
local Gui = require(script.Parent.Gui)
local Net = require(script.Parent.Parent.Net)

local Panels = {}

export type Panel = {
	Name: string,
	Blocking: boolean,
	Window: Frame,
	Body: Frame,
	OnOpen: ((any?) -> ())?,
	OnClose: (() -> ())?,
}

local registry: { [string]: Panel } = {}
local current: string? = nil
local backdrop: TextButton? = nil
local menuSent = false

local function setMenu(open: boolean)
	if open ~= menuSent then
		menuSent = open
		task.spawn(Net.request, "Menu", open)
	end
end

local function ensureBackdrop(): TextButton
	if backdrop then
		return backdrop
	end
	local b = UIKit.new("TextButton", {
		Name = "Backdrop",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(3, 3),
		Position = UDim2.fromScale(-1, -1),
		Visible = false,
		Parent = Gui.Layers.Panels,
	})
	b.Activated:Connect(function()
		Panels.close()
	end)
	backdrop = b
	return b
end

-- Creates a panel window: navy body, colored title tab, red close button.
function Panels.create(props: { [string]: any }): Panel
	local width, height = props.Width or 760, props.Height or 470
	local window = UIKit.new("Frame", {
		Name = props.Name,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(width, height),
		Position = props.Position or UDim2.new(0.5, 0, 0.5, 14),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		ZIndex = 2,
		Parent = Gui.Layers.Panels,
	})
	local body = UIKit.surface(window, {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		Swatch = Theme.Swatch.Navy,
		Radius = Theme.Radius.L,
		StrokeThickness = Theme.Stroke.Heavy,
		Shine = false,
		ShadowOffset = 7,
	})
	-- Title tab overlapping the top-left edge, like popular simulator shops.
	local swatch = props.Swatch or Theme.Swatch.Green
	local tab = UIKit.surface(window, {
		Name = "Tab",
		Size = UDim2.fromOffset(props.TabWidth or 250, 60),
		Position = UDim2.fromOffset(22, -30),
		Swatch = swatch,
		Radius = Theme.Radius.L,
		ZIndex = 3,
	})
	if props.Icon then
		UIKit.icon(tab.Face, props.Icon, UDim2.fromOffset(48, 48), UDim2.new(0, 8, 0.5, 0), Vector2.new(0, 0.5))
	end
	UIKit.text(tab.Face, {
		Text = props.Title,
		TextSize = Theme.Text.H1 + 4,
		Size = UDim2.new(1, if props.Icon then -66 else -20, 0.86, 0),
		Position = UDim2.new(0, if props.Icon then 58 else 10, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		ZIndex = 3,
	})
	local close = UIKit.button(window, {
		Name = "Close",
		Text = "X",
		TextSize = 30,
		Size = UDim2.fromOffset(56, 56),
		Position = UDim2.new(1, -18, 0, -20),
		AnchorPoint = Vector2.new(0.5, 0),
		Swatch = Theme.Swatch.Red,
		ZIndex = 4,
		OnClick = function()
			Panels.close()
		end,
	})
	close.Holder.ZIndex = 4
	local content = UIKit.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -40, 1, -64),
		Position = UDim2.fromOffset(20, 44),
		ZIndex = 2,
		Parent = body.Face,
	})
	local panel: Panel = {
		Name = props.Name,
		Blocking = props.Blocking ~= false,
		Window = window,
		Body = content,
		OnOpen = nil,
		OnClose = nil,
	}
	registry[props.Name] = panel
	return panel
end

function Panels.isOpen(name: string?): boolean
	if name then
		return current == name
	end
	return current ~= nil
end

function Panels.current(): string?
	return current
end

function Panels.open(name: string, arg: any?)
	local panel = registry[name]
	if not panel then
		return
	end
	if current == name then
		if panel.OnOpen then
			panel.OnOpen(arg)
		end
		return
	end
	if current then
		Panels.close(true)
	end
	current = name
	local b = ensureBackdrop()
	b.Visible = true
	UIKit.tween(b, 0.2, { BackgroundTransparency = 0.55 })
	local window = panel.Window
	window.Visible = true
	local scale = UIKit.scaleOf(window)
	if UIKit.reducedMotion then
		scale.Scale = 1
	else
		scale.Scale = 0.7
		UIKit.tween(scale, Theme.Motion.PanelIn, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	if panel.OnOpen then
		panel.OnOpen(arg)
	end
	setMenu(panel.Blocking)
	Net.MenuChanged:Fire(name)
end

function Panels.close(switching: boolean?)
	local name = current
	if not name then
		return
	end
	local panel = registry[name]
	current = nil
	if panel.OnClose then
		panel.OnClose()
	end
	local window = panel.Window
	local scale = UIKit.scaleOf(window)
	UIKit.tween(scale, Theme.Motion.PanelOut, { Scale = 0.85 })
	task.delay(Theme.Motion.PanelOut, function()
		if current ~= name then
			window.Visible = false
		end
	end)
	if not switching then
		local b = ensureBackdrop()
		UIKit.tween(b, 0.15, { BackgroundTransparency = 1 })
		task.delay(0.15, function()
			if not current then
				b.Visible = false
			end
		end)
		setMenu(false)
		Net.MenuChanged:Fire(nil)
	end
end

function Panels.toggle(name: string, arg: any?)
	if current == name then
		Panels.close()
	else
		Panels.open(name, arg)
	end
end

function Panels.init()
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			if current and not processed then
				Panels.close()
			end
		end
	end)
	-- Close panels when the Roblox menu opens so nothing stays "blocking" in the background.
	GuiService.MenuOpened:Connect(function()
		Panels.close()
	end)
end

return Panels
