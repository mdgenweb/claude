--!nonstrict
-- Spawnable physics props (crates, barrels, balls, planks, anvils, TNT, trampolines).

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local PropsData = require(Shared.Data.Props)

local Systems = script.Parent.Parent.Systems
local World = require(Systems.World)
local Physics2D = require(Systems.Physics2D)

local PropService = {}

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

function PropService:Init(services)
	self.S = services
end

function PropService:Start() end

local function newPart(model: Model, spec: { [string]: any }): Part
	local part = Instance.new("Part")
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in spec do
		(part :: any)[key] = value
	end
	part.Parent = model
	return part
end

local function deco(model: Model, root: BasePart, spec: { [string]: any }): Part
	spec.CanCollide = false
	spec.CanQuery = false
	spec.CanTouch = false
	spec.Massless = true
	local part = newPart(model, spec)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function collider(model: Model, spec: { [string]: any }): Part
	spec.CanCollide = true
	spec.CanQuery = true
	spec.CanTouch = true
	spec.CollisionGroup = "Props"
	return newPart(model, spec)
end

-- Each builder returns root, extraColliders, flags.
local BUILDERS = {}

BUILDERS.crate = function(model: Model, at: CFrame)
	local root = collider(model, { Name = "Crate", Size = Vector3.one * 3.6, CFrame = at * CFrame.new(0, 1.8, 0), Color = Color3.fromRGB(176, 128, 76), Material = Enum.Material.WoodPlanks, CustomPhysicalProperties = PhysicalProperties.new(0.6, 0.6, 0.15, 1, 1) })
	local edge = Color3.fromRGB(110, 74, 44)
	for _, y in { -1.6, 1.6 } do
		deco(model, root, { Name = "Edge", Size = Vector3.new(3.7, 0.4, 3.7), CFrame = root.CFrame * CFrame.new(0, y, 0), Color = edge, Material = Enum.Material.Wood })
	end
	for _, x in { -1.6, 1.6 } do
		deco(model, root, { Name = "Edge", Size = Vector3.new(0.4, 3.7, 3.7), CFrame = root.CFrame * CFrame.new(x, 0, 0), Color = edge, Material = Enum.Material.Wood })
	end
	deco(model, root, { Name = "Brace", Size = Vector3.new(0.35, 4.6, 0.3), CFrame = root.CFrame * CFrame.new(0, 0, 1.85) * CFrame.Angles(0, 0, math.rad(45)), Color = edge, Material = Enum.Material.Wood })
	return root, {}, {}
end

BUILDERS.barrel = function(model: Model, at: CFrame)
	local root = collider(model, { Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4.2, 3.2, 3.2), CFrame = at * CFrame.new(0, 2.1, 0) * UPRIGHT, Color = Color3.fromRGB(200, 44, 40), Material = Enum.Material.Metal, CustomPhysicalProperties = PhysicalProperties.new(0.9, 0.5, 0.2, 1, 1) })
	for _, y in { -1.4, 1.4 } do
		deco(model, root, { Name = "Band", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, 3.35, 3.35), CFrame = root.CFrame * CFrame.new(y, 0, 0), Color = Color3.fromRGB(60, 60, 66), Material = Enum.Material.Metal })
	end
	local symbol = deco(model, root, { Name = "Hazard", Size = Vector3.new(1.3, 1.3, 0.2), CFrame = CFrame.new(root.Position + Vector3.new(0, 0, 1.6)) * CFrame.Angles(0, 0, math.rad(45)), Color = Color3.fromRGB(255, 210, 40), Material = Enum.Material.Neon })
	local _ = symbol
	return root, {}, { explosive = true, blastRadius = 17, blastPower = 1.2, fuse = 0 }
end

BUILDERS.ball = function(model: Model, at: CFrame)
	local root = collider(model, { Name = "BeachBall", Shape = Enum.PartType.Ball, Size = Vector3.one * 3.6, CFrame = at * CFrame.new(0, 1.8, 0), Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.SmoothPlastic, CustomPhysicalProperties = PhysicalProperties.new(0.12, 0.4, 0.85, 1, 100) })
	-- Coloured stripes: thin discs through the centre whose rims poke out of the ball surface.
	local colors = { Color3.fromRGB(255, 70, 80), Color3.fromRGB(70, 160, 255), Color3.fromRGB(255, 210, 60) }
	for i, color in colors do
		deco(model, root, {
			Name = "Stripe",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.7, 3.66, 3.66),
			CFrame = root.CFrame * CFrame.Angles(0, 0, math.rad(i * 60)),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
		})
	end
	return root, {}, {}
