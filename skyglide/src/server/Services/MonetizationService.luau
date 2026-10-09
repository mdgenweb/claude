--!strict
-- Game passes, developer products and the limited relic stock.
--
-- * Pass ownership is checked with UserOwnsGamePassAsync on join and updated on purchase.
-- * Products are granted exactly once per receipt (profile receipt log) and only confirmed to
--   Roblox after the profile saved successfully (ProcessReceipt contract).
-- * Ids left at 0 in Config/Monetization are "not configured": Studio grants them for free so
--   every flow can be tested; live servers refuse them (the client shows them as unavailable).
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monetization = require(Shared.Config.Monetization)
local Relics = require(Shared.Definitions.Relics)
local Worlds = require(Shared.Definitions.Worlds)
local Boosts = require(Shared.Definitions.Boosts)
local Economy = require(Shared.Config.Economy)
local Remotes = require(Shared.Net.Remotes)
local Format = require(Shared.Util.Format)

local Server = script.Parent.Parent
local Guard = require(Server.Util.Guard)
local DataService = require(script.Parent.DataService)

local MonetizationService = {}

local IS_STUDIO = RunService:IsStudio()

local registry: { [string]: any } = {}
local owned: { [Player]: { [string]: boolean } } = {}
local productById: { [number]: Monetization.Product } = {}
local passById: { [number]: Monetization.Pass } = {}

-- Relic stock (global). sold[id] = units sold across all servers (cached, refreshed periodically).
local relicSold: { [string]: number } = {}
local globalStore: any = nil
local mockGlobal: { [string]: number } = {}

local serverInfo: RemoteEvent

local function bumpGlobal(key: string, delta: number): number?
	if globalStore then
		local ok, result = pcall(function()
			return globalStore:UpdateAsync(key, function(old: any)
				return (if type(old) == "number" then old else 0) + delta
			end)
		end)
		if ok and type(result) == "number" then
			return result
		end
		warn("[Monetization] global counter update failed: " .. tostring(result))
		return nil
	end
	mockGlobal[key] = (mockGlobal[key] or 0) + delta
	return mockGlobal[key]
end

local function readGlobal(key: string): number?
	if globalStore then
		local ok, result = pcall(function()
			return globalStore:GetAsync(key)
		end)
		if ok then
			return if type(result) == "number" then result else 0
		end
		return nil
	end
	return mockGlobal[key] or 0
end

local function broadcastRelics(target: Player?)
	local payload = { Kind = "Relics", Relics = {} :: { [string]: any } }
	for _, relic in Relics.List do
		payload.Relics[relic.Id] = { Sold = relicSold[relic.Id] or 0, Stock = relic.Stock }
	end
	if target then
		serverInfo:FireClient(target, payload)
	else
		serverInfo:FireAllClients(payload)
	end
end

local function refreshRelicStock()
	for _, relic in Relics.List do
		local v = readGlobal("RelicSold_" .. relic.Id)
		if v then
			relicSold[relic.Id] = v
		end
	end
	broadcastRelics(nil)
end

function MonetizationService.RelicRemaining(id: string): number
	local relic = Relics.Get(id)
	if not relic then
		return 0
	end
	return math.max(0, relic.Stock - (relicSold[id] or 0))
end

-- Pass ownership map for multipliers and feature gates.
function MonetizationService.Passes(player: Player): { [string]: boolean }
	local out = table.clone(owned[player] or {})
	if IS_STUDIO then
		local profile = DataService.Get(player)
		if profile then
			for key in profile.TestPasses do
				out[key] = true
			end
		end
	end
	return out
end

function MonetizationService.HasPass(player: Player, key: string): boolean
	return MonetizationService.Passes(player)[key] == true
end

local function onPassGranted(player: Player, pass: Monetization.Pass)
	local notify = registry.NotifyService
	if notify then
		notify.Toast(player, pass.Name .. " unlocked!", "Success")
	end
	DataService.MarkChanged(player)
	local character = registry.CharacterService
	if character then
		character.Refresh(player)
	end
end

