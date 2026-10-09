--!strict
-- Always-on HUD (UIController layer "HUD"), laid out like the genre (docs/DESIGN.md §6) with
-- original art:
--   left         2-column menu tiles (Shop, Rebirth %, Pets, Trails, Inventory, Gifts badge),
--                Settings gear and an Admin tile for admins; fades during the local flight
--   bottom-left  Rebirths, Wins and "Friend Boost +X%" (green + opens the invite prompt)
--   bottom-mid   Skill / multiplier row, level bar, three Robux Skill packs
--   top-mid      AUTO THROW (buy prompt or ON/OFF toggle); flight counter + banners below it
--   right        potion timers above the Starter Pack / 2x Skill / 2x Wins offers
-- Contextual pieces live in Hud* components: throw button + launch meter, flight overlay (counter,
-- zone banner, special banner, TAP!, combo, tap area) and the landing card.
-- Every button only sends intents (Net.Invoke / Net.Fire); the server decides all outcomes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monetization = require(Shared.Config.Monetization)
local Boosts = require(Shared.Definitions.Boosts)
local Rewards = require(Shared.Definitions.Rewards)
local Worlds = require(Shared.Definitions.Worlds)
local Format = require(Shared.Util.Format)

local Client = script.Parent.Parent.Parent
local StateController = require(Client.Controllers.StateController)
local UIController = require(Client.Controllers.UIController)
local AudioController = require(Client.Controllers.AudioController)
local Net = require(Client.Controllers.Net)
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local Components = Client.UI.Components
local Button = require(Components.Button)
local HudTile = require(Components.HudTile)
local HudStatPill = require(Components.HudStatPill)
local HudLevelBar = require(Components.HudLevelBar)
local HudThrowPanel = require(Components.HudThrowPanel)
local HudFlightOverlay = require(Components.HudFlightOverlay)
local HudLandingCard = require(Components.HudLandingCard)
local HudFlightState = require(Components.HudFlightState)

local HUD = {}

local hex = Color3.fromHex
local IS_STUDIO = RunService:IsStudio()
local MARGIN = 18
local POP = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- bottom-centre stack (design px, measured from the bottom edge)
local PACK_H = 66
local STACK_GAP = 8
HUD.BottomStack = 12 + PACK_H + STACK_GAP + HudLevelBar.Height -- top of the level block
HUD.ContextBottom = HUD.BottomStack + 14 -- where contextual panels (throw / pad) sit
HUD.CounterTop = 92 -- flight counter top when no tutorial bar is shown
HUD.CounterTopTutorial = 166

local function purchaseAvailable(id: number): boolean
	return id ~= 0 or IS_STUDIO
end

local function purchase(kind: string, key: string)
	task.spawn(Net.Invoke, "RequestPurchase", false, kind, key)
end

-- Left menu ---------------------------------------------------------------------------------------
type MenuRefs = { Group: CanvasGroup, Rebirth: HudTile.Tile, Gifts: HudTile.Tile, Admin: HudTile.Tile }

