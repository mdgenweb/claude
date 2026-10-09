--!strict
-- Rebirth menu ("Rebirth"): big "x<now> -> x<next>" Skill multiplier hero, level progress toward
-- the cap (Level / LevelCap, bar = Derived.RebirthProgress) with the cap after rebirth, what resets
-- and what is kept, and what the next rebirth unlocks (training pads gated at Rebirths + 1 in any
-- world, plus the next world's rebirth gate). The REBIRTH button is only enabled when
-- Derived.CanRebirth and just sends RequestRebirth; on success it plays the Rebirth sound with a
-- screen flash, a banner and a burst around the character.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Training = require(Shared.Definitions.Training)
local Worlds = require(Shared.Definitions.Worlds)
local Zones = require(Shared.Definitions.Zones)
local Format = require(Shared.Util.Format)

local Client = script.Parent.Parent.Parent
local StateController = require(Client.Controllers.StateController)
local UIController = require(Client.Controllers.UIController)
local AudioController = require(Client.Controllers.AudioController)
local Net = require(Client.Controllers.Net)
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local Effects = require(Client.VFX.Effects)
local Components = Client.UI.Components
local Button = require(Components.Button)
local MenuShell = require(Components.MenuShell)

local RebirthScreen = {}

local hex = Color3.fromHex
local PANEL = Vector2.new(1120, 720)
local PINK = Theme.Colors.Rebirth
local GOLD = Theme.Colors.Skill
local MAX_UNLOCK_LINES = 5

type Refs = {
	Now: TextLabel,
	Next: TextLabel,
	Count: TextLabel,
	LevelText: TextLabel,
	Percent: TextLabel,
	Fill: Frame,
	BarText: TextLabel,
	NextCap: TextLabel,
	Unlocks: { TextLabel },
	Rebirth: Button.Button,
	Glow: Frame,
}

local shell: MenuShell.Shell
local refs: Refs
local glowTween: Tween
local flash: Frame
local banner: Frame
local bannerScale: UIScale
local bannerTitle: TextLabel
local bannerSub: TextLabel

local function multText(m: any): string
	return "x" .. Format.Short(if type(m) == "number" then m else 1)
end

-- Lines for the "NEXT REBIRTH UNLOCKS" card.
local function unlockLines(data: { [string]: any }): { string }
	local rebirths = if type(data.Rebirths) == "number" then data.Rebirths else 0
	local unlocked = if type(data.Worlds) == "table" then data.Worlds else {}
	local reached = if type(data.Zones) == "table" then data.Zones else {}
	local nextR = rebirths + 1
	local lines = {}
	for _, pad in Training.List do
		if pad.PassKey == nil and pad.Rebirths == nextR then
			local world = Worlds.Get(pad.World)
			local name = if world then world.Name else ("World " .. pad.World)
			local lock = if unlocked[tostring(pad.World)] then "" else " " .. Theme.Icons.Lock
			table.insert(lines, string.format("🏋️ %sx Skill pad, %s%s", Format.Short(pad.Multiplier), name, lock))
		end
	end
	-- next world whose rebirth gate is still ahead
	for _, world in Worlds.List do
		if world.UnlockRebirths > rebirths and not unlocked[tostring(world.Id)] then
			if world.UnlockRebirths == nextR then
				table.insert(lines, string.format("%s Opens the %s gate!", Theme.Icons.World, world.Name))
				local zone = if world.UnlockZone then Zones.Get(world.UnlockZone) else nil
				if zone and not reached[zone.Id] then
					table.insert(lines, string.format("   (also land in %s)", zone.Name))
				end
			else
				local left = world.UnlockRebirths - rebirths
				table.insert(lines, string.format("%s %s gate: %d rebirths (%d to go)", Theme.Icons.World, world.Name, world.UnlockRebirths, left))
			end
			break
		end
	end
	if #lines == 0 then
		table.insert(lines, Theme.Icons.Star .. " A bigger multiplier and level cap!")
	end
	return lines
end

local function refresh()
	local data = StateController.Data
	if data == nil or refs == nil then
		return
	end
	local derived = StateController.Derived()
	local breakdown = if type(derived.Breakdown) == "table" then derived.Breakdown else {}
	local rebirths = if type(data.Rebirths) == "number" then data.Rebirths else 0
	local level = if type(data.Level) == "number" then data.Level else 1
	local cap = if type(derived.LevelCap) == "number" then derived.LevelCap else Economy.LevelCap(rebirths)
	local progress = math.clamp(if type(derived.RebirthProgress) == "number" then derived.RebirthProgress else level / cap, 0, 1)
	local can = derived.CanRebirth == true

	refs.Now.Text = multText(breakdown.Rebirth or Economy.RebirthMultiplier(rebirths))
	refs.Next.Text = multText(derived.NextRebirthMultiplier or Economy.RebirthMultiplier(rebirths + 1))
	refs.Count.Text = string.format("%s Rebirths: %s", Theme.Icons.Rebirth, Format.Commas(rebirths))
	refs.LevelText.Text = string.format("Level %d / %d", level, cap)
	refs.Percent.Text = Format.Percent(progress * 100)
	refs.Fill.Size = UDim2.fromScale(math.max(progress, 0.02), 1)
	if level >= cap then
		refs.BarText.Text = "MAX LEVEL - READY TO REBIRTH!"
	else
		local left = cap - level
		refs.BarText.Text = string.format("%d level%s to go", left, if left == 1 then "" else "s")
	end
	refs.NextCap.Text = string.format("Level cap after rebirth: %d", Economy.LevelCap(rebirths + 1))

	local lines = unlockLines(data)
	for i, label in refs.Unlocks do
		local line = lines[i]
		label.Visible = line ~= nil
		if line then
			label.Text = line
		end
	end

	if can then
		refs.Rebirth:SetText(Theme.Icons.Rebirth .. " REBIRTH")
		refs.Rebirth:SetStyle("Pink")
		refs.Rebirth:SetEnabled(true)
	else
		refs.Rebirth:SetText("REACH LEVEL " .. tostring(cap))
		refs.Rebirth:SetEnabled(false)
	end
	refs.Glow.Visible = can
	if can and shell:IsOpen() then
		glowTween:Play()
	else
		glowTween:Cancel()
	end
end

-- Celebration ------------------------------------------------------------------------------------

local function buildCelebration()
	local overlay = UIController.Layer("Overlay")
	flash = Create("Frame", {
		Name = "RebirthFlash",
		BackgroundColor3 = hex("#FFE3F2"),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 50,
		Parent = overlay,
	})
	banner = Create("Frame", {
		Name = "RebirthBanner",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(900, 220),
		Visible = false,
		ZIndex = 51,
		Parent = overlay,
	})
	bannerScale = Instance.new("UIScale")
	bannerScale.Parent = banner
	bannerTitle = Create.Text({
		Name = "Title",
		Text = "REBIRTH!",
		Size = UDim2.new(1, 0, 0, 130),
		Font = Theme.Fonts.Display,
		TextSize = 120,
		Scaled = true,
		Color = hex("#FFD0E8"),
		Stroke = 6,
		ZIndex = 52,
		Parent = banner,
	})
	Create.Gradient(bannerTitle, Color3.new(1, 1, 1), PINK, 90)
	bannerSub = Create.Text({
		Name = "Sub",
		Text = "",
		Position = UDim2.fromOffset(0, 136),
		Size = UDim2.new(1, 0, 0, 70),
		Font = Theme.Fonts.Display,
		TextSize = 64,
		Scaled = true,
		Color = GOLD,
		Stroke = 4,
		ZIndex = 52,
		Parent = banner,
	})
end

local bannerToken = 0

local function celebrate(rebirths: number)
	AudioController.Play("Rebirth")
	-- screen flash
	flash.Visible = true
	flash.BackgroundTransparency = 0.1
	local fade = TweenService:Create(flash, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
	fade.Completed:Once(function()
		flash.Visible = false
	end)
	fade:Play()
	-- banner
	bannerToken += 1
	local token = bannerToken
	bannerSub.Text = string.format("%s SKILL FOREVER", multText(Economy.RebirthMultiplier(rebirths)))
	bannerTitle.TextTransparency = 0
	bannerSub.TextTransparency = 0
	local titleStroke = bannerTitle:FindFirstChildOfClass("UIStroke")
	local subStroke = bannerSub:FindFirstChildOfClass("UIStroke")
	if titleStroke then
		titleStroke.Transparency = 0
	end
	if subStroke then
		subStroke.Transparency = 0
	end
	banner.Visible = true
	bannerScale.Scale = 0.3
	TweenService:Create(bannerScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(1.6, function()
		if token ~= bannerToken then
			return
		end
		local out = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(bannerScale, out, { Scale = 1.3 }):Play()
		TweenService:Create(bannerTitle, out, { TextTransparency = 1 }):Play()
		TweenService:Create(bannerSub, out, { TextTransparency = 1 }):Play()
		if titleStroke then
			TweenService:Create(titleStroke, out, { Transparency = 1 }):Play()
		end
		if subStroke then
			TweenService:Create(subStroke, out, { Transparency = 1 }):Play()
		end
		task.delay(0.45, function()
			if token == bannerToken then
				banner.Visible = false
			end
		end)
	end)
	-- burst around the character
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if root then
		local pos = root.Position
		Effects.Flash(pos, 16, PINK, 0.45)
		Effects.Ring(pos - Vector3.new(0, 2.6, 0), Vector3.yAxis, 18, PINK, 0.7, 0.3)
		Effects.Ring(pos - Vector3.new(0, 2.4, 0), Vector3.yAxis, 12, GOLD, 0.55, 0.3)
		Effects.Sparks(pos, GOLD, 50, 34, 1.1)
		Effects.Sparks(pos, PINK, 40, 26, 0.9)
	end
end

local function doRebirth()
	local derived = StateController.Derived()
	if derived.CanRebirth ~= true then
		return
	end
	local result = Net.Invoke("RequestRebirth", false)
	if result.ok then
		local data = StateController.Data
		local rebirths = if type(result.rebirths) == "number"
			then result.rebirths
			elseif data and type(data.Rebirths) == "number" then data.Rebirths + 1
			else 1
		celebrate(rebirths)
	end
end

-- Layout -----------------------------------------------------------------------------------------

local function card(parent: Instance, name: string, position: UDim2, size: UDim2, accent: Color3, title: string): Frame
	local frame: Frame = Create("Frame", {
		Name = name,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = position,
		Size = size,
		Parent = parent,
	})
	Create.Corner(16, frame)
	Create.Gradient(frame, Theme.Colors.Card, Theme.Colors.CardDeep, 90)
	Create.Stroke(frame, accent, 3, 0, true)
	local header: Frame = Create("Frame", {
		Name = "Header",
		BackgroundColor3 = accent,
		Size = UDim2.new(1, 0, 0, 46),
		Parent = frame,
	})
	Create.Corner(16, header)
	Create.Gradient(header, accent, MenuShell.Shade(accent, 0.6), 90)
	-- square off the header's bottom corners
	Create("Frame", {
		Name = "Square",
		BackgroundColor3 = MenuShell.Shade(accent, 0.6),
		Position = UDim2.new(0, 0, 1, -14),
		Size = UDim2.new(1, 0, 0, 14),
		Parent = header,
	})
	Create.Text({
		Name = "Title",
		Text = title,
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -24, 1, -8),
		Font = Theme.Fonts.Display,
		TextSize = 30,
		Scaled = true,
		Stroke = 2.6,
		ZIndex = 2,
		Parent = header,
	})
	local list: Frame = Create("Frame", {
		Name = "List",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 54),
		Size = UDim2.new(1, -28, 1, -62),
		Parent = frame,
	})
	Create.List(list, Enum.FillDirection.Vertical, 4)
	return list
end

local function line(parent: Instance, text: string, order: number, color: Color3?): TextLabel
	return Create.Text({
		Name = "Line" .. order,
		Text = text,
		Size = UDim2.new(1, 0, 0, 26),
		Font = Theme.Fonts.Body,
		TextSize = 22,
		Scaled = true,
		Color = color or Theme.Colors.Text,
		Stroke = 1.4,
		XAlign = Enum.TextXAlignment.Left,
		LayoutOrder = order,
		Parent = parent,
	})
end

local function multBox(parent: Instance, name: string, x: UDim, caption: string, color: Color3): TextLabel
	local box: Frame = Create("Frame", {
		Name = name,
		BackgroundColor3 = Theme.Colors.PanelDeep,
		BackgroundTransparency = 0.15,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(x.Scale, x.Offset, 0, 14),
		Size = UDim2.fromOffset(300, 128),
		Parent = parent,
	})
	Create.Corner(18, box)
	Create.Stroke(box, color, 3, 0, true)
	Create.Text({
		Name = "Caption",
		Text = caption,
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 28),
		Font = Theme.Fonts.Display,
		TextSize = 26,
		Scaled = true,
		Color = Theme.Colors.TextDim,
		Stroke = 2,
		Parent = box,
	})
	return Create.Text({
		Name = "Value",
		Text = "x1",
		Position = UDim2.fromOffset(10, 34),
		Size = UDim2.new(1, -20, 0, 86),
		Font = Theme.Fonts.Display,
		TextSize = 84,
		Scaled = true,
		Color = color,
		Stroke = 4,
		Parent = box,
	})
