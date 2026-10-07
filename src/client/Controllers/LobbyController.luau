--!strict
-- Lobby presentation: interactive props (prompts open store tabs / claim group reward),
-- floating decor, event countdowns, leaderboard boards (rendered locally so each player sees
-- their own rank row) and hearts above the heads of battling players.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Lobby = require(Shared.Config.Lobby)
local Format = require(Shared.Util.Format)
local GameConfig = require(Shared.Config.Game)
local Remotes = require(Shared.Net.Remotes)

local Client = script.Parent.Parent
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local Icons = require(Client.UI.Components.Icons)
local UIController = require(script.Parent.UIController)
local StateController = require(script.Parent.StateController)

local LobbyController = {}

local localPlayer = Players.LocalPlayer
local playerGui: PlayerGui
local bobbing: { [Model]: CFrame } = {}
local boardGuis: { [string]: SurfaceGui } = {}
local headHearts: { [number]: BillboardGui } = {}

---------------------------------------------------------------------------------------------
-- Prompts

local function onPrompt(prompt: ProximityPrompt)
	local route = prompt:GetAttribute("OpenUI")
	if type(route) == "string" then
		local screen, tab = string.match(route, "^(%w+):?(%w*)$")
		if screen then
			UIController.Open(screen, if tab ~= "" then tab else nil)
		end
		return
	end
	if prompt:GetAttribute("Action") == "ClaimGroup" then
		local result = Remotes.Function("StoreRequest"):InvokeServer("ClaimGroup")
		if type(result) == "table" then
			UIController.Toast(if result.ok then (result.message or "Claimed!") else (result.error or "Couldn't claim."), if result.ok then "Success" else "Error")
		end
	end
end

---------------------------------------------------------------------------------------------
-- Leaderboards

