--!strict
-- Egg menu ("Egg") + hatch reveal. UIController.Open("Egg", eggId) shows the egg, its price and
-- the live odds (Eggs.Odds with the player's Luck), with Hatch 1 / Hatch 3 (Triple Hatch pass) or a
-- Robux button for premium eggs. Hatching is decided on the server; the HatchResult event drives a
-- reveal in the Overlay layer: egg wobble -> crack flash -> pet with a rarity glow. Results that
-- arrive while a reveal is playing are queued. Gifts (payload.Egg == "") skip the egg stage.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Eggs = require(Shared.Definitions.Eggs)
local Pets = require(Shared.Definitions.Pets)
local Monetization = require(Shared.Config.Monetization)
local Rarity = require(Shared.Config.Rarity)
local Remotes = require(Shared.Net.Remotes)
local Format = require(Shared.Util.Format)
local PetFactory = require(Shared.Visual.PetFactory)
local EggFactory = require(Shared.Visual.EggFactory)

local Client = script.Parent.Parent.Parent
local StateController = require(Client.Controllers.StateController)
local UIController = require(Client.Controllers.UIController)
local AudioController = require(Client.Controllers.AudioController)
local Bus = require(Client.Controllers.Bus)
local Net = require(Client.Controllers.Net)
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local Components = Client.UI.Components
local Button = require(Components.Button)
local MenuShell = require(Components.MenuShell)
local Viewport = require(Components.Viewport)

local EggScreen = {}

local IS_STUDIO = RunService:IsStudio()
local PANEL = Vector2.new(1120, 700)
local LEFT_W = 380

local shell: MenuShell.Shell
local currentEgg: Eggs.Egg? = nil
local eggPreview: Frame
local eggName: TextLabel
local eggPrice: TextLabel
local hatchOne: Button.Button
local hatchThree: Button.Button
local luckLabel: TextLabel
local oddsHolder: Frame
local oddsLists: { [string]: { Frame: ScrollingFrame, Chances: { [string]: TextLabel } } } = {}
local previewEggId: string? = nil

local function shortChance(p: number): string
	local pct = p * 100
	if pct >= 10 then
		return string.format("%.1f%%", pct)
	elseif pct >= 0.1 then
		return string.format("%.2f%%", pct)
	end
	return string.format("%.3f%%", pct)
end

local function luck(): number
	local derived = StateController.Derived()
	return if type(derived.Luck) == "number" then derived.Luck else 1
end

local function oddsFor(egg: Eggs.Egg)
	local cached = oddsLists[egg.Id]
	if cached then
		return cached
	end
	local list: ScrollingFrame = Create("ScrollingFrame", {
		Name = "Odds_" .. egg.Id,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Theme.Colors.PanelEdge,
		Visible = false,
		Selectable = false,
		Parent = oddsHolder,
	})
	Create.List(list, Enum.FillDirection.Vertical, 8)
	Create.Padding(list, 6, 6)
	local chances: { [string]: TextLabel } = {}
	for i, entry in egg.Pets do
		local pet = Pets.Get(entry.Pet)
		if not pet then
			continue
		end
		local row: Frame = Create("Frame", {
			Name = entry.Pet,
			BackgroundColor3 = Theme.Colors.Card,
			Size = UDim2.new(1, -16, 0, 96),
			LayoutOrder = i,
			Parent = list,
		})
		Create.Corner(12, row)
		Create.Stroke(row, Theme.Rarity(pet.Rarity), 3, 0, true)
		local preview: Frame = Create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(90, 90),
			Position = UDim2.fromOffset(4, 3),
			Parent = row,
		})
		local petId = entry.Pet
		task.defer(function()
			Viewport.Model(preview, PetFactory.ForId(petId, 2), { Spin = 0.5, Yaw = math.pi, Pitch = math.rad(-8) })
		end)
		Create.Text({
			Text = pet.Name,
			Size = UDim2.new(1, -260, 0, 34),
			Position = UDim2.fromOffset(102, 10),
			Font = Theme.Fonts.Display,
			TextSize = 30,
			Scaled = true,
			XAlign = Enum.TextXAlignment.Left,
			Stroke = 2,
			Parent = row,
		})
		Create.Text({
			Text = string.format("%s  ·  x%s Skill", string.upper(pet.Rarity), Format.Short(1 + pet.SkillBoost)),
			Size = UDim2.new(1, -260, 0, 28),
			Position = UDim2.fromOffset(102, 52),
			Font = Theme.Fonts.Body,
			TextSize = 24,
			Scaled = true,
			Color = Theme.Rarity(pet.Rarity),
			XAlign = Enum.TextXAlignment.Left,
			Stroke = 1.6,
			Parent = row,
		})
		chances[entry.Pet] = Create.Text({
			Text = "",
			Size = UDim2.fromOffset(140, 44),
			Position = UDim2.new(1, -16, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Font = Theme.Fonts.Numbers,
			TextSize = 36,
			Scaled = true,
			Color = Theme.Colors.Skill,
			XAlign = Enum.TextXAlignment.Right,
			Stroke = 2.4,
			Parent = row,
		})
	end
	local entry = { Frame = list, Chances = chances }
	oddsLists[egg.Id] = entry
	return entry
end

local function priceAction(egg: Eggs.Egg): (string, string, boolean)
	local product = if egg.ProductKey then Monetization.Product(egg.ProductKey) else nil
	if product then
		if product.Id == 0 and not IS_STUDIO then
			return "SOON", "Disabled", false
		end
		return string.format("BUY %s %d", Theme.Icons.Robux, product.Robux), "Green", true
	end
	return "HATCH 1", "Green", true
end

-- Left column stacked from the bottom so it fits any panel height: hatch buttons, luck, price,
-- name, and the egg preview takes what is left. Short panels put the buttons side by side.
local function layoutLeft(compact: boolean)
	local buttons = if compact then 82 else 164
	if compact then
		hatchOne.Instance.Size = UDim2.new(0.5, -18, 0, 70)
		hatchOne.Instance.Position = UDim2.new(0, 12, 1, -12)
		hatchThree.Instance.Size = UDim2.new(0.5, -18, 0, 70)
		hatchThree.Instance.Position = UDim2.new(0.5, 6, 1, -12)
	else
		hatchOne.Instance.Size = UDim2.new(1, -24, 0, 70)
		hatchOne.Instance.Position = UDim2.new(0, 12, 1, -94)
		hatchThree.Instance.Size = UDim2.new(1, -24, 0, 70)
		hatchThree.Instance.Position = UDim2.new(0, 12, 1, -12)
	end
	luckLabel.AnchorPoint = Vector2.new(0, 1)
	luckLabel.Position = UDim2.new(0, 12, 1, -(buttons + 6))
	eggPrice.AnchorPoint = Vector2.new(0, 1)
	eggPrice.Position = UDim2.new(0, 12, 1, -(buttons + 6 + 28 + 4))
	eggName.AnchorPoint = Vector2.new(0, 1)
	eggName.Position = UDim2.new(0, 12, 1, -(buttons + 6 + 28 + 4 + 36 + 4))
	eggPreview.Size = UDim2.new(1, -60, 1, -(buttons + 6 + 28 + 4 + 36 + 4 + 42 + 16))
end

local function refresh()
	local egg = currentEgg
	local data = StateController.Data
	if egg == nil or data == nil then
		return
	end
	local l = luck()
	local odds = oddsFor(egg)
	for _, other in oddsLists do
		other.Frame.Visible = other == odds
	end
	for _, entry in Eggs.Odds(egg, l) do
		local label = odds.Chances[entry.Pet]
		if label then
			label.Text = shortChance(entry.Chance)
		end
	end
	luckLabel.Text = if l > 1 then string.format("%s LUCK x%s ACTIVE", Theme.Icons.Luck, Format.Short(l)) else ""
	eggName.Text = egg.Name
	if egg.ProductKey then
		local product = Monetization.Product(egg.ProductKey)
		eggPrice.Text = if product then string.format("%s %d per egg", Theme.Icons.Robux, product.Robux) else ""
		local text, style, enabled = priceAction(egg)
		hatchOne:SetText(text)
		hatchOne:SetStyle(style)
		hatchOne:SetEnabled(enabled)
		hatchThree.Instance.Visible = false
	else
		local wins = if type(data.Wins) == "number" then data.Wins else 0
		eggPrice.Text = string.format("%s %s Wins", Theme.Icons.Wins, Format.Short(egg.Price))
		eggPrice.TextColor3 = if wins >= egg.Price then Theme.Colors.Text else Theme.Colors.Danger
		hatchOne:SetText("HATCH 1")
		hatchOne:SetStyle("Green")
		hatchOne:SetEnabled(true)
		hatchThree.Instance.Visible = true
		if StateController.HasPass("TripleHatch") then
			hatchThree:SetText("HATCH 3")
			hatchThree:SetStyle("Purple")
		else
			hatchThree:SetText(Theme.Icons.Lock .. " HATCH 3")
			hatchThree:SetStyle("Grey")
		end
		hatchThree:SetEnabled(true)
	end
	if previewEggId ~= egg.Id then
		eggPreview:ClearAllChildren()
		previewEggId = egg.Id
		Viewport.Model(eggPreview, EggFactory.ForId(egg.Id, 6), { Spin = 0.7, Yaw = math.pi, Pitch = math.rad(-6) })
	end
end

local function hatch(count: number)
	local egg = currentEgg
	if egg == nil then
		return
	end
	if egg.ProductKey then
		task.spawn(Net.Invoke, "RequestPurchase", false, "Product", egg.ProductKey)
		return
	end
	if count == 3 and not StateController.HasPass("TripleHatch") then
		task.spawn(Net.Invoke, "RequestPurchase", false, "Pass", "TripleHatch")
		return
	end
	task.spawn(Net.Invoke, "RequestHatchEgg", false, egg.Id, count)
end

-- Hatch reveal ------------------------------------------------------------------------------------

type HatchPayload = { Egg: string, Pets: { { Uid: string, Id: string } }, Source: string? }

local overlay: TextButton
local stage: Frame
local subtitle: TextLabel
local hint: TextLabel
local stageScale: UIScale

-- The stage (up to 540 design px tall) sits between the title (ends ~140) and the hint (starts
-- ~110 from the bottom); short screens (phones) scale it down to fit that space.
local function fitStage()
	local designHeight = overlay.AbsoluteSize.Y / math.max(UIController.Scale, 0.01)
	if designHeight <= 0 then
		return
	end
	local space = designHeight - 250
	stageScale.Scale = math.clamp(space / 540, 0.4, 1)
	stage.Position = UDim2.new(0.5, 0, 0, 140 + space / 2)
end
local queue: { HatchPayload } = {}
local playing = false
local dismissable = false
local dismissSignal: BindableEvent

local function clearStage()
	for _, child in stage:GetChildren() do
		if child:IsA("GuiObject") then -- keeps the list layout and the fit scale
			child:Destroy()
		end
	end
end

local function revealCard(payload: HatchPayload, pet: Pets.Pet, petId: string, width: number)
	local card: Frame = Create("Frame", {
		Name = "Reveal",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(width, 520),
		Parent = stage,
	})
	local glow: Frame = Create("Frame", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(width * 0.95, width * 0.95),
		BackgroundColor3 = Theme.Rarity(pet.Rarity),
		BackgroundTransparency = 1,
		Parent = card,
	})
	Create.Round(glow)
	local rays: Frame = Create("Frame", {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(width * 1.05, width * 1.05),
		BackgroundTransparency = 1,
		Parent = card,
	})
	for i = 0, 5 do
		local ray: Frame = Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 0, 0, 26),
			Rotation = i * 30,
			BackgroundColor3 = Theme.RarityLight(pet.Rarity),
			BackgroundTransparency = 1,
			Parent = rays,
		})
		Create.Corner(13, ray)
	end
	local view: Frame = Create("Frame", {
		Name = "View",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(width * 0.85, width * 0.85),
		BackgroundTransparency = 1,
		Parent = card,
	})
	local name = Create.Text({
		Text = pet.Name,
		Size = UDim2.new(1, 0, 0, 52),
		Position = UDim2.new(0, 0, 1, -118),
		Font = Theme.Fonts.Display,
		TextSize = 46,
		Scaled = true,
		Stroke = 3.5,
		Parent = card,
	})
	local info = Create.Text({
		Text = string.format("%s  ·  x%s Skill", string.upper(pet.Rarity), Format.Short(1 + pet.SkillBoost)),
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0, 0, 1, -62),
		Font = Theme.Fonts.Display,
		TextSize = 34,
		Scaled = true,
		Color = Theme.Rarity(pet.Rarity),
		Stroke = 3,
		Parent = card,
	})
	name.TextTransparency = 1
	info.TextTransparency = 1
	return {
		Card = card,
		View = view,
		Glow = glow,
		Rays = rays,
		Name = name,
		Info = info,
		PetId = petId,
		Pet = pet,
		EggId = payload.Egg,
	}
