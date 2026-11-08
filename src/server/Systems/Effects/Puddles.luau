--!nonstrict
-- Splash puddles: thrown potions leave a material on the floor that keeps affecting anything
-- standing in it (fire patches, ice, trampoline goo, glue, acid, sludge, healing pools).

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Vfx = require(script.Parent.Vfx)

local Puddles = {}

local function rand(a: number, b: number): number
	return a + math.random() * (b - a)
end

local KINDS = {
	fire = {
		material = Enum.Material.Neon,
		transparency = 0.25,
		life = 10,
		emitter = "fire",
		light = Color3.fromRGB(255, 130, 50),
	},
	ice = {
		material = Enum.Material.Ice,
		transparency = 0.15,
		life = 16,
		collide = true,
		physics = PhysicalProperties.new(0.9, 0, 0.05, 100, 1),
		emitter = "frost",
		color = Color3.fromRGB(190, 240, 255),
	},
	bounce = {
		material = Enum.Material.Neon,
		transparency = 0.2,
		life = 14,
		collide = true,
		physics = PhysicalProperties.new(0.8, 0.3, 1, 1, 100),
		emitter = "slime",
	},
	glue = {
		material = Enum.Material.SmoothPlastic,
		transparency = 0.15,
		life = 12,
		emitter = "slime",
		reflectance = 0.2,
	},
	sludge = {
		material = Enum.Material.Mud,
		transparency = 0.1,
		life = 10,
		emitter = "stink",
	},
	acid = {
		material = Enum.Material.Neon,
		transparency = 0.3,
		life = 9,
		emitter = "acid",
		light = Color3.fromRGB(170, 255, 60),
	},
	heal = {
		material = Enum.Material.Neon,
		transparency = 0.35,
		life = 10,
		emitter = "sparkle",
		light = Color3.fromRGB(255, 120, 170),
	},
}

local function insideGolems(E, lab, puddle)
	local list = {}
	local p = puddle.position
	for _, golem in lab.golems do
		if golem.dead then
			continue
		end
		for _, part in golem.parts do
			if part.Parent then
				local offset = part.Position - p
				if math.abs(offset.X) < puddle.radius and offset.Y > -1.5 and offset.Y < 3.2 then
					table.insert(list, golem)
					break
				end
			end
		end
	end
	local _ = E
	return list
end

local BEHAVIOUR = {
	fire = function(E, lab, puddle)
		for _, golem in insideGolems(E, lab, puddle) do
			E:ApplyStatus(golem, "burning", { duration = 3, source = puddle.source })
		end
		if E.S.PropService then
			for _, prop in E.S.PropService:InRadius(lab, puddle.position, puddle.radius) do
				E.S.PropService:Ignite(prop, puddle.source)
			end
		end
	end,
	bounce = function(E, lab, puddle)
		puddle.cooldown = puddle.cooldown or {}
		local now = os.clock()
		for _, golem in insideGolems(E, lab, puddle) do
			if (puddle.cooldown[golem] or 0) < now then
				puddle.cooldown[golem] = now + 0.7
				E:Kick(golem, Vector3.new(rand(-8, 8), 95 * lab.timeScale, 0))
				E.S.GolemService:Stun(golem, 1.2)
				E.S.LabService:FXU(lab, "boing", { p = puddle.position })
			end
		end
	end,
	glue = function(E, lab, puddle)
		for _, golem in insideGolems(E, lab, puddle) do
			E.S.GolemService:Stun(golem, 1)
			if not golem.grabbedBy then
				for _, part in golem.parts do
					if part.Parent and not part.Anchored then
						part.AssemblyLinearVelocity *= 0.25
					end
				end
			end
		end
	end,
	sludge = function(E, lab, puddle)
		for _, golem in insideGolems(E, lab, puddle) do
			E:ApplyStatus(golem, "stinky", { duration = 3, source = puddle.source })
		end
	end,
	acid = function(E, lab, puddle)
		for _, golem in insideGolems(E, lab, puddle) do
			E.S.GolemService:Damage(golem, 3, { source = puddle.source, kind = "acid" })
		end
	end,
	heal = function(E, lab, puddle)
		for _, golem in insideGolems(E, lab, puddle) do
			if golem.state == "ko" or golem.shattered then
				E.S.GolemService:Reform(golem)
			elseif golem.health < golem.maxHealth then
				golem.health = math.min(golem.maxHealth, golem.health + 6)
				golem.model:SetAttribute("Health", golem.health)
			end
		end
	end,
}