local function renderBoard(model: Model, data: { [string]: any })
	local kind = model:GetAttribute("BoardKind")
	local screen: BasePart? = nil
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("BoardScreen") then
			screen = d
		end
	end
	if screen == nil then
		return
	end
	local key = model:GetFullName()
	local gui = boardGuis[key]
	if not gui then
		local created = Instance.new("SurfaceGui")
		created.Name = "Board"
		created.Adornee = screen
		created.Face = Enum.NormalId.Back
		created.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		created.PixelsPerStud = 30
		created.LightInfluence = 0
		created.Parent = playerGui
		boardGuis[key] = created
		gui = created
	end
	local g = gui :: SurfaceGui
	g:ClearAllChildren()
	local weekly = kind == "Weekly"
	local entries = if weekly then data.Weekly else data.AllTime
	local bg: Frame = Create("Frame", { BackgroundColor3 = Color3.fromHex("#141A2B"), Size = UDim2.fromScale(1, 1), Parent = g })
	local title = if weekly then Lobby.Leaderboards.WeeklyTitle else Lobby.Leaderboards.AllTimeTitle
	if weekly and data.WeekEndsAt then
		title ..= string.format("  (%s)", Format.Duration(data.WeekEndsAt - Workspace:GetServerTimeNow()))
	end
	Create.Text({ Text = title, Size = UDim2.new(1, -20, 0.11, 0), Position = UDim2.fromScale(0.02, 0.02), Font = Theme.Fonts.Display, Scaled = true, Stroke = 2, Parent = bg })
	local header: Frame = Create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.03, 0.14), Size = UDim2.fromScale(0.94, 0.06), Parent = bg })
	Create.Text({ Text = "Rank", Size = UDim2.fromScale(0.12, 1), Font = Theme.Fonts.Body, Scaled = true, Color = Theme.Colors.TextDim, Parent = header })
	Create.Text({ Text = "Name", Size = UDim2.fromScale(0.45, 1), Position = UDim2.fromScale(0.14, 0), Font = Theme.Fonts.Body, Scaled = true, XAlign = Enum.TextXAlignment.Left, Color = Theme.Colors.TextDim, Parent = header })
	Create.Text({ Text = if data.Stat == "RobuxSpent" then "Spent" else "Wins", Size = UDim2.fromScale(0.2, 1), Position = UDim2.fromScale(if weekly then 0.6 else 0.78, 0), Font = Theme.Fonts.Body, Scaled = true, Color = Theme.Colors.TextDim, Parent = header })
	if weekly then
		Create.Text({ Text = "Rewards", Size = UDim2.fromScale(0.18, 1), Position = UDim2.fromScale(0.82, 0), Font = Theme.Fonts.Body, Scaled = true, Color = Theme.Colors.TextDim, Parent = header })
	end
	local rowColors = { Color3.fromHex("#C9A227"), Color3.fromHex("#8E949E"), Color3.fromHex("#9C5B2E") }
	local function row(entry: { [string]: any }, y: number, highlight: boolean): TextLabel
		local r: Frame = Create("Frame", {
			BackgroundColor3 = if highlight then Color3.fromHex("#2F74E8") else (rowColors[entry.Rank] or Color3.fromHex("#1E2740")),
			BackgroundTransparency = if entry.Rank <= 3 or highlight then 0.1 else 0.3,
			Position = UDim2.fromScale(0.03, y),
			Size = UDim2.fromScale(0.94, 0.062),
			Parent = bg,
		})
		local rankLabel = Create.Text({ Text = tostring(entry.Rank), Size = UDim2.fromScale(0.12, 0.8), Position = UDim2.fromScale(0, 0.1), Font = Theme.Fonts.Display, Scaled = true, Stroke = 1.5, Parent = r })
		Create.Text({ Text = entry.Name, Size = UDim2.fromScale(0.45, 0.8), Position = UDim2.fromScale(0.14, 0.1), Font = Theme.Fonts.Body, Scaled = true, XAlign = Enum.TextXAlignment.Left, Stroke = 1.5, Parent = r })
		Create.Text({ Text = Format.Commas(entry.Value), Size = UDim2.fromScale(0.2, 0.8), Position = UDim2.fromScale(if weekly then 0.6 else 0.78, 0.1), Font = Theme.Fonts.Display, Scaled = true, Stroke = 1.5, Parent = r })
		if weekly and data.Rewards and data.Rewards[entry.Rank] then
			Create.Text({ Text = "x" .. data.Rewards[entry.Rank].Count .. " Adv.", Size = UDim2.fromScale(0.16, 0.8), Position = UDim2.fromScale(0.83, 0.1), Font = Theme.Fonts.Body, Scaled = true, Color = Theme.Colors.Gold, Stroke = 1.5, Parent = r })
		end
		return rankLabel
	end
	for i, entry in entries or {} do
		if i > 10 then
			break
		end
		row(entry, 0.21 + (i - 1) * 0.066, entry.UserId == localPlayer.UserId)
	end
	-- own rank pinned at the bottom
	local ranks = data.Ranks and data.Ranks[tostring(localPlayer.UserId)]
	local myRank = if ranks then (if weekly then ranks.Weekly else ranks.AllTime) else nil
	local profile = StateController.Data
	local myValue = 0
	if profile and profile.Stats then
		myValue = if data.Stat == "RobuxSpent" then profile.Stats.RobuxSpent or 0 else profile.Stats.Wins or 0
	end
	local myRankLabel = row({ Rank = myRank or 0, Name = localPlayer.Name, Value = myValue, UserId = localPlayer.UserId }, 0.9, true)
	if myRank == nil then
		myRankLabel.Text = "100+"
	end
end

local function renderBoards()
	local data = StateController.Leaderboards
	if data == nil then
		return
	end
	for _, model in CollectionService:GetTagged("Leaderboard") do
		if model:IsA("Model") then
			pcall(renderBoard, model, data)
		end
	end
end

---------------------------------------------------------------------------------------------
-- Hearts above battling players' heads

