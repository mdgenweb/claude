--[[
	ComplianceService
	Caches PolicyService results. Players with ArePaidRandomItemsRestricted may not spend Robux-bought
	currency on random outcomes (summons, trait rolls, grade rolls); EconomyService enforces it.
]]

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local RunService = game:GetService("RunService")

local ComplianceService = {}

local restricted: { [Player]: boolean } = {}
local registry

local function fetch(player: Player)
	for _ = 1, 3 do
		local ok, info = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		if ok and info then
			restricted[player] = info.ArePaidRandomItemsRestricted == true
			if registry then
				registry.DataService.markDirty(player)
			end
			return
		end
		task.wait(2)
	end
	-- Conservative default in live servers if the policy can't be read.
	restricted[player] = not RunService:IsStudio()
end

function ComplianceService.isRestricted(player: Player): boolean
	local value = restricted[player]
	if value == nil then
		return not RunService:IsStudio()
	end
	return value
end

function ComplianceService.init(services)
	registry = services
end

function ComplianceService.start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(fetch, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(fetch, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		restricted[player] = nil
	end)
	registry.NetService.addViewDecorator(function(player, _profile, view)
		view.randomItemsRestricted = ComplianceService.isRestricted(player)
	end)
end

return ComplianceService
