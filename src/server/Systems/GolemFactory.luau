--!nonstrict
-- Builds a golem (the test dummy) as a 2D active ragdoll.
--
-- Physics: 10 invisible/visible collider parts on the lab plane (z = 0), joined by Z-axis
-- HingeConstraints with limits. Visuals: massless welded decorations layered in depth
-- (arms in front of the torso, legs behind) so limbs overlap correctly in 2D.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Skins = require(Shared.Data.Skins)
local Physics2D = require(script.Parent.Physics2D)

local GolemFactory = {}

local UPRIGHT_CYL = CFrame.Angles(0, 0, math.rad(90)) -- cylinder axis X -> Y
local FACING_CYL = CFrame.Angles(0, math.rad(90), 0) -- cylinder axis X -> Z (disc facing camera)

local ARM_Z = 1.65 -- visual depth layers
local LEG_Z = -0.45

-- Collider layout relative to the feet centre.
local PARTS = {
	{
		name = "Torso",
		shape = Enum.PartType.Ball,
		size = Vector3.one * 3.0,
		at = Vector3.new(0, 4.6, 0),
		visible = true,
	},
	{
		name = "Head",
		shape = Enum.PartType.Ball,
		size = Vector3.one * 2.4,
		at = Vector3.new(0, 7.05, 0),
		visible = true,
	},
	{ name = "UpperArmL", size = Vector3.new(0.8, 1.6, 0.8), at = Vector3.new(-1.6, 4.7, 0), limb = "arm" },
	{ name = "LowerArmL", size = Vector3.new(0.75, 1.5, 0.75), at = Vector3.new(-1.6, 3.15, 0), limb = "forearm" },
	{ name = "UpperArmR", size = Vector3.new(0.8, 1.6, 0.8), at = Vector3.new(1.6, 4.7, 0), limb = "arm" },
	{ name = "LowerArmR", size = Vector3.new(0.75, 1.5, 0.75), at = Vector3.new(1.6, 3.15, 0), limb = "forearm" },
	{ name = "UpperLegL", size = Vector3.new(0.9, 1.7, 0.9), at = Vector3.new(-0.75, 2.65, 0), limb = "thigh" },
	{ name = "LowerLegL", size = Vector3.new(0.85, 1.8, 0.85), at = Vector3.new(-0.75, 0.9, 0), limb = "shin" },
	{ name = "UpperLegR", size = Vector3.new(0.9, 1.7, 0.9), at = Vector3.new(0.75, 2.65, 0), limb = "thigh" },
	{ name = "LowerLegR", size = Vector3.new(0.85, 1.8, 0.85), at = Vector3.new(0.75, 0.9, 0), limb = "shin" },
}

-- Hinge joints. Angles in degrees, positive = counter-clockwise as seen from the camera.
local JOINTS = {
	{ name = "Neck", a = "Torso", b = "Head", pivot = Vector3.new(0, 6.0, 0), lower = -40, upper = 40, kind = "neck" },
	{
		name = "ShoulderL",
		a = "Torso",
		b = "UpperArmL",
		pivot = Vector3.new(-1.6, 5.5, 0),
		lower = -175,
		upper = 175,
		kind = "shoulder",
	},
	{
		name = "ElbowL",
		a = "UpperArmL",
		b = "LowerArmL",
		pivot = Vector3.new(-1.6, 3.9, 0),
		lower = -15,
		upper = 150,
		kind = "elbow",
	},
	{
		name = "ShoulderR",
		a = "Torso",
		b = "UpperArmR",
		pivot = Vector3.new(1.6, 5.5, 0),
		lower = -175,
		upper = 175,
		kind = "shoulder",
	},
	{
		name = "ElbowR",
		a = "UpperArmR",
		b = "LowerArmR",
		pivot = Vector3.new(1.6, 3.9, 0),
		lower = -150,
		upper = 15,
		kind = "elbow",
	},
	{
		name = "HipL",
		a = "Torso",
		b = "UpperLegL",
		pivot = Vector3.new(-0.75, 3.5, 0),
		lower = -85,
		upper = 40,
		kind = "hip",
	},
	{
		name = "KneeL",
		a = "UpperLegL",
		b = "LowerLegL",
		pivot = Vector3.new(-0.75, 1.8, 0),
		lower = -70,
		upper = 70,
		kind = "knee",
	},
	{
		name = "HipR",
		a = "Torso",
		b = "UpperLegR",
		pivot = Vector3.new(0.75, 3.5, 0),
		lower = -40,
		upper = 85,
		kind = "hip",
	},
	{
		name = "KneeR",
		a = "UpperLegR",
		b = "LowerLegR",
		pivot = Vector3.new(0.75, 1.8, 0),
		lower = -70,
		upper = 70,
		kind = "knee",
	},
}
GolemFactory.Joints = JOINTS
GolemFactory.PartNames = {}
for _, spec in PARTS do
	table.insert(GolemFactory.PartNames, spec.name)