local function buildMenu(root: Frame): MenuRefs
	local TILE = 92
	local GAP = 10
	local PAD = 16
	local width = TILE * 2 + GAP + PAD * 2
	local height = TILE * 3 + GAP * 2 + GAP + 70 + PAD * 2
	local group: CanvasGroup = Create("CanvasGroup", {
		Name = "Menu",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, MARGIN - PAD, 0.5, -70),
		Size = UDim2.fromOffset(width, height),
		ZIndex = 2,
		Parent = root,
	})
	local grid: Frame = Create("Frame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAD, PAD),
		Size = UDim2.fromOffset(TILE * 2 + GAP, TILE * 3 + GAP * 2),
		Parent = group,
	})
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(TILE, TILE)
	layout.CellPadding = UDim2.fromOffset(GAP, GAP)
	layout.FillDirectionMaxCells = 2
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	local function tile(order: number, name: string, icon: string, label: string, top: string, bottom: string): HudTile.Tile
		return HudTile.new({
			Parent = grid,
			Name = name,
			Icon = icon,
			Label = label,
			Size = TILE,
			Top = hex(top),
			Bottom = hex(bottom),
			LayoutOrder = order,
			OnClick = function()
				UIController.Toggle(name)
			end,
		})
	end
	tile(1, "Shop", Theme.Icons.Shop, "Shop", "#FF8FC8", "#D7267A")
	local rebirth = tile(2, "Rebirth", Theme.Icons.Rebirth, "Rebirth", "#7FD8FF", "#2563EB")
	tile(3, "Pets", Theme.Icons.Pets, "Pets", "#FFB86B", "#E06A00")
	tile(4, "Trails", Theme.Icons.Trails, "Trails", "#C98CFF", "#7A2BD6")
	tile(5, "Inventory", Theme.Icons.Inventory, "Items", "#B4E36B", "#4E9A1E")
	local gifts = tile(6, "Gifts", Theme.Icons.Gifts, "Gifts", "#FF7B7B", "#C81E3A")

	local row: Frame = Create("Frame", {
		Name = "Extras",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAD, PAD + TILE * 3 + GAP * 3),
		Size = UDim2.fromOffset(TILE * 2 + GAP, 70),
		Parent = group,
	})
	Create.List(row, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	HudTile.new({
		Parent = row,
		Name = "Settings",
		Icon = Theme.Icons.Settings,
		Size = 66,
		Round = true,
		Top = hex("#E9EEF5"),
		Bottom = hex("#8C96A8"),
		LayoutOrder = 1,
		OnClick = function()
			UIController.Toggle("Settings")
		end,
	})
	local admin = HudTile.new({
		Parent = row,
		Name = "Admin",
		Icon = "🛠️",
		Size = 66,
		Top = hex("#FF6B6B"),
		Bottom = hex("#7A0A0A"),
		LayoutOrder = 2,
		OnClick = function()
			UIController.Toggle("Admin")
		end,
	})
	admin.Instance.Visible = false
	return { Group = group, Rebirth = rebirth, Gifts = gifts, Admin = admin }
end

-- Bottom-left counters ----------------------------------------------------------------------------
type CounterRefs = { Rebirths: HudStatPill.Pill, Wins: HudStatPill.Pill, Friends: HudStatPill.Pill }

local function buildCounters(root: Frame): CounterRefs
	local holder: Frame = Create("Frame", {
		Name = "Counters",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, MARGIN + 6, 1, -MARGIN),
		Size = UDim2.fromOffset(340, 3 * 52 + 2 * 12 + 8),
		ZIndex = 2,
		Parent = root,
	})
	Create.List(holder, Enum.FillDirection.Vertical, 12, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Bottom)
	local rebirths = HudStatPill.new({
		Parent = holder,
		Name = "Rebirths",
		Icon = Theme.Icons.Rebirth,
		Color = hex("#FFB3DA"),
		Badge = Theme.Colors.Rebirth,
		Width = 200,
		LayoutOrder = 1,
	})
	local wins = HudStatPill.new({
		Parent = holder,
		Name = "Wins",
		Icon = Theme.Icons.Wins,
		Color = Theme.Colors.Wins,
		Badge = hex("#F2A900"),
		Width = 250,
		LayoutOrder = 2,
	})
	local friendRow: Frame = Create("Frame", {
		Name = "FriendRow",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(340, 60),
		LayoutOrder = 3,
		Parent = holder,
	})
	local friends = HudStatPill.new({
		Parent = friendRow,
		Name = "FriendBoost",
		Icon = Theme.Icons.Friends,
		Color = hex("#9CFF7A"),
		Badge = hex("#2FA80F"),
		Width = 266,
	})
	friends.Instance.AnchorPoint = Vector2.new(0, 0.5)
	friends.Instance.Position = UDim2.fromScale(0, 0.5)
	friends:SetText("Friend Boost +0%")
	local invite = Button.new({
		Parent = friendRow,
		Name = "Invite",
		Size = UDim2.fromOffset(60, 60),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 274, 0.5, 0),
		Style = "Green",
		Text = "+",
		TextSize = 46,
		Corner = 30,
		OnClick = function()
			pcall(function()
				SocialService:PromptGameInvite(Players.LocalPlayer)
			end)
		end,
	})
	invite.Label.Size = UDim2.fromScale(0.75, 0.75)
	return { Rebirths = rebirths, Wins = wins, Friends = friends }
end

-- Bottom-centre: level block + Skill packs ---------------------------------------------------------
type PackRef = { Button: Button.Button, Key: string, Amount: number, Price: TextLabel, Rainbow: UIGradient? }