function Puddles.create(E, lab, kind: string, position: Vector3, _normal: Vector3?, color: Color3, source: Player?)
	local spec = KINDS[kind]
	if not spec then
		return nil
	end
	local hit = Workspace:Raycast(position + Vector3.new(0, 1.5, 0), Vector3.new(0, -26, 0), lab.staticRayParams)
	if not hit or hit.Normal.Y < 0.6 then
		return nil
	end
	local radius = 5.5
	local normal = hit.Normal
	local side = Vector3.zAxis:Cross(normal)
	if side.Magnitude < 0.1 then
		side = Vector3.xAxis
	end
	local part = Instance.new("Part")
	part.Name = "Puddle_" .. kind
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.32, radius * 2, radius * 2)
	part.CFrame = CFrame.fromMatrix(hit.Position + normal * 0.14, normal, side.Unit)
	part.Color = spec.color or color
	part.Material = spec.material
	part.Transparency = spec.transparency
	part.Reflectance = spec.reflectance or 0
	part.Anchored = true
	part.CanCollide = spec.collide == true
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CollisionGroup = "Static"
	if spec.physics then
		part.CustomPhysicalProperties = spec.physics
	end
	if spec.emitter then
		Vfx.emitter(
			part,
			spec.emitter,
			{ Rate = 8, Shape = Enum.ParticleEmitterShape.Disc, EmissionDirection = Enum.NormalId.Right }
		)
	end
	if spec.light then
		Vfx.light(part, spec.light, 12, 1.4, kind == "fire")
	end
	part.Parent = lab.effects

	local puddle = {
		kind = kind,
		part = part,
		position = hit.Position,
		radius = radius,
		remaining = spec.life or Config.Potions.PuddleLifetime,
		life = spec.life or Config.Potions.PuddleLifetime,
		baseTransparency = spec.transparency,
		source = source,
		timer = 0,
	}
	table.insert(lab.puddles, puddle)
	while #lab.puddles > Config.MaxPuddles do
		local oldest = table.remove(lab.puddles, 1)
		if oldest.part then
			oldest.part:Destroy()
		end
	end
	E.S.LabService:FX(lab, "puddle", { p = hit.Position, c = part.Color, r = radius })
	return puddle
end

function Puddles.update(E, lab, _dt: number, labDt: number)
	if labDt <= 0 then
		return
	end
	for i = #lab.puddles, 1, -1 do
		local puddle = lab.puddles[i]
		puddle.remaining -= labDt
		if puddle.remaining <= 0 or not puddle.part.Parent then
			table.remove(lab.puddles, i)
			puddle.part:Destroy()
			continue
		end
		if puddle.remaining < 1.5 then
			local alpha = 1 - puddle.remaining / 1.5
			puddle.part.Transparency = puddle.baseTransparency + (1 - puddle.baseTransparency) * alpha
		end
		puddle.timer -= labDt
		if puddle.timer <= 0 then
			puddle.timer = 0.2
			local behaviour = BEHAVIOUR[puddle.kind]
			if behaviour then
				local ok, err = pcall(behaviour, E, lab, puddle)
				if not ok then
					warn("[Puddles]", puddle.kind, err)
				end
			end
		end
	end
end

function Puddles.clear(lab)
	for _, puddle in lab.puddles do
		if puddle.part then
			puddle.part:Destroy()
		end
	end
	table.clear(lab.puddles)
end

return Puddles
