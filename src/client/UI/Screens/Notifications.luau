--!strict
-- Toast routing plus actionable popups: battle invites and trade requests (Accept / Decline).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)

local Client = script.Parent.Parent.Parent
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local Button = require(Client.UI.Components.Button)
local UIController = require(Client.Controllers.UIController)
local StateController = require(Client.Controllers.StateController)
local AudioController = require(Client.Controllers.AudioController)

local Notifications = {}

local holder: Frame

local function popup(title: string, body: string, timeout: number, onAnswer: (boolean) -> ())
	AudioController.Play("Select")
	local card: Frame = Create("Frame", {
		BackgroundColor3 = Theme.Colors.Panel,
		Size = UDim2.fromOffset(460, 170),
		Parent = holder,
	})
	Create.Stroke(card, Theme.Colors.ModalBorder, 2, 0, true)
	Create.Text({ Text = title, Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 8), Font = Theme.Fonts.Display, TextSize = 24, Scaled = true, Stroke = 2, Parent = card })
	Create.Text({ Text = body, Size = UDim2.new(1, -20, 0, 50), Position = UDim2.fromOffset(10, 44), Font = Theme.Fonts.BodySemi, TextSize = 26, Wrapped = true, Color = Theme.Colors.TextDim, Parent = card })
	local bar: Frame = Create("Frame", { BackgroundColor3 = Theme.Colors.PanelBorder, Position = UDim2.new(0, 0, 1, -4), Size = UDim2.new(1, 0, 0, 4), Parent = card })
	TweenService:Create(bar, TweenInfo.new(timeout, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 4) }):Play()
	local answered = false
	local function answer(value: boolean)
		if answered then
			return
		end
		answered = true
		card:Destroy()
		onAnswer(value)
	end
	Button.new({ Parent = card, Size = UDim2.fromOffset(190, 52), Position = UDim2.new(0, 20, 1, -14), AnchorPoint = Vector2.new(0, 1), Style = "Green", Text = "Accept", TextSize = 28, OnClick = function()
		answer(true)
	end })
	Button.new({ Parent = card, Size = UDim2.fromOffset(190, 52), Position = UDim2.new(1, -20, 1, -14), AnchorPoint = Vector2.new(1, 1), Style = "Red", Text = "Decline", TextSize = 28, OnClick = function()
		answer(false)
	end })
	task.delay(timeout, function()
		answer(false)
	end)
end

function Notifications.Init()
	holder = Create("Frame", {
		Name = "Popups",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -110),
		Size = UDim2.fromOffset(460, 400),
		Parent = UIController.Layer("Overlay"),
	})
	Create.List(holder, Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom)

	StateController.Notified:Connect(function(payload)
		UIController.Toast(payload.Text, payload.Kind)
	end)
	Remotes.Event("InviteReceived").OnClientEvent:Connect(function(invite)
		popup("Battle invite", string.format("%s wants to battle you (%s)!", invite.FromName, string.upper(invite.Mode)), invite.Timeout or 20, function(accept)
			Remotes.Event("InviteResponse"):FireServer(invite.InviteId, accept)
		end)
	end)
	Remotes.Event("TradeState").OnClientEvent:Connect(function(payload)
		if payload.Type == "Request" then
			popup("Trade request", payload.FromName .. " wants to trade with you.", payload.Timeout or 20, function(accept)
				Remotes.Event("TradeRequest"):FireServer("Respond", payload.RequestId, accept)
			end)
		end
	end)
end

return Notifications
