--!strict
-- Diagnostics for allow-listed admins (Config/Admin). Every request is re-checked here; normal
-- players get "not allowed" and the client never shows the panel to them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Admin = require(Shared.Config.Admin)
local Economy = require(Shared.Config.Economy)
local Worlds = require(Shared.Definitions.Worlds)
local Remotes = require(Shared.Net.Remotes)
local Validate = require(Shared.Util.Validate)

local Server = script.Parent.Parent
local Guard = require(Server.Util.Guard)
local DataService = require(script.Parent.DataService)

local AdminService = {}

local registry: { [string]: any } = {}

function AdminService.IsAdmin(player: Player): boolean
	if Admin.StudioAll and RunService:IsStudio() then
		return true
	end
	return table.find(Admin.UserIds, player.UserId) ~= nil
end

local function handle(player: Player, action: any, arg: any): { [string]: any }
	if not AdminService.IsAdmin(player) then
		return { ok = false, error = "Not allowed." }
	end
	if action == "Stats" then
		return {
			ok = true,
			stats = {
				Players = #Players:GetPlayers(),
				Flights = registry.FlightService and registry.FlightService.ActiveCount() or 0,
				MemoryMB = math.floor(Stats:GetTotalMemoryUsageMb()),
				Heartbeat = math.floor(1 / math.max(1e-3, Stats.HeartbeatTimeMs / 1000)),
				MockData = DataService.IsMock(),
			},
		}
	elseif action == "GrantSkill" and Validate.Number(arg, 0, 1e30) then
		registry.StatService.AddSkill(player, arg, "Admin")
	elseif action == "GrantWins" and Validate.Number(arg, 0, 1e30) then
		registry.StatService.AddWins(player, arg, "Admin")
	elseif action == "MaxLevel" then
		DataService.Update(player, function(p)
			p.Level = Economy.LevelCap(p.Rebirths)
			p.XP = 0
			return true
		end)
	elseif action == "UnlockWorlds" then
		DataService.Update(player, function(p)
			for _, w in Worlds.List do
				p.Worlds[tostring(w.Id)] = true
			end
			return true
		end)
	elseif action == "ResetTutorial" then
		DataService.Update(player, function(p)
			p.Tutorial = { Step = 1, Progress = 0, Done = false }
			return true
		end)
	else
		return { ok = false, error = "Unknown action." }
	end
	return { ok = true }
end

function AdminService.Init(reg: { [string]: any })
	registry = reg
	DataService.AddDecorator(function(player, view)
		view.IsAdmin = AdminService.IsAdmin(player)
	end)
end

function AdminService.Start()
	Guard.OnInvoke(Remotes.Function("AdminRequest"), 2, 5, handle)
end

return AdminService
