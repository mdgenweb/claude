--!strict
-- Interactive hub stations, built to the naming contract in docs/DESIGN.md §5 that clients read:
-- training pads (Pads/Pad_<id>), glider pedestals and relics (Pedestals/Pedestal_<id>,
-- Pedestals/Relic_<id>), eggs (Eggs/Egg_<id>), portals (Portals/Portal_<worldId>) and global
-- leaderboards (Boards/Board_<Stat>). Labels carry neutral defaults ("LOCKED", prices); each
-- client rewrites them locally from its own data. Prompts are only intents: the owning services
-- re-check distance, ownership and price on the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Map = require(Shared.Config.Map)
local Monetization = require(Shared.Config.Monetization)
local Rarity = require(Shared.Config.Rarity)
local Format = require(Shared.Util.Format)
local Themes = require(Shared.Visual.Themes)
local GliderFactory = require(Shared.Visual.GliderFactory)
local EggFactory = require(Shared.Visual.EggFactory)
local Worlds = require(Shared.Definitions.Worlds)
local Zones = require(Shared.Definitions.Zones)
local Training = require(Shared.Definitions.Training)
local Gliders = require(Shared.Definitions.Gliders)
local Relics = require(Shared.Definitions.Relics)
local Eggs = require(Shared.Definitions.Eggs)

local MapKit = require(script.Parent.MapKit)

local MapStations = {}

local NEON = Enum.Material.Neon
local WHITE = Color3.new(1, 1, 1)
local RED = Color3.fromHex("#FF4B4B")
local GREEN = Color3.fromHex("#5BE05B")
local GOLD = Color3.fromHex("#FFD447")
local PILL = Color3.fromHex("#141A33")
local PANEL = Color3.fromHex("#1B2140")

local PROMPT_REACH = 12
local PORTAL_REACH = 14

-- Shared visual with no dependency on the factories: used only if a factory call fails, so a
-- broken template never leaves a pedestal empty or stops the world from building.
local function fallbackModel(primary: Color3, secondary: Color3, size: number): Model
	local model = Instance.new("Model")
	local core = MapKit.Part(model, Vector3.new(size * 0.5, size * 0.12, size), CFrame.new(), primary, { Name = "Root" })
	MapKit.Part(model, Vector3.new(size, size * 0.06, size * 0.35), CFrame.new(0, 0, size * 0.1), secondary, {})
	model.PrimaryPart = core
	return model
end

-- Builds a factory model, falling back to a simple shape if the factory errors.
local function safeModel(label: string, build: () -> Model, primary: Color3, secondary: Color3, size: number): Model
	local ok, result = pcall(build)
	if ok and typeof(result) == "Instance" and result:IsA("Model") then
		return result
	end
	warn(string.format("[MapBuilder] %s model failed: %s", label, tostring(result)))
	return fallbackModel(primary, secondary, size)
end

-- Moves a model's pivot to the centre of its bounding box (so clients can spin it in place).
local function centerPivot(model: Model): Vector3
	local cf, size = model:GetBoundingBox()
	local center = CFrame.new(cf.Position)
	local primary = model.PrimaryPart
	if primary then
		primary.PivotOffset = primary.CFrame:ToObjectSpace(center)
	else
		model.WorldPivot = center
	end
	return size
end

local function anchorAll(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
end

local function label(part: BasePart, width: number, height: number, offsetY: number, maxDistance: number): BillboardGui
	return MapKit.Billboard(part, "Label", width, height, offsetY, maxDistance)
end

-- Stroked text line inside a billboard (x/width default to the full width).
local function line(gui: Instance, name: string, text: string, y: number, h: number, color: Color3, font: Font?): TextLabel
	return MapKit.Text(gui, name, text, y, h, color, { Font = font, StrokeThickness = 2.5 })
end

-- Dark rounded pill behind a short text (rebirth gates, Robux prices).
local function pill(gui: Instance, name: string, text: string, y: number, h: number, color: Color3): TextLabel
	local t = MapKit.Text(gui, name, text, y, h, color, { StrokeThickness = 1.5 })
	t.Position = UDim2.fromScale(0.22, y)
	t.Size = UDim2.fromScale(0.56, h)
	t.BackgroundColor3 = PILL
	t.BackgroundTransparency = 0.15
	MapKit.Corner(t, 0.5)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.12, 0)
	pad.PaddingBottom = UDim.new(0.12, 0)
	pad.Parent = t
	return t
