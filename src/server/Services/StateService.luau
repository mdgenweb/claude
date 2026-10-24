-- Live session per player: wraps saved data with session-only state (passes, lane,
-- menu state), owns all Scrap changes, and replicates a compact snapshot to the client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Signal = require(Shared.Signal)

local DataService = require(script.Parent.DataService)
local Analytics = require(script.Parent.Analytics)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local StateService = {}

export type Session = {
	Player: Player,
	Data: any,
	Passes: { [string]: boolean },
	Lane: number?,
	InMenu: boolean,
	BoostTicking: boolean,
	PushQueued: boolean,
	Leaderstats: Folder?,
}

local sessions: { [Player]: Session } = {}

StateService.Started = Signal.new() -- (player, session)
StateService.Ended = Signal.new() -- (player)
StateService.LevelChanged = Signal.new() -- (player, session)
StateService.LookChanged = Signal.new() -- (player, session) tool / finish

function StateService.get(player: Player): Session?
	return sessions[player]
end

function StateService.all(): { [Player]: Session }
	return sessions
end

function StateService.power(session: Session): number
	return Economy.powerForLevel(session.Data.Level)
end

function StateService.boostActive(session: Session): boolean
	return session.Data.BoostRemaining > 0
end

function StateService.areaUnlocked(session: Session, area: number): boolean
	if area == 1 then
		return true
	elseif area == 2 then
		return session.Data.Gates.Appliance
	elseif area == 3 then
		return session.Data.Gates.Crusher
	end
	return false
end

function StateService.rollDaily(data)
	local today = Economy.dayIndex(os.time())
	if data.Daily.Day ~= today then
		data.Daily = { Day = today, Progress = 0, Claimed = false }
	end
end

local function snapshot(session: Session)
	local data = session.Data
	StateService.rollDaily(data)
	local finishes = {}
	for id, owned in data.Finishes do
		if owned then
			table.insert(finishes, id)
		end
	end
	return {
		Scrap = data.Scrap,
		Level = data.Level,
		Power = Economy.powerForLevel(data.Level),
		Rebirths = data.Rebirths,
		Gates = { Appliance = data.Gates.Appliance, Crusher = data.Gates.Crusher }, -- string keys survive remotes
		CrusherDestroys = data.CrusherDestroys,
		Tool = data.Tool,
		ToolChosen = data.ToolChosen,
		Finish = data.Finish,
		Finishes = finishes,
		BoostCharges = data.BoostCharges,
		BoostRemaining = data.BoostRemaining,
		BoostTicking = session.BoostTicking,
		Workshop = { Stored = data.Workshop.Stored, Updated = data.Workshop.Updated },
		Daily = { Day = data.Daily.Day, Progress = data.Daily.Progress, Claimed = data.Daily.Claimed },
		Stamps = data.Stamps,
		StarterGranted = data.StarterGranted,
		Passes = table.clone(session.Passes),
		Lane = session.Lane,
		Funnel = table.clone(data.Funnel),
		Destroys = data.Stats.Destroys,
		ServerTime = os.time(),
		StudioTest = RunService:IsStudio() and Config.StudioTestPurchases,
		Multiplier = Economy.totalMultiplier(
			data.Rebirths,
			session.Passes.DoubleScrap == true,
			data.BoostRemaining > 0
		),
		MemoryData = DataService.usingMemory(),
	}
end

local function refreshPublic(session: Session)
	local player = session.Player
	local data = session.Data
	player:SetAttribute("Power", Economy.powerForLevel(data.Level))
	player:SetAttribute("MechLevel", data.Level)
	player:SetAttribute("Rebirths", data.Rebirths)
	player:SetAttribute("Lane", session.Lane)
	player:SetAttribute("IsVIP", session.Passes.FoundryVIP == true)
	player:SetAttribute("HasAutoFarm", session.Passes.AutoFarm == true)
	player:SetAttribute("Tool", data.Tool)
	local stats = session.Leaderstats
	if stats then
		local values = { Scrap = data.Scrap, Power = Economy.powerForLevel(data.Level), Rebirths = data.Rebirths }
		for name, value in values do
			local stat = stats:FindFirstChild(name)
			if stat and stat:IsA("IntValue") then
				stat.Value = value
			end
		end
	end
end

-- Queue a state push; multiple changes in one frame send one snapshot.
function StateService.push(player: Player)
	local session = sessions[player]
	if not session or session.PushQueued then
		return
	end
	session.PushQueued = true
	task.defer(function()
		session.PushQueued = false
		if sessions[player] ~= session then
			return
		end
		refreshPublic(session)
		Remotes.State:FireClient(player, snapshot(session))
	end)
end

-- Scrap in. `kind` is for analytics ("Smash", "Workshop", "Daily", "Purchase"...).
function StateService.addScrap(player: Player, amount: number, kind: string)
	local session = sessions[player]
	if not session or amount <= 0 then
		return
	end
	session.Data.Scrap += amount
	if kind == "Smash" then
		session.Data.Stats.ScrapEarned += amount
	end
	StateService.push(player)
end

-- Scrap out. Returns false (and changes nothing) if the player can't afford it.
function StateService.spend(player: Player, amount: number): boolean
	local session = sessions[player]
	if not session or amount < 0 or session.Data.Scrap < amount then
		return false
	end
	session.Data.Scrap -= amount
	StateService.push(player)
	return true
end

function StateService.notify(player: Player, kind: string, title: string, body: string?)
	Remotes.Notify:FireClient(player, kind, title, body or "")
end

local function makeLeaderstats(player: Player): Folder
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	for _, name in { "Scrap", "Power", "Rebirths" } do
		local v = Instance.new("IntValue")
		v.Name = name
		v.Parent = folder
	end
	folder.Parent = player
	return folder
end

local function onPlayerAdded(player: Player)
	local data = DataService.load(player)
	if not data then
		if player.Parent then
			player:Kick("We couldn't load your mech. Please rejoin in a moment.")
		end
		return
	end
	StateService.rollDaily(data)
	local session: Session = {
		Player = player,
		Data = data,
		Passes = {},
		Lane = nil,
		InMenu = false,
		BoostTicking = false,
		PushQueued = false,
		Leaderstats = makeLeaderstats(player),
	}
	sessions[player] = session
	Analytics.funnel(player, data, "Joined")
	refreshPublic(session)
	StateService.Started:Fire(player, session)
	StateService.push(player)
end

function StateService.init()
	Players.PlayerRemoving:Connect(function(player)
		if sessions[player] then
			sessions[player] = nil
			StateService.Ended:Fire(player)
		end
	end)
end

-- Called once every service has subscribed to Started, so nobody misses a player.
function StateService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return StateService
