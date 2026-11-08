--!nonstrict
-- Status effect definitions applied to golems by potions, puddles, hazards and reactions.
-- Each definition may implement: immune(golem), apply(E, golem, st, opts), refresh(...),
-- tick(E, golem, st, dt, labDt), remove(E, golem, st, reason), cleanup(E, golem, st).
-- `E` is the EffectsService; `E.S` gives access to every other service.

local Workspace = game:GetService("Workspace")

local Physics2D = require(script.Parent.Parent.Physics2D)
local World = require(script.Parent.Parent.World)
local Vfx = require(script.Parent.Vfx)

local Statuses = {}

local function rand(a: number, b: number): number
	return a + math.random() * (b - a)
end

local function torsoOf(golem): BasePart?
	local torso = golem.byName and golem.byName.Torso
	if torso and torso.Parent then
		return torso
	end
	return nil
end

local function add(st, instance)
	table.insert(st.instances, instance)
	return instance
end

-- Accumulates fractional damage so per-frame DoT still lands as whole numbers.
local function dot(E, golem, st, perSecond: number, labDt: number, kind: string)
	st.data.dotAcc = (st.data.dotAcc or 0) + perSecond * labDt
	if st.data.dotAcc >= 3 then
		local amount = st.data.dotAcc
		st.data.dotAcc = 0
		E.S.GolemService:Damage(golem, amount, { source = st.source, kind = kind })
	end
end

local function setController(golem, st, fn, upright: boolean?)
	st.data.controller = fn
	golem.controller = fn
	golem.controllerUpright = upright
	if golem.state == "standing" or golem.state == "gettingup" then
		golem.state = "stunned"
		golem.stateTime = 999 -- leave stun immediately → "controlled"
	end
end

local function clearController(E, golem, st)
	if golem.controller == st.data.controller then
		golem.controller = nil
		golem.controllerUpright = nil
		E.S.GolemService:SetPose(golem, nil)
		if golem.state == "controlled" then
			E.S.GolemService:SetState(golem, "standing")
		end
	end
end

local function limbList(golem): { BasePart }
	local list = {}
	for _, name in { "Torso", "Head", "UpperArmL", "UpperArmR", "LowerLegL", "LowerLegR" } do
		local part = golem.byName[name]
		if part and part.Parent then
			table.insert(list, part)
		end
	end
	return list
end

-- ─────────────────────────────── BURNING ───────────────────────────────

local function panicController(golem, _dt, labDt)
	local st = golem.statuses.burning
	if not st then
		return
	end
	st.data.panic = (st.data.panic or 0) - labDt
	if st.data.panic <= 0 and golem.grounded then
		st.data.panic = rand(0.35, 0.6)
		st.data.dir = -(st.data.dir or 1)
		st.E:Kick(golem, Vector3.new(st.data.dir * rand(16, 24), rand(24, 34), 0))
		st.E.S.GolemService:SetPose(golem, {
			ShoulderL = rand(-170, -90),
			ShoulderR = rand(90, 170),
			ElbowL = rand(0, 90),
			ElbowR = rand(-90, 0),
			HipL = rand(-30, 10),
			HipR = rand(-10, 30),
			KneeL = 0,
			KneeR = 0,
			Neck = rand(-20, 20),
		}, 0.7, 12)
	end
end

Statuses.burning = {
	duration = 8,
	immune = function(golem)
		return golem.skin.traits.fireproof == true or golem.statuses.ascension ~= nil
	end,
	apply = function(E, golem, st, opts)
		st.E = E
		local spirit = opts.spirit == true
		st.data.spirit = spirit
		local colors = if spirit
			then ColorSequence.new(Color3.fromRGB(160, 230, 255), Color3.fromRGB(40, 120, 255))
			else ColorSequence.new(Color3.fromRGB(255, 210, 90), Color3.fromRGB(255, 60, 20))
		for _, part in limbList(golem) do
			local big = part.Name == "Torso" or part.Name == "Head"
			add(st, Vfx.emitter(part, "fire", { Rate = if big then 34 else 14, Color = colors }))
		end
		local torso = torsoOf(golem)
		if torso then
			add(st, Vfx.emitter(torso, "embers"))
			add(st, Vfx.emitter(torso, "smoke"))
			add(
				st,
				Vfx.light(
					torso,
					if spirit then Color3.fromRGB(120, 190, 255) else Color3.fromRGB(255, 140, 50),
					14,
					2.2,
					true
				)
			)
		end
		st.data.char = 0
		E:SetLook(golem, "burning", { priority = 20, tint = Color3.fromRGB(28, 18, 18), tintAlpha = 0 })
		golem.model:SetAttribute("Burning", true)
		if not spirit then
			setController(golem, st, panicController, true)
		end
	end,
	tick = function(E, golem, st, _dt, labDt)
		if not st.data.spirit then
			local rate = if golem.skin.traits.melts then 10 else 5
			dot(E, golem, st, rate, labDt, "burn")
			st.data.char = math.min(0.7, st.data.char + labDt * 0.09)
			st.data.lookTimer = (st.data.lookTimer or 0) - labDt
			if st.data.lookTimer <= 0 then
				st.data.lookTimer = 0.5
				E:SetLook(
					golem,
					"burning",
					{ priority = 20, tint = Color3.fromRGB(28, 18, 18), tintAlpha = st.data.char }
				)
			end
		end
		-- Spread to anything touching.
		st.data.spread = (st.data.spread or 0) - labDt
		if st.data.spread <= 0 then
			st.data.spread = 0.4
			local torso = torsoOf(golem)
			if torso then
				for _, other in E.S.GolemService:InRadius(golem.lab, torso.Position, 4.2 * golem.scale) do
					if other ~= golem and not other.statuses.burning then
						E:ApplyStatus(other, "burning", { duration = 6, source = st.source })
					end
				end
				if E.S.PropService then
					for _, prop in E.S.PropService:InRadius(golem.lab, torso.Position, 6 * golem.scale) do
						E.S.PropService:Ignite(prop, st.source)
					end
				end
			end
		end
	end,
	remove = function(E, golem, st)
		E:SetLook(golem, "burning", nil)
		golem.model:SetAttribute("Burning", nil)
		clearController(E, golem, st)
		local torso = torsoOf(golem)
		if torso then
			E.S.LabService:FX(golem.lab, "smokepuff", { p = torso.Position })
		end
	end,
	cleanup = function(_E, golem)
		golem.model:SetAttribute("Burning", nil)
	end,
}

