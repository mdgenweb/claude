--!strict
-- World portal menu ("World"): opened from a portal with UIController.Open("World", worldId).
-- Shows the world, its two unlock requirements (reach the end of the previous river + rebirths)
-- with check marks, and a Travel button that sends a RequestEnterWorld intent. The server
-- re-checks everything; this screen only explains what is missing.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Worlds = require(Shared.Definitions.Worlds)
local Zones = require(Shared.Definitions.Zones)
local Themes = require(Shared.Visual.Themes)
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

local WorldScreen = {}

local PANEL = Vector2.new(900, 600)

local shell: MenuShell.Shell
local worldId = 1
local swatch: Frame
local swatchGradient: UIGradient
local nameLabel: TextLabel
local descLabel: TextLabel
local stateLabel: TextLabel
local reqLabels: { TextLabel } = {}
local travelButton: Button.Button

type Requirement = { Text: string, Met: boolean }

local function requirements(world: Worlds.World, data: { [string]: any }): { Requirement }
	local out: { Requirement } = {}
	local zones = if type(data.Zones) == "table" then data.Zones else {}
	local rebirths = if type(data.Rebirths) == "number" then data.Rebirths else 0
	if world.UnlockZone then
		local zone = Zones.Get(world.UnlockZone)
		local prev = Worlds.Get(world.Id - 1)
		table.insert(out, {
			Text = string.format("Throw to %s in %s (%s)", if zone then zone.Name else "the end of the river", if prev then prev.Name else "the last world", if zone then Format.Meters(zone.Distance) else "?"),
			Met = zones[world.UnlockZone] == true,
		})
	end
	if world.UnlockRebirths > 0 then
		table.insert(out, { Text = string.format("Reach %d rebirths (you have %d)", world.UnlockRebirths, rebirths), Met = rebirths >= world.UnlockRebirths })
	end
	if world.UnlockWins > 0 then
		local wins = if type(data.Wins) == "number" then data.Wins else 0
		table.insert(out, { Text = string.format("Pay %s Wins", Format.Short(world.UnlockWins)), Met = wins >= world.UnlockWins })
	end
	return out
end

local function refresh()
	local data = StateController.Data
	local world = Worlds.Get(worldId)
	if data == nil or world == nil then
		return
	end
	local theme = Themes[world.Theme]
	if theme then
		swatchGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHex(theme.Sky.Top)),
			ColorSequenceKeypoint.new(0.5, Color3.fromHex(theme.Water)),
			ColorSequenceKeypoint.new(1, Color3.fromHex(theme.FloorA)),
		})
	end
	nameLabel.Text = string.upper(world.Name)
	descLabel.Text = world.Description
	local unlocked = type(data.Worlds) == "table" and data.Worlds[tostring(world.Id)] == true
	local here = data.World == world.Id
	local reqs = if unlocked then {} else requirements(world, data)
	local allMet = true
	for i, label in reqLabels do
		local req = reqs[i]
		if req then
			label.Visible = true
			label.Text = (if req.Met then Theme.Icons.Check else Theme.Icons.Lock) .. "  " .. req.Text
			label.TextColor3 = if req.Met then Theme.Colors.Success else Theme.Colors.Text
			allMet = allMet and req.Met
		else
			label.Visible = false
		end
	end
	if unlocked then
		stateLabel.Text = if here then "YOU ARE HERE" else "UNLOCKED"
		stateLabel.TextColor3 = Theme.Colors.Success
	else
		stateLabel.Text = if allMet then "READY TO UNLOCK!" else "LOCKED"
		stateLabel.TextColor3 = if allMet then Theme.Colors.Skill else Theme.Colors.Danger
	end
	if here then
		travelButton:SetText("YOU ARE HERE")
		travelButton:SetStyle("Grey")
		travelButton:SetEnabled(false)
	elseif unlocked or allMet then
		travelButton:SetText(if unlocked then "TRAVEL" else "UNLOCK & TRAVEL")
		travelButton:SetStyle("Green")
		travelButton:SetEnabled(true)
	else
		travelButton:SetText("LOCKED")
		travelButton:SetStyle("Disabled")
		travelButton:SetEnabled(false)
	end
end

function WorldScreen.Init()
	shell = MenuShell.new({
		Name = "World",
		Title = "Portal",
		Icon = Theme.Icons.World,
		Size = PANEL,
		Accent = Color3.fromHex("#7CFFB2"),
		OnOpen = function(id: any)
			if type(id) == "number" and Worlds.Get(id) then
				worldId = id
			end
			refresh()
		end,
		FirstSelection = function()
			return travelButton.Instance
		end,
	})
	local content = shell.Content
	swatch = Create("Frame", {
		Name = "Swatch",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 0, 150),
		Parent = content,
	})
	Create.Corner(16, swatch)
	swatchGradient = Instance.new("UIGradient")
	swatchGradient.Rotation = 90
	swatchGradient.Parent = swatch
	nameLabel = Create.Text({
		Text = "",
		Size = UDim2.new(1, -40, 0, 70),
		Position = UDim2.fromOffset(20, 18),
		Font = Theme.Fonts.Display,
		TextSize = 64,
		Scaled = true,
		Stroke = 4,
		Parent = swatch,
	})
	descLabel = Create.Text({
		Text = "",
		Size = UDim2.new(1, -40, 0, 34),
		Position = UDim2.fromOffset(20, 96),
		Font = Theme.Fonts.Body,
		TextSize = 28,
		Scaled = true,
		Stroke = 2,
		Parent = swatch,
	})
	stateLabel = Create.Text({
		Text = "",
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(0, 166),
		Font = Theme.Fonts.Display,
		TextSize = 40,
		Scaled = true,
		Stroke = 3,
		Parent = content,
	})
	for i = 1, 3 do
		reqLabels[i] = Create.Text({
			Name = "Req" .. i,
			Text = "",
			Size = UDim2.new(1, -40, 0, 40),
			Position = UDim2.fromOffset(20, 220 + (i - 1) * 48),
			Font = Theme.Fonts.Body,
			TextSize = 28,
			Scaled = true,
			XAlign = Enum.TextXAlignment.Left,
			Stroke = 1.8,
			Parent = content,
		})
	end
	travelButton = Button.new({
		Parent = content,
		Name = "Travel",
		Size = UDim2.fromOffset(420, 76),
		Position = UDim2.new(0.5, 0, 1, -8),
		AnchorPoint = Vector2.new(0.5, 1),
		Style = "Green",
		Text = "TRAVEL",
		TextSize = 34,
		OnClick = function()
			local target = worldId
			task.spawn(function()
				local result = Net.Invoke("RequestEnterWorld", false, target)
				if result.ok then
					UIController.Close("World")
				end
			end)
		end,
	})
	UIController.Register("World", shell)
	StateController.DataChanged:Connect(function()
		if shell:IsOpen() then
			refresh()
		end
	end)
end

return WorldScreen
