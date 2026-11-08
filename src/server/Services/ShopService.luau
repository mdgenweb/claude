--!nonstrict
-- Monetization and rewards: game passes, developer products (idempotent receipts), codes,
-- Mystery Flask spins, daily login streak, the free ingredient rack, skins and the shop.
-- Also the central place for player notifications, badges and codex milestones.

local BadgeService = game:GetService("BadgeService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Ingredients = require(Shared.Data.Ingredients)
local Potions = require(Shared.Data.Potions)
local Skins = require(Shared.Data.Skins)
local Spins = require(Shared.Data.Spins)

local Codes = require(script.Parent.Parent.Data.Codes)
local World = require(script.Parent.Parent.Systems.World)

local ShopService = {}

-- Mystery Flask prizes live in shared data so the client reel matches the server roll.
local SPIN_TABLE = Spins.List
ShopService.SpinTable = SPIN_TABLE

local function today(): number
	return math.floor(os.time() / 86400)
end

function ShopService:Init(services)
	self.S = services
	self._passes = {}
	self._lastAction = {}
end

function ShopService:Start()
	MarketplaceService.ProcessReceipt = function(receipt)
		return self:_processReceipt(receipt)
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased then
			for key, id in Config.GamePasses do
				if id == passId then
					self._passes[player] = self._passes[player] or {}
					self._passes[player][key] = true
					self:_applyPassPerks(player, key)
					self:Notify(player, "toast", { text = "Thanks for supporting the lab! 💜", kind = "reward" })
				end
			end
		end
	end)
	self.S.DataService.ProfileLoaded:Connect(function(player, data)
		task.spawn(function()
			self:_checkPasses(player)
			self:_updateRack(player, data)
			self:_checkBadges(player, data)
			self:_award(player, Config.BadgeIds.Welcome)
			local streakReady = data.streak.day ~= today()
			self:Notify(player, "welcome", { streakReady = streakReady, temporary = data._temporary == true })
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self._passes[player] = nil
		self._lastAction[player] = nil
	end)
	Net.func("Shop").OnServerInvoke = function(player, action, a, b)
		local now = os.clock()
		if now - (self._lastAction[player] or 0) < 0.15 then
			return { ok = false, reason = "Slow down!" }
		end
		self._lastAction[player] = now
		local ok, result = pcall(self._handle, self, player, action, a, b)
		if not ok then
			warn("[ShopService] action failed", action, result)
			return { ok = false, reason = "Something went wrong." }
		end
		return result
	end
	Net.event("Settings").OnServerEvent:Connect(function(player, key, value)
		self:_setting(player, key, value)
	end)
	-- Ingredient rack regrowth tick.
	task.spawn(function()
		while true do
			task.wait(20)
			for _, player in Players:GetPlayers() do
				local data = self.S.DataService:Get(player)
				if data and self:_updateRack(player, data) then
					self.S.DataService:Replicate(player, "rack")
				end
			end
		end
	end)
end

-- ─────────────────────────────── notifications & badges ───────────────────────────────

function ShopService:Notify(player: Player, kind: string, payload)
	if player and player.Parent then
		Net.event("Notify"):FireClient(player, kind, payload or {})
	end
end

function ShopService:_award(player: Player, badgeId: number)
	if not badgeId or badgeId == 0 then
		return
	end
	task.spawn(function()
		local ok, has = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, badgeId)
		if ok and not has then
			pcall(BadgeService.AwardBadge, BadgeService, player.UserId, badgeId)
		end
	end)
end

function ShopService:_checkBadges(player: Player, data)
	local discovered, total = 0, 0
	for _, potion in Potions.List do
		if #potion.recipe >= 2 then
			total += 1
			if data.discovered[potion.id] then
				discovered += 1
			end
		end
	end
	if discovered >= 1 then
		self:_award(player, Config.BadgeIds.FirstDiscovery)
	end
	if discovered >= total / 2 then
		self:_award(player, Config.BadgeIds.HalfCodex)
	end
	if discovered >= total then
		self:_award(player, Config.BadgeIds.FullCodex)
	end
	return discovered, total
end

