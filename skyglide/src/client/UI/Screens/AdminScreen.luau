--!strict
-- Admin / diagnostics menu ("Admin"). Only reachable for allow-listed admins (Data.IsAdmin; the
-- HUD only shows its tile then). Every action is an AdminRequest that the server re-checks
-- against Config/Admin, so a normal player can never use it even by firing the remote directly.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
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

local AdminScreen = {}

local PANEL = Vector2.new(1160, 680)

type Action = { Text: string, Style: string, Action: string, Arg: any? }

local SECTIONS: { { Title: string, Actions: { Action } } } = {
	{
		Title = "GRANTS",
		Actions = {
			{ Text = "+1M Skill", Style = "Gold", Action = "GrantSkill", Arg = 1e6 },
			{ Text = "+1B Skill", Style = "Gold", Action = "GrantSkill", Arg = 1e9 },
			{ Text = "+1M Wins", Style = "Green", Action = "GrantWins", Arg = 1e6 },
			{ Text = "+1B Wins", Style = "Green", Action = "GrantWins", Arg = 1e9 },
		},
	},
	{
		Title = "PROGRESS",
		Actions = {
			{ Text = "Max Level", Style = "Blue", Action = "MaxLevel" },
			{ Text = "Unlock Worlds", Style = "Purple", Action = "UnlockWorlds" },
			{ Text = "Reset Tutorial", Style = "Orange", Action = "ResetTutorial" },
		},
	},
	{
		Title = "LIVE EVENT",
		Actions = {
			{ Text = "Start (30 min)", Style = "Pink", Action = "StartEvent", Arg = 30 },
			{ Text = "Stop Event", Style = "Red", Action = "StopEvent" },
		},
	},
}

local shell: MenuShell.Shell
local statsLabel: TextLabel
local eventLabel: TextLabel
local refreshButton: Button.Button

local function refreshStats()
	local result = Net.Invoke("AdminRequest", true, "Stats")
	if result.ok and type(result.stats) == "table" then
		local s = result.stats
		statsLabel.Text = string.format(
			"Players: %s\nActive flights: %s\nServer memory: %s MB\nHeartbeat: %s fps\nData store: %s",
			tostring(s.Players),
			tostring(s.Flights),
			tostring(s.MemoryMB),
			tostring(s.Heartbeat),
			if s.MockData then "IN-MEMORY MOCK (no API access)" else "DataStore"
		)
	else
		statsLabel.Text = "Not allowed."
	end
	local event = StateController.Event
	if event.Active then
		eventLabel.Text = string.format("%s active · ends in %s", event.Name, Format.Clock(event.EndsAt - Workspace:GetServerTimeNow()))
	else
		eventLabel.Text = "No live event running."
	end
end

function AdminScreen.Init()
	shell = MenuShell.new({
		Name = "Admin",
		Title = "Admin / Diagnostics",
		Icon = "🛠️",
		Size = PANEL,
		Accent = Theme.Colors.Danger,
		OnOpen = function()
			local data = StateController.Data
			if not (data and data.IsAdmin) then
				task.defer(UIController.Close, "Admin")
				return
			end
			task.spawn(refreshStats)
		end,
		FirstSelection = function()
			return refreshButton.Instance
		end,
	})
	local content = shell.Content

	local statsCard: Frame = Create("Frame", {
		Name = "Stats",
		BackgroundColor3 = Theme.Colors.CardDeep,
		Size = UDim2.new(0.4, -8, 1, 0),
		Parent = content,
	})
	Create.Corner(14, statsCard)
	Create.Stroke(statsCard, Theme.Colors.PanelEdge, 2, 0.4, true)
	Create.Text({
		Text = "SERVER",
		Size = UDim2.new(1, -24, 0, 36),
		Position = UDim2.fromOffset(12, 10),
		Font = Theme.Fonts.Display,
		TextSize = 30,
		Scaled = true,
		XAlign = Enum.TextXAlignment.Left,
		Stroke = 2.5,
		Parent = statsCard,
	})
	statsLabel = Create.Text({
		Text = "...",
		Size = UDim2.new(1, -24, 0, 220),
		Position = UDim2.fromOffset(12, 56),
		Font = Theme.Fonts.Body,
		TextSize = 24,
		XAlign = Enum.TextXAlignment.Left,
		YAlign = Enum.TextYAlignment.Top,
		Wrapped = true,
		Stroke = 1.2,
		Parent = statsCard,
	})
	eventLabel = Create.Text({
		Text = "",
		Size = UDim2.new(1, -24, 0, 60),
		Position = UDim2.fromOffset(12, 290),
		Font = Theme.Fonts.Body,
		TextSize = 22,
		Color = Theme.Colors.Rebirth,
		XAlign = Enum.TextXAlignment.Left,
		YAlign = Enum.TextYAlignment.Top,
		Wrapped = true,
		Stroke = 1.2,
		Parent = statsCard,
	})
	refreshButton = Button.new({
		Parent = statsCard,
		Name = "Refresh",
		Size = UDim2.new(1, -24, 0, 62),
		Position = UDim2.new(0, 12, 1, -12),
		AnchorPoint = Vector2.new(0, 1),
		Style = "Blue",
		Text = "Refresh",
		TextSize = 26,
		OnClick = function()
			task.spawn(refreshStats)
		end,
	})

	local actions: Frame = Create("Frame", {
		Name = "Actions",
		BackgroundTransparency = 1,
		Size = UDim2.new(0.6, -8, 1, 0),
		Position = UDim2.new(0.4, 8, 0, 0),
		Parent = content,
	})
	Create.List(actions, Enum.FillDirection.Vertical, 12)
	for i, section in SECTIONS do
		local box: Frame = Create("Frame", {
			Name = section.Title,
			BackgroundColor3 = Theme.Colors.Card,
			Size = UDim2.new(1, 0, 0, 160),
			LayoutOrder = i,
			Parent = actions,
		})
		Create.Corner(14, box)
		Create.Stroke(box, Theme.Colors.PanelBorder, 2, 0, true)
		Create.Text({
			Text = section.Title,
			Size = UDim2.new(1, -24, 0, 32),
			Position = UDim2.fromOffset(12, 8),
			Font = Theme.Fonts.Display,
			TextSize = 28,
			Scaled = true,
			XAlign = Enum.TextXAlignment.Left,
			Stroke = 2,
			Parent = box,
		})
		local row: Frame = Create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(12, 56),
			Size = UDim2.new(1, -24, 0, 70),
			Parent = box,
		})
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.new(1 / #section.Actions, -10, 0, 66)
		layout.CellPadding = UDim2.fromOffset(10, 0)
		layout.Parent = row
		for j, action in section.Actions do
			Button.new({
				Parent = row,
				Name = action.Action .. j,
				Size = UDim2.fromOffset(100, 66),
				LayoutOrder = j,
				Style = action.Style,
				Text = action.Text,
				TextSize = 22,
				OnClick = function()
					task.spawn(function()
						local result = Net.Invoke("AdminRequest", false, action.Action, action.Arg)
						if result.ok then
							UIController.Toast("Admin: " .. action.Text, "Success")
						end
						refreshStats()
					end)
				end,
			})
		end
	end

	UIController.Register("Admin", shell)
end

return AdminScreen
