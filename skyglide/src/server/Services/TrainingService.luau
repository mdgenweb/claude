--!strict
-- Training pads: tap (RequestTrain, rate limited) or AUTO (server ticks) while standing on a pad.
-- The server decides which pad you are on from your character position and checks its rebirth /
-- game-pass lock before paying Pad multiplier x Skill multiplier.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Monetization = require(Shared.Config.Monetization)
local Training = require(Shared.Definitions.Training)
local Remotes = require(Shared.Net.Remotes)

local Server = script.Parent.Parent
local Guard = require(Server.Util.Guard)
local DataService = require(script.Parent.DataService)
local StatService = require(script.Parent.StatService)
local MapService = require(script.Parent.MapService)

local TrainingService = {}

local registry: { [string]: any } = {}
local trainResult: RemoteEvent
local lastWarn: { [Player]: number } = {}

local function warnOnce(player: Player, text: string)
	local t = os.clock()
	if (lastWarn[player] or 0) + 2.5 > t then
		return
	end
	lastWarn[player] = t
	local notify = registry.NotifyService
	if notify then
		notify.Toast(player, text, "Error")
	end
end

-- Is the pad open for this player? Returns (ok, reason)
function TrainingService.PadUnlocked(player: Player, pad: Training.Pad): (boolean, string?)
	local profile = DataService.Get(player)
	if not profile then
		return false, "Loading"
	end
	if pad.PassKey then
		local monetization = registry.MonetizationService
		if not (monetization and monetization.HasPass(player, pad.PassKey)) then
			local pass = Monetization.Pass(pad.PassKey)
			return false, string.format("Unlock this pad with the %s pass!", if pass then pass.Name else pad.PassKey)
		end
		return true, nil
	end
	if profile.Rebirths < pad.Rebirths then
		return false, string.format("Needs %d rebirths!", pad.Rebirths)
	end
	return true, nil
end

local function rep(player: Player, manual: boolean): boolean
	local profile = DataService.Get(player)
	if not profile then
		return false
	end
	if registry.FlightService and registry.FlightService.IsFlying(player) then
		return false
	end
	local pad = MapService.PadAt(player, profile.World)
	if not pad then
		if manual then
			warnOnce(player, "Stand on a training pad to train!")
		end
		return false
	end
	local ok, reason = TrainingService.PadUnlocked(player, pad)
	if not ok then
		warnOnce(player, reason or "Locked")
		return false
	end
	if StatService.AtCap(player) then
		warnOnce(player, "MAX LEVEL! Rebirth to keep gaining Skill.")
		return false
	end
	local amount = pad.Multiplier * Economy.TrainRepBase * StatService.SkillMultiplier(player)
	local added = StatService.AddSkill(player, amount, "Train")
	if added > 0 then
		trainResult:FireClient(player, { Amount = added, Pad = pad.Id })
		local tutorial = registry.TutorialService
		if tutorial then
			tutorial.Event(player, "Train")
		end
	end
	return true
end

function TrainingService.Init(reg: { [string]: any })
	registry = reg
	trainResult = Remotes.Event("TrainResult")
end

function TrainingService.Start()
	Guard.OnEvent(Remotes.Event("RequestTrain"), Economy.TrainManualRate, Economy.TrainManualRate + 2, function(player)
		rep(player, true)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastWarn[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(Economy.TrainAutoInterval)
			for _, player in Players:GetPlayers() do
				local profile = DataService.Get(player)
				if profile and profile.Settings.AutoTrain then
					rep(player, false)
				end
			end
		end
	end)
end

return TrainingService
