-- Garage: pick a tool style (Hammer / Saw / Drill - identical stats) and a finish.
-- Finishes are looks only: craft the Worker Shell, earn Stamped Chrome, or buy paint.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local MechBuilder = require(Shared.MechBuilder)
local Theme = require(Shared.Theme)

local UI = script.Parent.Parent
local UIKit = require(UI.UIKit)
local Copy = require(UI.Copy)
local Panels = require(UI.Panels)
local Toasts = require(UI.Toasts)
local Viewport = require(UI.Viewport)
local Net = require(UI.Parent.Net)

local Garage = {}

local preview: ViewportFrame
local shownKey = ""
local toolCards = {}
local finishCards = {}

local FINISH_OFFER = { Lime = "LimePaint", Foundry = "FoundryVIP" }

local function request(action: string, arg: any?)
	local ok, msg = Net.request(action, arg)
	if not ok then
		Toasts.error(msg)
	end
end

local function owns(s, finishId: string): boolean
	return table.find(s.Finishes, finishId) ~= nil
end

function Garage.refresh()
	local s = Net.State
	if not s then
		return
	end
	local key = string.format("%d:%s:%s", s.Level, s.Tool, s.Finish)
	if key ~= shownKey then
		shownKey = key
		Viewport.showMech(preview, s.Level, s.Tool, s.Finish, 60)
		for id, c in toolCards do
			Viewport.showTool(c.View, id, s.Finish, s.Level)
		end
	end
	for id, c in toolCards do
		local equipped = s.Tool == id
		c.Button:SetText(if equipped then Copy.Garage.Equipped else Copy.Garage.Equip)
		c.Button:SetEnabled(not equipped)
	end
	for id, c in finishCards do
		local owned = owns(s, id)
		local equipped = s.Finish == id
		local button = c.Button
		if equipped then
			button:SetText(Copy.Garage.Equipped)
			button:SetSwatch(Theme.Swatch.Green)
			button:SetEnabled(false)
		elseif owned then
			button:SetText(Copy.Garage.Equip)
			button:SetSwatch(Theme.Swatch.Green)
			button:SetEnabled(true)
		elseif id == "Worker" then
			button:SetText(string.format("%s ⚙️%s", Copy.Garage.Craft, Economy.format(Config.WorkerShellCraftCost)))
			button:SetSwatch(Theme.Swatch.Orange)
			button:SetEnabled(true)
		elseif FINISH_OFFER[id] then
			local price = 0
			for _, o in Config.Offers do
				if o.Key == FINISH_OFFER[id] then
					price = o.Price
				end
			end
			button:SetText(string.format("%s R$%d", Copy.Garage.Get, price))
			button:SetSwatch(Theme.Swatch.Blue)
			button:SetEnabled(true)
		else
			button:SetText(
				string.format(
					"%d/%d 📋",
					math.min(s.Stamps, Config.Daily.StampsForFinish),
					Config.Daily.StampsForFinish
				)
			)
			button:SetEnabled(false)
		end
	end
end

local function onFinishClick(id: string)
	local s = Net.State
	if not s then
		return
	end
	if owns(s, id) then
		request("SelectFinish", id)
	elseif id == "Worker" then
		request("CraftWorker")
	elseif FINISH_OFFER[id] then
		Panels.open("Shop", FINISH_OFFER[id])
	end
end

