--!nonstrict
-- Map hazards driven by part attributes set in the map builders:
--   Lava, Bumper, Trampoline, Crusher (physics piston), Conveyor, Fan (updraft zone), Tesla, Icicle.

local Workspace = game:GetService("Workspace")

local Systems = script.Parent.Parent.Systems
local World = require(Systems.World)
local Physics2D = require(Systems.Physics2D)

local HazardService = {}

local function rand(a: number, b: number): number
	return a + math.random() * (b - a)
end

function HazardService:Init(services)
	self.S = services
	self._labs = {}
end

function HazardService:Start() end

local function objectOf(part: BasePart)
	return World.objectFromPart(part)
end

local function cooldownOk(store, key, seconds: number): boolean
	local now = os.clock()
	if (store[key] or 0) > now then
		return false
	end
	store[key] = now + seconds
	return true
end

-- ─────────────────────────────── registration ───────────────────────────────

function HazardService:RegisterLab(lab)
	local state = {
		lab = lab,
		connections = {},
		crushers = {},
		fans = {},
		teslas = {},
		icicles = {},
		conveyors = {},
		cooldowns = {},
		fanTimer = 0,
		icicleTimer = rand(6, 10),
	}
	self._labs[lab] = state
	for _, part in lab.room:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("Hazard") then
			self:_register(state, part)
		end
	end
end

function HazardService:RegisterPart(lab, part: BasePart)
	local state = self._labs[lab]
	if state then
		self:_register(state, part)
	end
end

function HazardService:UnregisterPart(lab, part: BasePart)
	local state = self._labs[lab]
	if not state then
		return
	end
	local conn = state.connections[part]
	if conn then
		conn:Disconnect()
		state.connections[part] = nil
	end
end

function HazardService:UnregisterLab(lab)
	local state = self._labs[lab]
	if not state then
		return
	end
	for _, conn in state.connections do
		conn:Disconnect()
	end
	self._labs[lab] = nil
end

function HazardService:_register(state, part: BasePart)
	local kind = part:GetAttribute("Hazard")
	local lab = state.lab
	if kind == "Lava" then
		part.CanTouch = true
		state.connections[part] = part.Touched:Connect(function(other)
			self:_lavaTouch(state, other)
		end)
	elseif kind == "Bumper" then
		part.CanTouch = true
		state.connections[part] = part.Touched:Connect(function(other)
			self:_bumperTouch(state, part, other)
		end)
	elseif kind == "Trampoline" then
		part.CanTouch = true
		state.connections[part] = part.Touched:Connect(function(other)
			self:_trampolineTouch(state, part, other)
		end)
	elseif kind == "Crusher" then
		self:_setupCrusher(state, part)
	elseif kind == "Conveyor" then
		table.insert(state.conveyors, { part = part, base = part.AssemblyLinearVelocity })
	elseif kind == "Fan" then
		table.insert(state.fans, part)
	elseif kind == "Tesla" then
		table.insert(
			state.teslas,
			{ part = part, timer = rand(1, (part:GetAttribute("TeslaInterval") :: number?) or 3) }
		)
	elseif kind == "Icicle" then
		part.CanTouch = true
		local record = { part = part, template = part:Clone(), cframe = part.CFrame, falling = false }
		table.insert(state.icicles, record)
		state.connections[part] = part.Touched:Connect(function(other)
			if not record.falling then
				local object = objectOf(other)
				if object then
					self:_dropIcicle(state, record)
				end
			end
		end)
	end
	local _ = lab
end

-- ─────────────────────────────── touch hazards ───────────────────────────────

function HazardService:_lavaTouch(state, other: BasePart)
	local object = objectOf(other)
	if not object or object.dead then
		return
	end
	local lab = state.lab
	if not cooldownOk(state.cooldowns, object, 0.45) then
		return
	end
	local E = self.S.EffectsService
	if object.kind == "golem" then
		E:ApplyStatus(object, "burning", { duration = 5 })
		self.S.GolemService:Damage(object, 8, { position = other.Position, kind = "lava" })
		self.S.GolemService:Stun(object, 1.5)
		E:Kick(object, Vector3.new(rand(-12, 12), 70 * lab.timeScale, 0))
		self.S.LabService:FXU(lab, "lavasplash", { p = other.Position })
	elseif object.kind == "prop" then
		if object.explosive then
			self.S.PropService:Ignite(object, nil)
		else
			E:Kick(object, Vector3.new(0, 45 * lab.timeScale, 0))
		end
	end
end