end

BUILDERS.plank = function(model: Model, at: CFrame)
	local root = collider(model, { Name = "Plank", Size = Vector3.new(16, 0.9, 2.6), CFrame = at * CFrame.new(0, 0.45, 0), Color = Color3.fromRGB(168, 118, 74), Material = Enum.Material.WoodPlanks, CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.7, 0.1, 1, 1) })
	return root, {}, {}
end

BUILDERS.anvil = function(model: Model, at: CFrame)
	local metal = Color3.fromRGB(64, 66, 76)
	local heavy = PhysicalProperties.new(9, 0.7, 0.02, 1, 1)
	local root = collider(model, { Name = "AnvilTop", Size = Vector3.new(4.2, 1.4, 2.4), CFrame = at * CFrame.new(0, 2.8, 0), Color = metal, Material = Enum.Material.Metal, CustomPhysicalProperties = heavy })
	local base = collider(model, { Name = "AnvilBase", Size = Vector3.new(2.6, 2.1, 2.2), CFrame = at * CFrame.new(0, 1.05, 0), Color = metal, Material = Enum.Material.Metal, CustomPhysicalProperties = heavy })
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = base
	weld.Parent = base
	deco(model, root, { Name = "Horn", Size = Vector3.new(1.8, 0.9, 1.8), CFrame = root.CFrame * CFrame.new(-2.8, 0.2, 0) * CFrame.Angles(0, 0, math.rad(-20)), Color = metal, Material = Enum.Material.Metal })
	return root, { base }, { heavy = true }
end

BUILDERS.bowling = function(model: Model, at: CFrame)
	local root = collider(model, { Name = "BowlingBall", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.8, CFrame = at * CFrame.new(0, 1.4, 0), Color = Color3.fromRGB(40, 60, 170), Material = Enum.Material.SmoothPlastic, Reflectance = 0.25, CustomPhysicalProperties = PhysicalProperties.new(4, 0.3, 0.3, 1, 1) })
	for i, offset in { Vector3.new(-0.35, 0.5, 1.15), Vector3.new(0.35, 0.5, 1.15), Vector3.new(0, -0.1, 1.3) } do
		deco(model, root, { Name = "Hole" .. i, Shape = Enum.PartType.Ball, Size = Vector3.one * 0.45, CFrame = root.CFrame * CFrame.new(offset), Color = Color3.fromRGB(15, 15, 20), Material = Enum.Material.SmoothPlastic })
	end
	return root, {}, {}
end

BUILDERS.tnt = function(model: Model, at: CFrame)
	local root = collider(model, { Name = "TNT", Size = Vector3.one * 2.8, CFrame = at * CFrame.new(0, 1.4, 0), Color = Color3.fromRGB(210, 40, 36), Material = Enum.Material.SmoothPlastic, CustomPhysicalProperties = PhysicalProperties.new(0.9, 0.6, 0.1, 1, 1) })
	deco(model, root, { Name = "Band", Size = Vector3.new(2.9, 0.9, 2.9), CFrame = root.CFrame, Color = Color3.fromRGB(240, 230, 210), Material = Enum.Material.SmoothPlastic })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(120, 40)
	gui.LightInfluence = 0.4
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "TNT"
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(180, 20, 20)
	label.FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
	label.Parent = gui
	local band = model:FindFirstChild("Band")
	gui.Parent = band
	local fuse = deco(model, root, { Name = "Fuse", Size = Vector3.new(0.2, 1, 0.2), CFrame = root.CFrame * CFrame.new(0, 1.9, 0), Color = Color3.fromRGB(60, 50, 40), Material = Enum.Material.Fabric })
	local _ = fuse
	return root, {}, { explosive = true, blastRadius = 19, blastPower = 1.4, fuse = 2.4 }
end

