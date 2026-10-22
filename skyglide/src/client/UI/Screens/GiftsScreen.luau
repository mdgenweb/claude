--!strict
-- Gifts menu ("Gifts"): the 7-day daily reward strip on top and the 12 playtime gifts below.
-- Timers are server-measured (Data.Session.Playtime) and ticked locally between syncs; CLAIM only
-- sends RequestClaimGift / RequestClaimDaily intents, the server re-checks the timer and pays.
-- Auto-opens once per session when the daily reward is ready.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rewards = require(Shared.Definitions.Rewards)
local Boosts = require(Shared.Definitions.Boosts)
local Pets = require(Shared.Definitions.Pets)
local Zones = require(Shared.Definitions.Zones)
local Format = require(Shared.Util.Format)

local Client = script.Parent.Parent.Parent
local StateController = require(Client.Controllers.StateController)
local UIController = require(Client.Controllers.UIController)
local Net = require(Client.Controllers.Net)
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local Components = Client.UI.Components
local Button = require(Components.Button)
local MenuShell = require(Components.MenuShell)
local MenuCard = require(Components.MenuCard)
local MenuGrid = require(Components.MenuGrid)

local GiftsScreen = {}

local hex = Color3.fromHex

local PANEL = Vector2.new(1240, 740)
local WIDTH = PANEL.X - 36
local HEIGHT = PANEL.Y - 78 - 16
local DAILY_H = 196

local shell: MenuShell.Shell
local giftCards: { MenuCard.Card } = {}
local dayFrames: { { Frame: Frame, Stroke: UIStroke, State: TextLabel, Reward: TextLabel } } = {}
local dailyButton: Button.Button
local streakLabel: TextLabel
local autoOpened = false

-- Emoji + short text for a reward entry in the player's current world.
local function describe(reward: Rewards.Reward, data: { [string]: any }?): (string, string)
	if reward.Kind == "Wins" then
		local world = if data and type(data.World) == "number" then data.World else 1
		local zones = Zones.ForWorld(world)
		local scale = if zones[1] then zones[1].Wins else 1
		return Theme.Icons.Wins, "+" .. Format.Short((reward.Amount or 0) * scale) .. " Wins"
	elseif reward.Kind == "Skill" then
		return Theme.Icons.Skill, string.format("Skill x%d reps", reward.Reps or 0)
	elseif reward.Kind == "Potion" then
		local boost = Boosts.Get(reward.Id or "")
		return Theme.Icons.Potion, string.format("%dx %s", reward.Count or 1, if boost then boost.Name else "Potion")
	elseif reward.Kind == "Pet" then
		local pet = Pets.Get(reward.Id or "")
		return Theme.Icons.Pets, if pet then pet.Name else "Pet"
	end
	return Theme.Icons.Gifts, "Gift"
end

local function claimedSet(data: { [string]: any }): { [number]: boolean }
	local set = {}
	local session = data.Session
	if type(session) == "table" and type(session.GiftsClaimed) == "table" then
		for _, i in session.GiftsClaimed do
			if type(i) == "number" then
				set[i] = true
			end
		end
	end
	return set
end

local function playtime(data: { [string]: any }): number
	local session = data.Session
	local base = if type(session) == "table" and type(session.Playtime) == "number" then session.Playtime else 0
	return base + StateController.Since()
end

-- Index (1..7) of the day the next daily claim pays, and whether it is claimable now.
local function dailyState(data: { [string]: any }): (number, boolean, number)
	local daily = if type(data.Daily) == "table" then data.Daily else { Day = 0, Streak = 0 }
	local derived = StateController.Derived()
	local now = (if type(derived.ServerTime) == "number" then derived.ServerTime else os.time()) + StateController.Since()
	local today = now // 86400
	local ready = data.DailyReady == true
	local streak: number = daily.Streak or 0
	if ready then
		local nextStreak = if daily.Day == today - 1 then streak + 1 else 1
		return (nextStreak - 1) % #Rewards.Daily + 1, true, nextStreak
	end
	return (math.max(1, streak) - 1) % #Rewards.Daily + 1, false, streak
