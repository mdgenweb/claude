--!nonstrict
-- The effect engine: applies potions, runs statuses on golems, world "fields" (black holes,
-- tornadoes, meteors...), puddles, explosions, lightning, shatters and the reaction rules that make
-- potions combine in surprising ways.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Reactions = require(Shared.Data.Reactions)

local ServerRoot = script.Parent.Parent
local Physics2D = require(ServerRoot.Systems.Physics2D)
local Vfx = require(ServerRoot.Systems.Effects.Vfx)
local Statuses = require(ServerRoot.Systems.Effects.Statuses)
local Fields = require(ServerRoot.Systems.Effects.Fields)
local Puddles = require(ServerRoot.Systems.Effects.Puddles)

local EffectsService = {
	Statuses = Statuses,
	Fields = Fields,
}

local LOOK_EXCLUDE = {
	EyeL = true, EyeR = true, PupilL = true, PupilR = true, KOMark = true,
	Mouth = true, Blush = true, Rune = true, Halo = true, Balloon = true,
	BalloonKnot = true, Booster = true, BoosterCone = true, Wing = true,
}

function EffectsService:Init(services)
	self.S = services
end

function EffectsService:Start() end

-- ─────────────────────────────── potions ───────────────────────────────

function EffectsService:ApplyPotion(lab, potion, position: Vector3, ctx)
	ctx = ctx or {}
	ctx.potion = potion
	local potency = ctx.potency or 1
	local feed = ctx.mode == "feed"
	local duration = potion.duration * potency * (if feed then Config.Potions.FeedDurationMultiplier else 1)
	local source = ctx.source
	local affected = 0

	if potion.kind == "field" then
		local center = position
		if feed and ctx.target and ctx.target.byName.Torso then
			center = ctx.target.byName.Torso.Position
		end
		local fn = Fields[potion.effect]
		if fn then
			fn(self, lab, center, potion, ctx, duration)
		end
		affected = 1
	else
		local targets
		if feed and ctx.target then
			targets = { ctx.target }
		else
			targets = self.S.GolemService:InRadius(lab, position, potion.radius)
		end
		for _, golem in targets do
			if self:ApplyStatus(golem, potion.effect, { duration = duration, source = source, potency = potency, potion = potion, origin = position }) then
				affected += 1
			end
		end
		-- Fire also lights explosive props.
		if potion.effect == "burning" and self.S.PropService then
			for _, prop in self.S.PropService:InRadius(lab, position, potion.radius) do
				self.S.PropService:Ignite(prop, source)
			end
		end
	end

	if not feed and potion.puddle then
		self:CreatePuddle(lab, potion.puddle, position, ctx.normal, potion.color, source)
	end
	if source and affected > 0 then
		self.S.EconomyService:AddChaos(source, 25 * affected, lab)
	end
end

-- ─────────────────────────────── statuses ───────────────────────────────

function EffectsService:HasStatus(golem, id: string): boolean
	return golem.statuses[id] ~= nil
end

function EffectsService:_reactionsBefore(golem, id: string, opts): boolean
	local lab = golem.lab
	local torso = golem.byName.Torso
	local position = if torso then torso.Position else lab.origin
	local source = opts.source
	local has = golem.statuses
	if id == "burning" then
		if has.frozen then
			self:RemoveStatus(golem, "frozen")
			self:Reaction(lab, "steam", position, source)
			Fields.steam(self, lab, position, nil, { source = source }, 0, 13)
			return false
		end
		if has.wet then
			self:RemoveStatus(golem, "wet")
			self.S.LabService:FX(lab, "sizzle", { p = position })
			return false
		end
		if has.balloons then
			self:RemoveStatus(golem, "balloons", "pop")
			self:Reaction(lab, "pop", position, source)
		end
		if has.ghost then
			opts.spirit = true
			self:Reaction(lab, "spiritflame", position, source)
		end
	elseif id == "frozen" then
		if has.burning then
			self:RemoveStatus(golem, "burning")
			self:Reaction(lab, "steam", position, source)
			Fields.steam(self, lab, position, nil, { source = source }, 0, 13)
			return false
		end
	elseif id == "shocked" then
		if has.wet or has.sticky or has.bouncy then
			opts.overcharge = true
			self:Reaction(lab, "overcharge", position, source)
		end
		if (has.golden or has.magnetic or golem.skin.traits.conductive) and not opts.chained then
			opts.conductor = true
			self:Reaction(lab, "conductor", position, source)
		end
		if has.rocket then
			has.rocket.data.overdrive = true
			has.rocket.remaining += 2
			self:Reaction(lab, "overdrive", position, source)
		end
		if has.balloons then
			self:RemoveStatus(golem, "balloons", "pop")
			self:Reaction(lab, "pop", position, source)
		end
	elseif id == "heal" then
		if has.zombie then
			self:Reaction(lab, "cure", position, source)
		end
	elseif id == "acid" then
		if has.golden then
			self:RemoveStatus(golem, "golden")
			self:Reaction(lab, "goldmelt", position, source)
			self:CoinBurst(lab, position, source, 3)
			return false
		end
	elseif id == "giant" then
		if has.tiny then
			self:RemoveStatus(golem, "tiny")
		end
	elseif id == "tiny" then
		if has.giant then
			self:RemoveStatus(golem, "giant")
		end
	end
	return true
