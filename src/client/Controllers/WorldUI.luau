-- Client-side world UI:
--  * HP bars over your own lane's junk (neighbours' junk stays uncluttered)
--  * a bouncing "SMASH!" pointer until the first smash
--  * hub pads that open their panel when you step on them, with live info lines
--  * gate barriers that open locally once you own the gate, and the unlock prompt

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Layout = require(Shared.Layout)
local Theme = require(Shared.Theme)

local Net = require(script.Parent.Parent.Net)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Panels = require(script.Parent.Parent.UI.Panels)

local WorldUI = {}

local player = Players.LocalPlayer
local world: Folder
local bars: { [Model]: { gui: BillboardGui, conn: RBXScriptConnection, update: () -> () } } = {}
local watchedLane: number? = nil
local laneConns: { RBXScriptConnection } = {}

-- HP bars ------------------------------------------------------------------------------

local function removeBar(model: Model)
	local bar = bars[model]
	if bar then
		bar.conn:Disconnect()
		bar.gui:Destroy()
		bars[model] = nil
	end
end

local function addBar(model: Model)
	if bars[model] or not model:IsA("Model") then
		return
	end
	local hitbox = model.PrimaryPart or model:WaitForChild("Hitbox", 2)
	if not hitbox then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "HPBar"
	gui.Size = UDim2.fromOffset(150, 46)
	gui.StudsOffsetWorldSpace = Vector3.new(0, (hitbox :: BasePart).Size.Y / 2 + 1.8, 0)
	gui.MaxDistance = 55
	gui.LightInfluence = 0
	gui.Adornee = hitbox
	local name = UIKit.text(gui, { Text = model.Name, TextSize = 18, Size = UDim2.new(1, 0, 0, 20) })
	local bar = UIKit.progress(gui, {
		Size = UDim2.new(1, -10, 0, 20),
		Position = UDim2.fromOffset(5, 22),
		TextSize = 13,
		Swatch = Theme.Swatch.Green,
	})
	local function update()
		local hp = model:GetAttribute("HP") or 0
		local maxHp = model:GetAttribute("MaxHP") or 1
		local area = model:GetAttribute("Area") or 1
		local locked = not Net.unlocked(area)
		local ratio = hp / maxHp
		local swatch = if locked
			then Theme.Swatch.Steel
			elseif ratio > 0.5 then Theme.Swatch.Green
			elseif ratio > 0.25 then Theme.Swatch.Yellow
			else Theme.Swatch.Red
		bar:Set(ratio, (if locked then "🔒 " else "") .. Economy.format(hp) .. " HP", swatch)
		name.Text = model.Name .. "  ⚙️" .. tostring(model:GetAttribute("Reward") or "")
	end
	update()
	gui.Parent = player:WaitForChild("PlayerGui")
	bars[model] = { gui = gui, conn = model:GetAttributeChangedSignal("HP"):Connect(update), update = update }
	model.Destroying:Connect(function()
		removeBar(model)
	end)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			removeBar(model)
		end
	end)
end

local function watchLane(lane: number?)
	if lane == watchedLane then
		return
	end
	watchedLane = lane
	for _, c in laneConns do
		c:Disconnect()
	end
	table.clear(laneConns)
	for model in bars do
		removeBar(model)
	end
	if not lane then
		return
	end
	local folder = world:WaitForChild("Targets"):WaitForChild("Lane" .. lane)
	for _, model in folder:GetChildren() do
		task.spawn(addBar, model)
	end
	table.insert(
		laneConns,
		folder.ChildAdded:Connect(function(model)
			task.spawn(addBar, model)
		end)
	)
end

-- Gate ownership changes the lock icons, so redraw every bar.
local function refreshBars()
	for model, bar in bars do
		if model.Parent then
			bar.update()
		end
	end
end

-- Smash pointer ---------------------------------------------------------------------------

local pointer: BillboardGui? = nil

local function updatePointer()
	local s = Net.State
	local show = s and (s.Destroys or 0) == 0 and watchedLane ~= nil and not Panels.isOpen("ToolPicker")
	if not show then
		if pointer then
			pointer:Destroy()
			pointer = nil
		end
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local best, bestD = nil, math.huge
	for model in bars do
		if model.Parent and model.PrimaryPart and model:GetAttribute("Area") == 1 then
			local d = (model.PrimaryPart.Position - root.Position).Magnitude
			if d < bestD then
				best, bestD = model, d
			end
		end
	end
	if not best then
		return
	end
	if not pointer then
		local gui = Instance.new("BillboardGui")
		gui.Name = "SmashPointer"
		gui.Size = UDim2.fromOffset(180, 110)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		UIKit.text(gui, {
			Text = "SMASH!",
			TextSize = 40,
			Size = UDim2.new(1, 0, 0, 46),
			Color = Color3.fromHex("#FFB24A"),
			StrokeThickness = 4,
		})
		local arrow = UIKit.text(gui, {
			Text = "▼",
			TextSize = 50,
			Size = UDim2.new(1, 0, 0, 56),
			Position = UDim2.fromOffset(0, 46),
			Color = Color3.fromHex("#FFE14D"),
			StrokeThickness = 4,
		})
		UIKit.bob(arrow, 8, 0.8)
		gui.Parent = player:WaitForChild("PlayerGui")
		pointer = gui
	end
	local p = pointer :: BillboardGui
	p.Adornee = best.PrimaryPart
	p.StudsOffsetWorldSpace = Vector3.new(0, (best.PrimaryPart :: BasePart).Size.Y / 2 + 5, 0)
