--!nonstrict
-- Golem lifecycle and behaviour: spawning, the stand/stun/get-up/KO state machine, impact damage,
-- airtime/height tracking, pose servos, reforming (healing), scaling and dismemberment.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Skins = require(Shared.Data.Skins)

local Systems = script.Parent.Parent.Systems
local World = require(Systems.World)
local Physics2D = require(Systems.Physics2D)
local GolemFactory = require(Systems.GolemFactory)

local P = Config.Physics
local GolemService = {}

-- Rest pose (degrees). Positive = counter-clockwise from the camera.
local REST_POSE = {
	Neck = 0,
	ShoulderL = -10,
	ShoulderR = 10,
	ElbowL = 12,
	ElbowR = -12,
	HipL = -4,
	HipR = 4,
	KneeL = 0,
	KneeR = 0,
}
GolemService.RestPose = REST_POSE

local KIND_TORQUE = {
	neck = 0.35,
	shoulder = 0.12,
	elbow = 0.08,
	hip = 1,
	knee = 0.9,
}

function GolemService:Init(services)
	self.S = services
end

function GolemService:Start() end

-- ─────────────────────────────── helpers ───────────────────────────────

local function countGolems(lab): number
	local n = 0
	for _ in lab.golems do
		n += 1
	end
	return n
end
GolemService.Count = countGolems

local function allocateGroup(lab): number?
	for i = 1, Config.MaxGolemsExpanded do
		if not lab.groupUsed[i] then
			lab.groupUsed[i] = true
			return i
		end
	end
	return nil
end

function GolemService:Attribution(golem): Player?
	local now = os.clock()
	local window = Config.Economy.ChaosAttributionWindow
	if golem.lastActor and golem.lastActor.Parent and now - golem.lastActorTime < window then
		return golem.lastActor
	end
	local lab = golem.lab
	if lab.lastActor and lab.lastActor.Parent and now - lab.lastActionTime < window then
		return lab.lastActor
	end
	return nil
end

function GolemService:Touch(golem, player: Player?)
	if player then
		golem.lastActor = player
		golem.lastActorTime = os.clock()
	end
end

local function setFace(golem, mode: string)
	if golem.face == mode then
		return
	end
	golem.face = mode
	local ko = mode == "ko"
	for _, part in golem.model:GetChildren() do
		if part.Name == "KOMark" then
			part.Transparency = if ko then 0 else 1
		elseif part.Name == "EyeL" or part.Name == "EyeR" or part.Name == "PupilL" or part.Name == "PupilR" then
			part.Transparency = if ko then 1 else 0
		end
	end
	local mouth = golem.faces.Mouth
	if mouth and mouth.Parent then
		if mode == "ko" or mode == "hurt" then
			mouth.Size = Vector3.new(0.5, 0.32, 0.14)
		elseif mode == "happy" then
			mouth.Size = Vector3.new(0.8, 0.18, 0.14)
		else
			mouth.Size = Vector3.new(0.6, 0.14, 0.14)
		end
	end
	golem.model:SetAttribute("Face", mode)
end
GolemService.SetFace = setFace

local function isActive(golem): boolean
	return golem.state == "standing"
		or golem.state == "gettingup"
		or (golem.state == "controlled" and not golem.controllerStunned)
end

