--!strict
-- Toggles and cosmetic preferences. AUTO THROW requires its game pass; AUTO train is free.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local Validate = require(Shared.Util.Validate)

local Server = script.Parent.Parent
local Guard = require(Server.Util.Guard)
local DataService = require(script.Parent.DataService)

local SettingsService = {}

local registry: { [string]: any } = {}

local PREFERENCES = { FollowCam = true, Sfx = true, LowFx = true }

local function onToggle(player: Player, key: any, on: any)
	if not Validate.Boolean(on) then
		return
	end
	if key == "AutoTrain" then
		DataService.Update(player, function(p)
			p.Settings.AutoTrain = on
			return true
		end)
	elseif key == "AutoThrow" then
		if on then
			local monetization = registry.MonetizationService
			if not (monetization and monetization.HasPass(player, "AutoThrow")) then
				local notify = registry.NotifyService
				if notify then
					notify.Toast(player, "Auto Throw needs the Auto Throw pass!", "Error")
				end
				return
			end
		end
		DataService.Update(player, function(p)
			p.Settings.AutoThrow = on
			return true
		end)
	end
end

local function onSetting(player: Player, key: any, value: any)
	if type(key) ~= "string" or not PREFERENCES[key] or not Validate.Boolean(value) then
		return
	end
	DataService.Update(player, function(p)
		(p.Settings :: any)[key] = value
		return true
	end)
end

function SettingsService.Init(reg: { [string]: any })
	registry = reg
end

function SettingsService.Start()
	Guard.OnEvent(Remotes.Event("RequestToggle"), 4, 6, onToggle)
	Guard.OnEvent(Remotes.Event("RequestSetting"), 4, 8, onSetting)
end

return SettingsService
