--!strict
-- Builds the compact lobby from Config/Lobby: navy plaza, duel hall, bridge, chevron path,
-- props (gacha machine, displays, group pedestal, leaderboards, decor orb), spawn and lighting.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Lobby = require(Shared.Config.Lobby)
local GachaDefinitions = require(Shared.Definitions.GachaDefinitions)
local PropFactory = require(Shared.Visual.PropFactory)
local WorldLabel = require(Shared.Visual.WorldLabel)

local P = PropFactory.Part
local C = Lobby.Colors

local LobbyService = {}

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function yawCFrame(pos: Vector3, yaw: number): CFrame
	return CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw), 0)
end

-- A raised platform with a trimmed edge.
local function platform(parent: Instance, name: string, center: Vector3, sizeX: number, sizeZ: number, height: number)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	P(folder, { Name = "Slab", Size = Vector3.new(sizeX, height, sizeZ), CFrame = CFrame.new(center + Vector3.new(0, -height / 2, 0)), Color = C.Floor })
	local t = 1.4
	-- top border trim
	P(folder, { Name = "TrimN", Size = Vector3.new(sizeX, 0.1, t), CFrame = CFrame.new(center + Vector3.new(0, 0.05, -sizeZ / 2 + t / 2)), Color = C.Trim, CanCollide = false })
	P(folder, { Name = "TrimS", Size = Vector3.new(sizeX, 0.1, t), CFrame = CFrame.new(center + Vector3.new(0, 0.05, sizeZ / 2 - t / 2)), Color = C.Trim, CanCollide = false })
	P(folder, { Name = "TrimW", Size = Vector3.new(t, 0.1, sizeZ), CFrame = CFrame.new(center + Vector3.new(-sizeX / 2 + t / 2, 0.05, 0)), Color = C.Trim, CanCollide = false })
	P(folder, { Name = "TrimE", Size = Vector3.new(t, 0.1, sizeZ), CFrame = CFrame.new(center + Vector3.new(sizeX / 2 - t / 2, 0.05, 0)), Color = C.Trim, CanCollide = false })
	-- glowing side band
	for _, spec in {
		{ Vector3.new(sizeX + 0.2, 0.5, 0.2), Vector3.new(0, -0.6, -sizeZ / 2) },
		{ Vector3.new(sizeX + 0.2, 0.5, 0.2), Vector3.new(0, -0.6, sizeZ / 2) },
		{ Vector3.new(0.2, 0.5, sizeZ + 0.2), Vector3.new(-sizeX / 2, -0.6, 0) },
		{ Vector3.new(0.2, 0.5, sizeZ + 0.2), Vector3.new(sizeX / 2, -0.6, 0) },
	} do
		P(folder, { Name = "Band", Size = spec[1], CFrame = CFrame.new(center + spec[2]), Color = C.TrimGlow, Material = Enum.Material.Neon, CanCollide = false })
	end
	-- subtle floor grid lines
	local step = 20
	for x = -sizeX / 2 + step, sizeX / 2 - step, step do
		P(folder, { Name = "Grid", Size = Vector3.new(0.25, 0.04, sizeZ - 3), CFrame = CFrame.new(center + Vector3.new(x, 0.02, 0)), Color = C.FloorDark, CanCollide = false, CastShadow = false })
	end
	for z = -sizeZ / 2 + step, sizeZ / 2 - step, step do
		P(folder, { Name = "Grid", Size = Vector3.new(sizeX - 3, 0.04, 0.25), CFrame = CFrame.new(center + Vector3.new(0, 0.02, z)), Color = C.FloorDark, CanCollide = false, CastShadow = false })
	end
	return folder
end