-- ─────────────────────────────── FROZEN ───────────────────────────────

Statuses.frozen = {
	duration = 10,
	immune = function(golem)
		return golem.skin.traits.frostproof == true
	end,
	apply = function(E, golem, st)
		E.S.GolemService:SetRigid(golem, true)
		golem.mods.noUpright.frozen = true
		golem.mods.damage.frozen = 0.5
		E:SetLook(golem, "frozen", {
			priority = 50,
			tint = Color3.fromRGB(175, 232, 255),
			tintAlpha = 0.72,
			material = Enum.Material.Ice,
			reflectance = 0.25,
		})
		E:SetPhys(golem, "frozen", { priority = 50, friction = 0.04, frictionWeight = 100, elasticity = 0.05 })
		local torso = torsoOf(golem)
		if torso then
			add(st, Vfx.emitter(torso, "frost", { Rate = 16 }))
			add(st, Vfx.light(torso, Color3.fromRGB(160, 220, 255), 9, 1))
			E.S.LabService:FX(golem.lab, "freeze", { p = torso.Position })
		end
		st.data.savedController = golem.controller
		golem.controller = nil
	end,
	remove = function(E, golem, st, reason)
		golem.mods.noUpright.frozen = nil
		golem.mods.damage.frozen = nil
		if not golem.statuses.golden then
			E.S.GolemService:SetRigid(golem, false)
		end
		E:SetLook(golem, "frozen", nil)
		E:SetPhys(golem, "frozen", nil)
		if st.data.savedController and golem.controller == nil then
			golem.controller = st.data.savedController
		end
		local torso = torsoOf(golem)
		if torso and reason ~= "shatter" then
			E.S.LabService:FX(golem.lab, "thaw", { p = torso.Position })
		end
	end,
}

-- ─────────────────────────────── LEVITATING ───────────────────────────────

Statuses.levitating = {
	duration = 9,
	apply = function(E, golem, st)
		golem.mods.gravity.levitate = -0.16
		golem.mods.limp.levitate = true
		E:SetDrag(golem, "levitate", 1.1)
		local torso = torsoOf(golem)
		if torso then
			add(st, Vfx.emitter(torso, "float"))
			add(st, Vfx.light(torso, Color3.fromRGB(200, 160, 255), 10, 1.2))
		end
		E:Kick(golem, Vector3.new(0, 14, 0))
	end,
	tick = function(E, golem, st, _dt, labDt)
		st.data.wobble = (st.data.wobble or 0) - labDt
		if st.data.wobble <= 0 then
			st.data.wobble = rand(0.5, 0.9)
			E:Pull(golem, Vector3.new(rand(-5, 5), rand(-1, 3), 0))
		end
	end,
	remove = function(E, golem)
		golem.mods.gravity.levitate = nil
		golem.mods.limp.levitate = nil
		E:SetDrag(golem, "levitate", nil)
	end,
}

-- ─────────────────────────────── BOUNCY ───────────────────────────────

Statuses.bouncy = {
	duration = 12,
	apply = function(E, golem, st)
		E:SetPhys(
			golem,
			"bouncy",
			{ priority = 40, elasticity = 1, elasticityWeight = 100, friction = 0.15, frictionWeight = 50 }
		)
		E:SetLook(
			golem,
			"bouncy",
			{ priority = 15, tint = Color3.fromRGB(110, 240, 120), tintAlpha = 0.35, material = Enum.Material.Rubber }
		)
		golem.mods.limp.bouncy = true
		golem.mods.damage.bouncy = 0.35
		local torso = torsoOf(golem)
		if torso then
			add(st, Vfx.emitter(torso, "slime"))
		end
		E:Kick(golem, Vector3.new(rand(-10, 10), 45, 0))
	end,
	remove = function(E, golem)
		E:SetPhys(golem, "bouncy", nil)
		E:SetLook(golem, "bouncy", nil)
		golem.mods.limp.bouncy = nil
		golem.mods.damage.bouncy = nil
	end,
}

-- ─────────────────────────────── ROCKET ───────────────────────────────

Statuses.rocket = {
	duration = 3.2,
	apply = function(E, golem, st)
		local torso = torsoOf(golem)
		if not torso then
			return
		end
		local s = golem.scale
		local booster = Instance.new("Part")
		booster.Name = "Booster"
		booster.Shape = Enum.PartType.Cylinder
		booster.Size = Vector3.new(4.6 * s, 1.3 * s, 1.3 * s)
		booster.CFrame = torso.CFrame * CFrame.new(0, 0.3 * s, -1.5 * s) * CFrame.Angles(0, 0, math.rad(90))
		booster.Color = Color3.fromRGB(230, 60, 50)
		booster.Material = Enum.Material.Metal
		booster.CanCollide = false
		booster.CanQuery = false
		booster.CanTouch = false
		booster.Massless = true
		booster.Parent = golem.model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = torso
		weld.Part1 = booster
		weld.Parent = booster
		add(st, booster)
		local cone = booster:Clone()
		cone.Name = "BoosterCone"
		cone.Shape = Enum.PartType.Ball
		cone.Size = Vector3.one * 1.3 * s
		cone.CFrame = torso.CFrame * CFrame.new(0, 2.6 * s, -1.5 * s)
		cone.Color = Color3.fromRGB(240, 240, 250)
		cone:ClearAllChildren()
		cone.Parent = golem.model
		local coneWeld = Instance.new("WeldConstraint")
		coneWeld.Part0 = torso
		coneWeld.Part1 = cone
		coneWeld.Parent = cone
		add(st, cone)
		local nozzle = Instance.new("Attachment")
		nozzle.Name = "Nozzle"
		nozzle.CFrame = CFrame.new(0, -2.2 * s, -1.5 * s)
		nozzle.Parent = torso
		add(st, nozzle)
		add(st, Vfx.emitter(nozzle, "thrust"))
		add(st, Vfx.emitter(nozzle, "thrustSmoke"))
		add(st, Vfx.light(booster, Color3.fromRGB(255, 160, 60), 16, 2.5, true))
		local thrust = Instance.new("VectorForce")
		thrust.Name = "Thrust"
		thrust.Attachment0 = torso:FindFirstChild("UprightAtt") :: Attachment
		thrust.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
		thrust.ApplyAtCenterOfMass = true
		thrust.Force = Vector3.zero
		thrust.Parent = torso
		add(st, thrust)
		st.data.thrust = thrust
		golem.mods.limp.rocket = true
		E.S.GolemService:Stun(golem, 4)
		E.S.LabService:FX(golem.lab, "ignite", { p = torso.Position })
	end,
	tick = function(E, golem, st, _dt, labDt)
		local thrust = st.data.thrust
		if not thrust or not thrust.Parent then
			return
		end
		st.data.sputter = (st.data.sputter or 0) - labDt
		if st.data.sputter <= 0 then
			st.data.sputter = 0.1
			st.data.factor = rand(0.8, 1.2)
		end
		local ts = golem.lab.timeScale
		local power = if st.data.overdrive then 4.4 else 2.7
		-- Thrust along the torso's up axis (attachment X axis).
		thrust.Force = Vector3.new(golem.mass * Workspace.Gravity * power * (st.data.factor or 1) * ts * ts, 0, 0)
		dot(E, golem, st, 2, labDt, "rocket")
	end,
	remove = function(E, golem, st, reason)
		golem.mods.limp.rocket = nil
		local torso = torsoOf(golem)
		if torso and reason == "expired" then
			E:Explosion(golem.lab, torso.Position, 9, 0.55, { source = st.source })
		end
	end,
}

