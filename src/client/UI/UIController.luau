--!nonstrict
-- UI root: builds the ScreenGuis, scales the 1920x1080 design to any screen, routes panels and
-- keybind actions, photo mode, screen flashes and the loading screen.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Ingredients = require(Shared.Data.Ingredients)

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)

local Signal = require(Shared.Util.Signal)

local UIController = {
	panels = {},
	openPanel = nil,
	PanelOpened = Signal.new(), -- (name)
}

local COMMANDS = {
	slowmo = true,
	pause = true,
	heal = true,
	reset = true,
	undo = true,
	spawnLast = true,
	clearZombies = true,
}

local function makeGui(name: string, order: number, ignoreInset: boolean): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = ignoreInset
	gui.ScreenInsets = if ignoreInset then Enum.ScreenInsets.None else Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = order
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

-- A container that fills the screen while its children are laid out in design pixels.
local function scaledRoot(gui: ScreenGui, touch: boolean): (Frame, UIScale)
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local function update()
		local size = gui.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		local s = math.min(size.X / Theme.DesignResolution.X, size.Y / Theme.DesignResolution.Y)
		if touch then
			s *= 1.3
		end
		s = math.clamp(s, 0.45, 1.4)
		scale.Scale = s
		root.Size = UDim2.fromOffset(size.X / s, size.Y / s)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	update()
	return root, scale
end

function UIController:Init(controllers)
	self.C = controllers
end

function UIController:Start()
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Health, false)
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.EmotesMenu, false)

	local touch = self.C.InputController:IsTouch()
	self.touch = touch
	self.hudGui = makeGui("FlaskHUD", 5, false)
	self.modalGui = makeGui("FlaskModals", 20, true)
	self.overlayGui = makeGui("FlaskOverlay", 100, true)
	self.hud = scaledRoot(self.hudGui, touch)
	self.modals = scaledRoot(self.modalGui, touch)
	self.overlay = self.overlayGui
	self.overlayScaled = scaledRoot(self.overlayGui, touch)
	Components.setSoundHandler(function(name)
		self.C.SoundController:Play(name, nil, { ui = true })
	end)
	Components.mountTooltip(self.overlayScaled)

	-- Screen flash overlay.
	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 300
	flash.Interactable = false
	flash.Parent = self.overlayGui
	self.flash = flash

	-- Slow-mo vignette.
	local vignette = Instance.new("Frame")
	vignette.Name = "Vignette"
	vignette.BackgroundColor3 = Color3.fromRGB(40, 90, 160)
	vignette.BackgroundTransparency = 1
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.Interactable = false
	vignette.ZIndex = 1
	vignette.Parent = self.overlayGui
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.18, 1),
		NumberSequenceKeypoint.new(0.82, 1),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	gradient.Parent = vignette
	self.vignette = vignette

	self:_loading()

	local Panels = script.Parent
	local function mount(name: string, moduleName: string)
		local module = require(Panels:WaitForChild(moduleName))
		module:Mount(self, self.C)
		self.panels[name] = module
	end
	self.Notifications = require(Panels.Notifications)
	self.Notifications:Mount(self, self.C)
	self.Hud = require(Panels.Hud)
	self.Hud:Mount(self, self.C)
	self.Hotbar = require(Panels.Hotbar)
	self.Hotbar:Mount(self, self.C)
	self.TrialHud = require(Panels.TrialHud)
	self.TrialHud:Mount(self, self.C)
	mount("brew", "BrewPanel")
	mount("codex", "CodexPanel")
	mount("challenges", "ChallengesPanel")
	mount("shop", "ShopPanel")
	mount("menu", "MenuPanel")
	mount("help", "HelpPanel")
	self.Tutorial = require(Panels.Tutorial)
	self.Tutorial:Mount(self, self.C)

	self.C.InputController.Action:Connect(function(action)
		self:_action(action)
	end)
	self.C.GrabController.InteractivePressed:Connect(function(kind)
		if kind == "Cauldron" then
			self:Open("brew")
		elseif kind == "Rack" then
			self:ClaimRack()
		end
	end)
	self.C.State.LabChanged:Connect(function(lab)
		TweenService:Create(
			vignette,
			TweenInfo.new(0.3),
			{ BackgroundTransparency = if lab.slowmo then 0.55 elseif lab.paused then 0.7 else 1 }
		):Play()
		vignette.BackgroundColor3 = if lab.paused then Color3.fromRGB(80, 80, 110) else Color3.fromRGB(40, 90, 160)
	end)
	GuiService.MenuOpened:Connect(function()
		self.C.GrabController:ForceDrop()
	end)
end

