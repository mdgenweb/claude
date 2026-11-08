--!nonstrict
-- Server bootstrap: creates remotes, then initialises and starts every service in order.
-- Services receive a shared table of all services in Init so they can call each other at runtime
-- without circular requires.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
Net.setup()

local ORDER = {
	"DataService",
	"EconomyService",
	"ShopService",
	"LabService",
	"GolemService",
	"PropService",
	"GrabService",
	"EffectsService",
	"PotionService",
	"HazardService",
	"ChallengeService",
	"TrialService",
	"CursorService",
}

local servicesFolder = script.Parent:WaitForChild("Services")
local services = {}
for _, name in ORDER do
	services[name] = require(servicesFolder:WaitForChild(name))
end

for _, name in ORDER do
	local service = services[name]
	if service.Init then
		service:Init(services)
	end
end

for _, name in ORDER do
	local service = services[name]
	if service.Start then
		local ok, err = pcall(service.Start, service)
		if not ok then
			warn(("[Main] %s failed to start: %s"):format(name, tostring(err)))
		end
	end
end

-- Only now start loading players, so every service is subscribed to ProfileLoaded.
services.DataService:BeginPlayers()

print(("[Flask Fiasco] server ready with %d services"):format(#ORDER))
