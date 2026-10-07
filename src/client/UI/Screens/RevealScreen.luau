--!strict
-- Gacha reveal (reference screenshot 2: square panel, sunburst rays, item art, green "Receive")
-- and the reward modal (screenshot 3: "You got a Ball Gacha for finishing your first battle",
-- art card, blue "Claim"). Reward modals queue while a match UI is active.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GachaDefinitions = require(Shared.Definitions.GachaDefinitions)
local Rarity = require(Shared.Config.Rarity)
local PropFactory = require(Shared.Visual.PropFactory)
local Remotes = require(Shared.Net.Remotes)

local Client = script.Parent.Parent.Parent
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local Button = require(Client.UI.Components.Button)
local ItemCard = require(Client.UI.Components.ItemCard)
local Viewport = require(Client.UI.Components.Viewport)
local Icons = require(Client.UI.Components.Icons)
local OrbArt = require(Client.UI.Components.OrbArt)
local UIController = require(Client.Controllers.UIController)
local AudioController = require(Client.Controllers.AudioController)

local RevealScreen = {}

local overlay: Frame
local stage: Frame
local raysFrame: Frame
local single: Frame
local singleTitle: TextLabel
local singleArt: Frame
local singleRarity: TextLabel
local singleNew: TextLabel
local multi: Frame
local multiGrid: Frame
local receive: Button.Button
local shaker: Frame
local isOpen = false
local spinConn: RBXScriptConnection?

-- reward modal
local modal: Frame
local modalTitle: TextLabel
local modalArt: Frame
local modalClaim: Button.Button
local modalQueue: { { [string]: any } } = {}
local modalBusy = false
local held = false

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function buildRays(parent: Frame)
	-- GuiObjects rotate around their own centre, so each bar spans the whole burst
	-- (two opposite rays per bar), fading out toward both ends.
	for k = 0, 6 do
		local ray: Frame = Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.1, 1.24),
			BackgroundColor3 = Color3.fromHex("#BDF3FF"),
			Rotation = k * (180 / 7),
			Parent = parent,
		})
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Rotation = 90
		g.Parent = ray
	end
	local glow: Frame = Create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62), BackgroundColor3 = Color3.fromHex("#59E1FF"), BackgroundTransparency = 0.55, Parent = parent })
	Create.Round(glow)
end

local function setRayColor(color: Color3)
	for _, child in raysFrame:GetChildren() do
		if child:IsA("Frame") then
			child.BackgroundColor3 = color
		end
	end
end

local function close()
	isOpen = false
	overlay.Visible = false
	if spinConn then
		spinConn:Disconnect()
		spinConn = nil
	end
	clear(singleArt)
	clear(multiGrid)
	clear(shaker)
	RevealScreen.Pump()
end

local function bestRarity(pulls: { { [string]: any } }): string
	local best = "Uncommon"
	for _, p in pulls do
		if Rarity.Get(p.Rarity).Order > Rarity.Get(best).Order then
			best = p.Rarity
		end
	end
	return best
end

