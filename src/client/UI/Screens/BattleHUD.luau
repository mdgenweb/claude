--!strict
-- In-match HUD reconstructed from the reference battle screenshot (4): mirrored player blocks
-- (avatar with team ring, team-coloured name, hearts, orb name, orb icon), plus banners,
-- 3-2-1 countdown, phase timer, aim prompt with Lock Aim, and the overtime indicator.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local BallDefinitions = require(Shared.Definitions.BallDefinitions)

local Client = script.Parent.Parent.Parent
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local Button = require(Client.UI.Components.Button)
local Icons = require(Client.UI.Components.Icons)
local OrbArt = require(Client.UI.Components.OrbArt)
local UIController = require(Client.Controllers.UIController)
local AudioController = require(Client.Controllers.AudioController)

local BattleHUD = {}

type Block = {
	Root: Frame,
	Hearts: { Frame },
	BallName: TextLabel,
	BallIcon: Frame,
	BallId: string?,
	Lock: TextLabel,
	Team: number,
}

local root: Frame
local sides: { Frame } = {}
local blocks: { [number]: Block } = {} -- by userId
local banner: TextLabel
local countdownLabel: TextLabel
local phasePill: Frame
local phaseLabel: TextLabel
local overtimeLabel: TextLabel
local aimBar: Frame
local aimHint: TextLabel
local lockButton: Button.Button
local aimFill: Frame
local phaseConn: RBXScriptConnection?
local aimConn: RBXScriptConnection?
local onLock: (() -> ())?
local thumbCache: { [number]: string } = {}

local function teamColor(team: number): Color3
	return if team == 1 then Theme.Colors.TeamRed else Theme.Colors.TeamBlue
end

local function thumbnail(userId: number, image: ImageLabel)
	if userId <= 0 then
		return
	end
	if thumbCache[userId] then
		image.Image = thumbCache[userId]
		return
	end
	task.spawn(function()
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok and content then
			thumbCache[userId] = content
			image.Image = content
		end
	end)
end

local function buildBlock(parent: Frame, p: { [string]: any }, mirrored: boolean, order: number): Block
	local frame: Frame = Create("Frame", {
		Name = "Player_" .. p.UserId,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(320, 340),
		LayoutOrder = order,
		Parent = parent,
	})
	local ax = if mirrored then 1 else 0
	local function x(offset: number): UDim
		return if mirrored then UDim.new(1, -offset) else UDim.new(0, offset)
	end
	local color = teamColor(p.Team)
	-- avatar
	local avatar: Frame = Create("Frame", { BackgroundColor3 = Color3.fromHex("#C9CCD3"), AnchorPoint = Vector2.new(ax, 0), Position = UDim2.new(x(30), UDim.new(0, 0)), Size = UDim2.fromOffset(105, 105), Parent = frame })
	Create.Round(avatar)
	Create.Stroke(avatar, color, 3.5, 0, true)
	local image: ImageLabel = Create("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = avatar })
	Create.Round(image)
	if p.IsBot then
		OrbArt.Draw(avatar, "bumper", 3)
	else
		thumbnail(p.UserId, image)
	end
	-- name
	Create.Text({
		Text = p.Name,
		Size = UDim2.fromOffset(190, 34),
		AnchorPoint = Vector2.new(ax, 0),
		Position = UDim2.new(x(140), UDim.new(0, 8)),
		Font = Theme.Fonts.Display,
		TextSize = 30,
		Scaled = true,
		XAlign = if mirrored then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left,
		Color = color,
		Stroke = 2,
		Parent = frame,
	})
	-- hearts
	local hearts = {}
	for i = 1, 3 do
		local heart = Icons.Heart(UDim2.fromOffset(46, 46), frame)
		heart.AnchorPoint = Vector2.new(ax, 0)
		heart.Position = UDim2.new(x(140 + (i - 1) * 56), UDim.new(0, 50))
		table.insert(hearts, heart)
	end
	local lock = Create.Text({ Text = "LOCKED", Size = UDim2.fromOffset(120, 24), AnchorPoint = Vector2.new(ax, 0), Position = UDim2.new(x(146), UDim.new(0, 100)), Font = Theme.Fonts.Display, TextSize = 18, Scaled = true, XAlign = if mirrored then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left, Color = Color3.fromHex("#7CFF6B"), Stroke = 1.5, Visible = false, Parent = frame })
	-- orb name + icon
	local ballName = Create.Text({ Text = "", Size = UDim2.fromOffset(230, 30), AnchorPoint = Vector2.new(if mirrored then 1 else 0, 0), Position = UDim2.new(if mirrored then UDim.new(1, 0) else UDim.new(0, 0), UDim.new(0, 114)), Font = Theme.Fonts.Body, TextSize = 28, Scaled = true, XAlign = if mirrored then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left, Stroke = 2, Parent = frame })
	local icon: Frame = Create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(ax, 0), Position = UDim2.new(x(14), UDim.new(0, 150)), Size = UDim2.fromOffset(140, 140), Parent = frame })
	return { Root = frame, Hearts = hearts, BallName = ballName, BallIcon = icon, BallId = nil, Lock = lock, Team = p.Team }