end

local function refresh()
	local data = StateController.Data
	if data == nil then
		return
	end
	-- daily strip
	local index, ready, streak = dailyState(data)
	streakLabel.Text = string.format("DAILY REWARDS  ·  %d day streak", if ready then math.max(0, streak - 1) else streak)
	for i, day in dayFrames do
		local isNext = i == index
		local _, rewardText = describe(Rewards.Daily[i], data) -- Wins scale with the current world
		day.Reward.Text = rewardText
		if ready then
			day.State.Text = if i < index then "✅" elseif isNext then "TODAY" else ""
		else
			day.State.Text = if i <= index then "✅" else ""
		end
		day.Stroke.Color = if isNext and ready then Theme.Colors.Skill else Theme.Colors.PanelBorder
		day.Stroke.Thickness = if isNext and ready then 4 else 2
		day.Frame.BackgroundTransparency = if (not ready and i <= index) or (ready and i < index) then 0.35 else 0
	end
	dailyButton:SetText(if ready then "CLAIM" else "COME BACK TOMORROW")
	dailyButton:SetStyle(if ready then "Green" else "Grey")
	dailyButton:SetEnabled(ready)

	-- playtime gifts
	local claimed = claimedSet(data)
	local played = playtime(data)
	for i, gift in Rewards.Gifts do
		local card = giftCards[i]
		local _, text = describe(gift.Reward, data)
		card:SetTitle(text)
		local remaining = gift.Minutes * 60 - played
		if claimed[i] then
			card:SetSubtitle("Claimed")
			card:SetAction("CLAIMED", "Grey", false)
			card:SetBadge("✅", Theme.Colors.Success)
		elseif remaining <= 0 then
			card:SetSubtitle("Ready!")
			card:SetAction("CLAIM", "Green", true)
			card:SetBadge("READY", Theme.Colors.Danger)
		else
			card:SetSubtitle(Format.Clock(remaining))
			card:SetAction(string.format("%d MIN", gift.Minutes), "Disabled", false)
			card:SetBadge(nil)
		end
	end
end

