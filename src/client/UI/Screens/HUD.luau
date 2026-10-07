--!strict
-- Lobby HUD reconstructed from the reference (screenshot 3):
--   left rail: Store / Inventory tiles, Emotes [R], Trade [T], Codes
--   bottom-left: coin + gem counters (gem "+")       top-centre: level bar + next reward
--   top-right: daily quests                           bottom-centre: Play (+ mode) / queue panel
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local GameConfig = require(Shared.Config.Game)
local QuestDefinitions = require(Shared.Definitions.QuestDefinitions)
local LevelRewards = require(Shared.Definitions.LevelRewards)
local BallDefinitions = require(Shared.Definitions.BallDefinitions)
local GachaDefinitions = require(Shared.Definitions.GachaDefinitions)
local PropFactory = require(Shared.Visual.PropFactory)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Net.Remotes)

local Client = script.Parent.Parent.Parent
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local Button = require(Client.UI.Components.Button)
local Icons = require(Client.UI.Components.Icons)
local Viewport = require(Client.UI.Components.Viewport)
local OrbArt = require(Client.UI.Components.OrbArt)
local UIController = require(Client.Controllers.UIController)
local StateController = require(Client.Controllers.StateController)
local AudioController = require(Client.Controllers.AudioController)

local HUD = {}

local root: Frame
local coinLabel: TextLabel
local gemLabel: TextLabel
local levelLeft: TextLabel
local levelRight: TextLabel
local levelFill: Frame
local levelText: TextLabel
local rewardIconHolder: Frame
local rewardName: TextLabel
local rewardTopLabel: TextLabel
local pillIconHolder: Frame
local pillLabel: TextLabel
local questRows: { [string]: { Title: TextLabel, Progress: TextLabel, Check: Frame } } = {}
local playButton: Button.Button
local modeButton: Button.Button
local playGroup: Frame
local queuePanel: Frame
local queueTitle: TextLabel
local queueSub: TextLabel
local practiceButton: Button.Button
local inviteButton: Button.Button
local emoteMenu: Frame
local invitePicker: Frame
local inviteList: ScrollingFrame
local mode = "1v1"
local visible = true
local lastCoins = -1

local function tile(name: string, label: string, y: number, iconModel: Model, onClick: () -> ())
	local button: TextButton = Create("TextButton", {
		Name = name,
		Size = UDim2.fromOffset(115, 115),
		Position = UDim2.fromOffset(20, y),
		BackgroundColor3 = Theme.Colors.Tile,
		BackgroundTransparency = 0.3,
		AutoButtonColor = false,
		Text = "",
		Parent = root,
	})
	Create.Stroke(button, Theme.Colors.TileBorder, 2, 0, true)
	local holder: Frame = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 1, -36),
		Position = UDim2.fromOffset(8, 4),
		Parent = button,
	})
	Viewport.Model(holder, iconModel, { Yaw = math.rad(-25), Zoom = 0.95, Fov = 28 })
	Create.Text({
		Text = label,
		Size = UDim2.new(1, -4, 0, 30),
		Position = UDim2.new(0.5, 0, 1, -18),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = Theme.Fonts.Display,
		TextSize = 24,
		Scaled = true,
		Stroke = 2.5,
		ZIndex = 3,
		Parent = button,
	})
	local scale = Instance.new("UIScale")
	scale.Parent = button
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1.06 }):Play()
		AudioController.Play("Hover", nil, 0.05)
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
	button.Activated:Connect(function()
		AudioController.Play("Click")
		onClick()
	end)
end

