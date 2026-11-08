--!nonstrict
-- World "field" effects spawned at a splash point: steam blasts, explosions, black holes, stasis
-- bubbles, meteor showers, tornadoes, supernovas, stink clouds and the Chaos Potion.
-- Signature: Fields[effect](E, lab, center, potion, ctx, duration, radiusOverride?)

local Workspace = game:GetService("Workspace")

local World = require(script.Parent.Parent.World)

local Fields = {}

local function rand(a: number, b: number): number
	return a + math.random() * (b - a)
end

local function objectsInRadius(E, lab, position: Vector3, radius: number)
	local list = {}
	for _, golem in E.S.GolemService:InRadius(lab, position, radius) do
		table.insert(list, golem)
	end
	if E.S.PropService then
		for _, prop in E.S.PropService:InRadius(lab, position, radius) do
			table.insert(list, prop)
		end
	end
	return list
end

local function rootPosition(object): Vector3?
	if object.kind == "golem" then
		local torso = object.byName.Torso
		return torso and torso.Position
	end
	return object.root and object.root.Position
end

-- ── Steam: radial push that leaves everything wet ──
function Fields.steam(E, lab, center: Vector3, _potion, ctx, _duration, radiusOverride: number?)
	local radius = radiusOverride or (_potion and _potion.radius) or 15
	local source = ctx and ctx.source
	E.S.LabService:FX(lab, "steam", { p = center, r = radius })
	for _, object in objectsInRadius(E, lab, center, radius) do
		local position = rootPosition(object)
		if position then
			local offset = position - center
			local d = offset.Magnitude
			local falloff = math.clamp(1 - d / radius, 0.2, 1)
			local dir = if d > 0.1 then offset.Unit else Vector3.yAxis
			dir = (Vector3.new(dir.X, dir.Y, 0) + Vector3.new(0, 0.5, 0)).Unit
			E:Kick(object, dir * 85 * falloff * lab.timeScale)
			if object.kind == "golem" then
				E.S.GolemService:Stun(object, 1.5)
				E.S.GolemService:Damage(object, 10 * falloff, { source = source, position = position, kind = "steam" })
				E:ApplyStatus(object, "wet", { duration = 6, source = source })
			end
		end
	end
end

-- ── Explosion ──
function Fields.explosion(E, lab, center: Vector3, potion, ctx)
	local potency = ctx.potency or 1
	E:Explosion(lab, center, potion.radius * math.sqrt(potency), potency, { source = ctx.source })
end

-- ── Stink cloud ──
function Fields.sludge(E, lab, center: Vector3, potion, ctx, duration: number)
	local radius = potion.radius
	E.S.LabService:FX(lab, "stink", { p = center, r = radius, d = duration })
	E:AddField(lab, {
		kind = "stink",
		position = center,
		radius = radius,
		remaining = duration,
		timer = 0,
		tick = function(_E, _lab, field, _dt, labDt)
			field.timer -= labDt
			if field.timer > 0 then
				return
			end
			field.timer = 0.5
			for _, golem in E.S.GolemService:InRadius(lab, field.position, field.radius) do
				E:ApplyStatus(golem, "stinky", { duration = 4, source = ctx.source })
			end
		end,
	})
end

-- ── Black hole ──
function Fields.blackhole(E, lab, center: Vector3, potion, ctx, duration: number)
	local radius = potion.radius
	local id = World.nextId()
	E.S.LabService:FX(lab, "blackhole", { id = id, p = center, r = radius, d = duration })
	E:AddField(lab, {
		kind = "blackhole",
		id = id,
		position = center,
		radius = radius,
		remaining = duration,
		tick = function(_E, _lab, field, _dt, labDt)
			local strength = 230 * math.min(1, field.age / 0.8 + 0.25)
			for _, object in objectsInRadius(E, lab, field.position, field.radius) do
				local position = rootPosition(object)
				if position then
					local offset = field.position - position
					local d = offset.Magnitude
					if d > 0.5 then
						local falloff = 1 - d / field.radius
						local tangent = Vector3.new(-offset.Y, offset.X, 0).Unit
						local pull = offset.Unit * strength * (falloff + 0.35) + tangent * 60 * falloff
						-- Damp existing speed near the core so things orbit instead of slingshotting.
						E:Pull(object, pull * labDt)
					end
					if object.kind == "golem" then
						E.S.GolemService:Stun(object, 1)
						if d < 5 then
							field.dmg = (field.dmg or 0) + 14 * labDt
							if field.dmg >= 4 then
								E.S.GolemService:Damage(
									object,
									field.dmg,
									{ source = ctx.source, position = position, kind = "void" }
								)
								field.dmg = 0
							end
						end
					end
				end
			end
		end,
		finish = function(_E, _lab, field, aborted)
			E.S.LabService:FX(lab, "blackholeend", { id = field.id, p = field.position })
			if not aborted then
				E:Explosion(
					lab,
					field.position,
					field.radius * 0.55,
					0.9,
					{ source = ctx.source, color = Color3.fromRGB(170, 90, 255) }
				)
			end
		end,
	})