function HazardService:_bumperTouch(state, bumper: BasePart, other: BasePart)
	local object = objectOf(other)
	if not object or object.dead then
		return
	end
	if not cooldownOk(state.cooldowns, object, 0.25) then
		return
	end
	local lab = state.lab
	local offset = other.Position - bumper.Position
	local dir = Vector3.new(offset.X, offset.Y, 0)
	dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.yAxis
	local force = bumper:GetAttribute("BumperForce") or 120
	self.S.EffectsService:Kick(object, dir * force * lab.timeScale)
	if object.kind == "golem" then
		self.S.GolemService:Stun(object, 1.2)
		self.S.GolemService:Damage(object, 4, { position = other.Position, kind = "bumper" })
	end
	self.S.LabService:FXU(lab, "bumper", { p = bumper.Position, c = bumper.Color })
end

function HazardService:_trampolineTouch(state, pad: BasePart, other: BasePart)
	local object = objectOf(other)
	if not object or object.dead then
		return
	end
	if other.Position.Y < pad.Position.Y then
		return
	end
	if not cooldownOk(state.cooldowns, object, 0.45) then
		return
	end
	local lab = state.lab
	local speed = pad:GetAttribute("LaunchSpeed") or 140
	self.S.EffectsService:Kick(object, Vector3.new(rand(-6, 6), speed * lab.timeScale, 0))
	if object.kind == "golem" then
		self.S.GolemService:Stun(object, 1.2)
	end
	self.S.LabService:FXU(lab, "boing", { p = pad.Position })
end

-- ─────────────────────────────── crushers (physics pistons) ───────────────────────────────

function HazardService:_setupCrusher(state, head: BasePart)
	local lab = state.lab
	local index = head:GetAttribute("CrusherIndex")
	local topY = head:GetAttribute("TopY") or 40
	local bottomY = head:GetAttribute("BottomY") or 3
	local travel = topY - bottomY
	-- Weld decoration children to the head.
	local container = head.Parent
	if container then
		for _, child in container:GetChildren() do
			if child:IsA("BasePart") and child ~= head and child:GetAttribute("CrusherChild") == index then
				child.Anchored = false
				child.CanCollide = false
				child.Massless = true
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = head
				weld.Part1 = child
				weld.Parent = child
			end
		end
	end
	local anchor = Instance.new("Part")
	anchor.Name = "CrusherAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(head.Position)
	anchor.Parent = head.Parent
	local a0 = Instance.new("Attachment")
	a0.CFrame = Physics2D.UpRotation
	a0.Parent = anchor
	local a1 = Instance.new("Attachment")
	a1.CFrame = head.CFrame:ToObjectSpace(CFrame.new(head.Position) * Physics2D.UpRotation)
	a1.Parent = head
	local slider = Instance.new("PrismaticConstraint")
	slider.Attachment0 = a0
	slider.Attachment1 = a1
	slider.LimitsEnabled = true
	slider.LowerLimit = -travel
	slider.UpperLimit = 0
	slider.ActuatorType = Enum.ActuatorType.Servo
	slider.ServoMaxForce = 5e7
	slider.Speed = 12
	slider.TargetPosition = 0
	slider.LinearResponsiveness = 120
	slider.Parent = head
	head.CustomPhysicalProperties = PhysicalProperties.new(20, 0.5, 0, 1, 1)
	head.Anchored = false
	head.CanTouch = true
	pcall(head.SetNetworkOwner, head, nil)

	local crusher = {
		head = head,
		slider = slider,
		travel = travel,
		period = head:GetAttribute("Period") or 3.4,
		phase = head:GetAttribute("Phase") or 0,
		t = 0,
		down = false,
	}
	table.insert(state.crushers, crusher)
	state.connections[head] = head.Touched:Connect(function(other)
		if not crusher.down then
			return
		end
		local object = objectOf(other)
		if not object or object.dead then
			return
		end
		if not cooldownOk(state.cooldowns, object, 0.6) then
			return
		end
		if object.kind == "golem" then
			self.S.GolemService:Damage(object, 30, { position = other.Position, kind = "crush" })
			self.S.GolemService:Stun(object, 2)
			self.S.LabService:FX(lab, "crush", { p = other.Position })
			if object.statuses.frozen or object.statuses.golden then
				self.S.EffectsService:Shatter(
					object,
					if object.statuses.golden then "gold" else "ice",
					nil,
					head.Position
				)
			end
		elseif object.kind == "prop" then
			if object.explosive then
				self.S.PropService:Explode(object)
			elseif object.propId == "crate" then
				self.S.LabService:FX(lab, "splinter", { p = object.root.Position })
				self.S.PropService:Despawn(object)
			end
		end
	end)
end

-- ─────────────────────────────── icicles ───────────────────────────────

