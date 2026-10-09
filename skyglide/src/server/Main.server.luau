--!strict
-- Server bootstrap: creates remotes, then initialises and starts every service in order.
-- Services expose optional Init(registry) (wire-up, no yielding except map building) and Start().
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)

Remotes.Init()

local Services = script.Parent.Services

local ORDER = {
	"DataService",
	"NotifyService",
	"MonetizationService",
	"EventService",
	"StatService",
	"TutorialService",
	"MapService",
	"CharacterService",
	"WorldService",
	"SettingsService",
	"TrainingService",
	"FlightService",
	"ShopService",
	"PetService",
	"RebirthService",
	"RewardService",
	"LeaderboardService",
	"AdminService",
}

local registry: { [string]: any } = {}
for _, name in ORDER do
	registry[name] = (require :: any)(Services:WaitForChild(name))
end

for _, name in ORDER do
	local service = registry[name]
	if type(service.Init) == "function" then
		local ok, err = pcall(service.Init, registry)
		if not ok then
			warn(string.format("[Main] %s.Init failed: %s", name, tostring(err)))
		end
	end
end

for _, name in ORDER do
	local service = registry[name]
	if type(service.Start) == "function" then
		task.spawn(function()
			local ok, err = pcall(service.Start)
			if not ok then
				warn(string.format("[Main] %s.Start failed: %s", name, tostring(err)))
			end
		end)
	end
end

print("[Sky Glide] server ready")