local function pill(name: string, label: string, key: string?, y: number, onClick: () -> ())
	local button: TextButton = Create("TextButton", {
		Name = name,
		Size = UDim2.fromOffset(173, 58),
		Position = UDim2.fromOffset(20, y),
		BackgroundColor3 = Theme.Colors.Tile,
		BackgroundTransparency = 0.3,
		AutoButtonColor = false,
		Text = "",
		Parent = root,
	})
	Create.Stroke(button, Theme.Colors.TileBorder, 2, 0, true)
	Create.Text({
		Text = label,
		Size = UDim2.new(1, if key then -64 else -20, 0, 30),
		Position = UDim2.new(0, 14, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Font = Theme.Fonts.Display,
		TextSize = 22,
		Scaled = true,
		XAlign = Enum.TextXAlignment.Left,
		Stroke = 2,
		Parent = button,
	})
	if key then
		local chip: Frame = Create("Frame", {
			Size = UDim2.fromOffset(32, 36),
			Position = UDim2.new(1, -40, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.fromHex("#2A3350"),
			Parent = button,
		})
		Create.Corner(5, chip)
		Create.Stroke(chip, Color3.fromHex("#7D869C"), 1.5, 0, true)
		Create.Text({ Text = key, Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Font = Theme.Fonts.Body, TextSize = 24, Scaled = true, Parent = chip })
	end
	button.Activated:Connect(function()
		AudioController.Play("Click")
		onClick()
	end)
	return button
end

local function currencyRow(icon: "Coin" | "Gem", yFromBottom: number, color: Color3): TextLabel
	local row: Frame = Create("Frame", {
		Name = icon .. "Row",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -yFromBottom),
		Size = UDim2.fromOffset(420, 80),
		Parent = root,
	})
	local strip: Frame = Create("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.new(1, 0, 0, 54),
		Position = UDim2.new(0, 30, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Parent = row,
	})
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.4), NumberSequenceKeypoint.new(1, 1) })
	fade.Parent = strip
	local iconFrame = if icon == "Coin" then Icons.Coin(UDim2.fromOffset(76, 76), row) else Icons.Gem(UDim2.fromOffset(84, 84), row)
	iconFrame.Position = UDim2.new(0, 0, 0.5, 0)
	iconFrame.AnchorPoint = Vector2.new(0, 0.5)
	iconFrame.ZIndex = 3
	local label = Create.Text({
		Name = "Value",
		Text = "0",
		Size = UDim2.fromOffset(300, 58),
		Position = UDim2.new(0, 96, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Font = Theme.Fonts.Display,
		TextSize = 54,
		Scaled = true,
		XAlign = Enum.TextXAlignment.Left,
		Color = color,
		Stroke = 3,
		Parent = row,
	})
	if icon == "Gem" then
		local plus: TextButton = Create("TextButton", {
			Name = "Plus",
			Size = UDim2.fromOffset(34, 34),
			Position = UDim2.new(0, 2, 1, -6),
			AnchorPoint = Vector2.new(0, 1),
			BackgroundColor3 = Color3.fromHex("#2F7BF5"),
			AutoButtonColor = true,
			Text = "",
			ZIndex = 5,
			Parent = row,
		})
		Create.Corner(6, plus)
		Create.Stroke(plus, Color3.fromHex("#0D2A66"), 2, 0, true)
		Icons.Plus(UDim2.fromScale(0.8, 0.8), plus).Position = UDim2.fromScale(0.1, 0.1)
		plus.Activated:Connect(function()
			AudioController.Play("Click")
			UIController.Open("Gems")
		end)
	end
	return label
end

local function buildLevelBar()
	local bar: Frame = Create("Frame", {
		Name = "Level",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(560, 60),
		Parent = root,
	})
	levelLeft = Create.Text({ Text = "Lv 1", Size = UDim2.fromOffset(80, 30), Position = UDim2.fromOffset(0, 0), Font = Theme.Fonts.Display, TextSize = 26, Scaled = true, Color = Color3.fromHex("#C9C9C9"), Stroke = 2, XAlign = Enum.TextXAlignment.Right, Parent = bar })
	local track: Frame = Create("Frame", {
		BackgroundColor3 = Theme.Colors.LevelTrack,
		Position = UDim2.fromOffset(92, 8),
		Size = UDim2.fromOffset(380, 16),
		Parent = bar,
	})
	Create.Stroke(track, Color3.fromHex("#8E949E"), 1.5, 0, true)
	levelFill = Create("Frame", { BackgroundColor3 = Theme.Colors.LevelFill, Size = UDim2.fromScale(0, 1), Parent = track })
	Create.Gradient(levelFill, Color3.fromHex("#D3D6DC"), Color3.fromHex("#8E949E"), 90)
	levelRight = Create.Text({ Text = "Lv 2", Size = UDim2.fromOffset(80, 30), Position = UDim2.fromOffset(484, 0), Font = Theme.Fonts.Display, TextSize = 26, Scaled = true, Color = Color3.fromHex("#C9C9C9"), Stroke = 2, XAlign = Enum.TextXAlignment.Left, Parent = bar })
	levelText = Create.Text({ Text = "0 / 20", Size = UDim2.fromOffset(200, 22), Position = UDim2.new(0.5, 0, 0, 34), AnchorPoint = Vector2.new(0.5, 0), Font = Theme.Fonts.Display, TextSize = 20, Scaled = true, Color = Color3.fromHex("#C9C9C9"), Stroke = 2, Parent = bar })

	-- next level reward (right of the bar)
	local reward: Frame = Create("Frame", { Name = "Reward", BackgroundTransparency = 1, Position = UDim2.fromOffset(575, -6), Size = UDim2.fromOffset(150, 90), Parent = bar })
	rewardTopLabel = Create.Text({ Text = "Lv2 Reward", Size = UDim2.new(1, 0, 0, 16), Font = Theme.Fonts.Display, TextSize = 14, Scaled = true, Color = Color3.fromHex("#9FD8FF"), Stroke = 1.5, Parent = reward })
	rewardIconHolder = Create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(58, 58), Parent = reward })
	rewardName = Create.Text({ Text = "", Size = UDim2.new(1, 20, 0, 22), Position = UDim2.new(0.5, 0, 0, 70), AnchorPoint = Vector2.new(0.5, 0), Font = Theme.Fonts.Display, TextSize = 18, Scaled = true, Stroke = 2, Parent = reward })
