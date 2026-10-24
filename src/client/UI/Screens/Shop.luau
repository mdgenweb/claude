-- Shop: the seven small, exact offers. A featured banner (Double Scrap, x1 -> x2) over
-- a card grid, in the style of popular simulator shops. Each card states the exact
-- benefit; live prices come from the Marketplace when real IDs are configured.

local MarketplaceService = game:GetService("MarketplaceService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Theme = require(Shared.Theme)

local UI = script.Parent.Parent
local UIKit = require(UI.UIKit)
local Copy = require(UI.Copy)
local Panels = require(UI.Panels)
local Gui = require(UI.Gui)
local Toasts = require(UI.Toasts)
local Net = require(UI.Parent.Net)

local Shop = {}

local cards: { [string]: any } = {}
local prices: { [string]: number } = {}
local pricesFetched = false
local note: TextLabel
local list: ScrollingFrame

local function offer(key: string): Config.Offer?
	for _, o in Config.Offers do
		if o.Key == key then
			return o
		end
	end
	return nil
end

local function priceText(o: Config.Offer): string
	return "R$" .. tostring(prices[o.Key] or o.Price)
end

local function fetchPrices()
	if pricesFetched then
		return
	end
	pricesFetched = true
	for _, o in Config.Offers do
		if o.Id ~= 0 then
			task.spawn(function()
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(
						o.Id,
						if o.Kind == "Pass" then Enum.InfoType.GamePass else Enum.InfoType.Product
					)
				end)
				if ok and info and info.PriceInRobux then
					prices[o.Key] = info.PriceInRobux
					Shop.refresh()
				end
			end)
		end
	end
end

local function buy(key: string)
	local ok, msg = Net.request("Buy", key)
	if not ok then
		Toasts.error(msg)
	end
end

