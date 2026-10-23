--!strict
-- Settings menu ("Settings"): sound, camera and effects toggles plus a personal stats card.
-- Toggles send RequestSetting intents (cosmetic preferences); the sound toggle also applies
-- locally right away. Init() keeps AudioController in sync with the saved setting even if this
-- panel is never opened.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Worlds = require(Shared.Definitions.Worlds)
local Format = require(Shared.Util.Format)

local Client = script.Parent.Parent.Parent
local StateController = require(Client.Controllers.StateController)
local UIController = require(Client.Controllers.UIController)
local AudioController = require(Client.Controllers.AudioController)
local Net = require(Client.Controllers.Net)
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local Components = Client.UI.Components
local MenuShell = require(Components.MenuShell)
local MenuToggle = require(Components.MenuToggle)
local Icon = require(Components.Icon)

local SettingsScreen = {}

local PANEL = Vector2.new(1100, 640)

type Row = { Key: string, Title: string, Hint: string, Icon: string }

local ROWS: { Row } = {
	{ Key = "Sfx", Title = "Sound effects", Hint = "Chimes, splashes and wind", Icon = "🔊" },
	{ Key = "FollowCam", Title = "Follow camera", Hint = "Chases your glider", Icon = "🎥" },
	{ Key = "LowFx", Title = "Low effects", Hint = "For older devices", Icon = "✨" },
}

local shell: MenuShell.Shell
local toggles: { [string]: MenuToggle.Toggle } = {}
local statsLabel: TextLabel
local firstToggle: GuiObject? = nil

local function setting(data: { [string]: any }, key: string, default: boolean): boolean
	local settings = data.Settings
	if type(settings) == "table" and type(settings[key]) == "boolean" then
		return settings[key]
	end
	return default
end

local function statsText(data: { [string]: any }): string
	local stats = if type(data.Stats) == "table" then data.Stats else {}
	local lines = {
		string.format("%s Throws: %s", Theme.Icons.Glider, Format.Commas(stats.Throws or 0)),
		string.format("%s Perfect catches: %s", Theme.Icons.Star, Format.Commas(stats.Perfects or 0)),
		string.format("%s Rebirths: %s", Theme.Icons.Rebirth, Format.Commas(data.Rebirths or 0)),
		string.format("%s Eggs hatched: %s", Theme.Icons.Egg, Format.Commas(stats.Hatches or 0)),
		string.format("%s Total Wins: %s", Theme.Icons.Wins, Format.Short(stats.TotalWins or 0)),
		string.format("%s Total Skill: %s", Theme.Icons.Skill, Format.Short(stats.TotalSkill or 0)),
		"",
		"BEST GLIDE PER WORLD",
	}
	local best = if type(data.Best) == "table" then data.Best else {}
	for _, world in Worlds.List do
		local meters = best[tostring(world.Id)]
		table.insert(lines, string.format("%s %s: %s", Theme.Icons.World, world.Name, if type(meters) == "number" then Format.Meters(meters) else "-"))
	end
	return table.concat(lines, "\n")
end

local function refresh()
	local data = StateController.Data
	if data == nil then
		return
	end
	toggles.Sfx:Set(setting(data, "Sfx", true))
	toggles.FollowCam:Set(setting(data, "FollowCam", true))
	toggles.LowFx:Set(setting(data, "LowFx", false))
	statsLabel.Text = statsText(data)
end

function SettingsScreen.Init()
	shell = MenuShell.new({
		Name = "Settings",
		Title = "Settings",
		Icon = Theme.Icons.Settings,
		Size = PANEL,
		Accent = Theme.Colors.PanelEdge,
		OnOpen = function()
			refresh()
		end,
		FirstSelection = function()
			return firstToggle
		end,
	})
	local content = shell.Content
	local left: Frame = Create("Frame", {
		Name = "Toggles",
		BackgroundTransparency = 1,
		Size = UDim2.new(0.56, -10, 1, 0),
		Parent = content,
	})
	Create.List(left, Enum.FillDirection.Vertical, 14)
	for i, row in ROWS do
		local frame: Frame = Create("Frame", {
			Name = row.Key,
			BackgroundColor3 = Theme.Colors.Card,
			Size = UDim2.new(1, 0, 0, 104),
			LayoutOrder = i,
			Parent = left,
		})
		Create.Corner(14, frame)
		Create.Stroke(frame, Theme.Colors.PanelBorder, 2, 0, true)
		Icon.new({
			Icon = row.Icon,
			Size = UDim2.fromOffset(64, 64),
			Position = UDim2.new(0, 14, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			TextSize = 46,
			Parent = frame,
		})
		Create.Text({
			Text = row.Title,
			Size = UDim2.new(1, -260, 0, 36),
			Position = UDim2.fromOffset(92, 16),
			Font = Theme.Fonts.Display,
			TextSize = 30,
			Scaled = true,
			XAlign = Enum.TextXAlignment.Left,
			Stroke = 2,
			Parent = frame,
		})
		Create.Text({
			Text = row.Hint,
			Size = UDim2.new(1, -260, 0, 28),
			Position = UDim2.fromOffset(92, 56),
			Font = Theme.Fonts.Body,
			TextSize = 22,
			Scaled = true,
			Color = Theme.Colors.TextDim,
			XAlign = Enum.TextXAlignment.Left,
			Stroke = 1,
			Parent = frame,
		})
		local key = row.Key
		local toggle = MenuToggle.new({
			Parent = frame,
			Name = "Toggle",
			Value = key ~= "LowFx",
			Position = UDim2.new(1, -16, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			OnChanged = function(value: boolean)
				if key == "Sfx" then
					AudioController.SetEnabled(value)
				end
				Net.Fire("RequestSetting", key, value)
			end,
		})
		toggles[key] = toggle
		if i == 1 then
			firstToggle = toggle.Instance
		end
	end

	local right: Frame = Create("Frame", {
		Name = "Stats",
		BackgroundColor3 = Theme.Colors.CardDeep,
		Size = UDim2.new(0.44, -10, 1, 0),
		Position = UDim2.new(0.56, 10, 0, 0),
		Parent = content,
	})
	Create.Corner(14, right)
	Create.Stroke(right, Theme.Colors.PanelEdge, 2, 0.4, true)
	Create.Text({
		Text = "📊 YOUR STATS",
		Size = UDim2.new(1, -24, 0, 40),
		Position = UDim2.fromOffset(12, 10),
		Font = Theme.Fonts.Display,
		TextSize = 32,
		Scaled = true,
		XAlign = Enum.TextXAlignment.Left,
		Stroke = 2.5,
		Parent = right,
	})
	statsLabel = Create.Text({
		Name = "Lines",
		Text = "",
		Size = UDim2.new(1, -28, 1, -64),
		Position = UDim2.fromOffset(14, 58),
		Font = Theme.Fonts.Body,
		TextSize = 24,
		XAlign = Enum.TextXAlignment.Left,
		YAlign = Enum.TextYAlignment.Top,
		Wrapped = true,
		Stroke = 1.2,
		Parent = right,
	})

	UIController.Register("Settings", shell)
	StateController.DataChanged:Connect(function(data)
		if data then
			AudioController.SetEnabled(setting(data, "Sfx", true))
		end
		if shell:IsOpen() then
			refresh()
		end
	end)
end

return SettingsScreen
