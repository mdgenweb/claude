--!strict
-- Free rewards: playtime gifts (per session), the 7-day daily track, codes, and potion use.
-- Timers are measured on the server; the client only asks to claim.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Rewards = require(Shared.Definitions.Rewards)
local Boosts = require(Shared.Definitions.Boosts)
local Pets = require(Shared.Definitions.Pets)
local Training = require(Shared.Definitions.Training)
local Zones = require(Shared.Definitions.Zones)
local Remotes = require(Shared.Net.Remotes)
local Validate = require(Shared.Util.Validate)
local Format = require(Shared.Util.Format)

local Server = script.Parent.Parent
local Guard = require(Server.Util.Guard)
local Codes = require(Server.Data.Codes)
local DataService = require(script.Parent.DataService)
local StatService = require(script.Parent.StatService)

local RewardService = {}

local registry: { [string]: any } = {}
local joinedAt: { [Player]: number } = {}
local claimed: { [Player]: { [number]: boolean } } = {}

local function today(): number
	return os.time() // 86400
end

-- Best pad multiplier this player can currently use in their world (for "Reps" rewards).
local function bestPad(player: Player): number
	local profile = DataService.Get(player)
	if not profile then
		return 1
	end
	local best = 1
	local training = registry.TrainingService
	for _, pad in Training.ForWorld(profile.World) do
		if pad.Multiplier > best and training and training.PadUnlocked(player, pad) then
			best = pad.Multiplier
		end
	end
	return best
end

local function winsScale(player: Player): number
	local profile = DataService.Get(player)
	if not profile then
		return 1
	end
	local zones = Zones.ForWorld(profile.World)
	return if zones[1] then zones[1].Wins else 1
end

-- Grants one reward entry. Returns a short human-readable description.
function RewardService.Grant(player: Player, reward: Rewards.Reward, source: string): string
	if reward.Kind == "Wins" then
		local amount = (reward.Amount or 0) * winsScale(player)
		StatService.AddWins(player, amount, source)
		return "+" .. Format.Short(amount) .. " Wins"
	elseif reward.Kind == "Skill" then
		local amount = StatService.RepsToSkill(player, reward.Reps or 0, bestPad(player))
		StatService.AddSkill(player, amount, source)
		return "+" .. Format.Short(amount) .. " Skill"
	elseif reward.Kind == "Potion" then
		local id = reward.Id or ""
		local def = Boosts.Get(id)
		if def then
			local count = reward.Count or 1
			DataService.Update(player, function(p)
				p.Potions[id] = math.min(Economy.Limits.MaxPotions, (p.Potions[id] or 0) + count)
				return true
			end)
			return string.format("%dx %s", count, def.Name)
		end
	elseif reward.Kind == "Pet" then
		local id = reward.Id or ""
		local def = Pets.Get(id)
		if def and registry.PetService then
			registry.PetService.GivePet(player, id, source)
			return def.Name
		end
	end
	return ""
end