local function buildFeatured(parent: Instance)
	local o = offer("DoubleScrap") :: Config.Offer
	local banner = UIKit.surface(parent, {
		Name = "Featured",
		Size = UDim2.new(1, -16, 0, 156),
		Swatch = Theme.Swatch.Green,
		Radius = Theme.Radius.L,
		LayoutOrder = 0,
	})
	banner.Face.ClipsDescendants = true
	local iconBox = UIKit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(140, 140),
		Position = UDim2.new(0, 14, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Parent = banner.Face,
	})
	UIKit.sunburst(iconBox, Color3.new(1, 1, 1), 10, 1)
	UIKit.icon(iconBox, o.Icon, UDim2.fromScale(0.78, 0.78), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	UIKit.text(banner.Face, {
		Text = string.upper(o.Name) .. "!",
		TextSize = 44,
		Size = UDim2.fromOffset(420, 52),
		Position = UDim2.fromOffset(170, 14),
		XAlign = Enum.TextXAlignment.Left,
		StrokeThickness = 4,
	})
	local arrow = UIKit.text(banner.Face, {
		Text = Copy.Shop.Featured,
		TextSize = 40,
		Size = UDim2.fromOffset(260, 46),
		Position = UDim2.fromOffset(170, 64),
		XAlign = Enum.TextXAlignment.Left,
		Color = Color3.fromHex("#FFE85E"),
		StrokeThickness = 4,
	})
	UIKit.bob(arrow, 3, 1.4)
	UIKit.text(banner.Face, {
		Text = o.Benefit,
		TextSize = 18,
		Font = Theme.Font.Body,
		Size = UDim2.fromOffset(420, 26),
		Position = UDim2.fromOffset(170, 114),
		XAlign = Enum.TextXAlignment.Left,
	})
	local price = UIKit.button(banner.Face, {
		Name = "Price",
		Text = priceText(o),
		TextSize = 32,
		Size = UDim2.fromOffset(170, 72),
		Position = UDim2.new(1, -18, 0.5, -3),
		AnchorPoint = Vector2.new(1, 0.5),
		Swatch = {
			Top = Color3.fromHex("#5BD94A"),
			Bottom = Color3.fromHex("#16872A"),
			Deep = Color3.fromHex("#0C5418"),
		},
		OnClick = function()
			buy(o.Key)
		end,
	})
	cards[o.Key] = { Holder = banner.Holder, Price = price, Offer = o }
end

local function buildCard(parent: Instance, o: Config.Offer, order: number)
	local swatch = Theme.Swatch[o.Color] or Theme.Swatch.Blue
	local card = UIKit.surface(parent, {
		Name = o.Key,
		Size = UDim2.fromOffset(250, 236),
		Swatch = swatch,
		Radius = Theme.Radius.L,
		LayoutOrder = order,
	})
	card.Face.ClipsDescendants = true
	local iconBox = UIKit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(84, 84),
		Position = UDim2.new(0.5, 0, 0, 10),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = card.Face,
	})
	UIKit.sunburst(iconBox, Color3.new(1, 1, 1), 8, 1)
	UIKit.icon(iconBox, o.Icon, UDim2.fromScale(0.85, 0.85), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	UIKit.text(card.Face, {
		Text = string.upper(o.Name),
		TextSize = 24,
		Size = UDim2.new(1, -16, 0, 30),
		Position = UDim2.fromOffset(8, 96),
	})
	local benefit = UIKit.text(card.Face, {
		Text = o.Benefit,
		TextSize = 15,
		Font = Theme.Font.Body,
		Size = UDim2.new(1, -20, 0, 42),
		Position = UDim2.fromOffset(10, 126),
	})
	local price = UIKit.button(card.Face, {
		Name = "Price",
		Text = priceText(o),
		TextSize = 26,
		Size = UDim2.new(1, -40, 0, 50),
		Position = UDim2.new(0.5, 0, 1, -12),
		AnchorPoint = Vector2.new(0.5, 1),
		Swatch = {
			Top = Color3.fromHex("#5BD94A"),
			Bottom = Color3.fromHex("#16872A"),
			Deep = Color3.fromHex("#0C5418"),
		},
		OnClick = function()
			buy(o.Key)
		end,
	})
	cards[o.Key] = { Holder = card.Holder, Price = price, Offer = o, Benefit = benefit }
end

function Shop.refresh()
	local s = Net.State
	if not s then
		return
	end
	for key, card in cards do
		local o = card.Offer
		local owned = o.Kind == "Pass" and s.Passes[key] == true
		if owned then
			card.Price:SetText("✓ " .. Copy.Shop.Owned)
			card.Price:SetEnabled(false)
		else
			card.Price:SetText(priceText(o))
			card.Price:SetEnabled(true)
		end
		if key == "WorkerStarter" and card.Benefit then
			local hasShell = table.find(s.Finishes, "Worker") ~= nil
			card.Benefit.Text = if hasShell and not owned then Copy.Shop.StarterOwnedShell else o.Benefit
		elseif key == "ScrapBoost" and card.Benefit then
			card.Benefit.Text = o.Benefit
				.. (if s.BoostCharges > 0 then "  " .. string.format(Copy.Shop.BoostHave, s.BoostCharges) else "")
		end
	end
	note.Visible = s.StudioTest == true
end

function Shop.init()
	local panel = Panels.create({
		Name = "Shop",
		Title = Copy.Shop.Title,
		Icon = "🛒",
		Swatch = Theme.Swatch.Green,
		Width = 860,
		Height = 540,
		TabWidth = 220,
	})
	list = UIKit.new("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Theme.Muted,
		Parent = panel.Body,
	})
	UIKit.list(list, true, 18, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
	UIKit.padding(list, 6, 8)
	buildFeatured(list)
	local grid = UIKit.new("Frame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = list,
	})
	UIKit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(250, 236),
		CellPadding = UDim2.fromOffset(18, 22),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	local order = 0
	for _, o in Config.Offers do
		if o.Key ~= "DoubleScrap" then
			order += 1
			buildCard(grid, o, order)
		end
	end
	note = UIKit.text(list, {
		Text = Copy.Shop.StudioNote,
		TextSize = 15,
		Font = Theme.Font.Body,
		Color = Theme.Muted,
		Size = UDim2.new(1, -20, 0, 24),
		LayoutOrder = 2,
	})

	panel.OnOpen = function(focusKey)
		fetchPrices()
		Shop.refresh()
		local card = focusKey and cards[focusKey]
		if card then
			task.defer(function()
				local y = (card.Holder.AbsolutePosition.Y - list.AbsolutePosition.Y) / Gui.scale + list.CanvasPosition.Y
				list.CanvasPosition = Vector2.new(0, math.max(0, y - 20))
				UIKit.pop(card.Holder, 0.12)
			end)
		end
	end
	Net.Changed:Connect(function()
		if Panels.isOpen("Shop") then
			Shop.refresh()
		end
	end)
end

return Shop