-- Invisible boundary walls with an optional gap (so players can't fall off).
local function boundary(parent: Instance, a: Vector3, b: Vector3, gapFrom: number?, gapTo: number?)
	local alongX = math.abs(b.X - a.X) > math.abs(b.Z - a.Z)
	local function wall(from: number, to: number)
		if to - from < 0.5 then
			return
		end
		local mid = (from + to) / 2
		local size = if alongX then Vector3.new(to - from, 14, 1) else Vector3.new(1, 14, to - from)
		local pos = if alongX then Vector3.new(mid, 7, a.Z) else Vector3.new(a.X, 7, mid)
		P(parent, { Name = "Boundary", Size = size, CFrame = CFrame.new(pos), Color = "#000000", Transparency = 1, CastShadow = false })
	end
	local lo = if alongX then math.min(a.X, b.X) else math.min(a.Z, b.Z)
	local hi = if alongX then math.max(a.X, b.X) else math.max(a.Z, b.Z)
	if gapFrom and gapTo then
		wall(lo, gapFrom)
		wall(gapTo, hi)
	else
		wall(lo, hi)
	end
end

local function chevrons(parent: Instance)
	local path = Lobby.Chevrons.Path
	local spacing = Lobby.Chevrons.Spacing
	local carry = 0
	for i = 1, #path - 1 do
		local a, b = v3(path[i]), v3(path[i + 1])
		local seg = b - a
		local len = seg.Magnitude
		local dir = seg.Unit
		local d = carry
		while d < len do
			local pos = a + dir * d + Vector3.new(0, 0.06, 0)
			local base = CFrame.lookAt(pos, pos + dir)
			for side = -1, 1, 2 do
				-- each arm angles back from the tip
				local arm = base * CFrame.Angles(0, math.rad(side * 40), 0) * CFrame.new(0, 0, 1.4)
				P(parent, { Name = "Chevron", Size = Vector3.new(0.9, 0.08, 3.2), CFrame = arm, Color = C.Chevron, CanCollide = false, CastShadow = false })
			end
			d += spacing
		end
		carry = d - len
	end
end

local function labelAbove(part: BasePart, height: number, text: string, color: string, size: number?)
	local s = size or 1
	WorldLabel.Create(part, {
		Name = "Title",
		Size = Vector2.new(12 * s, 3 * s),
		Offset = Vector3.new(0, height, 0),
		Lines = { { Text = text, Color = color, Height = 1 } },
	})
end

local function addPrompt(part: BasePart, action: string, object: string, attributes: { [string]: any })
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, 3, 0)
	attachment.Parent = part
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	for k, v in attributes do
		prompt:SetAttribute(k, v)
	end
	prompt.Parent = attachment
	CollectionService:AddTag(prompt, "UIPrompt")
end

local function buildProp(parent: Instance, prop: Lobby.PropConfig)
	local cf = yawCFrame(v3(prop.Position), prop.Yaw)
	local model: Model
	if prop.Kind == "GachaMachine" then
		model = PropFactory.GachaMachine(false)
		model:PivotTo(cf)
		labelAbove(model.PrimaryPart :: BasePart, 14.5, prop.Label or "", "#9FD8FF", 1.1)
		addPrompt(model.PrimaryPart :: BasePart, "Open Store", prop.Label or "", { OpenUI = prop.OpenUI })
		-- a second, advanced machine beside it
		local adv = PropFactory.GachaMachine(true)
		adv:PivotTo(cf * CFrame.new(-11, 0, -3) * CFrame.Angles(0, math.rad(12), 0))
		labelAbove(adv.PrimaryPart :: BasePart, 14.5, "Advanced", "#D9B3FF", 1.0)
		addPrompt(adv.PrimaryPart :: BasePart, "Open Store", "Advanced Orbs", { OpenUI = "Store:Balls" })
		adv.Parent = parent
	elseif prop.Kind == "CrateDisplay" then
		model = PropFactory.CrateDisplay()
		model:PivotTo(cf)
		labelAbove(model.PrimaryPart :: BasePart, 9, prop.Label or "", "#E3BFFF")
		addPrompt(model.PrimaryPart :: BasePart, "Open Store", prop.Label or "", { OpenUI = prop.OpenUI })
	elseif prop.Kind == "FlyerDisplay" then
		model = PropFactory.FlyerDisplay()
		model:PivotTo(cf)
		labelAbove(model.PrimaryPart :: BasePart, 14, prop.Label or "", "#9FD8FF")
		addPrompt(model.PrimaryPart :: BasePart, "Open Store", prop.Label or "", { OpenUI = prop.OpenUI })
	elseif prop.Kind == "EventDisplay" then
		model = PropFactory.EventDisplay()
		model:PivotTo(cf)
		local event = GachaDefinitions.Get("HarvestCrate")
		local anchor = model.PrimaryPart :: BasePart
		local gui = WorldLabel.Create(anchor, {
			Name = "EventLabel",
			Size = Vector2.new(14, 5),
			Offset = Vector3.new(0, 11, 0),
			Lines = {
				{ Name = "Title", Text = "Harvest Moon", Color = "#FFB347", Height = 1.1 },
				{ Name = "Timer", Text = "", Color = "#E3BFFF", Height = 0.8 },
			},
		})
		gui:SetAttribute("EndsAt", if event then event.EndsAt else 0)
		CollectionService:AddTag(gui, "EventTimer")
		addPrompt(anchor, "Open Store", "Event", { OpenUI = prop.OpenUI })
	elseif prop.Kind == "GroupPedestal" then
		model = PropFactory.GroupPedestal()
		model:PivotTo(cf)
		local anchor = model.PrimaryPart :: BasePart
		WorldLabel.Create(anchor, {
			Name = "GroupLabel",
			Size = Vector2.new(16, 5),
			Offset = Vector3.new(0, 8.5, 0),
			Lines = {
				{ Text = "Like + Join Group", Color = "#FFA000", Height = 1 },
				{ Text = "Advanced Orb Gacha +1", Color = "#FFE14D", Height = 0.9 },
			},
		})
		addPrompt(anchor, "Claim Reward", "Group Reward", { Action = "ClaimGroup" })
	elseif prop.Kind == "Leaderboard" then
		model = PropFactory.Leaderboard()
		model:PivotTo(cf)
		model:SetAttribute("BoardKind", prop.Label)
		CollectionService:AddTag(model, "Leaderboard")
	elseif prop.Kind == "DecorOrb" then
		model = PropFactory.DecorOrb()
		model:PivotTo(cf)
		CollectionService:AddTag(model, "Bob")
	else
		return
	end
	model.Name = prop.Id
	model.Parent = parent
	for _, child in model:GetDescendants() do
		if child:IsA("Model") and child:GetAttribute("Bob") then
			CollectionService:AddTag(child, "Bob")
		end
	end