local PACKS = {
	{ Key = "Skill10K", Style = "Gold" },
	{ Key = "Skill100K", Style = "Red" },
	{ Key = "Skill1M", Style = "Gold", Rainbow = true },
}

local function buildBottom(root: Frame): (HudLevelBar.LevelBar, { PackRef })
	local holder: Frame = Create("Frame", {
		Name = "Bottom",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(660, HudLevelBar.Height + STACK_GAP + PACK_H),
		ZIndex = 2,
		Parent = root,
	})
	Create.List(holder, Enum.FillDirection.Vertical, STACK_GAP, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom)
	local levelBar = HudLevelBar.new(holder, 1)

	local row: Frame = Create("Frame", {
		Name = "Packs",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(660, PACK_H),
		LayoutOrder = 2,
		Parent = holder,
	})
	Create.List(row, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	local packs: { PackRef } = {}
	for i, spec in PACKS do
		local product = Monetization.Product(spec.Key)
		if not product then
			continue
		end
		local key = spec.Key
		local button = Button.new({
			Parent = row,
			Name = key,
			Size = UDim2.fromOffset(206, PACK_H),
			Style = spec.Style,
			Text = "",
			TextSize = 34,
			Corner = 14,
			LayoutOrder = i,
			OnClick = function()
				purchase("Product", key)
			end,
		})
		button.Label.Size = UDim2.new(1, -16, 0.56, 0)
		button.Label.Position = UDim2.fromScale(0.5, 0.36)
		local price = Create.Text({
			Name = "Price",
			Text = "",
			Size = UDim2.new(1, -16, 0.34, 0),
			Position = UDim2.fromScale(0.5, 0.78),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Font = Theme.Fonts.Display,
			TextSize = 22,
			Scaled = true,
			Color = hex("#E9FFE0"),
			Stroke = 2,
			ZIndex = button.Instance.ZIndex + 2,
			Parent = button.Content,
		})
		local rainbow: UIGradient? = nil
		if spec.Rainbow then
			local gradient = button.Instance:FindFirstChildOfClass("UIGradient")
			if gradient then
				gradient.Color = Theme.Rainbow
				gradient.Rotation = 0
				rainbow = gradient
			end
		end
		if not purchaseAvailable(product.Id) then
			button:SetEnabled(false)
		end
		table.insert(packs, { Button = button, Key = key, Amount = product.Amount or 0, Price = price, Rainbow = rainbow })
	end
	return levelBar, packs
end

-- Top-centre AUTO THROW ---------------------------------------------------------------------------
type AutoRefs = { Button: Button.Button, Sub: TextLabel }

local function buildAuto(root: Frame, onClick: () -> ()): AutoRefs
	local button = Button.new({
		Parent = root,
		Name = "AutoThrow",
		Size = UDim2.fromOffset(276, 80),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Style = "Red",
		Text = Theme.Icons.Auto .. " AUTO THROW",
		TextSize = 36,
		Corner = 16,
		ZIndex = 3,
		OnClick = onClick,
	})
	button.Label.Size = UDim2.new(1, -18, 0.56, 0)
	button.Label.Position = UDim2.fromScale(0.5, 0.36)
	local sub = Create.Text({
		Name = "Sub",
		Text = "",
		Size = UDim2.new(1, -18, 0.32, 0),
		Position = UDim2.fromScale(0.5, 0.78),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = Theme.Fonts.Display,
		TextSize = 24,
		Scaled = true,
		Color = hex("#FFF2B3"),
		Stroke = 2,
		ZIndex = button.Instance.ZIndex + 2,
		Parent = button.Content,
	})
	return { Button = button, Sub = sub }
end

-- Right: offers + potion timers --------------------------------------------------------------------
type OfferRef = { Tile: HudTile.Tile, Kind: string, Key: string, Owned: (data: { [string]: any }) -> boolean }
type ChipRef = { Frame: Frame, Time: TextLabel, Id: string }

local function priceChip(parent: GuiObject, text: string)
	local chip: Frame = Create("Frame", {
		Name = "Price",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(84, 30),
		BackgroundColor3 = hex("#2FA80F"),
		ZIndex = 6,
		Parent = parent,
	})
	Create.Round(chip)
	Create.Stroke(chip, Theme.Colors.Stroke, 2.5, 0, true)
	Create.Text({
		Name = "Text",
		Text = text,
		Size = UDim2.fromScale(0.86, 0.8),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = Theme.Fonts.Display,
		TextSize = 22,
		Scaled = true,
		Stroke = 2,
		ZIndex = 7,
		Parent = chip,
	})
end

local function buildRight(root: Frame): ({ OfferRef }, { ChipRef })
	local TILE = 100
	local GAP = 26
	local offersHeight = TILE * 3 + GAP * 2 + 16
	local column: Frame = Create("Frame", {
		Name = "Offers",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -MARGIN, 0.5, 30),
		Size = UDim2.fromOffset(TILE + 8, offersHeight),
		ZIndex = 2,
		Parent = root,
	})
	Create.List(column, Enum.FillDirection.Vertical, GAP, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)

	local offers: { OfferRef } = {}
	local function offer(order: number, kind: string, key: string, icon: string, label: string, top: string, bottom: string, owned: (data: { [string]: any }) -> boolean)
		local id = 0
		local robux = 0
		if kind == "Pass" then
			local pass = Monetization.Pass(key)
			id, robux = if pass then pass.Id else 0, if pass then pass.Robux else 0
		else
			local product = Monetization.Product(key)
			id, robux = if product then product.Id else 0, if product then product.Robux else 0
		end
		local available = purchaseAvailable(id)
		local tile = HudTile.new({
			Parent = column,
			Name = key,
			Icon = icon,
			Label = label,
			Size = TILE,
			Top = hex(if available then top else "#8C93A3"),
			Bottom = hex(if available then bottom else "#5A6070"),
			LayoutOrder = order,
			OnClick = function()
				if available then
					purchase(kind, key)
				else
					UIController.Toast("Coming soon!", "Info")
				end
			end,
		})
		priceChip(tile.Instance, if available then Theme.Icons.Robux .. tostring(robux) else "SOON")
		table.insert(offers, { Tile = tile, Kind = kind, Key = key, Owned = owned })
	end
	offer(1, "Product", "StarterPack", Theme.Icons.Star, "Starter", "#FFE27A", "#F07800", function(data)
		return type(data.Flags) == "table" and data.Flags.StarterPack == true
	end)
	offer(2, "Pass", "DoubleSkill", Theme.Icons.Skill, "2x SKILL", "#7FD8FF", "#2563EB", function()
		return StateController.HasPass("DoubleSkill")
	end)
	offer(3, "Pass", "DoubleWins", Theme.Icons.Wins, "2x WINS", "#9CFF7A", "#2FA80F", function()
		return StateController.HasPass("DoubleWins")
	end)

	-- potion timers stack upward from just above the offers
	local chipsHolder: Frame = Create("Frame", {
		Name = "Potions",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -MARGIN, 0.5, 30 - offersHeight / 2 - 12),
		Size = UDim2.fromOffset(180, 3 * 44 + 2 * 8),
		ZIndex = 2,
		Parent = root,
	})
	Create.List(chipsHolder, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom)
	local STAT_ICON: { [string]: string } = { Skill = Theme.Icons.Skill, Wins = Theme.Icons.Wins, Luck = Theme.Icons.Luck }
	local chips: { ChipRef } = {}
	for i, boost in Boosts.List do
		local chip: Frame = Create("Frame", {
			Name = boost.Id,
			Size = UDim2.fromOffset(176, 44),
			BackgroundColor3 = Theme.Colors.PanelDeep,
			BackgroundTransparency = 0.2,
			LayoutOrder = i,
			Visible = false,
			Parent = chipsHolder,
		})
		Create.Round(chip)
		Create.Stroke(chip, hex(boost.Color), 3, 0, true)
		Create.Text({
			Name = "Label",
			Text = (STAT_ICON[boost.Stat] or Theme.Icons.Potion) .. " x" .. tostring(boost.Multiplier),
			Size = UDim2.new(0.48, 0, 0.8, 0),
			Position = UDim2.new(0, 10, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Font = Theme.Fonts.Display,
			TextSize = 26,
			Scaled = true,
			Color = hex(boost.Color),
			Stroke = 2.5,
			XAlign = Enum.TextXAlignment.Left,
			Parent = chip,
		})
		local time = Create.Text({
			Name = "Time",
			Text = "",
			Size = UDim2.new(0.48, 0, 0.74, 0),
			Position = UDim2.new(1, -12, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Font = Theme.Fonts.Display,
			TextSize = 24,
			Scaled = true,
			Stroke = 2.5,
			XAlign = Enum.TextXAlignment.Right,
			Parent = chip,
		})
		table.insert(chips, { Frame = chip, Time = time, Id = boost.Id })
	end
	return offers, chips
end

-- Init --------------------------------------------------------------------------------------------
function HUD.Init()
	local root = UIController.Layer("HUD")

	local menu = buildMenu(root)
	local counters = buildCounters(root)
	local levelBar, packs = buildBottom(root)
	local offers, chips = buildRight(root)
	HudThrowPanel.new(root, HUD.ContextBottom)
	local overlay = HudFlightOverlay.new(root)
	HudLandingCard.new(root)

	-- AUTO THROW: buy prompt until owned, then an ON/OFF toggle (optimistic until the next sync)
	local pendingAuto: boolean? = nil
	local auto: AutoRefs
	local function autoOn(): boolean
		if pendingAuto ~= nil then
			return pendingAuto
		end
		local data = StateController.Data
		return data ~= nil and type(data.Settings) == "table" and data.Settings.AutoThrow == true
	end
	local function refreshAuto()
		local pass = Monetization.Pass("AutoThrow")
		if StateController.HasPass("AutoThrow") then
			local on = autoOn()
			auto.Button:SetStyle(if on then "Green" else "Red")
			auto.Button:SetText(Theme.Icons.Auto .. " AUTO THROW")
			auto.Sub.Text = if on then "ON" else "OFF"
		else
			auto.Button:SetStyle("Red")
			auto.Button:SetText(Theme.Icons.Auto .. " AUTO THROW")
			if pass and purchaseAvailable(pass.Id) then
				auto.Sub.Text = "ONLY " .. Theme.Icons.Robux .. tostring(pass.Robux)
			else
				auto.Sub.Text = "COMING SOON"
			end
		end
	end
	auto = buildAuto(root, function()
		if StateController.HasPass("AutoThrow") then
			local on = not autoOn()
			pendingAuto = on
			Net.Fire("RequestToggle", "AutoThrow", on)
			refreshAuto()
		else
			purchase("Pass", "AutoThrow")
		end
	end)

	-- level-up flash (throttled: early levels arrive several per second)
	local FLASH_EVERY = 1.3
	local lastFlash = -math.huge
	local pendingLevel: number? = nil
	local flashScheduled = false
	local glow: Frame = Create("Frame", {
		Name = "LevelGlow",
		BackgroundColor3 = hex("#7FFFD4"),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 1,
		Parent = root,
	})
	local glowGradient = Instance.new("UIGradient")
	glowGradient.Rotation = 90
	glowGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.55, 1),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	glowGradient.Parent = glow
	local function flashLevel()
		flashScheduled = false
		local level = pendingLevel
		if level == nil then
			return
		end
		pendingLevel = nil
		lastFlash = os.clock()
		levelBar:FlashLevel(level)
		AudioController.Play("LevelUp", nil, 0.8)
		glow.Visible = true
		glow.BackgroundTransparency = 0.35
		local t = TweenService:Create(glow, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
		t:Play()
		t.Completed:Once(function()
			if glow.BackgroundTransparency >= 0.99 then
				glow.Visible = false
			end
		end)
	end
	local function queueLevelFlash(level: number)
		pendingLevel = level
		if flashScheduled then
			return
		end
		local wait = lastFlash + FLASH_EVERY - os.clock()
		if wait <= 0 then
			flashLevel()
		else
			flashScheduled = true
			task.delay(wait, flashLevel)
		end
	end

	-- timers (gift badge, potion chips) -----------------------------------------------------------
	local function refreshTimers()
		local data = StateController.Data
		if not data then
			return
		end
		local since = StateController.Since()
		-- claimable gifts
		local count = 0
		local session = data.Session
		if type(session) == "table" then
			local playtime = (tonumber(session.Playtime) or 0) + since
			local claimed = if type(session.GiftsClaimed) == "table" then session.GiftsClaimed else {}
			for _, gift in Rewards.Gifts do
				if playtime >= gift.Minutes * 60 and table.find(claimed, gift.Index) == nil then
					count += 1
				end
			end
		end
		if data.DailyReady == true then
			count += 1
		end
		menu.Gifts:SetBadge(count)
		-- potion timers
		local derived = if type(data.Derived) == "table" then data.Derived else {}
		local now = (tonumber(derived.ServerTime) or os.time()) + since
		local boosts = if type(data.Boosts) == "table" then data.Boosts else {}
		for _, chip in chips do
			local expiry = tonumber(boosts[chip.Id]) or 0
			local remaining = expiry - now
			if remaining > 0 then
				chip.Time.Text = if remaining >= 3600 then Format.Duration(remaining) else Format.Clock(remaining)
				chip.Frame.Visible = true
			else
				chip.Frame.Visible = false
			end
		end
	end

	-- data -> HUD ---------------------------------------------------------------------------------
	local function refresh(data: { [string]: any }, previous: { [string]: any }?)
		local derived = if type(data.Derived) == "table" then data.Derived else {}
		pendingAuto = nil

		-- left menu
		local progress = math.clamp(tonumber(derived.RebirthProgress) or 0, 0, 1)
		menu.Rebirth:SetCaption(Format.Percent(progress * 100))
		menu.Rebirth:SetGlow(progress >= 1)
		menu.Admin.Instance.Visible = data.IsAdmin == true

		-- counters
		counters.Rebirths:SetText(Format.Commas(tonumber(data.Rebirths) or 0))
		counters.Wins:SetText(Format.Short(tonumber(data.Wins) or 0))
		counters.Friends:SetText(string.format("Friend Boost +%d%%", math.floor((tonumber(derived.FriendBoost) or 0) * 100 + 0.5)))
		if previous then
			if (tonumber(data.Wins) or 0) > (tonumber(previous.Wins) or 0) then
				counters.Wins:Bump()
			end
			if (tonumber(data.Rebirths) or 0) > (tonumber(previous.Rebirths) or 0) then
				counters.Rebirths:Bump()
			elseif (tonumber(data.Level) or 1) > (tonumber(previous.Level) or 1) then
				queueLevelFlash(tonumber(data.Level) or 1)
			end
		end

		-- level block + packs
		levelBar:Update(data)
		local world = Worlds.Get(tonumber(data.World) or 1)
		local packScale = if world then world.SkillPackScale else 1
		for _, pack in packs do
			local product = Monetization.Product(pack.Key)
			local available = product ~= nil and purchaseAvailable(product.Id)
			pack.Button:SetText(Theme.Icons.Skill .. "+" .. Format.Short(pack.Amount * packScale))
			pack.Price.Text = if available and product then Theme.Icons.Robux .. tostring(product.Robux) else "SOON"
		end

		-- offers
		for _, offer in offers do
			offer.Tile.Instance.Visible = not offer.Owned(data)
		end

		refreshAuto()
		overlay:SetCounterTop(if type(data.Tutorial) == "table" and data.Tutorial.Done == false then HUD.CounterTopTutorial else HUD.CounterTop)
		refreshTimers()
	end

	StateController.DataChanged:Connect(function(data: any, previous: any)
		if type(data) == "table" then
			refresh(data, if type(previous) == "table" then previous else nil)
		end
	end)
	if StateController.Data then
		refresh(StateController.Data, nil)
	else
		refreshAuto()
	end

	-- flight: fade the left menu for a clean view
	HudFlightState.Changed:Connect(function(active: any)
		TweenService:Create(menu.Group, TweenInfo.new(0.3), { GroupTransparency = if active then 0.6 else 0 }):Play()
	end)

	-- one ticker for pulses (~20 Hz) and countdowns (1 Hz)
	local animAcc, timerAcc = 0, 0
	RunService.Heartbeat:Connect(function(dt: number)
		animAcc += dt
		timerAcc += dt
		if animAcc >= 0.05 then
			animAcc = 0
			local t = os.clock()
			menu.Rebirth:Animate(t)
			levelBar:Animate(t)
			for _, pack in packs do
				local rainbow = pack.Rainbow
				if rainbow then
					rainbow.Offset = Vector2.new(math.sin(t * 1.5) * 0.25, 0)
				end
			end
		end
		if timerAcc >= 1 then
			timerAcc = 0
			refreshTimers()
		end
	end)

	-- pop the HUD in once
	local intro = Instance.new("UIScale")
	intro.Scale = 0.85
	intro.Parent = menu.Group
	TweenService:Create(intro, POP, { Scale = 1 }):Play()
end

return HUD
