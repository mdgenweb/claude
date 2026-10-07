--!strict
-- Trading UI: pick a player -> request -> two-sided offer window -> both Ready -> short
-- confirmation countdown (cancellable). Any change resets both Ready flags and flashes an
-- anti-scam warning. All validation happens on the server (TradingService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BallDefinitions = require(Shared.Definitions.BallDefinitions)
local CosmeticDefinitions = require(Shared.Definitions.CosmeticDefinitions)
local Rarity = require(Shared.Config.Rarity)
local Remotes = require(Shared.Net.Remotes)

local Client = script.Parent.Parent.Parent
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local Button = require(Client.UI.Components.Button)
local Panel = require(Client.UI.Components.Panel)
local ItemCard = require(Client.UI.Components.ItemCard)
local Icons = require(Client.UI.Components.Icons)
local UIController = require(Client.Controllers.UIController)
local StateController = require(Client.Controllers.StateController)

local TradeScreen = {}

local panel: Panel.Panel
local pickView: Frame
local pickList: ScrollingFrame
local tradeView: Frame
local mineGrid: Frame
local theirsGrid: Frame
local theirsTitle: TextLabel
local myReadyMark: Frame
local theirReadyMark: Frame
local readyButton: Button.Button
local statusLabel: TextLabel
local warning: TextLabel
local invGrid: ScrollingFrame
local invTabs: { [string]: Button.Button } = {}
local invKind = "Ball"
local state: { [string]: any }? = nil
local countdownConn: RBXScriptConnection?

local remote = function(...: any)
	Remotes.Event("TradeRequest"):FireServer(...)
end

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function offeredCount(kind: string, id: string): number
	if state == nil then
		return 0
	end
	for _, item in state.Mine do
		if item.Kind == kind and item.Id == id then
			return item.Count
		end
	end
	return 0
end

local function renderPick()
	clear(pickList)
	local any = false
	for _, player in Players:GetPlayers() do
		if player ~= Players.LocalPlayer then
			any = true
			Button.new({ Parent = pickList, Size = UDim2.fromOffset(560, 56), Style = "Dark", Text = player.DisplayName, Font = Theme.Fonts.Body, TextSize = 28, OnClick = function()
				remote("Request", player.UserId)
			end })
		end
	end
	if not any then
		Create.Text({ Text = "No other players in this server yet.", Size = UDim2.fromOffset(560, 50), Font = Theme.Fonts.Body, TextSize = 28, Color = Theme.Colors.TextDim, Parent = pickList })
	end
end

local function renderOffer(grid: Frame, items: { { [string]: any } }, removable: boolean)
	clear(grid)
	for i, item in items do
		local card = ItemCard.new({
			Parent = grid,
			Kind = item.Kind,
			Id = item.Id,
			Size = UDim2.fromOffset(110, 110),
			Count = item.Count,
			LayoutOrder = i,
			OnClick = if removable then function()
				remote("SetItem", item.Kind, item.Id, item.Count - 1)
			end else nil,
		})
		if item.Count == 1 then
			card:SetCount(nil)
		end
	end
end

local function renderInventory()
	clear(invGrid)
	for kind, b in invTabs do
		b:SetStyle(if kind == invKind then "Orange" else "Dark")
	end
	local data = StateController.Data
	if data == nil then
		return
	end
	local bag = if invKind == "Ball" then data.Balls elseif invKind == "Explosion" then data.Explosions else data.Flyers
	local list = {}
	for id, count in bag do
		local tradable = true
		if invKind ~= "Ball" then
			local def = CosmeticDefinitions.Get(invKind, id)
			tradable = def ~= nil and def.Tradable
		else
			tradable = BallDefinitions.Get(id) ~= nil
		end
		local available = count - offeredCount(invKind, id)
		if tradable and available > 0 then
			local _, rarity = ItemCard.Info(invKind, id)
			table.insert(list, { Id = id, Count = available, Rarity = rarity })
		end
	end
	table.sort(list, function(a, b)
		return Rarity.Get(a.Rarity).Order > Rarity.Get(b.Rarity).Order
	end)
	for i, entry in list do
		ItemCard.new({
			Parent = invGrid,
			Kind = invKind,
			Id = entry.Id,
			Size = UDim2.fromOffset(110, 110),
			Count = entry.Count,
			LayoutOrder = i,
			OnClick = function()
				remote("SetItem", invKind, entry.Id, offeredCount(invKind, entry.Id) + 1)
			end,
		})
	end
end

local function renderTrade()
	local s = state
	if s == nil then
		return
	end
	theirsTitle.Text = s.Partner.Name .. "'s offer"
	renderOffer(mineGrid, s.Mine, s.Phase == "Offer")
	renderOffer(theirsGrid, s.Theirs, false)
	myReadyMark.Visible = s.MyReady
	theirReadyMark.Visible = s.TheirReady
	if s.Phase == "Confirming" then
		readyButton:SetText("Cancel")
		readyButton:SetStyle("Red")
	else
		readyButton:SetText(if s.MyReady then "Not Ready" else "Ready")
		readyButton:SetStyle(if s.MyReady then "Grey" else "Green")
	end
	if countdownConn then
		countdownConn:Disconnect()
		countdownConn = nil
	end
	if s.Phase == "Confirming" and s.ConfirmAt then
		countdownConn = RunService.Heartbeat:Connect(function()
			local left = math.max(0, (s.ConfirmAt :: number) - Workspace:GetServerTimeNow())
			statusLabel.Text = string.format("Both ready! Trading in %.1f...", left)
			statusLabel.TextColor3 = Color3.fromHex("#7CFF6B")
		end)
	else
		statusLabel.Text = if s.MyReady and not s.TheirReady then "Waiting for " .. s.Partner.Name .. " to ready up..." else "Add items, then press Ready."
		statusLabel.TextColor3 = Theme.Colors.TextDim
	end
	if s.Warning then
		warning.Text = "Warning: " .. s.Warning
		warning.Visible = true
	end
	renderInventory()
end

local function flashWarning(text: string)
	warning.Text = text
	warning.Visible = true
	warning.TextTransparency = 0
	local t = TweenService:Create(warning, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 4, true), { TextTransparency = 0.6 })
	t:Play()
