--!strict
-- Live event banner (Sky Festival): a pulsing ribbon at the top-right with the event name and a
-- countdown while a server-wide boost is active.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Client = script.Parent.Parent.Parent
local StateController = require(Client.Controllers.StateController)
local UIController = require(Client.Controllers.UIController)
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Format = require(ReplicatedStorage:WaitForChild("Shared").Util.Format)

local EventBanner = {}

function EventBanner.Init()
	local ribbon: Frame = Create("Frame", {
		Name = "EventBanner",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 24),
		Size = UDim2.fromOffset(330, 64),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		Parent = UIController.Layer("HUD"),
	})
	Create.Corner(14, ribbon)
	local gradient = Instance.new("UIGradient")
	gradient.Color = Theme.Rainbow
	gradient.Parent = ribbon
	Create.Stroke(ribbon, Theme.Colors.Stroke, 3, 0, true)
	local title = Create.Text({
		Text = "",
		Size = UDim2.new(1, -16, 0.58, 0),
		Position = UDim2.fromOffset(8, 2),
		Font = Theme.Fonts.Display,
		TextSize = 30,
		Scaled = true,
		Stroke = 2.5,
		Parent = ribbon,
	})
	local timer = Create.Text({
		Text = "",
		Size = UDim2.new(1, -16, 0.4, 0),
		Position = UDim2.new(0, 8, 0.58, 0),
		Font = Theme.Fonts.Body,
		TextSize = 20,
		Scaled = true,
		Stroke = 1.5,
		Parent = ribbon,
	})
	local scale = Instance.new("UIScale")
	scale.Parent = ribbon

	local function refresh()
		local event = StateController.Event
		local remaining = event.EndsAt - Workspace:GetServerTimeNow()
		local show = event.Active and remaining > 0
		if show and not ribbon.Visible then
			scale.Scale = 0.4
			TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
		ribbon.Visible = show
		if show then
			title.Text = "🎉 " .. event.Name .. " 🎉"
			timer.Text = "x2 SKILL · x2 WINS · " .. Format.Clock(remaining)
		end
	end
	StateController.ServerInfoChanged:Connect(function(kind)
		if kind == "Event" then
			refresh()
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.5 then
			acc = 0
			refresh()
			if ribbon.Visible then
				gradient.Offset = Vector2.new(math.sin(os.clock()) * 0.3, 0)
			end
		end
	end)
end

return EventBanner