end

local function rewardArt(holder: Frame, reward: LevelRewards.Reward)
	holder:ClearAllChildren()
	if reward.Kind == "Ball" and reward.Id then
		OrbArt.Draw(holder, reward.Id)
	elseif reward.Kind == "Ticket" then
		Viewport.Model(holder, PropFactory.GachaMachine(reward.Id == "AdvancedOrbGacha"), { Yaw = math.rad(-20) })
	elseif reward.Kind == "Gems" then
		Icons.Gem(UDim2.fromScale(1, 1), holder)
	else
		Icons.Coin(UDim2.fromScale(1, 1), holder)
	end
end

local function rewardText(reward: LevelRewards.Reward): string
	if reward.Kind == "Ball" and reward.Id then
		local def = BallDefinitions.Get(reward.Id)
		return if def then def.DisplayName else reward.Id
	elseif reward.Kind == "Ticket" and reward.Id then
		local crate = GachaDefinitions.Get(reward.Id)
		return if crate then crate.DisplayName else "Gacha"
	elseif reward.Kind == "Gems" then
		return string.format("%d Gems", reward.Amount or 0)
	end
	return string.format("%d Coins", reward.Amount or 0)
end

local function buildQuests()
	local panel: Frame = Create("Frame", {
		Name = "Quests",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(300, 190),
		Parent = root,
	})
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, 0.4), NumberSequenceKeypoint.new(1, 0.2) })
	g.Parent = panel
	Create.Padding(panel, 12, 6)
	Create.List(panel, Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Right)
	for i, quest in QuestDefinitions.Daily do
		local row: Frame = Create("Frame", { Name = quest.Id, BackgroundTransparency = 1, Size = UDim2.fromOffset(260, 58), LayoutOrder = i, Parent = panel })
		local title = Create.Text({ Text = quest.Title, Size = UDim2.fromOffset(260, 28), Font = Theme.Fonts.Body, TextSize = 26, Scaled = true, XAlign = Enum.TextXAlignment.Left, Stroke = 1.5, Parent = row })
		local progress = Create.Text({ Text = "0/" .. quest.Goal, Size = UDim2.fromOffset(120, 22), Position = UDim2.fromOffset(0, 30), Font = Theme.Fonts.Display, TextSize = 18, Scaled = true, XAlign = Enum.TextXAlignment.Left, Color = Color3.fromHex("#B8BCC6"), Stroke = 1.5, Parent = row })
		local coin = Icons.Coin(UDim2.fromOffset(22, 22), row)
		coin.Position = UDim2.fromOffset(176, 31)
		Create.Text({ Text = "X" .. quest.Reward.Coins, Size = UDim2.fromOffset(62, 22), Position = UDim2.fromOffset(200, 30), Font = Theme.Fonts.Display, TextSize = 18, Scaled = true, XAlign = Enum.TextXAlignment.Left, Color = Theme.Colors.Gold, Stroke = 1.5, Parent = row })
		local check = Icons.Check(UDim2.fromOffset(26, 26), row)
		check.Position = UDim2.fromOffset(140, 28)
		check.Visible = false
		questRows[quest.Id] = { Title = title, Progress = progress, Check = check }
	end