-- ─────────────────────────────── SHOCKED ───────────────────────────────

Statuses.shocked = {
	duration = 4,
	apply = function(E, golem, st, opts)
		local torso = torsoOf(golem)
		if not torso then
			return
		end
		local lab = golem.lab
		local G = E.S.GolemService
		G:Stun(golem, st.remaining + 0.5)
		golem.mods.limp.shocked = true
		local multiplier = (if opts.overcharge then 2 else 1) * (if golem.skin.traits.conductive then 1.5 else 1)
		if opts.overcharge then
			st.remaining += 2
		end
		if not opts.chained then
			local top = Vector3.new(torso.Position.X + rand(-6, 6), lab.origin.Y + lab.map.height - 1, torso.Position.Z)
			E:Lightning(lab, top, torso.Position)
		end
		G:Damage(
			golem,
			16 * multiplier * (st.potency or 1),
			{ source = st.source, position = torso.Position, kind = "shock" }
		)
		add(st, Vfx.emitter(torso, "shock"))
		add(st, Vfx.light(torso, Color3.fromRGB(150, 210, 255), 12, 2.5, true))
		E:Kick(golem, Vector3.new(0, 16, 0))
		-- Chain lightning.
		if not opts.chained then
			local count = 0
			local range = 16
			for _, other in lab.golems do
				local otherTorso = torsoOf(other)
				if other ~= golem and otherTorso and not other.statuses.shocked and count < 5 then
					local d = (otherTorso.Position - torso.Position).Magnitude
					local metal = other.skin.traits.conductive or other.statuses.golden or other.statuses.magnetic
					if d < range or (opts.conductor and metal) then
						count += 1
						E:Lightning(lab, torso.Position, otherTorso.Position)
						E:ApplyStatus(
							other,
							"shocked",
							{ duration = st.duration * 0.75, source = st.source, chained = true, potency = st.potency }
						)
					end
				end
			end
		end
	end,
	tick = function(E, golem, st, _dt, labDt)
		st.data.twitch = (st.data.twitch or 0) - labDt
		if st.data.twitch <= 0 then
			st.data.twitch = 0.11
			st.data.flash = not st.data.flash
			E:SetLook(
				golem,
				"shock",
				if st.data.flash
					then { priority = 70, color = Color3.fromRGB(235, 248, 255), material = Enum.Material.Neon }
					else nil
			)
			for _ = 1, 2 do
				local part = golem.parts[math.random(1, #golem.parts)]
				if part and part.Parent and not part.Anchored and not golem.grabbedBy then
					part:ApplyImpulse(Vector3.new(rand(-1, 1), rand(-0.5, 1), 0) * part.AssemblyMass * 16)
				end
			end
		end
	end,
	remove = function(E, golem)
		golem.mods.limp.shocked = nil
		E:SetLook(golem, "shock", nil)
		local torso = torsoOf(golem)
		if torso then
			E.S.LabService:FX(golem.lab, "smokepuff", { p = torso.Position })
		end
	end,
}

-- ─────────────────────────────── WET ───────────────────────────────

Statuses.wet = {
	duration = 6,
	apply = function(E, golem, st)
		local torso = torsoOf(golem)
		if torso then
			add(st, Vfx.emitter(torso, "drip"))
		end
		E:SetLook(
			golem,
			"wet",
			{ priority = 5, tint = Color3.fromRGB(110, 160, 255), tintAlpha = 0.18, reflectance = 0.2 }
		)
	end,
	remove = function(E, golem)
		E:SetLook(golem, "wet", nil)
	end,
}

-- ─────────────────────────────── HYPER ───────────────────────────────

local function hyperController(golem, _dt, labDt)
	local st = golem.statuses.hyper
	if not st then
		return
	end
	st.data.cd = (st.data.cd or 0) - labDt
	if st.data.cd <= 0 and golem.grounded then
		st.data.cd = rand(0.4, 0.75)
		st.E:Kick(golem, Vector3.new(rand(-1, 1) * 42, rand(55, 85), 0))
		local torso = torsoOf(golem)
		if torso and not torso.Anchored then
			torso.AssemblyAngularVelocity += Vector3.new(0, 0, rand(-9, 9))
		end
		st.E.S.LabService:FXU(golem.lab, "boing", { p = (torso and torso.Position) or golem.lab.origin })
	end
end

Statuses.hyper = {
	duration = 9,
	apply = function(E, golem, st)
		st.E = E
		golem.mods.limp.hyper = true
		local torso = torsoOf(golem)
		if torso then
			add(st, Vfx.emitter(torso, "shock", { Rate = 10, Color = ColorSequence.new(Color3.fromRGB(80, 255, 220)) }))
		end
		setController(golem, st, hyperController, false)
	end,
	remove = function(E, golem, st)
		golem.mods.limp.hyper = nil
		clearController(E, golem, st)
	end,
}

-- ─────────────────────────────── GIANT / TINY ───────────────────────────────

Statuses.giant = {
	duration = 15,
	apply = function(E, golem)
		E.S.GolemService:SetScale(golem, 2.4, 0.8)
		local torso = torsoOf(golem)
		if torso then
			E.S.LabService:FX(golem.lab, "grow", { p = torso.Position })
		end
	end,
	remove = function(E, golem, _st, reason)
		if reason ~= "clear" then
			E.S.GolemService:SetScale(golem, if golem.statuses.tiny then 0.45 else 1, 0.6)
		end
	end,
}

Statuses.tiny = {
	duration = 15,
	apply = function(E, golem)
		E.S.GolemService:SetScale(golem, 0.45, 0.6)
		golem.model:SetAttribute("Squeaky", true)
		local torso = torsoOf(golem)
		if torso then
			E.S.LabService:FX(golem.lab, "shrink", { p = torso.Position })
		end
	end,
	remove = function(E, golem, _st, reason)
		golem.model:SetAttribute("Squeaky", nil)
		if reason ~= "clear" then
			E.S.GolemService:SetScale(golem, if golem.statuses.giant then 2.4 else 1, 0.6)
		end
	end,
}

-- ─────────────────────────────── GRAVITY FLIP ───────────────────────────────

Statuses.gravityflip = {
	duration = 9,
	apply = function(E, golem, st)
		golem.mods.gravity.flip = -1
		golem.mods.limp.flip = true
		local torso = torsoOf(golem)
		if torso then
			add(
				st,
				Vfx.emitter(
					torso,
					"float",
					{ Color = ColorSequence.new(Color3.fromRGB(150, 130, 255)), Acceleration = Vector3.new(0, 6, 0) }
				)
			)
			add(st, Vfx.light(torso, Color3.fromRGB(140, 120, 255), 10, 1.4))
		end
		E:Kick(golem, Vector3.new(0, 22, 0))
	end,
	remove = function(_E, golem)
		golem.mods.gravity.flip = nil
		golem.mods.limp.flip = nil
	end,
}

-- ─────────────────────────────── GHOST ───────────────────────────────

Statuses.ghost = {
	duration = 8,
	apply = function(E, golem, st)
		E:SetLook(golem, "ghost", {
			priority = 45,
			color = Color3.fromRGB(190, 255, 255),
			material = Enum.Material.ForceField,
			transparency = 0.3,
		})
		st.data.collide = {}
		for _, part in golem.parts do
			st.data.collide[part] = part.CanCollide
			part.CanCollide = false
		end
		golem.mods.gravity.ghost = 0
		golem.mods.damage.ghost = 0
		golem.mods.limp.ghost = true
		E:SetDrag(golem, "ghost", 1.4)
		local torso = torsoOf(golem)
		if torso then
			add(st, Vfx.emitter(torso, "ghost"))
			add(st, Vfx.light(torso, Color3.fromRGB(170, 255, 255), 12, 1.2))
		end
	end,
	tick = function(E, golem, st, _dt, labDt)
		local torso = torsoOf(golem)
		if not torso then
			return
		end
		st.data.drift = (st.data.drift or 0) - labDt
		if st.data.drift <= 0 then
			st.data.drift = rand(0.5, 1)
			local lab = golem.lab
			local p = torso.Position - lab.origin
			local push = Vector3.new(rand(-12, 12), rand(-6, 10), 0)
			if p.X < lab.minX + 6 then
				push += Vector3.new(18, 0, 0)
			elseif p.X > lab.maxX - 6 then
				push -= Vector3.new(18, 0, 0)
			end
			if p.Y < 3 then
				push += Vector3.new(0, 16, 0)
			elseif p.Y > lab.map.height - 5 then
				push -= Vector3.new(0, 16, 0)
			end
			E:Pull(golem, push)
		end
	end,
	remove = function(E, golem, st)
		E:SetLook(golem, "ghost", nil)
		for part, collide in st.data.collide or {} do
			if part.Parent then
				part.CanCollide = collide
			end
		end
		golem.mods.gravity.ghost = nil
		golem.mods.damage.ghost = nil
		golem.mods.limp.ghost = nil
		E:SetDrag(golem, "ghost", nil)
		-- If it drifted somewhere it can't be, bring it back.
		local torso = torsoOf(golem)
		if torso then
			local lab = golem.lab
			local p = torso.Position - lab.origin
			if p.Y < 0.5 or p.X < lab.minX or p.X > lab.maxX or p.Y > lab.map.height then
				task.defer(function()
					E.S.GolemService:Reform(golem, { toSpawn = true })
				end)
			end
		end
	end,
}

-- ─────────────────────────────── ZOMBIE ───────────────────────────────

local ZOMBIE_POSE = {
	ShoulderL = -100,
	ShoulderR = 100,
	ElbowL = 20,
	ElbowR = -20,
	HipL = 0,
	HipR = 0,
	KneeL = 0,
	KneeR = 0,
	Neck = 15,
}

local function zombieController(golem, _dt, labDt)
	local st = golem.statuses.zombie
	if not st then
		return
	end
	local E = st.E
	local torso = torsoOf(golem)
	if not torso then
		return
	end
	local G = E.S.GolemService
	local target = G:Nearest(golem.lab, torso.Position, 160, function(other)
		return other ~= golem and not other.statuses.zombie and not other.shattered and not other.statuses.ascension
	end)
	st.data.hop = (st.data.hop or 0) - labDt
	if golem.grounded and st.data.hop <= 0 and not golem.controllerStunned then
		st.data.hop = rand(0.75, 1.15)
		local dir = if target
			then math.sign(target.byName.Torso.Position.X - torso.Position.X)
			else (if math.random() < 0.5 then -1 else 1)
		if dir == 0 then
			dir = 1
		end
		E:Kick(golem, Vector3.new(dir * rand(20, 30), rand(40, 52), 0))
		st.data.step = not st.data.step
		local pose = table.clone(ZOMBIE_POSE)
		pose.HipL = if st.data.step then -18 else 10
		pose.HipR = if st.data.step then -10 else 18
		G:SetPose(golem, pose, 0.8, 6)
	end
	st.data.bite = (st.data.bite or 0) - labDt
	if target and st.data.bite <= 0 then
		local targetTorso = target.byName.Torso
		local reach = 5.4 * math.max(golem.scale, target.scale)
		if targetTorso and (targetTorso.Position - torso.Position).Magnitude < reach then
			st.data.bite = 1
			E:ApplyStatus(target, "zombie", { source = st.source, duration = st.duration })
			G:Damage(target, 10, { source = st.source, position = targetTorso.Position, kind = "bite" })
			E.S.LabService:FX(golem.lab, "infect", { p = targetTorso.Position })
		end
	end
end

Statuses.zombie = {
	duration = 45,
	immune = function(golem)
		return golem.statuses.ascension ~= nil
	end,
	apply = function(E, golem, st)
		st.E = E
		E:SetLook(golem, "zombie", { priority = 30, tint = Color3.fromRGB(96, 172, 64), tintAlpha = 0.55 })
		st.data.pupils = {}
		for _, name in { "PupilL", "PupilR" } do
			local pupil = golem.faces[name]
			if pupil and pupil.Parent then
				st.data.pupils[pupil] = { pupil.Color, pupil.Material }
				pupil.Color = Color3.fromRGB(255, 40, 40)
				pupil.Material = Enum.Material.Neon
			end
		end
		golem.model:SetAttribute("Zombie", true)
		golem.uprightStrength = 0.75
		setController(golem, st, zombieController, true)
		E.S.GolemService:SetPose(golem, ZOMBIE_POSE, 0.8, 6)
		local torso = torsoOf(golem)
		if torso then
			add(st, Vfx.emitter(torso, "stink", { Color = ColorSequence.new(Color3.fromRGB(110, 170, 60)), Rate = 3 }))
			E.S.LabService:FX(golem.lab, "infect", { p = torso.Position })
		end
	end,
	remove = function(E, golem, st)
		E:SetLook(golem, "zombie", nil)
		for pupil, saved in st.data.pupils or {} do
			if pupil.Parent then
				pupil.Color = saved[1]
				pupil.Material = saved[2]
			end
		end
		golem.model:SetAttribute("Zombie", nil)
		golem.uprightStrength = nil
		clearController(E, golem, st)
	end,
}

-- ─────────────────────────────── GOLDEN ───────────────────────────────

Statuses.golden = {
	duration = 20,
	apply = function(E, golem, st)
		E.S.GolemService:SetRigid(golem, true)
		golem.mods.noUpright.golden = true
		golem.mods.damage.golden = 0.25
		E:SetLook(
			golem,
			"golden",
			{ priority = 60, color = Color3.fromRGB(255, 198, 56), material = Enum.Material.Foil, reflectance = 0.3 }
		)
		E:SetPhys(golem, "golden", { priority = 60, densityMul = 3 })
		local torso = torsoOf(golem)
		if torso then
			add(st, Vfx.emitter(torso, "gold"))
			add(st, Vfx.light(torso, Color3.fromRGB(255, 210, 90), 12, 1.6))
			E.S.LabService:FX(golem.lab, "gild", { p = torso.Position })
		end
		st.data.savedController = golem.controller
		golem.controller = nil
	end,
	remove = function(E, golem, st)
		golem.mods.noUpright.golden = nil
		golem.mods.damage.golden = nil
		if not golem.statuses.frozen then
			E.S.GolemService:SetRigid(golem, false)
		end
		E:SetLook(golem, "golden", nil)
		E:SetPhys(golem, "golden", nil)
		if st.data.savedController and golem.controller == nil then
			golem.controller = st.data.savedController
		end
	end,
}

-- ─────────────────────────────── MAGNETIC ───────────────────────────────

Statuses.magnetic = {
	duration = 9,
	apply = function(_E, golem, st)
		local torso = torsoOf(golem)
		if torso then
			add(
				st,
				Vfx.emitter(
					torso,
					"sparkle",
					{ Color = ColorSequence.new(Color3.fromRGB(255, 80, 90), Color3.fromRGB(90, 140, 255)), Rate = 20 }
				)
			)
			add(st, Vfx.light(torso, Color3.fromRGB(255, 90, 110), 14, 1.6, true))
		end
		golem.model:SetAttribute("Magnet", true)
	end,
	tick = function(E, golem, _st, _dt, labDt)
		local torso = torsoOf(golem)
		if not torso then
			return
		end
		local range = 24 * golem.scale
		local function pull(object, position: Vector3, strength: number)
			local offset = torso.Position - position
			local d = offset.Magnitude
			if d > 1.5 and d < range then
				local falloff = 1 - d / range + 0.25
				E:Pull(object, offset.Unit * strength * falloff * labDt)
			end
		end
		for _, other in golem.lab.golems do
			local otherTorso = torsoOf(other)
			if other ~= golem and otherTorso then
				pull(other, otherTorso.Position, if other.skin.traits.conductive then 160 else 95)
			end
		end
		if E.S.PropService then
			for _, prop in E.S.PropService:InRadius(golem.lab, torso.Position, range) do
				pull(prop, prop.root.Position, if prop.propId == "anvil" or prop.propId == "barrel" then 180 else 90)
			end
		end
	end,
	remove = function(_E, golem)
		golem.model:SetAttribute("Magnet", nil)
	end,
}

-- ─────────────────────────────── DISCO ───────────────────────────────

local DANCE = {
	{ ShoulderL = -150, ShoulderR = 30, ElbowL = 40, ElbowR = -40, HipL = -10, HipR = 10, Neck = 15 },
	{ ShoulderL = -30, ShoulderR = 150, ElbowL = 40, ElbowR = -40, HipL = 10, HipR = -10, Neck = -15 },
	{ ShoulderL = -160, ShoulderR = 160, ElbowL = 20, ElbowR = -20, HipL = -20, HipR = 20, Neck = 0 },
	{ ShoulderL = -60, ShoulderR = 60, ElbowL = 120, ElbowR = -120, HipL = 0, HipR = 0, Neck = 10 },
}

local function discoController(golem, _dt, labDt)
	local st = golem.statuses.disco
	if not st then
		return
	end
	st.data.beat = (st.data.beat or 0) - labDt
	if st.data.beat <= 0 then
		st.data.beat = 0.42
		st.data.move = (st.data.move or 0) % #DANCE + 1
		st.E.S.GolemService:SetPose(golem, DANCE[st.data.move], 1, 14)
		if st.data.move == 3 and golem.grounded then
			st.E:Kick(golem, Vector3.new(0, 22, 0))
		end
	end
end

Statuses.disco = {
	duration = 12,
	apply = function(E, golem, st)
		st.E = E
		golem.model:SetAttribute("Disco", true)
		golem.mods.happy = true
		local torso = torsoOf(golem)
		if torso then
			add(
				st,
				Vfx.emitter(torso, "sparkle", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 200)),
						ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 220, 255)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 240, 80)),
					}),
					Rate = 24,
				})
			)
			local light = add(st, Vfx.light(torso, Color3.fromRGB(255, 120, 255), 18, 2))
			light:AddTag("DiscoLight")
		end
		setController(golem, st, discoController, true)
	end,
	remove = function(E, golem, st)
		golem.model:SetAttribute("Disco", nil)
		golem.mods.happy = nil
		clearController(E, golem, st)
	end,
}