end

-- Applies (or refreshes) a status. Returns the status record, or nil if blocked.
function EffectsService:ApplyStatus(golem, id: string, opts)
	opts = opts or {}
	if golem.dead or not golem.model.Parent then
		return nil
	end
	local def = Statuses[id]
	if not def then
		warn("[Effects] unknown status", id)
		return nil
	end
	local protectedStatus = id == "heal" or id == "ascension"
	if golem.statuses.ascension and not protectedStatus then
		return nil -- ascended golems are untouchable
	end
	if def.immune and def.immune(golem) then
		local torso = golem.byName.Torso
		if torso then
			self.S.LabService:FXU(golem.lab, "immune", { p = torso.Position + Vector3.new(0, 4, 0) })
		end
		return nil
	end
	if not self:_reactionsBefore(golem, id, opts) then
		return nil
	end
	if opts.source then
		self.S.GolemService:Touch(golem, opts.source)
	end

	if def.instant then
		def.apply(self, golem, { id = id, data = {}, instances = {}, source = opts.source, potency = opts.potency or 1, opts = opts })
		self:_statusEvent(golem, id, opts.source)
		return true
	end

	local duration = opts.duration or def.duration or 5
	if golem.skin.traits.flammable and id == "burning" then
		duration *= 2
	end
	local existing = golem.statuses[id]
	if existing then
		existing.remaining = math.max(existing.remaining, duration)
		existing.source = opts.source or existing.source
		if def.refresh then
			def.refresh(self, golem, existing, opts)
		end
		return existing
	end
	local st = {
		id = id,
		def = def,
		golem = golem,
		duration = duration,
		remaining = duration,
		source = opts.source,
		potency = opts.potency or 1,
		data = {},
		instances = {},
		opts = opts,
		age = 0,
	}
	golem.statuses[id] = st
	golem.model:SetAttribute("S_" .. id, true)
	local ok, err = pcall(def.apply, self, golem, st, opts)
	if not ok then
		warn("[Effects] apply failed", id, err)
	end
	self.S.GolemService:ApplyActuators(golem, true)
	self.S.GolemService:_updateUpright(golem)
	self.S.GolemService:RefreshGravity(golem)
	self:_statusEvent(golem, id, opts.source)
	return st
end

function EffectsService:_statusEvent(golem, id: string, source: Player?)
	local actor = source or self.S.GolemService:Attribution(golem)
	if actor then
		self.S.ChallengeService:Event(actor, "status", 1, { status = id, golem = golem.id })
	end
end

function EffectsService:RemoveStatus(golem, id: string, reason: string?)
	local st = golem.statuses[id]
	if not st then
		return
	end
	golem.statuses[id] = nil
	if golem.model then
		golem.model:SetAttribute("S_" .. id, nil)
	end
	if st.def.remove and not golem.dead then
		local ok, err = pcall(st.def.remove, self, golem, st, reason)
		if not ok then
			warn("[Effects] remove failed", id, err)
		end
	end
	Vfx.clean(st.instances)
	if not golem.dead then
		self.S.GolemService:ApplyActuators(golem, true)
		self.S.GolemService:_updateUpright(golem)
		self.S.GolemService:RefreshGravity(golem)
	end
