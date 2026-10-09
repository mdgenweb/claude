--!strict
-- Bottom-centre progress block: "⚡ N SKILL" / "xM Multiplier" row above a wide level bar
-- ("Level L" + "x/y" or "MAX LEVEL"). Level is derived from Skill on the server: Data.XP is the
-- Skill progress inside the level and Derived.XPToNext the level's width. At the cap the bar turns
-- gold and a pulsing "REBIRTH!" hint opens the Rebirth screen. FlashLevel() pops "LEVEL UP!".
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage:WaitForChild("Shared").Util.Format)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local Button = require(script.Parent.Button)
local UIController = require(UI.Parent.Controllers.UIController)

export type LevelBar = {
	Instance: Frame,
	Update: (LevelBar, { [string]: any }) -> (),
	Animate: (LevelBar, number) -> (),
	FlashLevel: (LevelBar, number) -> (),
	Maxed: boolean,
}

local HudLevelBar = {}

local WIDTH = 660
local BAR_W = 640
local BAR_H = 54
local ROW_H = 42

local FILL = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local GOLD_TOP = Color3.fromHex("#FFE27A")
local GOLD_BOTTOM = Color3.fromHex("#F2A900")

HudLevelBar.Height = ROW_H + 4 + BAR_H

function HudLevelBar.new(parent: Instance, layoutOrder: number?): LevelBar
	local root: Frame = Create("Frame", {
		Name = "LevelBlock",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(WIDTH, HudLevelBar.Height),
		LayoutOrder = layoutOrder or 0,
		Parent = parent,
	})

	-- Skill / multiplier row
	local skillText = Create.Text({
		Name = "Skill",
		Text = Theme.Icons.Skill .. " 0 SKILL",
		Size = UDim2.new(0.58, 0, 0, ROW_H),
		Position = UDim2.fromOffset(10, 0),
		Font = Theme.Fonts.Display,
		TextSize = 38,
		Scaled = true,
		Color = Theme.Colors.Skill,
		Stroke = 3,
		XAlign = Enum.TextXAlignment.Left,
		Parent = root,
	})
	local multText = Create.Text({
		Name = "Multiplier",
		Text = "x1 Multiplier",
		Size = UDim2.new(0.4, 0, 0, ROW_H - 6),
		Position = UDim2.new(1, -10, 0, 3),
		AnchorPoint = Vector2.new(1, 0),
		Font = Theme.Fonts.Display,
		TextSize = 32,
		Scaled = true,
		Color = Color3.fromHex("#9FE6FF"),
		Stroke = 3,
		XAlign = Enum.TextXAlignment.Right,
		Parent = root,
	})

	-- Level bar
	local bar: Frame = Create("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, ROW_H + 4),
		Size = UDim2.fromOffset(BAR_W, BAR_H),
		BackgroundColor3 = Theme.Colors.LevelTrack,
		BackgroundTransparency = 0.05,
		Parent = root,
	})
	Create.Corner(14, bar)
	local barStroke = Create.Stroke(bar, Theme.Colors.Stroke, 3.5, 0, true)
	local fill: Frame = Create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = bar,
	})
	Create.Corner(14, fill)
	local fillGradient = Create.Gradient(fill, Theme.Colors.LevelFillTop, Theme.Colors.LevelFillBottom, 90)
	local gloss: Frame = Create("Frame", {
		Name = "Gloss",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.78,
		Position = UDim2.fromOffset(6, 4),
		Size = UDim2.new(1, -12, 0.36, 0),
		ZIndex = 2,
		Parent = bar,
	})
	Create.Corner(10, gloss)
	local levelText = Create.Text({
		Name = "Level",
		Text = "Level 1",
		Size = UDim2.new(0.45, 0, 0.8, 0),
		Position = UDim2.new(0, 16, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Font = Theme.Fonts.Display,
		TextSize = 34,
		Scaled = true,
		Stroke = 3,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = bar,
	})
	local progressText = Create.Text({
		Name = "Progress",
		Text = "0/1",
		Size = UDim2.new(0.5, 0, 0.8, 0),
		Position = UDim2.new(1, -16, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Font = Theme.Fonts.Display,
		TextSize = 34,
		Scaled = true,
		Stroke = 3,
		XAlign = Enum.TextXAlignment.Right,
		ZIndex = 3,
		Parent = bar,
	})

	-- "REBIRTH!" hint at the cap (wrapper holds the pulse scale; the button owns its hover scale)
	local hintHolder: Frame = Create("Frame", {
		Name = "RebirthHint",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, 12, 0.5, 0),
		Size = UDim2.fromOffset(150, 60),
		Visible = false,
		Parent = bar,
	})
	local hintScale = Instance.new("UIScale")
	hintScale.Parent = hintHolder
	Button.new({
		Parent = hintHolder,
		Name = "Rebirth",
		Size = UDim2.fromScale(1, 1),
		Style = "Pink",
		Text = Theme.Icons.Rebirth .. " REBIRTH!",
		TextSize = 26,
		Corner = 14,
		OnClick = function()
			UIController.Open("Rebirth")
		end,
	})

	-- "LEVEL UP!" pop centred on the bar (one reused label; never hidden by context panels)
	local levelUp = Create.Text({
		Name = "LevelUp",
		Text = "",
		Size = UDim2.fromOffset(200, 46),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = Theme.Fonts.Display,
		TextSize = 46,
		Scaled = true,
		Color = Color3.fromHex("#7FFFD4"),
		Stroke = 3.5,
		ZIndex = 5,
		Parent = bar,
	})
	levelUp.Visible = false
	local levelUpScale = Instance.new("UIScale")
	levelUpScale.Parent = levelUp

	local self = { Instance = root, Maxed = false } :: any
	local lastLevel = 0
	local flashToken = 0

	function self.Update(this: any, data: { [string]: any })
		local derived = if type(data.Derived) == "table" then data.Derived else {}
		local skill = tonumber(data.Skill) or 0
		local level = tonumber(data.Level) or 1
		local cap = tonumber(derived.LevelCap) or math.huge
		local span = math.max(tonumber(derived.XPToNext) or 1, 1e-9)
		local xp = tonumber(data.XP) or 0
		local maxed = level >= cap

		skillText.Text = Theme.Icons.Skill .. " " .. Format.Short(skill) .. " SKILL"
		multText.Text = "x" .. Format.Short(tonumber(derived.SkillMultiplier) or 1) .. " Multiplier"
		levelText.Text = "Level " .. tostring(level)
		progressText.Text = if maxed then "MAX LEVEL" else Format.Short(xp) .. "/" .. Format.Short(span)

		local ratio = if maxed then 1 else math.clamp(xp / span, 0, 1)
		if ratio > 0 then
			ratio = math.max(ratio, 0.04) -- keep the rounded fill readable when nearly empty
		end
		if level > lastLevel and lastLevel > 0 then
			fill.Size = UDim2.fromScale(0, 1)
		end
		lastLevel = level
		TweenService:Create(fill, FILL, { Size = UDim2.fromScale(ratio, 1) }):Play()

		if maxed ~= this.Maxed then
			this.Maxed = maxed
			fillGradient.Color = if maxed
				then ColorSequence.new(GOLD_TOP, GOLD_BOTTOM)
				else ColorSequence.new(Theme.Colors.LevelFillTop, Theme.Colors.LevelFillBottom)
			hintHolder.Visible = maxed
			if not maxed then
				barStroke.Color = Theme.Colors.Stroke
				hintScale.Scale = 1
			end
		end
	end

	-- Pulses the cap hint (called by the HUD ticker).
	function self.Animate(this: any, t: number)
		if this.Maxed then
			local w = (math.sin(t * 5) + 1) / 2
			hintScale.Scale = 1 + w * 0.1
			barStroke.Color = Theme.Colors.Stroke:Lerp(GOLD_TOP, w * 0.8)
		end
	end

	function self.FlashLevel(_: any, level: number)
		flashToken += 1
		local token = flashToken
		levelUp.Text = "LEVEL UP! " .. tostring(level)
		levelUp.Visible = true
		levelUp.TextTransparency = 0
		levelUp.Position = UDim2.fromScale(0.5, 0.5)
		levelUpScale.Scale = 0.4
		TweenService:Create(levelUpScale, POP, { Scale = 1.05 }):Play()
		TweenService:Create(levelUp, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0.5, -10),
		}):Play()
		barStroke.Color = Color3.fromHex("#7FFFD4")
		task.delay(1.1, function()
			if token ~= flashToken then
				return
			end
			local fade = TweenService:Create(levelUp, TweenInfo.new(0.3), { TextTransparency = 1 })
			fade:Play()
			fade.Completed:Wait()
			if token == flashToken then
				levelUp.Visible = false
				if not self.Maxed then
					barStroke.Color = Theme.Colors.Stroke
				end
			end
		end)
	end

	return self :: LevelBar
end

return HudLevelBar