-- ─────────────────────────────── ACID ───────────────────────────────

Statuses.acid = {
	duration = 7,
	apply = function(E, golem, st)
		E:SetLook(golem, "acid", { priority = 25, tint = Color3.fromRGB(170, 255, 60), tintAlpha = 0.45 })
		local torso = torsoOf(golem)
		if torso then
			add(st, Vfx.emitter(torso, "acid"))
			add(st, Vfx.light(torso, Color3.fromRGB(170, 255, 60), 10, 1.2))
		end
		st.data.detach = 1.4
		E.S.GolemService:Stun(golem, 2)
	end,
	tick = function(E, golem, st, _dt, labDt)
		dot(E, golem, st, 6, labDt, "acid")
		st.data.detach -= labDt
		if st.data.detach <= 0 then
			st.data.detach = 1.6
			local order = { "ElbowL", "ElbowR", "KneeL", "KneeR", "ShoulderL", "ShoulderR", "HipL", "HipR" }
			for _, name in order do
				if golem.joints[name] then
					E.S.GolemService:Detach(golem, name, Vector3.new(rand(-6, 6), 10, 0))
					break
				end
			end
		end
	end,
	remove = function(E, golem)
		E:SetLook(golem, "acid", nil)
	end,
}

-- ─────────────────────────────── INSTANT: HEAL / CLONE ───────────────────────────────

