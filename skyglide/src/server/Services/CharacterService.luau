--!strict
-- Character dressing: the equipped glider held in the right hand (everyone sees what you throw)
-- and the equipped trail. Players don't collide with each other.
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gliders = require(Shared.Definitions.Gliders)
local Relics = require(Shared.Definitions.Relics)
local Trails = require(Shared.Definitions.Trails)
local GliderFactory = require(Shared.Visual.GliderFactory)

local DataService = require(script.Parent.DataService)

local CharacterService = {}

local GROUP = "SkyGlidePlayers"

local function setGroup(character: Model)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = GROUP
		end
	end
	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = GROUP
		end
	end)
end

local function visualFor(profile: DataService.Profile): any
	if profile.Relic ~= "" then
		local relic = Relics.Get(profile.Relic)
		if relic then
			return relic.Visual
		end
	end
	local glider = Gliders.Get(profile.Glider) or Gliders.Get(Gliders.Default)
	return if glider then glider.Visual else nil
end

local function dress(player: Player)
	local character = player.Character
	local profile = DataService.Get(player)
	if not character or not profile then
		return
	end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local root = character:FindFirstChild("HumanoidRootPart")
	local old = character:FindFirstChild("HeldGlider")
	if old then
		old:Destroy()
	end
	local visual = visualFor(profile)
	if hand and hand:IsA("BasePart") and visual then
		local model = GliderFactory.Build(visual, 2.4, false)
		model.Name = "HeldGlider"
		local primary = model.PrimaryPart
		if primary then
			model:PivotTo(hand.CFrame * CFrame.new(0, -hand.Size.Y / 2 - 0.2, -0.4) * CFrame.Angles(math.rad(-20), 0, 0))
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = hand
			weld.Part1 = primary
			weld.Parent = primary
		end
		model.Parent = character
	end
	-- trail
	if root and root:IsA("BasePart") then
		local oldTrail = root:FindFirstChild("SkyTrail")
		if oldTrail then
			oldTrail:Destroy()
		end
		for _, name in { "TrailA0", "TrailA1" } do
			local a = root:FindFirstChild(name)
			if a then
				a:Destroy()
			end
		end
		local def = Trails.Get(profile.Trail)
		if def then
			local a0 = Instance.new("Attachment")
			a0.Name = "TrailA0"
			a0.Position = Vector3.new(0, 0.9, 0.4)
			a0.Parent = root
			local a1 = Instance.new("Attachment")
			a1.Name = "TrailA1"
			a1.Position = Vector3.new(0, -1.4, 0.4)
			a1.Parent = root
			local trail = Instance.new("Trail")
			trail.Name = "SkyTrail"
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Lifetime = 0.6
			trail.LightEmission = 0.6
			trail.FaceCamera = true
			local keys = {}
			for i, hex in def.Colors do
				local t = if #def.Colors == 1 then 0 else (i - 1) / (#def.Colors - 1)
				table.insert(keys, ColorSequenceKeypoint.new(t, Color3.fromHex(hex)))
			end
			if #keys == 1 then
				table.insert(keys, ColorSequenceKeypoint.new(1, keys[1].Value))
			end
			trail.Color = ColorSequence.new(keys)
			trail.Transparency = NumberSequence.new(0.15, 1)
			trail.Parent = root
		end
	end
	player:SetAttribute("Glider", if profile.Relic ~= "" then "relic:" .. profile.Relic else profile.Glider)
	player:SetAttribute("Trail", profile.Trail)
end

function CharacterService.Refresh(player: Player)
	task.spawn(dress, player)
end

function CharacterService.Init()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(GROUP)
		PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
	end)
end

function CharacterService.Start()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			setGroup(character)
			character:WaitForChild("HumanoidRootPart", 10)
			DataService.WaitFor(player, 30)
			task.wait(0.2)
			dress(player)
		end)
		if player.Character then
			setGroup(player.Character)
			task.spawn(dress, player)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
end

return CharacterService