end

local function buildPlay()
	playGroup = Create("Frame", {
		Name = "PlayGroup",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.fromOffset(420, 150),
		Parent = root,
	})
	-- next reward pill above Play (reference: "Lv 3 Reward 😊")
	local rewardPill: Frame = Create("Frame", {
		Name = "RewardPill",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(270, 60),
		Parent = playGroup,
	})
	pillLabel = Create.Text({ Text = "Lv 2 Reward", Size = UDim2.fromOffset(190, 32), Position = UDim2.fromOffset(10, 14), Font = Theme.Fonts.Display, TextSize = 26, Scaled = true, Color = Color3.fromHex("#C9C9C9"), Stroke = 2, XAlign = Enum.TextXAlignment.Left, Parent = rewardPill })
	pillIconHolder = Create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(204, 2), Size = UDim2.fromOffset(56, 56), Parent = rewardPill })

	playButton = Button.new({
		Parent = playGroup,
		Name = "Play",
		Size = UDim2.fromOffset(288, 63),
		Position = UDim2.new(0.5, 0, 1, 0),
		AnchorPoint = Vector2.new(0.5, 1),
		Style = "Green",
		Text = "Play",
		TextSize = 44,
		OnClick = function()
			Remotes.Event("QueueRequest"):FireServer("Play", mode)
		end,
	})
	modeButton = Button.new({
		Parent = playGroup,
		Name = "Mode",
		Size = UDim2.fromOffset(86, 63),
		Position = UDim2.new(0.5, 154, 1, 0),
		AnchorPoint = Vector2.new(0, 1),
		Style = "Blue",
		Text = "1V1",
		TextSize = 24,
		OnClick = function()
			mode = if mode == "1v1" then "2v2" else "1v1"
			modeButton:SetText(GameConfig.Modes[mode].Label)
			modeButton:SetStyle(if mode == "1v1" then "Blue" else "Purple")
		end,
	})
end

