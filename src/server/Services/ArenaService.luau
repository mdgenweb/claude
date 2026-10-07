--!strict
-- Builds the duel stations (arena box, ledges, pads, VS screen, status label) from
-- Config/Lobby + Visual/ArenaGeometry and owns character placement on the pads.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Lobby = require(Shared.Config.Lobby)
local GameConfig = require(Shared.Config.Game)
local Economy = require(Shared.Config.Economy)
local ArenaGeometry = require(Shared.Visual.ArenaGeometry)
local PropFactory = require(Shared.Visual.PropFactory)
local WorldLabel = require(Shared.Visual.WorldLabel)
local Signal = require(Shared.Util.Signal)

local P = PropFactory.Part

export type Pad = {
	Index: number,
	Team: number,
	Part: BasePart,
	Prompt: ProximityPrompt,
	Occupant: Player?,
	Bot: { [string]: any }?,
}

export type Station = {
	Id: string,
	Index: number,
	Mode: "1v1" | "2v2",
	Kind: string,
	CFrame: CFrame,
	Model: Model,
	Pads: { Pad },
	Label: BillboardGui,
	VsScreen: SurfaceGui,
	State: string,
	Match: any,
	FoundAt: number?,
}

local ArenaService = {}

ArenaService.Stations = {} :: { Station }
ArenaService.ById = {} :: { [string]: Station }
ArenaService.PadTriggered = Signal.new() -- (player, station, padIndex)

local locked: { [Player]: CFrame } = {}

local function teamColor(team: number): string
	return if team == 1 then Lobby.Colors.TeamRed else Lobby.Colors.TeamBlue
end

