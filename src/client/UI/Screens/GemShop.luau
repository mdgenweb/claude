--!strict
-- Gem packs (the "+" next to the gem counter). Purchases go through Roblox developer products;
-- packs without a configured product id act as free test grants in Studio only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Net.Remotes)

local Client = script.Parent.Parent.Parent
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local Button = require(Client.UI.Components.Button)
local Panel = require(Client.UI.Components.Panel)
local Icons = require(Client.UI.Components.Icons)
local UIController = require(Client.Controllers.UIController)

local GemShop = {}

function GemShop.Init()
	local panel = Panel.new({
		Parent = UIController.Layer("Menus"),
		Name = "Gems",
		Title = "Gems",
		Size = Vector2.new(1000, 520),
		OnClose = function()
			UIController.Close("Gems")
		end,
	})
	local row: Frame = Create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 1, -50), Parent = panel.Content })
	Create.List(row, Enum.FillDirection.Horizontal, 18, Enum.HorizontalAlignment.Center)
	for i, product in Economy.GemProducts do
		local card: Frame = Create("Frame", { BackgroundColor3 = Theme.Colors.Card, Size = UDim2.fromOffset(222, 360), LayoutOrder = i, Parent = row })
		Create.Stroke(card, Theme.Colors.PanelBorder, 2, 0, true)
		local art: Frame = Create("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 170), BackgroundColor3 = Color3.new(1, 1, 1), Parent = card })
		Create.Gradient(art, Color3.fromHex("#5BA8FF"), Color3.fromHex("#1C3F99"), 90)
		for k = 1, math.min(i + 1, 4) do
			local gem = Icons.Gem(UDim2.fromOffset(90 - k * 8, 90 - k * 8), art)
			gem.AnchorPoint = Vector2.new(0.5, 0.5)
			gem.Position = UDim2.fromScale(0.5 + (k - 1) * 0.12 * (if k % 2 == 0 then -1 else 1), 0.5 + (k - 1) * 0.08)
		end
		if product.Badge then
			Create.Text({ Text = product.Badge, Size = UDim2.fromOffset(90, 30), Position = UDim2.new(1, -6, 0, 6), AnchorPoint = Vector2.new(1, 0), Font = Theme.Fonts.Display, TextSize = 22, Scaled = true, Color = Theme.Colors.Gold, Stroke = 2, Rotation = 8, Parent = art })
		end
		Create.Text({ Text = Format.Commas(product.Gems), Size = UDim2.new(1, -20, 0, 44), Position = UDim2.fromOffset(10, 190), Font = Theme.Fonts.Display, TextSize = 40, Scaled = true, Color = Theme.Colors.GemText, Stroke = 2.5, Parent = card })
		Create.Text({ Text = "Gems", Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 234), Font = Theme.Fonts.Body, TextSize = 26, Color = Theme.Colors.TextDim, Parent = card })
		local label = if product.ProductId == 0 then (if RunService:IsStudio() then "Test" else "Soon") else ("R$ " .. product.Robux)
		Button.new({ Parent = card, Size = UDim2.new(1, -24, 0, 62), Position = UDim2.new(0.5, 0, 1, -12), AnchorPoint = Vector2.new(0.5, 1), Style = "Green", Text = label, TextSize = 32, OnClick = function()
			local result = Remotes.Function("StoreRequest"):InvokeServer("BuyGems", product.Key)
			if type(result) == "table" and result.ok then
				if result.message then
					UIController.Toast(result.message, "Success")
				end
			else
				UIController.Toast(if type(result) == "table" and result.error then result.error else "Purchase failed.", "Error")
			end
		end })
	end
	Create.Text({ Text = "Gems reroll your battle offers and buy extra collection picks.", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 1, -30), Font = Theme.Fonts.BodySemi, TextSize = 24, Color = Theme.Colors.TextDim, Parent = panel.Content })

	UIController.Register("Gems", {
		Open = function()
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

return GemShop