local function buildQueuePanel()
	queuePanel = Create("Frame", {
		Name = "QueuePanel",
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.06,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.fromOffset(560, 150),
		Visible = false,
		Parent = root,
	})
	Create.Stroke(queuePanel, Theme.Colors.ModalBorder, 2, 0, true)
	queueTitle = Create.Text({ Text = "Waiting for opponent...", Size = UDim2.new(1, -20, 0, 36), Position = UDim2.fromOffset(10, 8), Font = Theme.Fonts.Display, TextSize = 30, Scaled = true, Stroke = 2, Parent = queuePanel })
	queueSub = Create.Text({ Text = "1/2 PLAYERS", Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 46), Font = Theme.Fonts.Body, TextSize = 24, Scaled = true, Color = Theme.Colors.TextDim, Stroke = 1.5, Parent = queuePanel })
	local row: Frame = Create("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 10, 1, -66), Size = UDim2.new(1, -20, 0, 56), Parent = queuePanel })
	Create.List(row, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center)
	inviteButton = Button.new({ Parent = row, Size = UDim2.fromOffset(160, 54), Style = "Blue", Text = "Invite", TextSize = 26, LayoutOrder = 1, OnClick = function()
		invitePicker.Visible = not invitePicker.Visible
		if invitePicker.Visible then
			HUD.RefreshInvites()
		end
	end })
	practiceButton = Button.new({ Parent = row, Size = UDim2.fromOffset(190, 54), Style = "Purple", Text = "Practice Bot", TextSize = 24, LayoutOrder = 2, OnClick = function()
		Remotes.Event("QueueRequest"):FireServer("Practice")
	end })
	Button.new({ Parent = row, Size = UDim2.fromOffset(150, 54), Style = "Red", Text = "Leave", TextSize = 26, LayoutOrder = 3, OnClick = function()
		Remotes.Event("QueueRequest"):FireServer("Leave")
		invitePicker.Visible = false
	end })
	practiceButton.Instance.Visible = GameConfig.Bots.Enabled

	invitePicker = Create("Frame", {
		Name = "InvitePicker",
		BackgroundColor3 = Theme.Colors.Panel,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -10),
		Size = UDim2.fromOffset(420, 300),
		Visible = false,
		Parent = queuePanel,
	})
	Create.Stroke(invitePicker, Theme.Colors.ModalBorder, 2, 0, true)
	Create.Text({ Text = "Invite a player", Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 6), Font = Theme.Fonts.Display, TextSize = 22, Scaled = true, Stroke = 2, Parent = invitePicker })
	inviteList = Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 44),
		Size = UDim2.new(1, -20, 1, -54),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = invitePicker,
	})
	Create.List(inviteList, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center)
end

function HUD.RefreshInvites()
	for _, child in inviteList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local any = false
	for _, player in Players:GetPlayers() do
		if player ~= Players.LocalPlayer then
			any = true
			Button.new({
				Parent = inviteList,
				Size = UDim2.fromOffset(380, 48),
				Style = "Dark",
				Text = player.DisplayName,
				Font = Theme.Fonts.Body,
				TextSize = 26,
				OnClick = function()
					Remotes.Event("InviteRequest"):FireServer(player.UserId)
					invitePicker.Visible = false
				end,
			})
		end
	end
	if not any then
		Create.Text({ Text = "Nobody else is here yet.", Size = UDim2.fromOffset(380, 40), Font = Theme.Fonts.Body, TextSize = 24, Color = Theme.Colors.TextDim, Parent = inviteList })
	end
end

local function buildEmotes()
	emoteMenu = Create("Frame", {
		Name = "EmoteMenu",
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.05,
		Position = UDim2.fromOffset(205, 437),
		Size = UDim2.fromOffset(330, 200),
		Visible = false,
		Parent = root,
	})
	Create.Stroke(emoteMenu, Theme.Colors.TileBorder, 2, 0, true)
	Create.Padding(emoteMenu, 10)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(150, 50)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.Parent = emoteMenu
	for _, emote in { "wave", "point", "cheer", "laugh", "dance", "dance2" } do
		Button.new({
			Parent = emoteMenu,
			Size = UDim2.fromOffset(150, 50),
			Style = "Dark",
			Text = string.upper(string.sub(emote, 1, 1)) .. string.sub(emote, 2),
			Font = Theme.Fonts.Body,
			TextSize = 24,
			OnClick = function()
				emoteMenu.Visible = false
				local character = Players.LocalPlayer.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					local ok, played = pcall(function()
						return humanoid:PlayEmote(emote)
					end)
					if not ok or not played then
						UIController.Toast("That emote isn't available for your avatar.", "Error")
					end
				end
			end,
		})
	end
end

