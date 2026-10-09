--!strict
-- Training pads on the client. Every 0.2 s it finds the pad under the local character with the
-- same math as the server (MapService.PadAt) and fires Bus.PadChanged. While on a pad it shows the
-- pad panel (HUD layer, above the level bar): UNLOCKED/LOCKED, "<mult>x SKILL", the gate, an AUTO
-- toggle and a big TRAIN button (or "Unlock R$X" for a pass pad, or REBIRTH at max level).
-- Clicking/tapping the world (not GUI) or gamepad A on an unlocked pad sends RequestTrain,
-- throttled to Economy.TrainManualRate. The server picks the pad and pays; TrainResult only drives
-- the "+N ⚡" popups, a little character dip and the Train sound.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Map = require(Shared.Config.Map)
local Monetization = require(Shared.Config.Monetization)
local Training = require(Shared.Definitions.Training)
local Remotes = require(Shared.Net.Remotes)
local Format = require(Shared.Util.Format)

local Client = script.Parent.Parent
local StateController = require(script.Parent.StateController)
local UIController = require(script.Parent.UIController)
local AudioController = require(script.Parent.AudioController)
local Bus = require(script.Parent.Bus)
local Net = require(script.Parent.Net)
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local Button = require(Client.UI.Components.Button)
local HudFlightState = require(Client.UI.Components.HudFlightState)
local HUD = require(Client.UI.Screens.HUD)
local Effects = require(Client.VFX.Effects)

local TrainingController = {}

TrainingController.Pad = nil :: Training.Pad?

local localPlayer = Players.LocalPlayer
local ACTION = "SkyGlideTrain"
local SCAN_EVERY = 0.2
local MIN_GAP = 1 / Economy.TrainManualRate
local POP = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local hex = Color3.fromHex

local padsByWorld: { [number]: { Training.Pad } } = {}
local lastSent = -math.huge
local rng = Random.new()

-- character dip (root joint C0 offset; purely local and cosmetic)
local rootJoint: Motor6D? = nil
local rootC0 = CFrame.identity

local function padsFor(world: number): { Training.Pad }
	local list = padsByWorld[world]
	if list == nil then
		list = Training.ForWorld(world)
		padsByWorld[world] = list
	end
	return list
end

local function rootPart(): BasePart?
	local character = localPlayer.Character
	local part = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if part and part:IsA("BasePart") then part else nil
end

-- Same test as MapService.PadAt on the server.
local function padAt(position: Vector3, world: number): Training.Pad?
	local l = position - Map.Origin(world)
	local halfX = Map.PadSize.X / 2 + Map.StandTolerance
	local halfZ = Map.PadSize.Z / 2 + Map.StandTolerance
	for _, pad in padsFor(world) do
		local c = Map.PadPosition(pad.Slot)
		if math.abs(l.X - c.X) <= halfX and math.abs(l.Z - c.Z) <= halfZ and l.Y > c.Y - 2 and l.Y < c.Y + 12 then
			return pad
		end
	end
	return nil
end

local function isMaxLevel(data: { [string]: any }): boolean
	local derived = if type(data.Derived) == "table" then data.Derived else {}
	local cap = tonumber(derived.LevelCap)
	return cap ~= nil and (tonumber(data.Level) or 1) >= cap
end

-- (unlocked, reason text for the gate line)
local function padState(pad: Training.Pad, data: { [string]: any }?): (boolean, string)
	if pad.PassKey then
		local pass = Monetization.Pass(pad.PassKey)
		if StateController.HasPass(pad.PassKey) then
			return true, "ALL WORLDS PAD"
		end
		return false, "ALL WORLDS - " .. (if pass then pass.Name else "Pass") .. " pass"
	end
	local rebirths = if data then tonumber(data.Rebirths) or 0 else 0
	if rebirths < pad.Rebirths then
		return false, string.format("Needs %d %s Rebirths", pad.Rebirths, Theme.Icons.Rebirth)
	end
	return true, if pad.Rebirths > 0 then string.format("%d %s Rebirths", pad.Rebirths, Theme.Icons.Rebirth) else "Free for everyone"
end

-- Sends one manual rep if allowed (throttled). Returns true when an intent was sent.
function TrainingController.Train(): boolean
	local pad = TrainingController.Pad
	local data = StateController.Data
	if not pad or not data or HudFlightState.Active then
		return false
	end
	local unlocked = padState(pad, data)
	if not unlocked or isMaxLevel(data) then
		return false
	end
	local now = os.clock()
	if now - lastSent < MIN_GAP then
		return false
	end
	lastSent = now
	Net.Fire("RequestTrain")
	return true
end

local function findRootJoint(character: Model)
	rootJoint = nil
	local hrp = character:WaitForChild("HumanoidRootPart", 10)
	if not hrp then
		return
	end
	-- R15 "Root" lives in LowerTorso, R6 "RootJoint" in the HumanoidRootPart
	for _ = 1, 20 do
		for _, d in character:GetDescendants() do
			if d:IsA("Motor6D") and d.Part0 == hrp then
				rootJoint = d
				rootC0 = d.C0
				return
			end
		end
		task.wait(0.25)
		if character.Parent == nil then
			return
		end
	end
