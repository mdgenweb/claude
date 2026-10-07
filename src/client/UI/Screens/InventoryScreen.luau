--!strict
-- Inventory / collection: Orbs, Explosions, Flyers and unopened Gachas. Grid with rarity filter,
-- search, sort, owned/locked states, duplicate counts; detail panel with ability text, stats,
-- Equip (cosmetics) and Open (gacha tickets).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BallDefinitions = require(Shared.Definitions.BallDefinitions)
local CosmeticDefinitions = require(Shared.Definitions.CosmeticDefinitions)
local GachaDefinitions = require(Shared.Definitions.GachaDefinitions)
local Rarity = require(Shared.Config.Rarity)
local Remotes = require(Shared.Net.Remotes)

local Client = script.Parent.Parent.Parent
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local Button = require(Client.UI.Components.Button)
local Panel = require(Client.UI.Components.Panel)
local ItemCard = require(Client.UI.Components.ItemCard)
local UIController = require(Client.Controllers.UIController)
local StateController = require(Client.Controllers.StateController)

local InventoryScreen = {}

type Entry = { Kind: string, Id: string, Name: string, Rarity: string, Count: number, Description: string }

local TABS = { { Key = "Ball", Label = "Orbs" }, { Key = "Explosion", Label = "Explosions" }, { Key = "Flyer", Label = "Flyers" }, { Key = "Ticket", Label = "Gachas" } }

local panel: Panel.Panel
local grid: ScrollingFrame
local progressLabel: TextLabel
local detail: Frame
local detailArt: Frame
local detailName: TextLabel
local detailRarity: TextLabel
local detailDesc: TextLabel
local detailStats: TextLabel
local actionButton: Button.Button
local searchBox: TextBox
local sortButton: Button.Button
local tabButtons: { [string]: Button.Button } = {}
local filterButtons: { [string]: Button.Button } = {}
local currentTab = "Ball"
local rarityFilter: string? = nil
local sortMode = "Rarity"
local selected: Entry? = nil

local function entries(): { Entry }
	local list: { Entry } = {}
	if currentTab == "Ball" then
		for _, def in BallDefinitions.All() do
			table.insert(list, { Kind = "Ball", Id = def.Id, Name = def.DisplayName, Rarity = def.Rarity, Count = StateController.Count("Ball", def.Id), Description = def.Description })
		end
	elseif currentTab == "Ticket" then
		for _, crate in GachaDefinitions.All() do
			local count = StateController.Count("Ticket", crate.Id)
			if count > 0 then
				local _, rarity = ItemCard.Info("Ticket", crate.Id)
				table.insert(list, { Kind = "Ticket", Id = crate.Id, Name = crate.DisplayName, Rarity = rarity, Count = count, Description = "An unopened gacha. Open it to get a random prize!" })
			end
		end
	else
		for _, def in CosmeticDefinitions.All(currentTab :: any) do
			table.insert(list, { Kind = def.Kind :: string, Id = def.Id, Name = def.DisplayName, Rarity = def.Rarity, Count = StateController.Count(def.Kind, def.Id), Description = def.Description })
		end
	end
	return list
end

local function showDetail(entry: Entry?)
	selected = entry
	for _, child in detailArt:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if entry == nil then
		detailName.Text = "Select an item"
		detailRarity.Text = ""
		detailDesc.Text = ""
		detailStats.Text = ""
		actionButton.Instance.Visible = false
		return
	end
	ItemCard.Art(detailArt, entry.Kind, entry.Id, 2, true)
	detailName.Text = entry.Name
	detailRarity.Text = entry.Rarity
	detailRarity.TextColor3 = Theme.Rarity(entry.Rarity)
	detailDesc.Text = entry.Description
	detailStats.Text = ""
	if entry.Kind == "Ball" then
		local def = BallDefinitions.Get(entry.Id)
		if def then
			detailStats.Text = string.format("HP %d   ·   Bump %d   ·   Speed %d%%   ·   Size %.1f", def.BaseHP, def.ContactDamage, math.floor(def.Speed * 100), def.Radius * 2)
		end
	end
	if entry.Count > 1 then
		detailStats.Text ..= string.format("\nOwned: x%d", entry.Count)
	end
	actionButton.Instance.Visible = true
	local data = StateController.Data
	if entry.Kind == "Ticket" then
		actionButton:SetText("Open")
		actionButton:SetStyle("Green")
		actionButton:SetEnabled(entry.Count > 0)
	elseif entry.Kind == "Ball" then
		actionButton:SetText(if entry.Count > 0 then "Owned" else "Locked")
		actionButton:SetEnabled(false)
	else
		local equipped = data and data.Equipped and data.Equipped[entry.Kind] == entry.Id
		actionButton:SetText(if equipped then "Equipped" elseif entry.Count > 0 then "Equip" else "Locked")
		actionButton:SetStyle("Blue")
		actionButton:SetEnabled(entry.Count > 0 and not equipped)
	end