end

-- PADS --------------------------------------------------------------------------------------------

function MapStations.Pads(ctx: MapKit.Ctx, parent: Instance)
	for _, pad in Training.ForWorld(ctx.World.Id) do
		local c = Map.PadPosition(pad.Slot)
		local size = Map.PadSize
		local color = MapKit.Hex(pad.Color)
		local trim = if pad.PassKey then MapKit.Hex(pad.Accent) else MapKit.Tint(color, 0.45)
		local part = MapKit.Part(parent, size, MapKit.CF(ctx, c.X, c.Y + 0.2 + size.Y / 2, c.Z), color, {
			Solid = true,
			Shadow = true,
			Name = "Pad_" .. pad.Id,
		})
		part.CanTouch = true -- clients may use touch/overlap queries on pads
		part:SetAttribute("PadId", pad.Id)
		-- glowing trim showing around the slab, and an inset square on top
		MapKit.Part(part, Vector3.new(size.X + 1.6, 0.8, size.Z + 1.6), MapKit.CF(ctx, c.X, c.Y + 0.4, c.Z), trim, {
			Material = NEON,
			Name = "Trim",
		})
		MapKit.Part(part, Vector3.new(size.X * 0.72, 0.1, size.Z * 0.72), MapKit.CF(ctx, c.X, c.Y + 0.2 + size.Y + 0.03, c.Z), MapKit.Shade(color, 0.12), {
			Name = "Inset",
		})
		-- the multiplier painted on the pad, readable from the path (east of the pads)
		local decal = MapKit.FloorDecal(part, MapKit.At(ctx, c.X, c.Y + 0.2 + size.Y + 0.1, c.Z), Vector3.new(-1, 0, 0), size.Z * 0.66, size.X * 0.4)
		local paint = MapKit.Surface(decal, "Paint", Enum.NormalId.Front, 12)
		MapKit.Text(paint, "PaintText", Format.Short(pad.Multiplier) .. "x", 0, 1, WHITE, {
			Font = MapKit.Fonts.Numbers,
			Transparency = 0.25,
			StrokeThickness = 3,
		})

		local gui = label(part, 13, 8, 9, 110)
		local multColor = WHITE
		if pad.PassKey then
			local pass = Monetization.Pass(pad.PassKey)
			line(gui, "Caption", "ALL WORLDS", 0, 0.15, WHITE, MapKit.Fonts.Body)
			pill(gui, "Gate", "R$" .. tostring(if pass then pass.Robux else 0), 0.16, 0.26, GREEN)
			multColor = color
		else
			pill(gui, "Gate", "🌀 " .. tostring(pad.Rebirths), 0.16, 0.26, WHITE)
		end
		line(gui, "Status", "LOCKED", 0.44, 0.22, RED)
		line(gui, "Mult", Format.Short(pad.Multiplier) .. "x SKILL", 0.67, 0.33, multColor)
	end
end

-- PEDESTALS ---------------------------------------------------------------------------------------

-- Round pedestal base (PrimaryPart "Base") with a glowing foot ring and an inset top.
local function pedestalBase(ctx: MapKit.Ctx, model: Model, pos: Vector3, diameter: number, height: number, stone: Color3, ring: Color3): Part
	local base = MapKit.Disc(model, diameter, height, MapKit.CF(ctx, pos.X, pos.Y + height / 2, pos.Z), stone, {
		Solid = true,
		Shadow = true,
		Name = "Base",
	})
	MapKit.Disc(model, diameter + 1.2, 0.6, MapKit.CF(ctx, pos.X, pos.Y + 0.3, pos.Z), ring, {
		Material = NEON,
		Name = "Ring",
	})
	MapKit.Disc(model, diameter * 0.75, 0.12, MapKit.CF(ctx, pos.X, pos.Y + height + 0.04, pos.Z), ring, { Name = "Top" })
	model.PrimaryPart = base
	return base
