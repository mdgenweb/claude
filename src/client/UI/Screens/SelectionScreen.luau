--!strict
-- Orb selection each round: three random offers (CONFIRMED), reroll for gems (LIKELY), and the
-- once-per-match free collection pick (CONFIRMED). Timer, opponent status, locked-in state.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BallDefinitions = require(Shared.Definitions.BallDefinitions)
local Rarity = require(Shared.Config.Rarity)
local Remotes = require(Shared.Net.Remotes)

local Client = script.Parent.Parent.Parent
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local Button = require(Client.UI.Components.Button)
local OrbArt = require(Client.UI.Components.OrbArt)
local ItemCard = require(Client.UI.Components.ItemCard)
local Icons = require(Client.UI.Components.Icons)
local UIController = require(Client.Controllers.UIController)
local StateController = require(Client.Controllers.StateController)
local AudioController = require(Client.Controllers.AudioController)

local SelectionScreen = {}

local root: Frame
local holder: Frame
local title: TextLabel
local timerLabel: TextLabel
local cardsRow: Frame
local rerollButton: Button.Button
local collectionButton: Button.Button
local opponentLabel: TextLabel
local collectionView: Frame
local collectionGrid: ScrollingFrame
local current: { [string]: any }? = nil
local cards: { TextButton } = {}
local timerConn: RBXScriptConnection?
local lastTick = -1

local function send(action: string, arg: any)
	Remotes.Event("SelectionRequest"):FireServer(action, arg)
end

local function offerCard(index: number, defId: string, picked: boolean, isSelected: boolean): TextButton
	local def = BallDefinitions.Get(defId)
	local rarity = if def then def.Rarity else "Uncommon"
	local rColor = Theme.Rarity(rarity)
	local card: TextButton = Create("TextButton", {
		Name = "Offer" .. index,
		Size = UDim2.fromOffset(320, 440),
		BackgroundColor3 = Theme.Colors.Card,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = index,
		Selectable = true,
	})
	local stroke = Create.Stroke(card, rColor, if isSelected then 5 else 2.5, 0, true)
	if isSelected then
		stroke.Color = Color3.new(1, 1, 1)
	end
	local top: Frame = Create("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 0, 220), Parent = card })
	OrbArt.RarityBackground(top, rarity)
	local artHolder: Frame = Create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(190, 190), Parent = top })
	local art = OrbArt.Draw(artHolder, defId, 2)
	local tag: Frame = Create("Frame", { BackgroundColor3 = Theme.Colors.PanelDeep, BackgroundTransparency = 0.2, Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(130, 30), ZIndex = 10, Parent = top })
	Create.Corner(15, tag)
	Create.Text({ Text = rarity, Size = UDim2.new(1, -10, 1, -4), Position = UDim2.fromOffset(5, 2), Font = Theme.Fonts.Display, TextSize = 18, Scaled = true, Color = rColor, Stroke = 1, ZIndex = 11, Parent = tag })
	Create.Text({ Text = if def then def.DisplayName else defId, Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 228), Font = Theme.Fonts.BodyHeavy, TextSize = 36, Scaled = true, Stroke = 2, Parent = card })
	Create.Text({ Text = if def then def.Description else "", Size = UDim2.new(1, -24, 0, 112), Position = UDim2.fromOffset(12, 272), Font = Theme.Fonts.BodySemi, TextSize = 23, Wrapped = true, YAlign = Enum.TextYAlignment.Top, Color = Theme.Colors.TextDim, Parent = card })
	if def then
		local stats: Frame = Create("Frame", { BackgroundColor3 = Theme.Colors.PanelDeep, Position = UDim2.new(0, 10, 1, -48), Size = UDim2.new(1, -20, 0, 38), Parent = card })
		Create.Corner(8, stats)
		local heart = Icons.Heart(UDim2.fromOffset(26, 26), stats)
		heart.Position = UDim2.fromOffset(10, 6)
		Create.Text({ Text = tostring(def.BaseHP), Size = UDim2.fromOffset(60, 30), Position = UDim2.fromOffset(40, 4), Font = Theme.Fonts.Display, TextSize = 20, XAlign = Enum.TextXAlignment.Left, Stroke = 1.5, Parent = stats })
		Create.Text({ Text = string.format("Bump %d  ·  Size %.1f", def.ContactDamage, def.Radius * 2), Size = UDim2.fromOffset(190, 30), Position = UDim2.new(1, -10, 0, 4), AnchorPoint = Vector2.new(1, 0), Font = Theme.Fonts.Body, TextSize = 22, XAlign = Enum.TextXAlignment.Right, Color = Color3.fromHex("#9FD8FF"), Parent = stats })
	end
	if picked then
		if isSelected then
			local stamp = Create.Text({ Text = "LOCKED IN", Size = UDim2.fromOffset(260, 50), Position = UDim2.fromScale(0.5, 0.25), AnchorPoint = Vector2.new(0.5, 0.5), Font = Theme.Fonts.Display, TextSize = 36, Scaled = true, Color = Color3.fromHex("#7CFF6B"), Stroke = 3, Rotation = -8, ZIndex = 30, Parent = card })
			local s = Instance.new("UIScale")
			s.Scale = 1.8
			s.Parent = stamp
			TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		else
			Create("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), ZIndex = 25, Parent = card })
		end
	end
	local scale = Instance.new("UIScale")
	scale.Parent = card
	card.MouseEnter:Connect(function()
		if not picked then
			TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.04 }):Play()
			AudioController.Play("Hover", nil, 0.05)
		end
	end)
	card.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	card.Activated:Connect(function()
		if picked then
			return
		end
		AudioController.Play("Select")
		send("Pick", index)
	end)
	-- idle wobble of the art
	task.spawn(function()
		local t = index
		while card.Parent do
			t += RunService.Heartbeat:Wait()
			art:SetRotation(math.sin(t * 1.5) * 8)
		end
	end)
	return card
