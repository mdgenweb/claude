--[[
	SummonService
	The Gumball Machine. Validates, charges, rolls (SummonLogic), applies auto-delete and pity.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Banners = require(Shared.Config.Banners)
local Units = require(Shared.Config.Units)
local SummonLogic = require(Shared.Logic.SummonLogic)

local SummonService = {}

local registry
local rng = Random.new()

local NEVER_DELETE = { Mythic = true, Secret = true }

local function pityFor(profile, bannerId: string)
	local pity = profile.pity[bannerId]
	if not pity then
		pity = { legendary = 0, mythic = 0 }
		profile.pity[bannerId] = pity
	end
	return pity
end

function SummonService.summon(player: Player, profile, bannerId: any, count: any)
	local banner = Banners.byId[bannerId]
	if not banner then
		return false, "That banner doesn't exist."
	end
	local now = os.time()
	if not SummonLogic.isActive(banner, now) then
		return false, "That banner has ended."
	end
	if count ~= 1 and count ~= 10 then
		return false, "Bad summon count."
	end
	if registry.MatchService.isInMatch(player) then
		return false, "Finish your match first!"
	end

	local InventoryService = registry.InventoryService
	-- Reserve space only for pulls that could be kept (auto-delete can only free space, never needs it).
	if InventoryService.freeSlots(player, profile) < count then
		return false, "Your backpack is full! Release units or get the Big Backpack."
	end

	local ShopService = registry.ShopService
	local vip = ShopService.hasPass(player, "VIP")
	local lucky = ShopService.hasPass(player, "LuckySummons")
	local cost = SummonLogic.cost(count, vip)
	local ok, err = registry.EconomyService.spend(player, profile, { Gumballs = cost }, true)
	if not ok then
		return false, err
	end

	local pity = pityFor(profile, banner.id)
	local results = {}
	local refund = 0
	local best = "Rare"
	for _ = 1, count do
		local result, newPity = SummonLogic.roll(banner, pity, rng, { lucky = lucky, now = now })
		pity.legendary, pity.mythic = newPity.legendary, newPity.mythic

		local unit = Units.get(result.unitId)
		local alreadyOwned = profile.discovered[result.unitId] == true
		local entry = {
			unitId = result.unitId,
			rarity = result.rarity,
			shiny = result.shiny,
			pityHit = result.pityHit,
			new = not alreadyOwned,
		}
		if
			alreadyOwned
			and not NEVER_DELETE[unit.rarity]
			and not result.shiny
			and profile.autoDelete[unit.rarity] == true
		then
			entry.deleted = true
			refund += GameConfig.Summon.AutoDeleteRefund[unit.rarity] or 0
		else
			local instance = InventoryService.addUnit(player, profile, result.unitId, { shiny = result.shiny, force = true })
			if instance then
				entry.uid = instance.uid
				entry.grades = instance.grades
			end
		end
		if SummonLogic.RARITY_RANK[result.rarity] > SummonLogic.RARITY_RANK[best] then
			best = result.rarity
		end
		table.insert(results, entry)
	end

	if refund > 0 then
		registry.EconomyService.grant(player, profile, { Gumballs = refund })
	end
	registry.ProgressionService.track(player, profile, "Summons", count)

	if SummonLogic.RARITY_RANK[best] >= SummonLogic.RARITY_RANK.Mythic then
		local first
		for _, entry in results do
			if entry.rarity == best then
				first = entry
				break
			end
		end
		registry.NetService.notifyAll(
			string.format("%s summoned %s %s!", player.DisplayName, best, Units.get(first.unitId).name),
			"broadcast"
		)
	end

	return true, {
		results = results,
		best = best,
		refund = refund,
		pity = { legendary = pity.legendary, mythic = pity.mythic },
		cost = cost,
	}
end

function SummonService.init(services)
	registry = services
end

function SummonService.start()
	local NetService = registry.NetService

	NetService.handle("Summon", function(player, payload, profile)
		return SummonService.summon(player, profile, payload.bannerId, payload.count)
	end, { rate = 2, burst = 3 })

	NetService.handle("SetAutoDelete", function(_player, payload, profile)
		local rarity = payload.rarity
		if profile.autoDelete[rarity] == nil then
			return false, "That rarity can't be auto-deleted."
		end
		profile.autoDelete[rarity] = payload.enabled == true
		return true, profile.autoDelete
	end, { rate = 6 })

	NetService.addViewDecorator(function(player, _profile, view)
		view.luckySummons = registry.ShopService.hasPass(player, "LuckySummons")
	end)
end

return SummonService
