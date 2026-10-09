--!strict
-- First-session guide (client side of TutorialService). While Data.Tutorial.Done is false it shows
-- a hint bar under AUTO THROW (Definitions/Tutorial step text, "x/Count" progress, a Skip button
-- with a confirm tap) and guides the character to the step's target: a sparkly Beam from the
-- HumanoidRootPart to an invisible anchored part plus a bobbing neon arrow above the target.
-- Steps only advance on the server; this module just draws. Everything is torn down when the
-- tutorial ends, and the beam re-attaches on respawn.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Map = require(Shared.Config.Map)
local Tutorial = require(Shared.Definitions.Tutorial)

local Client = script.Parent.Parent
local StateController = require(script.Parent.StateController)
local UIController = require(script.Parent.UIController)
local Net = require(script.Parent.Net)
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local Button = require(Client.UI.Components.Button)
local HudFlightState = require(Client.UI.Components.HudFlightState)
local Effects = require(Client.VFX.Effects)

local TutorialController = {}

local localPlayer = Players.LocalPlayer
local GOLD = Color3.fromHex("#FFD447")
local POP = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local BAR_TOP = 96
local ARROW_HEIGHT = 10
local NEAR = 12 -- studs: hide the beam once the player is this close (the arrow stays)

-- Arrow pieces relative to the arrow origin (apex points down at the target).
local SHAFT_OFFSET = CFrame.new(0, 2.6, 0)
local HEAD_LEFT = CFrame.new(0, -0.4, -0.9) * CFrame.Angles(0, 0, math.pi)
local HEAD_RIGHT = CFrame.new(0, -0.4, 0.9) * CFrame.Angles(0, math.pi, math.pi)

-- World position of a step's target anchor (matches MapService.Anchor on the server).
local function targetPosition(target: string?, world: number): Vector3?
	if target == nil then
		return nil
	end
	local origin = Map.Origin(world)
	if target == "Pad1" then
		return origin + Map.PadPosition(1)
	elseif target == "ThrowZone" then
		local zone = Map.ThrowZone
		return origin + Vector3.new((zone.MinX + zone.MaxX) / 2, 0, (zone.MinZ + zone.MaxZ) / 2)
	elseif target == "GliderShop" then
		return origin + Map.PedestalPosition(2)
	elseif target == "Egg1" then
		return origin + Map.EggPosition(1)
	end
	return nil
end

type Guide = {
	Folder: Folder,
	Anchor: Part,
	EndAttachment: Attachment,
	Beam: Beam,
	Shaft: Part,
	Left: WedgePart,
	Right: WedgePart,
}

local function neon(className: string, size: Vector3, parent: Instance): BasePart
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = GOLD
	p.Size = size
	p.Parent = parent
	return p
end

local function buildGuide(): Guide
	local folder = Instance.new("Folder")
	folder.Name = "TutorialGuide"
	folder.Parent = Effects.Folder()
	local anchor = neon("Part", Vector3.one, folder) :: Part
	anchor.Name = "Target"
	anchor.Transparency = 1
	local endAttachment = Instance.new("Attachment")
	endAttachment.Name = "GuideEnd"
	endAttachment.Position = Vector3.new(0, 1.5, 0)
	endAttachment.Parent = anchor
	local beam = Instance.new("Beam")
	beam.Name = "GuideBeam"
	beam.Attachment1 = endAttachment
	beam.Color = ColorSequence.new(GOLD, Color3.fromHex("#FFF6C2"))
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.15, 0.15),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Width0 = 1.4
	beam.Width1 = 1.4
	beam.Segments = 24
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = 3
	beam.TextureSpeed = 1.6
	beam.Parent = anchor
	local shaft = neon("Part", Vector3.new(1.2, 3, 1.2), folder) :: Part
	shaft.Name = "ArrowShaft"
	local left = neon("WedgePart", Vector3.new(1.2, 2.4, 1.8), folder) :: WedgePart
	left.Name = "ArrowHeadL"
	local right = neon("WedgePart", Vector3.new(1.2, 2.4, 1.8), folder) :: WedgePart
	right.Name = "ArrowHeadR"
	return {
		Folder = folder,
		Anchor = anchor,
		EndAttachment = endAttachment,
		Beam = beam,
		Shaft = shaft,
		Left = left,
		Right = right,
	}
end