end

local function renderCollection()
	for _, child in collectionGrid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local data = StateController.Data
	if data == nil then
		return
	end
	local list = {}
	for id, count in data.Balls do
		local def = BallDefinitions.Get(id)
		if def and count > 0 then
			table.insert(list, def)
		end
	end
	table.sort(list, function(a, b)
		local ra, rb = Rarity.Get(a.Rarity).Order, Rarity.Get(b.Rarity).Order
		if ra ~= rb then
			return ra > rb
		end
		return a.DisplayName < b.DisplayName
	end)
	for i, def in list do
		ItemCard.new({ Parent = collectionGrid, Kind = "Ball", Id = def.Id, Size = UDim2.fromOffset(140, 140), LayoutOrder = i, OnClick = function()
			send("Collection", def.Id)
			collectionView.Visible = false
		end })
	end
end

local function render(payload: { [string]: any })
	for _, card in cards do
		card:Destroy()
	end
	table.clear(cards)
	for i, id in payload.Offers do
		local card = offerCard(i, id, payload.Picked, payload.Selected == id)
		card.Parent = cardsRow
		table.insert(cards, card)
	end
	-- picked from collection (not one of the offers)
	if payload.Picked and payload.Selected and not table.find(payload.Offers, payload.Selected) then
		for _, card in cards do
			card:Destroy()
		end
		table.clear(cards)
		local card = offerCard(1, payload.Selected, true, true)
		card.Parent = cardsRow
		table.insert(cards, card)
	end
	title.Text = if payload.Picked then "Waiting for opponent..." else string.format("Round %d · Choose your Orb", payload.Round or 1)
	rerollButton:SetText(string.format("Reroll  %d", payload.RerollCost))
	rerollButton:SetEnabled(not payload.Picked and (payload.RerollsLeft or 0) > 0)
	collectionButton:SetText(if (payload.FreePicksLeft or 0) > 0 then "Collection · FREE" else string.format("Collection · %d", payload.CollectionCost))
	collectionButton:SetEnabled(not payload.Picked)
end

function SelectionScreen.SetOpponentStatus(text: string)
	opponentLabel.Text = text
end

function SelectionScreen.Show(payload: { [string]: any })
	local first = current == nil or current.Round ~= payload.Round
	current = payload
	root.Visible = true
	render(payload)
	if first then
		collectionView.Visible = false
		local s = holder:FindFirstChildOfClass("UIScale") :: UIScale
		s.Scale = 0.85
		TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		AudioController.Play("Open")
	end
	if timerConn then
		timerConn:Disconnect()
	end
	timerConn = RunService.Heartbeat:Connect(function()
		local left = math.max(0, (payload.Deadline or 0) - Workspace:GetServerTimeNow())
		local whole = math.ceil(left)
		timerLabel.Text = tostring(whole)
		timerLabel.TextColor3 = if left <= 5 then Color3.fromHex("#FF5A6A") else Color3.new(1, 1, 1)
		if whole ~= lastTick and whole <= 5 and whole > 0 and not payload.Picked then
			AudioController.Play("Countdown", nil, nil, 0.5)
		end
		lastTick = whole
	end)