end

function BattleHUD.Show(summary: { [string]: any })
	for _, side in sides do
		for _, child in side:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end
	table.clear(blocks)
	local counts = { 0, 0 }
	for _, p in summary.Participants do
		counts[p.Team] += 1
		local block = buildBlock(sides[p.Team], p, p.Team == 2, counts[p.Team])
		if summary.Mode == "2v2" then
			local s = Instance.new("UIScale")
			s.Scale = 0.68
			s.Parent = block.Root
			block.Root.Size = UDim2.fromOffset(320 * 0.68, 340 * 0.68)
		end
		blocks[p.UserId] = block
	end
	root.Visible = true
	BattleHUD.Update(summary)
end

function BattleHUD.Update(summary: { [string]: any })
	for _, p in summary.Participants do
		local block = blocks[p.UserId]
		if block then
			local hearts = summary.Hearts[p.Team]
			for i, heart in block.Hearts do
				Icons.SetHeart(heart, i <= hearts)
			end
			if p.Ball and p.Ball ~= block.BallId then
				block.BallId = p.Ball
				for _, child in block.BallIcon:GetChildren() do
					child:Destroy()
				end
				OrbArt.Draw(block.BallIcon, p.Ball)
				local def = BallDefinitions.Get(p.Ball)
				block.BallName.Text = if def then def.DisplayName else p.Ball
			elseif p.Ball == nil and summary.State == "BallSelection" then
				block.BallName.Text = if p.Picked then "Ready!" else "Choosing..."
				block.BallId = nil
				for _, child in block.BallIcon:GetChildren() do
					child:Destroy()
				end
			end
			block.Lock.Visible = summary.State == "AimPhase" and p.Locked
		end
	end
end

-- Animates a team's newest lost heart breaking.
function BattleHUD.BreakHeart(team: number, remaining: number)
	AudioController.Play("HeartBreak")
	for _, block in blocks do
		if block.Team == team then
			local heart = block.Hearts[remaining + 1]
			if heart then
				local s = heart:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
				s.Parent = heart
				s.Scale = 1.6
				TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
				Icons.SetHeart(heart, false)
			end
		end
	end
end

function BattleHUD.Banner(text: string, color: Color3?, duration: number?)
	banner.Text = text
	banner.TextColor3 = color or Color3.new(1, 1, 1)
	banner.Visible = true
	local s = banner:FindFirstChildOfClass("UIScale") :: UIScale
	s.Scale = 2.2
	banner.TextTransparency = 0
	TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local token = os.clock()
	banner:SetAttribute("Token", token)
	task.delay(duration or 1.6, function()
		if banner:GetAttribute("Token") == token then
			local t = TweenService:Create(banner, TweenInfo.new(0.25), { TextTransparency = 1 })
			t:Play()
			t.Completed:Wait()
			if banner:GetAttribute("Token") == token then
				banner.Visible = false
			end
		end
	end)
end

function BattleHUD.Countdown(deadline: number)
	task.spawn(function()
		local last = -1
		while true do
			local left = deadline - Workspace:GetServerTimeNow()
			local n = math.ceil(left)
			if n <= 0 then
				break
			end
			if n ~= last then
				last = n
				countdownLabel.Text = tostring(n)
				countdownLabel.Visible = true
				local s = countdownLabel:FindFirstChildOfClass("UIScale") :: UIScale
				s.Scale = 1.8
				TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
				AudioController.Play("Countdown")
			end
			RunService.Heartbeat:Wait()
		end
		countdownLabel.Text = "GO!"
		countdownLabel.TextColor3 = Color3.fromHex("#7CFF6B")
		AudioController.Play("CountdownGo")
		task.wait(0.6)
		countdownLabel.Visible = false
		countdownLabel.TextColor3 = Color3.new(1, 1, 1)
	end)
end

function BattleHUD.PhaseTimer(text: string?, deadline: number?)
	if phaseConn then
		phaseConn:Disconnect()
		phaseConn = nil
	end
	if text == nil or deadline == nil then
		phasePill.Visible = false
		return
	end
	phasePill.Visible = true
	phaseConn = RunService.Heartbeat:Connect(function()
		local left = math.max(0, (deadline :: number) - Workspace:GetServerTimeNow())
		phaseLabel.Text = string.format("%s  %d", text :: string, math.ceil(left))
	end)
end