function HazardService:_dropIcicle(state, record)
	if record.falling or not record.part.Parent then
		return
	end
	local lab = state.lab
	record.falling = true
	local part = record.part
	part.Anchored = false
	part.CollisionGroup = "Props"
	Physics2D.attach(part, lab.planeOrigin, { lockRotation = true, gravity = false })
	pcall(part.SetNetworkOwner, part, nil)
	self.S.LabService:FXU(lab, "crack", { p = part.Position })
	local hitConn
	hitConn = part.Touched:Connect(function(other)
		local object = objectOf(other)
		if object and object.kind == "golem" and part.AssemblyLinearVelocity.Magnitude > 20 then
			hitConn:Disconnect()
			self.S.GolemService:Damage(object, 22, { position = part.Position, kind = "icicle" })
			self.S.EffectsService:ApplyStatus(object, "frozen", { duration = 3 })
			self.S.LabService:FX(lab, "shatter", { p = part.Position, kind = "ice", c = part.Color, small = true })
			part:Destroy()
		end
	end)
	task.delay(2.5, function()
		if hitConn.Connected then
			hitConn:Disconnect()
		end
		if part.Parent then
			self.S.LabService:FX(lab, "shatter", { p = part.Position, kind = "ice", c = part.Color, small = true })
			part:Destroy()
		end
	end)
	task.delay(10, function()
		if lab.destroyed or not self._labs[lab] or state ~= self._labs[lab] then
			return
		end
		local fresh = record.template:Clone()
		fresh.CFrame = record.cframe
		fresh.Parent = lab.room:FindFirstChild("Hazards") or lab.room
		record.part = fresh
		record.falling = false
		state.connections[fresh] = fresh.Touched:Connect(function(other)
			if not record.falling and objectOf(other) then
				self:_dropIcicle(state, record)
			end
		end)
	end)
end

-- ─────────────────────────────── per-frame ───────────────────────────────

function HazardService:Update(lab, dt: number, labDt: number)
	local state = self._labs[lab]
	if not state then
		return
	end
	local ts = lab.timeScale

	-- Crushers: wait at the top, slam down fast, rise slowly. Paused labs freeze them.
	for _, crusher in state.crushers do
		local head = crusher.head
		if not head.Parent then
			continue
		end
		if lab.paused then
			if not head.Anchored then
				head.Anchored = true
			end
			continue
		elseif head.Anchored then
			head.Anchored = false
		end
		crusher.t += labDt
		local cycle = (crusher.t + crusher.phase) % crusher.period
		local wantDown = cycle > crusher.period * 0.55 and cycle < crusher.period * 0.72
		if wantDown ~= crusher.down then
			crusher.down = wantDown
			crusher.slider.TargetPosition = if wantDown then -crusher.travel else 0
			crusher.slider.Speed = (if wantDown then 85 else 14) * ts
			if wantDown then
				self.S.LabService:FX(lab, "crusherslam", { p = head.Position })
			end
		end
	end

	-- Conveyors follow the lab's time scale.
	for _, conveyor in state.conveyors do
		local target = conveyor.base * (if lab.paused then 0 else ts)
		if (conveyor.part.AssemblyLinearVelocity - target).Magnitude > 0.01 then
			conveyor.part.AssemblyLinearVelocity = target
		end
	end

	if labDt <= 0 then
		return
	end

	-- Updraft fans.
	state.fanTimer -= labDt
	if state.fanTimer <= 0 and #state.fans > 0 then
		local step = 0.1 - state.fanTimer
		state.fanTimer = 0.1
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { lab.dynamic }
		for _, zone in state.fans do
			local seen = {}
			for _, part in Workspace:GetPartBoundsInBox(zone.CFrame, zone.Size, params) do
				local object = objectOf(part)
				if object and not seen[object] then
					seen[object] = true
					local accel = zone:GetAttribute("FanAccel") or 300
					self.S.EffectsService:Pull(object, Vector3.new(0, accel * step, 0))
					if object.kind == "golem" then
						self.S.GolemService:Stun(object, 1)
					end
				end
			end
		end
	end

	-- Tesla coils.
	for _, tesla in state.teslas do
		tesla.timer -= labDt
		if tesla.timer <= 0 then
			tesla.timer = (tesla.part:GetAttribute("TeslaInterval") or 3) * rand(0.8, 1.3)
			local range = tesla.part:GetAttribute("TeslaRange") or 30
			local from = tesla.part.Position
			local target = self.S.GolemService:Nearest(lab, from, range)
			if target then
				local to = target.byName.Torso.Position
				self.S.EffectsService:Lightning(lab, from, to)
				self.S.EffectsService:ApplyStatus(target, "shocked", { duration = 2.5, chained = false })
			else
				local miss = from + Vector3.new(rand(-14, 14), rand(-16, -6), 0)
				self.S.EffectsService:Lightning(lab, from, miss)
			end
		end
	end

	-- Random icicle drops keep the cavern lively.
	if #state.icicles > 0 then
		state.icicleTimer -= labDt
		if state.icicleTimer <= 0 then
			state.icicleTimer = rand(7, 13)
			local record = state.icicles[math.random(1, #state.icicles)]
			self:_dropIcicle(state, record)
		end
	end
	local _ = dt
end

return HazardService
