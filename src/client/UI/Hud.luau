-- Always-on HUD: Scrap & Power counters, left menu stack, Boost / Auto buttons,
-- the "next upgrade" widget (the concept's nearby next goal) and the next-gate chip.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Theme = require(Shared.Theme)

local UIKit = require(script.Parent.UIKit)
local Gui = require(script.Parent.Gui)
local Copy = require(script.Parent.Copy)
local Panels = require(script.Parent.Panels)
local Toasts = require(script.Parent.Toasts)
local Net = require(script.Parent.Parent.Net)
local Sound = require(script.Parent.Parent.Controllers.Sound)
local AutoFarm = require(script.Parent.Parent.Controllers.AutoFarm)

local Hud = {}

local refs: { [string]: any } = {}
local shownScrap = 0
local scrapValue: NumberValue

local function milestoneIcon(level: number): string
	local icons = { "💥", "💪", "🔨", "🤖", "🛡️", "🦾", "🚀", "☢️", "👑" }
	return icons[level] or "⚡"
end

-- Top bar -------------------------------------------------------------------------

local function buildTopBar(layer: Frame)
	local top = UIKit.new("Frame", {
		Name = "TopBar",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(540, 100),
		Position = UDim2.new(0.5, 0, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = layer,
	})
	local scrap = UIKit.surface(top, {
		Name = "Scrap",
		Size = UDim2.fromOffset(290, 58),
		Position = UDim2.fromOffset(30, 10),
		Swatch = Theme.Swatch.Navy,
		Radius = 999,
	})
	local coin = UIKit.surface(top, {
		Name = "Coin",
		Size = UDim2.fromOffset(74, 74),
		Position = UDim2.fromOffset(0, 2),
		Swatch = Theme.Swatch.Yellow,
		Radius = 999,
		ZIndex = 3,
	})
	UIKit.icon(coin.Face, "⚙️", UDim2.fromScale(0.7, 0.7), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	local amount = UIKit.text(scrap.Face, {
		Name = "Amount",
		Text = "0",
		TextSize = 40,
		Size = UDim2.new(1, -66, 0.9, 0),
		Position = UDim2.new(0, 56, 0.05, 0),
		XAlign = Enum.TextXAlignment.Left,
		Color = Theme.ScrapGold,
	})
	local power = UIKit.surface(top, {
		Name = "Power",
		Size = UDim2.fromOffset(196, 50),
		Position = UDim2.fromOffset(340, 14),
		Swatch = Theme.Swatch.Navy,
		Radius = 999,
	})
	local bolt = UIKit.surface(top, {
		Name = "Bolt",
		Size = UDim2.fromOffset(60, 60),
		Position = UDim2.fromOffset(318, 9),
		Swatch = Theme.Swatch.Blue,
		Radius = 999,
		ZIndex = 3,
	})
	UIKit.icon(bolt.Face, "⚡", UDim2.fromScale(0.7, 0.7), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	local powerText = UIKit.text(power.Face, {
		Text = "1",
		TextSize = 32,
		Size = UDim2.fromScale(0.55, 0.9),
		Position = UDim2.new(0, 46, 0.05, 0),
		XAlign = Enum.TextXAlignment.Left,
		Color = Theme.PowerCyan,
	})
	UIKit.text(power.Face, {
		Text = Copy.Hud.Power,
		TextSize = 16,
		Size = UDim2.fromScale(0.34, 0.6),
		Position = UDim2.fromScale(0.62, 0.2),
		Font = Theme.Font.Body,
		Color = Theme.Muted,
	})
	local multi = UIKit.chip(top, {
		Name = "Multiplier",
		Text = "x2 SCRAP",
		Size = UDim2.fromOffset(150, 30),
		Position = UDim2.fromOffset(100, 70),
		Swatch = Theme.Swatch.Green,
	})
	multi.Holder.Visible = false
	refs.Coin = coin.Holder
	refs.ScrapAmount = amount
	refs.ScrapPill = scrap.Holder
	refs.PowerText = powerText
	refs.Multiplier = multi

	scrapValue = Instance.new("NumberValue")
	scrapValue.Changed:Connect(function(v)
		amount.Text = Economy.format(v)
	end)
end

-- Left menu stack ---------------------------------------------------------------------

local function buildNav(layer: Frame)
	local nav = UIKit.new("Frame", {
		Name = "Nav",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(96, 500),
		Position = UDim2.new(0, 18, 0.5, 10),
		AnchorPoint = Vector2.new(0, 0.5),
		Parent = layer,
	})
	UIKit.list(nav, true, 22, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	local items = {
		{ "Shop", Copy.Nav.Shop, "🛒", Theme.Swatch.Green },
		{ "Upgrade", Copy.Nav.Upgrade, "⚡", Theme.Swatch.Orange },
		{ "Rebirth", Copy.Nav.Rebirth, "♻️", Theme.Swatch.Purple },
		{ "Garage", Copy.Nav.Garage, "🎨", Theme.Swatch.Blue },
		{ "Daily", Copy.Nav.Daily, "📋", Theme.Swatch.Yellow },
	}
	refs.Nav = {}
	for i, item in items do
		local button = UIKit.iconButton(nav, {
			Name = item[1],
			Text = item[2],
			Icon = item[3],
			Swatch = item[4],
			LayoutOrder = i,
			OnClick = function()
				Panels.toggle(item[1])
			end,
		})
		refs.Nav[item[1]] = button
	end
end

-- Right side: Boost & Auto -------------------------------------------------------------

local function buildRight(layer: Frame)
	local right = UIKit.new("Frame", {
		Name = "Right",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(110, 300),
		Position = UDim2.new(1, -18, 0.5, 10),
		AnchorPoint = Vector2.new(1, 0.5),
		Parent = layer,
	})
	UIKit.list(right, true, 40, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)

	local boost = UIKit.iconButton(right, {
		Name = "Boost",
		Text = Copy.Hud.Boost,
		Icon = "🚀",
		Swatch = Theme.Swatch.Orange,
		SizePx = 88,
		LayoutOrder = 1,
		OnClick = function()
			local s = Net.State
			if s and s.BoostCharges > 0 then
				local ok, msg = Net.request("ActivateBoost")
				if not ok then
					Toasts.error(msg)
				end
			else
				Panels.open("Shop", "ScrapBoost")
			end
		end,
	})
	local boostChip = UIKit.chip(boost.Holder, {
		Text = "",
		Size = UDim2.fromOffset(96, 28),
		Position = UDim2.new(0.5, 0, 1, 20),
		AnchorPoint = Vector2.new(0.5, 0),
		Swatch = Theme.Swatch.Navy,
		TextSize = 18,
	})

	local auto = UIKit.iconButton(right, {
		Name = "Auto",
		Text = Copy.Hud.Auto,
		Icon = "🤖",
		Swatch = Theme.Swatch.Blue,
		SizePx = 88,
		LayoutOrder = 2,
		OnClick = function()
			if Players.LocalPlayer:GetAttribute("HasAutoFarm") then
				AutoFarm.toggle()
			else
				Panels.open("Shop", "AutoFarm")
			end
		end,
	})
	local autoChip = UIKit.chip(auto.Holder, {
		Text = Copy.Hud.Off,
		Size = UDim2.fromOffset(86, 28),
		Position = UDim2.new(0.5, 0, 1, 20),
		AnchorPoint = Vector2.new(0.5, 0),
		Swatch = Theme.Swatch.Steel,
		TextSize = 18,
	})
	refs.BoostChip = boostChip
	refs.AutoChip = autoChip
	refs.Boost = boost
end

-- Bottom: next upgrade + goal ---------------------------------------------------------

local function buildBottom(layer: Frame)
	local widget = UIKit.surface(layer, {
		Name = "NextUpgrade",
		Size = UDim2.fromOffset(580, 104),
		Position = UDim2.new(0.5, 0, 1, -22),
		AnchorPoint = Vector2.new(0.5, 1),
		Swatch = Theme.Swatch.Navy,
		Radius = Theme.Radius.L,
	})
	local iconBox = UIKit.surface(widget.Face, {
		Size = UDim2.fromOffset(78, 78),
		Position = UDim2.new(0, 12, 0.5, -3),
		AnchorPoint = Vector2.new(0, 0.5),
		Swatch = Theme.Swatch.Orange,
		Radius = Theme.Radius.M,
	})
	local icon =
		UIKit.icon(iconBox.Face, "⚡", UDim2.fromScale(0.7, 0.7), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	local title = UIKit.text(widget.Face, {
		Text = "",
		TextSize = 26,
		Size = UDim2.fromOffset(290, 30),
		Position = UDim2.fromOffset(104, 8),
		XAlign = Enum.TextXAlignment.Left,
	})
	local sub = UIKit.text(widget.Face, {
		Text = "",
		TextSize = 17,
		Font = Theme.Font.Body,
		Color = Theme.Muted,
		Size = UDim2.fromOffset(290, 22),
		Position = UDim2.fromOffset(104, 38),
		XAlign = Enum.TextXAlignment.Left,
	})
	local bar = UIKit.progress(
		widget.Face,
		{ Size = UDim2.fromOffset(290, 26), Position = UDim2.fromOffset(104, 66), Swatch = Theme.Swatch.Yellow }
	)
	local button = UIKit.button(widget.Face, {
		Name = "UpgradeButton",
		Text = Copy.Hud.UpgradeButton,
		TextSize = 28,
		Size = UDim2.fromOffset(158, 70),
		Position = UDim2.new(1, -14, 0.5, -3),
		AnchorPoint = Vector2.new(1, 0.5),
		Swatch = Theme.Swatch.Green,
		OnClick = function()
			local s = Net.State
			if s and not Economy.nextUpgrade(s.Level) then
				Panels.open("Rebirth")
				return
			end
			local ok, msg = Net.request("Upgrade")
			if not ok then
				Toasts.error(msg)
			end
		end,
		OnDisabledClick = function()
			local s = Net.State
			local nextUp = s and Economy.nextUpgrade(s.Level)
			if nextUp then
				Toasts.error(string.format("Need %s more Scrap. Keep smashing!", Economy.format(nextUp.Cost - s.Scrap)))
			end
		end,
	})
	local goal = UIKit.chip(layer, {
		Name = "Goal",
		Text = "",
		Size = UDim2.fromOffset(470, 34),
		Position = UDim2.new(0.5, 0, 1, -138),
		AnchorPoint = Vector2.new(0.5, 1),
		Swatch = Theme.Swatch.Navy,
		TextSize = 19,
	})
	refs.Next = { Title = title, Sub = sub, Bar = bar, Button = button, Icon = icon }
	refs.Goal = goal

	-- First-session hint: "SMASH THE JUNK!"
	local hint = UIKit.new("Frame", {
		Name = "SmashHint",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(620, 110),
		Position = UDim2.new(0.5, 0, 1, -200),
		AnchorPoint = Vector2.new(0.5, 1),
		Visible = false,
		Parent = layer,
	})
	UIKit.text(hint, {
		Text = Copy.Hud.SmashTitle,
		TextSize = 58,
		Size = UDim2.new(1, 0, 0, 64),
		Color = Color3.fromHex("#FFB24A"),
		StrokeThickness = 5,
		Rotation = -2,
	})
	UIKit.text(hint, {
		Text = Copy.Hud.SmashSub,
		TextSize = 22,
		Font = Theme.Font.Body,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 70),
	})
	UIKit.bob(hint, 6, 1.2)
	refs.Hint = hint
	refs.Layer = layer
end

-- Updates ----------------------------------------------------------------------------

local function goalText(s): string
	for area = 2, 3 do
		if not Net.unlocked(area) then
			local def = Config.Areas[area]
			return string.format(Copy.Goal.Gate, def.Name, Economy.format(def.GatePower), Economy.format(def.GateScrap))
		end
	end
	local check = Economy.checkRebirth(s.Level, s.CrusherDestroys, s.Scrap, s.Rebirths)
	if check.maxed then
		return Copy.Goal.AllDone
	elseif check.ok then
		return Copy.Goal.RebirthReady
	elseif not check.destroysOk then
		return string.format(Copy.Goal.Rebirth, s.CrusherDestroys, Config.Rebirth.RequiredCrusherDestroys)
	end
	return string.format(Copy.Goal.RebirthFee, Economy.format(check.fee))
end

function Hud.update(s, prev)
	-- Scrap counter: count up and bump when it grows.
	if not prev then
		shownScrap = s.Scrap
		scrapValue.Value = s.Scrap
	elseif s.Scrap ~= shownScrap then
		local grew = s.Scrap > shownScrap
		shownScrap = s.Scrap
		UIKit.tween(scrapValue, 0.35, { Value = s.Scrap })
		if grew then
			UIKit.pop(refs.ScrapPill, 0.08)
		end
	end
	refs.PowerText.Text = Economy.format(s.Power)
	if prev and s.Power ~= prev.Power then
		UIKit.pop(refs.PowerText, 0.3)
	end
	local multiplier = s.Multiplier or 1
	refs.Multiplier.Holder.Visible = multiplier > 1.001
	refs.Multiplier.Label.Text =
		string.format("x%s SCRAP", (string.format("%.2f", multiplier):gsub("0+$", ""):gsub("%.$", "")))

	-- Next upgrade widget
	local nextUp = Economy.nextUpgrade(s.Level)
	local n = refs.Next
	if nextUp then
		n.Title.Text = "NEXT: ⚡" .. Economy.format(nextUp.Power) .. " POWER"
		n.Sub.Text = nextUp.Milestone
		n.Icon.Text = milestoneIcon(s.Level + 1)
		local affordable = s.Scrap >= nextUp.Cost
		n.Bar:Set(
			s.Scrap / nextUp.Cost,
			Economy.format(math.min(s.Scrap, nextUp.Cost)) .. " / " .. Economy.format(nextUp.Cost) .. " Scrap",
			if affordable then Theme.Swatch.Green else Theme.Swatch.Yellow
		)
		n.Button:SetText(Copy.Hud.UpgradeButton)
		n.Button:SetSwatch(Theme.Swatch.Green)
		n.Button:SetEnabled(affordable)
		if affordable and (not prev or prev.Scrap < nextUp.Cost or prev.Level ~= s.Level) then
			UIKit.pop(n.Button.Holder, 0.15)
		end
	else
		n.Title.Text = Copy.Hud.MaxPower
		n.Sub.Text = Copy.Hud.MaxPowerSub
		n.Icon.Text = "👑"
		n.Bar:Set(1, "⚡ " .. Economy.format(s.Power) .. " POWER", Theme.Swatch.Purple)
		n.Button:SetText(Copy.Rebirth.Button)
		n.Button:SetSwatch(Theme.Swatch.Purple)
		n.Button:SetEnabled(true)
	end
	refs.Goal.Label.Text = goalText(s)

	-- Badges: only for things the player can act on right now.
	local nav = refs.Nav
	nav.Upgrade.Badge:Set(nextUp ~= nil and s.Scrap >= nextUp.Cost)
	nav.Rebirth.Badge:Set(Economy.checkRebirth(s.Level, s.CrusherDestroys, s.Scrap, s.Rebirths).ok)
	local dailyReady = not s.Daily.Claimed and s.Daily.Progress >= Config.Daily.Goal
	nav.Daily.Badge:Set(dailyReady or Net.workshopStored() >= Config.Workshop.Cap)
	if prev and #s.Finishes > #prev.Finishes then
		nav.Garage.Badge:Set(true, "NEW")
	end

	Hud.updateBoost()
	Hud.updateAuto()

	refs.Hint.Visible = (s.Destroys or 0) == 0 and not Panels.isOpen("ToolPicker")

	if s.MemoryData and not refs.MemoryChip then
		refs.MemoryChip = UIKit.chip(refs.Layer, {
			Text = Copy.Hud.MemoryWarning,
			Size = UDim2.fromOffset(360, 26),
			Position = UDim2.new(0, 16, 1, -12),
			AnchorPoint = Vector2.new(0, 1),
			Swatch = Theme.Swatch.Red,
			TextSize = 14,
		})
	end
end

function Hud.updateBoost()
	local s = Net.State
	if not s or not refs.BoostChip then
		return
	end
	local remaining = Net.boostRemaining()
	if remaining > 0 then
		refs.BoostChip.Label.Text = Economy.formatTime(remaining)
		UIKit.setSwatch(refs.BoostChip.Gradient, if s.BoostTicking then Theme.Swatch.Green else Theme.Swatch.Steel)
	elseif s.BoostCharges > 0 then
		refs.BoostChip.Label.Text = "x" .. s.BoostCharges
		UIKit.setSwatch(refs.BoostChip.Gradient, Theme.Swatch.Orange)
	else
		refs.BoostChip.Label.Text = Copy.Hud.BoostNone
		UIKit.setSwatch(refs.BoostChip.Gradient, Theme.Swatch.Navy)
	end
end

function Hud.updateAuto()
	local owned = Players.LocalPlayer:GetAttribute("HasAutoFarm") == true
	local chip = refs.AutoChip
	if not owned then
		chip.Label.Text = "🔒"
		UIKit.setSwatch(chip.Gradient, Theme.Swatch.Navy)
	elseif AutoFarm.enabled then
		chip.Label.Text = Copy.Hud.On
		UIKit.setSwatch(chip.Gradient, Theme.Swatch.Green)
	else
		chip.Label.Text = Copy.Hud.Off
		UIKit.setSwatch(chip.Gradient, Theme.Swatch.Steel)
	end
end

function Hud.clearBadge(name: string)
	local item = refs.Nav and refs.Nav[name]
	if item and name == "Garage" then
		item.Badge:Set(false)
	end
end

-- Scrap chips fly from the smashed junk into the counter.
function Hud.flyScrap(worldPos: Vector3, amount: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local point, onScreen = camera:WorldToScreenPoint(worldPos)
	local coin = refs.Coin :: Frame
	local target = coin.AbsolutePosition + coin.AbsoluteSize / 2
	local count = math.clamp(math.floor(math.log(amount + 1, 2)), 2, 7)
	local start = if onScreen then Vector2.new(point.X, point.Y) else target + Vector2.new(0, 220)
	local layer = Gui.Layers.Fly
	for i = 1, count do
		local chip = UIKit.icon(layer, "⚙️", UDim2.fromOffset(30, 30), Gui.toRoot(start), Vector2.new(0.5, 0.5))
		local burst = Vector2.new(math.random(-70, 70), math.random(-80, -20)) / Gui.scale
		local mid = Gui.toRoot(start) + UDim2.fromOffset(burst.X, burst.Y)
		task.delay((i - 1) * 0.035, function()
			UIKit.tween(chip, 0.16, { Position = mid }, Enum.EasingStyle.Quad)
			task.wait(0.16)
			UIKit.tween(
				chip,
				0.42,
				{ Position = Gui.toRoot(target), Size = UDim2.fromOffset(18, 18) },
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			)
			task.wait(0.42)
			chip:Destroy()
			if i == 1 then
				Sound.play("Coin", nil, 1 + math.random() * 0.2)
				UIKit.pop(coin, 0.2)
			end
		end)
	end
	-- "+40" floater beside the counter.
	local pill = refs.ScrapPill :: Frame
	local floater = UIKit.text(layer, {
		Text = "+" .. Economy.format(amount),
		TextSize = 30,
		Color = Theme.Good,
		Size = UDim2.fromOffset(140, 36),
		Position = Gui.toRoot(pill.AbsolutePosition + Vector2.new(pill.AbsoluteSize.X + 10, 10)),
	})
	task.delay(0.5, function()
		UIKit.tween(floater, 0.8, { Position = floater.Position + UDim2.fromOffset(0, -30), TextTransparency = 1 })
		local stroke = floater:FindFirstChildOfClass("UIStroke")
		if stroke then
			UIKit.tween(stroke, 0.8, { Transparency = 1 })
		end
		task.wait(0.8)
		floater:Destroy()
	end)
end

function Hud.init()
	local layer = Gui.Layers.Hud
	buildTopBar(layer)
	buildNav(layer)
	buildRight(layer)
	buildBottom(layer)
	Players.LocalPlayer:GetAttributeChangedSignal("HasAutoFarm"):Connect(Hud.updateAuto)
	AutoFarm.Changed:Connect(Hud.updateAuto)
	Net.MenuChanged:Connect(function(name)
		if name then
			Hud.clearBadge(name)
		end
		if Net.State then
			Hud.update(Net.State, Net.State)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			Hud.updateBoost()
		end
	end)
end

return Hud