-- Pushes servo/motor settings to the hinges according to state, pose and modifiers.
function GolemService:ApplyActuators(golem, force: boolean?)
	local massFactor = golem.mass * golem.scale
	local g = Workspace.Gravity
	local ts = golem.lab.timeScale
	local ts2 = ts * ts
	if golem.rigid then
		for name, hinge in golem.joints do
			if hinge.Parent then
				hinge.ActuatorType = Enum.ActuatorType.Servo
				hinge.TargetAngle = golem.rigidPose[name] or hinge.CurrentAngle
				hinge.ServoMaxTorque = 1e7
				hinge.AngularSpeed = 20
			end
		end
		return
	end
	local active = isActive(golem) and next(golem.mods.limp) == nil
	for name, hinge in golem.joints do
		if not hinge.Parent then
			continue
		end
		local kind = hinge:GetAttribute("Kind")
		if active then
			local target = golem.pose[name] or REST_POSE[name] or 0
			local torque = massFactor * P.LegServoTorquePerMass * (KIND_TORQUE[kind] or 0.2) * golem.poseStrength * ts2
			if kind == "shoulder" or kind == "elbow" then
				-- Arms are light: a gentler servo so they swing on impacts but hold a pose.
				torque = massFactor
					* P.ArmServoTorquePerMass
					* 40
					* (KIND_TORQUE[kind] or 0.1)
					* (golem.armStrength or 1)
					* ts2
			end
			if hinge.ActuatorType ~= Enum.ActuatorType.Servo then
				hinge.ActuatorType = Enum.ActuatorType.Servo
			end
			if force or math.abs(hinge.TargetAngle - target) > 1.5 then
				hinge.TargetAngle = target
			end
			hinge.ServoMaxTorque = torque
			hinge.AngularSpeed = (golem.poseSpeed or 7) * ts
			hinge.AngularResponsiveness = 40
		else
			if hinge.ActuatorType ~= Enum.ActuatorType.Motor then
				hinge.ActuatorType = Enum.ActuatorType.Motor
			end
			hinge.AngularVelocity = 0
			-- Joint friction: a fraction of the child limb's own gravity torque, so limbs still dangle.
			local child = hinge.Attachment1 and hinge.Attachment1.Parent
			local childMass = if child and child:IsA("BasePart") then child:GetMass() else 1
			hinge.MotorMaxTorque = childMass * g * ts2 * 0.45 * golem.scale * (golem.limpFriction or 1)
		end
	end
end

function GolemService:SetPose(golem, pose: { [string]: number }?, strength: number?, speed: number?)
	golem.pose = pose or REST_POSE
	golem.poseStrength = strength or 1
	golem.poseSpeed = speed or 7
	if isActive(golem) then
		self:ApplyActuators(golem)
	end
end

function GolemService:SetState(golem, state: string)
	if golem.state == state then
		return
	end
	if golem.state == "ko" and state ~= "standing" and state ~= "gettingup" then
		-- KO golems only leave KO by healing.
		if not golem.reviving then
			return
		end
	end
	golem.state = state
	golem.stateTime = 0
	golem.model:SetAttribute("State", state)
	if state == "ko" then
		setFace(golem, "ko")
	elseif state == "stunned" then
		setFace(golem, "hurt")
	else
		setFace(golem, if golem.mods.happy then "happy" else "normal")
	end
	self:ApplyActuators(golem, true)
	self:_updateUpright(golem)
end

function GolemService:_updateUpright(golem)
	local upright = golem.upright
	if not upright or not upright.Parent then
		return
	end
	local wants = (
		golem.state == "standing"
		or golem.state == "gettingup"
		or (golem.state == "controlled" and golem.controllerUpright and not golem.controllerStunned)
	)
		and not golem.rigid
		and next(golem.mods.noUpright) == nil
		and next(golem.mods.limp) == nil
		and not golem.grabbedBy
		and not golem.detached.Neck
	upright.Enabled = wants
	local ts = golem.lab.timeScale
	local ramp = 1
	if golem.state == "gettingup" then
		ramp = math.clamp(golem.stateTime / P.GetUpTime, 0.25, 1)
	end
	-- Torque ∝ total mass × lever arm (∝ scale).
	upright.MaxTorque = golem.mass
		* golem.scale
		* P.UprightTorquePerMass
		* ramp
		* ts
		* ts
		* (golem.uprightStrength or 1)
	upright.Responsiveness = 30 * ts
end

-- Total gravity multiplier for a golem (map × modifiers × slow-mo²).
function GolemService:GravityScale(golem): number
	local scale = golem.lab.map.gravityScale
	for _, factor in golem.mods.gravity do
		scale *= factor
	end
	local ts = golem.lab.timeScale
	return scale * ts * ts
end

function GolemService:RefreshGravity(golem)
	local scale = self:GravityScale(golem)
	golem.gravityScale = scale
	for _, part in golem.parts do
		if part.Parent and not part.Anchored then
			Physics2D.setGravityScale(part, scale)
		end
	end
end

function GolemService:ResetMotionHistory(golem, grace: number?)
	table.clear(golem.prevVel)
	golem.impactGrace = math.max(golem.impactGrace or 0, grace or 0.2)
end

-- ─────────────────────────────── spawning ───────────────────────────────