local function refreshData(data: { [string]: any })
	if data.Coins ~= lastCoins and lastCoins >= 0 then
		local scale = coinLabel:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		scale.Parent = coinLabel
		scale.Scale = 1.15
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	lastCoins = data.Coins
	coinLabel.Text = Format.Commas(data.Coins)
	gemLabel.Text = Format.Commas(data.Gems)
	local need = Economy.XPToNext(data.Level)
	levelLeft.Text = "Lv " .. data.Level
	levelRight.Text = "Lv " .. (data.Level + 1)
	levelText.Text = string.format("%d / %d", data.XP, need)
	TweenService:Create(levelFill, TweenInfo.new(0.4), { Size = UDim2.fromScale(math.clamp(data.XP / need, 0, 1), 1) }):Play()
	local nextReward = LevelRewards.For(data.Level + 1)
	rewardTopLabel.Text = string.format("Lv%d Reward", data.Level + 1)
	rewardName.Text = rewardText(nextReward)
	pillLabel.Text = string.format("Lv %d Reward", data.Level + 1)
	rewardArt(rewardIconHolder, nextReward)
	rewardArt(pillIconHolder, nextReward)

	local quests = data.Quests or { Progress = {}, Done = {} }
	for _, quest in QuestDefinitions.Daily do
		local row = questRows[quest.Id]
		local value = quests.Progress[quest.Id] or 0
		local done = quests.Done[quest.Id] == true
		row.Progress.Text = string.format("%d/%d", math.min(value, quest.Goal), quest.Goal)
		row.Check.Visible = done
		row.Title.TextColor3 = if done then Color3.fromHex("#7CFF6B") else Color3.new(1, 1, 1)
	end
end

local function refreshQueue()
	local station, _ = StateController.MyStation()
	local inQueue = station ~= nil and station.State ~= "InMatch"
	queuePanel.Visible = inQueue and visible
	playGroup.Visible = (not inQueue) and visible
	if not inQueue then
		invitePicker.Visible = false
		return
	end
	local s = station :: { [string]: any }
	local count = 0
	for _, pad in s.Pads do
		if pad.UserId ~= 0 then
			count += 1
		end
	end
	if s.State == "MatchFound" then
		queueTitle.Text = "Match found!"
		queueSub.Text = "Get ready..."
	else
		queueTitle.Text = if s.Mode == "2v2" then "Waiting for players..." else "Waiting for opponent..."
		queueSub.Text = string.format("%d/%d PLAYERS  ·  Win %d", count, s.Capacity, Economy.MatchRewards.Win.Coins)
	end
	practiceButton:SetEnabled(s.State == "Waiting")
	inviteButton:SetEnabled(s.State == "Waiting")
end

function HUD.SetVisible(show: boolean)
	visible = show
	root.Visible = show
	refreshQueue()
end

function HUD.Init()
	root = Create("Frame", {
		Name = "HUD",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = UIController.Layer("HUD"),
	})
	tile("Store", "Store", 140, PropFactory.GachaMachine(false), function()
		UIController.Toggle("Store", "Balls")
	end)
	tile("Inventory", "Inventory", 288, PropFactory.InventoryBox(), function()
		UIController.Toggle("Inventory")
	end)
	pill("Emotes", "Emotes", "R", 437, function()
		emoteMenu.Visible = not emoteMenu.Visible
	end)
	pill("Trade", "Trade", "T", 505, function()
		UIController.Toggle("Trade")
	end)
	pill("Codes", "Codes", nil, 573, function()
		UIController.Toggle("Codes")
	end)
	buildEmotes()
	coinLabel = currencyRow("Coin", 110, Theme.Colors.Gold)
	gemLabel = currencyRow("Gem", 22, Theme.Colors.GemText)
	buildLevelBar()
	buildQuests()
	buildPlay()
	buildQueuePanel()

	StateController.DataChanged:Connect(refreshData)
	if StateController.Data then
		refreshData(StateController.Data)
	end
	StateController.StationChanged:Connect(refreshQueue)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not visible then
			return
		end
		if input.KeyCode == Enum.KeyCode.R then
			emoteMenu.Visible = not emoteMenu.Visible
		elseif input.KeyCode == Enum.KeyCode.T then
			UIController.Toggle("Trade")
		end
	end)
end

return HUD
