--!strict
-- Store reconstructed from the reference (screenshot 1): title, currency bars, four coloured tabs
-- (Events / Orbs / Explosions / Flyers), paged crate cards with odds, prize preview strip,
-- "View All", Open 1 / Open 10 with prices, and a "Tradable" badge.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GachaDefinitions = require(Shared.Definitions.GachaDefinitions)
local Rarity = require(Shared.Config.Rarity)
local PropFactory = require(Shared.Visual.PropFactory)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Net.Remotes)

local Client = script.Parent.Parent.Parent
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local Button = require(Client.UI.Components.Button)
local Icons = require(Client.UI.Components.Icons)
local Panel = require(Client.UI.Components.Panel)
local ItemCard = require(Client.UI.Components.ItemCard)
local Viewport = require(Client.UI.Components.Viewport)
local OrbArt = require(Client.UI.Components.OrbArt)
local CosmeticModels = require(Client.VFX.CosmeticModels)
local UIController = require(Client.Controllers.UIController)
local StateController = require(Client.Controllers.StateController)

local StoreScreen = {}

local TAB_LABEL = { Events = "Events", Balls = "Orbs", Explosions = "Explosions", Flyers = "Flyers" }
local TAB_WIDTH = { Events = 125, Balls = 260, Explosions = 260, Flyers = 260 }

local panel: Panel.Panel
local pager: Frame
local subLabel: TextLabel
local coinValue: TextLabel
local gemValue: TextLabel
local prevButton: Button.Button
local nextButton: Button.Button
local viewAll: Frame
local viewAllGrid: ScrollingFrame
local viewAllTitle: TextLabel
local currentTab = "Balls"
local page = 1
local opening = false
local tabButtons: { [string]: TextButton } = {}

local function currencyBar(parent: Instance, x: number, isGem: boolean): TextLabel
	local bar: Frame = Create("Frame", {
		Name = if isGem then "GemBar" else "CoinBar",
		Position = UDim2.fromOffset(x, 18),
		Size = UDim2.fromOffset(250, 46),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = parent,
	})
	Create.Corner(4, bar)
	if isGem then
		Create.Gradient(bar, Color3.fromHex("#5BA8FF"), Color3.fromHex("#2C6FE0"), 90)
	else
		Create.Gradient(bar, Color3.fromHex("#FFC14D"), Color3.fromHex("#F08C00"), 90)
	end
	Create.Stroke(bar, Color3.fromHex("#1A1D26"), 2.5, 0, true)
	local icon = if isGem then Icons.Gem(UDim2.fromOffset(80, 80), bar) else Icons.Coin(UDim2.fromOffset(76, 76), bar)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.new(0, 0, 0.5, 0)
	icon.ZIndex = 4
	local value = Create.Text({ Text = "0", Size = UDim2.new(1, -60, 1, -8), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Font = Theme.Fonts.Display, TextSize = 34, Scaled = true, XAlign = Enum.TextXAlignment.Right, Stroke = 2.5, Parent = bar })
	if isGem then
		Button.new({ Parent = parent, Size = UDim2.fromOffset(48, 48), Position = UDim2.fromOffset(x + 262, 17), Style = "Blue", Text = "+", TextSize = 34, OnClick = function()
			UIController.Open("Gems")
		end })
	end
	return value
end

