-- Juice for the core loop: arm swing, impact sparks, target shake/flash, damage
-- numbers, chunky debris when junk breaks, and Scrap flying into the counter.
-- Everything here is local and cosmetic; the server owns damage and rewards.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Theme)
local Economy = require(Shared.Economy)

local Net = require(script.Parent.Parent.Net)
local Sound = require(script.Parent.Sound)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local Effects = {}

local player = Players.LocalPlayer
local fxFolder: Folder
local onReward: ((Vector3, number) -> ())? = nil

local TOOL_SPARK = {
	Hammer = Color3.fromHex("#FFE14D"),
	Saw = Color3.fromHex("#FF9E2C"),
	Drill = Color3.fromHex("#B8C4DA"),
}

-- Arm swing ----------------------------------------------------------------------------
-- Rotates the right shoulder joint locally: wind up, slam, recover (0.32 s).

type Swing = { motor: Motor6D, base: CFrame, last: CFrame, t: number }
local swings: { [Motor6D]: Swing } = {}

local function swingAngle(t: number): number
	if t < 0.12 then
		return 140 * (t / 0.12)
	elseif t < 0.2 then
		return 140 - 110 * ((t - 0.12) / 0.08)
	elseif t < 0.32 then
		return 30 * (1 - (t - 0.2) / 0.12)
	end
	return 0
end

RunService.RenderStepped:Connect(function(dt)
	for motor, swing in swings do
		if not motor.Parent then
			swings[motor] = nil
			continue
		end
		if not motor.C0:FuzzyEq(swing.last, 1e-3) then
			swing.base = motor.C0 -- the server rebuilt / rescaled the rig meanwhile
		end
		swing.t += dt
		local angle = swingAngle(swing.t)
		local cf = swing.base * CFrame.Angles(math.rad(angle), 0, 0)
		motor.C0 = cf
		swing.last = cf
		if swing.t >= 0.32 then
			motor.C0 = swing.base
			swings[motor] = nil
		end
	end
end)

local function swingArm(character: Model)
	local arm = character:FindFirstChild("RightUpperArm")
	local motor = arm and arm:FindFirstChild("RightShoulder")
	if not motor or not motor:IsA("Motor6D") then
		return
	end
	local existing = swings[motor]
	if existing then
		existing.t = 0
		return
	end
	swings[motor] = { motor = motor, base = motor.C0, last = motor.C0, t = 0 }
end

-- Little helpers -------------------------------------------------------------------

local function chip(position: Vector3, color: Color3, size: number, velocity: Vector3, life: number, neon: boolean?)
	local p = Instance.new("Part")
	p.Size = Vector3.new(size, size, size)
	p.CFrame = CFrame.new(position) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
	p.Color = color
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.CanCollide = not neon
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.CollisionGroup = "Debris"
	p.AssemblyLinearVelocity = velocity
	p.AssemblyAngularVelocity = Vector3.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10))
	p.Parent = fxFolder
	task.delay(life * 0.6, function()
		if p.Parent then
			TweenService:Create(p, TweenInfo.new(life * 0.4), { Transparency = 1, Size = p.Size * 0.4 }):Play()
		end
	end)
	task.delay(life, function()
		p:Destroy()
	end)
	return p
end

local function ring(position: Vector3, color: Color3, radius: number, time: number)
	local r = Instance.new("Part")
	r.Shape = Enum.PartType.Cylinder
	r.Size = Vector3.new(0.2, 1, 1)
	r.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	r.Anchored = true
	r.CanCollide = false
	r.CanQuery = false
	r.CanTouch = false
	r.CastShadow = false
	r.Material = Enum.Material.Neon
	r.Color = color
	r.Transparency = 0.2
	r.Parent = fxFolder
	TweenService:Create(
		r,
		TweenInfo.new(time, Enum.EasingStyle.Quad),
		{ Size = Vector3.new(0.2, radius * 2, radius * 2), Transparency = 1 }
	):Play()
	task.delay(time, function()
		r:Destroy()
	end)
end

local function dust(position: Vector3, size: number)
	for _ = 1, 3 do
		local puff = Instance.new("Part")
		puff.Shape = Enum.PartType.Ball
		puff.Size = Vector3.one * size * 0.5
		puff.CFrame = CFrame.new(
			position + Vector3.new(math.random(-10, 10) / 10 * size * 0.4, 0, math.random(-10, 10) / 10 * size * 0.4)
		)
		puff.Anchored = true
		puff.CanCollide = false
		puff.CanQuery = false
		puff.CanTouch = false
		puff.CastShadow = false
		puff.Color = Color3.fromHex("#C9BBA8")
		puff.Material = Enum.Material.SmoothPlastic
		puff.Transparency = 0.35
		puff.Parent = fxFolder
		TweenService:Create(puff, TweenInfo.new(0.7, Enum.EasingStyle.Quad), {
			Size = Vector3.one * size * 1.6,
			Transparency = 1,
			CFrame = puff.CFrame + Vector3.new(0, size * 0.6, 0),
		}):Play()
		task.delay(0.7, function()
			puff:Destroy()
		end)
	end
end

local shaking: { [Model]: CFrame } = {}