function TutorialController.Start()
	local layer = UIController.Layer("HUD")

	-- Hint bar ------------------------------------------------------------------------------------
	local bar: Frame = Create("Frame", {
		Name = "TutorialBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, BAR_TOP),
		Size = UDim2.fromOffset(780, 62),
		BackgroundColor3 = Theme.Colors.PanelDeep,
		BackgroundTransparency = 0.12,
		Visible = false,
		ZIndex = 3,
		Parent = layer,
	})
	Create.Corner(18, bar)
	Create.Stroke(bar, GOLD, 3, 0, true)
	local barScale = Instance.new("UIScale")
	barScale.Parent = bar
	local stepText = Create.Text({
		Name = "Step",
		Text = "",
		Size = UDim2.fromOffset(90, 22),
		Position = UDim2.fromOffset(18, -11),
		Font = Theme.Fonts.Display,
		TextSize = 20,
		Scaled = true,
		Color = GOLD,
		Stroke = 2.5,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 5,
		Parent = bar,
	})
	local hint = Create.Text({
		Name = "Hint",
		Text = "",
		Size = UDim2.new(1, -250, 0, 44),
		Position = UDim2.new(0, 18, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Font = Theme.Fonts.Display,
		TextSize = 30,
		Scaled = true,
		Stroke = 2.5,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Parent = bar,
	})
	local chip: Frame = Create("Frame", {
		Name = "Progress",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -124, 0.5, 0),
		Size = UDim2.fromOffset(92, 40),
		BackgroundColor3 = Theme.Colors.Success,
		Visible = false,
		ZIndex = 4,
		Parent = bar,
	})
	Create.Round(chip)
	Create.Stroke(chip, Theme.Colors.Stroke, 2.5, 0, true)
	local chipScale = Instance.new("UIScale")
	chipScale.Parent = chip
	local progress = Create.Text({
		Name = "Text",
		Text = "",
		Size = UDim2.fromScale(0.84, 0.8),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = Theme.Fonts.Display,
		TextSize = 26,
		Scaled = true,
		Stroke = 2,
		ZIndex = 5,
		Parent = chip,
	})

	local confirmUntil = 0
	local skip: Button.Button
	skip = Button.new({
		Parent = bar,
		Name = "Skip",
		Size = UDim2.fromOffset(104, 60),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Style = "Grey",
		Text = "Skip",
		TextSize = 28,
		Corner = 14,
		ZIndex = 4,
		OnClick = function()
			local now = os.clock()
			if now < confirmUntil then
				confirmUntil = 0
				Net.Fire("RequestTutorial", "Skip")
				skip:SetText("...")
				return
			end
			confirmUntil = now + 3
			skip:SetText("Sure?")
			skip:SetStyle("Red")
			task.delay(3, function()
				if os.clock() >= confirmUntil and confirmUntil ~= 0 then
					confirmUntil = 0
					skip:SetText("Skip")
					skip:SetStyle("Grey")
				end
			end)
		end,
	})

	-- Guide ---------------------------------------------------------------------------------------
	local guide: Guide? = nil
	local startAttachment: Attachment? = nil
	local target: Vector3? = nil
	local renderConn: RBXScriptConnection? = nil
	local shownStep = 0
	local shownProgress = -1

	local function attachCharacter(character: Model?)
		if startAttachment then
			startAttachment:Destroy()
			startAttachment = nil
		end
		local g = guide
		if not g or not character then
			return
		end
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp or not hrp:IsA("BasePart") then
			return
		end
		local a = Instance.new("Attachment")
		a.Name = "TutorialGuideStart"
		a.Position = Vector3.new(0, -1.8, 0)
		a.Parent = hrp
		startAttachment = a
		g.Beam.Attachment0 = a
	end

	local function stepGuide()
		local g = guide
		local pos = target
		if not g or not pos then
			return
		end
		local t = os.clock()
		local base = CFrame.new(pos + Vector3.new(0, ARROW_HEIGHT + math.sin(t * 3) * 1.2, 0)) * CFrame.Angles(0, t * 1.8, 0)
		g.Shaft.CFrame = base * SHAFT_OFFSET
		g.Left.CFrame = base * HEAD_LEFT
		g.Right.CFrame = base * HEAD_RIGHT
		local a = startAttachment
		local near = true
		if a and a.Parent then
			local delta = a.WorldPosition - pos
			near = Vector3.new(delta.X, 0, delta.Z).Magnitude < NEAR
		end
		g.Beam.Enabled = not near and not HudFlightState.Active
	end

	local function clearGuide()
		if renderConn then
			renderConn:Disconnect()
			renderConn = nil
		end
		if startAttachment then
			startAttachment:Destroy()
			startAttachment = nil
		end
		if guide then
			guide.Folder:Destroy()
			guide = nil
		end
		target = nil
	end

	local function showGuide(pos: Vector3)
		if guide == nil then
			guide = buildGuide()
			attachCharacter(localPlayer.Character)
		end
		target = pos
		local g = guide :: Guide
		g.Anchor.CFrame = CFrame.new(pos)
		g.Folder.Parent = Effects.Folder()
		if renderConn == nil then
			renderConn = RunService.RenderStepped:Connect(stepGuide)
		end
		stepGuide()
	end

	local function refresh()
		local data = StateController.Data
		local tut = if data and type(data.Tutorial) == "table" then data.Tutorial else nil
		if not data or not tut or tut.Done ~= false then
			bar.Visible = false
			clearGuide()
			shownStep = 0
			return
		end
		local index = tonumber(tut.Step) or 1
		local step = Tutorial.Steps[index]
		if not step then
			bar.Visible = false
			clearGuide()
			return
		end
		hint.Text = step.Text
		stepText.Text = string.format("STEP %d/%d", index, #Tutorial.Steps)
		local done = tonumber(tut.Progress) or 0
		if step.Count and step.Count > 1 then
			chip.Visible = true
			progress.Text = string.format("%d/%d", math.min(done, step.Count), step.Count)
			if index == shownStep and done ~= shownProgress then
				chipScale.Scale = 1.25
				TweenService:Create(chipScale, POP, { Scale = 1 }):Play()
			end
		else
			chip.Visible = false
		end
		if index ~= shownStep then
			bar.Visible = true
			barScale.Scale = 0.6
			TweenService:Create(barScale, POP, { Scale = 1 }):Play()
		end
		shownStep = index
		shownProgress = done
		if confirmUntil == 0 then
			skip:SetText("Skip")
			skip:SetStyle("Grey")
		end

		local pos = targetPosition(step.Target, tonumber(data.World) or 1)
		if pos then
			showGuide(pos)
		else
			clearGuide()
		end
	end

	StateController.DataChanged:Connect(refresh)
	localPlayer.CharacterAdded:Connect(function(character: Model)
		character:WaitForChild("HumanoidRootPart", 10)
		attachCharacter(character)
	end)
	localPlayer.CharacterRemoving:Connect(function()
		if startAttachment then
			startAttachment:Destroy()
			startAttachment = nil
		end
	end)
	refresh()
end

return TutorialController