local function tabIcon(tab: string, holder: Frame)
	if tab == "Balls" then
		OrbArt.Draw(holder, "thorn")
	elseif tab == "Explosions" then
		ItemCard.ExplosionArt(holder, "confetti", 2)
	elseif tab == "Flyers" then
		Viewport.Model(holder, CosmeticModels.Flyer("saucer"), { Yaw = math.rad(-30), Pitch = math.rad(-25) })
	else
		for i = 0, 3 do
			local sq = Icons.Rect(holder, 0.32 + (i % 2) * 0.36, 0.32 + (i // 2) * 0.36, 0.3, 0.3, Color3.new(1, 1, 1), 0, 0.18, 2)
			sq.BackgroundTransparency = 0.05
		end
	end
end

local function priceButton(parent: Instance, crate: GachaDefinitions.Crate, count: number, x: number)
	local b = Button.new({
		Parent = parent,
		Size = UDim2.fromOffset(241, 68),
		Position = UDim2.new(0, x, 1, -10),
		AnchorPoint = Vector2.new(0, 1),
		Style = "Grey",
		Text = "",
		OnClick = function()
			StoreScreen.OpenCrate(crate.Id, count)
		end,
	})
	Create.Text({ Text = "Open " .. count, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 4), Font = Theme.Fonts.Body, TextSize = 28, Scaled = true, Stroke = 2, ZIndex = 4, Parent = b.Content })
	Create.Text({ Text = Format.Commas(crate.Price * count), Size = UDim2.new(0.62, 0, 0, 34), Position = UDim2.new(0.62, 0, 0, 30), AnchorPoint = Vector2.new(1, 0), Font = Theme.Fonts.Display, TextSize = 34, Scaled = true, XAlign = Enum.TextXAlignment.Right, Stroke = 2.5, ZIndex = 4, Parent = b.Content })
	local icon = Icons.Currency(crate.Currency, UDim2.fromOffset(38, 38), b.Content)
	icon.Position = UDim2.new(0.66, 0, 0, 28)
	icon.ZIndex = 5
end

local function crateCard(crate: GachaDefinitions.Crate, index: number): Frame
	local card: Frame = Create("Frame", {
		Name = crate.Id,
		BackgroundColor3 = Theme.Colors.Card,
		Size = UDim2.fromOffset(530, 535),
		LayoutOrder = index,
	})
	Create.Stroke(card, Theme.Colors.PanelBorder, 2, 0, true)
	-- header
	local cur = Icons.Currency(crate.Currency, UDim2.fromOffset(34, 34), card)
	cur.Position = UDim2.fromOffset(12, 8)
	Create.Text({ Text = crate.DisplayName, Size = UDim2.fromOffset(330, 30), Position = UDim2.fromOffset(52, 10), Font = Theme.Fonts.Display, TextSize = 22, Scaled = true, XAlign = Enum.TextXAlignment.Left, Stroke = 1.5, Parent = card })
	local swap = Icons.Swap(UDim2.fromOffset(34, 34), card)
	swap.Position = UDim2.new(1, -170, 0, 8)
	Create.Text({ Text = "Tradable", Size = UDim2.fromOffset(120, 30), Position = UDim2.new(1, -130, 0, 10), Font = Theme.Fonts.Body, TextSize = 28, Scaled = true, XAlign = Enum.TextXAlignment.Left, Color = Theme.Colors.Success, Stroke = 1.5, Parent = card })

	-- crate art
	local art: Frame = Create("Frame", { Name = "Art", Position = UDim2.fromOffset(14, 48), Size = UDim2.fromOffset(250, 195), BackgroundColor3 = Color3.new(1, 1, 1), Parent = card })
	if crate.Theme == "Gems" then
		Create.Gradient(art, Color3.fromHex("#FF4BE0"), Color3.fromHex("#9B1FD6"), 90)
		Create.Stroke(art, Color3.fromHex("#FF7BEA"), 2, 0, true)
	elseif crate.Theme == "Event" then
		Create.Gradient(art, Color3.fromHex("#FFB347"), Color3.fromHex("#B03A00"), 90)
		Create.Stroke(art, Color3.fromHex("#FFD08A"), 2, 0, true)
	else
		Create.Gradient(art, Color3.fromHex("#2A3A66"), Color3.fromHex("#131A30"), 90)
		Create.Stroke(art, Theme.Colors.PanelBorder, 2, 0, true)
	end
	local model = if crate.Art == "Machine" or crate.Art == "MachineAdvanced" then PropFactory.GachaMachine(crate.Art == "MachineAdvanced") else PropFactory.Crate(if crate.Art == "CrateFlyer" then "Flyer" elseif crate.Art == "CrateExplosion" then "Explosion" else "Event")
	Viewport.Model(art, model, { Yaw = math.rad(-25), Zoom = 0.9, Spin = 0.25 })

	-- odds / event info
	local odds: Frame = Create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(280, 70), Size = UDim2.fromOffset(236, 150), Parent = card })
	Create.List(odds, Enum.FillDirection.Vertical, 3)
	if crate.Odds then
		for i, rarityId in Rarity.Order do
			local pct = crate.Odds[rarityId]
			if pct then
				local row: Frame = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(236, 30), LayoutOrder = i, Parent = odds })
				Create.Text({ Text = rarityId .. ":", Size = UDim2.fromScale(0.6, 1), Font = Theme.Fonts.Body, TextSize = 28, Scaled = true, XAlign = Enum.TextXAlignment.Left, Color = Theme.Rarity(rarityId), Stroke = 1.5, Parent = row })
				Create.Text({ Text = string.format("%.2f%%", pct), Size = UDim2.fromScale(0.4, 1), Position = UDim2.fromScale(0.6, 0), Font = Theme.Fonts.Body, TextSize = 28, Scaled = true, XAlign = Enum.TextXAlignment.Right, Stroke = 1.5, Parent = row })
			end
		end
	elseif crate.Items then
		local total = 0
		for _, item in crate.Items do
			total += item.Weight
		end
		for i, item in crate.Items do
			local name, rarityId = ItemCard.Info(item.Kind, item.Id)
			local row: Frame = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(236, 30), LayoutOrder = i, Parent = odds })
			Create.Text({ Text = name, Size = UDim2.fromScale(0.68, 1), Font = Theme.Fonts.Body, TextSize = 24, Scaled = true, XAlign = Enum.TextXAlignment.Left, Color = Theme.Rarity(rarityId), Stroke = 1.5, Parent = row })
			Create.Text({ Text = string.format("%.2f%%", item.Weight / total * 100), Size = UDim2.fromScale(0.32, 1), Position = UDim2.fromScale(0.68, 0), Font = Theme.Fonts.Body, TextSize = 24, Scaled = true, XAlign = Enum.TextXAlignment.Right, Stroke = 1.5, Parent = row })
		end
	end

	-- prize preview
	Create.Text({ Text = "Prize Preview", Size = UDim2.fromOffset(240, 32), Position = UDim2.fromOffset(14, 254), Font = Theme.Fonts.Body, TextSize = 32, Scaled = true, XAlign = Enum.TextXAlignment.Left, Stroke = 1.5, Parent = card })
	local viewAllButton: TextButton = Create("TextButton", { BackgroundTransparency = 1, Text = "View All >", FontFace = Theme.Fonts.Body, TextSize = 26, TextColor3 = Theme.Colors.TextDim, Position = UDim2.new(1, -140, 0, 256), Size = UDim2.fromOffset(126, 30), TextXAlignment = Enum.TextXAlignment.Right, Parent = card })
	Create.Stroke(viewAllButton, Theme.Colors.Stroke, 1.5)
	viewAllButton.Activated:Connect(function()
		StoreScreen.ShowAll(crate)
	end)
	local strip: ScrollingFrame = Create("ScrollingFrame", {
		Name = "Prizes",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 290),
		Size = UDim2.new(1, -28, 0, 150),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 4,
		Parent = card,
	})
	Create.List(strip, Enum.FillDirection.Horizontal, 8)
	local pool = GachaDefinitions.Pool(crate)
	table.sort(pool, function(a, b)
		return Rarity.Get(a.Rarity).Order > Rarity.Get(b.Rarity).Order
	end)
	for i, item in pool do
		if i > 8 then
			break
		end
		ItemCard.new({ Parent = strip, Kind = item.Kind, Id = item.Id, Size = UDim2.fromOffset(140, 140), LayoutOrder = i })
	end

	priceButton(card, crate, 1, 14)
	priceButton(card, crate, 10, 275)
	return card