function GolemService:Spawn(lab, skinId: string?, localPos: Vector3?, options)
	local opts = options or {}
	local cap = lab.maxGolems
	if countGolems(lab) >= cap then
		return nil, ("Too many golems (max %d)"):format(cap)
	end
	local groupIndex = allocateGroup(lab)
	if not groupIndex then
		return nil, "No collision group available"
	end
	local skin = Skins.get(skinId)
	local spot = localPos or lab.layout.spawn
	local feet = lab.origin + Vector3.new(spot.X, spot.Y, 0)
	local result = GolemFactory.build(skin.id, feet, lab.planeOrigin, Physics2D.GolemGroups[groupIndex], lab.dynamic)

	local golem: any = {
		kind = "golem",
		id = opts.id or World.nextId(),
		lab = lab,
		skin = skin,
		groupIndex = groupIndex,
		maxHealth = Config.Golem.MaxHealth,
		health = Config.Golem.MaxHealth,
		state = "none",
		stateTime = 0,
		statuses = {},
		mods = { gravity = {}, noUpright = {}, limp = {}, damage = {} },
		prevVel = {},
		impactGrace = 0.4,
		grounded = true,
		airTime = 0,
		flightMaxHeight = 0,
		lastHeightEmit = 0,
		scale = 1,
		detached = {},
		rigid = false,
		rigidPose = {},
		pose = REST_POSE,
		poseStrength = 1,
		poseSpeed = 7,
		lastActor = opts.source,
		lastActorTime = if opts.source then os.clock() else 0,
		lastImpactFx = 0,
		checkTimer = 0,
		gravityTimer = 0,
		gravityScale = 1,
		spawnTime = os.clock(),
	}
	self:_adoptBuild(golem, result)
	lab.golems[golem.id] = golem
	World.register(golem)
	self:SetState(golem, "standing")
	self:RefreshGravity(golem)
	Physics2D.setOwner(golem.parts, nil)
	if lab.paused then
		self.S.LabService:FreezeObject(lab, golem)
	end
	return golem
end

function GolemService:_adoptBuild(golem, result)
	golem.model = result.model
	golem.parts = result.physical
	golem.byName = result.parts
	golem.joints = result.joints
	golem.upright = result.upright
	golem.lift = result.lift
	golem.mass = result.mass
	golem.baseMass = result.mass
	golem.faces = result.faces
	golem.face = nil
	golem.model:SetAttribute("GolemId", golem.id)
	golem.model:SetAttribute("Health", golem.health)
	golem.model:SetAttribute("MaxHealth", golem.maxHealth)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { golem.model }
	params.RespectCanCollide = true
	golem.rayParams = params
end

function GolemService:Despawn(golem)
	local lab = golem.lab
	if lab.golems[golem.id] ~= golem then
		return
	end
	if self.S.EffectsService then
		self.S.EffectsService:ClearAll(golem, true)
	end
	if golem.grabbedBy and self.S.GrabService then
		self.S.GrabService:ForceRelease(golem)
	end
	World.unregister(golem)
	lab.golems[golem.id] = nil
	lab.groupUsed[golem.groupIndex] = nil
	golem.dead = true
	if golem.model then
		golem.model:Destroy()
	end
end