end

local function play(payload: HatchPayload)
	playing = true
	dismissable = false
	clearStage()
	overlay.Visible = true
	fitStage()
	overlay.BackgroundTransparency = 1
	TweenService:Create(overlay, TweenInfo.new(0.25), { BackgroundTransparency = 0.35 }):Play()
	local egg = Eggs.Get(payload.Egg)
	subtitle.Text = if egg then egg.Name else (payload.Source or "Reward")
	hint.Text = ""

	local count = math.max(1, #payload.Pets)
	local width = if count >= 3 then 340 else 420
	local cards = {}
	local bestOrder = 0
	for _, result in payload.Pets do
		local pet = Pets.Get(result.Id)
		if pet then
			table.insert(cards, revealCard(payload, pet, result.Id, width))
			bestOrder = math.max(bestOrder, Rarity.Order(pet.Rarity))
		end
	end

	-- egg wobble (skipped for gifts / starter packs)
	if egg then
		for _, c in cards do
			Viewport.Model(c.View, EggFactory.ForId(egg.Id, 6), { Yaw = math.pi, Pitch = math.rad(-6) })
		end
		for i = 1, 3 do
			AudioController.Play("EggShake")
			for _, c in cards do
				local angle = if i % 2 == 0 then -14 - i * 3 else 14 + i * 3
				TweenService:Create(c.View, TweenInfo.new(0.14, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 1, true), { Rotation = angle }):Play()
			end
			task.wait(0.34)
		end
		AudioController.Play("EggCrack")
	end

	-- crack flash -> pets
	local flash: Frame = Create("Frame", {
		Name = "Flash",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Parent = overlay,
	})
	TweenService:Create(flash, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
	task.delay(0.5, function()
		flash:Destroy()
	end)
	for _, c in cards do
		c.View:ClearAllChildren()
		c.View.Rotation = 0
		Viewport.Model(c.View, PetFactory.ForId(c.PetId, 3), { Spin = 0.9, Yaw = math.pi, Pitch = math.rad(-8) })
		local scale = Instance.new("UIScale")
		scale.Scale = 0.3
		scale.Parent = c.View
		TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		TweenService:Create(c.Glow, TweenInfo.new(0.4), { BackgroundTransparency = 0.55 }):Play()
		for _, ray in c.Rays:GetChildren() do
			if ray:IsA("Frame") then
				TweenService:Create(ray, TweenInfo.new(0.4), { BackgroundTransparency = if Rarity.Order(c.Pet.Rarity) >= 4 then 0.45 else 0.75 }):Play()
			end
		end
		TweenService:Create(c.Rays, TweenInfo.new(8, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 }):Play()
		TweenService:Create(c.Name, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
		TweenService:Create(c.Info, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
	end
	if bestOrder >= Rarity.Order("Legendary") then
		AudioController.Play("RareHatch")
	else
		AudioController.Play("Reward")
	end
	task.wait(0.6)
	hint.Text = if UserInputService.GamepadEnabled then "Press A to continue" else "Tap to continue"
	dismissable = true
	dismissSignal.Event:Wait()
	TweenService:Create(overlay, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
	task.wait(0.2)
	clearStage()
	overlay.Visible = false
	playing = false
	local nextPayload = table.remove(queue, 1)
	if nextPayload then
		play(nextPayload)
	end
end

local function enqueue(payload: HatchPayload)
	if playing then
		table.insert(queue, payload)
	else
		task.spawn(play, payload)
	end
end

local function buildOverlay()
	overlay = Create("TextButton", {
		Name = "HatchReveal",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = UIController.Layer("Overlay"),
	})
	dismissSignal = Instance.new("BindableEvent")
	overlay.Activated:Connect(function()
		if dismissable then
			dismissable = false
			dismissSignal:Fire()
		end
	end)
	UserInputService.InputBegan:Connect(function(input)
		if overlay.Visible and dismissable and (input.KeyCode == Enum.KeyCode.ButtonA or input.KeyCode == Enum.KeyCode.ButtonB or input.KeyCode == Enum.KeyCode.Space) then
			dismissable = false
			dismissSignal:Fire()
		end
	end)
	subtitle = Create.Text({
		Text = "",
		Size = UDim2.fromOffset(900, 60),
		Position = UDim2.new(0.5, 0, 0, 70),
		AnchorPoint = Vector2.new(0.5, 0),
		Font = Theme.Fonts.Display,
		TextSize = 54,
		Scaled = true,
		Stroke = 4,
		Parent = overlay,
	})
	stage = Create("Frame", {
		Name = "Stage",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(1200, 540),
		Parent = overlay,
	})
	Create.List(stage, Enum.FillDirection.Horizontal, 24, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	stageScale = Instance.new("UIScale")
	stageScale.Parent = stage
	UIController.ScaleChanged:Connect(function()
		if overlay.Visible then
			fitStage()
		end
	end)
	hint = Create.Text({
		Text = "",
		Size = UDim2.fromOffset(600, 40),
		Position = UDim2.new(0.5, 0, 1, -60),
		AnchorPoint = Vector2.new(0.5, 1),
		Font = Theme.Fonts.Display,
		TextSize = 32,
		Scaled = true,
		Color = Theme.Colors.TextDim,
		Stroke = 2.5,
		Parent = overlay,
	})
end

function EggScreen.Init()
	shell = MenuShell.new({
		Name = "Egg",
		Title = "Egg",
		Icon = Theme.Icons.Egg,
		Size = PANEL,
		Accent = Theme.Colors.Skill,
		OnResize = function(contentHeight: number)
			layoutLeft(contentHeight < 560)
		end,
		OnOpen = function(eggId: any)
			if type(eggId) == "string" and Eggs.Get(eggId) then
				currentEgg = Eggs.Get(eggId)
			end
			if currentEgg then
				shell.Panel:SetTitle(Theme.Icons.Egg .. " " .. string.upper(currentEgg.Name))
			end
			refresh()
		end,
		FirstSelection = function()
			return hatchOne.Instance
		end,
	})
	local content = shell.Content
	local left: Frame = Create("Frame", {
		Name = "Left",
		BackgroundColor3 = Theme.Colors.CardDeep,
		Size = UDim2.new(0, LEFT_W, 1, 0),
		Parent = content,
	})
	Create.Corner(16, left)
	Create.Stroke(left, Theme.Colors.PanelEdge, 2, 0.4, true)
	eggPreview = Create("Frame", {
		Name = "Preview",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(30, 8),
		Size = UDim2.new(1, -60, 0, 250),
		Parent = left,
	})
	eggName = Create.Text({
		Text = "",
		Size = UDim2.new(1, -24, 0, 42),
		Position = UDim2.fromOffset(12, 262),
		Font = Theme.Fonts.Display,
		TextSize = 38,
		Scaled = true,
		Stroke = 3,
		Parent = left,
	})
	eggPrice = Create.Text({
		Text = "",
		Size = UDim2.new(1, -24, 0, 36),
		Position = UDim2.fromOffset(12, 308),
		Font = Theme.Fonts.Display,
		TextSize = 32,
		Scaled = true,
		Stroke = 2.5,
		Parent = left,
	})
	luckLabel = Create.Text({
		Text = "",
		Size = UDim2.new(1, -24, 0, 28),
		Position = UDim2.fromOffset(12, 350),
		Font = Theme.Fonts.Display,
		TextSize = 24,
		Scaled = true,
		Color = Theme.Colors.Success,
		Stroke = 2,
		Parent = left,
	})
	hatchOne = Button.new({
		Parent = left,
		Name = "HatchOne",
		Size = UDim2.new(1, -24, 0, 70),
		Position = UDim2.new(0, 12, 1, -94),
		AnchorPoint = Vector2.new(0, 1),
		Style = "Green",
		Text = "HATCH 1",
		TextSize = 30,
		OnClick = function()
			hatch(1)
		end,
	})
	hatchThree = Button.new({
		Parent = left,
		Name = "HatchThree",
		Size = UDim2.new(1, -24, 0, 70),
		Position = UDim2.new(0, 12, 1, -12),
		AnchorPoint = Vector2.new(0, 1),
		Style = "Purple",
		Text = "HATCH 3",
		TextSize = 30,
		OnClick = function()
			hatch(3)
		end,
	})
	layoutLeft(false)
	local right: Frame = Create("Frame", {
		Name = "Right",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(LEFT_W + 16, 0),
		Size = UDim2.new(1, -(LEFT_W + 16), 1, 0),
		Parent = content,
	})
	Create.Text({
		Text = "CHANCES",
		Size = UDim2.new(1, 0, 0, 36),
		Font = Theme.Fonts.Display,
		TextSize = 32,
		Scaled = true,
		XAlign = Enum.TextXAlignment.Left,
		Stroke = 2.5,
		Parent = right,
	})
	oddsHolder = Create("Frame", {
		Name = "Odds",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -44),
		Parent = right,
	})

	buildOverlay()
	UIController.Register("Egg", shell)
	StateController.DataChanged:Connect(function()
		if shell:IsOpen() then
			refresh()
		end
	end)
	Remotes.Event("HatchResult").OnClientEvent:Connect(function(payload: any)
		if type(payload) ~= "table" or type(payload.Pets) ~= "table" then
			return
		end
		Bus.HatchResult:Fire(payload)
		enqueue({
			Egg = if type(payload.Egg) == "string" then payload.Egg else "",
			Pets = payload.Pets,
			Source = if type(payload.Source) == "string" then payload.Source else nil,
		})
	end)
end

return EggScreen
