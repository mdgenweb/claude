--[[
	Elmore Defense: server bootstrap.
	Services are plain modules with optional init(registry) and start(). init runs in order (no yielding),
	then every start runs. Services talk to each other through the registry to avoid require cycles.
]]

local LightingSetup = require(script.Parent.World.LightingSetup)
local LobbyBuilder = require(script.Parent.World.LobbyBuilder)

local Services = script.Parent.Services

local ORDER = {
	"DataService",
	"NetService",
	"ComplianceService",
	"EconomyService",
	"ShopService",
	"InventoryService",
	"ProgressionService",
	"BattlePassService",
	"SummonService",
	"RerollService",
	"EvolutionService",
	"LeaderboardService",
	"MatchService",
	"LobbyService",
	"DevService",
}

local registry = {}
for _, name in ORDER do
	registry[name] = require(Services:FindFirstChild(name))
end

for _, name in ORDER do
	local service = registry[name]
	if service.init then
		service.init(registry)
	end
end

LightingSetup.apply()
LobbyBuilder.build()

-- DataService starts last: it begins loading profiles, and every ProfileLoaded listener must exist by then.
local startOrder = table.clone(ORDER)
table.remove(startOrder, table.find(startOrder, "DataService"))
table.insert(startOrder, "DataService")

for _, name in startOrder do
	local service = registry[name]
	if service.start then
		local ok, err = pcall(service.start)
		if not ok then
			warn(string.format("[Main] %s.start failed: %s", name, tostring(err)))
		end
	end
end

print("[Elmore Defense] server ready")