local function buildDaily(parent: Frame)
	local strip: Frame = Create("Frame", {
		Name = "Daily",
		BackgroundColor3 = Theme.Colors.CardDeep,
		BackgroundTransparency = 0.2,
		Size = UDim2.new(1, 0, 0, DAILY_H),
		Parent = parent,
	})
	Create.Corner(16, strip)
	Create.Stroke(strip, Theme.Colors.PanelEdge, 2, 0.4, true)
	streakLabel = Create.Text({
		Text = "DAILY REWARDS",
		Size = UDim2.new(1, -260, 0, 34),
		Position = UDim2.fromOffset(18, 8),
		Font = Theme.Fonts.Display,
		TextSize = 30,
		Scaled = true,
		XAlign = Enum.TextXAlignment.Left,
		Stroke = 2.5,
		Parent = strip,
	})
	dailyButton = Button.new({
		Parent = strip,
		Name = "ClaimDaily",
		Size = UDim2.fromOffset(240, 62),
		Position = UDim2.new(1, -14, 0, 8),
		AnchorPoint = Vector2.new(1, 0),
		Style = "Green",
		Text = "CLAIM",
		TextSize = 26,
		OnClick = function()
			Net.Invoke("RequestClaimDaily", false)
		end,
	})
	local row: Frame = Create("Frame", {
		Name = "Days",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 78),
		Size = UDim2.new(1, -28, 0, DAILY_H - 90),
		Parent = strip,
	})
	Create.List(row, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center)
	local count = #Rewards.Daily
	local w = math.floor((WIDTH - 28 - 10 * (count - 1)) / count)
	for i, reward in Rewards.Daily do
		local icon, text = describe(reward, nil)
		local day: Frame = Create("Frame", {
			Name = "Day" .. i,
			BackgroundColor3 = Theme.Colors.Card,
			Size = UDim2.new(0, w, 1, 0),
			LayoutOrder = i,
			Parent = row,
		})
		Create.Corner(12, day)
		local stroke = Create.Stroke(day, Theme.Colors.PanelBorder, 2, 0, true)
		Create.Text({
			Text = "DAY " .. i,
			Size = UDim2.new(1, -8, 0, 22),
			Position = UDim2.fromOffset(4, 4),
			Font = Theme.Fonts.Display,
			TextSize = 20,
			Scaled = true,
			Color = Theme.Colors.TextDim,
			Stroke = 1.5,
			Parent = day,
		})
		Create.Text({
			Text = icon,
			Size = UDim2.new(1, 0, 0, 34),
			Position = UDim2.fromOffset(0, 26),
			TextSize = 30,
			Scaled = true,
			Parent = day,
		})
		local rewardLabel = Create.Text({
			Name = "Reward",
			Text = text,
			Size = UDim2.new(1, -8, 0, 22),
			Position = UDim2.new(0, 4, 1, -26),
			Font = Theme.Fonts.Body,
			TextSize = 18,
			Scaled = true,
			Stroke = 1.5,
			Parent = day,
		})
		local state = Create.Text({
			Name = "State",
			Text = "",
			Size = UDim2.fromOffset(70, 22),
			Position = UDim2.new(1, -4, 0, 4),
			AnchorPoint = Vector2.new(1, 0),
			Font = Theme.Fonts.Display,
			TextSize = 18,
			Scaled = true,
			Color = Theme.Colors.Skill,
			Stroke = 1.5,
			Parent = day,
		})
		table.insert(dayFrames, { Frame = day, Stroke = stroke, State = state, Reward = rewardLabel })
	end
end

local function buildGifts(parent: Frame)
	local columns = 6
	local grid = MenuGrid.new({
		Parent = parent,
		Name = "GiftsGrid",
		Position = UDim2.fromOffset(0, DAILY_H + 12),
		Size = UDim2.new(1, 0, 1, -(DAILY_H + 12)),
		Cell = Vector2.new(MenuGrid.CellWidth(WIDTH, columns), 196),
	})
	for i, gift in Rewards.Gifts do
		local icon = describe(gift.Reward, nil)
		local card = MenuCard.new({
			Parent = grid,
			Name = "Gift" .. i,
			LayoutOrder = i,
			Accent = hex(if gift.Reward.Kind == "Pet" then "#FF8FC8" elseif gift.Reward.Kind == "Potion" then "#C98CFF" elseif gift.Reward.Kind == "Wins" then "#FFC53D" else "#5FB8FF"),
			Rainbow = i == #Rewards.Gifts,
			Icon = icon,
			Title = "",
			Subtitle = "",
			ButtonText = "",
			OnClick = function()
				Net.Invoke("RequestClaimGift", false, i)
			end,
		})
		giftCards[i] = card
	end
end

function GiftsScreen.Init()
	shell = MenuShell.new({
		Name = "Gifts",
		Title = "Gifts",
		Icon = Theme.Icons.Gifts,
		Size = PANEL,
		Accent = hex("#FF5FB0"),
		OnOpen = function()
			refresh()
		end,
		FirstSelection = function()
			return dailyButton.Instance
		end,
	})
	buildDaily(shell.Content)
	buildGifts(shell.Content)
	UIController.Register("Gifts", shell)

	StateController.DataChanged:Connect(function(data)
		if shell:IsOpen() then
			refresh()
		end
		if not autoOpened and data and data.DailyReady == true then
			autoOpened = true
			task.delay(3, function()
				if not UIController.AnyMenuOpen() then
					UIController.Open("Gifts")
				end
			end)
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.5 and shell:IsOpen() then
			acc = 0
			refresh()
		end
	end)
	local _ = HEIGHT
end

return GiftsScreen