end

local function placeDisplay(model: Model, display: Model, center: Vector3)
	display.Name = "Display"
	anchorAll(display)
	centerPivot(display)
	display:PivotTo(CFrame.new(center))
	display:SetAttribute("Spin", true)
	display.Parent = model
end

local function gliderPedestal(ctx: MapKit.Ctx, parent: Instance, glider: Gliders.Glider, index: number)
	local pos = Map.PedestalPosition(index)
	local rarity = MapKit.Hex(Rarity.Get(glider.Rarity).Color)
	local model = Instance.new("Model")
	model.Name = "Pedestal_" .. glider.Id
	model:SetAttribute("Glider", glider.Id)
	local base = pedestalBase(ctx, model, pos, 10, 2.4, ctx.Pal.Stone, rarity)

	local primary = MapKit.Hex(glider.Visual.Primary)
	local secondary = MapKit.Hex(glider.Visual.Secondary)
	local display = safeModel(glider.Id, function()
		return GliderFactory.Build(glider.Visual, 5, true)
	end, primary, secondary, 5)
	placeDisplay(model, display, MapKit.At(ctx, pos.X, pos.Y + 6.5, pos.Z))
	if Rarity.Order(glider.Rarity) >= Rarity.Order("Legendary") then
		MapKit.Sparkles(base, rarity, 3, 2.5)
	end

	MapKit.Prompt(base, "BuyPrompt", glider.Name, "Buy", PROMPT_REACH)
	local gui = label(base, 10, 5.4, 11.5, 70)
	line(gui, "Status", "LOCKED", 0, 0.28, RED)
	line(gui, "Skill", "+" .. Format.Short(glider.SkillPerRing) .. " Skill", 0.28, 0.42, WHITE)
	line(gui, "Price", if glider.Price <= 0 then "FREE" else Format.Short(glider.Price) .. " Wins", 0.7, 0.3, GOLD)
	model.Parent = parent
end

local function relicPedestal(ctx: MapKit.Ctx, parent: Instance, relic: Relics.Relic, index: number)
	local pos = Map.RelicSpot + Map.PedestalStepAcross * (index - 1)
	local primary = MapKit.Hex(relic.Visual.Primary)
	local secondary = MapKit.Hex(relic.Visual.Secondary)
	local model = Instance.new("Model")
	model.Name = "Relic_" .. relic.Id
	model:SetAttribute("Relic", relic.Id)
	local base = pedestalBase(ctx, model, pos, 11, 3, MapKit.Shade(primary, 0.35), primary)
	MapKit.Disc(model, 13.5, 0.5, MapKit.CF(ctx, pos.X, pos.Y + 0.9, pos.Z), secondary, {
		Material = NEON,
		Name = "Ring2",
	})
	local display = safeModel(relic.Id, function()
		return GliderFactory.Build(relic.Visual, 6, true)
	end, primary, secondary, 6)
	placeDisplay(model, display, MapKit.At(ctx, pos.X, pos.Y + 8, pos.Z))
	MapKit.Sparkles(base, primary, 6, 4)
	MapKit.Light(base, primary, 16, 1.5)

	MapKit.Prompt(base, "BuyPrompt", relic.Name, "Buy", PROMPT_REACH)
	local product = Monetization.Product(relic.ProductKey)
	local gui = label(base, 14, 8, 14, 90)
	line(gui, "Stock", string.format("STOCK: %s/%s", Format.Commas(relic.Stock), Format.Commas(relic.Stock)), 0, 0.2, WHITE)
	local bonus = line(gui, "Bonus", string.format("ALWAYS %d%% BETTER", math.floor(relic.BonusOverBest * 100 + 0.5)), 0.2, 0.24, WHITE)
	MapKit.Gradient(bonus, MapKit.Rainbow)
	local title = line(gui, "Title", string.upper(relic.Name), 0.44, 0.3, WHITE)
	MapKit.Gradient(title, { GOLD, Color3.fromHex("#FF9A3D") })
	line(gui, "Price", "R$" .. tostring(if product then product.Robux else 0), 0.75, 0.25, GREEN)
	model.Parent = parent