end

local function render()
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for key, b in tabButtons do
		b:SetStyle(if key == currentTab then "Orange" else "Dark")
	end
	for key, b in filterButtons do
		b:SetStyle(if key == (rarityFilter or "All") then "Blue" else "Dark")
	end
	local list = entries()
	local owned, total = 0, 0
	for _, e in list do
		total += 1
		if e.Count > 0 then
			owned += 1
		end
	end
	progressLabel.Text = if currentTab == "Ticket" then string.format("%d unopened", total) else string.format("Collected %d / %d", owned, total)
	local query = string.lower(searchBox.Text)
	local filtered = {}
	for _, e in list do
		if (rarityFilter == nil or e.Rarity == rarityFilter) and (query == "" or string.find(string.lower(e.Name), query, 1, true)) then
			table.insert(filtered, e)
		end
	end
	table.sort(filtered, function(a, b)
		if sortMode == "Name" then
			return a.Name < b.Name
		elseif sortMode == "Owned" and (a.Count > 0) ~= (b.Count > 0) then
			return a.Count > 0
		end
		local ra, rb = Rarity.Get(a.Rarity).Order, Rarity.Get(b.Rarity).Order
		if ra ~= rb then
			return ra > rb
		end
		return a.Name < b.Name
	end)
	local data = StateController.Data
	for i, e in filtered do
		local card = ItemCard.new({
			Parent = grid,
			Kind = e.Kind,
			Id = e.Id,
			Size = UDim2.fromOffset(150, 150),
			Count = e.Count,
			Locked = e.Count <= 0,
			LayoutOrder = i,
			OnClick = function()
				showDetail(e)
			end,
		})
		if data and e.Kind ~= "Ball" and e.Kind ~= "Ticket" and data.Equipped and data.Equipped[e.Kind] == e.Id then
			card:SetSelected(true)
		end
	end
	if #filtered == 0 then
		Create.Text({ Text = if currentTab == "Ticket" then "No unopened gachas. Win battles and level up to earn more!" else "Nothing matches.", Size = UDim2.fromOffset(600, 60), Font = Theme.Fonts.Body, TextSize = 28, Color = Theme.Colors.TextDim, Wrapped = true, Parent = grid })
	end
	if selected then
		for _, e in list do
			if e.Id == selected.Id and e.Kind == selected.Kind then
				showDetail(e)
				return
			end
		end
	end
	showDetail(nil)
end

local function onAction()
	local entry = selected
	if entry == nil then
		return
	end
	if entry.Kind == "Ticket" then
		local result = Remotes.Function("StoreRequest"):InvokeServer("OpenTicket", entry.Id)
		if type(result) == "table" and result.ok then
			UIController.Close("Inventory")
			UIController.Open("Reveal", { Crate = entry.Id, Pulls = result.pulls })
		else
			UIController.Toast(if type(result) == "table" and result.error then result.error else "Couldn't open.", "Error")
		end
	elseif entry.Kind == "Explosion" or entry.Kind == "Flyer" then
		local result = Remotes.Function("StoreRequest"):InvokeServer("Equip", entry.Kind, entry.Id)
		if type(result) == "table" and result.ok then
			UIController.Toast(entry.Name .. " equipped!", "Success")
		else
			UIController.Toast(if type(result) == "table" and result.error then result.error else "Couldn't equip.", "Error")
		end
	end
end

