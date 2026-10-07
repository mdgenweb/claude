--!strict
-- Match results: VICTORY / DEFEAT, coin + XP rewards with level progress, streak, and
-- Play Again (requeue) / Lobby.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)

local Client = script.Parent.Parent.Parent
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local Button = require(Client.UI.Components.Button)
local Icons = require(Client.UI.Components.Icons)
local UIController = require(Client.Controllers.UIController)
local AudioController = require(Client.Controllers.AudioController)

local ResultsScreen = {}

local root: Frame
local card: Frame
local title: TextLabel
local subtitle: TextLabel
local coinsLabel: TextLabel
local xpLabel: TextLabel
local levelLabel: TextLabel
local levelFill: Frame
local streakLabel: TextLabel
local lastMode = "1v1"
local onDismiss: (() -> ())?
local onRequeue: ((string) -> ())?

function ResultsScreen.Show(payload: { [string]: any }, mode: string, dismissed: () -> (), requeue: ((string) -> ())?)
	lastMode = mode
	onDismiss = dismissed
	onRequeue = requeue
	local won = payload.Won
	title.Text = if won then "VICTORY" else "DEFEAT"
	title.TextColor3 = if won then Theme.Colors.Gold else Color3.fromHex("#FF4F5E")
	subtitle.Text = if payload.Practice then "Practice match (reduced rewards)" elseif payload.Forfeit and won then "Your opponent left the battle" else (if won then "You won the battle!" else "Better luck next time!")
	local rewards = payload.Rewards or {}
	coinsLabel.Text = "+" .. tostring(rewards.Coins or 0)
	xpLabel.Text = "+" .. tostring(rewards.XP or 0) .. " XP"
	levelLabel.Text = string.format("Lv %d   %d / %d", rewards.Level or 1, rewards.XPNow or 0, rewards.XPNeed or 20)
	levelFill.Size = UDim2.fromScale(0, 1)
	TweenService:Create(levelFill, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(math.clamp((rewards.XPNow or 0) / math.max(1, rewards.XPNeed or 1), 0, 1), 1) }):Play()
	streakLabel.Text = if (rewards.Streak or 0) >= 2 then string.format("Win streak: %d", rewards.Streak) else ""
	root.Visible = true
	local s = card:FindFirstChildOfClass("UIScale") :: UIScale
	s.Scale = 0.7
	TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	AudioController.Play(if won then "Victory" else "Defeat")
end

function ResultsScreen.Hide()
	if not root.Visible then
		return
	end
	root.Visible = false
	local cb = onDismiss
	onDismiss = nil
	if cb then
		cb()
	end
end

function ResultsScreen.IsOpen(): boolean
	return root.Visible
end

function ResultsScreen.Init()
	root = Create("Frame", { Name = "Results", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, Size = UDim2.fromScale(1, 1), Visible = false, Active = true, Parent = UIController.Layer("Overlay") })
	card = Create("Frame", { BackgroundColor3 = Color3.fromHex("#121729"), BackgroundTransparency = 0.04, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(808, 500), Parent = root })
	Create.Stroke(card, Theme.Colors.ModalBorder, 2, 0, true)
	Instance.new("UIScale").Parent = card
	title = Create.Text({ Text = "VICTORY", Size = UDim2.new(1, -40, 0, 90), Position = UDim2.fromOffset(20, 18), Font = Theme.Fonts.Display, TextSize = 80, Scaled = true, Stroke = 4, Parent = card })
	subtitle = Create.Text({ Text = "", Size = UDim2.new(1, -40, 0, 34), Position = UDim2.fromOffset(20, 110), Font = Theme.Fonts.Body, TextSize = 30, Color = Theme.Colors.TextDim, Parent = card })

	local rewards: Frame = Create("Frame", { BackgroundColor3 = Theme.Colors.Card, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 160), Size = UDim2.fromOffset(600, 180), Parent = card })
	Create.Stroke(rewards, Theme.Colors.PanelBorder, 2, 0, true)
	local coin = Icons.Coin(UDim2.fromOffset(64, 64), rewards)
	coin.Position = UDim2.fromOffset(40, 18)
	coinsLabel = Create.Text({ Text = "+0", Size = UDim2.fromOffset(180, 60), Position = UDim2.fromOffset(116, 20), Font = Theme.Fonts.Display, TextSize = 50, Scaled = true, XAlign = Enum.TextXAlignment.Left, Color = Theme.Colors.Gold, Stroke = 3, Parent = rewards })
	xpLabel = Create.Text({ Text = "+0 XP", Size = UDim2.fromOffset(230, 60), Position = UDim2.new(1, -30, 0, 20), AnchorPoint = Vector2.new(1, 0), Font = Theme.Fonts.Display, TextSize = 44, Scaled = true, XAlign = Enum.TextXAlignment.Right, Color = Color3.fromHex("#9FD8FF"), Stroke = 3, Parent = rewards })
	local track: Frame = Create("Frame", { BackgroundColor3 = Theme.Colors.LevelTrack, Position = UDim2.fromOffset(40, 112), Size = UDim2.new(1, -80, 0, 18), Parent = rewards })
	Create.Stroke(track, Color3.fromHex("#8E949E"), 1.5, 0, true)
	levelFill = Create("Frame", { BackgroundColor3 = Color3.fromHex("#7BE52A"), Size = UDim2.fromScale(0, 1), Parent = track })
	levelLabel = Create.Text({ Text = "", Size = UDim2.new(1, -80, 0, 28), Position = UDim2.fromOffset(40, 138), Font = Theme.Fonts.Display, TextSize = 20, Scaled = true, Color = Color3.fromHex("#C9C9C9"), Stroke = 2, Parent = rewards })
	streakLabel = Create.Text({ Text = "", Size = UDim2.new(1, -40, 0, 30), Position = UDim2.fromOffset(20, 348), Font = Theme.Fonts.Display, TextSize = 24, Color = Color3.fromHex("#FFB347"), Stroke = 2, Parent = card })

	Button.new({ Parent = card, Size = UDim2.fromOffset(300, 70), Position = UDim2.new(0.5, -12, 1, -24), AnchorPoint = Vector2.new(1, 1), Style = "Green", Text = "Play Again", TextSize = 36, OnClick = function()
		local requeue = onRequeue
		ResultsScreen.Hide()
		if requeue then
			requeue(lastMode)
		else
			Remotes.Event("QueueRequest"):FireServer("Play", lastMode)
		end
	end })
	Button.new({ Parent = card, Size = UDim2.fromOffset(300, 70), Position = UDim2.new(0.5, 12, 1, -24), AnchorPoint = Vector2.new(0, 1), Style = "Blue", Text = "Lobby", TextSize = 36, OnClick = function()
		ResultsScreen.Hide()
	end })
end

return ResultsScreen
