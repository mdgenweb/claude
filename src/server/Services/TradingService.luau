--!strict
-- Secure two-party trading (CONFIRMED feature: items are marked "Tradable").
--
-- Flow: Request -> Accept -> both edit offers -> both Ready -> short Confirming countdown ->
-- atomic exchange. Any change to either offer clears both Ready flags. Ownership is checked
-- when items are offered AND again at execution, inside one non-yielding block, against the
-- session-locked profiles held by this server (so items cannot be duplicated).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local Validate = require(Shared.Util.Validate)

local Server = script.Parent.Parent
local Guard = require(Server.Util.Guard)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local MatchService = require(script.Parent.MatchService)

local TradingService = {}

local CONFIRM_SECONDS = 4
local REQUEST_TIMEOUT = 20
local MAX_ENTRIES = 12

type Offer = { [string]: number } -- "Kind:Id" -> count
type Side = { Player: Player, Offer: Offer, Ready: boolean }
type Trade = {
	Id: string,
	A: Side,
	B: Side,
	Phase: "Offer" | "Confirming" | "Done",
	ConfirmAt: number?,
	Token: number,
}
type Request = { From: Player, To: Player, Expires: number }

local tradeOf: { [Player]: Trade } = {}
local requests: { [string]: Request } = {}
local queueService: any

local stateRemote: RemoteEvent
local notifyRemote: RemoteEvent

local function notify(player: Player, text: string, kind: string?)
	if player.Parent then
		notifyRemote:FireClient(player, { Text = text, Kind = kind or "Error" })
	end
end

function TradingService.IsTrading(player: Player): boolean
	return tradeOf[player] ~= nil
end

local function sides(trade: Trade, player: Player): (Side, Side)
	if trade.A.Player == player then
		return trade.A, trade.B
	end
	return trade.B, trade.A
end

local function offerList(offer: Offer): { { Kind: string, Id: string, Count: number } }
	local list = {}
	for key, count in offer do
		local kind, id = string.match(key, "^(%a+):(.+)$")
		if kind and id then
			table.insert(list, { Kind = kind, Id = id, Count = count })
		end
	end
	table.sort(list, function(a, b)
		return a.Kind .. a.Id < b.Kind .. b.Id
	end)
	return list
end

local function push(trade: Trade, warning: string?)
	for _, side in { trade.A, trade.B } do
		local mine, theirs = sides(trade, side.Player)
		if side.Player.Parent then
			stateRemote:FireClient(side.Player, {
				Type = "State",
				TradeId = trade.Id,
				Partner = { UserId = theirs.Player.UserId, Name = theirs.Player.DisplayName },
				Mine = offerList(mine.Offer),
				Theirs = offerList(theirs.Offer),
				MyReady = mine.Ready,
				TheirReady = theirs.Ready,
				Phase = trade.Phase,
				ConfirmAt = trade.ConfirmAt,
				Warning = warning,
			})
		end
	end
end

local function close(trade: Trade, reason: string)
	if trade.Phase == "Done" then
		return
	end
	trade.Phase = "Done"
	trade.Token += 1
	for _, side in { trade.A, trade.B } do
		if tradeOf[side.Player] == trade then
			tradeOf[side.Player] = nil
		end
		if side.Player.Parent then
			stateRemote:FireClient(side.Player, { Type = "Closed", Reason = reason })
		end
	end
end

local function eligible(player: Player): string?
	if DataService.Get(player) == nil then
		return "still loading"
	end
	if MatchService.InMatch(player) then
		return "in a battle"
	end
	if queueService and queueService.IsQueued(player) then
		return "waiting on a battle pad"
	end
	if tradeOf[player] then
		return "already trading"
	end
	return nil
end

local function resetReady(trade: Trade)
	trade.A.Ready = false
	trade.B.Ready = false
	trade.Phase = "Offer"
	trade.ConfirmAt = nil
	trade.Token += 1
end

-- Validates and performs the swap atomically. Returns error text or nil.
local function execute(trade: Trade): string?
	local a, b = trade.A.Player, trade.B.Player
	local pa, pb = DataService.Get(a), DataService.Get(b)
	if pa == nil or pb == nil then
		return "A player's data is unavailable."
	end
	-- verify (no yields from here until the mutation is complete)
	local function verify(side: Side, profile: DataService.Profile): string?
		for _, item in offerList(side.Offer) do
			local bag = EconomyService.BagFor(profile, item.Kind)
			if bag == nil or not EconomyService.IsTradable(item.Kind, item.Id) or (bag[item.Id] or 0) < item.Count then
				return side.Player.DisplayName .. " no longer has everything they offered."
			end
		end
		return nil
	end
	local problem = verify(trade.A, pa) or verify(trade.B, pb)
	if problem then
		return problem
	end
	if next(trade.A.Offer) == nil and next(trade.B.Offer) == nil then
		return "The trade is empty."
	end
	-- mutate
	for _, item in offerList(trade.A.Offer) do
		EconomyService.AddToProfile(pa, item.Kind, item.Id, -item.Count)
		EconomyService.AddToProfile(pb, item.Kind, item.Id, item.Count)
	end
	for _, item in offerList(trade.B.Offer) do
		EconomyService.AddToProfile(pb, item.Kind, item.Id, -item.Count)
		EconomyService.AddToProfile(pa, item.Kind, item.Id, item.Count)
	end
	DataService.MarkChanged(a)
	DataService.MarkChanged(b)
	print(string.format("[Trade] %s <-> %s: %s | %s", a.Name, b.Name, HttpService:JSONEncode(trade.A.Offer), HttpService:JSONEncode(trade.B.Offer)))
	task.spawn(DataService.SaveNow, a)
	task.spawn(DataService.SaveNow, b)
	return nil