-- Heal = rebuild the golem fresh where it currently is (keeps id, skin and group).
function GolemService:Reform(golem, options)
	local opts = options or {}
	if golem.dead then
		return
	end
	local lab = golem.lab
	if golem.grabbedBy and self.S.GrabService then
		self.S.GrabService:ForceRelease(golem)
	end
	if self.S.EffectsService then
		self.S.EffectsService:ClearAll(golem, true)
	end
	local torso = golem.byName.Torso
	local at = if torso and torso.Parent then torso.Position else lab.origin + lab.layout.spawn
	-- Find the ground under the golem.
	local hit = Workspace:Raycast(at + Vector3.new(0, 2, 0), Vector3.new(0, -60, 0), lab.staticRayParams)
	local feetY = if hit then hit.Position.Y + 0.05 else at.Y - 4.6
	local localX = math.clamp(at.X - lab.origin.X, lab.minX + 4, lab.maxX - 4)
	local localY = math.clamp(feetY - lab.origin.Y, 0, lab.map.height - 10)
	if opts.toSpawn then
		localX, localY = lab.layout.spawn.X, lab.layout.spawn.Y
	end

	World.unregister(golem)
	golem.model:Destroy()
	golem.health = golem.maxHealth
	golem.scale = 1
	golem.rigid = false
	golem.rigidPose = {}
	golem.detached = {}
	golem.statuses = {}
	golem.mods = { gravity = {}, noUpright = {}, limp = {}, damage = {} }
	golem.controller = nil
	golem.controllerUpright = nil
	golem.pose = REST_POSE
	golem.poseStrength = 1
	golem.uprightStrength = nil
	golem.armStrength = nil
	golem.limpFriction = nil
	table.clear(golem.prevVel)
	golem.impactGrace = 0.5
	golem.airTime = 0
	golem.flightMaxHeight = 0
	golem.state = "none"
	golem.reviving = true

	local feet = lab.origin + Vector3.new(localX, localY, 0)
	local result =
		GolemFactory.build(golem.skin.id, feet, lab.planeOrigin, Physics2D.GolemGroups[golem.groupIndex], lab.dynamic)
	self:_adoptBuild(golem, result)
	World.register(golem)
	self:SetState(golem, "standing")
	golem.reviving = nil
	self:RefreshGravity(golem)
	Physics2D.setOwner(golem.parts, nil)
	if lab.paused then
		self.S.LabService:FreezeObject(lab, golem)
	end
	if not opts.silent then
		self.S.LabService:FX(lab, "reform", { p = feet + Vector3.new(0, 4.5, 0), c = golem.skin.accent })
	end
	return golem
end

-- ─────────────────────────────── damage ───────────────────────────────

function GolemService:Damage(golem, amount: number, options)
	local info = options or {}
	if golem.dead or amount <= 0 then
		return 0
	end
	for _, factor in golem.mods.damage do
		amount *= factor
	end
	if amount < 0.5 then
		return 0
	end
	amount = math.floor(amount + 0.5)
	local wasAlive = golem.health > 0
	golem.health = math.max(0, golem.health - amount)
	golem.model:SetAttribute("Health", golem.health)

	local actor = info.source or self:Attribution(golem)
	local position = info.position or (golem.byName.Torso and golem.byName.Torso.Position)
	if position and not info.silent then
		self.S.LabService:FXU(golem.lab, "dmg", { p = position, a = amount, k = info.kind })
	end
	if actor then
		self.S.EconomyService:AddChaos(actor, amount, golem.lab)
		self.S.ChallengeService:Event(actor, "damage", amount)
		local data = self.S.DataService:Get(actor)
		if data then
			data.stats.damage += amount
		end
	end
	if wasAlive and golem.health <= 0 then
		self:SetState(golem, "ko")
		self.S.LabService:FX(golem.lab, "ko", { p = position })
		if actor then
			self.S.EconomyService:AddChaos(actor, 150, golem.lab)
			self.S.ChallengeService:Event(actor, "ko", 1, { golem = golem.id })
			local data = self.S.DataService:Get(actor)
			if data then
				data.stats.kos += 1
			end
		end
	end
	return amount
end

function GolemService:Stun(golem, duration: number?)
	if golem.dead or golem.state == "ko" or golem.rigid then
		return
	end
	if golem.state == "controlled" then
		golem.controllerStunned = math.max(golem.controllerStunned or 0, duration or P.StunTime)
		self:ApplyActuators(golem, true)
		self:_updateUpright(golem)
		return
	end
	self:SetState(golem, "stunned")
	golem.stunDuration = duration or P.StunTime
end

-- ─────────────────────────────── posing / rigid ───────────────────────────────

function GolemService:SetRigid(golem, rigid: boolean)
	if golem.rigid == rigid then
		return
	end
	golem.rigid = rigid
	if rigid then
		for name, hinge in golem.joints do
			golem.rigidPose[name] = hinge.CurrentAngle
		end
	end
	self:ApplyActuators(golem, true)
	self:_updateUpright(golem)
end

