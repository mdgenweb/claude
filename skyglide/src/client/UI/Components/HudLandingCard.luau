--!strict
-- Landing result card for the local player's throws (Bus.FlightLanded owner payload): zone name in
-- the zone colour, distance, +Wins / +Skill, perfect catches, special-throw tag and a "NEW BEST!" /
-- "NEW ZONE!" ribbon. Pops for ~2.5 s. A landing that opened a world (payload.UnlockedWorld) also
-- plays a big "NEW WORLD UNLOCKED" celebration with pooled confetti.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FlightSim = require(Shared.Sim.FlightSim)
local Format = require(Shared.Util.Format)
local Worlds = require(Shared.Definitions.Worlds)
local Zones = require(Shared.Definitions.Zones)

local UI = script.Parent.Parent
local Client = UI.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local AudioController = require(Client.Controllers.AudioController)
local Bus = require(Client.Controllers.Bus)

local HudLandingCard = {}

local POP = TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SHRINK = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local WHITE = Color3.new(1, 1, 1)
local CARD_TIME = 2.6
local WORLD_TIME = 4.5
local CONFETTI = 28

function HudLandingCard.new(root: Frame)
	local localPlayer = Players.LocalPlayer

	-- card ------------------------------------------------------------------------------------
	local card: Frame = Create("Frame", {
		Name = "LandingCard",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(500, 270),
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.06,
		Visible = false,
		ZIndex = 10,
		Parent = root,
	})
	Create.Corner(20, card)
	local cardStroke = Create.Stroke(card, WHITE, 4, 0, true)
	local cardScale = Instance.new("UIScale")
	cardScale.Parent = card

	local header: Frame = Create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 66),
		BackgroundColor3 = WHITE,
		ZIndex = 11,
		Parent = card,
	})
	Create.Corner(20, header)
	local headerGradient = Instance.new("UIGradient")
	headerGradient.Rotation = 90
	headerGradient.Parent = header
	local zoneText = Create.Text({
		Name = "Zone",
		Text = "",
		Size = UDim2.new(1, -40, 0, 50),
		Position = UDim2.new(0.5, 0, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0),
		Font = Theme.Fonts.Display,
		TextSize = 48,
		Scaled = true,
		Stroke = 3.5,
		ZIndex = 12,
		Parent = header,
	})
	local distanceText = Create.Text({
		Name = "Distance",
		Text = "",
		Size = UDim2.new(1, -40, 0, 70),
		Position = UDim2.new(0.5, 0, 0, 70),
		AnchorPoint = Vector2.new(0.5, 0),
		Font = Theme.Fonts.Display,
		TextSize = 70,
		Scaled = true,
		Stroke = 4,
		ZIndex = 12,
		Parent = card,
	})
	local winsText = Create.Text({
		Name = "Wins",
		Text = "",
		Size = UDim2.new(0.5, -20, 0, 44),
		Position = UDim2.fromOffset(20, 146),
		Font = Theme.Fonts.Display,
		TextSize = 42,
		Scaled = true,
		Color = Theme.Colors.Wins,
		Stroke = 3,
		ZIndex = 12,
		Parent = card,
	})
	local skillText = Create.Text({
		Name = "Skill",
		Text = "",
		Size = UDim2.new(0.5, -20, 0, 44),
		Position = UDim2.new(0.5, 0, 0, 146),
		Font = Theme.Fonts.Display,
		TextSize = 42,
		Scaled = true,
		Color = Color3.fromHex("#9FE6FF"),
		Stroke = 3,
		ZIndex = 12,
		Parent = card,
	})
	local perfectText = Create.Text({
		Name = "Perfects",
		Text = "",
		Size = UDim2.new(1, -40, 0, 34),
		Position = UDim2.new(0.5, 0, 0, 196),
		AnchorPoint = Vector2.new(0.5, 0),
		Font = Theme.Fonts.Display,
		TextSize = 32,
		Scaled = true,
		Color = Theme.Colors.MeterPerfect,
		Stroke = 2.5,
		ZIndex = 12,
		Parent = card,
	})
	local specialText = Create.Text({
		Name = "Special",
		Text = "",
		Size = UDim2.new(1, -40, 0, 28),
		Position = UDim2.new(0.5, 0, 0, 232),
		AnchorPoint = Vector2.new(0.5, 0),
		Font = Theme.Fonts.Display,
		TextSize = 28,
		Scaled = true,
		Stroke = 2.5,
		ZIndex = 12,
		Parent = card,
	})
	local ribbon: Frame = Create("Frame", {
		Name = "Ribbon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -40, 0, 0),
		Size = UDim2.fromOffset(210, 52),
		Rotation = 12,
		BackgroundColor3 = WHITE,
		Visible = false,
		ZIndex = 14,
		Parent = card,
	})
	Create.Corner(12, ribbon)
	local ribbonGradient = Create.Gradient(ribbon, Color3.fromHex("#FF8FC8"), Color3.fromHex("#E8357F"), 90)
	Create.Stroke(ribbon, Theme.Colors.Stroke, 3, 0, true)
	local ribbonText = Create.Text({
		Name = "Text",
		Text = "NEW BEST!",
		Size = UDim2.new(1, -16, 1, -10),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = Theme.Fonts.Display,
		TextSize = 34,
		Scaled = true,
		Stroke = 3,
		ZIndex = 15,
		Parent = ribbon,
	})
	local ribbonScale = Instance.new("UIScale")
	ribbonScale.Parent = ribbon

	-- world unlock celebration ----------------------------------------------------------------
	local world: Frame = Create("Frame", {
		Name = "WorldUnlocked",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.2),
		Size = UDim2.fromOffset(1040, 170),
		BackgroundColor3 = WHITE,
		Visible = false,
		ZIndex = 20,
		Parent = root,
	})
	Create.Corner(26, world)
	Create.Stroke(world, Theme.Colors.Stroke, 5, 0, true)
	local worldGradient = Instance.new("UIGradient")
	worldGradient.Color = Theme.Rainbow
	worldGradient.Parent = world
	local worldScale = Instance.new("UIScale")
	worldScale.Parent = world
	local worldTitle = Create.Text({
		Name = "Title",
		Text = "",
		Size = UDim2.new(1, -40, 0, 100),
		Position = UDim2.new(0.5, 0, 0, 10),
		AnchorPoint = Vector2.new(0.5, 0),
		Font = Theme.Fonts.Display,
		TextSize = 80,
		Scaled = true,
		Stroke = 5,
		ZIndex = 21,
		Parent = world,
	})
	Create.Text({
		Name = "Subtitle",
		Text = Theme.Icons.World .. " Use the portal to travel there!",
		Size = UDim2.new(1, -40, 0, 44),
		Position = UDim2.new(0.5, 0, 1, -10),
		AnchorPoint = Vector2.new(0.5, 1),
		Font = Theme.Fonts.Display,
		TextSize = 40,
		Scaled = true,
		Stroke = 3.5,
		ZIndex = 21,
		Parent = world,
	})
	local confettiLayer: Frame = Create("Frame", {
		Name = "Confetti",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 19,
		Visible = false,
		Parent = root,
	})
	local CONFETTI_COLORS = {
		Color3.fromHex("#FF4F4F"),
		Color3.fromHex("#FFC53D"),
		Color3.fromHex("#5BE05B"),
		Color3.fromHex("#3FA9FF"),
		Color3.fromHex("#B65CFF"),
		Color3.fromHex("#FF8FC8"),
	}
	local pieces: { Frame } = table.create(CONFETTI)
	for i = 1, CONFETTI do
		pieces[i] = Create("Frame", {
			Name = "Piece",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(16, 26),
			BackgroundColor3 = CONFETTI_COLORS[(i - 1) % #CONFETTI_COLORS + 1],
			ZIndex = 19,
			Parent = confettiLayer,
		})
	end
	local rng = Random.new()

	local cardToken = 0
	local worldToken = 0

	local function celebrateWorld(worldId: number)
		local def = Worlds.Get(worldId)
		if not def then
			return
		end
		worldToken += 1
		local token = worldToken
		worldTitle.Text = "NEW WORLD UNLOCKED: " .. string.upper(def.Name) .. "!"
		world.Visible = true
		worldScale.Scale = 0.2
		TweenService:Create(worldScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		confettiLayer.Visible = true
		for _, piece in pieces do
			local x = rng:NextNumber(0.05, 0.95)
			piece.Position = UDim2.fromScale(x, -0.05)
			piece.Rotation = rng:NextNumber(0, 360)
			piece.BackgroundTransparency = 0
			local fall = TweenInfo.new(rng:NextNumber(2.2, 3.6), Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, rng:NextNumber(0, 0.8))
			TweenService:Create(piece, fall, {
				Position = UDim2.fromScale(x + rng:NextNumber(-0.12, 0.12), 1.08),
				Rotation = piece.Rotation + rng:NextNumber(-540, 540),
			}):Play()
		end
		AudioController.Play("Rebirth")
		task.delay(WORLD_TIME, function()
			if token ~= worldToken then
				return
			end
			local out = TweenService:Create(worldScale, SHRINK, { Scale = 0 })
			out:Play()
			out.Completed:Wait()
			if token == worldToken then
				world.Visible = false
				confettiLayer.Visible = false
			end
		end)
	end

	local function show(payload: { [string]: any })
		local zone = if type(payload.Zone) == "string" then Zones.Get(payload.Zone) else nil
		local color = if zone then Color3.fromHex(zone.Color) else WHITE
		zoneText.Text = if zone then zone.Name else "Splash!"
		zoneText.TextColor3 = WHITE
		headerGradient.Color = ColorSequence.new(color:Lerp(WHITE, 0.15), color:Lerp(Color3.new(0, 0, 0), 0.45))
		cardStroke.Color = color
		distanceText.Text = Format.Meters(tonumber(payload.Distance) or 0)
		winsText.Text = "+" .. Format.Short(tonumber(payload.Wins) or 0) .. " " .. Theme.Icons.Wins
		skillText.Text = "+" .. Format.Short(tonumber(payload.Skill) or 0) .. " " .. Theme.Icons.Skill
		local perfects = tonumber(payload.Perfects) or 0
		local rings = tonumber(payload.Rings) or 0
		perfectText.Text = string.format("%s %d/%d PERFECT CATCHES", Theme.Icons.Star, perfects, rings)
		local info = FlightSim.SpecialInfo(if type(payload.Special) == "string" then payload.Special else nil)
		if info then
			specialText.Text = string.format("%s THROW x%d", info.Name, info.Multiplier)
			specialText.TextColor3 = Color3.fromHex(info.Color)
			specialText.Visible = true
		else
			specialText.Visible = false
		end

		local newBest = payload.NewBest == true
		local newZone = payload.NewZone == true
		ribbon.Visible = newBest or newZone
		if newBest then
			ribbonText.Text = "NEW BEST!"
			ribbonGradient.Color = ColorSequence.new(Color3.fromHex("#FF8FC8"), Color3.fromHex("#E8357F"))
		elseif newZone then
			ribbonText.Text = "NEW ZONE!"
			ribbonGradient.Color = ColorSequence.new(Color3.fromHex("#7BEA4A"), Color3.fromHex("#2FA80F"))
		end
		if ribbon.Visible then
			ribbonScale.Scale = 0
			TweenService:Create(ribbonScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.25), { Scale = 1 }):Play()
		end

		cardToken += 1
		local token = cardToken
		card.Visible = true
		cardScale.Scale = 0.3
		TweenService:Create(cardScale, POP, { Scale = 1 }):Play()
		if newBest then
			AudioController.Play("NewBest")
		else
			AudioController.Play("Reward", nil, nil, 0.6)
		end
		task.delay(CARD_TIME, function()
			if token ~= cardToken then
				return
			end
			local out = TweenService:Create(cardScale, SHRINK, { Scale = 0 })
			out:Play()
			out.Completed:Wait()
			if token == cardToken then
				card.Visible = false
			end
		end)

		if type(payload.UnlockedWorld) == "number" then
			celebrateWorld(payload.UnlockedWorld)
		end
	end

	Bus.FlightLanded:Connect(function(payload: any)
		if type(payload) ~= "table" or payload.Cancelled or payload.Owner ~= true then
			return
		end
		if payload.UserId ~= nil and payload.UserId ~= localPlayer.UserId then
			return
		end
		show(payload)
	end)
end

return HudLandingCard