end

-- Removes every status. `silent` skips end-of-effect behaviour (used before rebuilding a golem).
function EffectsService:ClearAll(golem, silent: boolean?)
	for id, st in table.clone(golem.statuses) do
		if silent then
			golem.statuses[id] = nil
			if st.def.cleanup then
				pcall(st.def.cleanup, self, golem, st)
			end
			Vfx.clean(st.instances)
			if golem.model then
				golem.model:SetAttribute("S_" .. id, nil)
			end
		else
			self:RemoveStatus(golem, id, "clear")
		end
	end
	golem.looks = nil
	golem.physLayers = nil
	golem.reformAt = nil
end

function EffectsService:CureAllZombies(lab)
	for _, golem in lab.golems do
		if golem.statuses.zombie then
			self:RemoveStatus(golem, "zombie", "cure")
			local torso = golem.byName.Torso
			if torso then
				self.S.LabService:FX(lab, "cure", { p = torso.Position })
			end
		end
	end
end

-- ─────────────────────────────── looks & physical layers ───────────────────────────────

-- Visual override layers; the highest priority wins. spec = {priority, color?, tint?, tintAlpha?,
-- material?, transparency?, reflectance?}
function EffectsService:SetLook(golem, key: string, spec)
	golem.looks = golem.looks or {}
	golem.looks[key] = spec
	self:RefreshLook(golem)
end

function EffectsService:RefreshLook(golem)
	if golem.dead or not golem.model.Parent then
		return
	end
	golem.baseLook = golem.baseLook or {}
	if golem.baseModel ~= golem.model then
		golem.baseModel = golem.model
		table.clear(golem.baseLook)
	end
	local best
	for _, spec in golem.looks or {} do
		if not best or spec.priority > best.priority then
			best = spec
		end
	end
	for _, part in golem.model:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		local base = golem.baseLook[part]
		if not base then
			if part.Transparency >= 1 then
				continue
			end
			base = { Color = part.Color, Material = part.Material, Transparency = part.Transparency, Reflectance = part.Reflectance }
			golem.baseLook[part] = base
		end
		local excluded = LOOK_EXCLUDE[part.Name]
		if not best or (excluded and not best.includeFace) then
			if part.Name ~= "KOMark" then
				part.Color = base.Color
				part.Material = base.Material
				part.Reflectance = base.Reflectance
				if not (golem.face == "ko" and (part.Name:sub(1, 3) == "Eye" or part.Name:sub(1, 5) == "Pupil")) then
					part.Transparency = base.Transparency
				end
			end
			if excluded and best and best.transparency then
				part.Transparency = math.max(base.Transparency, best.transparency)
			end
		else
			local color = base.Color
			if best.color then
				color = best.color
			elseif best.tint then
				color = base.Color:Lerp(best.tint, best.tintAlpha or 0.5)
			end
			part.Color = color
			part.Material = best.material or base.Material
			part.Reflectance = best.reflectance or base.Reflectance
			part.Transparency = math.max(base.Transparency, best.transparency or 0)
		end
	end
end

-- Physical property layers merged by priority over the skin's base properties.
function EffectsService:SetPhys(golem, key: string, spec)
	golem.physLayers = golem.physLayers or {}
	golem.physLayers[key] = spec
	self:RefreshPhys(golem)
end

function EffectsService:RefreshPhys(golem)
	local skin = golem.skin
	local props = {
		density = Config.Physics.GolemDensity * skin.density,
		friction = skin.friction,
		elasticity = skin.elasticity,
		frictionWeight = 1,
		elasticityWeight = 1,
	}
	local layers = {}
	for _, spec in golem.physLayers or {} do
		table.insert(layers, spec)
	end
	table.sort(layers, function(a, b)
		return a.priority < b.priority
	end)
	for _, spec in layers do
		for key, value in spec do
			if key ~= "priority" then
				props[key] = if key == "densityMul" then props.density * value else value
			end
		end
	end
	local physical = PhysicalProperties.new(math.max(props.density, 0.01), math.clamp(props.friction, 0, 2), math.clamp(props.elasticity, 0, 1), props.frictionWeight, props.elasticityWeight)
	for _, part in golem.parts do
		if part.Parent then
			part.CustomPhysicalProperties = physical
		end
	end
	local mass = 0
	for _, part in golem.parts do
		if part.Parent then
			mass += part:GetMass()
		end
	end
	golem.mass = mass
	self.S.GolemService:RefreshGravity(golem)