local function heartsFor(userId: number, hearts: number?)
	local existing = headHearts[userId]
	if hearts == nil then
		if existing then
			existing:Destroy()
			headHearts[userId] = nil
		end
		return
	end
	local player = Players:GetPlayerByUserId(userId)
	local head = player and player.Character and player.Character:FindFirstChild("Head")
	if head == nil then
		return
	end
	local gui = existing
	if not gui or gui.Adornee ~= head then
		if gui then
			gui:Destroy()
		end
		local g = Instance.new("BillboardGui")
		g.Name = "Hearts_" .. userId
		g.Adornee = head :: BasePart
		g.Size = UDim2.new(4.2, 0, 1.3, 0)
		g.StudsOffset = Vector3.new(0, 2.4, 0)
		g.LightInfluence = 0
		g.MaxDistance = 140
		g.Parent = playerGui
		local holder: Frame = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = g })
		Create.List(holder, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
		for i = 1, GameConfig.Hearts do
			local heart = Icons.Heart(UDim2.fromScale(0.3, 1), holder)
			heart.LayoutOrder = i
			heart.Name = "H" .. i
		end
		headHearts[userId] = g
		gui = g
	end
	local holder = (gui :: BillboardGui):FindFirstChildOfClass("Frame")
	if holder then
		for i = 1, GameConfig.Hearts do
			local heart = holder:FindFirstChild("H" .. i) :: Frame?
			if heart then
				Icons.SetHeart(heart, i <= (hearts :: number))
			end
		end
	end
end

local function onStation(payload: { [string]: any })
	local match = payload.Match
	local seen: { [number]: boolean } = {}
	if match and match.State ~= "Closed" and match.State ~= "Created" then
		for _, p in match.Participants do
			if p.UserId > 0 then
				seen[p.UserId] = true
				heartsFor(p.UserId, match.Hearts[p.Team])
			end
		end
	end
	-- remove hearts of players who were in this station's previous match
	for _, pad in payload.Pads do
		if pad.UserId > 0 and not seen[pad.UserId] then
			heartsFor(pad.UserId, nil)
		end
	end
	if match == nil then
		for userId, gui in headHearts do
			local still = false
			for _, station in StateController.Stations do
				if station.Match then
					for _, p in station.Match.Participants do
						if p.UserId == userId then
							still = true
						end
					end
				end
			end
			if not still then
				gui:Destroy()
				headHearts[userId] = nil
			end
		end
	end
end

function LobbyController.Start()
	playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if CollectionService:HasTag(prompt, "UIPrompt") then
			onPrompt(prompt)
		end
	end)

	local function trackBob(model: Instance)
		if model:IsA("Model") then
			bobbing[model] = model:GetPivot()
		end
	end
	for _, m in CollectionService:GetTagged("Bob") do
		trackBob(m)
	end
	CollectionService:GetInstanceAddedSignal("Bob"):Connect(trackBob)
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for model, base in bobbing do
			if model.Parent == nil then
				bobbing[model] = nil
			else
				local amp = (model:GetAttribute("Bob") :: number?) or 1
				model:PivotTo(base * CFrame.new(0, math.sin(t * 1.4) * amp, 0) * CFrame.Angles(0, t * 0.35, 0))
			end
		end
	end)

	-- event countdowns + leaderboard week timer
	task.spawn(function()
		while true do
			for _, gui in CollectionService:GetTagged("EventTimer") do
				local endsAt = gui:GetAttribute("EndsAt") :: number?
				local timer = gui:FindFirstChild("Timer") :: TextLabel?
				if endsAt and timer then
					local left = endsAt - Workspace:GetServerTimeNow()
					timer.Text = if left > 0 then "Ends in " .. Format.Duration(left) else "Event ended"
				end
			end
			task.wait(1)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(30)
			renderBoards()
		end
	end)

	StateController.LeaderboardChanged:Connect(renderBoards)
	StateController.StationChanged:Connect(onStation)
	renderBoards()
end

return LobbyController