local function buildStation(config: Lobby.StationConfig, index: number, parent: Instance): Station
	local kindName = ArenaGeometry.KindForMode(config.Mode)
	local k = ArenaGeometry.Get(kindName)
	local cf = ArenaGeometry.StationCFrame(config.Position, config.Yaw, kindName)
	local model = PropFactory.Model("Station_" .. config.Id)
	model:SetAttribute("StationId", config.Id)
	model:SetAttribute("StationIndex", index)
	model:SetAttribute("Mode", config.Mode)
	model:SetAttribute("Kind", kindName)
	model:SetAttribute("Yaw", config.Yaw)
	model:SetAttribute("Floor", Vector3.new(config.Position[1], config.Position[2], config.Position[3]))
	CollectionService:AddTag(model, "Station")

	local h, f = k.Half, k.Frame
	local depth = k.FrontZ - (k.BackZ - 0.5)
	local midZ = (k.FrontZ + (k.BackZ - 0.5)) / 2
	local frameColor = Lobby.Colors.ArenaFrame
	-- frame: left, right, top, bottom
	P(model, { Name = "FrameL", Size = Vector3.new(f, 2 * (h + f), depth), CFrame = cf * CFrame.new(-(h + f / 2), 0, midZ), Color = frameColor })
	P(model, { Name = "FrameR", Size = Vector3.new(f, 2 * (h + f), depth), CFrame = cf * CFrame.new(h + f / 2, 0, midZ), Color = frameColor })
	P(model, { Name = "FrameT", Size = Vector3.new(2 * h, f, depth), CFrame = cf * CFrame.new(0, h + f / 2, midZ), Color = frameColor })
	P(model, { Name = "FrameB", Size = Vector3.new(2 * h, f, depth), CFrame = cf * CFrame.new(0, -(h + f / 2), midZ), Color = frameColor })
	-- front lip highlight
	local lipColor = "#454955"
	for _, spec in {
		{ Vector3.new(f, 2 * (h + f), 0.2), Vector3.new(-(h + f / 2), 0, k.FrontZ + 0.1) },
		{ Vector3.new(f, 2 * (h + f), 0.2), Vector3.new(h + f / 2, 0, k.FrontZ + 0.1) },
		{ Vector3.new(2 * h, f, 0.2), Vector3.new(0, h + f / 2, k.FrontZ + 0.1) },
		{ Vector3.new(2 * h, f, 0.2), Vector3.new(0, -(h + f / 2), k.FrontZ + 0.1) },
	} do
		P(model, { Name = "Lip", Size = spec[1], CFrame = cf * CFrame.new(spec[2]), Color = lipColor, CanCollide = false })
	end
	-- back wall (black interior) with the idle "VS" screen
	local back = P(model, { Name = "BackWall", Size = Vector3.new(2 * h, 2 * h, 0.5), CFrame = cf * CFrame.new(0, 0, k.BackZ - 0.25), Color = Lobby.Colors.ArenaInterior })
	local vs = Instance.new("SurfaceGui")
	vs.Name = "VsScreen"
	vs.PixelsPerStud = 40
	vs.LightInfluence = 0
	vs.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	vs.ResetOnSpawn = false
	-- BackWall's Front face points along its LookVector (-Z local of the station) = away from the
	-- viewer, so use the Back face.
	vs.Face = Enum.NormalId.Back
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromHex("#141C33")
	bg.BorderSizePixel = 0
	bg.Parent = vs
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromHex("#1B2747"), Color3.fromHex("#0D1224"))
	grad.Rotation = 90
	grad.Parent = bg
	for s = 0, 7 do
		local stripe = Instance.new("Frame")
		stripe.AnchorPoint = Vector2.new(0.5, 0.5)
		stripe.Position = UDim2.fromScale(-0.1 + s * 0.17, 0.5)
		stripe.Size = UDim2.fromScale(0.05, 1.6)
		stripe.Rotation = 25
		stripe.BackgroundColor3 = Color3.fromHex("#22305A")
		stripe.BackgroundTransparency = 0.35
		stripe.BorderSizePixel = 0
		stripe.Parent = bg
	end
	bg.ClipsDescendants = true
	local vsText = Instance.new("TextLabel")
	vsText.Size = UDim2.fromScale(0.8, 0.45)
	vsText.Position = UDim2.fromScale(0.1, 0.27)
	vsText.BackgroundTransparency = 1
	vsText.FontFace = WorldLabel.DisplayFont
	vsText.Text = "VS"
	vsText.TextScaled = true
	vsText.TextColor3 = Color3.fromHex("#E8ECF5")
	local vsStroke = Instance.new("UIStroke")
	vsStroke.Thickness = 6
	vsStroke.Color = Color3.fromHex("#0A0E1A")
	vsStroke.Parent = vsText
	vsText.Parent = bg
	local modeText = Instance.new("TextLabel")
	modeText.Size = UDim2.fromScale(0.6, 0.12)
	modeText.Position = UDim2.fromScale(0.2, 0.74)
	modeText.BackgroundTransparency = 1
	modeText.FontFace = WorldLabel.DisplayFont
	modeText.Text = GameConfig.Modes[config.Mode].Label
	modeText.TextScaled = true
	modeText.TextColor3 = Color3.fromHex("#59A8FF")
	modeText.Parent = bg
	vs.Parent = back

	-- ledges, steps and pads
	local floorY = -k.BaseHeight
	local ledgeTop = -k.LedgeDrop
	local ledgeH = ledgeTop - floorY
	local zBack, zFront = k.LedgeDepth[1], k.LedgeDepth[2]
	local pads: { Pad } = {}
	for side = -1, 1, 2 do
		local inner, outer = k.LedgeInner, k.LedgeOuter
		local width = outer - inner
		local cx = side * (inner + width / 2)
		P(model, { Name = "Ledge", Size = Vector3.new(width, ledgeH, zFront - zBack), CFrame = cf * CFrame.new(cx, floorY + ledgeH / 2, (zBack + zFront) / 2), Color = Lobby.Colors.Ledge })
		P(model, { Name = "LedgeBand", Size = Vector3.new(width, 0.7, 0.2), CFrame = cf * CFrame.new(cx, ledgeTop - 0.35, zFront + 0.1), Color = Lobby.Colors.LedgeBand, Material = Enum.Material.Neon, CanCollide = false })
		P(model, { Name = "LedgeTop", Size = Vector3.new(width, 0.12, zFront - zBack), CFrame = cf * CFrame.new(cx, ledgeTop + 0.06, (zBack + zFront) / 2), Color = "#2A3A60" })
		local steps = math.ceil(ledgeH)
		for s = 1, steps do
			local stepH = ledgeH * (steps - s + 1) / (steps + 1)
			P(model, {
				Name = "Step",
				Size = Vector3.new(1.3, stepH, 5),
				CFrame = cf * CFrame.new(side * (outer + 0.65 + (s - 1) * 1.3), floorY + stepH / 2, 1.5),
				Color = Lobby.Colors.Ledge,
			})
		end
	end
	for padIndex, padSpec in k.Pads do
		local padCf = cf * CFrame.new(padSpec.X, ledgeTop + 0.2, 0.6)
		local ring = P(model, { Name = "Pad" .. padIndex, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 4.6, 4.6), CFrame = PropFactory.Upright(padCf), Color = teamColor(padSpec.Team), Material = Enum.Material.Neon, CanCollide = false })
		P(model, { Name = "PadInner", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 3.8, 3.8), CFrame = PropFactory.Upright(padCf), Color = "#121829", CanCollide = false })
		local attachment = Instance.new("Attachment")
		attachment.Position = Vector3.new(0, 2.5, 0)
		attachment.Parent = ring
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Join Battle"
		prompt.ObjectText = GameConfig.Modes[config.Mode].Label
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = attachment
		table.insert(pads, { Index = padIndex, Team = padSpec.Team, Part = ring, Prompt = prompt, Occupant = nil, Bot = nil })
	end

	-- status label above the arena ("0/2 PLAYERS", "Win 100")
	local anchor = P(model, { Name = "LabelAnchor", Size = Vector3.new(1, 1, 1), CFrame = cf * CFrame.new(0, h + f + 4.5, 0), Color = "#000000", Transparency = 1, CanCollide = false })
	local capacity = #pads
	local label = WorldLabel.Create(anchor, {
		Name = "Status",
		Size = Vector2.new(22, 6),
		MaxDistance = 260,
		Lines = {
			{ Name = "Count", Text = string.format("0/%d PLAYERS", capacity), Height = 1.1 },
			{ Name = "Reward", Text = string.format('<font color="#FFC72C">Win %d</font>', Economy.MatchRewards.Win.Coins), Height = 1 },
		},
	})

	model.Parent = parent
	return {
		Id = config.Id,
		Index = index,
		Mode = config.Mode,
		Kind = kindName,
		CFrame = cf,
		Model = model,
		Pads = pads,
		Label = label,
		VsScreen = vs,
		State = "Idle",
		Match = nil,
		FoundAt = nil,
	}