Statuses.heal = {
	instant = true,
	apply = function(E, golem)
		local torso = torsoOf(golem)
		local position = if torso then torso.Position else golem.lab.origin
		E.S.GolemService:Reform(golem, { silent = true })
		E.S.LabService:FX(golem.lab, "heal", { p = position })
	end,
}

Statuses.clone = {
	instant = true,
	apply = function(E, golem, st)
		local torso = torsoOf(golem)
		if not torso then
			return
		end
		local lab = golem.lab
		local localPos = torso.Position - lab.origin
		local offset = if localPos.X > 0 then -5 else 5
		local spawnAt =
			Vector3.new(math.clamp(localPos.X + offset, lab.minX + 4, lab.maxX - 4), math.max(0, localPos.Y - 4.6), 0)
		local clone, err = E.S.GolemService:Spawn(lab, golem.skin.id, spawnAt, { source = st.source })
		if clone then
			E.S.LabService:FX(lab, "clone", { p = clone.byName.Torso.Position, c = golem.skin.body })
			for id, other in golem.statuses do
				if id ~= "clone" and Statuses[id] and not Statuses[id].instant then
					E:ApplyStatus(clone, id, { duration = other.remaining, source = st.source })
				end
			end
		elseif st.source then
			E.S.ShopService:Notify(st.source, "toast", { text = err or "Lab is full!", kind = "error" })
		end
	end,
}