end

local function decoration(
	parent: Model,
	host: BasePart,
	shape: Enum.PartType,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	name: string
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("Deco", true)
	part.Parent = parent
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = host
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function addAccessory(model: Model, parts, skin, origin: CFrame)
	local head: BasePart = parts.Head
	local torso: BasePart = parts.Torso
	local headCF = head.CFrame
	local kind = skin.accessory
	if kind == "strawhat" then
		local straw = Color3.fromRGB(230, 196, 100)
		decoration(
			model,
			head,
			Enum.PartType.Cylinder,
			Vector3.new(0.2, 4.2, 4.2),
			headCF * CFrame.new(0, 1.05, 0.2) * UPRIGHT_CYL,
			straw,
			Enum.Material.Fabric,
			"HatBrim"
		)
		decoration(
			model,
			head,
			Enum.PartType.Cylinder,
			Vector3.new(1.3, 2.2, 2.2),
			headCF * CFrame.new(0, 1.65, 0.1) * UPRIGHT_CYL,
			straw,
			Enum.Material.Fabric,
			"HatTop"
		)
		decoration(
			model,
			head,
			Enum.PartType.Cylinder,
			Vector3.new(0.3, 2.25, 2.25),
			headCF * CFrame.new(0, 1.25, 0.1) * UPRIGHT_CYL,
			Color3.fromRGB(170, 50, 50),
			Enum.Material.Fabric,
			"HatBand"
		)
	elseif kind == "carrot" then
		decoration(
			model,
			head,
			Enum.PartType.Cylinder,
			Vector3.new(1.1, 0.34, 0.34),
			headCF * CFrame.new(0, -0.1, 1.5) * FACING_CYL,
			Color3.fromRGB(255, 130, 30),
			Enum.Material.SmoothPlastic,
			"Carrot"
		)
		for _, x in { -0.5, 0, 0.5 } do
			decoration(
				model,
				torso,
				Enum.PartType.Ball,
				Vector3.one * 0.35,
				torso.CFrame * CFrame.new(x * 0.2, 0.6 - math.abs(x), 1.42),
				Color3.fromRGB(30, 30, 30),
				Enum.Material.SmoothPlastic,
				"Button"
			)
		end
	elseif kind == "bolts" then
		for _, side in { -1, 1 } do
			decoration(
				model,
				head,
				Enum.PartType.Cylinder,
				Vector3.new(0.6, 0.4, 0.4),
				headCF * CFrame.new(side * 1.3, -0.4, 0),
				Color3.fromRGB(180, 180, 190),
				Enum.Material.Metal,
				"Bolt"
			)
		end
		decoration(
			model,
			torso,
			Enum.PartType.Block,
			Vector3.new(2.2, 0.3, 0.3),
			torso.CFrame * CFrame.new(0, -0.6, 1.35),
			Color3.fromRGB(70, 70, 80),
			Enum.Material.Metal,
			"Plate"
		)
	elseif kind == "crystal" then
		for i, offset in { Vector3.new(-0.6, 1.1, 0.2), Vector3.new(0.1, 1.3, 0), Vector3.new(0.7, 1.0, 0.1) } do
			decoration(
				model,
				head,
				Enum.PartType.Block,
				Vector3.new(0.45, 1.3 + i * 0.15, 0.45),
				headCF * CFrame.new(offset) * CFrame.Angles(0, math.rad(45), math.rad((i - 2) * 20)),
				Color3.fromRGB(255, 140, 255),
				Enum.Material.Neon,
				"Shard"
			)
		end
	elseif kind == "gear" then
		local gear = decoration(
			model,
			torso,
			Enum.PartType.Cylinder,
			Vector3.new(0.25, 1.4, 1.4),
			torso.CFrame * CFrame.new(0, 0.1, 1.45) * FACING_CYL,
			Color3.fromRGB(220, 170, 80),
			Enum.Material.Metal,
			"Gear"
		)
		gear:AddTag("Spinner")
		gear:SetAttribute("SpinSpeed", 2)
		gear:SetAttribute("SpinAxis", "Z")
	elseif kind == "horns" then
		for _, side in { -1, 1 } do
			decoration(
				model,
				head,
				Enum.PartType.Block,
				Vector3.new(0.4, 1.4, 0.4),
				headCF * CFrame.new(side * 0.8, 1.2, 0) * CFrame.Angles(0, 0, math.rad(-side * 25)),
				Color3.fromRGB(40, 30, 30),
				Enum.Material.Basalt,
				"Horn"
			)
		end
	elseif kind == "halo" then
		local halo = decoration(
			model,
			head,
			Enum.PartType.Cylinder,
			Vector3.new(0.15, 2.2, 2.2),
			headCF * CFrame.new(0, 1.7, 0) * UPRIGHT_CYL,
			Color3.fromRGB(255, 230, 120),
			Enum.Material.Neon,
			"Halo"
		)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 220, 140)
		light.Range = 10
		light.Brightness = 1.4
		light.Parent = halo
	elseif kind == "crown" then
		local gold = Color3.fromRGB(255, 200, 60)
		decoration(
			model,
			head,
			Enum.PartType.Cylinder,
			Vector3.new(0.5, 1.6, 1.6),
			headCF * CFrame.new(0, 1.2, 0) * UPRIGHT_CYL,
			gold,
			Enum.Material.Foil,
			"CrownBand"
		)
		for _, x in { -0.55, 0, 0.55 } do
			decoration(
				model,
				head,
				Enum.PartType.Block,
				Vector3.new(0.3, 0.5, 0.3),
				headCF * CFrame.new(x, 1.6, 0.6) * CFrame.Angles(0, 0, math.rad(45)),
				gold,
				Enum.Material.Foil,
				"CrownSpike"
			)
		end
		decoration(
			model,
			head,
			Enum.PartType.Ball,
			Vector3.one * 0.3,
			headCF * CFrame.new(0, 1.25, 0.85),
			Color3.fromRGB(255, 40, 90),
			Enum.Material.Neon,
			"CrownGem"
		)
	end
	local _ = origin