end

function SelectionScreen.Hide()
	if timerConn then
		timerConn:Disconnect()
		timerConn = nil
	end
	current = nil
	root.Visible = false
	collectionView.Visible = false
end

function SelectionScreen.Init()
	root = Create("Frame", { Name = "Selection", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6, Size = UDim2.fromScale(1, 1), Visible = false, Active = true, Parent = UIController.Layer("Battle") })
	holder = Create("Frame", { BackgroundColor3 = Theme.Colors.Panel, BackgroundTransparency = 0.04, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(1110, 640), Parent = root })
	Create.Stroke(holder, Theme.Colors.ModalBorder, 2, 0, true)
	Instance.new("UIScale").Parent = holder
	title = Create.Text({ Text = "Choose your Orb", Size = UDim2.new(1, -200, 0, 50), Position = UDim2.fromOffset(24, 14), Font = Theme.Fonts.Display, TextSize = 40, Scaled = true, XAlign = Enum.TextXAlignment.Left, Stroke = 2.5, Parent = holder })
	local timerPill: Frame = Create("Frame", { BackgroundColor3 = Theme.Colors.PanelDeep, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 14), Size = UDim2.fromOffset(110, 54), Parent = holder })
	Create.Corner(27, timerPill)
	Create.Stroke(timerPill, Theme.Colors.PanelBorder, 2, 0, true)
	timerLabel = Create.Text({ Text = "15", Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Font = Theme.Fonts.Display, TextSize = 36, Scaled = true, Stroke = 2, Parent = timerPill })
	cardsRow = Create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 80), Size = UDim2.new(1, -40, 0, 450), Parent = holder })
	Create.List(cardsRow, Enum.FillDirection.Horizontal, 28, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	local bottom: Frame = Create("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 24, 1, -88), Size = UDim2.new(1, -48, 0, 70), Parent = holder })
	rerollButton = Button.new({ Parent = bottom, Size = UDim2.fromOffset(250, 64), Position = UDim2.fromOffset(0, 3), Style = "Blue", Text = "Reroll 10", TextSize = 28, OnClick = function()
		send("Reroll", nil)
	end })
	local gem = Icons.Gem(UDim2.fromOffset(36, 36), rerollButton.Content)
	gem.Position = UDim2.new(1, -46, 0.5, -18)
	gem.ZIndex = 6
	collectionButton = Button.new({ Parent = bottom, Size = UDim2.fromOffset(330, 64), Position = UDim2.fromOffset(268, 3), Style = "Purple", Text = "Collection · FREE", TextSize = 26, OnClick = function()
		renderCollection()
		collectionView.Visible = true
	end })
	opponentLabel = Create.Text({ Text = "", Size = UDim2.fromOffset(420, 64), Position = UDim2.new(1, 0, 0, 3), AnchorPoint = Vector2.new(1, 0), Font = Theme.Fonts.Body, TextSize = 28, Scaled = true, XAlign = Enum.TextXAlignment.Right, Color = Theme.Colors.TextDim, Stroke = 1.5, Parent = bottom })

	collectionView = Create("Frame", { BackgroundColor3 = Theme.Colors.PanelDeep, BackgroundTransparency = 0.02, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 40, Active = true, Parent = holder })
	Create.Text({ Text = "Pick any Orb from your collection", Size = UDim2.new(1, -220, 0, 44), Position = UDim2.fromOffset(24, 16), Font = Theme.Fonts.Display, TextSize = 30, Scaled = true, XAlign = Enum.TextXAlignment.Left, Stroke = 2, ZIndex = 41, Parent = collectionView })
	Button.new({ Parent = collectionView, Size = UDim2.fromOffset(150, 52), Position = UDim2.new(1, -20, 0, 14), AnchorPoint = Vector2.new(1, 0), Style = "Blue", Text = "Back", TextSize = 26, ZIndex = 42, OnClick = function()
		collectionView.Visible = false
	end })
	collectionGrid = Create("ScrollingFrame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 80), Size = UDim2.new(1, -48, 1, -100), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, ZIndex = 41, Parent = collectionView })
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(140, 140)
	grid.CellPadding = UDim2.fromOffset(12, 12)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = collectionGrid
end

return SelectionScreen
