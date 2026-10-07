--!strict
-- Owns the ScreenGuis, responsive scaling, the screen router and toasts.
--
-- Layout model: every layer has one root Frame under a UIScale. Screens position with Scale +
-- AnchorPoint (so they stick to corners/centres on any aspect ratio) and size in design pixels
-- (1800 x 920 reference), which the UIScale converts for the actual viewport. Touch devices get
-- a size boost for comfortable tap targets. Safe areas come from ScreenInsets.CoreUISafeInsets.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Signal = require(Shared.Util.Signal)

local Client = script.Parent.Parent
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local AudioController = require(script.Parent.AudioController)

export type Screen = {
	Open: (any, ...any) -> (),
	Close: (any) -> (),
	IsOpen: (any) -> boolean,
}

local UIController = {}

UIController.Scale = 1
UIController.ScaleChanged = Signal.new()
UIController.ScreenOpened = Signal.new() -- (name)
UIController.ScreenClosed = Signal.new() -- (name)

local layers: { [string]: Frame } = {}
local layerScales: { UIScale } = {}
local screens: { [string]: Screen } = {}
local EXCLUSIVE = { Store = true, Inventory = true, Trade = true, Codes = true, Gems = true }
local toastHolder: Frame

local LAYERS = {
	{ Name = "HUD", Order = 1 },
	{ Name = "Battle", Order = 5 },
	{ Name = "Menus", Order = 10 },
	{ Name = "Overlay", Order = 20 },
	{ Name = "Toasts", Order = 30 },
}

local function computeScale(): number
	local camera = Workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Vector2.new(1800, 920)
	local s = math.min(size.X / Theme.DesignSize.X, size.Y / Theme.DesignSize.Y)
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		s *= 1.22 -- bigger tap targets on phones/tablets
	end
	if GuiService:IsTenFootInterface() then
		s *= 0.92 -- TV safe margin
	end
	return math.clamp(s, 0.42, 1.6)
end

local function applyScale()
	local s = computeScale()
	UIController.Scale = s
	for _, scale in layerScales do
		scale.Scale = s
	end
	for _, root in layers do
		root.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	UIController.ScaleChanged:Fire(s)
end

function UIController.Layer(name: string): Frame
	return layers[name]
end

function UIController.Register(name: string, screen: Screen)
	screens[name] = screen
end

function UIController.Get(name: string): Screen?
	return screens[name]
end

function UIController.Open(name: string, ...: any)
	local screen = screens[name]
	if screen == nil then
		warn("[UI] unknown screen " .. name)
		return
	end
	if EXCLUSIVE[name] then
		for other, s in screens do
			if other ~= name and EXCLUSIVE[other] and s:IsOpen() then
				s:Close()
				UIController.ScreenClosed:Fire(other)
			end
		end
	end
	screen:Open(...)
	UIController.ScreenOpened:Fire(name)
end

function UIController.Close(name: string)
	local screen = screens[name]
	if screen and screen:IsOpen() then
		screen:Close()
		UIController.ScreenClosed:Fire(name)
	end
end

function UIController.Toggle(name: string, ...: any)
	local screen = screens[name]
	if screen and screen:IsOpen() then
		UIController.Close(name)
	else
		UIController.Open(name, ...)
	end
end

function UIController.AnyMenuOpen(): boolean
	for name, s in screens do
		if EXCLUSIVE[name] and s:IsOpen() then
			return true
		end
	end
	return false
end

function UIController.CloseMenus()
	for name, s in screens do
		if EXCLUSIVE[name] and s:IsOpen() then
			UIController.Close(name)
		end
	end
end

local TOAST_COLORS = {
	Error = Color3.fromHex("#FF5A6A"),
	Info = Color3.fromHex("#9FD8FF"),
	Success = Color3.fromHex("#7CFF6B"),
	Quest = Color3.fromHex("#FFC72C"),
}

function UIController.Toast(text: string, kind: string?)
	if not toastHolder then
		return
	end
	local k = kind or "Info"
	if k == "Error" then
		AudioController.Play("Error", nil, 0.3)
	elseif k == "Quest" or k == "Success" then
		AudioController.Play("Reward", nil, 0.5)
	end
	local pill: Frame = Create("Frame", {
		Name = "Toast",
		BackgroundColor3 = Theme.Colors.PanelDeep,
		BackgroundTransparency = 0.08,
		Size = UDim2.fromOffset(560, 50),
		Parent = toastHolder,
	})
	Create.Corner(10, pill)
	Create.Stroke(pill, TOAST_COLORS[k] or TOAST_COLORS.Info, 2, 0, true)
	Create.Text({
		Text = text,
		Size = UDim2.new(1, -24, 1, -8),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = Theme.Fonts.Body,
		TextSize = 28,
		Scaled = true,
		Color = TOAST_COLORS[k] or Color3.new(1, 1, 1),
		Stroke = 1.5,
		Parent = pill,
	})
	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = pill
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(2.6, function()
		local t = TweenService:Create(scale, TweenInfo.new(0.2), { Scale = 0 })
		t:Play()
		t.Completed:Wait()
		pill:Destroy()
	end)
end

function UIController.Init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)
	for _, layer in LAYERS do
		local gui = Instance.new("ScreenGui")
		gui.Name = "OrbClash_" .. layer.Name
		gui.DisplayOrder = layer.Order
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = false
		gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.Parent = playerGui
		local root: Frame = Create("Frame", {
			Name = "Root",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Parent = gui,
		})
		local scale = Instance.new("UIScale")
		scale.Parent = root
		table.insert(layerScales, scale)
		layers[layer.Name] = root
	end
	toastHolder = Create("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(560, 400),
		Parent = layers.Toasts,
	})
	Create.List(toastHolder, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center)
	applyScale()
	local function watchCamera()
		local camera = Workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale)
		end
		applyScale()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()
end

return UIController
