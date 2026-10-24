-- Upgrade panel: live 3D preview of your mech next to the nine Power upgrades,
-- each showing the visible milestone it unlocks (the "one more upgrade" hook).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Theme = require(Shared.Theme)

local UI = script.Parent.Parent
local UIKit = require(UI.UIKit)
local Copy = require(UI.Copy)
local Panels = require(UI.Panels)
local Toasts = require(UI.Toasts)
local Viewport = require(UI.Viewport)
local Net = require(UI.Parent.Net)

local Upgrade = {}

local rows = {}
local preview: ViewportFrame
local formLabel: TextLabel
local powerLabel: TextLabel
local shownKey = ""

local function buildRow(list: ScrollingFrame, index: number)
	local up = Config.Upgrades[index]
	local isForm = up.Milestone:find("form") ~= nil
	local surface = UIKit.surface(list, {
		Name = "Row" .. index,
		Size = UDim2.new(1, -16, 0, 70),
		Swatch = if isForm then Theme.Swatch.Orange else Theme.Swatch.Navy,
		LayoutOrder = index,
		Radius = Theme.Radius.M,
		ShadowOffset = 4,
	})
	local num = UIKit.surface(surface.Face, {
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.new(0, 10, 0.5, -2),
		AnchorPoint = Vector2.new(0, 0.5),
		Swatch = Theme.Swatch.Steel,
		Radius = 999,
		ShadowOffset = 3,
	})
	local numLabel = UIKit.text(num.Face, { Text = tostring(index), TextSize = 24 })
	UIKit.text(surface.Face, {
		Text = "⚡ " .. Economy.format(up.Power) .. " POWER",
		TextSize = 24,
		Size = UDim2.new(0.55, 0, 0, 30),
		Position = UDim2.fromOffset(68, 7),
		XAlign = Enum.TextXAlignment.Left,
	})
	UIKit.text(surface.Face, {
		Text = up.Milestone,
		TextSize = 17,
		Font = Theme.Font.Body,
		Color = if isForm then Theme.White else Theme.Muted,
		Size = UDim2.new(0.55, 0, 0, 22),
		Position = UDim2.fromOffset(68, 38),
		XAlign = Enum.TextXAlignment.Left,
	})
	if isForm then
		UIKit.chip(surface.Face, {
			Text = Copy.Upgrade.NewForm,
			Size = UDim2.fromOffset(104, 24),
			Position = UDim2.new(0.62, 0, 0, 8),
			Swatch = Theme.Swatch.Purple,
			TextSize = 14,
		})
	end
	local buy = UIKit.button(surface.Face, {
		Name = "Buy",
		Text = "⚙️ " .. Economy.format(up.Cost),
		TextSize = 22,
		Size = UDim2.fromOffset(150, 50),
		Position = UDim2.new(1, -12, 0.5, -2),
		AnchorPoint = Vector2.new(1, 0.5),
		Swatch = Theme.Swatch.Green,
		OnClick = function()
			local ok, msg = Net.request("Upgrade")
			if not ok then
				Toasts.error(msg)
			end
		end,
		OnDisabledClick = function()
			local s = Net.State
			if s and s.Level + 1 == index then
				Toasts.error(string.format("Need %s more Scrap", Economy.format(up.Cost - s.Scrap)))
			elseif s and index > s.Level + 1 then
				Toasts.error("Buy the upgrades above first")
			end
		end,
	})
	rows[index] = { Num = num, NumLabel = numLabel, Buy = buy }
end

local function refresh()
	local s = Net.State
	if not s then
		return
	end
	for index, row in rows do
		local up = Config.Upgrades[index]
		if index <= s.Level then
			row.Buy:SetText("✓ " .. Copy.Upgrade.Owned)
			row.Buy:SetSwatch(Theme.Swatch.Blue)
			row.Buy:SetEnabled(false)
			UIKit.setSwatch(row.Num.Gradient, Theme.Swatch.Green)
		elseif index == s.Level + 1 then
			row.Buy:SetText("⚙️ " .. Economy.format(up.Cost))
			row.Buy:SetSwatch(Theme.Swatch.Green)
			row.Buy:SetEnabled(s.Scrap >= up.Cost)
			UIKit.setSwatch(row.Num.Gradient, Theme.Swatch.Yellow)
		else
			row.Buy:SetText("⚙️ " .. Economy.format(up.Cost))
			row.Buy:SetEnabled(false)
			UIKit.setSwatch(row.Num.Gradient, Theme.Swatch.Steel)
		end
	end
	formLabel.Text = string.upper(Economy.formFor(s.Level).Name)
	powerLabel.Text = string.format("⚡ %s POWER · LVL %d/%d", Economy.format(s.Power), s.Level, Economy.MaxLevel)
	local key = string.format("%d:%s:%s", s.Level, s.Tool, s.Finish)
	if key ~= shownKey then
		shownKey = key
		Viewport.showMech(preview, s.Level, s.Tool, s.Finish, 30)
	end
end

function Upgrade.init()
	local panel = Panels.create({
		Name = "Upgrade",
		Title = Copy.Upgrade.Title,
		Icon = "⚡",
		Swatch = Theme.Swatch.Orange,
		Width = 860,
		Height = 520,
		TabWidth = 300,
		Blocking = false,
	})
	local body = panel.Body

	local card = UIKit.surface(
		body,
		{ Size = UDim2.fromOffset(270, 440), Swatch = Theme.Swatch.Navy, Radius = Theme.Radius.L, Shine = false }
	)
	card.Face.ClipsDescendants = true
	UIKit.sunburst(card.Face, Color3.fromHex("#FFB24A"), 10, 2)
	UIKit.text(card.Face, {
		Text = Copy.Upgrade.Current,
		TextSize = 18,
		Font = Theme.Font.Body,
		Color = Theme.Muted,
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.fromOffset(0, 10),
		ZIndex = 3,
	})
	preview =
		Viewport.create(card.Face, { Size = UDim2.new(1, 0, 0, 320), Position = UDim2.fromOffset(0, 30), ZIndex = 3 })
	formLabel = UIKit.text(card.Face, {
		Text = "",
		TextSize = 34,
		Color = Color3.fromHex("#FFB24A"),
		Size = UDim2.new(1, -16, 0, 40),
		Position = UDim2.fromOffset(8, 352),
		ZIndex = 3,
	})
	powerLabel = UIKit.text(card.Face, {
		Text = "",
		TextSize = 18,
		Font = Theme.Font.Body,
		Size = UDim2.new(1, -16, 0, 26),
		Position = UDim2.fromOffset(8, 396),
		ZIndex = 3,
	})

	local list = UIKit.new("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -290, 1, 0),
		Position = UDim2.fromOffset(290, 0),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Theme.Muted,
		Parent = body,
	})
	UIKit.list(list, true, 12, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top)
	UIKit.padding(list, 4, 6)
	for index = 1, #Config.Upgrades do
		buildRow(list, index)
	end

	panel.OnOpen = function()
		refresh()
		local s = Net.State
		if s then
			-- Scroll so the next upgrade is in view.
			list.CanvasPosition = Vector2.new(0, math.max(0, (s.Level - 1) * 82))
		end
	end
	Net.Changed:Connect(function()
		if Panels.isOpen("Upgrade") then
			refresh()
		end
	end)
end

return Upgrade