end

function MapStations.Pedestals(ctx: MapKit.Ctx, parent: Instance)
	for i, glider in Gliders.ForWorld(ctx.World.Id) do
		gliderPedestal(ctx, parent, glider, i)
	end
	for i, relic in Relics.List do
		relicPedestal(ctx, parent, relic, i)
	end
end

-- EGGS --------------------------------------------------------------------------------------------

function MapStations.Eggs(ctx: MapKit.Ctx, parent: Instance)
	for i, egg in Eggs.ForWorld(ctx.World.Id) do
		local pos = Map.EggPosition(i)
		local color = MapKit.Hex(egg.Color)
		local accent = MapKit.Hex(egg.Accent)
		local model = Instance.new("Model")
		model.Name = "Egg_" .. egg.Id
		model:SetAttribute("Egg", egg.Id)
		local base = MapKit.Disc(model, 12, 2, MapKit.CF(ctx, pos.X, pos.Y + 1, pos.Z), ctx.Pal.Stone, {
			Solid = true,
			Shadow = true,
			Name = "Base",
		})
		model.PrimaryPart = base
		MapKit.Disc(model, 13, 0.6, MapKit.CF(ctx, pos.X, pos.Y + 0.3, pos.Z), accent, { Material = NEON, Name = "Ring" })
		MapKit.Disc(model, 9, 1, MapKit.CF(ctx, pos.X, pos.Y + 2.5, pos.Z), color, { Shadow = true, Name = "Stand" })

		local eggModel = safeModel(egg.Id, function()
			return EggFactory.Build(egg, 7)
		end, color, accent, 7)
		eggModel.Name = "Display"
		anchorAll(eggModel)
		local size = centerPivot(eggModel)
		eggModel:PivotTo(CFrame.new(MapKit.At(ctx, pos.X, pos.Y + 3 + size.Y / 2, pos.Z)))
		eggModel.Parent = model

		local robux = egg.ProductKey ~= nil
		if robux then
			MapKit.Sparkles(base, accent, 5, 3)
			MapKit.Light(base, accent, 14, 1.2)
		end
		MapKit.Prompt(base, "HatchPrompt", egg.Name, "Hatch", PROMPT_REACH)
		local gui = label(base, 12, 5, 13.5, 90)
		line(gui, "Name", egg.Name, 0, 0.56, color)
		local price: string
		if robux then
			local product = Monetization.Product(egg.ProductKey :: string)
			price = "R$" .. tostring(if product then product.Robux else 0)
		else
			price = "🏆 " .. Format.Short(egg.Price)
		end
		line(gui, "Price", price, 0.56, 0.44, if robux then GREEN else GOLD)
		model.Parent = parent
	end
end

-- PORTALS -----------------------------------------------------------------------------------------

local function requirementText(target: Worlds.World): string
	local parts = {}
	if target.UnlockZone then
		local zone = Zones.Get(target.UnlockZone)
		table.insert(parts, "🏁 Reach " .. (if zone then zone.Name else "the river end"))
	end
	if target.UnlockRebirths > 0 then
		table.insert(parts, "🌀 " .. target.UnlockRebirths .. " Rebirths")
	end
	if target.UnlockWins > 0 then
		table.insert(parts, "🏆 " .. Format.Short(target.UnlockWins))
	end
	return if #parts > 0 then table.concat(parts, "  +  ") else "OPEN"
end