end

-- Pads ---------------------------------------------------------------------------------------

local currentPad: string? = nil
local openedByPad: string? = nil

local function padLiveText(id: string): string
	local s = Net.State
	if not s then
		return ""
	end
	if id == "Upgrade" then
		local nextUp = Economy.nextUpgrade(s.Level)
		if not nextUp then
			return "MAX POWER!"
		end
		return string.format("Next: ⚡%s for %s Scrap", Economy.format(nextUp.Power), Economy.format(nextUp.Cost))
	elseif id == "Daily" then
		return string.format(
			"Workshop %d/%d · Contract %d/%d",
			math.floor(Net.workshopStored()),
			Config.Workshop.Cap,
			math.min(s.Daily.Progress, Config.Daily.Goal),
			Config.Daily.Goal
		)
	elseif id == "Rebirth" then
		if s.Rebirths >= Economy.MaxRebirths then
			return "All rebirths done!"
		end
		return string.format(
			"Scrap x%.2f → x%.2f",
			Economy.rebirthFactor(s.Rebirths),
			Economy.rebirthFactor(s.Rebirths + 1)
		)
	elseif id == "Shop" then
		return if s.BoostCharges > 0
			then string.format("%d boost charge%s ready", s.BoostCharges, if s.BoostCharges == 1 then "" else "s")
			else "7 offers"
	elseif id == "Garage" then
		return string.format("%d/%d finishes", #s.Finishes, #Config.Finishes)
	end
	return ""
end

local function updatePads(root: BasePart?)
	local pads = world:FindFirstChild("Hub") and world.Hub:FindFirstChild("Pads")
	if not pads then
		return
	end
	local inside: string? = nil
	for _, pad in pads:GetChildren() do
		local id = pad:GetAttribute("PadId")
		if id then
			local label = pad:FindFirstChild("Label")
			local live = label and label:FindFirstChild("Live")
			if live then
				live.Text = padLiveText(id)
			end
			if root then
				local flat = Vector3.new(pad.Position.X - root.Position.X, 0, pad.Position.Z - root.Position.Z)
				if flat.Magnitude <= Layout.PadRadius and math.abs(pad.Position.Y - root.Position.Y) < 10 then
					inside = id
				end
			end
		end
	end
	if inside ~= currentPad then
		if currentPad and openedByPad == currentPad and Panels.isOpen(currentPad) then
			Panels.close()
		end
		currentPad = inside
		openedByPad = nil
		if inside then
			Panels.open(inside)
			openedByPad = inside
		end
	end
end

-- Gates -----------------------------------------------------------------------------------------

local promptedGate: number? = nil

local function updateGates(root: BasePart?)
	for gate = 1, 2 do
		local folder = world:FindFirstChild("Gate" .. gate)
		local barrier = folder and folder:FindFirstChild("Barrier") :: BasePart?
		if barrier then
			local area = barrier:GetAttribute("GateArea")
			local open = Net.unlocked(area)
			barrier.CanCollide = not open
			barrier.Transparency = if open then 1 else 0.2
			local label = barrier:FindFirstChild("Label") :: BillboardGui?
			if label then
				label.Enabled = not open
			end
			if root and not open then
				local d =
					Vector3.new(barrier.Position.X - root.Position.X, 0, barrier.Position.Z - root.Position.Z).Magnitude
				if d < 12 and promptedGate ~= area and not Panels.isOpen() then
					promptedGate = area
					Panels.open("Gate", area)
				elseif d > 20 and promptedGate == area then
					promptedGate = nil
				end
			end
		end
	end
end

function WorldUI.init()
	world = Workspace:WaitForChild("World")
	Net.Changed:Connect(function(s)
		watchLane(s.Lane)
		refreshBars()
		updateGates(nil)
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local ok, err = pcall(function()
				updatePads(root)
				updateGates(root)
				updatePointer()
			end)
			if not ok then
				warn("[WorldUI] " .. tostring(err))
			end
		end
	end)
end

return WorldUI
