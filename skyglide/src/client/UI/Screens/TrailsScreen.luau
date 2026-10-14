--!strict
-- Trails menu ("Trails"): every trail with its gradient swatch, Wins bonus and price.
-- Buy / Equip / Unequip are RequestTrailAction intents; the server spends the Wins.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Trails = require(Shared.Definitions.Trails)
local Format = require(Shared.Util.Format)

local Client = script.Parent.Parent.Parent
local StateController = require(Client.Controllers.StateController)
local UIController = require(Client.Controllers.UIController)
local Net = require(Client.Controllers.Net)
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local Components = Client.UI.Components
local MenuShell = require(Components.MenuShell)
local MenuCard = require(Components.MenuCard)
local MenuGrid = require(Components.MenuGrid)

local TrailsScreen = {}

local PANEL = Vector2.new(1240, 740)
local WIDTH = PANEL.X - 36

local shell: MenuShell.Shell
local cards: { [string]: MenuCard.Card } = {}
local firstButton: GuiObject? = nil

local function gradientOf(trail: Trails.Trail): ColorSequence
	local keys = {}
	for i, h in trail.Colors do
		local t = if #trail.Colors == 1 then 0 else (i - 1) / (#trail.Colors - 1)
		table.insert(keys, ColorSequenceKeypoint.new(t, Color3.fromHex(h)))
	end
	if #keys == 1 then
		table.insert(keys, ColorSequenceKeypoint.new(1, keys[1].Value))
	end
	return ColorSequence.new(keys)
end

local function refresh()
	local data = StateController.Data
	if data == nil then
		return
	end
	local owned = if type(data.Trails) == "table" then data.Trails else {}
	local wins = if type(data.Wins) == "number" then data.Wins else 0
	for _, trail in Trails.List do
		local card = cards[trail.Id]
		if data.Trail == trail.Id then
			card:SetAction("UNEQUIP", "Orange", true)
			card:SetBadge("EQUIPPED", Theme.Colors.Success)
		elseif owned[trail.Id] then
			card:SetAction("EQUIP", "Blue", true)
			card:SetBadge("OWNED", Theme.Colors.PanelEdge)
		else
			local affordable = wins >= trail.Price
			card:SetAction(string.format("%s %s", Theme.Icons.Wins, Format.Short(trail.Price)), if affordable then "Green" else "Grey", true)
			card:SetBadge(nil)
		end
	end
end

local function act(trail: Trails.Trail)
	local data = StateController.Data
	if data == nil then
		return
	end
	local owned = if type(data.Trails) == "table" then data.Trails else {}
	local action = if data.Trail == trail.Id then "Unequip" elseif owned[trail.Id] then "Equip" else "Buy"
	task.spawn(Net.Invoke, "RequestTrailAction", false, action, trail.Id)
end

function TrailsScreen.Init()
	shell = MenuShell.new({
		Name = "Trails",
		Title = "Trails",
		Icon = Theme.Icons.Trails,
		Size = PANEL,
		Accent = Color3.fromHex("#B65CFF"),
		OnOpen = function()
			refresh()
		end,
		FirstSelection = function()
			return firstButton
		end,
	})
	local grid = MenuGrid.new({
		Parent = shell.Content,
		Name = "TrailGrid",
		Size = UDim2.fromScale(1, 1),
		Cell = Vector2.new(MenuGrid.CellWidth(WIDTH, 4), 300),
	})
	for i, trail in Trails.List do
		local card = MenuCard.new({
			Parent = grid,
			Name = trail.Id,
			LayoutOrder = i,
			Accent = Theme.Rarity(trail.Rarity),
			Rainbow = trail.Rarity == "Mythic",
			Icon = Theme.Icons.Trails,
			Title = trail.Name,
			Subtitle = string.format("+%s%% Wins", Format.Short(trail.WinsBoost * 100)),
			Description = string.upper(trail.Rarity) .. "\nA ribbon behind you and your glider.",
			ButtonText = "",
			OnClick = function()
				act(trail)
			end,
		})
		-- gradient swatch across the top of the card
		local swatch: Frame = Create("Frame", {
			Name = "Swatch",
			BackgroundColor3 = Color3.new(1, 1, 1),
			Size = UDim2.new(1, -24, 0, 12),
			Position = UDim2.fromOffset(12, 8),
			ZIndex = 4,
			Parent = card.Instance,
		})
		Create.Corner(6, swatch)
		local g = Instance.new("UIGradient")
		g.Color = gradientOf(trail)
		g.Parent = swatch
		cards[trail.Id] = card
		if i == 1 and card.Button then
			firstButton = card.Button.Instance
		end
	end
	UIController.Register("Trails", shell)
	StateController.DataChanged:Connect(function()
		if shell:IsOpen() then
			refresh()
		end
	end)
end

return TrailsScreen