function ShopService:OnDiscovery(player: Player, potionId: string)
	local data = self.S.DataService:Get(player)
	if not data then
		return
	end
	local discovered, total = self:_checkBadges(player, data)
	self:Notify(player, "discover", { id = potionId, count = discovered, total = total })
	if discovered == total - 1 and not data.discovered[Potions.FinalId] then
		self:Notify(
			player,
			"toast",
			{ text = "Only the Philosopher's Elixir remains... clear the Magnum Opus trial!", kind = "reward" }
		)
	end
end

function ShopService:DiscoverReaction(player: Player, reactionId: string)
	local data = self.S.DataService:Get(player)
	if not data or data.reactions[reactionId] then
		return
	end
	data.reactions[reactionId] = true
	data.stats.reactions += 1
	self.S.DataService:Replicate(player, "reactions", "stats")
	self.S.EconomyService:AddXp(player, 80)
	self:Notify(player, "reactionDiscovered", { id = reactionId })
end

function ShopService:OnAscension(player: Player)
	local data = self.S.DataService:Get(player)
	if not data then
		return
	end
	if not data.skins.ascended then
		data.skins.ascended = true
		data.title = "Grand Alchemist"
		self.S.DataService:Replicate(player, "skins", "title")
		self:_award(player, Config.BadgeIds.GrandAlchemist)
		self:Notify(player, "ascended", {})
	end
end

-- ─────────────────────────────── passes & products ───────────────────────────────

function ShopService:HasPass(player: Player, key: string): boolean
	local cache = self._passes[player]
	return cache ~= nil and cache[key] == true
end

function ShopService:_checkPasses(player: Player)
	self._passes[player] = self._passes[player] or {}
	for key, id in Config.GamePasses do
		if id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
			if ok and owns then
				self._passes[player][key] = true
				self:_applyPassPerks(player, key)
			end
		end
	end
	self:Notify(player, "passes", self._passes[player])
end

function ShopService:_applyPassPerks(player: Player, key: string)
	local data = self.S.DataService:Get(player)
	if not data then
		return
	end
	if key == "VIP" and not data.skins.gold then
		data.skins.gold = true
		self.S.DataService:Replicate(player, "skins")
	elseif key == "LabExpansion" then
		local lab = World.ownerLab[player]
		if lab then
			lab.maxGolems = Config.MaxGolemsExpanded
			self.S.LabService:BroadcastState(lab)
		end
	end
	if key == "VIP" then
		player:SetAttribute("VIP", true)
	end
	self:Notify(player, "passes", self._passes[player])
end