-- ─────────────────────────────── DRAGON BREATH ───────────────────────────────

local function breathController(golem, _dt, labDt)
	local st = golem.statuses.dragonbreath
	if not st then
		return
	end
	local E = st.E
	local head = golem.byName.Head
	local att: Attachment? = st.data.mouth
	if not head or not head.Parent or not att then
		return
	end
	local mouth = head.CFrame * CFrame.new(0, -0.4 * golem.scale, 1.2 * golem.scale)
	local target = E.S.GolemService:Nearest(golem.lab, head.Position, 44, function(other)
		return other ~= golem
	end)
	local dir
	if target then
		local offset = target.byName.Torso.Position - mouth.Position
		dir = Vector3.new(offset.X, offset.Y, 0)
	else
		st.data.sweep = (st.data.sweep or 0) + labDt * 1.6
		dir = Vector3.new(math.cos(st.data.sweep), math.sin(st.data.sweep) * 0.4, 0)
	end
	if dir.Magnitude < 0.1 then
		dir = Vector3.xAxis
	end
	dir = dir.Unit
	local right = dir:Cross(Vector3.zAxis)
	if right.Magnitude < 0.1 then
		right = Vector3.xAxis
	end
	local world = CFrame.fromMatrix(mouth.Position, right.Unit, dir)
	att.CFrame = head.CFrame:ToObjectSpace(world)

	st.data.burn = (st.data.burn or 0) - labDt
	if st.data.burn <= 0 then
		st.data.burn = 0.15
		for _, other in golem.lab.golems do
			local otherTorso = torsoOf(other)
			if other ~= golem and otherTorso then
				local offset = otherTorso.Position - mouth.Position
				local d = offset.Magnitude
				if d < 28 and d > 0.1 and offset.Unit:Dot(dir) > 0.9 then
					E:ApplyStatus(other, "burning", { duration = 4, source = st.source })
					E:Pull(other, dir * 9)
				end
			end
		end
		if E.S.PropService then
			for _, prop in E.S.PropService:InRadius(golem.lab, mouth.Position, 28) do
				local offset = prop.root.Position - mouth.Position
				if offset.Magnitude > 0.1 and offset.Unit:Dot(dir) > 0.9 then
					E.S.PropService:Ignite(prop, st.source)
				end
			end
		end
		E:Pull(golem, -dir * 3)
	end
