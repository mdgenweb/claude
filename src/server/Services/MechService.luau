-- Turns each player's character into their mech: hides the avatar, scales the body to
-- the current form, welds the armor/tool on, and adds a nameplate. Rebuilt whenever the
-- player upgrades, rebirths or changes tool/finish. Players spawn in their own lane,
-- facing their junk.

local PhysicsService = game:GetService("PhysicsService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Economy)
local Layout = require(Shared.Layout)
local MechBuilder = require(Shared.MechBuilder)
local Theme = require(Shared.Theme)

local StateService = require(script.Parent.StateService)
local LaneService = require(script.Parent.LaneService)

local MechService = {}

local GROUP = "Mechs"

local function setGroup(part: Instance)
	if part:IsA("BasePart") then
		part.CollisionGroup = GROUP
	end
end

local function nameplate(character: Model, player: Player, session)
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local old = head:FindFirstChild("Nameplate")
	if old then
		old:Destroy()
	end
	local data = session.Data
	local vip = session.Passes.FoundryVIP == true
	local scale = character:GetScale()
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Size = UDim2.fromOffset(220, 60)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.4 * scale + 0.6, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.Adornee = head
	local function line(textValue: string, y: number, h: number, color: Color3, font: Enum.Font)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, h)
		t.Position = UDim2.fromScale(0, y)
		t.Font = font
		t.TextScaled = true
		t.TextColor3 = color
		t.Text = textValue
		local stroke = Instance.new("UIStroke")
		stroke.Color = Theme.Ink
		stroke.Thickness = 2.5
		stroke.Parent = t
		t.Parent = gui
	end
	line(
		(if vip then "👑 " else "") .. player.DisplayName,
		0,
		0.55,
		if vip then Theme.ScrapGold else Theme.White,
		Theme.Font.Display
	)
	line(
		string.format(
			"%s · ⚡%s",
			string.upper(Economy.formFor(data.Level).Name),
			Economy.format(Economy.powerForLevel(data.Level))
		),
		0.55,
		0.42,
		Color3.fromHex("#FFB24A"),
		Theme.Font.Body
	)
	gui.Parent = head
end

-- Rebuilds the mech on the player's current character.
function MechService.refresh(player: Player)
	local session = StateService.get(player)
	local character = player.Character
	if not session or not character or not character.Parent then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local data = session.Data
	local old = character:FindFirstChild("Mech")
	if old then
		old:Destroy()
	end
	local scale = Economy.bodyScale(data.Level)
	if math.abs(character:GetScale() - scale) > 0.001 then
		local ok, err = pcall(function()
			character:ScaleTo(scale)
		end)
		if not ok then
			warn("[MechService] ScaleTo failed: " .. tostring(err))
		end
		local baseHip = humanoid:GetAttribute("BaseHipHeight")
		if baseHip and humanoid.RigType == Enum.HumanoidRigType.R15 then
			humanoid.HipHeight = baseHip * character:GetScale()
		end
	end
	local folder = MechBuilder.apply(character, data.Level, data.Tool, data.Finish)
	for _, part in folder:GetDescendants() do
		setGroup(part)
	end
	MechBuilder.hideAvatar(character)
	nameplate(character, player, session)
	character:SetAttribute("MechLevel", data.Level)
end

local function placeInLane(player: Player, character: Model)
	local session = StateService.get(player)
	local lane = session and session.Lane
	if not lane then
		return
	end
	local entrance = Layout.laneEntrance(1, lane)
	local height = MechBuilder.RootHeight * character:GetScale() + 0.5
	character:PivotTo(CFrame.new(entrance + Vector3.new(0, height, 0)))
end

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root then
		return
	end
	-- Give the engine a moment to finish assembling the rig.
	character:WaitForChild("RightHand", 3)
	task.wait()
	if not StateService.get(player) or player.Character ~= character then
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	if humanoid:GetAttribute("BaseHipHeight") == nil then
		humanoid:SetAttribute("BaseHipHeight", humanoid.HipHeight / math.max(character:GetScale(), 0.01))
	end
	for _, d in character:GetDescendants() do
		setGroup(d)
	end
	character.DescendantAdded:Connect(function(d)
		setGroup(d)
		if d:IsA("Accessory") then
			task.defer(d.Destroy, d)
		end
	end)
	MechService.refresh(player)
	placeInLane(player, character)
end

function MechService.init()
	for _, name in { GROUP, "Debris" } do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	-- Mechs walk through each other; client-side debris never shoves anyone around.
	PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
	PhysicsService:CollisionGroupSetCollidable("Debris", GROUP, false)
	PhysicsService:CollisionGroupSetCollidable("Debris", "Debris", false)

	StateService.Started:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end)
	LaneService.Assigned:Connect(function(player)
		MechService.sendToLane(player)
	end)
	StateService.LevelChanged:Connect(MechService.refresh)
	StateService.LookChanged:Connect(MechService.refresh)
end

function MechService.sendToLane(player: Player)
	if player.Character then
		placeInLane(player, player.Character)
	end
end

return MechService