-- Big glowing archway (PrimaryPart "Frame" = the threshold slab) with a swirling neon disc.
local function portal(ctx: MapKit.Ctx, parent: Instance, target: Worlds.World, spot: Vector3, isNext: boolean)
	local theme = Themes[target.Theme] or Themes.Isles
	local glow = MapKit.Hex(theme.Accent)
	local swirl = MapKit.Hex(theme.Water)
	local stoneA = MapKit.Hex(theme.Cliff)
	local stoneB = MapKit.Hex(theme.CliffAlt)
	local model = Instance.new("Model")
	model.Name = "Portal_" .. target.Id
	model:SetAttribute("World", target.Id)

	local x, z = spot.X, spot.Z
	local frame = MapKit.Part(model, Vector3.new(30, 1, 10), MapKit.CF(ctx, x, spot.Y + 0.5, z), ctx.Pal.Stone, {
		Solid = true,
		Shadow = true,
		Name = "Frame",
	})
	frame.CanTouch = true
	model.PrimaryPart = frame
	MapKit.Part(model, Vector3.new(31, 0.6, 11), MapKit.CF(ctx, x, spot.Y + 0.3, z), glow, { Material = NEON, Name = "Glow" })
	-- stacked checker pillars
	local blockH = 5.5
	for side = -1, 1, 2 do
		for i = 0, 3 do
			MapKit.Part(model, Vector3.new(4.5, blockH, 6), MapKit.CF(ctx, x + side * 12.5, spot.Y + 1 + blockH * (i + 0.5), z), if (i + side) % 2 == 0 then stoneA else stoneB, {
				Solid = true,
				Shadow = true,
				Name = "Pillar",
			})
		end
	end
	-- stepped voxel arch over the top: {x offset, y offset, width} per step, mirrored
	local top = spot.Y + 1 + blockH * 4
	local steps = { { 11, 0, 7.5 }, { 6, 2.4, 5 } }
	for i, step in steps do
		for side = -1, 1, 2 do
			MapKit.Part(model, Vector3.new(step[3], 4.5, 6), MapKit.CF(ctx, x + side * step[1], top + step[2] + 2.25, z), if (i + side) % 2 == 0 then stoneA else stoneB, {
				Shadow = true,
				Name = "Arch",
			})
		end
	end
	local crown = top + 3.6 + 2.25
	MapKit.Part(model, Vector3.new(8, 4.5, 6), MapKit.CF(ctx, x, crown, z), stoneA, { Shadow = true, Name = "Arch" })
	MapKit.Part(model, Vector3.new(4, 4, 6.4), MapKit.CF(ctx, x, crown, z), glow, { Material = NEON, Name = "Keystone" })
	-- swirling disc: neon discs plus animated beam rings, facing the hub (-Z)
	local center = MapKit.At(ctx, x, spot.Y + 12.5, z)
	local facing = MapKit.Facing(center, -Vector3.zAxis)
	MapKit.FacingDisc(model, 21, 0.6, facing, glow, { Material = NEON, Transparency = 0.2, Name = "Disc" })
	MapKit.FacingDisc(model, 14, 0.8, facing, swirl, { Material = NEON, Transparency = 0.15, Name = "Inner" })
	local anchor = MapKit.Part(model, Vector3.new(1, 1, 1), facing * CFrame.new(0, 0, -0.6), WHITE, {
		Transparency = 1,
		Name = "Swirl",
	})
	MapKit.BeamRing(anchor, 9.5, 2.2, MapKit.Tint(glow, 0.3), 3)
	MapKit.BeamRing(anchor, 5.5, 1.8, WHITE, -4)
	MapKit.Sparkles(anchor, glow, 6, 3)
	MapKit.Light(anchor, glow, 22, 1.5)

	local world = ctx.World
	MapKit.Prompt(frame, "PortalPrompt", target.Name, "Travel", PORTAL_REACH)
	local gui = label(frame, 18, 7, 0, 160)
	-- in front of the arch crown (toward the hub) so the arch never hides it
	gui.StudsOffsetWorldSpace = Vector3.new(0, top - spot.Y + 5, -5)
	line(gui, "Name", string.upper(target.Name), 0, 0.55, glow)
	if isNext then
		line(gui, "Requirement", requirementText(target), 0.58, 0.42, WHITE, MapKit.Fonts.Body)
	else
		line(gui, "Requirement", "Back to world " .. tostring(target.Id), 0.58, 0.42, GREEN, MapKit.Fonts.Body)
	end
	model:SetAttribute("From", world.Id)
	model.Parent = parent