end

local dipToken = 0
local function dip()
	local joint = rootJoint
	if not joint or joint.Parent == nil then
		return
	end
	dipToken += 1
	local token = dipToken
	local down = TweenService:Create(joint, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		C0 = CFrame.new(0, -0.32, 0) * rootC0,
	})
	down:Play()
	task.delay(0.07, function()
		if token == dipToken and (joint.Parent :: Instance?) ~= nil then
			TweenService:Create(joint, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { C0 = rootC0 }):Play()
		end
	end)
end

function TrainingController.Start()
	local layer = UIController.Layer("HUD")

	-- Pad panel -----------------------------------------------------------------------------------
	local panel: Frame = Create("Frame", {
		Name = "PadPanel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -HUD.ContextBottom),
		Size = UDim2.fromOffset(620, 128),
		BackgroundColor3 = Theme.Colors.PanelDeep,
		BackgroundTransparency = 0.15,
		Visible = false,
		ZIndex = 3,
		Parent = layer,
	})
	Create.Corner(20, panel)
	local panelStroke = Create.Stroke(panel, Theme.Colors.Stroke, 4, 0, true)
	local panelScale = Instance.new("UIScale")
	panelScale.Parent = panel
	local status = Create.Text({
		Name = "Status",
		Text = "UNLOCKED",
		Size = UDim2.fromOffset(270, 30),
		Position = UDim2.fromOffset(18, 10),
		Font = Theme.Fonts.Display,
		TextSize = 30,
		Scaled = true,
		Color = Theme.Colors.Unlocked,
		Stroke = 2.5,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Parent = panel,
	})
	local mult = Create.Text({
		Name = "Mult",
		Text = "1x SKILL",
		Size = UDim2.fromOffset(270, 52),
		Position = UDim2.fromOffset(18, 40),
		Font = Theme.Fonts.Display,
		TextSize = 52,
		Scaled = true,
		Color = Theme.Colors.Skill,
		Stroke = 3.5,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Parent = panel,
	})
	local gate = Create.Text({
		Name = "Gate",
		Text = "",
		Size = UDim2.fromOffset(270, 26),
		Position = UDim2.fromOffset(18, 94),
		Font = Theme.Fonts.Display,
		TextSize = 24,
		Scaled = true,
		Color = Theme.Colors.TextDim,
		Stroke = 2,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Parent = panel,
	})

	local pendingAuto: boolean? = nil
	local function autoOn(): boolean
		if pendingAuto ~= nil then
			return pendingAuto
		end
		local data = StateController.Data
		return data ~= nil and type(data.Settings) == "table" and data.Settings.AutoTrain == true
	end

	local refreshPanel: () -> ()
	local autoButton = Button.new({
		Parent = panel,
		Name = "Auto",
		Size = UDim2.fromOffset(118, 80),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 298, 0.5, 0),
		Style = "Red",
		Text = Theme.Icons.Auto .. " AUTO",
		TextSize = 28,
		Corner = 14,
		ZIndex = 4,
		OnClick = function()
			local on = not autoOn()
			pendingAuto = on
			Net.Fire("RequestToggle", "AutoTrain", on)
			refreshPanel()
		end,
	})
	autoButton.Label.Size = UDim2.new(1, -12, 0.5, 0)
	autoButton.Label.Position = UDim2.fromScale(0.5, 0.34)
	local autoSub = Create.Text({
		Name = "State",
		Text = "OFF",
		Size = UDim2.new(1, -12, 0.36, 0),
		Position = UDim2.fromScale(0.5, 0.74),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = Theme.Fonts.Display,
		TextSize = 26,
		Scaled = true,
		Stroke = 2,
		ZIndex = autoButton.Instance.ZIndex + 2,
		Parent = autoButton.Content,
	})

	local trainHolder: Frame = Create("Frame", {
		Name = "TrainHolder",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(180, 92),
		ZIndex = 4,
		Parent = panel,
	})
	local trainPunch = Instance.new("UIScale")
	trainPunch.Parent = trainHolder
	local mode = "Train" -- "Train" | "Unlock" | "Rebirth" | "Locked"
	local trainButton = Button.new({
		Parent = trainHolder,
		Name = "Train",
		Size = UDim2.fromScale(1, 1),
		Style = "Green",
		Text = "TRAIN",
		TextSize = 44,
		Corner = 18,
		ZIndex = 4,
		Silent = true,
		OnClick = function()
			local pad = TrainingController.Pad
			if mode == "Train" then
				TrainingController.Train()
			elseif mode == "Unlock" and pad and pad.PassKey then
				AudioController.Play("Click")
				task.spawn(Net.Invoke, "RequestPurchase", false, "Pass", pad.PassKey)
			elseif mode == "Rebirth" then
				AudioController.Play("Click")
				UIController.Open("Rebirth")
			else
				AudioController.Play("Error", nil, 0.2)
			end
		end,
	})

	refreshPanel = function()
		local pad = TrainingController.Pad
		local data = StateController.Data
		if not pad then
			panel.Visible = false
			return
		end
		local unlocked, reason = padState(pad, data)
		local maxed = data ~= nil and isMaxLevel(data)
		local accent = hex(pad.Color)
		panelStroke.Color = accent:Lerp(Theme.Colors.Stroke, 0.35)
		mult.Text = Format.Short(pad.Multiplier) .. "x SKILL"
		if maxed and unlocked then
			status.Text = "MAX LEVEL - REBIRTH!"
			status.TextColor3 = Theme.Colors.Rebirth
			gate.Text = "Training is paused at the level cap"
			mode = "Rebirth"
			trainButton:SetStyle("Pink")
			trainButton:SetText(Theme.Icons.Rebirth .. " REBIRTH")
		elseif unlocked then
			status.Text = "UNLOCKED"
			status.TextColor3 = Theme.Colors.Unlocked
			gate.Text = reason
			mode = "Train"
			trainButton:SetStyle("Green")
			trainButton:SetText("TRAIN")
		else
			status.Text = Theme.Icons.Lock .. " LOCKED"
			status.TextColor3 = Theme.Colors.Locked
			gate.Text = reason
			if pad.PassKey then
				local pass = Monetization.Pass(pad.PassKey)
				local available = pass ~= nil and (pass.Id ~= 0 or RunService:IsStudio())
				mode = if available then "Unlock" else "Locked"
				trainButton:SetStyle(if available then "Gold" else "Disabled")
				trainButton:SetText(if available and pass then "Unlock " .. Theme.Icons.Robux .. tostring(pass.Robux) else "SOON")
			else
				mode = "Locked"
				trainButton:SetStyle("Disabled")
				trainButton:SetText(string.format("%s %d %s", Theme.Icons.Lock, pad.Rebirths, Theme.Icons.Rebirth))
			end
		end
		local on = autoOn()
		autoButton:SetStyle(if on then "Green" else "Red")
		autoSub.Text = if on then "ON" else "OFF"
		panel.Visible = not HudFlightState.Active
	end

	-- gamepad A trains while standing on an open pad (sinks the jump only then)
	local bound = false
	local function onAction(_: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
		if GuiService.SelectedObject ~= nil then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then
			TrainingController.Train()
		end
		return Enum.ContextActionResult.Sink
	end
	local function refreshBinding()
		local pad = TrainingController.Pad
		local data = StateController.Data
		local want = pad ~= nil and data ~= nil and (padState(pad, data)) and not isMaxLevel(data) and not HudFlightState.Active
		if want and not bound then
			bound = true
			ContextActionService:BindActionAtPriority(ACTION, onAction, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonA)
		elseif not want and bound then
			bound = false
			ContextActionService:UnbindAction(ACTION)
		end
	end

	local function setPad(pad: Training.Pad?)
		if pad == TrainingController.Pad then
			return
		end
		local had = TrainingController.Pad ~= nil
		TrainingController.Pad = pad
		Bus.PadChanged:Fire(pad)
		refreshPanel()
		refreshBinding()
		if pad and not had and panel.Visible then
			panelScale.Scale = 0.7
			TweenService:Create(panelScale, POP, { Scale = 1 }):Play()
		end
	end

	-- world clicks / taps (GUI clicks arrive as gameProcessed and are ignored)
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or TrainingController.Pad == nil then
			return
		end
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			TrainingController.Train()
		end
	end)

	-- server results -> feedback
	Remotes.Event("TrainResult").OnClientEvent:Connect(function(payload: any)
		local amount = if type(payload) == "table" then tonumber(payload.Amount) else tonumber(payload)
		if not amount or amount <= 0 then
			return
		end
		Bus.TrainResult:Fire(amount)
		AudioController.Play("Train", nil, 0.05)
		local hrp = rootPart()
		if hrp then
			local offset = Vector3.new(rng:NextNumber(-1.6, 1.6), 3.6 + rng:NextNumber(0, 0.8), rng:NextNumber(-0.8, 0.8))
			Effects.Popup(hrp.Position + offset, "+" .. Format.Short(amount) .. " " .. Theme.Icons.Skill, Theme.Colors.Skill, 1.1)
		end
		dip()
		if panel.Visible then
			trainPunch.Scale = 0.9
			TweenService:Create(trainPunch, POP, { Scale = 1 }):Play()
		end
	end)

	StateController.DataChanged:Connect(function()
		pendingAuto = nil
		refreshPanel()
		refreshBinding()
	end)
	HudFlightState.Changed:Connect(function()
		refreshPanel()
		refreshBinding()
	end)

	local function onCharacter(character: Model)
		setPad(nil)
		task.spawn(findRootJoint, character)
	end
	localPlayer.CharacterAdded:Connect(onCharacter)
	if localPlayer.Character then
		onCharacter(localPlayer.Character)
	end

	-- pad scan
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < SCAN_EVERY then
			return
		end
		acc = 0
		local hrp = rootPart()
		local data = StateController.Data
		if not hrp or not data then
			setPad(nil)
			return
		end
		local world = tonumber(data.World) or 1
		setPad(padAt(hrp.Position, world))
	end)
end

return TrainingController
