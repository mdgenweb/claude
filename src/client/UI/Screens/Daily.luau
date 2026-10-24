-- Rewards: the daily contract (30 smashes -> 100 Scrap + a stamp; five stamps unlock
-- Stamped Chrome) and the workshop (40 Scrap an hour, capped at 240, even offline).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Theme = require(Shared.Theme)

local UI = script.Parent.Parent
local UIKit = require(UI.UIKit)
local Copy = require(UI.Copy)
local Panels = require(UI.Panels)
local Toasts = require(UI.Toasts)
local Net = require(UI.Parent.Net)

local Daily = {}

local refs: { [string]: any } = {}

local function card(parent: Instance, title: string, swatch: Theme.Swatch, position: UDim2)
	local c = UIKit.surface(parent, {
		Size = UDim2.fromOffset(350, 360),
		Position = position,
		Swatch = Theme.Swatch.Navy,
		Radius = Theme.Radius.L,
		Shine = false,
	})
	local header = UIKit.surface(c.Face, {
		Size = UDim2.new(1, -24, 0, 48),
		Position = UDim2.fromOffset(12, 12),
		Swatch = swatch,
		Radius = Theme.Radius.M,
		ShadowOffset = 3,
	})
	UIKit.text(header.Face, { Text = title, TextSize = 28 })
	return c.Face
end

local function claim(action: string)
	local ok, msg = Net.request(action)
	if not ok then
		Toasts.error(msg)
	end
end

function Daily.refresh()
	local s = Net.State
	if not s then
		return
	end
	local goal = Config.Daily.Goal
	local progress = math.min(s.Daily.Progress, goal)
	refs.ContractBar:Set(
		progress / goal,
		string.format("%d / %d", progress, goal),
		if progress >= goal then Theme.Swatch.Green else Theme.Swatch.Yellow
	)
	for i, stamp in refs.Stamps do
		local filled = i <= math.min(s.Stamps, Config.Daily.StampsForFinish)
		UIKit.setSwatch(stamp.Gradient, if filled then Theme.Swatch.Yellow else Theme.Swatch.Steel)
		stamp.Label.Text = if filled then "✓" else ""
	end
	refs.StampText.Text =
		string.format(Copy.Daily.Stamps, math.min(s.Stamps, Config.Daily.StampsForFinish), Config.Daily.StampsForFinish)
	if s.Daily.Claimed then
		refs.ContractButton:SetText(Copy.Daily.Claimed)
		refs.ContractButton:SetEnabled(false)
	else
		refs.ContractButton:SetText(Copy.Daily.Claim)
		refs.ContractButton:SetEnabled(progress >= goal)
	end
	Daily.refreshWorkshop()
end

function Daily.refreshWorkshop()
	local stored = Net.workshopStored()
	local cap = Config.Workshop.Cap
	refs.WorkshopAmount.Text = string.format("⚙️ %d / %d", math.floor(stored), cap)
	refs.WorkshopBar:Set(stored / cap, nil, if stored >= cap then Theme.Swatch.Green else Theme.Swatch.Yellow)
	if stored >= cap then
		refs.WorkshopTime.Text = Copy.Daily.WorkshopFull
	else
		local seconds = (cap - stored) / Config.Workshop.RatePerHour * 3600
		refs.WorkshopTime.Text = string.format(Copy.Daily.WorkshopTime, Economy.formatTime(seconds))
	end
	refs.WorkshopButton:SetText(string.format("%s %d", Copy.Daily.Claim, math.floor(stored)))
	refs.WorkshopButton:SetEnabled(stored >= 1)
end