end

Statuses.dragonbreath = {
	duration = 6,
	apply = function(E, golem, st)
		st.E = E
		local head = golem.byName.Head
		if not head then
			return
		end
		local mouth = Instance.new("Attachment")
		mouth.Name = "BreathAtt"
		mouth.CFrame = CFrame.new(0, -0.4, 1.2)
		mouth.Parent = head
		add(st, mouth)
		st.data.mouth = mouth
		add(st, Vfx.emitter(mouth, "breath"))
		add(st, Vfx.light(head, Color3.fromRGB(255, 130, 40), 18, 2.6, true))
		setController(golem, st, breathController, true)
		E.S.LabService:FX(golem.lab, "roar", { p = head.Position })
	end,
	remove = function(E, golem, st)
		clearController(E, golem, st)
	end,
}

-- ─────────────────────────────── BALLOONS ───────────────────────────────

local BALLOON_COLORS = { Color3.fromRGB(255, 70, 110), Color3.fromRGB(80, 170, 255), Color3.fromRGB(255, 220, 60) }

Statuses.balloons = {
	duration = 14,
	apply = function(E, golem, st)
		local lab = golem.lab
		local anchors = {
			{ part = golem.byName.LowerArmL, offset = Vector3.new(0, -0.8, 0) },
			{ part = golem.byName.Head, offset = Vector3.new(0, 1.1, 0) },
			{ part = golem.byName.LowerArmR, offset = Vector3.new(0, -0.8, 0) },
		}
		st.data.balloons = {}
		for i, anchor in anchors do
			local host = anchor.part
			if not host or not host.Parent then
				continue
			end
			local s = golem.scale
			local balloon = Instance.new("Part")
			balloon.Name = "Balloon"
			balloon.Shape = Enum.PartType.Ball
			balloon.Size = Vector3.one * 2.8 * math.max(s, 0.6)
			balloon.Color = BALLOON_COLORS[i]
			balloon.Material = Enum.Material.SmoothPlastic
			balloon.Reflectance = 0.15
			balloon.CustomPhysicalProperties = PhysicalProperties.new(0.02, 0.2, 0.5, 1, 1)
			balloon.CollisionGroup = Physics2D.GolemGroups[golem.groupIndex]
			balloon.CanQuery = true
			balloon.CanTouch = true
			local top = host.Position + Vector3.new((i - 2) * 2.4 * s, 7 * s, 0)
			balloon.CFrame = CFrame.new(Vector3.new(top.X, top.Y, host.Position.Z))
			balloon.Parent = golem.model
			add(st, balloon)
			Physics2D.attach(balloon, lab.planeOrigin, { lockRotation = false, gravity = false })
			local knot = Instance.new("Attachment")
			knot.Name = "BalloonKnot"
			knot.Position = Vector3.new(0, -balloon.Size.Y / 2, 0)
			knot.Parent = balloon
			local hold = Instance.new("Attachment")
			hold.Name = "BalloonHold"
			hold.Position = anchor.offset * s
			hold.Parent = host
			add(st, hold)
			local rope = Instance.new("RopeConstraint")
			rope.Attachment0 = knot
			rope.Attachment1 = hold
			rope.Length = 6 * s
			rope.Visible = true
			rope.Thickness = 0.08
			rope.Color = BrickColor.new("Institutional white")
			rope.Parent = balloon
			local buoy = Instance.new("VectorForce")
			buoy.Name = "Buoy"
			buoy.Attachment0 = knot
			buoy.RelativeTo = Enum.ActuatorRelativeTo.World
			buoy.ApplyAtCenterOfMass = true
			buoy.Parent = balloon
			table.insert(st.data.balloons, { part = balloon, force = buoy })
			World.partToObject[balloon] = golem
		end
		golem.mods.limp.balloons = true
		E:SetDrag(golem, "balloons", 0.6)
		E.S.LabService:FX(lab, "inflate", { p = golem.byName.Head.Position })
	end,
	tick = function(_E, golem, st)
		local alive = 0
		for _, b in st.data.balloons do
			if b.part.Parent then
				alive += 1
			end
		end
		local ts = golem.lab.timeScale
		local g = Workspace.Gravity
		for _, b in st.data.balloons do
			if b.part.Parent then
				-- Three balloons lift ~1.45x the golem's weight in total.
				local lift = (golem.mass * 1.45 / math.max(alive, 1) * (alive / 3) + b.part:GetMass()) * g * ts * ts
				b.force.Force = Vector3.new(0, lift, 0)
			end
		end
	end,
	remove = function(E, golem, st, reason)
		for _, b in st.data.balloons or {} do
			World.partToObject[b.part] = nil
			if b.part.Parent and reason ~= "clear" then
				E.S.LabService:FX(golem.lab, "balloonpop", { p = b.part.Position, c = b.part.Color })
			end
		end
		golem.mods.limp.balloons = nil
		E:SetDrag(golem, "balloons", nil)
	end,
	cleanup = function(_E, _golem, st)
		for _, b in st.data.balloons or {} do
			World.partToObject[b.part] = nil
		end
	end,
}

-- ─────────────────────────────── STICKY ───────────────────────────────