end

function TradeScreen.Init()
	panel = Panel.new({
		Parent = UIController.Layer("Menus"),
		Name = "Trade",
		Title = "Trade",
		Size = Vector2.new(1160, 800),
		OnClose = function()
			if state then
				remote("Cancel")
			end
			UIController.Close("Trade")
		end,
	})
	local content = panel.Content

	-- player picker
	pickView = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = content })
	Create.Text({ Text = "Choose a player to trade with", Size = UDim2.new(1, 0, 0, 40), Font = Theme.Fonts.Body, TextSize = 34, Stroke = 1.5, Parent = pickView })
	pickList = Create("ScrollingFrame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 1, -130), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, Parent = pickView })
	Create.List(pickList, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center)
	Create.Text({ Text = "Trades are checked by the server. Both players must press Ready, and any change resets it.", Size = UDim2.new(1, 0, 0, 56), Position = UDim2.new(0, 0, 1, -60), Font = Theme.Fonts.BodySemi, TextSize = 24, Wrapped = true, Color = Theme.Colors.TextDim, Parent = pickView })

	-- trade window
	tradeView = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = content })
	local function side(x: number, title: string): (Frame, TextLabel, Frame)
		local box: Frame = Create("Frame", { BackgroundColor3 = Theme.Colors.Card, Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(548, 300), Parent = tradeView })
		Create.Stroke(box, Theme.Colors.PanelBorder, 2, 0, true)
		local label = Create.Text({ Text = title, Size = UDim2.new(1, -80, 0, 36), Position = UDim2.fromOffset(14, 6), Font = Theme.Fonts.Display, TextSize = 26, Scaled = true, XAlign = Enum.TextXAlignment.Left, Stroke = 2, Parent = box })
		local mark = Icons.Check(UDim2.fromOffset(40, 40), box)
		mark.Position = UDim2.new(1, -52, 0, 4)
		local grid: Frame = Create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 50), Size = UDim2.new(1, -28, 1, -60), Parent = box })
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.fromOffset(110, 110)
		layout.CellPadding = UDim2.fromOffset(10, 10)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		return grid, label, mark
	end
	local _myTitle: TextLabel
	mineGrid, _myTitle, myReadyMark = side(0, "Your offer")
	theirsGrid, theirsTitle, theirReadyMark = side(568, "Their offer")

	warning = Create.Text({ Text = "", Size = UDim2.new(1, 0, 0, 32), Position = UDim2.fromOffset(0, 306), Font = Theme.Fonts.Body, TextSize = 28, Color = Color3.fromHex("#FFB347"), Stroke = 1.5, Visible = false, Parent = tradeView })
	statusLabel = Create.Text({ Text = "", Size = UDim2.new(0.6, 0, 0, 30), Position = UDim2.fromOffset(0, 342), Font = Theme.Fonts.Body, TextSize = 26, XAlign = Enum.TextXAlignment.Left, Color = Theme.Colors.TextDim, Parent = tradeView })
	readyButton = Button.new({ Parent = tradeView, Size = UDim2.fromOffset(220, 58), Position = UDim2.new(1, 0, 0, 334), AnchorPoint = Vector2.new(1, 0), Style = "Green", Text = "Ready", TextSize = 32, OnClick = function()
		if state == nil then
			return
		end
		if state.Phase == "Confirming" then
			remote("Ready", false)
		else
			remote("Ready", not state.MyReady)
		end
	end })

	local tabs: Frame = Create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 400), Size = UDim2.new(1, 0, 0, 46), Parent = tradeView })
	Create.List(tabs, Enum.FillDirection.Horizontal, 10)
	for i, entry in { { "Ball", "Orbs" }, { "Explosion", "Explosions" }, { "Flyer", "Flyers" } } do
		invTabs[entry[1]] = Button.new({ Parent = tabs, Size = UDim2.fromOffset(170, 44), Style = "Dark", Text = entry[2], Font = Theme.Fonts.BodyHeavy, TextSize = 26, LayoutOrder = i, OnClick = function()
			invKind = entry[1]
			renderInventory()
		end })
	end
	Create.Text({ Text = "Click your items to offer them. Click an offered item to take it back.", Size = UDim2.fromOffset(560, 40), Position = UDim2.new(1, 0, 0, 402), AnchorPoint = Vector2.new(1, 0), Font = Theme.Fonts.BodySemi, TextSize = 22, Wrapped = true, XAlign = Enum.TextXAlignment.Right, Color = Theme.Colors.TextDim, Parent = tradeView })
	invGrid = Create("ScrollingFrame", { BackgroundColor3 = Theme.Colors.Card, BackgroundTransparency = 0.3, Position = UDim2.fromOffset(0, 456), Size = UDim2.new(1, 0, 1, -456), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, Parent = tradeView })
	Create.Padding(invGrid, 10)
	local invLayout = Instance.new("UIGridLayout")
	invLayout.CellSize = UDim2.fromOffset(110, 110)
	invLayout.CellPadding = UDim2.fromOffset(10, 10)
	invLayout.SortOrder = Enum.SortOrder.LayoutOrder
	invLayout.Parent = invGrid

	Remotes.Event("TradeState").OnClientEvent:Connect(function(payload)
		if payload.Type == "State" then
			state = payload
			pickView.Visible = false
			tradeView.Visible = true
			if not panel.Visible then
				UIController.Open("Trade")
			end
			renderTrade()
		elseif payload.Type == "Changed" then
			flashWarning("Careful! The other player changed their offer. Check it again.")
		elseif payload.Type == "Closed" then
			state = nil
			if countdownConn then
				countdownConn:Disconnect()
				countdownConn = nil
			end
			if payload.Reason ~= "Completed" then
				UIController.Toast("Trade " .. string.lower(payload.Reason or "closed") .. ".", "Info")
			end
			UIController.Close("Trade")
		end
	end)
	StateController.DataChanged:Connect(function()
		if state and panel.Visible then
			renderInventory()
		end
	end)

	UIController.Register("Trade", {
		Open = function()
			if state then
				pickView.Visible = false
				tradeView.Visible = true
				renderTrade()
			else
				warning.Visible = false
				pickView.Visible = true
				tradeView.Visible = false
				renderPick()
			end
			panel:Open()
		end,
		Close = function()
			panel:Close()
		end,
		IsOpen = function()
			return panel.Visible
		end,
	})
end

return TradeScreen