end

-- ─────────────────────────────── shared effect helpers ───────────────────────────────

function EffectsService:Reaction(lab, id: string, position: Vector3, source: Player?)
	local reaction = Reactions.ById[id]
	if not reaction then
		return
	end
	self.S.LabService:FX(lab, "reaction", { id = id, p = position })
	local actor = source or lab.lastActor
	if actor and actor.Parent then
		self.S.EconomyService:AddChaos(actor, reaction.chaos, lab)
		self.S.ChallengeService:Event(actor, "reaction", 1, { reaction = id })
		self.S.ShopService:DiscoverReaction(actor, id)
	end
end

-- Velocity change applied to every physical part of an object (mass-independent "kick").
function EffectsService:Kick(object, velocityChange: Vector3, perPart: ((BasePart) -> Vector3)?)
	if object.dead then
		return
	end
	self.S.GrabService:Claim(object)
	local seen = {}
	for _, part in object.parts do
		if part.Parent and not part.Anchored then
			local root = part.AssemblyRootPart or part
			if not seen[root] then
				seen[root] = true
				local dv = if perPart then perPart(root) else velocityChange
				Physics2D.impulse(root, dv * root.AssemblyMass)
			end
		end
	end
	if object.kind == "golem" then
		self.S.GolemService:ResetMotionHistory(object, 0.12)
	end
end

-- Lightweight per-frame push (no ownership claim, skips held objects). Used by continuous fields.
function EffectsService:Pull(object, velocityChange: Vector3)
	if object.dead or object.grabbedBy then
		return
	end
	local seen = {}
	for _, part in object.parts do
		if part.Parent and not part.Anchored then
			local root = part.AssemblyRootPart or part
			if not seen[root] then
				seen[root] = true
				root:ApplyImpulse(Vector3.new(velocityChange.X, velocityChange.Y, 0) * root.AssemblyMass)
			end
		end
	end
end

-- Air drag channels: the strongest active channel wins.
function EffectsService:SetDrag(golem, key: string, value: number?)
	golem.dragMods = golem.dragMods or {}
	golem.dragMods[key] = value
	local best = 0
	for _, v in golem.dragMods do
		best = math.max(best, v)
	end
	golem.drag = if best > 0 then best else nil
end