local function claimGift(player: Player, index: any): { [string]: any }
	if not Validate.Integer(index, 1, #Rewards.Gifts) then
		return { ok = false, error = "Unknown gift." }
	end
	local start = joinedAt[player]
	if not start or not DataService.Get(player) then
		return { ok = false, error = "Still loading..." }
	end
	local gift = Rewards.Gifts[index]
	local set = claimed[player]
	if set[index] then
		return { ok = false, error = "Already claimed!" }
	end
	local remaining = gift.Minutes * 60 - (os.time() - start)
	if remaining > 0 then
		return { ok = false, error = "Ready in " .. Format.Duration(remaining) }
	end
	set[index] = true
	local text = RewardService.Grant(player, gift.Reward, "Gift")
	DataService.MarkDirty(player)
	return { ok = true, message = text }
end

local function claimDaily(player: Player): { [string]: any }
	local profile = DataService.Get(player)
	if not profile then
		return { ok = false, error = "Still loading..." }
	end
	local day = today()
	if profile.Daily.Day >= day then
		return { ok = false, error = "Come back tomorrow!" }
	end
	local streak = if profile.Daily.Day == day - 1 then profile.Daily.Streak + 1 else 1
	DataService.Update(player, function(p)
		p.Daily.Day = day
		p.Daily.Streak = streak
		return true
	end)
	local reward = Rewards.Daily[(streak - 1) % #Rewards.Daily + 1]
	local text = RewardService.Grant(player, reward, "Daily reward")
	return { ok = true, message = string.format("Day %d: %s", streak, text) }
end

local function redeemCode(player: Player, raw: any): { [string]: any }
	if not Validate.String(raw, 32) then
		return { ok = false, error = "Invalid code." }
	end
	local code = string.upper((string.gsub(raw, "%s", "")))
	local def = Codes[code]
	local profile = DataService.Get(player)
	if not profile then
		return { ok = false, error = "Still loading..." }
	end
	if not def or (def.Expires > 0 and os.time() > def.Expires) then
		return { ok = false, error = "That code is invalid or expired." }
	end
	if profile.Codes[code] then
		return { ok = false, error = "You already redeemed this code." }
	end
	DataService.Update(player, function(p)
		p.Codes[code] = true
		return true
	end)
	local parts = {}
	for _, reward in def.Rewards do
		table.insert(parts, RewardService.Grant(player, reward, "Code"))
	end
	return { ok = true, message = "Redeemed: " .. table.concat(parts, ", ") }
end

local function useBoost(player: Player, id: any): { [string]: any }
	if not Boosts.Exists(id) then
		return { ok = false, error = "Unknown potion." }
	end
	local def = Boosts.Get(id) :: Boosts.Boost
	local ok = DataService.Update(player, function(p)
		local count = p.Potions[id] or 0
		if count <= 0 then
			return false
		end
		local now = os.time()
		local current = math.max(now, p.Boosts[id] or 0)
		if current - now + def.Duration > Boosts.MaxStackSeconds then
			return false
		end
		if count > 1 then
			p.Potions[id] = count - 1
		else
			p.Potions[id] = nil :: any
		end
		p.Boosts[id] = current + def.Duration
		return true
	end)
	if not ok then
		return { ok = false, error = "You can't use that right now." }
	end
	return { ok = true, message = def.Name .. " active!" }
end

function RewardService.Init(reg: { [string]: any })
	registry = reg
	DataService.AddDecorator(function(player, view)
		local start = joinedAt[player] or os.time()
		local set: { [number]: boolean } = claimed[player] or {}
		local list = {}
		for i in set do
			table.insert(list, i)
		end
		view.Session = { Playtime = os.time() - start, GiftsClaimed = list }
		view.DailyReady = (DataService.Get(player) :: any).Daily.Day < today()
	end)
end

function RewardService.Start()
	Guard.OnInvoke(Remotes.Function("RequestClaimGift"), 2, 4, claimGift)
	Guard.OnInvoke(Remotes.Function("RequestClaimDaily"), 1, 2, claimDaily)
	Guard.OnInvoke(Remotes.Function("RequestRedeemCode"), 0.5, 3, redeemCode)
	Guard.OnInvoke(Remotes.Function("RequestUseBoost"), 2, 4, useBoost)
	local function added(player: Player)
		joinedAt[player] = os.time()
		claimed[player] = {}
	end
	Players.PlayerAdded:Connect(added)
	for _, player in Players:GetPlayers() do
		added(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local start = joinedAt[player]
		if start then
			DataService.Update(player, function(p)
				p.Stats.Playtime += os.time() - start
				return true
			end)
		end
		joinedAt[player] = nil
		claimed[player] = nil
	end)
	-- refresh client timers / expire boosts once in a while
	task.spawn(function()
		while true do
			task.wait(15)
			local now = os.time()
			for _, player in Players:GetPlayers() do
				local profile = DataService.Get(player)
				if profile then
					for id, expiry in profile.Boosts do
						if expiry <= now then
							profile.Boosts[id] = nil
						end
					end
					DataService.MarkDirty(player)
				end
			end
		end
	end)
end

return RewardService