end

local function beginConfirm(trade: Trade)
	trade.Phase = "Confirming"
	trade.ConfirmAt = Workspace:GetServerTimeNow() + CONFIRM_SECONDS
	trade.Token += 1
	local token = trade.Token
	push(trade)
	task.delay(CONFIRM_SECONDS, function()
		if trade.Token ~= token or trade.Phase ~= "Confirming" then
			return
		end
		local err = execute(trade)
		if err then
			resetReady(trade)
			push(trade, err)
			return
		end
		close(trade, "Completed")
		notify(trade.A.Player, "Trade complete!", "Success")
		notify(trade.B.Player, "Trade complete!", "Success")
	end)
end

local function handle(player: Player, action: any, a1: any, a2: any, a3: any)
	if action == "Request" then
		if not Validate.Integer(a1, 1, 2 ^ 53) then
			return
		end
		local target = Players:GetPlayerByUserId(a1)
		if target == nil or target == player then
			return
		end
		local mine = eligible(player)
		if mine then
			notify(player, "You can't trade while " .. mine .. ".")
			return
		end
		local theirs = eligible(target)
		if theirs then
			notify(player, target.DisplayName .. " can't trade right now (" .. theirs .. ").")
			return
		end
		local id = HttpService:GenerateGUID(false)
		requests[id] = { From = player, To = target, Expires = os.clock() + REQUEST_TIMEOUT }
		stateRemote:FireClient(target, { Type = "Request", RequestId = id, FromName = player.DisplayName, FromUserId = player.UserId, Timeout = REQUEST_TIMEOUT })
		notify(player, "Trade request sent to " .. target.DisplayName, "Info")
	elseif action == "Respond" then
		if type(a1) ~= "string" then
			return
		end
		local req = requests[a1]
		requests[a1] = nil
		if req == nil or req.To ~= player or os.clock() > req.Expires or req.From.Parent == nil then
			notify(player, "That trade request expired.")
			return
		end
		if a2 ~= true then
			notify(req.From, player.DisplayName .. " declined your trade.", "Info")
			return
		end
		if eligible(player) or eligible(req.From) then
			notify(player, "Trade can't start right now.")
			return
		end
		local trade: Trade = {
			Id = HttpService:GenerateGUID(false),
			A = { Player = req.From, Offer = {}, Ready = false },
			B = { Player = player, Offer = {}, Ready = false },
			Phase = "Offer",
			ConfirmAt = nil,
			Token = 0,
		}
		tradeOf[req.From] = trade
		tradeOf[player] = trade
		push(trade)
	else
		local trade = tradeOf[player]
		if trade == nil or trade.Phase == "Done" then
			return
		end
		local me, other = sides(trade, player)
		if action == "SetItem" then
			-- a1 = kind, a2 = id, a3 = count
			if not Validate.OneOf(a1, { "Ball", "Explosion", "Flyer" }) or not Validate.Id(a2) or not Validate.Integer(a3, 0, 9999) then
				return
			end
			if not EconomyService.IsTradable(a1, a2) then
				notify(player, "That item can't be traded.")
				return
			end
			local owned = EconomyService.Count(player, a1, a2)
			local key = a1 .. ":" .. a2
			local count = math.min(a3, owned)
			local entries = 0
			for _ in me.Offer do
				entries += 1
			end
			if count > 0 and me.Offer[key] == nil and entries >= MAX_ENTRIES then
				notify(player, "Offer is full.")
				return
			end
			if count > 0 then
				me.Offer[key] = count
			else
				me.Offer[key] = nil
			end
			local wasReady = me.Ready or other.Ready
			resetReady(trade)
			push(trade, nil)
			if wasReady and other.Player.Parent then
				-- anti-scam: tell the other side the offer changed
				stateRemote:FireClient(other.Player, { Type = "Changed" })
			end
		elseif action == "Ready" then
			me.Ready = a1 == true
			if not me.Ready then
				resetReady(trade)
				push(trade)
				return
			end
			if me.Ready and other.Ready then
				beginConfirm(trade)
			else
				push(trade)
			end
		elseif action == "Cancel" then
			notify(other.Player, player.DisplayName .. " cancelled the trade.", "Info")
			close(trade, "Cancelled")
		end
	end
end

function TradingService.Init(registry: { [string]: any })
	queueService = registry.QueueService
	stateRemote = Remotes.Event("TradeState")
	notifyRemote = Remotes.Event("Notify")
end

function TradingService.Start()
	Guard.OnEvent(Remotes.Event("TradeRequest"), 6, 12, function(player: Player, action: any, a1: any, a2: any, a3: any)
		if action == "Request" and not Guard.Allow(player, "TradeRequestSend", 0.34, 2) then
			notify(player, "Please wait before sending another request.")
			return
		end
		handle(player, action, a1, a2, a3)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local trade = tradeOf[player]
		if trade then
			local _, other = sides(trade, player)
			notify(other.Player, "Trade cancelled: " .. player.DisplayName .. " left.")
			close(trade, "Disconnected")
		end
		for id, req in requests do
			if req.From == player or req.To == player then
				requests[id] = nil
			end
		end
	end)
end

return TradingService