end

-- ── Stasis bubble: time stops inside ──
function Fields.stasis(E, lab, center: Vector3, potion, ctx, duration: number)
	local radius = potion.radius
	E.S.LabService:FX(lab, "stasis", { p = center, r = radius, d = duration })
	local frozen = {}
	local objects = objectsInRadius(E, lab, center, radius)
	for _, object in objects do
		E.S.GrabService:Claim(object)
		object.inStasis = true
		for _, part in object.parts do
			if part.Parent and not part.Anchored then
				frozen[part] = { v = part.AssemblyLinearVelocity, w = part.AssemblyAngularVelocity }
				part.Anchored = true
			end
		end
		if object.kind == "golem" then
			E:ApplyStatus(object, "stasis", { duration = duration, source = ctx.source })
		end
	end
	E:AddField(lab, {
		kind = "stasis",
		position = center,
		radius = radius,
		remaining = duration,
		finish = function()
			for _, object in objects do
				object.inStasis = nil
			end
			local released = {}
			for part, record in frozen do
				if part.Parent then
					if lab.paused then
						lab.frozenParts = lab.frozenParts or {}
						lab.frozenParts[part] = record
					else
						part.Anchored = false
						table.insert(released, { part, record })
					end
				end
			end
			for _, entry in released do
				entry[1].AssemblyLinearVelocity = entry[2].v
				entry[1].AssemblyAngularVelocity = entry[2].w
			end
			for _, object in objects do
				if object.kind == "golem" and not object.dead then
					E.S.GolemService:ResetMotionHistory(object, 0.3)
				end
			end
			E.S.LabService:FX(lab, "stasisend", { p = center, r = radius })
		end,
	})
end

-- ── Meteor shower ──
function Fields.meteors(E, lab, center: Vector3, potion, ctx, duration: number)
	local spread = potion.radius
	local count = 7
	E.S.LabService:FX(lab, "meteorcall", { p = center })
	local field
	field = E:AddField(lab, {
		kind = "meteors",
		position = center,
		remaining = duration + 3,
		spawned = 0,
		next = 0.15,
		meteors = {},
		tick = function(_E, _lab, f, _dt, labDt)
			if f.spawned < count and f.age >= f.next then
				f.spawned += 1
				f.next = f.age + duration / count
				local top = lab.origin.Y + lab.map.height - 2
				local startX = math.clamp(
					center.X + rand(-spread / 2, spread / 2) - 14,
					lab.origin.X + lab.minX + 2,
					lab.origin.X + lab.maxX - 2
				)
				local meteor = {
					id = World.nextId(),
					position = Vector3.new(startX, top, lab.origin.Z),
					velocity = Vector3.new(rand(18, 34), -rand(95, 120), 0),
				}
				table.insert(f.meteors, meteor)
				E.S.LabService:FX(lab, "meteor", { id = meteor.id, p = meteor.position, v = meteor.velocity })
			end
			for i = #f.meteors, 1, -1 do
				local m = f.meteors[i]
				local step = m.velocity * labDt
				local hit = Workspace:Raycast(m.position, step, lab.worldRayParams)
				if hit or m.position.Y < lab.origin.Y - 10 then
					local at = if hit then hit.Position else m.position
					table.remove(f.meteors, i)
					E.S.LabService:FX(lab, "meteorhit", { id = m.id, p = at })
					E:Explosion(lab, at, 10, 0.8, { source = ctx.source, color = Color3.fromRGB(255, 120, 40) })
				else
					m.position += step
				end
			end
			if f.spawned >= count and #f.meteors == 0 then
				f.remaining = 0
			end
		end,
	})
	local _ = field
end