function EffectsService:Explosion(lab, position: Vector3, radius: number, power: number, opts)
	opts = opts or {}
	local source = opts.source
	local G = self.S.GolemService
	-- Mega Blast: exploding right on top of a giant golem doubles the radius.
	for _, golem in lab.golems do
		local torso = golem.byName.Torso
		if golem.statuses.giant and torso and (torso.Position - position).Magnitude < 7 * golem.scale then
			radius *= 2
			power *= 1.4
			self:Reaction(lab, "megablast", position, source)
			break
		end
	end
	self.S.LabService:FX(lab, "explode", { p = position, r = radius, c = opts.color or Color3.fromRGB(255, 150, 60), big = opts.big })
	local ts = lab.timeScale
	local hits = 0
	for _, golem in G:InRadius(lab, position, radius) do
		hits += 1
		local torso = golem.byName.Torso
		local d = if torso then (torso.Position - position).Magnitude else radius
		local falloff = math.clamp(1 - d / radius, 0.15, 1)
		if source then
			G:Touch(golem, source)
		end
		if golem.statuses.balloons then
			self:RemoveStatus(golem, "balloons", "pop")
			self:Reaction(lab, "pop", position, source)
		end
		if golem.statuses.frozen or golem.statuses.golden or (golem.skin.traits.brittle and falloff > 0.7) then
			self:Shatter(golem, if golem.statuses.golden then "gold" elseif golem.statuses.frozen then "ice" else "crystal", source, position)
			continue
		end
		G:Stun(golem, 2.2)
		self:Kick(golem, Vector3.zero, function(part)
			local offset = part.Position - position
			local dir = if offset.Magnitude > 0.1 then offset.Unit else Vector3.yAxis
			dir = (Vector3.new(dir.X, dir.Y, 0) + Vector3.new(0, 0.45, 0)).Unit
			return dir * 135 * power * falloff * ts
		end)
		G:Damage(golem, 48 * power * falloff * falloff, { source = source, position = torso and torso.Position, kind = "blast" })
		-- Close blasts pop a limb off.
		if falloff > 0.72 and power >= 1 and math.random() < 0.35 then
			local joints = { "ShoulderL", "ShoulderR", "HipL", "HipR", "ElbowL", "ElbowR" }
			G:Detach(golem, joints[math.random(1, #joints)], Vector3.new(0, 30, 0))
		end
	end
	if self.S.PropService then
		for _, prop in self.S.PropService:InRadius(lab, position, radius) do
			if prop.explosive and prop.root and (prop.root.Position - position).Magnitude > 0.5 then
				task.delay(0.08 + math.random() * 0.12, function()
					self.S.PropService:Ignite(prop, source)
				end)
			end
			local offset = prop.root.Position - position
			local d = offset.Magnitude
			local falloff = math.clamp(1 - d / radius, 0.15, 1)
			local dir = if d > 0.1 then offset.Unit else Vector3.yAxis
			dir = (Vector3.new(dir.X, dir.Y, 0) + Vector3.new(0, 0.4, 0)).Unit
			self:Kick(prop, dir * 120 * power * falloff * ts)
			prop.lastActor = source or prop.lastActor
			prop.lastActorTime = os.clock()
		end
	end
	if source then
		self.S.EconomyService:AddChaos(source, 40 + hits * 20, lab)
	end
end

function EffectsService:Lightning(lab, from: Vector3, to: Vector3, color: Color3?)
	self.S.LabService:FX(lab, "lightning", { a = from, b = to, c = color or Color3.fromRGB(170, 220, 255) })
end

function EffectsService:CoinBurst(lab, position: Vector3, source: Player?, multiplier: number?)
	lab.lastCoinBurst = lab.lastCoinBurst or 0
	local now = os.clock()
	local coins = 0
	if source and now - lab.lastCoinBurst > 2.5 then
		lab.lastCoinBurst = now
		coins = math.floor(Config.Economy.GoldShatterCoins * (multiplier or 1))
		self.S.EconomyService:AddCoins(source, coins, "gold")
	end
	self.S.LabService:FX(lab, "coins", { p = position, n = math.max(coins, 6) })
end

-- Breaks a golem apart; it reforms automatically a few seconds later.
function EffectsService:Shatter(golem, kind: string, source: Player?, from: Vector3?)
	if golem.dead or golem.shattered then
		return
	end
	local lab = golem.lab
	local torso = golem.byName.Torso
	local position = if torso then torso.Position else lab.origin
	source = source or self.S.GolemService:Attribution(golem)
	golem.shattered = true
	if kind == "ice" then
		self:Reaction(lab, "shatter", position, source)
	end
	if kind == "gold" then
		self:CoinBurst(lab, position, source, 1)
		if source then
			self.S.ChallengeService:Event(source, "goldshatter", 1, { golem = golem.id })
		end
	end
	if source then
		self.S.ChallengeService:Event(source, "shatter", 1, { golem = golem.id })
		local data = self.S.DataService:Get(source)
		if data then
			data.stats.shatters += 1
		end
	end
	self.S.LabService:FX(lab, "shatter", { p = position, kind = kind, c = golem.skin.body })
	-- Unlock the statue so the pieces tumble freely.
	for id in table.clone(golem.statuses) do
		if id == "frozen" or id == "golden" then
			self:RemoveStatus(golem, id, "shatter")
		end
	end
	self.S.GolemService:SetRigid(golem, false)
	self.S.GolemService:DetachAll(golem, 55)
	if from then
		self:Kick(golem, Vector3.zero, function(part)
			local offset = part.Position - from
			local dir = if offset.Magnitude > 0.1 then offset.Unit else Vector3.yAxis
			return (Vector3.new(dir.X, dir.Y, 0) + Vector3.new(0, 0.5, 0)).Unit * 60
		end)
	end
	self.S.GolemService:Damage(golem, 35, { source = source, position = position, kind = "shatter" })
	golem.reformAt = os.clock() + 3.5
end

function EffectsService:CreatePuddle(lab, kind: string, position: Vector3, normal: Vector3?, color: Color3, source: Player?)
	Puddles.create(self, lab, kind, position, normal, color, source)
end

function EffectsService:AddField(lab, field)
	field.remaining = field.remaining or 5
	field.age = 0
	table.insert(lab.fields, field)
	return field
end

-- ─────────────────────────────── hooks ───────────────────────────────

-- Called by GolemService for every hard impact. Return true to suppress normal impact damage.
function EffectsService:OnImpact(golem, part: BasePart, dv: number): boolean
	if golem.shattered then
		return true
	end
	local s = golem.statuses
	if s.ghost or s.ascension then
		return true
	end
	if s.frozen and dv > 50 then
		self:Shatter(golem, "ice", nil, part.Position - part.AssemblyLinearVelocity.Unit * 2)
		return true
	end
	if s.golden and dv > 68 then
		self:Shatter(golem, "gold", nil, nil)
		return true
	end
	if golem.skin.traits.brittle and dv > 115 then
		self:Shatter(golem, "crystal", nil, nil)
		return true
	end
	if s.bouncy then
		return dv < 80
	end
	return false
end

function EffectsService:OnTimeScale(lab, ratio: number)
	local _ = ratio
	for _, golem in lab.golems do
		for _, st in golem.statuses do
			if st.def.timescale then
				pcall(st.def.timescale, self, golem, st, lab.timeScale)
			end
		end
	end
end

function EffectsService:ClearLab(lab)
	for _, field in lab.fields do
		if field.finish and not field.finished then
			field.finished = true
			pcall(field.finish, self, lab, field, true)
		end
		Vfx.clean(field.instances)
	end
	table.clear(lab.fields)
	Puddles.clear(lab)
end

-- ─────────────────────────────── update ───────────────────────────────

function EffectsService:Update(lab, dt: number, labDt: number)
	local now = os.clock()
	for _, golem in table.clone(lab.golems) do
		if golem.dead then
			continue
		end
		if golem.reformAt and now >= golem.reformAt then
			golem.reformAt = nil
			golem.shattered = nil
			self.S.GolemService:Reform(golem)
			continue
		end
		if labDt <= 0 then
			continue
		end
		for id, st in table.clone(golem.statuses) do
			if golem.statuses[id] ~= st then
				continue
			end
			st.remaining -= labDt
			st.age += labDt
			if st.def.tick then
				local ok, err = pcall(st.def.tick, self, golem, st, dt, labDt)
				if not ok then
					warn("[Effects] tick failed", id, err)
				end
			end
			if golem.dead then
				break
			end
			if st.remaining <= 0 and golem.statuses[id] == st then
				self:RemoveStatus(golem, id, "expired")
			end
		end
		-- Generic air drag used by floaty statuses.
		if golem.drag and golem.drag > 0 and not golem.grabbedBy and not golem.dead then
			local damp = math.clamp(1 - golem.drag * labDt, 0, 1)
			for _, part in golem.parts do
				if part.Parent and not part.Anchored then
					part.AssemblyLinearVelocity *= damp
				end
			end
		end
	end

	-- World fields.
	for i = #lab.fields, 1, -1 do
		local field = lab.fields[i]
		if labDt > 0 then
			field.remaining -= labDt
			field.age += labDt
			if field.tick then
				local ok, err = pcall(field.tick, self, lab, field, dt, labDt)
				if not ok then
					warn("[Effects] field tick failed", field.kind, err)
					field.remaining = 0
				end
			end
		end
		if field.remaining <= 0 then
			table.remove(lab.fields, i)
			if field.finish and not field.finished then
				field.finished = true
				local ok, err = pcall(field.finish, self, lab, field, false)
				if not ok then
					warn("[Effects] field finish failed", field.kind, err)
				end
			end
			Vfx.clean(field.instances)
		end
	end

	Puddles.update(self, lab, dt, labDt)
	local _ = Workspace
end

return EffectsService