end

local function renderTab()
	for _, child in pager:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for name, button in tabButtons do
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if name == currentTab then Color3.new(1, 1, 1) else Color3.fromHex("#0B0F1A")
			stroke.Thickness = if name == currentTab then 3 else 2
		end
	end
	local crates = {}
	for _, crate in GachaDefinitions.ForTab(currentTab) do
		if GachaDefinitions.IsActive(crate, Workspace:GetServerTimeNow()) then
			table.insert(crates, crate)
		end
	end
	local pages = math.max(1, math.ceil(#crates / 2))
	page = math.clamp(page, 1, pages)
	for i = (page - 1) * 2 + 1, math.min(#crates, page * 2) do
		crateCard(crates[i], i).Parent = pager
	end
	prevButton.Instance.Visible = page > 1
	nextButton.Instance.Visible = page < pages
	if #crates == 0 then
		Create.Text({ Text = "No events right now. Check back soon!", Size = UDim2.fromOffset(700, 60), Font = Theme.Fonts.Body, TextSize = 34, Color = Theme.Colors.TextDim, Parent = pager })
	end
	if currentTab == "Events" then
		local event = GachaDefinitions.Get("HarvestCrate")
		local left = if event and event.EndsAt then event.EndsAt - Workspace:GetServerTimeNow() else 0
		subLabel.Text = if left > 0 then "Harvest Moon event · ends in " .. Format.Duration(left) else "Events"
	else
		subLabel.Text = "Every pull is decided by the server. Duplicates can be traded."
	end
end

function StoreScreen.ShowAll(crate: GachaDefinitions.Crate)
	for _, child in viewAllGrid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	viewAllTitle.Text = crate.DisplayName .. " — all prizes"
	local pool = GachaDefinitions.Pool(crate)
	local perRarity: { [string]: number } = {}
	for _, item in pool do
		perRarity[item.Rarity] = (perRarity[item.Rarity] or 0) + 1
	end
	local totalWeight = 0
	if crate.Items then
		for _, it in crate.Items do
			totalWeight += it.Weight
		end
	end
	for i, item in pool do
		local holder: Frame = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(150, 186), LayoutOrder = i, Parent = viewAllGrid })
		ItemCard.new({ Parent = holder, Kind = item.Kind, Id = item.Id, Size = UDim2.fromOffset(150, 150) })
		local chance = 0
		if crate.Odds then
			chance = (crate.Odds[item.Rarity] or 0) / math.max(1, perRarity[item.Rarity] or 1)
		elseif crate.Items then
			for _, it in crate.Items do
				if it.Id == item.Id then
					chance = it.Weight / totalWeight * 100
				end
			end
		end
		Create.Text({ Text = string.format("%.2f%%", chance), Size = UDim2.fromOffset(150, 30), Position = UDim2.fromOffset(0, 154), Font = Theme.Fonts.Body, TextSize = 26, Color = Theme.Rarity(item.Rarity), Stroke = 1.5, Parent = holder })
	end
	viewAll.Visible = true
end

function StoreScreen.OpenCrate(crateId: string, count: number)
	if opening then
		return
	end
	local crate = GachaDefinitions.Get(crateId)
	local data = StateController.Data
	if crate and data then
		local balance = if crate.Currency == "Coins" then data.Coins else data.Gems
		if balance < crate.Price * count then
			UIController.Toast(if crate.Currency == "Coins" then "Not enough coins!" else "Not enough gems!", "Error")
			if crate.Currency == "Gems" then
				UIController.Open("Gems")
			end
			return
		end
	end
	opening = true
	local result = Remotes.Function("StoreRequest"):InvokeServer("OpenCrate", crateId, count)
	opening = false
	if type(result) ~= "table" or not result.ok then
		UIController.Toast(if type(result) == "table" and result.error then result.error else "Purchase failed.", "Error")
		return
	end
	UIController.Open("Reveal", { Crate = crateId, Pulls = result.pulls })
end

local function refreshCurrency(data: { [string]: any })
	coinValue.Text = Format.Commas(data.Coins)
	gemValue.Text = Format.Commas(data.Gems)
end

function StoreScreen.Init()
	panel = Panel.new({
		Parent = UIController.Layer("Menus"),
		Name = "Store",
		Title = "Store",
		Size = Vector2.new(1140, 810),
		OnClose = function()
			UIController.Close("Store")
		end,
	})
	local body = panel.Body
	coinValue = currencyBar(body, 520, false)
	gemValue = currencyBar(body, 800, true)

	-- tabs
	local tabs: Frame = Create("Frame", { Name = "Tabs", BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 92), Size = UDim2.new(1, -40, 0, 96), Parent = body })
	Create.List(tabs, Enum.FillDirection.Horizontal, 18)
	for i, tab in GachaDefinitions.Tabs do
		local colors = Theme.Tabs[tab]
		local button: TextButton = Create("TextButton", { Name = tab, Size = UDim2.fromOffset(TAB_WIDTH[tab], 92), BackgroundColor3 = Color3.new(1, 1, 1), AutoButtonColor = false, Text = "", LayoutOrder = i, Parent = tabs })
		Create.Corner(6, button)
		Create.Gradient(button, colors.Top, colors.Bottom, 90)
		Create.Stroke(button, Color3.fromHex("#0B0F1A"), 2, 0, true)
		local icon: Frame = Create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -18), Size = UDim2.fromOffset(92, 92), ZIndex = 2, Parent = button })
		tabIcon(tab, icon)
		Create.Text({ Text = TAB_LABEL[tab], Size = UDim2.new(1, -10, 0, 40), Position = UDim2.new(0.5, 0, 1, -24), AnchorPoint = Vector2.new(0.5, 0.5), Font = Theme.Fonts.BodyHeavy, TextSize = 40, Scaled = true, Stroke = 2.5, ZIndex = 10, Parent = button })
		button.Activated:Connect(function()
			currentTab = tab
			page = 1
			renderTab()
		end)
		tabButtons[tab] = button
	end

	local sub: Frame = Create("Frame", { Name = "SubBar", BackgroundColor3 = Theme.Colors.SubBar, Position = UDim2.fromOffset(20, 198), Size = UDim2.new(1, -40, 0, 44), Parent = body })
	subLabel = Create.Text({ Text = "", Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5), Font = Theme.Fonts.BodySemi, TextSize = 24, Scaled = true, Color = Theme.Colors.TextDim, XAlign = Enum.TextXAlignment.Left, Parent = sub })

	pager = Create("Frame", { Name = "Pager", BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 252), Size = UDim2.new(1, -40, 0, 540), Parent = body })
	Create.List(pager, Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Center)
	nextButton = Button.new({ Parent = body, Size = UDim2.fromOffset(42, 68), Position = UDim2.new(1, -6, 1, -26), AnchorPoint = Vector2.new(1, 1), Style = "Blue", Text = ">", TextSize = 30, ZIndex = 5, OnClick = function()
		page += 1
		renderTab()
	end })
	prevButton = Button.new({ Parent = body, Size = UDim2.fromOffset(42, 68), Position = UDim2.new(0, 6, 1, -26), AnchorPoint = Vector2.new(0, 1), Style = "Blue", Text = "<", TextSize = 30, ZIndex = 5, OnClick = function()
		page -= 1
		renderTab()
	end })

	-- "View All" overlay
	viewAll = Create("Frame", { Name = "ViewAll", BackgroundColor3 = Theme.Colors.PanelDeep, BackgroundTransparency = 0.02, Size = UDim2.fromScale(1, 1), ZIndex = 30, Visible = false, Active = true, Parent = body })
	viewAllTitle = Create.Text({ Text = "", Size = UDim2.new(1, -120, 0, 50), Position = UDim2.fromOffset(24, 16), Font = Theme.Fonts.Display, TextSize = 34, Scaled = true, XAlign = Enum.TextXAlignment.Left, Stroke = 2, ZIndex = 31, Parent = viewAll })
	viewAllGrid = Create("ScrollingFrame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 80), Size = UDim2.new(1, -48, 1, -100), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, ZIndex = 31, Parent = viewAll })
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(150, 190)
	grid.CellPadding = UDim2.fromOffset(16, 12)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = viewAllGrid
	Button.new({ Parent = viewAll, Size = UDim2.fromOffset(150, 54), Position = UDim2.new(1, -20, 0, 16), AnchorPoint = Vector2.new(1, 0), Style = "Blue", Text = "Back", TextSize = 26, ZIndex = 32, OnClick = function()
		viewAll.Visible = false
	end })

	StateController.DataChanged:Connect(refreshCurrency)
	if StateController.Data then
		refreshCurrency(StateController.Data)
	end

	UIController.Register("Store", {
		Open = function(_, tab: string?)
			if tab and TAB_LABEL[tab] then
				currentTab = tab
			end
			page = 1
			viewAll.Visible = false
			renderTab()
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

return StoreScreen