Statuses.sticky = {
	duration = 10,
	apply = function(E, golem, st)
		E:SetLook(
			golem,
			"sticky",
			{ priority = 12, tint = Color3.fromRGB(150, 230, 60), tintAlpha = 0.35, reflectance = 0.15 }
		)
		golem.mods.limp.sticky = true
		st.data.welds = 0
		st.data.conns = {}
		local torso = torsoOf(golem)
		if torso then
			add(st, Vfx.emitter(torso, "slime", { Rate = 10, Color = ColorSequence.new(Color3.fromRGB(160, 240, 70)) }))
		end
		for _, part in golem.parts do
			local conn = part.Touched:Connect(function(other: BasePart)
				if st.data.welds >= 5 or not golem.statuses.sticky or golem.grabbedBy then
					return
				end
				if not other.CanCollide or other:IsDescendantOf(golem.model) or other.Name == "Balloon" then
					return
				end
				if other.CollisionGroup == "Debris" then
					return
				end
				st.data.welds += 1
				local weld = Instance.new("WeldConstraint")
				weld.Name = "StickyWeld"
				weld.Part0 = part
				weld.Part1 = other
				weld.Parent = part
				add(st, weld)
				E.S.LabService:FXU(golem.lab, "splat", { p = part.Position, c = Color3.fromRGB(150, 230, 60) })
			end)
			table.insert(st.data.conns, conn)
		end
	end,
	remove = function(E, golem, st)
		for _, conn in st.data.conns or {} do
			conn:Disconnect()
		end
		golem.mods.limp.sticky = nil
		E:SetLook(golem, "sticky", nil)
	end,
	cleanup = function(_E, _golem, st)
		for _, conn in st.data.conns or {} do
			conn:Disconnect()
		end
	end,
}

-- ─────────────────────────────── STINKY (sludge) ───────────────────────────────

Statuses.stinky = {
	duration = 5,
	apply = function(_E, golem, st)
		local head = golem.byName.Head
		if head then
			add(st, Vfx.emitter(head, "stink"))
		end
	end,
	tick = function(E, golem, st, _dt, labDt)
		dot(E, golem, st, 1.5, labDt, "stink")
		st.data.cough = (st.data.cough or 0.3) - labDt
		if st.data.cough <= 0 then
			st.data.cough = rand(0.9, 1.4)
			if golem.grounded then
				E:Pull(golem, Vector3.new(rand(-6, 6), 16, 0))
			end
			local head = golem.byName.Head
			if head then
				E.S.LabService:FXU(golem.lab, "cough", { p = head.Position })
			end
		end
	end,
}

-- ─────────────────────────────── STASIS marker ───────────────────────────────

Statuses.stasis = {
	duration = 5,
	apply = function(E, golem)
		E:SetLook(golem, "stasis", { priority = 55, tint = Color3.fromRGB(110, 255, 255), tintAlpha = 0.35 })
	end,
	remove = function(E, golem)
		E:SetLook(golem, "stasis", nil)
	end,
}

-- ─────────────────────────────── ASCENSION (endgame) ───────────────────────────────

local ASCEND_POSE = {
	ShoulderL = -140,
	ShoulderR = 140,
	ElbowL = 10,
	ElbowR = -10,
	HipL = -4,
	HipR = 4,
	KneeL = 0,
	KneeR = 0,
	Neck = 0,
}

local function ascendController(golem, _dt, labDt)
	local st = golem.statuses.ascension
	if not st then
		return
	end
	st.data.bob = (st.data.bob or 0) + labDt
	if math.floor(st.data.bob * 2) ~= st.data.lastBob then
		st.data.lastBob = math.floor(st.data.bob * 2)
		st.E:Pull(golem, Vector3.new(0, math.sin(st.data.bob * 2) * 4, 0))
	end
end

Statuses.ascension = {
	duration = 30,
	apply = function(E, golem, st)
		st.E = E
		local torso = torsoOf(golem)
		local head = golem.byName.Head
		if not torso or not head then
			return
		end
		E:SetLook(
			golem,
			"ascension",
			{ priority = 90, color = Color3.fromRGB(255, 246, 228), material = Enum.Material.Marble, reflectance = 0.1 }
		)
		golem.mods.gravity.ascend = -0.03
		golem.mods.damage.ascend = 0
		E:SetDrag(golem, "ascend", 1.6)
		local s = golem.scale
		local function weldDeco(part: BasePart)
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			part.Parent = golem.model
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = torso
			weld.Part1 = part
			weld.Parent = part
			add(st, part)
		end
		local halo = Instance.new("Part")
		halo.Name = "Halo"
		halo.Shape = Enum.PartType.Cylinder
		halo.Size = Vector3.new(0.18, 2.4 * s, 2.4 * s)
		halo.CFrame = head.CFrame * CFrame.new(0, 1.8 * s, 0) * CFrame.Angles(0, 0, math.rad(90))
		halo.Color = Color3.fromRGB(255, 230, 120)
		halo.Material = Enum.Material.Neon
		weldDeco(halo)
		for _, side in { -1, 1 } do
			local wing = Instance.new("Part")
			wing.Name = "Wing"
			wing.Size = Vector3.new(4.4 * s, 2.2 * s, 0.25 * s)
			wing.CFrame = torso.CFrame
				* CFrame.new(side * 2.9 * s, 0.9 * s, -1.1 * s)
				* CFrame.Angles(0, 0, math.rad(side * 24))
			wing.Color = Color3.fromRGB(255, 252, 240)
			wing.Material = Enum.Material.Neon
			wing.Transparency = 0.15
			weldDeco(wing)
		end
		add(st, Vfx.emitter(torso, "aura"))
		add(st, Vfx.emitter(torso, "gold", { Rate = 20 }))
		add(st, Vfx.light(torso, Color3.fromRGB(255, 230, 160), 26, 2.4))
		setController(golem, st, ascendController, true)
		E.S.GolemService:SetPose(golem, ASCEND_POSE, 1, 3)
		E.S.LabService:FX(golem.lab, "ascend", { p = torso.Position })
		-- Blessing shockwave: heals every other golem and showers coins.
		for _, other in golem.lab.golems do
			if other ~= golem then
				task.defer(function()
					if not other.dead then
						E.S.GolemService:Reform(other)
					end
				end)
			end
		end
		E:CoinBurst(golem.lab, torso.Position, st.source, 10)
		if st.source then
			E.S.ShopService:OnAscension(st.source)
		end
	end,
	remove = function(E, golem, st)
		golem.mods.gravity.ascend = nil
		golem.mods.damage.ascend = nil
		E:SetDrag(golem, "ascend", nil)
		E:SetLook(golem, "ascension", nil)
		clearController(E, golem, st)
	end,
}

return Statuses