BUILDERS.trampoline = function(model: Model, at: CFrame)
	local frame = collider(model, { Name = "TrampolineFrame", Size = Vector3.new(10, 1.6, 6), CFrame = at * CFrame.new(0, 0.8, 0), Color = Color3.fromRGB(60, 64, 80), Material = Enum.Material.Metal, Anchored = true })
	local top = collider(model, {
		Name = "TrampolineTop",
		Size = Vector3.new(9, 0.4, 5.4),
		CFrame = at * CFrame.new(0, 1.75, 0),
		Color = Color3.fromRGB(80, 180, 255),
		Material = Enum.Material.Rubber,
		Anchored = true,
		CustomPhysicalProperties = PhysicalProperties.new(0.8, 0.3, 1, 1, 100),
	})
	top:SetAttribute("Hazard", "Trampoline")
	top:SetAttribute("LaunchSpeed", 150)
	for _, x in { -4.4, 4.4 } do
		newPart(model, { Name = "Spring", Size = Vector3.new(0.6, 1.4, 0.6), CFrame = at * CFrame.new(x, 1.8, 2.2), Color = Color3.fromRGB(220, 220, 230), Material = Enum.Material.Metal, Anchored = true, CanCollide = false, CanQuery = false })
	end
	return frame, { top }, { static = true }
end

-- ─────────────────────────────── spawning ───────────────────────────────

local function countProps(lab): number
	local n = 0
	for _ in lab.props do
		n += 1
	end
	return n
end

function PropService:Spawn(lab, propId: string, localPos: Vector3, options)
	local opts = options or {}
	local builder = BUILDERS[propId]
	if not builder then
		return nil, "Unknown item"
	end
	if countProps(lab) >= Config.MaxProps then
		return nil, ("Too many items (max %d)"):format(Config.MaxProps)
	end
	local model = Instance.new("Model")
	model.Name = "Prop_" .. propId
	local world = lab.origin + Vector3.new(localPos.X, localPos.Y, 0)
	local at = CFrame.new(world)
	local root, extra, flags = builder(model, at)
	local parts = { root }
	for _, part in extra do
		table.insert(parts, part)
	end
	model.PrimaryPart = root
	model:SetAttribute("PropId", propId)

	local prop: any = {
		kind = "prop",
		id = World.nextId(),
		propId = propId,
		lab = lab,
		model = model,
		root = root,
		parts = parts,
		static = flags.static == true,
		explosive = flags.explosive == true,
		blastRadius = flags.blastRadius,
		blastPower = flags.blastPower,
		fuseTime = flags.fuse,
		fuse = nil,
		prevVel = nil,
		lastActor = opts.source,
		lastActorTime = if opts.source then os.clock() else 0,
		mods = { gravity = {} },
		statuses = {},
	}
	model.Parent = lab.dynamic
	if not prop.static then
		Physics2D.attach(root, lab.planeOrigin, { lockRotation = true, gravity = true })
		self:_refreshGravityFor(prop)
		Physics2D.setOwner(parts, nil)
	else
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
		if self.S.HazardService then
			for _, part in parts do
				if part:GetAttribute("Hazard") then
					self.S.HazardService:RegisterPart(lab, part)
				end
			end
		end
	end
	lab.props[prop.id] = prop
	World.register(prop)
	if lab.paused and not prop.static then
		self.S.LabService:FreezeObject(lab, prop)
	end
	return prop
end

function PropService:SpawnFor(player: Player, lab, propId: string, localPos: Vector3?)
	local info = PropsData.ById[propId]
	local data = self.S.DataService:Get(player)
	if not info or not data then
		return nil
	end
	if data.level < info.unlockLevel then
		self.S.ShopService:Notify(player, "toast", { text = ("%s unlocks at level %d"):format(info.name, info.unlockLevel), kind = "error" })
		return nil
	end
	local position = localPos or Vector3.new(0, 20, 0)
	if propId == "trampoline" then
		-- Snap to the surface below the cursor.
		local hit = Workspace:Raycast(lab.origin + Vector3.new(position.X, position.Y + 2, 0), Vector3.new(0, -120, 0), lab.staticRayParams)
		if not hit then
			return nil
		end
		position = Vector3.new(position.X, hit.Position.Y - lab.origin.Y, 0)
	end
	local prop, err = self:Spawn(lab, propId, position, { source = player })
	if not prop then
		self.S.ShopService:Notify(player, "toast", { text = err or "Can't place that here", kind = "error" })
		return nil
	end
	lab.lastSpawn = { kind = "prop", id = propId }
	table.insert(lab.spawnHistory, { kind = "prop", ref = prop })
	self.S.LabService:FX(lab, "spawn", { p = prop.root.Position, c = Color3.fromRGB(255, 230, 160) })
	return prop
end

