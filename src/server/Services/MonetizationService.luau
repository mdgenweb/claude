--!strict
-- Gem developer products. Purchases are granted exactly once per receipt (idempotent via the
-- profile's receipt log) and only confirmed to Roblox after the profile has been saved.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Lobby = require(Shared.Config.Lobby)

local DataService = require(script.Parent.DataService)

local MonetizationService = {}

local byProductId: { [number]: typeof(Economy.GemProducts[1]) } = {}
local byKey: { [string]: typeof(Economy.GemProducts[1]) } = {}

local function weekIndex(): number
	return (os.time() - Lobby.Leaderboards.WeekEpochOffset) // 604800
end

local function grantGems(profile: DataService.Profile, gems: number, robux: number)
	profile.Gems = math.min(profile.Gems + gems, Economy.Limits.MaxGems)
	profile.Stats.RobuxSpent += robux
	local week = weekIndex()
	if profile.Weekly.Week ~= week then
		profile.Weekly.Week = week
		profile.Weekly.Wins = 0
		profile.Weekly.RobuxSpent = 0
	end
	profile.Weekly.RobuxSpent += robux
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local product = byProductId[receipt.ProductId]
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
	local already = table.find(profile.Receipts, purchaseId) ~= nil
	if not already then
		DataService.Update(player, function(p)
			grantGems(p, product.Gems, receipt.CurrencySpent or product.Robux)
			table.insert(p.Receipts, purchaseId)
			while #p.Receipts > 50 do
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

-- Client asked to buy a gem pack (by key). Real products prompt Roblox's purchase dialog; packs
-- without a configured ProductId are free test grants inside Studio only.
function MonetizationService.RequestGemPack(player: Player, key: any): { [string]: any }
	local product = if type(key) == "string" then byKey[key] else nil
	if product == nil then
		return { ok = false, error = "Unknown pack." }
	end
	if product.ProductId == 0 then
		if RunService:IsStudio() then
			DataService.Update(player, function(p)
				grantGems(p, product.Gems, 0)
				return true
			end)
			return { ok = true, message = string.format("Studio test: +%d Gems", product.Gems) }
		end
		return { ok = false, error = "This pack is not available yet." }
	end
	MarketplaceService:PromptProductPurchase(player, product.ProductId)
	return { ok = true, prompted = true }
end

function MonetizationService.Init()
	for _, product in Economy.GemProducts do
		byKey[product.Key] = product
		if product.ProductId ~= 0 then
			byProductId[product.ProductId] = product
		end
	end
end

function MonetizationService.Start()
	MarketplaceService.ProcessReceipt = processReceipt
end

return MonetizationService