local function open(args: { Crate: string?, Pulls: { { [string]: any } } })
	isOpen = true
	overlay.Visible = true
	single.Visible = false
	multi.Visible = false
	raysFrame.Visible = false
	receive.Instance.Visible = false
	clear(shaker)
	shaker.Visible = true
	local crate = if args.Crate then GachaDefinitions.Get(args.Crate) else nil
	local model = if crate and (crate.Art == "Machine" or crate.Art == "MachineAdvanced") then PropFactory.GachaMachine(crate.Art == "MachineAdvanced") elseif crate then PropFactory.Crate(if crate.Art == "CrateFlyer" then "Flyer" elseif crate.Art == "CrateExplosion" then "Explosion" else "Event") else PropFactory.GachaMachine(false)
	Viewport.Model(shaker, model, { Yaw = math.rad(-20), Zoom = 0.9 })

	-- anticipation shake
	AudioController.Play("GachaShake")
	local t0 = os.clock()
	if spinConn then
		spinConn:Disconnect()
	end
	spinConn = RunService.RenderStepped:Connect(function(dt: number)
		local t = os.clock() - t0
		if shaker.Visible then
			shaker.Rotation = math.sin(t * 38) * (6 + t * 10)
		end
		raysFrame.Rotation += dt * 25
	end)
	task.wait(0.9)
	if not isOpen then
		return
	end
	shaker.Visible = false
	raysFrame.Visible = true
	local best = bestRarity(args.Pulls)
	setRayColor(Theme.RarityLight(best))
	local order = Rarity.Get(best).Order
	if order >= 4 then
		AudioController.Play("LegendaryPull")
	elseif order >= 2 then
		AudioController.Play("RarePull")
	else
		AudioController.Play("GachaReveal")
	end

	if #args.Pulls == 1 then
		local pull = args.Pulls[1]
		local name, rarity = ItemCard.Info(pull.Kind, pull.Id)
		single.Visible = true
		singleTitle.Text = name
		singleRarity.Text = rarity
		singleRarity.TextColor3 = Theme.Rarity(rarity)
		singleNew.Visible = pull.New == true
		ItemCard.Art(singleArt, pull.Kind, pull.Id, 3, true)
		local scale = singleArt:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		scale.Parent = singleArt
		scale.Scale = 0.2
		TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	else
		multi.Visible = true
		for i, pull in args.Pulls do
			local card = ItemCard.new({ Parent = multiGrid, Kind = pull.Kind, Id = pull.Id, Size = UDim2.fromOffset(150, 150), LayoutOrder = i })
			card.Instance.Visible = false
			task.delay(0.08 * i, function()
				card.Instance.Visible = true
				local scale = card.Instance:FindFirstChildOfClass("UIScale") :: UIScale?
				if scale then
					scale.Scale = 0.3
					TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
				end
				AudioController.Play("Select", nil, nil, 0.6)
			end)
		end
	end
	task.wait(0.4)
	receive.Instance.Visible = isOpen
end

---------------------------------------------------------------------------------------------
-- Reward modal

local MODAL_TEXT = {
	FirstBattle = "You got an Orb Gacha for finishing your first battle",
	Group = "Thanks for joining the group! Here's an Advanced Orb Gacha",
	Weekly = "You placed #%d on last week's board!",
	LevelUp = "Level %d reached!",
}

local function showModal(info: { [string]: any })
	modalBusy = true
	modal.Visible = true
	clear(modalArt)
	local text = MODAL_TEXT[info.Kind] or "Reward!"
	if info.Kind == "Weekly" then
		text = string.format(text, info.Rank or 1)
	elseif info.Kind == "LevelUp" then
		text = string.format(text, info.Level or 1)
		AudioController.Play("LevelUp")
	else
		AudioController.Play("Reward")
	end
	modalTitle.Text = text
	local ticket = info.Ticket
	local reward = info.Reward
	if reward and reward.Kind == "Ball" then
		OrbArt.Draw(modalArt, reward.Id)
	elseif reward and (reward.Kind == "Coins" or reward.Kind == "Gems") then
		Icons.Currency(reward.Kind, UDim2.fromScale(0.8, 0.8), modalArt).Position = UDim2.fromScale(0.1, 0.1)
	else
		local id = ticket or (reward and reward.Id) or "OrbGacha"
		Viewport.Model(modalArt, PropFactory.GachaMachine(id == "AdvancedOrbGacha"), { Yaw = math.rad(-20), Zoom = 0.9, Spin = 0.5 })
	end
	local openTicket = ticket or (if reward and reward.Kind == "Ticket" then reward.Id else nil)
	modalClaim:SetText(if openTicket then "Claim" else "Nice!")
	local conn: RBXScriptConnection
	conn = modalClaim.Instance.Activated:Connect(function()
		conn:Disconnect()
		modal.Visible = false
		modalBusy = false
		if openTicket then
			local result = Remotes.Function("StoreRequest"):InvokeServer("OpenTicket", openTicket)
			if type(result) == "table" and result.ok then
				UIController.Open("Reveal", { Crate = openTicket, Pulls = result.pulls })
				return
			end
		end
		RevealScreen.Pump()
	end)
end

function RevealScreen.Pump()
	if modalBusy or held or isOpen or #modalQueue == 0 then
		return
	end
	showModal(table.remove(modalQueue, 1) :: { [string]: any })
end

function RevealScreen.Hold(hold: boolean)
	held = hold
	if not hold then
		RevealScreen.Pump()
	end
end

function RevealScreen.QueueReward(info: { [string]: any })
	table.insert(modalQueue, info)
	RevealScreen.Pump()