end

function MapStations.Portals(ctx: MapKit.Ctx, parent: Instance)
	local id = ctx.World.Id
	local nextWorld = Worlds.Get(id + 1)
	if nextWorld then
		portal(ctx, parent, nextWorld, Map.PortalNext, true)
	end
	local prevWorld = Worlds.Get(id - 1)
	if prevWorld then
		portal(ctx, parent, prevWorld, Map.PortalPrev, false)
	end
end

-- LEADERBOARDS ------------------------------------------------------------------------------------

local BOARD_TITLES: { [string]: string } = {
	Wins = "🏆 TOP WINS",
	BestDistance = "📏 LONGEST GLIDE",
	Rebirths = "🌀 MOST REBIRTHS",
}

function MapStations.Boards(ctx: MapKit.Ctx, parent: Instance)
	local width, height = 34, 24
	for _, entry in Map.Leaderboards do
		local center = ctx.Origin + entry.Position
		local facing = MapKit.Facing(center, entry.Facing)
		local board = MapKit.Part(parent, Vector3.new(width, height, 1.2), facing, PANEL, {
			Solid = true,
			Shadow = true,
			Name = "Board_" .. entry.Stat,
		})
		-- backing frame, posts and a header block
		MapKit.Part(board, Vector3.new(width + 2.4, height + 2.4, 1), facing * CFrame.new(0, 0, 0.6), ctx.Pal.Accent, { Shadow = true, Name = "Backing" })
		for side = -1, 1, 2 do
			local foot = facing * CFrame.new(side * (width / 2 - 2), -height / 2, 0.6)
			local ground = foot.Position.Y - ctx.Origin.Y
			MapKit.Part(board, Vector3.new(1.6, ground + 1, 1.6), foot * CFrame.new(0, -(ground + 1) / 2 + 0.5, 0), ctx.Pal.Stone, { Name = "Post" })
		end
		MapKit.Part(board, Vector3.new(width * 0.5, 3, 1.6), facing * CFrame.new(0, height / 2 + 1.5, 0.3), ctx.Pal.Accent, {
			Material = NEON,
			Name = "Header",
		})

		local gui = MapKit.Surface(board, "Board", Enum.NormalId.Front, 40)
		local bg = Instance.new("Frame")
		bg.Name = "Background"
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = PANEL
		bg.BorderSizePixel = 0
		bg.ZIndex = 0
		MapKit.Gradient(bg, { MapKit.Tint(PANEL, 0.12), MapKit.Shade(PANEL, 0.25) }).Rotation = 90
		bg.Parent = gui
		local title = MapKit.Text(gui, "Title", BOARD_TITLES[entry.Stat] or string.upper(entry.Stat), 0.02, 0.15, GOLD, { StrokeThickness = 4 })
		title.ZIndex = 2
		local list = Instance.new("Frame")
		list.Name = "List"
		list.BackgroundTransparency = 1
		list.Position = UDim2.fromScale(0.05, 0.2)
		list.Size = UDim2.fromScale(0.9, 0.78)
		list.ZIndex = 2
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.FillDirection = Enum.FillDirection.Vertical
		layout.Padding = UDim.new(0.005, 0)
		layout.Parent = list
		local waiting = MapKit.Text(list, "Waiting", "Loading top players...", 0, 0.09, WHITE, { Transparency = 0.35 })
		waiting.LayoutOrder = 0
		list.Parent = gui
	end
end

return MapStations
