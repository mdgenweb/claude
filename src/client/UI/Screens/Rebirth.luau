-- Rebirth: five milestones (+25% base Scrap each). Shows exactly what resets and what
-- stays, and needs a second tap to confirm.

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

local Rebirth = {}

local dots = {}
local reqRows = {}
local bonusLabel: TextLabel
local button
local confirming = false
local confirmToken = 0

local function setConfirm(on: boolean)
	confirming = on
	confirmToken += 1
	if on then
		button:SetText(Copy.Rebirth.Confirm)
		button:SetSwatch(Theme.Swatch.Red)
		local token = confirmToken
		task.delay(3, function()
			if confirmToken == token and confirming then
				setConfirm(false)
				Rebirth.refresh()
			end
		end)
	end
end

local function requirementRow(parent: Instance, order: number)
	local row = UIKit.new(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = order, Parent = parent }
	)
	local mark = UIKit.icon(row, "❌", UDim2.fromOffset(30, 30), UDim2.fromScale(0, 0.5), Vector2.new(0, 0.5))
	local label = UIKit.text(row, {
		Text = "",
		TextSize = 22,
		Size = UDim2.new(1, -40, 1, 0),
		Position = UDim2.fromOffset(40, 0),
		XAlign = Enum.TextXAlignment.Left,
	})
	return { Mark = mark, Label = label }
end

local function listCard(parent: Instance, title: string, items: { string }, swatch: Theme.Swatch, position: UDim2)
	local card = UIKit.surface(parent, {
		Size = UDim2.fromOffset(340, 150),
		Position = position,
		Swatch = swatch,
		Radius = Theme.Radius.M,
		Shine = false,
	})
	UIKit.text(
		card.Face,
		{ Text = title, TextSize = 24, Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 8) }
	)
	for i, item in items do
		UIKit.text(card.Face, {
			Text = "• " .. item,
			TextSize = 19,
			Font = Theme.Font.Body,
			Size = UDim2.new(1, -30, 0, 26),
			Position = UDim2.fromOffset(18, 10 + i * 32),
			XAlign = Enum.TextXAlignment.Left,
		})
	end
end

function Rebirth.refresh()
	local s = Net.State
	if not s then
		return
	end
	for i, dot in dots do
		local done = i <= s.Rebirths
		local nextOne = i == s.Rebirths + 1
		UIKit.setSwatch(
			dot.Gradient,
			if done then Theme.Swatch.Purple elseif nextOne then Theme.Swatch.Yellow else Theme.Swatch.Steel
		)
		dot.Label.Text = if done then "✓" else tostring(i)
	end
	local now = Economy.rebirthFactor(s.Rebirths)
	local after = Economy.rebirthFactor(s.Rebirths + 1)
	bonusLabel.Text = string.format("%s: x%.2f  →  x%.2f", Copy.Rebirth.Bonus, now, after)
	local check = Economy.checkRebirth(s.Level, s.CrusherDestroys, s.Scrap, s.Rebirths)
	local function set(row, ok: boolean, text: string)
		row.Mark.Text = if ok then "✅" else "❌"
		row.Label.Text = text
		row.Label.TextColor3 = if ok then Theme.Good else Theme.White
	end
	set(reqRows[1], check.powerOk, Copy.Rebirth.NeedPower .. string.format("  (%s)", Economy.format(s.Power)))
	set(
		reqRows[2],
		check.destroysOk,
		string.format(
			Copy.Rebirth.NeedSmashes,
			math.min(s.CrusherDestroys, Config.Rebirth.RequiredCrusherDestroys),
			Config.Rebirth.RequiredCrusherDestroys
		)
	)
	set(reqRows[3], check.scrapOk, string.format(Copy.Rebirth.NeedFee, Economy.format(check.fee)))
	if check.maxed then
		bonusLabel.Text = string.format("%s: x%.2f", Copy.Rebirth.Bonus, now)
		button:SetText(Copy.Rebirth.Maxed)
		button:SetEnabled(false)
		return
	end
	if not confirming then
		button:SetText(string.format("%s · ⚙️ %s", Copy.Rebirth.Button, Economy.format(check.fee)))
		button:SetSwatch(Theme.Swatch.Purple)
	end
	button:SetEnabled(check.ok)
end

function Rebirth.init()
	local panel = Panels.create({
		Name = "Rebirth",
		Title = Copy.Rebirth.Title,
		Icon = "♻️",
		Swatch = Theme.Swatch.Purple,
		Width = 760,
		Height = 540,
		TabWidth = 270,
	})
	local body = panel.Body

	local track = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 84), Parent = body })
	UIKit.new("Frame", {
		BackgroundColor3 = Theme.Ink,
		Size = UDim2.new(0.8, 0, 0, 8),
		Position = UDim2.fromScale(0.5, 0.36),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = track,
	})
	for i = 1, Economy.MaxRebirths do
		local x = 0.1 + (i - 1) * 0.2
		local dot = UIKit.surface(track, {
			Size = UDim2.fromOffset(52, 52),
			Position = UDim2.new(x, 0, 0.36, -2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Swatch = Theme.Swatch.Steel,
			Radius = 999,
			ShadowOffset = 3,
		})
		local label = UIKit.text(dot.Face, { Text = tostring(i), TextSize = 26 })
		UIKit.text(track, {
			Text = string.format("+%d%%", i * 25),
			TextSize = 17,
			Font = Theme.Font.Body,
			Color = Theme.Muted,
			Size = UDim2.fromOffset(80, 22),
			Position = UDim2.new(x, 0, 1, -6),
			AnchorPoint = Vector2.new(0.5, 1),
		})
		dots[i] = { Gradient = dot.Gradient, Label = label }
	end
	bonusLabel = UIKit.text(body, {
		Text = "",
		TextSize = 24,
		Color = Color3.fromHex("#E2C2FF"),
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 90),
	})

	local reqs = UIKit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -40, 0, 112),
		Position = UDim2.fromOffset(20, 126),
		Parent = body,
	})
	UIKit.list(reqs, true, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top)
	for i = 1, 3 do
		reqRows[i] = requirementRow(reqs, i)
	end

	listCard(body, Copy.Rebirth.Resets, Copy.Rebirth.ResetList, Theme.Swatch.Red, UDim2.fromOffset(4, 244))
	listCard(body, Copy.Rebirth.Keeps, Copy.Rebirth.KeepList, Theme.Swatch.Green, UDim2.new(1, -344, 0, 244))

	button = UIKit.button(body, {
		Name = "RebirthButton",
		Text = Copy.Rebirth.Button,
		TextSize = 30,
		Size = UDim2.fromOffset(380, 66),
		Position = UDim2.new(0.5, 0, 1, -6),
		AnchorPoint = Vector2.new(0.5, 1),
		Swatch = Theme.Swatch.Purple,
		OnClick = function()
			if not confirming then
				setConfirm(true)
				return
			end
			setConfirm(false)
			local ok, msg = Net.request("Rebirth")
			if ok then
				Panels.close()
			else
				Toasts.error(msg)
				Rebirth.refresh()
			end
		end,
		OnDisabledClick = function()
			Toasts.error("Finish the checklist above first")
		end,
	})

	panel.OnOpen = function()
		setConfirm(false)
		Rebirth.refresh()
	end
	Net.Changed:Connect(function()
		if Panels.isOpen("Rebirth") then
			Rebirth.refresh()
		end
	end)
end

return Rebirth
