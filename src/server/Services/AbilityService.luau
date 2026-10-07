--!strict
-- Registry of server ability modules (Battle/Abilities/<AbilityId>). The battle World resolves
-- abilities through here, so new abilities are picked up without touching the match loop.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BallDefinitions = require(Shared.Definitions.BallDefinitions)

local Server = script.Parent.Parent
local Types = require(Server.Battle.Types)

local AbilityService = {}

local registry: { [string]: Types.Ability } = {}

function AbilityService.Init()
	for _, module in Server.Battle.Abilities:GetChildren() do
		if module:IsA("ModuleScript") then
			local ok, ability = pcall(require, module)
			if ok and type(ability) == "table" then
				registry[module.Name] = ability :: Types.Ability
			else
				warn(string.format("[AbilityService] failed to load ability %s: %s", module.Name, tostring(ability)))
			end
		end
	end
	for _, def in BallDefinitions.All() do
		if def.AbilityId and registry[def.AbilityId] == nil then
			warn(string.format("[AbilityService] %s references missing ability %s", def.Id, def.AbilityId))
		end
	end
end

function AbilityService.Get(id: string): Types.Ability?
	return registry[id]
end

return AbilityService
