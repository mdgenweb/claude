--[[
	LobbyBuilder
	Elmore Plaza: the hub. Each station has a ProximityPrompt tagged with attribute `Screen`, which the client
	uses to open the matching UI (everything is also reachable from the HUD for mobile players).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Build = require(script.Parent.Build)
local Props = require(script.Parent.Props)

local LobbyBuilder = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function addPrompt(part: BasePart, screen: string, actionText: string, objectText: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("Screen", screen)
	prompt.Parent = part
	return prompt
end

local function station(parent: Instance, name: string, position: Vector3, color: Color3, screen: string, actionText: string)
	local pad = Build.cylinder(parent, position + Vector3.new(0, 0.25, 0), 0.5, 12, color)
	pad.Name = name .. "Pad"
	local ring = Build.cylinder(parent, position + Vector3.new(0, 0.2, 0), 0.4, 13.4, rgb(40, 28, 60))
	ring.Name = name .. "Ring"
	local anchor = Build.part({
		Name = name .. "Prompt",
		Size = Vector3.new(2, 2, 2),
		CFrame = CFrame.new(position + Vector3.new(0, 3, 0)),
		Transparency = 1,
		CanCollide = false,
	}, parent)
	addPrompt(anchor, screen, actionText, name)
	Build.label(anchor, name, { offset = Vector3.new(0, 9, 0), size = UDim2.fromOffset(320, 70), color = color })
	return anchor
end

function LobbyBuilder.build()
	local origin = GameConfig.Lobby.Origin
	local existing = workspace:FindFirstChild("Lobby")
	if existing then
		existing:Destroy()
	end
	local lobby = Build.model("Lobby", workspace)

	-- Ground & plaza
	Build.part({
		Name = "Grass",
		CFrame = CFrame.new(origin + Vector3.new(0, -0.5, 0)),
		Size = Vector3.new(240, 1, 200),
		Color = rgb(118, 200, 92),
		Material = Enum.Material.Grass,
	}, lobby)
	Build.cylinder(lobby, origin + Vector3.new(0, 0.05, 0), 0.3, 84, rgb(240, 226, 200), Enum.Material.Concrete)
	Build.cylinder(lobby, origin + Vector3.new(0, 0.1, 0), 0.3, 30, rgb(255, 214, 120), Enum.Material.Concrete)
	-- Walkway to spawn
	Build.block(lobby, CFrame.new(origin + Vector3.new(0, 0.08, 40)), Vector3.new(12, 0.3, 30), rgb(240, 226, 200), Enum.Material.Concrete)

	-- Spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(origin + GameConfig.Lobby.SpawnOffset - Vector3.new(0, 3.5, 0))
	spawn.Color = rgb(79, 183, 242)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = lobby
	Props.archSign(lobby, CFrame.new(origin + Vector3.new(0, 0, 50)), "ELMORE DEFENSE")

	-- Centrepiece: the Gumball Machine (summons)
	local machine = Props.gumballMachine(lobby, origin + Vector3.new(0, 0, -6), 1)
	local chute = machine:FindFirstChild("Chute") :: BasePart
	addPrompt(chute, "Summon", "Summon", "Gumball Machine")
	Build.label(machine.PrimaryPart :: BasePart, "SUMMON", {
		offset = Vector3.new(0, 10, 0),
		size = UDim2.fromOffset(320, 80),
		color = rgb(255, 120, 190),
	})

	-- Elmore Junior High: Play
	Props.school(lobby, CFrame.new(origin + Vector3.new(0, 0, -64)) * CFrame.Angles(0, math.rad(180), 0))
	station(lobby, "PLAY", origin + Vector3.new(0, 0, -48), rgb(87, 209, 99), "Play", "Choose a mission")

	-- Void Rift: Traits
	Props.voidPortal(lobby, CFrame.lookAt(origin + Vector3.new(-46, 0, -14), origin + Vector3.new(0, 0, -14)) * CFrame.Angles(0, math.rad(90), 0))
	station(lobby, "VOID RIFT", origin + Vector3.new(-34, 0, -14), rgb(176, 108, 255), "Traits", "Reroll traits")

	-- Principal Brown's Office: Grades
	Props.shop(lobby, CFrame.lookAt(origin + Vector3.new(50, 0, -14), origin + Vector3.new(0, 0, -14)) * CFrame.Angles(0, math.rad(180), 0), "PRINCIPAL", rgb(255, 196, 46))
	station(lobby, "REPORT CARDS", origin + Vector3.new(36, 0, -14), rgb(255, 214, 70), "Grades", "Reroll grades")

	-- Joyful Burger: Glow-Ups
	Props.shop(lobby, CFrame.lookAt(origin + Vector3.new(50, 0, 20), origin + Vector3.new(0, 0, 20)) * CFrame.Angles(0, math.rad(180), 0), "JOYFUL BURGER", rgb(255, 120, 60))
	station(lobby, "GLOW-UPS", origin + Vector3.new(36, 0, 20), rgb(255, 138, 31), "Evolve", "Evolve units")

	-- Yearbook podium: Index
	local podium = Build.block(lobby, CFrame.new(origin + Vector3.new(-46, 2, 20)), Vector3.new(4, 4, 4), rgb(140, 92, 56), Enum.Material.Wood)
	local book = Build.block(lobby, CFrame.new(origin + Vector3.new(-46, 4.4, 20)) * CFrame.Angles(math.rad(-20), math.rad(90), 0), Vector3.new(5, 0.8, 3.6), rgb(79, 183, 242))
	book.Name = "Yearbook"
	podium.Name = "YearbookPodium"
	station(lobby, "YEARBOOK", origin + Vector3.new(-34, 0, 20), rgb(79, 183, 242), "Yearbook", "Open the Yearbook")

	-- Elmore Pass board + Shop kiosk + Codes mailbox
	local board = Build.block(lobby, CFrame.new(origin + Vector3.new(-24, 6, -36)) * CFrame.Angles(0, math.rad(25), 0), Vector3.new(12, 8, 0.6), rgb(255, 248, 231))
	Build.label(board, "ELMORE PASS\nSEASON 1", { surface = true, face = Enum.NormalId.Back, color = rgb(255, 120, 190) })
	Build.label(board, "ELMORE PASS\nSEASON 1", { surface = true, face = Enum.NormalId.Front, color = rgb(255, 120, 190) })
	Build.cylinder(lobby, origin + Vector3.new(-24, 1, -36), 2, 1, rgb(40, 28, 60))
	station(lobby, "ELMORE PASS", origin + Vector3.new(-20, 0, -28), rgb(255, 120, 190), "Pass", "View the pass")

	Props.shop(lobby, CFrame.lookAt(origin + Vector3.new(26, 0, -40), origin) * CFrame.Angles(0, math.rad(180), 0), "MALL KIOSK", rgb(79, 183, 242))
	station(lobby, "SHOP", origin + Vector3.new(20, 0, -28), rgb(79, 183, 242), "Shop", "Open the shop")

	local mailbox = Build.block(lobby, CFrame.new(origin + Vector3.new(16, 3, 34)), Vector3.new(2.4, 2, 3.2), rgb(80, 120, 220), Enum.Material.Metal)
	Build.cylinder(lobby, origin + Vector3.new(16, 1, 34), 2, 0.6, rgb(60, 60, 80))
	addPrompt(mailbox, "Codes", "Redeem codes", "Elmore Mailbox")
	Build.label(mailbox, "CODES", { offset = Vector3.new(0, 4, 0), size = UDim2.fromOffset(200, 50), color = rgb(255, 214, 70) })

	-- Leaderboard board (populated by LeaderboardService)
	local leaderboard = Build.block(lobby, CFrame.new(origin + Vector3.new(-18, 7, 32)) * CFrame.Angles(0, math.rad(-20), 0), Vector3.new(12, 12, 0.6), rgb(40, 28, 60))
	leaderboard.Name = "LeaderboardBoard"

	-- Dressing: ring of lamps, benches, perimeter trees
	for index = 0, 11 do
		local angle = index / 12 * math.pi * 2
		local position = origin + Vector3.new(math.cos(angle) * 40, 0, math.sin(angle) * 40)
		if math.abs(math.cos(angle)) > 0.25 or math.sin(angle) < 0 then
			Props.lamp(lobby, position, if index % 2 == 0 then rgb(255, 236, 160) else rgb(255, 180, 220))
		end
	end
	for index = 0, 5 do
		local angle = (index + 0.5) / 6 * math.pi * 2
		local position = origin + Vector3.new(math.cos(angle) * 22, 0, math.sin(angle) * 22)
		Props.bench(lobby, CFrame.lookAt(position, origin))
	end
	local rng = Random.new(7)
	for index = 0, 27 do
		local angle = index / 28 * math.pi * 2
		local radius = rng:NextNumber(78, 92)
		local position = origin + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius * 0.8)
		if index % 3 == 0 then
			Props.pine(lobby, position, rng:NextNumber(1, 1.5))
		else
			Props.tree(lobby, position, rng:NextNumber(1, 1.6))
		end
	end
	for index = 0, 9 do
		local angle = index / 10 * math.pi * 2 + 0.3
		Props.bush(lobby, origin + Vector3.new(math.cos(angle) * 60, 0, math.sin(angle) * 50))
	end

	return lobby
end

return LobbyBuilder