function BattleHUD.ShowAim(deadline: number, total: number, lockCallback: () -> ())
	onLock = lockCallback
	aimBar.Visible = true
	lockButton:SetEnabled(true)
	lockButton:SetText("Lock Aim")
	aimHint.Text = "Drag to aim  ·  Space to lock"
	if aimConn then
		aimConn:Disconnect()
	end
	aimConn = RunService.Heartbeat:Connect(function()
		local left = math.max(0, deadline - Workspace:GetServerTimeNow())
		aimFill.Size = UDim2.fromScale(math.clamp(left / total, 0, 1), 1)
	end)
end

function BattleHUD.AimLocked()
	lockButton:SetEnabled(false)
	lockButton:SetText("Locked!")
	aimHint.Text = "Waiting for the others..."
end

function BattleHUD.HideAim()
	aimBar.Visible = false
	onLock = nil
	if aimConn then
		aimConn:Disconnect()
		aimConn = nil
	end
end

function BattleHUD.Overtime(level: number?)
	if level == nil then
		overtimeLabel.Visible = false
		return
	end
	overtimeLabel.Visible = true
	overtimeLabel.Text = string.format("OVERTIME  x%.2f", 1 + level * 0.25)
end

function BattleHUD.Hide()
	root.Visible = false
	BattleHUD.HideAim()
	BattleHUD.PhaseTimer(nil, nil)
	BattleHUD.Overtime(nil)
	countdownLabel.Visible = false
	banner.Visible = false
end

function BattleHUD.Init()
	root = Create("Frame", { Name = "BattleHUD", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = UIController.Layer("Battle") })
	for team = 1, 2 do
		local side: Frame = Create("Frame", {
			Name = "Team" .. team,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(if team == 1 then 0 else 1, 0),
			Position = UDim2.new(if team == 1 then 0 else 1, 0, 0, 56),
			Size = UDim2.fromOffset(330, 700),
			Parent = root,
		})
		Create.List(side, Enum.FillDirection.Vertical, 6, if team == 1 then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Right)
		sides[team] = side
	end
	banner = Create.Text({ Text = "", Size = UDim2.fromOffset(1100, 110), Position = UDim2.fromScale(0.5, 0.28), AnchorPoint = Vector2.new(0.5, 0.5), Font = Theme.Fonts.Display, TextSize = 90, Scaled = true, Stroke = 5, Visible = false, ZIndex = 20, Parent = root })
	Instance.new("UIScale").Parent = banner
	countdownLabel = Create.Text({ Text = "3", Size = UDim2.fromOffset(400, 200), Position = UDim2.fromScale(0.5, 0.45), AnchorPoint = Vector2.new(0.5, 0.5), Font = Theme.Fonts.Display, TextSize = 170, Scaled = true, Stroke = 6, Visible = false, ZIndex = 21, Parent = root })
	Instance.new("UIScale").Parent = countdownLabel
	phasePill = Create("Frame", { BackgroundColor3 = Theme.Colors.PanelDeep, BackgroundTransparency = 0.15, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(300, 56), Visible = false, Parent = root })
	Create.Corner(28, phasePill)
	Create.Stroke(phasePill, Theme.Colors.PanelBorder, 2, 0, true)
	phaseLabel = Create.Text({ Text = "", Size = UDim2.fromScale(0.86, 0.7), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Font = Theme.Fonts.Display, TextSize = 28, Scaled = true, Stroke = 2, Parent = phasePill })
	overtimeLabel = Create.Text({ Text = "", Size = UDim2.fromOffset(360, 36), Position = UDim2.new(0.5, 0, 0, 72), AnchorPoint = Vector2.new(0.5, 0), Font = Theme.Fonts.Display, TextSize = 26, Scaled = true, Color = Color3.fromHex("#FF5A6A"), Stroke = 2.5, Visible = false, Parent = root })

	aimBar = Create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -28), Size = UDim2.fromOffset(420, 150), Visible = false, Parent = root })
	aimHint = Create.Text({ Text = "", Size = UDim2.new(1, 0, 0, 34), Font = Theme.Fonts.Display, TextSize = 24, Scaled = true, Stroke = 2.5, Parent = aimBar })
	local track: Frame = Create("Frame", { BackgroundColor3 = Theme.Colors.LevelTrack, Position = UDim2.fromOffset(66, 44), Size = UDim2.fromOffset(288, 10), Parent = aimBar })
	Create.Corner(5, track)
	aimFill = Create("Frame", { BackgroundColor3 = Color3.fromHex("#7BE52A"), Size = UDim2.fromScale(1, 1), Parent = track })
	Create.Corner(5, aimFill)
	lockButton = Button.new({ Parent = aimBar, Size = UDim2.fromOffset(288, 70), Position = UDim2.new(0.5, 0, 1, 0), AnchorPoint = Vector2.new(0.5, 1), Style = "Green", Text = "Lock Aim", TextSize = 40, OnClick = function()
		if onLock then
			onLock()
		end
	end })
end

return BattleHUD