local function grantProduct(player: Player, product: Monetization.Product, robux: number): boolean
	local profile = DataService.Get(player)
	if not profile then
		return false
	end
	local notify = registry.NotifyService
	if product.Kind == "Skill" then
		local world = Worlds.Get(profile.World)
		local amount = (product.Amount or 0) * (if world then world.SkillPackScale else 1)
		registry.StatService.AddSkill(player, amount, "Product")
		if notify then
			notify.Toast(player, "+" .. Format.Short(amount) .. " Skill!", "Success")
		end
	elseif product.Kind == "StarterPack" then
		local pack = Monetization.StarterPack
		DataService.Update(player, function(p)
			p.Flags.StarterPack = true
			for id, n in pack.Potions do
				p.Potions[id] = math.min(Economy.Limits.MaxPotions, (p.Potions[id] or 0) + n)
			end
			return true
		end)
		registry.StatService.AddWins(player, pack.Wins, "Product")
		registry.PetService.GivePet(player, pack.Pet, "Starter Pack")
	elseif product.Kind == "Relic" then
		local relicId = product.Ref or ""
		local relic = Relics.Get(relicId)
		if not relic then
			return false
		end
		local isNew = not profile.Relics[relicId]
		DataService.Update(player, function(p)
			p.Relics[relicId] = true
			p.Relic = relicId
			return true
		end)
		if isNew then
			task.spawn(function()
				local sold = bumpGlobal("RelicSold_" .. relicId, 1)
				if sold then
					relicSold[relicId] = sold
					broadcastRelics(nil)
				end
			end)
		end
		if notify then
			notify.Toast(player, relic.Name .. " equipped! Always 125% better.", "Rare")
		end
		local character = registry.CharacterService
		if character then
			character.Refresh(player)
		end
	elseif product.Kind == "Egg" then
		registry.PetService.HatchFree(player, product.Ref or "", 1)
	elseif product.Kind == "Potion" then
		local id = product.Ref or ""
		if not Boosts.Exists(id) then
			return false
		end
		DataService.Update(player, function(p)
			p.Potions[id] = math.min(Economy.Limits.MaxPotions, (p.Potions[id] or 0) + (product.Amount or 1))
			return true
		end)
		if notify then
			notify.Toast(player, "Potions added to your inventory!", "Success")
		end
	else
		return false
	end
	if robux > 0 then
		DataService.Update(player, function(p)
			p.Stats.RobuxSpent += robux
			return true
		end)
	end
	return true
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local product = productById[receipt.ProductId]
	if product == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if player == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = DataService.WaitFor(player, 15)
	if profile == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if table.find(profile.Receipts, purchaseId) == nil then
		local ok = grantProduct(player, product, receipt.CurrencySpent or product.Robux)
		if not ok then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		DataService.Update(player, function(p)
			table.insert(p.Receipts, purchaseId)
			while #p.Receipts > 100 do
				table.remove(p.Receipts, 1)
			end
			return true
		end)
	end
	if not DataService.SaveNow(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function requestPurchase(player: Player, kind: any, key: any): { [string]: any }
	if type(key) ~= "string" or #key > 32 then
		return { ok = false, error = "Unknown item." }
	end
	local profile = DataService.Get(player)
	if not profile then
		return { ok = false, error = "Still loading..." }
	end
	if kind == "Pass" then
		local pass = Monetization.Pass(key)
		if not pass then
			return { ok = false, error = "Unknown pass." }
		end
		if MonetizationService.HasPass(player, key) then
			return { ok = false, error = "You already own this!" }
		end
		if pass.Id == 0 then
			if IS_STUDIO then
				DataService.Update(player, function(p)
					p.TestPasses[key] = true
					return true
				end)
				onPassGranted(player, pass)
				return { ok = true, message = "Studio test: " .. pass.Name .. " granted" }
			end
			return { ok = false, error = "This pass is not available yet." }
		end
		MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		return { ok = true, prompted = true }
	elseif kind == "Product" then
		local product = Monetization.Product(key)
		if not product then
			return { ok = false, error = "Unknown product." }
		end
		if product.Kind == "StarterPack" and profile.Flags.StarterPack then
			return { ok = false, error = "You already bought the Starter Pack!" }
		end
		if product.Kind == "Relic" then
			local relicId = product.Ref or ""
			if profile.Relics[relicId] then
				return { ok = false, error = "You already own this relic!" }
			end
			if MonetizationService.RelicRemaining(relicId) <= 0 then
				return { ok = false, error = "Sold out!" }
			end
		end
		if product.Id == 0 then
			if IS_STUDIO then
				local ok = grantProduct(player, product, 0)
				return if ok then { ok = true, message = "Studio test grant: " .. product.Name } else { ok = false, error = "Could not grant." }
			end
			return { ok = false, error = "This item is not available yet." }
		end
		MarketplaceService:PromptProductPurchase(player, product.Id)
		return { ok = true, prompted = true }
	end
	return { ok = false, error = "Unknown purchase type." }
end

local function loadOwnership(player: Player)
	local map = owned[player] or {}
	owned[player] = map
	for _, pass in Monetization.Passes do
		if pass.Id ~= 0 then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok and has then
				map[pass.Key] = true
			end
		end
	end
	DataService.MarkDirty(player)
end

function MonetizationService.Init(reg: { [string]: any })
	registry = reg
	serverInfo = Remotes.Event("ServerInfo")
	for _, product in Monetization.Products do
		if product.Id ~= 0 then
			productById[product.Id] = product
		end
	end
	for _, pass in Monetization.Passes do
		if pass.Id ~= 0 then
			passById[pass.Id] = pass
		end
	end
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore("SkyGlide_Global_v1")
	end)
	if ok and store then
		local probe = pcall(function()
			store:GetAsync("__probe")
		end)
		if probe then
			globalStore = store
		end
	end
end

function MonetizationService.Start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		local pass = passById[passId]
		if pass and purchased then
			local map = owned[player] or {}
			owned[player] = map
			map[pass.Key] = true
			onPassGranted(player, pass)
		end
	end)
	Guard.OnInvoke(Remotes.Function("RequestPurchase"), 2, 4, requestPurchase)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadOwnership, player)
		task.delay(3, broadcastRelics, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(loadOwnership, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)
	task.spawn(function()
		while true do
			refreshRelicStock()
			task.wait(60)
		end
	end)
end

return MonetizationService