function GolemService:Detach(golem, jointName: string, impulse: Vector3?)
	local hinge = golem.joints[jointName]
	if not hinge or golem.detached[jointName] then
		return nil
	end
	local child = hinge.Attachment1 and hinge.Attachment1.Parent
	local pivot = hinge.Attachment0 and hinge.Attachment0.WorldPosition
	hinge:Destroy()
	golem.joints[jointName] = nil
	golem.detached[jointName] = true
	if child and child:IsA("BasePart") then
		-- The freed limb chain needs its own rotation lock now.
		local att = Physics2D.planeAttachment(child)
		local lock = Instance.new("AlignOrientation")
		lock.Name = "Lock2D"
		lock.Mode = Enum.OrientationAlignmentMode.OneAttachment
		lock.AlignType = Enum.AlignType.PrimaryAxisParallel
		lock.Attachment0 = att
		lock.PrimaryAxis = Vector3.zAxis
		lock.RigidityEnabled = true
		lock.Parent = child
		if impulse then
			Physics2D.impulse(child, impulse)
		end
	end
	if pivot then
		self.S.LabService:FX(golem.lab, "pop", { p = pivot, c = golem.skin.limb })
	end
	if jointName == "Neck" or (golem.detached.HipL and golem.detached.HipR) then
		self:Stun(golem, 999)
	end
	self:_updateUpright(golem)
	return child
end

function GolemService:DetachAll(golem, strength: number)
	local torso = golem.byName.Torso
	for name in table.clone(golem.joints) do
		local hinge = golem.joints[name]
		local child = hinge and hinge.Attachment1 and hinge.Attachment1.Parent
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, 0).Unit
		if child and child:IsA("BasePart") and torso then
			local offset = child.Position - torso.Position
			if offset.Magnitude > 0.1 then
				dir = (Vector3.new(offset.X, offset.Y, 0).Unit + Vector3.new(0, 0.6, 0)).Unit
			end
		end
		local mass = if child and child:IsA("BasePart") then child:GetMass() else 1
		self:Detach(golem, name, dir * mass * strength)
	end
	self:Stun(golem, 999)
end

-- Smoothly scales the golem (Model:ScaleTo in small steps so the solver can push out of the floor).
function GolemService:SetScale(golem, target: number, duration: number?)
	golem.scaleTarget = target
	golem.scaleFrom = golem.scale
	golem.scaleT = 0
	golem.scaleDuration = duration or 0.6
end

local function stepScale(self, golem, dt: number)
	if not golem.scaleTarget then
		return
	end
	golem.scaleT += dt
	local alpha = math.clamp(golem.scaleT / golem.scaleDuration, 0, 1)
	local eased = 1 - (1 - alpha) ^ 3
	local scale = golem.scaleFrom + (golem.scaleTarget - golem.scaleFrom) * eased
	if math.abs(scale - golem.scale) > 0.01 or alpha >= 1 then
		local ok = pcall(function()
			golem.model:ScaleTo(scale)
		end)
		if ok then
			golem.scale = scale
			golem.model:SetAttribute("Scale", scale)
			local mass = 0
			for _, part in golem.parts do
				if part.Parent then
					mass += part:GetMass()
				end
			end
			golem.mass = mass -- always the real total mass
			self:RefreshGravity(golem)
			self:ApplyActuators(golem)
			self:_updateUpright(golem)
			self:ResetMotionHistory(golem, 0.15)
		end
	end
	if alpha >= 1 then
		golem.scaleTarget = nil
	end
end

-- ─────────────────────────────── per-frame update ───────────────────────────────

local IMPACT_PARTS = { "Torso", "Head" }