local function shakeTarget(model: Model)
	if shaking[model] or not model.Parent then
		return
	end
	local base = model:GetPivot()
	shaking[model] = base
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.45
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	task.spawn(function()
		for _, offset in { Vector3.new(0.25, 0, 0), Vector3.new(-0.2, 0, 0.1), Vector3.new(0.1, 0, -0.15) } do
			if not model.Parent then
				break
			end
			model:PivotTo(base + offset)
			task.wait(0.03)
		end
		if model.Parent then
			model:PivotTo(base)
		end
		highlight:Destroy()
		shaking[model] = nil
	end)
end

local function floatingText(position: Vector3, text: string, color: Color3, size: number)
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = position
	anchor.Parent = Workspace.Terrain
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 50)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = anchor
	gui.Parent = anchor
	local label = UIKit.text(gui, { Text = text, TextSize = size, Color = color, Rotation = math.random(-8, 8) })
	local stroke = label:FindFirstChildOfClass("UIStroke")
	gui.StudsOffsetWorldSpace = Vector3.new(math.random(-10, 10) / 10, 0, 0)
	UIKit.pop(label, 0.5)
	TweenService:Create(
		gui,
		TweenInfo.new(0.9, Enum.EasingStyle.Quad),
		{ StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(0, 3, 0) }
	):Play()
	task.delay(0.45, function()
		TweenService:Create(label, TweenInfo.new(0.45), { TextTransparency = 1 }):Play()
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.45), { Transparency = 1 }):Play()
		end
	end)
	task.delay(0.95, function()
		anchor:Destroy()
	end)
end

local function cameraKick(strength: number)
	if UIKit.reducedMotion then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	task.spawn(function()
		for i = 1, 4 do
			local s = strength * (1 - i / 5)
			camera.CFrame *= CFrame.Angles(
				math.rad(math.random(-10, 10) / 10 * s),
				math.rad(math.random(-10, 10) / 10 * s),
				0
			)
			RunService.RenderStepped:Wait()
		end
	end)
end

-- Event handlers ---------------------------------------------------------------------------

local function onHit(userId: number, model: Model, damage: number)
	local attacker = Players:GetPlayerByUserId(userId)
	local character = attacker and attacker.Character
	if character then
		swingArm(character)
	end
	if not model or not model.Parent or not model.PrimaryPart then
		return
	end
	local hitbox = model.PrimaryPart
	local top = hitbox.Position + Vector3.new(0, hitbox.Size.Y / 2, 0)
	local toolId = attacker and attacker:GetAttribute("Tool") or "Hammer"
	local level = (attacker and attacker:GetAttribute("MechLevel")) or 0
	local spark = TOOL_SPARK[toolId] or TOOL_SPARK.Hammer
	local strong = level >= 1
	local mine = attacker == player
	local distance = Workspace.CurrentCamera and (Workspace.CurrentCamera.CFrame.Position - top).Magnitude or 0
	if distance > 160 then
		return
	end
	shakeTarget(model)
	local impact = top + Vector3.new(0, -hitbox.Size.Y * 0.25, 0)
	for _ = 1, if strong then 6 else 3 do
		chip(
			impact,
			spark,
			0.25,
			Vector3.new(math.random(-14, 14), math.random(10, 22), math.random(-14, 14)),
			0.45,
			true
		)
	end
	ring(impact, spark, if strong then 3 + level * 0.4 else 2, 0.25)
	if mine then
		floatingText(
			top + Vector3.new(0, 1, 0),
			"-" .. Economy.format(damage),
			if strong then Color3.fromHex("#FFE14D") else Theme.White,
			30
		)
		Sound.play("Hit", impact, 0.9 + math.random() * 0.25)
		if level >= 4 then
			cameraKick(0.6)
		end
	end
end

local function onBreak(userId: number, position: Vector3, size: Vector3, colors: { Color3 }, area: number)
	local camera = Workspace.CurrentCamera
	if camera and (camera.CFrame.Position - position).Magnitude > 220 then
		return
	end
	local count = 6 + area * 3
	local base = position - Vector3.new(0, size.Y * 0.2, 0)
	for i = 1, count do
		local color = colors[(i % math.max(#colors, 1)) + 1] or Color3.fromHex("#8A6A4A")
		local s = math.clamp(size.Magnitude / 10, 0.4, 1.4) * (0.6 + math.random() * 0.6)
		chip(
			base
				+ Vector3.new(
					math.random(-10, 10) / 10 * size.X * 0.3,
					math.random() * size.Y * 0.5,
					math.random(-10, 10) / 10 * size.Z * 0.3
				),
			color,
			s,
			Vector3.new(math.random(-22, 22), math.random(18, 38), math.random(-22, 22)),
			1.6
		)
	end
	dust(Vector3.new(position.X, position.Y - size.Y / 2 + 0.5, position.Z), math.max(size.X, size.Z))
	if userId == player.UserId then
		Sound.play("Break", position)
		cameraKick(1.2)
	end
end

function Effects.init(rewardHandler: (Vector3, number) -> ())
	onReward = rewardHandler
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "LocalFx"
	fxFolder.Parent = Workspace
	Net.Fx:Connect(function(name, ...)
		if name == "Hit" then
			onHit(...)
		elseif name == "Break" then
			onBreak(...)
		elseif name == "Reward" then
			local amount, position = ...
			floatingText(
				position + Vector3.new(0, 1.5, 0),
				"+" .. Economy.format(amount) .. " ⚙️",
				Theme.ScrapGold,
				38
			)
			if onReward then
				onReward(position, amount)
			end
		end
	end)
end

return Effects