function Daily.init()
	local panel = Panels.create({
		Name = "Daily",
		Title = Copy.Daily.Title,
		Icon = "📋",
		Swatch = Theme.Swatch.Yellow,
		Width = 780,
		Height = 470,
		TabWidth = 280,
	})
	local body = panel.Body

	local contract = card(body, Copy.Daily.Contract, Theme.Swatch.Orange, UDim2.fromOffset(6, 10))
	UIKit.text(contract, {
		Text = string.format(Copy.Daily.ContractTask, Config.Daily.Goal),
		TextSize = 24,
		Size = UDim2.new(1, -24, 0, 30),
		Position = UDim2.fromOffset(12, 72),
	})
	refs.ContractBar = UIKit.progress(
		contract,
		{ Size = UDim2.new(1, -40, 0, 30), Position = UDim2.fromOffset(20, 112), TextSize = 18 }
	)
	UIKit.text(contract, {
		Text = Copy.Daily.ContractReward,
		TextSize = 20,
		Font = Theme.Font.Body,
		Size = UDim2.new(1, -24, 0, 26),
		Position = UDim2.fromOffset(12, 152),
	})
	local stamps = UIKit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -24, 0, 50),
		Position = UDim2.fromOffset(12, 186),
		Parent = contract,
	})
	UIKit.list(stamps, false, 10)
	refs.Stamps = {}
	for i = 1, Config.Daily.StampsForFinish do
		local stamp = UIKit.surface(stamps, {
			Size = UDim2.fromOffset(44, 44),
			Swatch = Theme.Swatch.Steel,
			Radius = 999,
			ShadowOffset = 3,
			LayoutOrder = i,
		})
		refs.Stamps[i] = { Gradient = stamp.Gradient, Label = UIKit.text(stamp.Face, { Text = "", TextSize = 22 }) }
	end
	refs.StampText = UIKit.text(contract, {
		Text = "",
		TextSize = 15,
		Font = Theme.Font.Body,
		Color = Theme.Muted,
		Size = UDim2.new(1, -24, 0, 22),
		Position = UDim2.fromOffset(12, 242),
	})
	refs.ContractButton = UIKit.button(contract, {
		Text = Copy.Daily.Claim,
		TextSize = 28,
		Size = UDim2.new(1, -60, 0, 60),
		Position = UDim2.new(0.5, 0, 1, -18),
		AnchorPoint = Vector2.new(0.5, 1),
		OnClick = function()
			claim("ClaimDaily")
		end,
		OnDisabledClick = function()
			local s = Net.State
			if s and not s.Daily.Claimed then
				Toasts.error(string.format("Smash %d more junk first", Config.Daily.Goal - s.Daily.Progress))
			end
		end,
	})

	local workshop = card(body, Copy.Daily.Workshop, Theme.Swatch.Blue, UDim2.new(1, -356, 0, 10))
	refs.WorkshopAmount = UIKit.text(workshop, {
		Text = "",
		TextSize = 40,
		Color = Theme.ScrapGold,
		Size = UDim2.new(1, -24, 0, 46),
		Position = UDim2.fromOffset(12, 72),
	})
	UIKit.text(workshop, {
		Text = Copy.Daily.WorkshopRate,
		TextSize = 17,
		Font = Theme.Font.Body,
		Size = UDim2.new(1, -24, 0, 44),
		Position = UDim2.fromOffset(12, 122),
	})
	refs.WorkshopBar =
		UIKit.progress(workshop, { Size = UDim2.new(1, -40, 0, 26), Position = UDim2.fromOffset(20, 176) })
	refs.WorkshopTime = UIKit.text(workshop, {
		Text = "",
		TextSize = 16,
		Font = Theme.Font.Body,
		Color = Theme.Muted,
		Size = UDim2.new(1, -24, 0, 24),
		Position = UDim2.fromOffset(12, 212),
	})
	refs.WorkshopButton = UIKit.button(workshop, {
		Text = Copy.Daily.Claim,
		TextSize = 28,
		Size = UDim2.new(1, -60, 0, 60),
		Position = UDim2.new(0.5, 0, 1, -18),
		AnchorPoint = Vector2.new(0.5, 1),
		OnClick = function()
			claim("ClaimWorkshop")
		end,
	})

	panel.OnOpen = Daily.refresh
	Net.Changed:Connect(function()
		if Panels.isOpen("Daily") then
			Daily.refresh()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if Panels.isOpen("Daily") then
				Daily.refreshWorkshop()
			end
		end
	end)
end

return Daily
