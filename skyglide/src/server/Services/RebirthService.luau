--!strict
-- Rebirth: available at the level cap. Resets Skill, Level and XP; keeps Wins, gliders, pets,
-- trails and worlds; raises the permanent Skill multiplier and the level cap.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Progression = require(Shared.Sim.Progression)
local Remotes = require(Shared.Net.Remotes)

local Server = script.Parent.Parent
local Guard = require(Server.Util.Guard)
local DataService = require(script.Parent.DataService)

local RebirthService = {}

local registry: { [string]: any } = {}

local function requestRebirth(player: Player): { [string]: any }
	local profile = DataService.Get(player)
	if not profile then
		return { ok = false, error = "Still loading..." }
	end
	if registry.FlightService and registry.FlightService.IsFlying(player) then
		return { ok = false, error = "Wait until your glider lands." }
	end
	if not Progression.CanRebirth(profile) then
		return { ok = false, error = string.format("Reach level %d to rebirth!", Progression.LevelCap(profile)) }
	end
	local rebirths = DataService.Update(player, function(p)
		p.Rebirths += 1
		p.Skill = 0
		Progression.SyncLevel(p)
		return p.Rebirths
	end) or 0
	DataService.SaveNow(player)
	local notify = registry.NotifyService
	if notify then
		notify.Toast(player, string.format("REBIRTH %d! Skill multiplier x%d", rebirths, Economy.RebirthMultiplier(rebirths)), "Rare")
	end
	return { ok = true, rebirths = rebirths }
end

function RebirthService.Init(reg: { [string]: any })
	registry = reg
end

function RebirthService.Start()
	Guard.OnInvoke(Remotes.Function("RequestRebirth"), 1, 2, requestRebirth)
end

return RebirthService
