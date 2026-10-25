--[[
	LeaderboardService
	Global "best Infinite wave" leaderboard on an OrderedDataStore (cached; refreshed every 2 minutes).
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local LeaderboardService = {}

local registry
local store: OrderedDataStore? = nil
local cache = { updatedAt = 0, entries = {} }
local nameCache: { [number]: string } = {}
local REFRESH = 120

local function resolveName(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	nameCache[userId] = if ok and name then name else ("Player " .. userId)
	return nameCache[userId]
end

local function refresh()
	if not store then
		return
	end
	local ok, pages = pcall(function()
		return (store :: OrderedDataStore):GetSortedAsync(false, 25)
	end)
	if not ok then
		return
	end
	local entries = {}
	for rank, item in pages:GetCurrentPage() do
		local userId = tonumber(item.key)
		if userId then
			table.insert(entries, { rank = rank, userId = userId, name = resolveName(userId), wave = item.value })
		end
	end
	cache = { updatedAt = os.time(), entries = entries }
	LeaderboardService.renderBoard()
end

-- Writes the top 10 onto the lobby's physical board.
function LeaderboardService.renderBoard()
	local lobby = workspace:FindFirstChild("Lobby")
	local board = lobby and lobby:FindFirstChild("LeaderboardBoard")
	if not board then
		return
	end
	local gui = board:FindFirstChild("BoardGui")
	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Name = "BoardGui"
		gui.Face = Enum.NormalId.Back
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.Parent = board
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 6)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = gui
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 16)
		padding.Parent = gui
	end
	for _, child in gui:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local function line(text: string, order: number, color: Color3, height: number)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(0.92, 0, 0, height)
		label.Text = text
		label.TextScaled = true
		label.FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
		label.TextColor3 = color
		label.LayoutOrder = order
		label.Parent = gui
	end
	line("INFINITE MODE: TOP WAVES", 0, Color3.fromRGB(255, 214, 70), 52)
	if #cache.entries == 0 then
		line("No records yet. Be the first!", 1, Color3.fromRGB(255, 255, 255), 30)
	end
	for index = 1, math.min(10, #cache.entries) do
		local entry = cache.entries[index]
		local color = if index == 1
			then Color3.fromRGB(255, 214, 70)
			elseif index <= 3 then Color3.fromRGB(176, 220, 255)
			else Color3.fromRGB(255, 255, 255)
		line(string.format("#%d  %s  -  Wave %d", index, entry.name, entry.wave), index, color, 30)
	end
end

function LeaderboardService.submit(player: Player, wave: number)
	if not store or wave <= 0 then
		return
	end
	task.spawn(function()
		pcall(function()
			(store :: OrderedDataStore):UpdateAsync(tostring(player.UserId), function(old)
				if old and old >= wave then
					return nil
				end
				return math.floor(wave)
			end)
		end)
	end)
end

function LeaderboardService.top()
	return cache.entries
end

function LeaderboardService.init(services)
	registry = services
	if registry.DataService.isMemoryMode() then
		return
	end
	local ok, result = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, GameConfig.LeaderboardStoreName)
	if ok then
		store = result
	end
end

function LeaderboardService.start()
	LeaderboardService.renderBoard()
	task.spawn(function()
		while true do
			refresh()
			task.wait(REFRESH)
		end
	end)
	registry.NetService.handle("GetLeaderboard", function()
		return true, cache.entries
	end, { rate = 1, burst = 2, requireProfile = false })
end

return LeaderboardService