end

function RebirthScreen.Init()
	shell = MenuShell.new({
		Name = "Rebirth",
		Title = "Rebirth",
		Icon = Theme.Icons.Rebirth,
		Size = PANEL,
		Accent = PINK,
		OnOpen = function()
			task.defer(refresh)
		end,
		OnClose = function()
			if glowTween then
				glowTween:Cancel()
			end
		end,
		FirstSelection = function()
			return if refs then refs.Rebirth.Instance else nil
		end,
	})
	local content = shell.Content

	-- hero: x<now> -> x<next>
	local hero: Frame = Create("Frame", {
		Name = "Hero",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 0, 192),
		Parent = content,
	})
	Create.Corner(18, hero)
	Create.Gradient(hero, hex("#7A2BD6"), hex("#3B1580"), 90)
	Create.Stroke(hero, PINK, 3, 0, true)
	local now = multBox(hero, "Now", UDim.new(0.5, -230), "NOW", Theme.Colors.Text)
	local nextLabel = multBox(hero, "Next", UDim.new(0.5, 230), "AFTER REBIRTH", GOLD)
	local arrow = Create.Text({
		Name = "Arrow",
		Text = "➜",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 78),
		Size = UDim2.fromOffset(120, 90),
		Font = Theme.Fonts.Display,
		TextSize = 90,
		Scaled = true,
		Color = GOLD,
		Stroke = 4,
		Parent = hero,
	})
	TweenService:Create(arrow, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Position = UDim2.new(0.5, 12, 0, 78),
	}):Play()
	local count = Create.Text({
		Name = "Count",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -40, 0, 34),
		Font = Theme.Fonts.Display,
		TextSize = 30,
		Scaled = true,
		Stroke = 2.4,
		Parent = hero,
	})
	-- caption under the boxes
	Create.Text({
		Name = "Hint",
		Text = "Skill multiplier",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 18, 1, -10),
		Size = UDim2.fromOffset(220, 28),
		Font = Theme.Fonts.Body,
		TextSize = 22,
		Scaled = true,
		Color = Theme.Colors.TextDim,
		Stroke = 1.2,
		XAlign = Enum.TextXAlignment.Left,
		Parent = hero,
	})

	-- level progress
	local progress: Frame = Create("Frame", {
		Name = "Progress",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 204),
		Size = UDim2.new(1, 0, 0, 120),
		Parent = content,
	})
	local levelText = Create.Text({
		Name = "Level",
		Text = "",
		Size = UDim2.new(0.6, 0, 0, 40),
		Font = Theme.Fonts.Display,
		TextSize = 38,
		Scaled = true,
		XAlign = Enum.TextXAlignment.Left,
		Stroke = 3,
		Parent = progress,
	})
	local percent = Create.Text({
		Name = "Percent",
		Text = "",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.3, 0, 0, 40),
		Font = Theme.Fonts.Display,
		TextSize = 38,
		Scaled = true,
		Color = PINK,
		XAlign = Enum.TextXAlignment.Right,
		Stroke = 3,
		Parent = progress,
	})
	local track: Frame = Create("Frame", {
		Name = "Track",
		BackgroundColor3 = Theme.Colors.LevelTrack,
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 0, 44),
		ClipsDescendants = true,
		Parent = progress,
	})
	Create.Corner(12, track)
	Create.Stroke(track, Theme.Colors.Stroke, 3, 0, true)
	local fill: Frame = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(0.02, 1),
		Parent = track,
	})
	Create.Corner(12, fill)
	Create.Gradient(fill, hex("#FF9ED2"), hex("#D7267A"), 90)
	local barText = Create.Text({
		Name = "BarText",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -20, 0.72, 0),
		Font = Theme.Fonts.Display,
		TextSize = 28,
		Scaled = true,
		Stroke = 2.4,
		ZIndex = 3,
		Parent = track,
	})
	local nextCap = Create.Text({
		Name = "NextCap",
		Text = "",
		Position = UDim2.fromOffset(0, 94),
		Size = UDim2.new(1, 0, 0, 26),
		Font = Theme.Fonts.Body,
		TextSize = 22,
		Scaled = true,
		Color = Theme.Colors.TextDim,
		XAlign = Enum.TextXAlignment.Left,
		Stroke = 1.2,
		Parent = progress,
	})

	-- resets / keeps / unlocks
	local colW = math.floor((PANEL.X - 36 - 2 * 14) / 3)
	local colTop = 334
	local colH = 200
	local resets = card(content, "Resets", UDim2.fromOffset(0, colTop), UDim2.fromOffset(colW, colH), Theme.Colors.Danger, "RESETS")
	line(resets, Theme.Icons.Skill .. " Skill", 1)
	line(resets, Theme.Icons.Star .. " Level", 2)
	line(resets, "Everything else stays!", 3, Theme.Colors.TextMuted)
	local keeps = card(content, "Keeps", UDim2.fromOffset(colW + 14, colTop), UDim2.fromOffset(colW, colH), Theme.Colors.Success, "KEEPS")
	line(keeps, Theme.Icons.Wins .. " Wins", 1)
	line(keeps, Theme.Icons.Glider .. " Gliders", 2)
	line(keeps, Theme.Icons.Pets .. " Pets", 3)
	line(keeps, Theme.Icons.Trails .. " Trails", 4)
	line(keeps, Theme.Icons.World .. " Worlds", 5)
	local unlockList = card(content, "Unlocks", UDim2.fromOffset((colW + 14) * 2, colTop), UDim2.fromOffset(colW, colH), GOLD, "NEXT REBIRTH UNLOCKS")
	local unlocks: { TextLabel } = {}
	for i = 1, MAX_UNLOCK_LINES do
		local label = line(unlockList, "", i)
		label.Visible = false
		unlocks[i] = label
	end

	-- rebirth button with a pulsing glow when ready
	local glow: Frame = Create("Frame", {
		Name = "Glow",
		BackgroundColor3 = GOLD,
		BackgroundTransparency = 0.6,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 6),
		Size = UDim2.fromOffset(480, 96),
		Visible = false,
		Parent = content,
	})
	Create.Corner(22, glow)
	glowTween = TweenService:Create(glow, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		BackgroundTransparency = 0.95,
	})
	local rebirthButton = Button.new({
		Parent = content,
		Name = "RebirthButton",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(440, 82),
		Style = "Pink",
		Text = Theme.Icons.Rebirth .. " REBIRTH",
		TextSize = 44,
		Corner = 16,
		OnClick = function()
			task.spawn(doRebirth)
		end,
	})

	refs = {
		Now = now,
		Next = nextLabel,
		Count = count,
		LevelText = levelText,
		Percent = percent,
		Fill = fill,
		BarText = barText,
		NextCap = nextCap,
		Unlocks = unlocks,
		Rebirth = rebirthButton,
		Glow = glow,
	}

	buildCelebration()
	UIController.Register("Rebirth", shell)
	StateController.DataChanged:Connect(function()
		if shell:IsOpen() then
			refresh()
		end
	end)
	refresh()
end

return RebirthScreen
