--!strict
-- leaderstats (player list) and global top-10 boards on the hub walls.
-- Huge numbers are stored in OrderedDataStores as floor(log10(x + 1) * 1e5) so any value fits
-- an integer key; boards decode them back for display.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Map = require(Shared.Config.Map)
local Remotes = require(Shared.Net.Remotes)
local Format = require(Shared.Util.Format)

local DataService = require(script.Parent.DataService)
local MapService = require(script.Parent.MapService)

local LeaderboardService = {}

local STATS = { "Wins", "BestDistance", "Rebirths" }
local TITLES = { Wins = "TOP WINS", BestDistance = "LONGEST GLIDE", Rebirths = "MOST REBIRTHS" }
local LOG_SCALE = 1e5

local stores: { [string]: any } = {}
local boards: { [string]: { { Name: string, Value: number } } } = {}
local serverInfo: RemoteEvent

local function encode(stat: string, value: number): number
	if stat == "Rebirths" then
		return math.floor(value)
	end
	return math.floor(math.log10(math.max(0, value) + 1) * LOG_SCALE)
end

local function decode(stat: string, value: number): number
	if stat == "Rebirths" then
		return value
	end
	return 10 ^ (value / LOG_SCALE) - 1
end

local function display(stat: string, value: number): string
	if stat == "BestDistance" then
		return Format.Meters(value)
	end
	return Format.Short(value)
end

local function statValue(profile: DataService.Profile, stat: string): number
	if stat == "Wins" then
		return profile.Stats.TotalWins
	elseif stat == "BestDistance" then
		return profile.Stats.BestDistance
	end
	return profile.Rebirths
end

local function setupLeaderstats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local skill = Instance.new("StringValue")
	skill.Name = "Skill"
	skill.Value = "0"
	skill.Parent = folder
	local wins = Instance.new("StringValue")
	wins.Name = "Wins"
	wins.Value = "0"
	wins.Parent = folder
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = folder
	folder.Parent = player
end

local function updateLeaderstats(player: Player, profile: DataService.Profile)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		return
	end
	local skill = folder:FindFirstChild("Skill") :: StringValue?
	local wins = folder:FindFirstChild("Wins") :: StringValue?
	local rebirths = folder:FindFirstChild("Rebirths") :: IntValue?
	if skill then
		skill.Value = Format.Short(profile.Skill)
	end
	if wins then
		wins.Value = Format.Short(profile.Wins)
	end
	if rebirths then
		rebirths.Value = profile.Rebirths
	end
end

local function renderBoards()
	local folder = MapService.Folder
	if not folder then
		return
	end
	for _, stat in STATS do
		local rows: { { Name: string, Value: number } } = boards[stat] or {}
		for _, part in folder:GetDescendants() do
			if part.Name == "Board_" .. stat then
				local gui = part:FindFirstChild("Board")
				local list = gui and gui:FindFirstChild("List")
				local title = gui and gui:FindFirstChild("Title")
				if title and title:IsA("TextLabel") then
					title.Text = TITLES[stat]
				end
				if list then
					for _, child in list:GetChildren() do
						if child:IsA("TextLabel") then
							child:Destroy()
						end
					end
					for i, row in rows do
						local label = Instance.new("TextLabel")
						label.Name = "Row" .. i
						label.LayoutOrder = i
						label.BackgroundTransparency = 1
						label.Size = UDim2.new(1, 0, 0.09, 0)
						label.TextScaled = true
						label.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
						label.TextColor3 = if i == 1 then Color3.fromHex("#FFD447") elseif i == 2 then Color3.fromHex("#E3E9F2") elseif i == 3 then Color3.fromHex("#FFB07A") else Color3.new(1, 1, 1)
						label.Text = string.format("#%d  %s  -  %s", i, row.Name, display(stat, row.Value))
						local stroke = Instance.new("UIStroke")
						stroke.Thickness = 2
						stroke.Parent = label
						label.Parent = list
					end
				end
			end
		end
	end
	serverInfo:FireAllClients({ Kind = "Leaderboards", Boards = boards })
end

local nameCache: { [number]: string } = {}

local function namesFor(userIds: { number }): { [number]: string }
	local out = {}
	for _, id in userIds do
		local player = Players:GetPlayerByUserId(id)
		if player then
			out[id] = player.DisplayName
		elseif nameCache[id] then
			out[id] = nameCache[id]
		else
			local ok, name = pcall(function()
				return Players:GetNameFromUserIdAsync(id)
			end)
			out[id] = if ok and name then name else ("Player " .. id)
			if ok and name then
				nameCache[id] = name
			end
		end
	end
	return out
end

local function refresh()
	for _, stat in STATS do
		local store = stores[stat]
		if store then
			for _, player in Players:GetPlayers() do
				local profile = DataService.Get(player)
				if profile then
					local value = encode(stat, statValue(profile, stat))
					if value > 0 then
						pcall(function()
							store:SetAsync(tostring(player.UserId), value)
						end)
					end
				end
			end
			local ok, pages = pcall(function()
				return store:GetSortedAsync(false, 10)
			end)
			if ok and pages then
				local entries = pages:GetCurrentPage()
				local ids = {}
				for _, e in entries do
					table.insert(ids, tonumber(e.key) or 0)
				end
				local names = namesFor(ids)
				local rows = {}
				for _, e in entries do
					table.insert(rows, { Name = names[tonumber(e.key) or 0] or "?", Value = decode(stat, e.value) })
				end
				boards[stat] = rows
			end
		else
			-- no DataStore access (Studio without API): show this server's players
			local rows = {}
			for _, player in Players:GetPlayers() do
				local profile = DataService.Get(player)
				if profile then
					table.insert(rows, { Name = player.DisplayName, Value = statValue(profile, stat) })
				end
			end
			table.sort(rows, function(a, b)
				return a.Value > b.Value
			end)
			while #rows > 10 do
				table.remove(rows)
			end
			boards[stat] = rows
		end
	end
	renderBoards()
end

function LeaderboardService.Init()
	serverInfo = Remotes.Event("ServerInfo")
	for _, stat in STATS do
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore("SkyGlide_LB_" .. stat .. "_v1")
		end)
		if ok and store then
			local probe = pcall(function()
				store:GetSortedAsync(false, 1)
			end)
			if probe then
				stores[stat] = store
			end
		end
	end
	local _ = Map
end

function LeaderboardService.Start()
	Players.PlayerAdded:Connect(setupLeaderstats)
	for _, player in Players:GetPlayers() do
		if not player:FindFirstChild("leaderstats") then
			setupLeaderstats(player)
		end
	end
	DataService.Changed:Connect(function(player, profile)
		updateLeaderstats(player, profile)
	end)
	DataService.Loaded:Connect(function(player, profile)
		updateLeaderstats(player, profile)
	end)
	task.spawn(function()
		task.wait(8)
		while true do
			refresh()
			task.wait(120)
		end
	end)
end

return LeaderboardService