-- ── Tornado ──
function Fields.tornado(E, lab, center: Vector3, potion, ctx, duration: number)
	local id = World.nextId()
	local floorY = lab.origin.Y
	local height = math.min(lab.map.height - 2, 60)
	E.S.LabService:FX(
		lab,
		"tornado",
		{ id = id, p = Vector3.new(center.X, floorY, center.Z), d = duration, h = height }
	)
	E:AddField(lab, {
		kind = "tornado",
		id = id,
		x = center.X,
		targetX = center.X,
		remaining = duration,
		send = 0,
		tick = function(_E, _lab, field, _dt, labDt)
			if math.abs(field.x - field.targetX) < 2 then
				field.targetX =
					math.clamp(field.x + rand(-26, 26), lab.origin.X + lab.minX + 8, lab.origin.X + lab.maxX - 8)
			end
			field.x += math.sign(field.targetX - field.x) * 10 * labDt
			local halfWidth = potion.radius * 0.6
			for _, object in objectsInRadius(E, lab, Vector3.new(field.x, floorY + height / 2, center.Z), height) do
				local position = rootPosition(object)
				if position then
					local dx = position.X - field.x
					local dy = position.Y - floorY
					if math.abs(dx) < halfWidth and dy < height then
						local lift = if dy < height * 0.85 then 230 else -60
						local swirl = math.sin(field.age * 7 + dy * 0.3) * 130
						local center = -dx * 9
						E:Pull(object, Vector3.new(swirl + center, lift, 0) * labDt)
						if object.kind == "golem" then
							E.S.GolemService:Stun(object, 1.2)
							local torso = object.byName.Torso
							if torso and not torso.Anchored and not object.grabbedBy then
								torso.AssemblyAngularVelocity = Vector3.new(0, 0, 9)
							end
						end
					end
				end
			end
			field.send -= labDt
			if field.send <= 0 then
				field.send = 0.12
				E.S.LabService:FXU(lab, "tornadomove", { id = field.id, x = field.x })
			end
		end,
		finish = function(_E, _lab, field)
			E.S.LabService:FX(lab, "tornadoend", { id = field.id })
		end,
	})
	local _ = ctx
end

-- ── Supernova: blinding flash, then the biggest blast in the game ──
function Fields.supernova(E, lab, center: Vector3, potion, ctx)
	E.S.LabService:FX(lab, "supernova", { p = center, r = potion.radius })
	task.delay(0.75, function()
		if lab.destroyed then
			return
		end
		E:Explosion(
			lab,
			center,
			potion.radius,
			2.2 * (ctx.potency or 1),
			{ source = ctx.source, color = Color3.fromRGB(255, 250, 210), big = true }
		)
		for _, golem in E.S.GolemService:InRadius(lab, center, potion.radius * 0.8) do
			E:ApplyStatus(golem, "burning", { duration = 6, source = ctx.source })
		end
	end)
end

-- ── Chaos Potion: three random effects ──
local CHAOS_STATUSES = {
	"burning",
	"frozen",
	"levitating",
	"bouncy",
	"shocked",
	"giant",
	"tiny",
	"gravityflip",
	"ghost",
	"zombie",
	"golden",
	"magnetic",
	"disco",
	"acid",
	"rocket",
	"balloons",
	"hyper",
}
local CHAOS_FIELDS = { "explosion", "blackhole", "stasis", "tornado", "meteors", "steam" }

function Fields.chaos(E, lab, center: Vector3, potion, ctx)
	E.S.LabService:FX(lab, "chaos", { p = center })
	local used = {}
	for _ = 1, 3 do
		if math.random() < 0.6 then
			local id
			repeat
				id = CHAOS_STATUSES[math.random(1, #CHAOS_STATUSES)]
			until not used[id]
			used[id] = true
			for _, golem in E.S.GolemService:InRadius(lab, center, potion.radius) do
				E:ApplyStatus(golem, id, { source = ctx.source })
			end
		else
			local id
			repeat
				id = CHAOS_FIELDS[math.random(1, #CHAOS_FIELDS)]
			until not used[id]
			used[id] = true
			local fake = { radius = if id == "blackhole" then 26 elseif id == "explosion" then 16 else 14 }
			local fn = Fields[id]
			if fn then
				fn(E, lab, center + Vector3.new(rand(-4, 4), rand(0, 4), 0), fake, ctx, 5)
			end
		end
	end
end

return Fields
