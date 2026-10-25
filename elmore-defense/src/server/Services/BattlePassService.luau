--[[
	BattlePassService ("Elmore Pass")
	XP, level claims (free + premium tracks), premium unlock and tier skips. Resets when the season id changes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BattlePass = require(ReplicatedStorage.Shared.Config.BattlePass)

local BattlePassService = {}

local registry

local function ensureSeason(profile)
	if profile.pass.season ~= BattlePass.seasonId then
		profile.pass = { season = BattlePass.seasonId, xp = 0, premium = false, free = {}, prem = {} }
	end
	return profile.pass
end

function BattlePassService.level(profile): number
	local pass = ensureSeason(profile)
	return math.min(BattlePass.levels, math.floor(pass.xp / BattlePass.xpPerLevel))
end

function BattlePassService.addXp(player: Player, profile, amount: number)
	local pass = ensureSeason(profile)
	local before = BattlePassService.level(profile)
	pass.xp = math.min(pass.xp + math.max(0, math.floor(amount)), BattlePass.levels * BattlePass.xpPerLevel)
	local after = BattlePassService.level(profile)
	if after > before then
		registry.NetService.notify(player, "Elmore Pass level " .. after .. "!", "pass")
	end
	registry.DataService.markDirty(player)
end

function BattlePassService.grantPremium(player: Player, profile)
	ensureSeason(profile).premium = true
	registry.DataService.markDirty(player)
end

function BattlePassService.addTier(player: Player, profile)
	local pass = ensureSeason(profile)
	local level = BattlePassService.level(profile)
	if level >= BattlePass.levels then
		return
	end
	pass.xp = (level + 1) * BattlePass.xpPerLevel
	registry.DataService.markDirty(player)
end

local function grantReward(player: Player, profile, reward)
	if reward.kind == "Unit" then
		local instance = registry.InventoryService.addUnit(player, profile, reward.id, { shiny = reward.shiny, force = true })
		return { unit = reward.id, uid = instance and instance.uid, shiny = reward.shiny }
	end
	return registry.EconomyService.grant(player, profile, { [reward.id] = reward.amount })
end

local function claim(player: Player, profile, level: number, track: string)
	local pass = ensureSeason(profile)
	if level < 1 or level > BattlePassService.level(profile) then
		return false, "Reach that level first!"
	end
	local claimed = if track == "premium" then pass.prem else pass.free
	local rewards = if track == "premium" then BattlePass.premium else BattlePass.free
	if track == "premium" and not pass.premium then
		return false, "Unlock Premium to claim this."
	end
	local key = tostring(level)
	if claimed[key] then
		return false, "Already claimed."
	end
	local reward = rewards[level]
	if not reward then
		return false, "No reward."
	end
	claimed[key] = true
	return true, grantReward(player, profile, reward)
end

function BattlePassService.init(services)
	registry = services
end

function BattlePassService.start()
	local NetService = registry.NetService

	registry.DataService.ProfileLoaded:Connect(function(_player, profile)
		ensureSeason(profile)
	end)

	NetService.addViewDecorator(function(_player, profile, view)
		view.passLevel = BattlePassService.level(profile)
	end)

	NetService.handle("ClaimPass", function(player, payload, profile)
		local level = tonumber(payload.level)
		local track = if payload.track == "premium" then "premium" else "free"
		if not level then
			return false, "Bad level."
		end
		return claim(player, profile, math.floor(level), track)
	end, { rate = 8 })

	NetService.handle("ClaimPassAll", function(player, _payload, profile)
		local pass = ensureSeason(profile)
		local count = 0
		for level = 1, BattlePassService.level(profile) do
			if not pass.free[tostring(level)] and claim(player, profile, level, "free") then
				count += 1
			end
			if pass.premium and not pass.prem[tostring(level)] and claim(player, profile, level, "premium") then
				count += 1
			end
		end
		if count == 0 then
			return false, "Nothing to claim yet."
		end
		return true, { claimed = count }
	end, { rate = 1, burst = 2 })
end

return BattlePassService
