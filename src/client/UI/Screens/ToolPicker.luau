-- First join: "PICK YOUR MECH!" - choose one of three free tool styles. One tap, then
-- straight into smashing. (The choice can be changed any time in the Garage.)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Theme = require(Shared.Theme)

local UI = script.Parent.Parent
local UIKit = require(UI.UIKit)
local Copy = require(UI.Copy)
local Panels = require(UI.Panels)
local Toasts = require(UI.Toasts)
local Viewport = require(UI.Viewport)
local Net = require(UI.Parent.Net)

local ToolPicker = {}

local shown = false
local CARD_SWATCH = { Hammer = Theme.Swatch.Orange, Saw = Theme.Swatch.Red, Drill = Theme.Swatch.Blue }

function ToolPicker.init()
	local panel = Panels.create({
		Name = "ToolPicker",
		Title = Copy.Picker.Title,
		Icon = "🤖",
		Swatch = Theme.Swatch.Orange,
		Width = 940,
		Height = 560,
		TabWidth = 420,
	})
	local body = panel.Body
	UIKit.text(body, {
		Text = Copy.Picker.Sub,
		TextSize = 22,
		Font = Theme.Font.Body,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 4),
	})
	local row = UIKit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -48),
		Position = UDim2.fromOffset(0, 46),
		Parent = body,
	})
	UIKit.list(row, false, 26, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
	local views = {}
	for i, tool in Config.Tools do
		local card = UIKit.surface(row, {
			Size = UDim2.fromOffset(270, 420),
			Swatch = CARD_SWATCH[tool.Id] or Theme.Swatch.Blue,
			Radius = Theme.Radius.L,
			LayoutOrder = i,
		})
		card.Face.ClipsDescendants = true
		UIKit.sunburst(card.Face, Color3.new(1, 1, 1), 10, 2)
		views[tool.Id] = Viewport.create(
			card.Face,
			{ Size = UDim2.new(1, 0, 0, 250), Position = UDim2.fromOffset(0, 6), ZIndex = 3 }
		)
		UIKit.text(card.Face, {
			Text = string.upper(tool.Name),
			TextSize = 40,
			Size = UDim2.new(1, -16, 0, 46),
			Position = UDim2.fromOffset(8, 256),
			ZIndex = 3,
			StrokeThickness = 4,
		})
		UIKit.text(card.Face, {
			Text = tool.Blurb,
			TextSize = 18,
			Font = Theme.Font.Body,
			Size = UDim2.new(1, -16, 0, 26),
			Position = UDim2.fromOffset(8, 302),
			ZIndex = 3,
		})
		UIKit.button(card.Face, {
			Text = Copy.Picker.Button,
			TextSize = 30,
			Size = UDim2.new(1, -50, 0, 62),
			Position = UDim2.new(0.5, 0, 1, -14),
			AnchorPoint = Vector2.new(0.5, 1),
			Swatch = Theme.Swatch.Green,
			ZIndex = 3,
			OnClick = function()
				local ok, msg = Net.request("SelectTool", tool.Id)
				if ok then
					Panels.close()
					Toasts.show("Info", "Nice pick!", "Walk up to the junk in your lane to smash it.")
				else
					Toasts.error(msg)
				end
			end,
		})
	end
	panel.OnClose = function()
		local s = Net.State
		if s and not s.ToolChosen then
			-- Closed without picking: keep the current tool so the intro doesn't get stuck.
			task.spawn(Net.request, "SelectTool", s.Tool)
		end
	end
	panel.OnOpen = function()
		for id, view in views do
			Viewport.showMech(view, 4, id, nil, 150)
		end
	end
	Net.Changed:Connect(function(s)
		if not shown and s and not s.ToolChosen then
			shown = true
			task.delay(0.6, Panels.open, "ToolPicker")
		end
	end)
end

return ToolPicker
