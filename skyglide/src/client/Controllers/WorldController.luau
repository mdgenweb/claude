--!strict
-- Client side of the world: per-world lighting (Visual/Themes, no asset ids), live labels and
-- prompt texts on pads / pedestals / relic / eggs / portals from the local player's data, the
-- ProximityPrompt actions (each one only sends an intent or opens a menu), and the spinning
-- glider/egg displays. Everything here is cosmetic or an intent; the server re-checks all of it.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local Themes = require(Shared.Visual.Themes)
local Worlds = require(Shared.Definitions.Worlds)
local Zones = require(Shared.Definitions.Zones)
local Training = require(Shared.Definitions.Training)
local Gliders = require(Shared.Definitions.Gliders)
local Relics = require(Shared.Definitions.Relics)
local Eggs = require(Shared.Definitions.Eggs)
local Monetization = require(Shared.Config.Monetization)
local Format = require(Shared.Util.Format)

local StateController = require(script.Parent.StateController)
local UIController = require(script.Parent.UIController)
local Bus = require(script.Parent.Bus)
local Net = require(script.Parent.Net)

local WorldController = {}

local hex = Color3.fromHex
local GREEN = hex("#5BE05B")
local RED = hex("#FF4F5E")
local GOLD = hex("#FFD447")
local WHITE = Color3.new(1, 1, 1)
local BLUE = hex("#7FD8FF")

local currentWorld = 0
type Effects = { Atmosphere: Atmosphere, Color: ColorCorrectionEffect, Bloom: BloomEffect }
local effects: Effects? = nil
local worldsFolder: Instance? = nil
local spinners: { Model } = {}
local spinBase: { [Model]: CFrame } = {}
local spinRoot: { [Model]: { Root: BasePart, Offset: CFrame } } = {} -- rigged displays: move the root only

-- Lighting ----------------------------------------------------------------------------------------

local function ensureEffects(): Effects
	local existing = effects
	if existing then
		return existing
	end
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") or child:IsA("Sky") then
			child:Destroy()
		end
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "SkyGlideAtmosphere"
	atmosphere.Parent = Lighting
	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "SkyGlideColor"
	colorCorrection.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "SkyGlideBloom"
	bloom.Intensity = 0.55
	bloom.Size = 22
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local created: Effects = { Atmosphere = atmosphere, Color = colorCorrection, Bloom = bloom }
	effects = created
	return created
end

local function applyLighting(worldId: number)
	local world = Worlds.Get(worldId)
	local theme = if world then Themes[world.Theme] else nil
	if not theme then
		return
	end
	local fx = ensureEffects()
	local atmosphere = fx.Atmosphere
	local colorCorrection = fx.Color
	Lighting.ClockTime = theme.ClockTime
	Lighting.Ambient = hex(theme.Ambient)
	Lighting.OutdoorAmbient = hex(theme.Ambient):Lerp(WHITE, 0.35)
	Lighting.FogColor = hex(theme.Fog)
	Lighting.FogStart = 900
	Lighting.FogEnd = 9000
	atmosphere.Color = hex(theme.Sky.Horizon)
	atmosphere.Decay = hex(theme.Sky.Top)
	atmosphere.Density = if theme.Props == "Volcano" then 0.36 else 0.26
	atmosphere.Offset = 0.1
	atmosphere.Haze = if theme.Props == "Volcano" then 2.2 else 1.1
	atmosphere.Glare = 0.25
	colorCorrection.Saturation = 0.14
	colorCorrection.Contrast = 0.06
	colorCorrection.Brightness = 0.02
	colorCorrection.TintColor = if theme.Props == "Volcano"
		then hex("#FFE6D2")
		elseif theme.Props == "Ice" then hex("#E8F6FF")
		else WHITE
end

local function setWorld(worldId: number)
	if worldId == currentWorld then
		return
	end
	currentWorld = worldId
	applyLighting(worldId)
	Bus.WorldChanged:Fire(worldId)
end

-- Labels --------------------------------------------------------------------------------------------

local function labelText(holder: Instance?, name: string): TextLabel?
	if holder == nil then
		return nil
	end
	local gui = holder:FindFirstChild("Label")
	local text = if gui then gui:FindFirstChild(name, true) else nil
	return if text and text:IsA("TextLabel") then text else nil
end

local function setLabel(holder: Instance?, name: string, text: string, color: Color3?)
	local label = labelText(holder, name)
	if label then
		label.Text = text
		if color then
			label.TextColor3 = color
		end
	end
end

local function setPrompt(holder: Instance?, name: string, action: string)
	local prompt = if holder then holder:FindFirstChild(name) else nil
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.ActionText = action
	end
end

local function worldModel(worldId: number): Instance?
	local folder = worldsFolder
	return if folder then folder:FindFirstChild("World_" .. worldId) else nil
end

local function child(root: Instance?, ...: string): Instance?
	local node = root
	for _, name in { ... } do
		if node == nil then
			return nil
		end
		node = node:FindFirstChild(name)
	end
	return node