end

function ArenaService.SetLabel(station: Station, text: string, color: string?)
	local count = station.Label:FindFirstChild("Count") :: TextLabel?
	if count then
		count.Text = text
		count.TextColor3 = Color3.fromHex(color or "#FFFFFF")
	end
end

function ArenaService.SetIdleVisuals(station: Station, idle: boolean)
	station.VsScreen.Enabled = idle
	station.Label.Enabled = idle
	station.Model:SetAttribute("InMatch", not idle)
end

function ArenaService.Occupants(station: Station): number
	local n = 0
	for _, pad in station.Pads do
		if pad.Occupant or pad.Bot then
			n += 1
		end
	end
	return n
end

-- Character placement ----------------------------------------------------------------------
local function rootOf(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function ArenaService.LockCharacter(player: Player, cf: CFrame)
	locked[player] = cf
	local root = rootOf(player)
	local character = player.Character
	if root and character then
		root.Anchored = true
		character:PivotTo(cf)
	end
end

function ArenaService.UnlockCharacter(player: Player, release: CFrame?)
	locked[player] = nil
	local root = rootOf(player)
	local character = player.Character
	if root and character then
		if release then
			character:PivotTo(release)
		end
		root.Anchored = false
	end
end

function ArenaService.IsLocked(player: Player): boolean
	return if locked[player] then true else false
end

function ArenaService.PadCFrame(station: Station, padIndex: number): CFrame
	return ArenaGeometry.PadCFrame(station.CFrame, station.Kind, padIndex)
end

function ArenaService.ReleaseCFrame(station: Station, padIndex: number): CFrame
	return ArenaGeometry.ReleaseCFrame(station.CFrame, station.Kind, padIndex)
end

function ArenaService.Init()
	local lobbyFolder = Workspace:FindFirstChild("Lobby") or Instance.new("Folder")
	lobbyFolder.Name = "Lobby"
	lobbyFolder.Parent = Workspace
	local folder = Instance.new("Folder")
	folder.Name = "Stations"
	folder.Parent = lobbyFolder
	for index, config in Lobby.Stations do
		local station = buildStation(config, index, folder)
		table.insert(ArenaService.Stations, station)
		ArenaService.ById[station.Id] = station
	end
end

function ArenaService.Start()
	for _, station in ArenaService.Stations do
		for _, pad in station.Pads do
			pad.Prompt.Triggered:Connect(function(player: Player)
				ArenaService.PadTriggered:Fire(player, station, pad.Index)
			end)
		end
	end
	-- keep locked characters on their pads across respawns
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			local cf = locked[player]
			if cf then
				local root = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
				if root and locked[player] then
					root.Anchored = true
					character:PivotTo(locked[player] :: CFrame)
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		locked[player] = nil
	end)
end

return ArenaService
