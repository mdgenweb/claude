--!strict
-- Codes (reference guides: Gift -> Codes -> "Enter code here..." -> Redeem).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Net.Remotes)

local Client = script.Parent.Parent.Parent
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local Button = require(Client.UI.Components.Button)
local Panel = require(Client.UI.Components.Panel)
local UIController = require(Client.Controllers.UIController)

local CodesScreen = {}

function CodesScreen.Init()
	local panel = Panel.new({
		Parent = UIController.Layer("Menus"),
		Name = "Codes",
		Title = "Codes",
		Size = Vector2.new(640, 360),
		TitleSize = 48,
		OnClose = function()
			UIController.Close("Codes")
		end,
	})
	local content = panel.Content
	Create.Text({ Text = "Follow the group for new codes every update!", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 4), Font = Theme.Fonts.BodySemi, TextSize = 26, Color = Theme.Colors.TextDim, Parent = content })
	local box: TextBox = Create("TextBox", {
		PlaceholderText = "Enter code here...",
		Text = "",
		ClearTextOnFocus = false,
		FontFace = Theme.Fonts.Display,
		TextSize = 28,
		TextColor3 = Color3.new(1, 1, 1),
		PlaceholderColor3 = Theme.Colors.TextMuted,
		BackgroundColor3 = Theme.Colors.SubBar,
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 62),
		Parent = content,
	})
	Create.Stroke(box, Theme.Colors.PanelBorder, 2, 0, true)
	local status = Create.Text({ Text = "", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 122), Font = Theme.Fonts.Body, TextSize = 26, Parent = content })
	local busy = false
	local function redeem()
		if busy or box.Text == "" then
			return
		end
		busy = true
		local result = Remotes.Function("StoreRequest"):InvokeServer("RedeemCode", box.Text)
		busy = false
		if type(result) == "table" and result.ok then
			status.Text = result.message or "Redeemed!"
			status.TextColor3 = Color3.fromHex("#7CFF6B")
			box.Text = ""
		else
			status.Text = if type(result) == "table" and result.error then result.error else "Invalid code."
			status.TextColor3 = Color3.fromHex("#FF5A6A")
		end
	end
	box.FocusLost:Connect(function(enter)
		if enter then
			redeem()
		end
	end)
	Button.new({ Parent = content, Size = UDim2.fromOffset(240, 62), Position = UDim2.new(0.5, 0, 1, -4), AnchorPoint = Vector2.new(0.5, 1), Style = "Green", Text = "Redeem", TextSize = 34, OnClick = redeem })

	UIController.Register("Codes", {
		Open = function()
			status.Text = ""
			panel:Open()
		end,
		Close = function()
			panel:Close()
		end,
		IsOpen = function()
			return panel.Visible
		end,
	})
end

return CodesScreen