end

local function setupLighting()
	Lighting.Ambient = Color3.fromRGB(118, 122, 140)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 152, 165)
	Lighting.Brightness = 2.2
	Lighting.ClockTime = 14.2
	Lighting.GeographicLatitude = 30
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.7
	Lighting.GlobalShadows = true
	Lighting.FogColor = Color3.fromHex(C.Void)
	Lighting.FogStart = 400
	Lighting.FogEnd = 2000
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.42
	atmosphere.Offset = 0
	atmosphere.Color = Color3.fromRGB(199, 200, 206)
	atmosphere.Decay = Color3.fromRGB(160, 162, 172)
	atmosphere.Glare = 0
	atmosphere.Haze = 2.2
	atmosphere.Parent = Lighting
	local sky = Instance.new("Sky")
	sky.CelestialBodiesShown = false
	sky.StarCount = 0
	sky.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 22
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Contrast = 0.06
	cc.Saturation = 0.12
	cc.Parent = Lighting
end

function LobbyService.Init()
	local lobby = Workspace:FindFirstChild("Lobby") or Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = Workspace

	-- remove a default baseplate / spawn if the place has one
	for _, child in Workspace:GetChildren() do
		if child.Name == "Baseplate" or child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end

	local plaza = Lobby.Plaza
	local hall = Lobby.Hall
	local bridge = Lobby.Bridge
	platform(lobby, "Plaza", v3(plaza.Center), plaza.Size[1], plaza.Size[2], plaza.Height)
	platform(lobby, "Hall", v3(hall.Center), hall.Size[1], hall.Size[2], hall.Height)
	local bFrom, bTo = v3(bridge.From), v3(bridge.To)
	local bridgeLen = (bTo - bFrom).Magnitude
	platform(lobby, "Bridge", (bFrom + bTo) / 2, bridgeLen + 4, bridge.Width, plaza.Height)

	-- boundaries (with gaps where the bridge joins)
	local walls = Instance.new("Folder")
	walls.Name = "Boundaries"
	walls.Parent = lobby
	local px, pz = plaza.Size[1] / 2, plaza.Size[2] / 2
	local pc = v3(plaza.Center)
	local gapLo, gapHi = bFrom.Z - bridge.Width / 2, bFrom.Z + bridge.Width / 2
	boundary(walls, pc + Vector3.new(-px, 0, -pz), pc + Vector3.new(px, 0, -pz))
	boundary(walls, pc + Vector3.new(-px, 0, pz), pc + Vector3.new(px, 0, pz))
	boundary(walls, pc + Vector3.new(-px, 0, -pz), pc + Vector3.new(-px, 0, pz))
	boundary(walls, pc + Vector3.new(px, 0, -pz), pc + Vector3.new(px, 0, pz), gapLo, gapHi)
	local hc = v3(hall.Center)
	local hx, hz = hall.Size[1] / 2, hall.Size[2] / 2
	boundary(walls, hc + Vector3.new(-hx, 0, -hz), hc + Vector3.new(hx, 0, -hz))
	boundary(walls, hc + Vector3.new(-hx, 0, hz), hc + Vector3.new(hx, 0, hz))
	boundary(walls, hc + Vector3.new(-hx, 0, -hz), hc + Vector3.new(-hx, 0, hz), gapLo, gapHi)
	boundary(walls, hc + Vector3.new(hx, 0, -hz), hc + Vector3.new(hx, 0, hz))
	boundary(walls, bFrom + Vector3.new(0, 0, -bridge.Width / 2), bTo + Vector3.new(0, 0, -bridge.Width / 2))
	boundary(walls, bFrom + Vector3.new(0, 0, bridge.Width / 2), bTo + Vector3.new(0, 0, bridge.Width / 2))

	-- hall back walls with light strips behind the stations
	for _, z in { hc.Z - hz - 0.5, hc.Z + hz + 0.5 } do
		P(lobby, { Name = "HallWall", Size = Vector3.new(hall.Size[1], 30, 1), CFrame = CFrame.new(hc.X, 15, z), Color = "#141C33" })
		for y = 6, 26, 10 do
			P(lobby, { Name = "WallStrip", Size = Vector3.new(hall.Size[1] - 6, 0.4, 0.2), CFrame = CFrame.new(hc.X, y, z + (if z < hc.Z then 0.6 else -0.6)), Color = C.Trim, Material = Enum.Material.Neon, CanCollide = false })
		end
	end
	local signAnchor = P(lobby, { Name = "HallSign", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(hc.X - hx + 6, 16, hc.Z), Color = "#000000", Transparency = 1, CanCollide = false })
	WorldLabel.Create(signAnchor, {
		Name = "Sign",
		Size = Vector2.new(30, 6),
		MaxDistance = 400,
		Lines = { { Text = "BATTLE ARENAS", Color = "#FFFFFF", Height = 1 }, { Text = "1V1", Color = "#59A8FF", Height = 0.7 } },
	})

	local chevronFolder = Instance.new("Folder")
	chevronFolder.Name = "Chevrons"
	chevronFolder.Parent = lobby
	chevrons(chevronFolder)

	local props = Instance.new("Folder")
	props.Name = "Props"
	props.Parent = lobby
	for _, prop in Lobby.Props do
		buildProp(props, prop)
	end

	-- 2v2 sign over the team station
	for _, station in Lobby.Stations do
		if station.Mode == "2v2" then
			local anchor = P(lobby, { Name = "TeamSign", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(v3(station.Position) + Vector3.new(0, 30, 0)), Color = "#000000", Transparency = 1, CanCollide = false })
			WorldLabel.Create(anchor, { Name = "Sign", Size = Vector2.new(16, 6), MaxDistance = 400, Lines = { { Text = "2V2", Color = "#FFFFFF", Height = 1 } } })
		end
	end

	-- spawn
	local spawnCfg = Lobby.Spawn
	local spawnPos = v3(spawnCfg.Position) + Vector3.new(0, 0.5, 0)
	local facing = Vector3.new(math.sin(math.rad(spawnCfg.Yaw)), 0, math.cos(math.rad(spawnCfg.Yaw)))
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.lookAt(spawnPos, spawnPos + facing)
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = lobby
	P(lobby, { Name = "SpawnRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 12, 12), CFrame = PropFactory.Upright(CFrame.new(spawnPos - Vector3.new(0, 0.42, 0))), Color = C.TrimGlow, Material = Enum.Material.Neon, CanCollide = false })
	P(lobby, { Name = "SpawnDisc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.14, 10.6, 10.6), CFrame = PropFactory.Upright(CFrame.new(spawnPos - Vector3.new(0, 0.4, 0))), Color = C.FloorDark, CanCollide = false })

	setupLighting()
	Workspace.FallenPartsDestroyHeight = -60
end

return LobbyService