end

-- Robux items whose id is still 0 are free test grants in Studio and "SOON" on live servers.
local IS_STUDIO = RunService:IsStudio()
local function robuxPrice(id: number?, robux: number?): (string, Color3)
	if id == nil or (id == 0 and not IS_STUDIO) then
		return "SOON", WHITE
	end
	return "R$" .. tostring(robux or 0), GREEN
end

local function refreshLabels()
	local data = StateController.Data
	if data == nil or worldsFolder == nil then
		return
	end
	local rebirths = if type(data.Rebirths) == "number" then data.Rebirths else 0
	local wins = if type(data.Wins) == "number" then data.Wins else 0
	local gliders = if type(data.Gliders) == "table" then data.Gliders else {}
	local relics = if type(data.Relics) == "table" then data.Relics else {}
	local worlds = if type(data.Worlds) == "table" then data.Worlds else {}
	local zones = if type(data.Zones) == "table" then data.Zones else {}
	local equippedRelic = if type(data.Relic) == "string" then data.Relic else ""

	for _, world in Worlds.List do
		local model = worldModel(world.Id)
		if model == nil then
			continue
		end
		-- training pads
		for _, pad in Training.ForWorld(world.Id) do
			local part = child(model, "Pads", "Pad_" .. pad.Id)
			local unlocked = if pad.PassKey then StateController.HasPass(pad.PassKey) else rebirths >= pad.Rebirths
			setLabel(part, "Status", if unlocked then "UNLOCKED" else "LOCKED", if unlocked then GREEN else RED)
			if pad.PassKey then
				if unlocked then
					setLabel(part, "Gate", "OWNED", GREEN)
				else
					local pass = Monetization.Pass(pad.PassKey)
					setLabel(part, "Gate", robuxPrice(if pass then pass.Id else nil, if pass then pass.Robux else nil))
				end
			end
		end
		-- glider pedestals
		for _, glider in Gliders.ForWorld(world.Id) do
			local base = child(model, "Pedestals", "Pedestal_" .. glider.Id, "Base")
			if base == nil then
				continue
			end
			if data.Glider == glider.Id and equippedRelic == "" then
				setLabel(base, "Status", "EQUIPPED", GREEN)
				setPrompt(base, "BuyPrompt", "Equipped")
			elseif gliders[glider.Id] then
				setLabel(base, "Status", "OWNED", BLUE)
				setPrompt(base, "BuyPrompt", "Equip")
			elseif wins >= glider.Price then
				setLabel(base, "Status", "UNLOCKED", GREEN)
				setPrompt(base, "BuyPrompt", "Buy")
			else
				setLabel(base, "Status", "LOCKED", RED)
				setPrompt(base, "BuyPrompt", "Buy")
			end
			setLabel(base, "Price", if gliders[glider.Id] then "OWNED" elseif glider.Price <= 0 then "FREE" else Format.Short(glider.Price) .. " Wins", GOLD)
		end
		-- relic
		for _, relic in Relics.List do
			local base = child(model, "Pedestals", "Relic_" .. relic.Id, "Base")
			if base == nil then
				continue
			end
			local info = StateController.Relics[relic.Id]
			local left = if info then math.max(0, info.Stock - info.Sold) else relic.Stock
			setLabel(base, "Stock", string.format("STOCK: %s/%s", Format.Commas(left), Format.Commas(relic.Stock)), if left > 0 then WHITE else RED)
			local product = Monetization.Product(relic.ProductKey)
			if relics[relic.Id] then
				setLabel(base, "Price", if equippedRelic == relic.Id then "EQUIPPED" else "OWNED", GREEN)
				setPrompt(base, "BuyPrompt", if equippedRelic == relic.Id then "Equipped" else "Equip")
			else
				local price, color = robuxPrice(if product then product.Id else nil, if product then product.Robux else nil)
				if left <= 0 then
					setLabel(base, "Price", "SOLD OUT", RED)
				else
					setLabel(base, "Price", if price == "SOON" then price else "ONLY " .. price, color)
				end
				setPrompt(base, "BuyPrompt", "Buy")
			end
		end
		-- eggs
		for _, egg in Eggs.ForWorld(world.Id) do
			local base = child(model, "Eggs", "Egg_" .. egg.Id, "Base")
			if base and egg.ProductKey then
				local product = Monetization.Product(egg.ProductKey)
				setLabel(base, "Price", robuxPrice(if product then product.Id else nil, if product then product.Robux else nil))
			elseif base then
				setLabel(base, "Price", Format.Short(egg.Price) .. " Wins", if wins >= egg.Price then GOLD else RED)
			end
		end
		-- portals
		for _, target in Worlds.List do
			local frame = child(model, "Portals", "Portal_" .. target.Id, "Frame")
			if frame == nil or target.Id < world.Id then
				continue
			end
			if worlds[tostring(target.Id)] then
				setLabel(frame, "Requirement", "UNLOCKED - step in!", GREEN)
			else
				local parts = {}
				if target.UnlockZone and not zones[target.UnlockZone] then
					local zone = Zones.Get(target.UnlockZone)
					table.insert(parts, "🏁 Reach " .. (if zone then zone.Name else "the river end"))
				end
				if rebirths < target.UnlockRebirths then
					table.insert(parts, string.format("🌀 %d/%d Rebirths", rebirths, target.UnlockRebirths))
				end
				setLabel(frame, "Requirement", if #parts == 0 then "READY TO UNLOCK!" else table.concat(parts, "  +  "), if #parts == 0 then GOLD else WHITE)
			end
		end
	end
end

-- Prompts -------------------------------------------------------------------------------------------

local function onPrompt(prompt: ProximityPrompt)
	local holder = prompt.Parent
	local model = if holder then holder.Parent else nil
	if model == nil then
		return
	end
	local data = StateController.Data
	if prompt.Name == "BuyPrompt" then
		local gliderId = string.match(model.Name, "^Pedestal_(.+)$")
		local relicId = string.match(model.Name, "^Relic_(.+)$")
		if gliderId and Gliders.Get(gliderId) then
			local owned = data and type(data.Gliders) == "table" and data.Gliders[gliderId]
			if owned then
				task.spawn(Net.Invoke, "RequestEquipThrowable", false, gliderId)
			else
				task.spawn(Net.Invoke, "RequestBuyThrowable", false, gliderId)
			end
		elseif relicId then
			local relic = Relics.Get(relicId)
			if relic == nil then
				return
			end
			local owned = data and type(data.Relics) == "table" and data.Relics[relicId]
			if owned then
				task.spawn(Net.Invoke, "RequestEquipThrowable", false, "relic:" .. relicId)
			else
				task.spawn(Net.Invoke, "RequestPurchase", false, "Product", relic.ProductKey)
			end
		end
	elseif prompt.Name == "HatchPrompt" then
		local eggId = string.match(model.Name, "^Egg_(.+)$")
		if eggId and Eggs.Get(eggId) then
			UIController.Open("Egg", eggId)
		end
	elseif prompt.Name == "PortalPrompt" then
		local id = tonumber(string.match(model.Name, "^Portal_(%d+)$"))
		if id and Worlds.Get(id) then
			UIController.Open("World", id)
		end
	end
end

-- Spinning displays ---------------------------------------------------------------------------------

local function track(model: Instance)
	if model:IsA("Model") and model:GetAttribute("Spin") == true and not spinBase[model] then
		spinBase[model] = model:GetPivot()
		local root = model.PrimaryPart
		if root and root.Anchored then
			-- the server rigged it (only the root anchored, the rest welded): one CFrame per frame
			local welded = model:FindFirstChildWhichIsA("WeldConstraint", true) ~= nil
			if welded then
				spinRoot[model] = { Root = root, Offset = root.PivotOffset:Inverse() }
			end
		end
		table.insert(spinners, model)
	end
end

local function scan(root: Instance)
	for _, d in root:GetDescendants() do
		track(d)
	end
	root.DescendantAdded:Connect(function(d)
		task.defer(track, d)
	end)
end

local function stepSpinners()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local camPos = camera.CFrame.Position
	local t = os.clock()
	for i = #spinners, 1, -1 do
		local model = spinners[i]
		if model.Parent == nil then
			table.remove(spinners, i)
			spinBase[model] = nil
			spinRoot[model] = nil
			continue
		end
		local base = spinBase[model]
		if (base.Position - camPos).Magnitude < 150 then
			local phase = i * 0.7
			local cf = base * CFrame.new(0, math.sin(t * 2 + phase) * 0.35, 0) * CFrame.Angles(0, t * 0.9 + phase, 0)
			local rig = spinRoot[model]
			if rig then
				rig.Root.CFrame = cf * rig.Offset
			else
				model:PivotTo(cf)
			end
		end
	end
end

-- Start ---------------------------------------------------------------------------------------------

function WorldController.Start()
	Remotes.Event("WorldChanged").OnClientEvent:Connect(function(worldId: any)
		if type(worldId) == "number" then
			setWorld(worldId)
		end
	end)
	local function fromData(data: { [string]: any }?)
		if data and type(data.World) == "number" then
			setWorld(data.World)
		end
		refreshLabels()
	end
	StateController.DataChanged:Connect(fromData)
	StateController.ServerInfoChanged:Connect(function(kind)
		if kind == "Relics" then
			refreshLabels()
		end
	end)
	fromData(StateController.Data)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		if player == Players.LocalPlayer then
			onPrompt(prompt)
		end
	end)
	task.spawn(function()
		local folder = Workspace:WaitForChild("Worlds", 60)
		if folder == nil then
			warn("[WorldController] Workspace.Worlds never appeared")
			return
		end
		worldsFolder = folder
		scan(folder)
		folder.ChildAdded:Connect(function()
			task.defer(refreshLabels)
		end)
		refreshLabels()
	end)
	RunService.RenderStepped:Connect(stepSpinners)
end

return WorldController