function GolemService:Update(lab, dt: number, labDt: number)
	if lab.paused then
		return
	end
	local g = Workspace.Gravity
	local ts = math.max(lab.timeScale, 0.05)
	for _, golem in lab.golems do
		if golem.dead then
			continue
		end
		local torso: BasePart? = golem.byName.Torso
		if not torso or not torso.Parent then
			continue
		end

		stepScale(self, golem, labDt)

		-- Periodic gravity refresh (mass changes when scaling, statuses change modifiers).
		golem.gravityTimer -= dt
		if golem.gravityTimer <= 0 then
			golem.gravityTimer = 0.25
			self:RefreshGravity(golem)
			self:_updateUpright(golem)
		end

		-- ── Impact detection via Δv against expected gravity ──
		golem.impactGrace = math.max(0, (golem.impactGrace or 0) - dt)
		local expectedDv = Vector3.new(0, -g * golem.gravityScale * dt, 0)
		for _, name in IMPACT_PARTS do
			local part = golem.byName[name]
			if part and part.Parent and not part.Anchored then
				local v = part.AssemblyLinearVelocity
				local prev = golem.prevVel[name]
				golem.prevVel[name] = v
				if prev and golem.impactGrace <= 0 then
					local dv = (v - (prev + expectedDv)).Magnitude / ts
					local threshold = P.ImpactThreshold * (if golem.grabbedBy then 1.9 else 1)
					if dv > threshold then
						self:_onImpact(golem, part, dv, threshold)
					end
				end
			end
		end

		-- ── Ground / airtime / height (20 Hz) ──
		golem.checkTimer -= dt
		if golem.checkTimer <= 0 then
			golem.checkTimer = 0.05
			local down = if golem.gravityScale < 0 then 1 else -1
			local hit = Workspace:Raycast(torso.Position, Vector3.new(0, down * 6.2 * golem.scale, 0), golem.rayParams)
			local wasGrounded = golem.grounded
			golem.grounded = hit ~= nil
			local height = torso.Position.Y - lab.origin.Y
			if not golem.grounded and not golem.grabbedBy then
				golem.flightMaxHeight = math.max(golem.flightMaxHeight, height)
			end
			if golem.grounded and not wasGrounded then
				self:_onLanded(golem)
			end
		end
		if not golem.grounded and not golem.grabbedBy and not torso.Anchored then
			golem.airTime += labDt
			if golem.airTime > 1 and os.clock() - golem.lastHeightEmit > 0.5 then
				golem.lastHeightEmit = os.clock()
				local actor = self:Attribution(golem)
				if actor then
					self.S.ChallengeService:Event(actor, "airtime", golem.airTime)
					self.S.ChallengeService:Event(actor, "height", golem.flightMaxHeight)
				end
			end
		end

		-- ── State machine ──
		golem.stateTime += labDt
		local speed = torso.AssemblyLinearVelocity.Magnitude / ts
		if golem.state == "standing" then
			-- Fell over (pushed hard enough to tip) → stunned.
			if torso.CFrame.UpVector.Y < 0.45 and not golem.rigid then
				self:Stun(golem)
			elseif golem.grabbedBy then
				self:Stun(golem, P.StunTime)
			end
		elseif golem.state == "stunned" then
			local duration = golem.stunDuration or P.StunTime
			if golem.grabbedBy or speed > 9 or not golem.grounded then
				golem.stateTime = math.min(golem.stateTime, duration * 0.6)
			end
			if
				golem.stateTime >= duration
				and golem.health > 0
				and next(golem.mods.limp) == nil
				and not golem.rigid
			then
				if golem.controller then
					self:SetState(golem, "controlled")
				else
					self:SetState(golem, "gettingup")
				end
			end
		elseif golem.state == "gettingup" then
			local lift = golem.lift
			local t = golem.stateTime / P.GetUpTime
			if lift and lift.Parent then
				lift.Enabled = t < 0.6
				lift.Force =
					Vector3.new(0, golem.mass * g * math.max(golem.gravityScale, 0.2) * 1.15 * math.max(0, 1 - t), 0)
			end
			self:_updateUpright(golem)
			if golem.stateTime >= P.GetUpTime then
				if lift then
					lift.Enabled = false
				end
				self:SetState(golem, if golem.controller then "controlled" else "standing")
			end
		elseif golem.state == "controlled" then
			if golem.controllerStunned then
				-- Stay limp while flying around; recover once settled.
				if speed < 12 and golem.grounded then
					golem.controllerStunned -= labDt
				end
				if golem.controllerStunned <= 0 then
					golem.controllerStunned = nil
					self:ApplyActuators(golem, true)
					self:_updateUpright(golem)
				end
			end
			if not golem.controller then
				self:SetState(golem, "standing")
			end
		end
		if golem.state ~= "gettingup" and golem.lift and golem.lift.Enabled then
			golem.lift.Enabled = false
		end

		-- Status-driven behaviour (zombie, hyper, disco...).
		if golem.controller and not golem.grabbedBy and golem.state ~= "ko" and not golem.rigid then
			local ok, err = pcall(golem.controller, golem, dt, labDt)
			if not ok then
				warn("[GolemService] controller error:", err)
				golem.controller = nil
			end
		end

		-- Idle breathing while standing.
		if golem.state == "standing" and not golem.controller then
			local t = os.clock() + golem.id
			local sway = math.sin(t * 1.6) * 4
			local pose = golem.idlePose or table.clone(REST_POSE)
			golem.idlePose = pose
			pose.ShoulderL = REST_POSE.ShoulderL - sway
			pose.ShoulderR = REST_POSE.ShoulderR + sway
			pose.Neck = math.sin(t * 0.7) * 6
			golem.pose = pose
			if math.floor(t * 8) ~= golem.lastIdleTick then
				golem.lastIdleTick = math.floor(t * 8)
				self:ApplyActuators(golem)
			end
		end

		-- ── Safety: velocity clamp and out-of-bounds recovery ──
		if not golem.grabbedBy then
			local v = torso.AssemblyLinearVelocity
			local limit = P.MaxSpeed * ts
			if v.Magnitude > limit then
				for _, part in golem.parts do
					if part.Parent and not part.Anchored then
						local pv = part.AssemblyLinearVelocity
						-- Only rescale parts that are actually too fast (never normalise a zero vector).
						if pv.Magnitude > limit then
							part.AssemblyLinearVelocity = pv.Unit * limit * 0.9
						end
					end
				end
			end
		end
		local p = torso.Position - lab.origin
		if p ~= p or p.X < lab.minX - 30 or p.X > lab.maxX + 30 or p.Y < -40 or p.Y > lab.map.height + 40 then
			self:Reform(golem, { toSpawn = true })
		end
	end