function UIController:_loading()
	local screen = Instance.new("Frame")
	screen.Name = "Loading"
	screen.BackgroundColor3 = Theme.Color.Surface.Base
	screen.Size = UDim2.fromScale(1, 1)
	screen.ZIndex = 400
	screen.Parent = self.overlayGui
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(40, 24, 70), Theme.Color.Surface.Base)
	gradient.Rotation = 90
	gradient.Parent = screen
	local title = Components.text({
		parent = screen,
		text = "FLASK FIASCO",
		type = "Display",
		textSize = 96,
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 110),
		position = UDim2.fromScale(0.5, 0.42),
		anchor = Vector2.new(0.5, 0.5),
		color = Theme.Color.Accent.Gold,
		z = 401,
	})
	local subtitle = Components.text({
		parent = screen,
		text = "🧪  Warming up the cauldron...",
		type = "Heading",
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 40),
		position = UDim2.fromScale(0.5, 0.53),
		anchor = Vector2.new(0.5, 0.5),
		color = Theme.Color.Text.Secondary,
		z = 401,
	})
	local tips = {
		"Tip: Frozen golems shatter when they hit something hard!",
		"Tip: Mix two ingredients you've never combined to discover new potions.",
		"Tip: Press G for slow motion, Space to stop time.",
		"Tip: Brew a potion 5 times to master it: infinite bottles!",
		"Tip: Fire + Ice makes a steam explosion.",
	}
	local tip = Components.text({
		parent = screen,
		text = tips[math.random(1, #tips)],
		type = "Body",
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 30),
		position = UDim2.new(0.5, 0, 1, -80),
		anchor = Vector2.new(0.5, 0.5),
		color = Theme.Color.Text.Muted,
		z = 401,
	})
	local _ = tip
	local bob = 0
	local conn = game:GetService("RunService").RenderStepped:Connect(function(dt)
		bob += dt
		title.Position = UDim2.new(0.5, 0, 0.42, math.sin(bob * 2) * 6)
	end)
	local function finish()
		conn:Disconnect()
		subtitle.Text = "✨ Ready!"
		task.wait(0.4)
		local tween = TweenService:Create(screen, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
		for _, child in screen:GetDescendants() do
			if child:IsA("TextLabel") then
				TweenService:Create(child, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			elseif child:IsA("UIStroke") then
				TweenService:Create(child, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end
		end
		tween:Play()
		tween.Completed:Wait()
		screen:Destroy()
	end
	task.spawn(function()
		local State = self.C.State
		local started = os.clock()
		while not (State.ready and State.lab) and os.clock() - started < 30 do
			task.wait(0.1)
		end
		finish()
	end)
end

function UIController:_action(action: string)
	local State = self.C.State
	if action == "back" then
		if self.openPanel then
			self:Close()
		elseif State.photoMode then
			self:SetPhotoMode(false)
		elseif State.selected then
			State:Select(nil)
		end
		return
	end
	if COMMANDS[action] then
		Net.event("Command"):FireServer(action)
		if action == "heal" then
			self.C.SoundController:Play("heal")
		end
		return
	end
	if action == "photo" then
		self:SetPhotoMode(not State.photoMode)
	elseif action == "follow" then
		local model = self.C.GrabController.hoverModel
		local torso = model and model:FindFirstChild("Torso")
		self.C.CameraController:Follow(torso)
		if not torso then
			self.C.CameraController:Reset()
		end
	elseif self.panels[action] then
		self:Toggle(action)
	end
end

function UIController:Open(name: string)
	local panel = self.panels[name]
	if not panel then
		return
	end
	if self.openPanel and self.openPanel ~= name then
		self.panels[self.openPanel]:Close()
	end
	self.openPanel = name
	self.C.GrabController:ForceDrop()
	panel:Open()
	self.C.InputController.enabled = false
	self.PanelOpened:Fire(name)
end

function UIController:Close()
	if self.openPanel then
		local panel = self.panels[self.openPanel]
		self.openPanel = nil
		panel:Close()
	end
	self.C.InputController.enabled = true
	Components.hideTooltip()
end

-- Panels call this when their modal closes itself (close button).
function UIController:PanelClosed(name: string)
	if self.openPanel == name then
		self.openPanel = nil
		self.C.InputController.enabled = true
	end
end

function UIController:Toggle(name: string)
	if self.openPanel == name then
		self:Close()
	else
		self:Open(name)
	end
end

function UIController:SetPhotoMode(on: boolean)
	local State = self.C.State
	State.photoMode = on
	State.PhotoModeChanged:Fire(on)
	self.hudGui.Enabled = not on
	if on then
		self:Close()
		self:Toast("📷 Photo mode: press P or Esc to exit", "info")
	end
end

function UIController:ScreenFlash(color: Color3, alpha: number, duration: number)
	self.flash.BackgroundColor3 = color
	self.flash.BackgroundTransparency = 1 - alpha
	TweenService:Create(self.flash, TweenInfo.new(duration, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
		:Play()
end

function UIController:Toast(text: string, kind: string?)
	self.Notifications:Toast(text, kind or "info")
end

function UIController:ClaimRack()
	local result = Net.func("Shop"):InvokeServer("claimRack")
	if result and result.ok then
		local parts = {}
		for id, amount in result.items do
			local ingredient = Ingredients.ById[id]
			if ingredient then
				table.insert(parts, ingredient.icon .. " x" .. amount)
			end
		end
		self:Toast("🌿 Picked fresh herbs: " .. table.concat(parts, "  "), "reward")
		self.C.SoundController:Play("reward")
	elseif result then
		self:Toast(result.reason or "Nothing to pick yet.", "info")
	end
end

-- Viewport-space position → design-space position inside a scaled root.
function UIController:ToDesign(root: Frame, viewport: Vector2): Vector2
	local scale = root:FindFirstChildOfClass("UIScale")
	local s = if scale then scale.Scale else 1
	local inset = if root:FindFirstAncestorOfClass("ScreenGui")
			and (root:FindFirstAncestorOfClass("ScreenGui") :: ScreenGui).IgnoreGuiInset
		then Vector2.zero
		else GuiService:GetGuiInset()
	return (viewport - inset) / s
end

local _ = UserInputService
local __ = Workspace
return UIController