function InventoryScreen.Init()
	panel = Panel.new({
		Parent = UIController.Layer("Menus"),
		Name = "Inventory",
		Title = "Inventory",
		Size = Vector2.new(1180, 800),
		OnClose = function()
			UIController.Close("Inventory")
		end,
	})
	local body = panel.Body
	progressLabel = Create.Text({ Text = "", Size = UDim2.fromOffset(300, 34), Position = UDim2.new(1, -330, 0, 26), Font = Theme.Fonts.Display, TextSize = 24, Scaled = true, XAlign = Enum.TextXAlignment.Right, Color = Theme.Colors.Gold, Stroke = 2, Parent = body })

	local tabs: Frame = Create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 90), Size = UDim2.new(1, -40, 0, 56), Parent = body })
	Create.List(tabs, Enum.FillDirection.Horizontal, 12)
	for i, tab in TABS do
		tabButtons[tab.Key] = Button.new({ Parent = tabs, Size = UDim2.fromOffset(190, 54), Style = "Dark", Text = tab.Label, Font = Theme.Fonts.BodyHeavy, TextSize = 30, LayoutOrder = i, OnClick = function()
			currentTab = tab.Key
			selected = nil
			render()
		end })
	end

	local filters: Frame = Create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 156), Size = UDim2.new(0, 760, 0, 44), Parent = body })
	Create.List(filters, Enum.FillDirection.Horizontal, 8)
	for i, key in { "All", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" } do
		local b = Button.new({ Parent = filters, Size = UDim2.fromOffset(if key == "All" then 70 else 120, 42), Style = "Dark", Text = key, Font = Theme.Fonts.Body, TextSize = 22, LayoutOrder = i, OnClick = function()
			rarityFilter = if key == "All" then nil else key
			render()
		end })
		if key ~= "All" then
			b.Label.TextColor3 = Theme.Rarity(key)
		end
		filterButtons[key] = b
	end
	searchBox = Create("TextBox", {
		Name = "Search",
		PlaceholderText = "Search...",
		Text = "",
		ClearTextOnFocus = false,
		FontFace = Theme.Fonts.Body,
		TextSize = 24,
		TextColor3 = Color3.new(1, 1, 1),
		PlaceholderColor3 = Theme.Colors.TextMuted,
		BackgroundColor3 = Theme.Colors.SubBar,
		Position = UDim2.fromOffset(20, 208),
		Size = UDim2.fromOffset(500, 42),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = body,
	})
	Create.Padding(searchBox, 12, 0)
	Create.Stroke(searchBox, Theme.Colors.PanelBorder, 1.5, 0, true)
	searchBox:GetPropertyChangedSignal("Text"):Connect(render)
	sortButton = Button.new({ Parent = body, Size = UDim2.fromOffset(240, 42), Position = UDim2.fromOffset(540, 208), Style = "Dark", Text = "Sort: Rarity", Font = Theme.Fonts.Body, TextSize = 22, OnClick = function()
		sortMode = if sortMode == "Rarity" then "Name" elseif sortMode == "Name" then "Owned" else "Rarity"
		sortButton:SetText("Sort: " .. sortMode)
		render()
	end })

	grid = Create("ScrollingFrame", { Name = "Grid", BackgroundColor3 = Theme.Colors.Card, BackgroundTransparency = 0.2, Position = UDim2.fromOffset(20, 262), Size = UDim2.fromOffset(760, 520), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, Parent = body })
	Create.Padding(grid, 12)
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(150, 150)
	layout.CellPadding = UDim2.fromOffset(12, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	detail = Create("Frame", { Name = "Detail", BackgroundColor3 = Theme.Colors.Card, Position = UDim2.fromOffset(800, 156), Size = UDim2.fromOffset(360, 626), Parent = body })
	Create.Stroke(detail, Theme.Colors.PanelBorder, 2, 0, true)
	detailArt = Create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16), Size = UDim2.fromOffset(220, 220), Parent = detail })
	detailName = Create.Text({ Text = "", Size = UDim2.new(1, -24, 0, 40), Position = UDim2.fromOffset(12, 246), Font = Theme.Fonts.Body, TextSize = 36, Scaled = true, Stroke = 2, Parent = detail })
	detailRarity = Create.Text({ Text = "", Size = UDim2.new(1, -24, 0, 28), Position = UDim2.fromOffset(12, 288), Font = Theme.Fonts.Display, TextSize = 22, Scaled = true, Stroke = 1.5, Parent = detail })
	detailDesc = Create.Text({ Text = "", Size = UDim2.new(1, -28, 0, 130), Position = UDim2.fromOffset(14, 326), Font = Theme.Fonts.BodySemi, TextSize = 25, Wrapped = true, YAlign = Enum.TextYAlignment.Top, Color = Theme.Colors.TextDim, Parent = detail })
	detailStats = Create.Text({ Text = "", Size = UDim2.new(1, -28, 0, 60), Position = UDim2.fromOffset(14, 460), Font = Theme.Fonts.Body, TextSize = 22, Wrapped = true, YAlign = Enum.TextYAlignment.Top, Color = Color3.fromHex("#9FD8FF"), Parent = detail })
	actionButton = Button.new({ Parent = detail, Size = UDim2.new(1, -40, 0, 62), Position = UDim2.new(0.5, 0, 1, -16), AnchorPoint = Vector2.new(0.5, 1), Style = "Blue", Text = "Equip", TextSize = 32, OnClick = onAction })

	StateController.DataChanged:Connect(function()
		if panel.Visible then
			render()
		end
	end)

	UIController.Register("Inventory", {
		Open = function(_, tab: string?)
			if tab then
				currentTab = tab
			end
			render()
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

return InventoryScreen
