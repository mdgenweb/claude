-- Gate prompt: appears when you walk up to a locked gate and shows exactly what is
-- missing (Power and Scrap) with one UNLOCK button.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Theme = require(Shared.Theme)

local UI = script.Parent.Parent
local UIKit = require(UI.UIKit)
local Copy = require(UI.Copy)
local Panels = require(UI.Panels)
local Toasts = require(UI.Toasts)
local Net = require(UI.Parent.Net)

local Gate = {}

local area = 2
local title: TextLabel
local blurb: TextLabel
local rows = {}
local button

local function refresh()
	local s = Net.State
	if not s then
		return
	end
	local def = Config.Areas[area]
	title.Text = string.upper(def.Name)
	blurb.Text = string.format("%s · %s HP · %d Scrap each", def.Blurb, Economy.format(def.HP), def.Scrap)
	local check = Economy.checkGate(area, s.Level, s.Scrap, { [2] = Net.unlocked(2) })
	local function set(row, ok: boolean, text: string)
		row.Mark.Text = if ok then "✅" else "❌"
		row.Label.Text = text
		row.Label.TextColor3 = if ok then Theme.Good else Theme.White
	end
	if check.needPrevious then
		set(rows[1], false, Copy.Gate.NeedPrevious)
		rows[2].Mark.Text = ""
		rows[2].Label.Text = ""
	else
		set(
			rows[1],
			not check.needPower,
			string.format(Copy.Gate.NeedPower, Economy.format(def.GatePower))
				.. string.format("  (you: %s)", Economy.format(s.Power))
		)
		set(rows[2], not check.needScrap, string.format(Copy.Gate.NeedScrap, Economy.format(def.GateScrap)))
	end
	button:SetText(string.format("%s · ⚙️ %s", Copy.Gate.Button, Economy.format(def.GateScrap)))
	button:SetEnabled(check.ok)
	if Net.unlocked(area) then
		Panels.close()
	end
end

function Gate.init()
	local panel = Panels.create({
		Name = "Gate",
		Title = "UNLOCK",
		Icon = "🔓",
		Swatch = Theme.Swatch.Blue,
		Width = 560,
		Height = 330,
		TabWidth = 230,
		Blocking = false,
	})
	local body = panel.Body
	title = UIKit.text(body, {
		Text = "",
		TextSize = 40,
		Color = Color3.fromHex("#FFB24A"),
		Size = UDim2.new(1, 0, 0, 46),
		StrokeThickness = 4,
	})
	blurb = UIKit.text(body, {
		Text = "",
		TextSize = 18,
		Font = Theme.Font.Body,
		Color = Theme.Muted,
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.fromOffset(0, 48),
	})
	for i = 1, 2 do
		local row = UIKit.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -40, 0, 34),
			Position = UDim2.fromOffset(20, 80 + (i - 1) * 40),
			Parent = body,
		})
		rows[i] = {
			Mark = UIKit.icon(row, "", UDim2.fromOffset(30, 30), UDim2.fromScale(0, 0.5), Vector2.new(0, 0.5)),
			Label = UIKit.text(row, {
				Text = "",
				TextSize = 22,
				Size = UDim2.new(1, -40, 1, 0),
				Position = UDim2.fromOffset(40, 0),
				XAlign = Enum.TextXAlignment.Left,
			}),
		}
	end
	button = UIKit.button(body, {
		Text = Copy.Gate.Button,
		TextSize = 28,
		Size = UDim2.fromOffset(320, 62),
		Position = UDim2.new(0.5, 0, 1, -6),
		AnchorPoint = Vector2.new(0.5, 1),
		Swatch = Theme.Swatch.Green,
		OnClick = function()
			local ok, msg = Net.request("UnlockGate", area)
			if ok then
				Panels.close()
			else
				Toasts.error(msg)
			end
		end,
		OnDisabledClick = function()
			Toasts.error("Keep smashing and upgrading to open this gate")
		end,
	})
	panel.OnOpen = function(whichArea)
		area = whichArea or area
		refresh()
	end
	Net.Changed:Connect(function()
		if Panels.isOpen("Gate") then
			refresh()
		end
	end)
end

return Gate