function Garage.init()
	local panel = Panels.create({
		Name = "Garage",
		Title = Copy.Garage.Title,
		Icon = "🎨",
		Swatch = Theme.Swatch.Blue,
		Width = 900,
		Height = 560,
		TabWidth = 270,
	})
	local body = panel.Body

	local card = UIKit.surface(
		body,
		{ Size = UDim2.fromOffset(250, 476), Swatch = Theme.Swatch.Navy, Radius = Theme.Radius.L, Shine = false }
	)
	card.Face.ClipsDescendants = true
	UIKit.sunburst(card.Face, Color3.fromHex("#62CCFF"), 10, 2)
	preview =
		Viewport.create(card.Face, { Size = UDim2.new(1, 0, 1, -10), Position = UDim2.fromOffset(0, 5), ZIndex = 3 })

	local right = UIKit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -270, 1, 0),
		Position = UDim2.fromOffset(270, 0),
		Parent = body,
	})
	UIKit.text(
		right,
		{ Text = Copy.Garage.Tools, TextSize = 28, Size = UDim2.fromOffset(200, 32), XAlign = Enum.TextXAlignment.Left }
	)
	UIKit.text(right, {
		Text = Copy.Garage.ToolsSub,
		TextSize = 17,
		Font = Theme.Font.Body,
		Color = Theme.Muted,
		Size = UDim2.new(1, -210, 0, 32),
		Position = UDim2.fromOffset(150, 0),
		XAlign = Enum.TextXAlignment.Left,
	})
	local tools = UIKit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 200),
		Position = UDim2.fromOffset(0, 38),
		Parent = right,
	})
	UIKit.list(tools, false, 16, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top)
	for i, tool in Config.Tools do
		local c = UIKit.surface(
			tools,
			{ Size = UDim2.fromOffset(180, 196), Swatch = Theme.Swatch.Steel, Radius = Theme.Radius.L, LayoutOrder = i }
		)
		local view =
			Viewport.create(c.Face, { Size = UDim2.new(1, 0, 0, 100), Position = UDim2.fromOffset(0, 4), ZIndex = 3 })
		UIKit.text(c.Face, {
			Text = string.upper(tool.Name),
			TextSize = 24,
			Size = UDim2.new(1, -12, 0, 28),
			Position = UDim2.fromOffset(6, 100),
		})
		UIKit.text(c.Face, {
			Text = tool.Blurb,
			TextSize = 14,
			Font = Theme.Font.Body,
			Size = UDim2.new(1, -12, 0, 20),
			Position = UDim2.fromOffset(6, 126),
		})
		local button = UIKit.button(c.Face, {
			Text = Copy.Garage.Equip,
			TextSize = 20,
			Size = UDim2.new(1, -24, 0, 40),
			Position = UDim2.new(0.5, 0, 1, -10),
			AnchorPoint = Vector2.new(0.5, 1),
			OnClick = function()
				request("SelectTool", tool.Id)
			end,
		})
		toolCards[tool.Id] = { View = view, Button = button }
	end

	UIKit.text(right, {
		Text = Copy.Garage.Finishes,
		TextSize = 28,
		Size = UDim2.fromOffset(200, 32),
		Position = UDim2.fromOffset(0, 250),
		XAlign = Enum.TextXAlignment.Left,
	})
	local finishes = UIKit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 196),
		Position = UDim2.fromOffset(0, 284),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 6,
		Parent = right,
	})
	UIKit.list(finishes, false, 14, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top)
	UIKit.padding(finishes, 4)
	for i, finish in Config.Finishes do
		local palette = MechBuilder.palette(4, if finish.Id == "Default" then nil else finish.Id)
		local c = UIKit.surface(
			finishes,
			{ Size = UDim2.fromOffset(150, 176), Swatch = Theme.Swatch.Navy, Radius = Theme.Radius.L, LayoutOrder = i }
		)
		local swatches = UIKit.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -16, 0, 44),
			Position = UDim2.fromOffset(8, 10),
			Parent = c.Face,
		})
		UIKit.list(swatches, false, 6)
		for j, color in { palette.Primary, palette.Secondary, palette.Eyes } do
			local dot = UIKit.new(
				"Frame",
				{ Size = UDim2.fromOffset(38, 38), BackgroundColor3 = color, LayoutOrder = j, Parent = swatches }
			)
			UIKit.corner(dot, 19)
			UIKit.stroke(dot, 2.5, Theme.Ink, true)
		end
		UIKit.text(c.Face, {
			Text = string.upper(finish.Name),
			TextSize = 19,
			Size = UDim2.new(1, -12, 0, 26),
			Position = UDim2.fromOffset(6, 60),
		})
		UIKit.text(c.Face, {
			Text = finish.HowToGet,
			TextSize = 13,
			Font = Theme.Font.Body,
			Color = Theme.Muted,
			Size = UDim2.new(1, -12, 0, 34),
			Position = UDim2.fromOffset(6, 86),
		})
		local button = UIKit.button(c.Face, {
			Text = Copy.Garage.Equip,
			TextSize = 17,
			Size = UDim2.new(1, -18, 0, 38),
			Position = UDim2.new(0.5, 0, 1, -10),
			AnchorPoint = Vector2.new(0.5, 1),
			OnClick = function()
				onFinishClick(finish.Id)
			end,
			OnDisabledClick = function()
				if finish.Id == "Chrome" then
					Toasts.error("Collect 5 daily stamps to unlock Stamped Chrome")
				end
			end,
		})
		finishCards[finish.Id] = { Button = button }
	end

	panel.OnOpen = Garage.refresh
	Net.Changed:Connect(function()
		if Panels.isOpen("Garage") then
			Garage.refresh()
		end
	end)
end

return Garage
