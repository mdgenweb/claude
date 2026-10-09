--!strict
-- Advances the first-session guide from real server events (Definitions/Tutorial).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tutorial = require(Shared.Definitions.Tutorial)
local Remotes = require(Shared.Net.Remotes)

local Server = script.Parent.Parent
local Guard = require(Server.Util.Guard)
local DataService = require(script.Parent.DataService)

local TutorialService = {}

local registry: { [string]: any } = {}

function TutorialService.Event(player: Player, event: string, amount: number?)
	local profile = DataService.Get(player)
	if not profile or profile.Tutorial.Done then
		return
	end
	local step = Tutorial.Steps[profile.Tutorial.Step]
	if not step or step.Event ~= event then
		return
	end
	DataService.Update(player, function(p)
		p.Tutorial.Progress += amount or 1
		if p.Tutorial.Progress >= (step.Count or 1) then
			p.Tutorial.Step += 1
			p.Tutorial.Progress = 0
			if p.Tutorial.Step > #Tutorial.Steps then
				p.Tutorial.Done = true
			end
		end
		return true
	end)
	local updated = DataService.Get(player)
	if updated and updated.Tutorial.Done then
		local notify = registry.NotifyService
		if notify then
			notify.Toast(player, "Tutorial complete! Fly farther to unlock new zones.", "Success")
		end
	end
end

function TutorialService.Init(reg: { [string]: any })
	registry = reg
end

function TutorialService.Start()
	Guard.OnEvent(Remotes.Event("RequestTutorial"), 1, 2, function(player, action)
		if action == "Skip" then
			DataService.Update(player, function(p)
				p.Tutorial.Done = true
				return true
			end)
		end
	end)
	-- "Walk into the Throw Zone" is detected on the server from the character position.
	task.spawn(function()
		local Players = game:GetService("Players")
		while true do
			task.wait(0.5)
			local map = registry.MapService
			for _, player in Players:GetPlayers() do
				local profile = DataService.Get(player)
				if profile and not profile.Tutorial.Done and map then
					local step = Tutorial.Steps[profile.Tutorial.Step]
					if step and step.Event == "EnterThrowZone" and map.InThrowZone(player, profile.World) then
						TutorialService.Event(player, "EnterThrowZone")
					end
				end
			end
		end
	end)
end

return TutorialService