function ShopService:_processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = self.S.DataService:WaitFor(player, 15)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if self.S.DataService:HasReceipt(player, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local reward = Config.Products[receipt.ProductId]
	if not reward then
		warn("[ShopService] unknown product", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if reward.coins then
		data.coins += reward.coins
	end
	if reward.spins then
		data.spins += reward.spins
	end
	self.S.DataService:AddReceipt(player, purchaseId)
	-- Persist before acknowledging so a crash can never lose a paid reward.
	if not self.S.DataService:SaveNow(player) and not self.S.DataService._memoryOnly then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	self.S.DataService:Replicate(player, "coins", "spins")
	self.S.EconomyService:_syncLeaderstats(player, data)
	self:Notify(player, "toast", { text = "Purchase complete! Thank you 💜", kind = "reward" })
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ─────────────────────────────── rack & streak ───────────────────────────────

local COMMON_IDS = { "ember_root", "frost_lotus", "gale_feather", "slime_gel", "moon_dew" }

-- Regrows rack stock over real time. Returns true when stock changed.
function ShopService:_updateRack(player: Player, data): boolean
	local rack = data.rack
	local now = os.time()
	if rack.last == 0 then
		rack.last = now
		return false
	end
	local cap = Config.Economy.RackCapacity
	if rack.stock >= cap then
		rack.last = now
		return false
	end
	local grown = (now - rack.last) // Config.Economy.RackRegrowSeconds
	if grown <= 0 then
		return false
	end
	rack.stock = math.min(cap, rack.stock + grown)
	rack.last += grown * Config.Economy.RackRegrowSeconds
	local lab = World.ownerLab[player]
	if lab then
		self.S.LabService:RefreshRack(lab)
	end
	return true
end

local function grantIngredients(data, bundle: { [string]: number })
	for id, amount in bundle do
		data.ingredients[id] = (data.ingredients[id] or 0) + amount
	end
end

local function randomOfRarity(rarity: string, level: number): string?
	local pool = {}
	for _, ingredient in Ingredients.List do
		if
			ingredient.rarity == rarity
			and ingredient.price > 0
			and ingredient.unlockLevel <= math.max(level, 1) + 4
		then
			table.insert(pool, ingredient.id)
		end
	end
	if #pool == 0 then
		for _, ingredient in Ingredients.List do
			if ingredient.rarity == rarity and ingredient.price > 0 then
				table.insert(pool, ingredient.id)
			end
		end
	end
	if #pool == 0 then
		return nil
	end
	return pool[math.random(1, #pool)]
end

-- ─────────────────────────────── actions ───────────────────────────────

function ShopService:_handle(player: Player, action: any, a: any, b: any)
	local data = self.S.DataService:Get(player)
	if not data then
		return { ok = false, reason = "Loading..." }
	end
	local DS, Econ = self.S.DataService, self.S.EconomyService

	if action == "buyIngredient" then
		local ingredient = typeof(a) == "string" and Ingredients.ById[a]
		local qty = if typeof(b) == "number" then math.clamp(math.floor(b), 1, 25) else 1
		if not ingredient or ingredient.price <= 0 then
			return { ok = false, reason = "Not for sale." }
		end
		if data.level < ingredient.unlockLevel then
			return { ok = false, reason = ("Unlocks at level %d"):format(ingredient.unlockLevel) }
		end
		local cost = ingredient.price * qty
		if not Econ:SpendCoins(player, cost) then
			return { ok = false, reason = "Not enough coins." }
		end
		data.ingredients[ingredient.id] = (data.ingredients[ingredient.id] or 0) + qty
		DS:Replicate(player, "ingredients")
		return { ok = true }
	elseif action == "buySkin" then
		local skin = typeof(a) == "string" and Skins.ById[a]
		if not skin or skin.source ~= "shop" or not skin.price then
			return { ok = false, reason = "Not for sale." }
		end
		if data.skins[skin.id] then
			return { ok = false, reason = "Already owned." }
		end
		if not Econ:SpendCoins(player, skin.price) then
			return { ok = false, reason = "Not enough coins." }
		end
		data.skins[skin.id] = true
		data.equippedSkin = skin.id
		DS:Replicate(player, "skins", "equippedSkin")
		return { ok = true }
	elseif action == "equipSkin" then
		if typeof(a) ~= "string" or not data.skins[a] or not Skins.ById[a] then
			return { ok = false, reason = "Locked." }
		end
		data.equippedSkin = a
		DS:Replicate(player, "equippedSkin")
		local lab = World.ownerLab[player]
		if lab then
			lab.lastSpawn = { kind = "golem", id = a }
		end
		return { ok = true }
	elseif action == "redeemCode" then
		if typeof(a) ~= "string" or #a > 32 then
			return { ok = false, reason = "Invalid code." }
		end
		local code = a:upper():gsub("%s", "")
		local reward = Codes[code]
		if not reward or (reward.expires and os.time() > reward.expires) then
			return { ok = false, reason = "That code doesn't exist (or expired)." }
		end
		if data.codes[code] then
			return { ok = false, reason = "Already redeemed!" }
		end
		data.codes[code] = os.time()
		if reward.coins then
			data.coins += reward.coins
		end
		if reward.spins then
			data.spins += reward.spins
		end
		if reward.ingredients then
			grantIngredients(data, reward.ingredients)
		end
		if reward.skin then
			data.skins[reward.skin] = true
		end
		DS:Replicate(player, "coins", "spins", "ingredients", "skins", "codes")
		Econ:_syncLeaderstats(player, data)
		return { ok = true, reward = reward }
	elseif action == "spin" then
		if data.spins <= 0 then
			return { ok = false, reason = "No Mystery Flasks left." }
		end
		data.spins -= 1
		local total = 0
		for _, entry in SPIN_TABLE do
			total += entry.weight
		end
		local roll = math.random() * total
		local index = #SPIN_TABLE
		for i, entry in SPIN_TABLE do
			roll -= entry.weight
			if roll <= 0 then
				index = i
				break
			end
		end
		local entry = SPIN_TABLE[index]
		local granted = { label = entry.label, icon = entry.icon, items = {} }
		if entry.kind == "coins" then
			data.coins += entry.amount
		elseif entry.kind == "bundle" then
			for _ = 1, 3 do
				local id = randomOfRarity(entry.rarity, data.level)
				if id then
					data.ingredients[id] = (data.ingredients[id] or 0) + entry.amount
					granted.items[id] = (granted.items[id] or 0) + entry.amount
				end
			end
		elseif entry.kind == "ingredient" then
			data.ingredients[entry.id] = (data.ingredients[entry.id] or 0) + entry.amount
			granted.items[entry.id] = entry.amount
		elseif entry.kind == "potions" then
			local pool = {}
			for id in data.discovered do
				if Potions.ById[id] and id ~= Potions.FinalId then
					table.insert(pool, id)
				end
			end
			if #pool == 0 then
				pool = { "inferno_brew", "frost_tonic", "bouncy_goo" }
			end
			for _ = 1, entry.amount do
				local id = pool[math.random(1, #pool)]
				data.potions[id] = (data.potions[id] or 0) + 1
			end
		elseif entry.kind == "skin" then
			if data.skins[entry.id] then
				data.coins += 500
				granted.duplicate = true
			else
				data.skins[entry.id] = true
			end
		end
		DS:Replicate(player, "coins", "spins", "ingredients", "potions", "skins")
		Econ:_syncLeaderstats(player, data)
		return { ok = true, index = index, prize = granted }
	elseif action == "claimDaily" then
		local day = today()
		if data.streak.day == day then
			return { ok = false, reason = "Come back tomorrow!" }
		end
		data.streak.count = if data.streak.day == day - 1 then data.streak.count + 1 else 1
		data.streak.day = day
		local reward = Config.DailyStreakRewards[(data.streak.count - 1) % #Config.DailyStreakRewards + 1]
		if reward.coins then
			data.coins += reward.coins
		end
		if reward.spins then
			data.spins += reward.spins
		end
		if reward.ingredients then
			grantIngredients(data, reward.ingredients)
		end
		DS:Replicate(player, "coins", "spins", "ingredients", "streak")
		Econ:_syncLeaderstats(player, data)
		return { ok = true, day = data.streak.count, reward = reward }
	elseif action == "claimRack" then
		local lab = World.viewLab[player]
		if lab and lab.owner ~= player then
			return { ok = false, reason = "That's " .. lab.owner.DisplayName .. "'s herb rack!" }
		end
		self:_updateRack(player, data)
		local stock = data.rack.stock
		if stock <= 0 then
			local wait = Config.Economy.RackRegrowSeconds - (os.time() - data.rack.last)
			return { ok = false, reason = ("Herbs regrow in %ds"):format(math.max(1, wait)) }
		end
		local got = {}
		for _ = 1, stock do
			local id = COMMON_IDS[math.random(1, #COMMON_IDS)]
			data.ingredients[id] = (data.ingredients[id] or 0) + 1
			got[id] = (got[id] or 0) + 1
		end
		data.rack.stock = 0
		data.rack.last = os.time()
		DS:Replicate(player, "ingredients", "rack")
		if World.ownerLab[player] then
			self.S.LabService:RefreshRack(World.ownerLab[player])
		end
		return { ok = true, items = got }
	end
	return { ok = false, reason = "Unknown action." }
end

function ShopService:_setting(player: Player, key: any, value: any)
	local data = self.S.DataService:Get(player)
	if not data or typeof(key) ~= "string" then
		return
	end
	local settings = data.settings
	if (key == "sfx" or key == "music" or key == "shake") and typeof(value) == "number" then
		settings[key] = math.clamp(value, 0, 1)
	elseif key == "quality" and (value == "high" or value == "low") then
		settings.quality = value
	elseif key == "tutorial" and typeof(value) == "number" then
		settings.tutorial = math.clamp(math.floor(value), 0, 99)
	else
		return
	end
	self.S.DataService:Replicate(player, "settings")
end

return ShopService