end

export type BuildResult = {
	model: Model,
	parts: { [string]: BasePart },
	physical: { BasePart },
	joints: { [string]: HingeConstraint },
	upright: AlignOrientation,
	lift: VectorForce,
	mass: number,
	faces: { [string]: BasePart },
}

-- Builds and parents a golem. `feet` is the world position of the feet centre (on the plane).
function GolemFactory.build(
	skinId: string,
	feet: Vector3,
	planeOrigin: Attachment,
	group: string,
	parent: Instance
): BuildResult
	local skin = Skins.get(skinId)
	local model = Instance.new("Model")
	model.Name = "Golem"
	model:SetAttribute("Skin", skin.id)
	if skin.rainbow then
		model:SetAttribute("Rainbow", true)
	end

	local origin = CFrame.new(feet)
	local parts: { [string]: BasePart } = {}
	local physical = {}
	local physicalProps =
		PhysicalProperties.new(Config.Physics.GolemDensity * skin.density, skin.friction, skin.elasticity, 1, 1)

	for _, spec in PARTS do
		local part = Instance.new("Part")
		part.Name = spec.name
		part.Shape = spec.shape or Enum.PartType.Block
		part.Size = spec.size
		part.CFrame = origin * CFrame.new(spec.at)
		part.Color = if spec.name == "Torso" or spec.name == "Head" then skin.body else skin.limb
		part.Material = skin.material
		part.Transparency = if spec.visible then 0 else 1
		part.CanCollide = true
		part.CanQuery = true
		part.CanTouch = true
		part.CastShadow = spec.visible == true
		part.CollisionGroup = group
		part.CustomPhysicalProperties = physicalProps
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part:SetAttribute("Limb", spec.limb or spec.name)
		part.Parent = model
		parts[spec.name] = part
		table.insert(physical, part)
	end
	model.PrimaryPart = parts.Torso

	-- ── Visual layers ──
	local limbColor, jointColor, mat = skin.limb, skin.joint, skin.material
	local function limbVisual(
		part: BasePart,
		z: number,
		diameter: number,
		endBall: number?,
		endColor: Color3?,
		isLeg: boolean?
	)
		local cf = part.CFrame
		decoration(
			model,
			part,
			Enum.PartType.Cylinder,
			Vector3.new(part.Size.Y, diameter, diameter),
			cf * CFrame.new(0, 0, z) * UPRIGHT_CYL,
			limbColor,
			mat,
			"LimbVisual"
		)
		if endBall then
			local bottom = cf * CFrame.new(0, -part.Size.Y / 2, z)
			decoration(
				model,
				part,
				Enum.PartType.Ball,
				Vector3.one * endBall,
				bottom,
				endColor or jointColor,
				mat,
				if isLeg then "Knee" else "EndBall"
			)
		end
	end
	limbVisual(parts.UpperArmL, ARM_Z, 0.82, 0.9)
	limbVisual(parts.UpperArmR, ARM_Z, 0.82, 0.9)
	limbVisual(parts.LowerArmL, ARM_Z, 0.76, 0.95, skin.body)
	limbVisual(parts.LowerArmR, ARM_Z, 0.76, 0.95, skin.body)
	limbVisual(parts.UpperLegL, LEG_Z, 0.92, 0.98, nil, true)
	limbVisual(parts.UpperLegR, LEG_Z, 0.92, 0.98, nil, true)
	limbVisual(parts.LowerLegL, LEG_Z, 0.86)
	limbVisual(parts.LowerLegR, LEG_Z, 0.86)
	-- Boots.
	for _, name in { "LowerLegL", "LowerLegR" } do
		local leg = parts[name]
		local side = if name == "LowerLegL" then -1 else 1
		decoration(
			model,
			leg,
			Enum.PartType.Block,
			Vector3.new(1.35, 0.55, 1.2),
			leg.CFrame * CFrame.new(side * 0.18, -0.65, LEG_Z + 0.25),
			jointColor,
			mat,
			"Boot"
		)
	end
	-- Shoulder and hip balls (on the torso so limbs pivot under them).
	for _, x in { -1.6, 1.6 } do
		decoration(
			model,
			parts.Torso,
			Enum.PartType.Ball,
			Vector3.one * 1.05,
			origin * CFrame.new(x, 5.5, ARM_Z),
			jointColor,
			mat,
			"Shoulder"
		)
	end
	for _, x in { -0.75, 0.75 } do
		decoration(
			model,
			parts.Torso,
			Enum.PartType.Ball,
			Vector3.one * 1.0,
			origin * CFrame.new(x, 3.5, LEG_Z),
			jointColor,
			mat,
			"Hip"
		)
	end

	-- Chest rune (glowing core) and belly seam.
	local torsoCF = parts.Torso.CFrame
	local rune = decoration(
		model,
		parts.Torso,
		Enum.PartType.Block,
		Vector3.new(0.55, 0.55, 0.2),
		torsoCF * CFrame.new(0, 0.35, 1.42) * CFrame.Angles(0, 0, math.rad(45)),
		skin.accent,
		Enum.Material.Neon,
		"Rune"
	)
	rune.CastShadow = false
	local runeLight = Instance.new("PointLight")
	runeLight.Name = "RuneLight"
	runeLight.Color = skin.accent
	runeLight.Range = 7
	runeLight.Brightness = 1.1
	runeLight.Shadows = false
	runeLight.Parent = rune
	decoration(
		model,
		parts.Torso,
		Enum.PartType.Cylinder,
		Vector3.new(0.22, 2.9, 2.9),
		torsoCF * CFrame.new(0, -0.15, 0.08) * FACING_CYL,
		jointColor,
		mat,
		"Seam"
	).Transparency =
		0.0

	-- Face.
	local headCF = parts.Head.CFrame
	local faces = {}
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "L" else "R"
		local eye = decoration(
			model,
			parts.Head,
			Enum.PartType.Ball,
			Vector3.one * 0.66,
			headCF * CFrame.new(side * 0.46, 0.18, 0.96),
			skin.eye,
			Enum.Material.SmoothPlastic,
			"Eye" .. tag
		)
		eye.CastShadow = false
		faces["Eye" .. tag] = eye
		-- Pupils use a Weld (not WeldConstraint) so clients can offset C0 to look at the cursor.
		local pupil = Instance.new("Part")
		pupil.Name = "Pupil" .. tag
		pupil.Shape = Enum.PartType.Ball
		pupil.Size = Vector3.one * 0.32
		pupil.Color = skin.pupil
		pupil.Material = Enum.Material.SmoothPlastic
		pupil.CanCollide = false
		pupil.CanQuery = false
		pupil.CanTouch = false
		pupil.Massless = true
		pupil.CastShadow = false
		pupil:SetAttribute("Deco", true)
		pupil.CFrame = headCF * CFrame.new(side * 0.46, 0.16, 1.24)
		pupil.Parent = model
		local weld = Instance.new("Weld")
		weld.Name = "PupilWeld"
		weld.Part0 = parts.Head
		weld.Part1 = pupil
		weld.C0 = headCF:ToObjectSpace(pupil.CFrame)
		weld.Parent = pupil
		pupil:SetAttribute("RestC0", weld.C0)
		faces["Pupil" .. tag] = pupil
		-- KO "X" eyes (hidden until knocked out).
		for _, angle in { 45, -45 } do
			local cross = decoration(
				model,
				parts.Head,
				Enum.PartType.Block,
				Vector3.new(0.62, 0.14, 0.14),
				headCF * CFrame.new(side * 0.46, 0.16, 1.2) * CFrame.Angles(0, 0, math.rad(angle)),
				Color3.fromRGB(30, 22, 30),
				Enum.Material.SmoothPlastic,
				"KOMark"
			)
			cross.Transparency = 1
			cross.CastShadow = false
		end
		-- Blush.
		local blush = decoration(
			model,
			parts.Head,
			Enum.PartType.Ball,
			Vector3.one * 0.34,
			headCF * CFrame.new(side * 0.8, -0.28, 0.82),
			Color3.fromRGB(255, 120, 140),
			Enum.Material.SmoothPlastic,
			"Blush"
		)
		blush.Transparency = 0.45
		blush.CastShadow = false
	end
	local mouth = decoration(
		model,
		parts.Head,
		Enum.PartType.Block,
		Vector3.new(0.6, 0.14, 0.14),
		headCF * CFrame.new(0, -0.42, 1.12),
		Color3.fromRGB(40, 24, 30),
		Enum.Material.SmoothPlastic,
		"Mouth"
	)
	mouth.CastShadow = false
	faces.Mouth = mouth

	addAccessory(model, parts, skin, origin)

	-- ── Physics constraints ──
	for _, part in physical do
		Physics2D.attach(part, planeOrigin, { lockRotation = part.Name == "Torso", gravity = true })
	end

	local joints = {}
	local rotation = Physics2D.PlaneRotation
	for _, spec in JOINTS do
		local a, b = parts[spec.a], parts[spec.b]
		local pivotWorld = origin * CFrame.new(spec.pivot)
		local frame = CFrame.new(pivotWorld.Position) * rotation
		local att0 = Instance.new("Attachment")
		att0.Name = spec.name .. "0"
		att0.CFrame = a.CFrame:ToObjectSpace(frame)
		att0.Parent = a
		local att1 = Instance.new("Attachment")
		att1.Name = spec.name .. "1"
		att1.CFrame = b.CFrame:ToObjectSpace(frame)
		att1.Parent = b
		local hinge = Instance.new("HingeConstraint")
		hinge.Name = spec.name
		hinge.Attachment0 = att0
		hinge.Attachment1 = att1
		hinge.LimitsEnabled = true
		hinge.LowerAngle = spec.lower
		hinge.UpperAngle = spec.upper
		hinge.Restitution = 0.05
		hinge.ActuatorType = Enum.ActuatorType.Motor
		hinge.AngularVelocity = 0
		hinge.MotorMaxTorque = 0
		hinge.Visible = false
		hinge:SetAttribute("Kind", spec.kind)
		hinge.Parent = a
		joints[spec.name] = hinge
	end

	-- Upright controller (only active while standing).
	local uprightAtt = Instance.new("Attachment")
	uprightAtt.Name = "UprightAtt"
	uprightAtt.CFrame = parts.Torso.CFrame:ToObjectSpace(CFrame.new(parts.Torso.Position) * Physics2D.UpRotation)
	uprightAtt.Parent = parts.Torso
	local upright = Instance.new("AlignOrientation")
	upright.Name = "Upright"
	upright.Mode = Enum.OrientationAlignmentMode.OneAttachment
	upright.AlignType = Enum.AlignType.PrimaryAxisParallel
	upright.Attachment0 = uprightAtt
	upright.PrimaryAxis = Vector3.yAxis
	upright.Responsiveness = 30
	upright.MaxTorque = 0
	upright.MaxAngularVelocity = 12
	upright.Enabled = false
	upright.Parent = parts.Torso

	local lift = Instance.new("VectorForce")
	lift.Name = "Lift"
	lift.Attachment0 = parts.Torso:FindFirstChild("Plane2D") :: Attachment
	lift.RelativeTo = Enum.ActuatorRelativeTo.World
	lift.ApplyAtCenterOfMass = true
	lift.Force = Vector3.zero
	lift.Enabled = false
	lift.Parent = parts.Torso

	model.Parent = parent

	local mass = 0
	for _, part in physical do
		mass += part:GetMass()
	end

	return {
		model = model,
		parts = parts,
		physical = physical,
		joints = joints,
		upright = upright,
		lift = lift,
		mass = mass,
		faces = faces,
	}
end

return GolemFactory
