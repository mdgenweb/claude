--[[
	ShopService
	Game passes (ownership cache), developer products (idempotent ProcessReceipt), Gumball shop items,
	and Studio-only dev grants for products/passes whose ids are still 0.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Shop = require(Shared.Config.Shop)
local BattlePass = require(Shared.Config.BattlePass)

local ShopService = {}

local registry
local owned: { [Player]: { [string]: boolean } } = {}
local MAX_RECEIPTS = 60

local function devGrantsAllowed(): boolean
	return RunService:IsStudio() and GameConfig.Dev.GrantUnconfiguredPurchasesInStudio
end

function ShopService.hasPass(player: Player, key: string): boolean
	local cache = owned[player]
	if cache and cache[key] then
		return true
	end
	local profile = registry.DataService.get(player)
	return profile ~= nil and profile.devPasses[key] == true
end

local function refreshPasses(player: Player)
	local cache = {}
	for key, pass in Shop.GamePasses do
		if pass.id ~= 0 then
			local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
			cache[key] = ok and result == true
		end
	end
	owned[player] = cache
	registry.DataService.markDirty(player)
end

local function pruneReceipts(profile)
	local entries = {}
	for id, time in profile.receipts do
		table.insert(entries, { id = id, time = time })
	end
	if #entries <= MAX_RECEIPTS then
		return
	end
	table.sort(entries, function(a, b)
		return a.time < b.time
	end)
	for index = 1, #entries - MAX_RECEIPTS do
		profile.receipts[entries[index].id] = nil
	end
end

-- Applies a product's effect. Returns ok, message.
local function applyProduct(player: Player, profile, key: string)
	local product = Shop.Products[key]
	if not product then
		return false, "Unknown product"
	end
	if product.oneTime then
		profile.oneTime[key] = true
	end
	if product.special == "PassPremium" then
		registry.BattlePassService.grantPremium(player, profile)
		profile.oneTime["PassPremium_" .. BattlePass.seasonId] = true
	elseif product.special == "PassTier" then
		registry.BattlePassService.addTier(player, profile)
	elseif product.grant then
		registry.EconomyService.grant(player, profile, product.grant, { paid = product.paid == true })
	end
	registry.NetService.notify(player, "Thanks for your purchase! " .. product.name, "purchase")
	return true, nil
end

local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = registry.DataService.wait(player, 15)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receiptInfo.PurchaseId)
	if profile.receipts[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local key = Shop.productKeyById(receiptInfo.ProductId)
	if not key then
		warn("[ShopService] receipt for unknown product", receiptInfo.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok = applyProduct(player, profile, key)
	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	profile.receipts[purchaseId] = os.time()
	pruneReceipts(profile)
	-- Persist before acknowledging so a crash can't lose a paid grant.
	if not registry.DataService.save(player, false) then
		profile.receipts[purchaseId] = nil
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ShopService.init(services)
	registry = services
end

function ShopService.start()
	local NetService = registry.NetService

	MarketplaceService.ProcessReceipt = processReceipt

	Players.PlayerAdded:Connect(function(player)
		task.spawn(refreshPasses, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(refreshPasses, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for key, pass in Shop.GamePasses do
			if pass.id == passId then
				owned[player] = owned[player] or {}
				owned[player][key] = true
				NetService.notify(player, "You now own " .. pass.name .. "!", "purchase")
				registry.DataService.markDirty(player)
			end
		end
	end)

	NetService.addViewDecorator(function(player, profile, view)
		local passes = {}
		for key in Shop.GamePasses do
			passes[key] = ShopService.hasPass(player, key)
		end
		view.passes = passes
		view.devGrants = devGrantsAllowed()
		view.premiumOwned = profile.pass.premium == true
	end)

	NetService.handle("BuyGumballItem", function(player, payload, profile)
		local entry = Shop.gumballItem(payload.id)
		if not entry then
			return false, "Unknown item."
		end
		local ok, err = registry.EconomyService.spend(player, profile, { Gumballs = entry.cost }, false)
		if not ok then
			return false, err
		end
		return true, registry.EconomyService.grant(player, profile, entry.grant)
	end, { rate = 4 })

	-- Studio-only: simulate purchases for unconfigured ids so every flow can be tested.
	NetService.handle("DevPurchase", function(player, payload, profile)
		if not devGrantsAllowed() then
			return false, "Purchases are not configured yet."
		end
		if payload.kind == "pass" then
			local pass = Shop.GamePasses[payload.key]
			if not pass or pass.id ~= 0 then
				return false, "Use the real prompt for configured passes."
			end
			profile.devPasses[payload.key] = true
			NetService.notify(player, "[Studio] Granted pass: " .. pass.name, "purchase")
			return true, nil
		elseif payload.kind == "product" then
			local product = Shop.Products[payload.key]
			if not product or product.id ~= 0 then
				return false, "Use the real prompt for configured products."
			end
			if product.oneTime and profile.oneTime[payload.key] then
				return false, "Already purchased."
			end
			return applyProduct(player, profile, payload.key)
		end
		return false, "Bad request."
	end, { rate = 3 })
end

return ShopService