end

function RevealScreen.Init()
	local layer = UIController.Layer("Overlay")
	overlay = Create("Frame", { Name = "Reveal", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), Visible = false, Active = true, Parent = layer })
	stage = Create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(900, 620), Parent = overlay })
	raysFrame = Create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromOffset(620, 620), Parent = stage })
	buildRays(raysFrame)
	shaker = Create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(300, 300), Parent = stage })

	single = Create("Frame", { Name = "Single", BackgroundColor3 = Theme.Colors.Panel, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromOffset(300, 300), Visible = false, Parent = stage })
	Create.Stroke(single, Color3.fromHex("#2A3A66"), 2, 0, true)
	singleTitle = Create.Text({ Text = "", Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 10), Font = Theme.Fonts.Body, TextSize = 36, Scaled = true, Stroke = 2.5, ZIndex = 4, Parent = single })
	singleArt = Create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.fromOffset(200, 200), ZIndex = 3, Parent = single })
	singleRarity = Create.Text({ Text = "", Size = UDim2.new(1, -20, 0, 32), Position = UDim2.new(0, 10, 1, -38), Font = Theme.Fonts.Display, TextSize = 26, Scaled = true, Stroke = 2, ZIndex = 4, Parent = single })
	singleNew = Create.Text({ Text = "NEW!", Size = UDim2.fromOffset(90, 34), Position = UDim2.new(1, -10, 0, 50), AnchorPoint = Vector2.new(1, 0), Font = Theme.Fonts.Display, TextSize = 26, Scaled = true, Color = Color3.fromHex("#FFE14D"), Stroke = 2.5, Rotation = 12, ZIndex = 6, Parent = single })

	multi = Create("Frame", { Name = "Multi", BackgroundColor3 = Theme.Colors.Panel, BackgroundTransparency = 0.05, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromOffset(880, 400), Visible = false, Parent = stage })
	Create.Stroke(multi, Theme.Colors.PanelBorder, 2, 0, true)
	multiGrid = Create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 30), Size = UDim2.new(1, -40, 1, -50), Parent = multi })
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(150, 150)
	grid.CellPadding = UDim2.fromOffset(16, 26)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = multiGrid

	receive = Button.new({ Parent = stage, Size = UDim2.fromOffset(240, 64), Position = UDim2.new(0.5, 0, 1, -10), AnchorPoint = Vector2.new(0.5, 1), Style = "Green", Text = "Receive", TextSize = 40, OnClick = function()
		AudioController.Play("Purchase")
		close()
	end })

	-- reward modal (first battle / group / weekly / level up)
	modal = Create("Frame", { Name = "RewardModal", BackgroundColor3 = Color3.fromHex("#121729"), BackgroundTransparency = 0.06, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(808, 454), Visible = false, Active = true, Parent = layer })
	Create.Stroke(modal, Theme.Colors.ModalBorder, 2, 0, true)
	modalTitle = Create.Text({ Text = "", Size = UDim2.new(1, -40, 0, 40), Position = UDim2.fromOffset(20, 34), Font = Theme.Fonts.Body, TextSize = 34, Scaled = true, Stroke = 1.5, Parent = modal })
	local card: Frame = Create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 100), Size = UDim2.fromOffset(180, 232), BackgroundColor3 = Color3.new(1, 1, 1), Parent = modal })
	Create.Gradient(card, Color3.fromHex("#FF4BE0"), Color3.fromHex("#7A1FA8"), 90)
	Create.Stroke(card, Color3.fromHex("#FF7BEA"), 2, 0, true)
	modalArt = Create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(160, 200), Parent = card })
	modalClaim = Button.new({ Parent = modal, Size = UDim2.fromOffset(272, 68), Position = UDim2.new(0.5, 0, 1, -24), AnchorPoint = Vector2.new(0.5, 1), Style = "Blue", Text = "Claim", TextSize = 40 })

	UIController.Register("Reveal", {
		Open = function(_, args)
			task.spawn(open, args)
		end,
		Close = function()
			close()
		end,
		IsOpen = function()
			return isOpen
		end,
	})

	Remotes.Event("RewardPopup").OnClientEvent:Connect(function(info)
		RevealScreen.QueueReward(info)
	end)
end

return RevealScreen
