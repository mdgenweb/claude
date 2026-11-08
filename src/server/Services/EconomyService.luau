--!nonstrict
-- Coins, XP & levels, and the Chaos Points combo meter that turns mayhem into rewards.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Ingredients = require(Shared.Data.Ingredients)
local Maps = require(Shared.Data.Maps)
local Skins = require(Shared.Data.Skins)
local PropsData = require(Shared.Data.Props)

local E = Config.Economy
local EconomyService = {}

function EconomyService:Init(services)
	self.S = services
	self._chaos = {}
end

function EconomyService:Start()
	self.S.DataService.ProfileLoaded:Connect(function(player, data)
		self:_setupLeaderstats(player, data)
		self._chaos[player] = {
			combo = 1,
			comboChaos = 0,
			lastHit = 0,
			pending = 0,
			unsent = 0,
			minute = 0,
			minuteStart = os.clock(),
			coinRemainder = 0,
			xpRemainder = 0,
			lastSend = 0,
		}
	end)
	Players.PlayerRemoving:Connect(function(player)
		self._chaos[player] = nil
	end)
	-- Convert accumulated chaos into coins/XP once per second (keeps remote traffic low).
	task.spawn(function()
		while true do
			task.wait(1)
			for player, state in self._chaos do
				if player.Parent then
					self:_flush(player, state)
				end
			end
		end
	end)
end

function EconomyService:_setupLeaderstats(player: Player, data)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = data.level
	level.Parent = stats
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = data.coins
	coins.Parent = stats
	stats.Parent = player
end

function EconomyService:_syncLeaderstats(player: Player, data)
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		local level = stats:FindFirstChild("Level") :: IntValue?
		local coins = stats:FindFirstChild("Coins") :: IntValue?
		if level then
			level.Value = data.level
		end
		if coins then
			coins.Value = data.coins
		end
	end
end

local function multiplier(self, player: Player): number
	if self.S.ShopService and self.S.ShopService:HasPass(player, "VIP") then
		return E.VipMultiplier
	end
	return 1
end

-- `raw` skips the VIP multiplier (purchases, refunds).
function EconomyService:AddCoins(player: Player, amount: number, reason: string?, raw: boolean?)
	local data = self.S.DataService:Get(player)
	if not data or amount == 0 then
		return 0
	end
	local value = if raw or amount < 0 then amount else math.floor(amount * multiplier(self, player))
	data.coins = math.max(0, data.coins + value)
	self.S.DataService:Replicate(player, "coins")
	self:_syncLeaderstats(player, data)
	if reason and value > 0 and reason ~= "chaos" then
		Net.unreliable("FXU"):FireClient(player, "coins", { a = value, r = reason })
	end
	return value
end

function EconomyService:SpendCoins(player: Player, amount: number): boolean
	local data = self.S.DataService:Get(player)
	if not data or amount < 0 or data.coins < amount then
		return false
	end
	data.coins -= amount
	self.S.DataService:Replicate(player, "coins")
	self:_syncLeaderstats(player, data)
	return true
end

-- What a level unlocks (used for the level-up popup).
local function unlocksAt(level: number)
	local list = {}
	for _, ingredient in Ingredients.List do
		if ingredient.unlockLevel == level and ingredient.price > 0 then
			table.insert(list, { kind = "ingredient", name = ingredient.name, icon = ingredient.icon })
		end
	end
	for _, map in Maps.List do
		if map.unlockLevel == level then
			table.insert(list, { kind = "map", name = map.name, icon = map.icon })
		end
	end
	for _, skin in Skins.List do
		if skin.source == "level" and skin.level == level then
			table.insert(list, { kind = "skin", name = skin.name, icon = "🗿" })
		end
	end
	for _, prop in PropsData.List do
		if prop.unlockLevel == level and level > 1 then
			table.insert(list, { kind = "item", name = prop.name, icon = prop.icon })
		end
	end
	return list
end

function EconomyService:AddXp(player: Player, amount: number, raw: boolean?)
	local data = self.S.DataService:Get(player)
	if not data or amount <= 0 then
		return
	end
	data.xp += if raw then amount else math.floor(amount * multiplier(self, player))
	local leveled = false
	while data.level < E.MaxLevel and data.xp >= Config.xpForLevel(data.level) do
		data.xp -= Config.xpForLevel(data.level)
		data.level += 1
		leveled = true
		local bonus = data.level * E.LevelUpCoinsPerLevel
		data.coins += bonus
		if data.level % 5 == 0 then
			data.spins += 1
		end
		for _, skin in Skins.List do
			if skin.source == "level" and skin.level and data.level >= skin.level then
				data.skins[skin.id] = true
			end
		end
		self.S.ShopService:Notify(player, "levelup", {
			level = data.level,
			rank = Config.rankForLevel(data.level),
			coins = bonus,
			unlocks = unlocksAt(data.level),
		})
	end
	if data.level >= E.MaxLevel then
		data.xp = math.min(data.xp, Config.xpForLevel(data.level))
	end
	if leveled then
		self.S.DataService:Replicate(player, "xp", "level", "coins", "spins", "skins")
	else
		self.S.DataService:Replicate(player, "xp")
	end
	if leveled then
		self:_syncLeaderstats(player, data)
		self.S.ChallengeService:RefreshDaily(player)
	end
end

-- ─────────────────────────────── chaos ───────────────────────────────

function EconomyService:AddChaos(player: Player, amount: number, _lab)
	local state = self._chaos[player]
	local data = self.S.DataService:Get(player)
	if not state or not data or amount <= 0 then
		return
	end
	local now = os.clock()
	if now - state.minuteStart > 60 then
		state.minuteStart = now
		state.minute = 0
	end
	if state.minute >= E.ChaosPerMinuteCap then
		return
	end
	if now - state.lastHit > E.ComboWindow then
		state.combo = 1
		state.comboChaos = 0
	end
	state.lastHit = now
	state.comboChaos += amount
	state.combo = math.min(E.ComboMax, 1 + math.floor(state.comboChaos / E.ComboStep))
	local gained = math.min(math.floor(amount * state.combo), E.ChaosPerMinuteCap - state.minute)
	state.minute += gained
	state.pending += gained
	state.unsent += gained
	data.stats.chaos += gained
	-- Live meter update (unreliable, throttled to ~12 Hz).
	if now - state.lastSend > 0.08 then
		state.lastSend = now
		Net.unreliable("FXU"):FireClient(player, "chaos", { g = state.unsent, c = state.combo, w = E.ComboWindow })
		state.unsent = 0
	end
end

function EconomyService:_flush(player: Player, state)
	if state.unsent > 0 then
		Net.unreliable("FXU"):FireClient(player, "chaos", { g = state.unsent, c = state.combo, w = E.ComboWindow })
		state.unsent = 0
	end
	if state.pending <= 0 then
		return
	end
	local chaos = state.pending
	state.pending = 0
	local coinTotal = chaos + state.coinRemainder
	local coins = coinTotal // E.ChaosPerCoin
	state.coinRemainder = coinTotal % E.ChaosPerCoin
	local xpTotal = chaos + state.xpRemainder
	local xp = xpTotal // E.ChaosPerXp
	state.xpRemainder = xpTotal % E.ChaosPerXp
	if coins > 0 then
		self:AddCoins(player, coins, "chaos")
	end
	if xp > 0 then
		self:AddXp(player, xp)
	end
end

return EconomyService