end

function GolemService:_onImpact(golem, part: BasePart, dv: number, threshold: number)
	local lab = golem.lab
	local damage = (dv - threshold) * P.ImpactDamageScale * (if part.Name == "Head" then 1.3 else 1)
	if golem.grabbedBy then
		damage *= 0.6
	end
	if self.S.EffectsService then
		local handled = self.S.EffectsService:OnImpact(golem, part, dv)
		if handled then
			return
		end
	end
	self:Damage(golem, damage, { position = part.Position, kind = "impact", silent = damage < 2 })
	if dv > P.KnockdownThreshold and golem.state == "standing" then
		self:Stun(golem)
	end
	local now = os.clock()
	if now - golem.lastImpactFx > 0.09 then
		golem.lastImpactFx = now
		self.S.LabService:FXU(
			lab,
			"impact",
			{ p = part.Position, s = math.clamp(dv / 120, 0.1, 1.5), c = golem.skin.body }
		)
	end
end

function GolemService:_onLanded(golem)
	local actor = self:Attribution(golem)
	if golem.airTime > 0.6 and actor then
		self.S.ChallengeService:Event(actor, "airtime", golem.airTime)
		self.S.ChallengeService:Event(actor, "height", golem.flightMaxHeight)
		if golem.airTime > 2 then
			self.S.EconomyService:AddChaos(actor, math.floor(golem.airTime * 30), golem.lab)
		end
		local data = self.S.DataService:Get(actor)
		if data and golem.flightMaxHeight > data.stats.maxHeight then
			data.stats.maxHeight = math.floor(golem.flightMaxHeight)
		end
	end
	if golem.scale > 1.8 and golem.airTime > 0.4 then
		self.S.LabService:FX(golem.lab, "quake", { p = golem.byName.Torso.Position, s = golem.scale })
	end
	golem.airTime = 0
	golem.flightMaxHeight = 0
end

function GolemService:HealAll(lab)
	for _, golem in table.clone(lab.golems) do
		self:Reform(golem)
	end
end

function GolemService:ClearAll(lab)
	for _, golem in table.clone(lab.golems) do
		self:Despawn(golem)
	end
end

-- Nearest golem to a world point (optionally filtered).
function GolemService:Nearest(lab, position: Vector3, maxDistance: number, filter: ((any) -> boolean)?)
	local best, bestDistance = nil, maxDistance
	for _, golem in lab.golems do
		local torso = golem.byName.Torso
		if not golem.dead and torso and torso.Parent and (not filter or filter(golem)) then
			local d = (torso.Position - position).Magnitude
			if d < bestDistance then
				best, bestDistance = golem, d
			end
		end
	end
	return best, bestDistance
end

function GolemService:InRadius(lab, position: Vector3, radius: number)
	local list = {}
	for _, golem in lab.golems do
		if golem.dead then
			continue
		end
		local closest = math.huge
		for _, part in golem.parts do
			if part.Parent then
				local d = (part.Position - position).Magnitude
				if d < closest then
					closest = d
				end
			end
		end
		if closest <= radius * math.max(1, golem.scale * 0.6) then
			table.insert(list, golem)
		end
	end
	return list
end

return GolemService
