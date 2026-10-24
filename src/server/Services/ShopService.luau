-- Seven exact offers: five passes (Lime Paint, Worker Starter Pack, Double Scrap,
-- Auto Farm, Foundry VIP) and two repeatable products (Scrap Boost, 600 Scrap).
-- Pass perks are re-applied every join; product receipts are granted once per PurchaseId
-- and saved before the purchase is confirmed. Boost time only ticks during salvage play.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Layout = require(Shared.Layout)

local DataService = require(script.Parent.DataService)
local StateService = require(script.Parent.StateService)
local LaneService = require(script.Parent.LaneService)
local Analytics = require(script.Parent.Analytics)

local ShopService = {}

local offersByKey: { [string]: Config.Offer } = {}
local passByid: { [number]: Config.Offer } = {}
local productById: { [number]: Config.Offer } = {}
for _, offer in Config.Offers do
	offersByKey[offer.Key] = offer
	if offer.Id ~= 0 then
		if offer.Kind == "Pass" then
			passByid[offer.Id] = offer
		else
			productById[offer.Id] = offer
		end
	end
end

local function studioFree(offer: Config.Offer): boolean
	return offer.Id == 0 and Config.StudioTestPurchases and RunService:IsStudio()
end

-- Perks that follow from owning a pass. Safe to call repeatedly.
local function applyPassPerks(player: Player)
	local session = StateService.get(player)
	if not session then
		return
	end
	local data = session.Data
	local passes = session.Passes
	if passes.LimePaint then
		data.Finishes.Lime = true
	end
	if passes.FoundryVIP then
		data.Finishes.Foundry = true
	end
	if passes.WorkerStarter then
		data.Finishes.Worker = true
		if not data.StarterGranted then
			-- The 250 Scrap is granted exactly once, across reconnects (saved flag).
			data.StarterGranted = true
			StateService.addScrap(player, Config.StarterPackScrap, "Purchase")
			Analytics.economy(
				player,
				true,
				Config.StarterPackScrap,
				data.Scrap,
				Enum.AnalyticsEconomyTransactionType.IAP,
				"WorkerStarter"
			)
		end
	end
	if session.Lane then
		LaneService.refreshSign(session.Lane)
	end
	StateService.LookChanged:Fire(player, session)
	StateService.push(player)
end

local function grantPass(player: Player, offer: Config.Offer, announce: boolean)
	local session = StateService.get(player)
	if not session then
		return
	end
	session.Passes[offer.Key] = true
	applyPassPerks(player)
	if announce then
		StateService.notify(player, "Purchase", offer.Name .. "!", offer.Benefit)
	end
end

local function grantProduct(player: Player, offer: Config.Offer)
	local session = StateService.get(player)
	if not session then
		return
	end
	local data = session.Data
	if offer.Key == "ScrapBoost" then
		data.BoostCharges += 1
		StateService.notify(player, "Purchase", "Scrap Boost stored!", "Tap BOOST to start 10 minutes of 2x Scrap.")
	elseif offer.Key == "Scrap600" then
		-- Purchased Scrap is never multiplied.
		StateService.addScrap(player, Config.ScrapPackAmount, "Purchase")
		Analytics.economy(
			player,
			true,
			Config.ScrapPackAmount,
			data.Scrap,
			Enum.AnalyticsEconomyTransactionType.IAP,
			"Scrap600"
		)
		StateService.notify(player, "Purchase", "+600 Scrap", "Thanks for supporting the game!")
	end
	StateService.push(player)
end

local function checkOwnedPasses(player: Player)
	for _, offer in Config.Offers do
		if offer.Kind == "Pass" and offer.Id ~= 0 then
			for _ = 1, 3 do
				local ok, owns = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, offer.Id)
				end)
				if ok then
					if owns then
						local session = StateService.get(player)
						if session then
							session.Passes[offer.Key] = true
						end
					end
					break
				end
				task.wait(1)
			end
		end
	end
	applyPassPerks(player)
end

-- Called from the client's BUY buttons.
function ShopService.buy(player: Player, key: string): (boolean, string?)
	local offer = offersByKey[key]
	local session = StateService.get(player)
	if not offer or not session then
		return false
	end
	if offer.Kind == "Pass" and session.Passes[key] then
		return false, "You already own " .. offer.Name
	end
	if studioFree(offer) then
		-- Studio test mode: grant directly so every flow can be played without real IDs.
		if offer.Kind == "Pass" then
			grantPass(player, offer, true)
		else
			grantProduct(player, offer)
		end
		return true, "Studio test purchase"
	end
	if offer.Id == 0 then
		return false, "This offer isn't set up yet"
	end
	if offer.Kind == "Pass" then
		MarketplaceService:PromptGamePassPurchase(player, offer.Id)
	else
		MarketplaceService:PromptProductPurchase(player, offer.Id)
	end
	return true
end

function ShopService.activateBoost(player: Player): (boolean, string?)
	local session = StateService.get(player)
	if not session then
		return false
	end
	local data = session.Data
	if data.BoostCharges <= 0 then
		return false, "No boost charges. Get one in the Shop!"
	end
	data.BoostCharges -= 1
	-- Each activation adds ten minutes; it extends duration, never strength.
	data.BoostRemaining += Config.Boost.SecondsPerCharge
	StateService.notify(player, "Boost", "2x SCRAP!", "Boost time: " .. Economy.formatTime(data.BoostRemaining))
	StateService.push(player)
	return true
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local offer = productById[receipt.ProductId]
	if not offer then
		warn("[ShopService] Unknown product " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- Need a live session (not just data that is still being released), or the grant
	-- below would do nothing while the receipt is recorded as used.
	local session = StateService.get(player)
	local data = DataService.get(player)
	if not session or not data or session.Data ~= data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if not DataService.hasReceipt(data, purchaseId) then
		DataService.addReceipt(data, purchaseId)
		grantProduct(player, offer)
	end
	-- Only confirm once the grant (and the receipt id) is safely saved.
	if DataService.usingMemory() or DataService.save(player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function ShopService.init()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local offer = passByid[passId]
		if purchased and offer then
			grantPass(player, offer, true)
		end
	end)
	StateService.Started:Connect(checkOwnedPasses)

	-- Boost clock: only counts down while the player is out salvaging in the yards
	-- and not sitting in a blocking menu. Offline time never counts.
	task.spawn(function()
		local last = os.clock()
		local flushAt = os.clock() + 60
		while true do
			task.wait(1)
			local now = os.clock()
			local dt = now - last
			last = now
			for player, session in StateService.all() do
				local data = session.Data
				data.Stats.PlaySeconds += dt
				local ticking = false
				if data.BoostRemaining > 0 then
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
					local humanoid = character and character:FindFirstChildOfClass("Humanoid")
					ticking = root ~= nil
						and humanoid ~= nil
						and humanoid.Health > 0
						and not session.InMenu
						and Layout.isInYard(root.Position)
					if ticking then
						data.BoostRemaining = math.max(0, data.BoostRemaining - dt)
						if data.BoostRemaining == 0 then
							ticking = false
							StateService.notify(
								player,
								"Boost",
								"Boost finished",
								if data.BoostCharges > 0 then "You have more charges ready." else ""
							)
						end
					end
				end
				-- The client counts down locally while ticking; push only when the state flips.
				if ticking ~= session.BoostTicking then
					session.BoostTicking = ticking
					StateService.push(player)
				end
			end
			if now >= flushAt then
				flushAt = now + 60
				Analytics.flush(function(player)
					local s = StateService.get(player)
					return s and s.Data.Scrap
				end)
			end
		end
	end)
end

return ShopService