function PropService:Despawn(prop)
	local lab = prop.lab
	if lab.props[prop.id] ~= prop then
		return
	end
	if self.S.GrabService then
		self.S.GrabService:ForceRelease(prop)
	end
	if self.S.HazardService then
		for _, part in prop.parts do
			self.S.HazardService:UnregisterPart(lab, part)
		end
	end
	World.unregister(prop)
	lab.props[prop.id] = nil
	prop.dead = true
	prop.model:Destroy()
end

function PropService:ClearAll(lab)
	for _, prop in table.clone(lab.props) do
		self:Despawn(prop)
	end
end

function PropService:_refreshGravityFor(prop)
	if prop.static then
		return
	end
	local lab = prop.lab
	local scale = lab.map.gravityScale * lab.timeScale * lab.timeScale
	for _, factor in prop.mods.gravity do
		scale *= factor
	end
	Physics2D.setGravityScale(prop.root, scale)
end

function PropService:RefreshGravity(lab)
	for _, prop in lab.props do
		self:_refreshGravityFor(prop)
	end
end

-- Lights a fuse (TNT) or detonates immediately (barrels).
function PropService:Ignite(prop, source: Player?)
	if not prop.explosive or prop.dead or prop.fuse then
		return
	end
	if source then
		prop.lastActor = source
		prop.lastActorTime = os.clock()
	end
	if (prop.fuseTime or 0) <= 0 then
		self:Explode(prop)
		return
	end
	prop.fuse = prop.fuseTime
	local spark = Instance.new("ParticleEmitter")
	spark.Texture = "rbxasset://textures/particles/fire_sparks_main.dds"
	spark.Rate = 40
	spark.Lifetime = NumberRange.new(0.2, 0.4)
	spark.Speed = NumberRange.new(4, 8)
	spark.SpreadAngle = Vector2.new(60, 60)
	spark.LightEmission = 1
	spark.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120))
	spark.Size = NumberSequence.new(0.3, 0)
	spark.Parent = prop.model:FindFirstChild("Fuse") or prop.root
	local light = Instance.new("PointLight")
	light.Name = "FuseLight"
	light.Color = Color3.fromRGB(255, 160, 60)
	light.Range = 10
	light.Brightness = 2
	light.Parent = prop.root
	self.S.LabService:FX(prop.lab, "fuse", { p = prop.root.Position })
end

function PropService:Explode(prop)
	if prop.dead then
		return
	end
	local lab = prop.lab
	local position = prop.root.Position
	local source = if prop.lastActor and os.clock() - prop.lastActorTime < Config.Economy.ChaosAttributionWindow then prop.lastActor else nil
	self:Despawn(prop)
	if self.S.EffectsService then
		self.S.EffectsService:Explosion(lab, position, prop.blastRadius or 16, prop.blastPower or 1, { source = source, color = Color3.fromRGB(255, 140, 50) })
	end
end

function PropService:Update(lab, dt: number, labDt: number)
	if lab.paused then
		return
	end
	local ts = math.max(lab.timeScale, 0.05)
	for _, prop in table.clone(lab.props) do
		if prop.dead or prop.static then
			continue
		end
		local root = prop.root
		if not root.Parent then
			self:Despawn(prop)
			continue
		end
		-- Explosives react to hard knocks.
		if prop.explosive and not root.Anchored then
			local v = root.AssemblyLinearVelocity
			if prop.prevVel then
				local dv = (v - prop.prevVel).Magnitude / ts
				if dv > 75 then
					self:Ignite(prop, prop.lastActor)
				end
			end
			prop.prevVel = v
		end
		if prop.fuse then
			prop.fuse -= labDt
			local light = root:FindFirstChild("FuseLight")
			if light then
				light.Enabled = math.floor(prop.fuse * 8) % 2 == 0
			end
			if prop.fuse <= 0 then
				self:Explode(prop)
				continue
			end
		end
		-- Out of bounds cleanup.
		local p = root.Position - lab.origin
		if p ~= p or p.X < lab.minX - 30 or p.X > lab.maxX + 30 or p.Y < -40 or p.Y > lab.map.height + 40 then
			self:Despawn(prop)
		end
	end
end

-- Props within a radius (used by explosions, black holes, magnets...).
function PropService:InRadius(lab, position: Vector3, radius: number)
	local list = {}
	for _, prop in lab.props do
		if not prop.dead and not prop.static and prop.root.Parent then
			if (prop.root.Position - position).Magnitude <= radius then
				table.insert(list, prop)
			end
		end
	end
	return list
end

return PropService
