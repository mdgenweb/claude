--!nonstrict
-- Lightweight static golem model for UI previews (shop skin cards, spawn menu).

local GolemPreview = {}

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local function part(
	model: Model,
	shape: Enum.PartType,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

function GolemPreview.build(skin): Model
	local model = Instance.new("Model")
	model.Name = "GolemPreview"
	local mat = skin.material
	local torso = part(model, Enum.PartType.Ball, Vector3.one * 3, CFrame.new(0, 4.6, 0), skin.body, mat)
	part(model, Enum.PartType.Ball, Vector3.one * 2.4, CFrame.new(0, 7.05, 0), skin.body, mat)
	for _, side in { -1, 1 } do
		-- Arms (slightly raised for a friendly pose) and legs.
		local shoulder = CFrame.new(side * 1.6, 5.5, 1.65)
		part(model, Enum.PartType.Ball, Vector3.one * 1.05, shoulder, skin.joint, mat)
		local arm = shoulder * CFrame.Angles(0, 0, math.rad(side * 18))
		part(
			model,
			Enum.PartType.Cylinder,
			Vector3.new(3, 0.8, 0.8),
			arm * CFrame.new(0, -1.5, 0) * UPRIGHT,
			skin.limb,
			mat
		)
		part(model, Enum.PartType.Ball, Vector3.one * 0.95, arm * CFrame.new(0, -3.1, 0), skin.body, mat)
		part(
			model,
			Enum.PartType.Cylinder,
			Vector3.new(3.4, 0.9, 0.9),
			CFrame.new(side * 0.75, 1.8, -0.45) * UPRIGHT,
			skin.limb,
			mat
		)
		part(
			model,
			Enum.PartType.Block,
			Vector3.new(1.35, 0.55, 1.2),
			CFrame.new(side * 0.93, 0.25, -0.2),
			skin.joint,
			mat
		)
		part(
			model,
			Enum.PartType.Ball,
			Vector3.one * 0.66,
			CFrame.new(side * 0.46, 7.23, 0.96),
			skin.eye,
			Enum.Material.SmoothPlastic
		)
		part(
			model,
			Enum.PartType.Ball,
			Vector3.one * 0.32,
			CFrame.new(side * 0.46, 7.21, 1.24),
			skin.pupil,
			Enum.Material.SmoothPlastic
		)
		part(
			model,
			Enum.PartType.Ball,
			Vector3.one * 0.34,
			CFrame.new(side * 0.8, 6.77, 0.82),
			Color3.fromRGB(255, 120, 140),
			Enum.Material.SmoothPlastic
		).Transparency =
			0.45
	end
	part(
		model,
		Enum.PartType.Block,
		Vector3.new(0.6, 0.14, 0.14),
		CFrame.new(0, 6.63, 1.12),
		Color3.fromRGB(40, 24, 30),
		Enum.Material.SmoothPlastic
	)
	part(
		model,
		Enum.PartType.Block,
		Vector3.new(0.55, 0.55, 0.2),
		CFrame.new(0, 4.95, 1.42) * CFrame.Angles(0, 0, math.rad(45)),
		skin.accent,
		Enum.Material.Neon
	)
	if skin.accessory == "strawhat" then
		part(
			model,
			Enum.PartType.Cylinder,
			Vector3.new(0.2, 4.2, 4.2),
			CFrame.new(0, 8.1, 0.2) * UPRIGHT,
			Color3.fromRGB(230, 196, 100),
			Enum.Material.Fabric
		)
		part(
			model,
			Enum.PartType.Cylinder,
			Vector3.new(1.3, 2.2, 2.2),
			CFrame.new(0, 8.7, 0.1) * UPRIGHT,
			Color3.fromRGB(230, 196, 100),
			Enum.Material.Fabric
		)
	elseif skin.accessory == "carrot" then
		part(
			model,
			Enum.PartType.Cylinder,
			Vector3.new(1.1, 0.34, 0.34),
			CFrame.new(0, 6.95, 1.5) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(255, 130, 30),
			Enum.Material.SmoothPlastic
		)
	elseif skin.accessory == "halo" then
		part(
			model,
			Enum.PartType.Cylinder,
			Vector3.new(0.15, 2.2, 2.2),
			CFrame.new(0, 8.75, 0) * UPRIGHT,
			Color3.fromRGB(255, 230, 120),
			Enum.Material.Neon
		)
	elseif skin.accessory == "crown" then
		part(
			model,
			Enum.PartType.Cylinder,
			Vector3.new(0.5, 1.6, 1.6),
			CFrame.new(0, 8.25, 0) * UPRIGHT,
			Color3.fromRGB(255, 200, 60),
			Enum.Material.Foil
		)
	elseif skin.accessory == "horns" then
		for _, side in { -1, 1 } do
			part(
				model,
				Enum.PartType.Block,
				Vector3.new(0.4, 1.4, 0.4),
				CFrame.new(side * 0.8, 8.25, 0) * CFrame.Angles(0, 0, math.rad(-side * 25)),
				Color3.fromRGB(40, 30, 30),
				Enum.Material.Basalt
			)
		end
	elseif skin.accessory == "crystal" then
		part(
			model,
			Enum.PartType.Block,
			Vector3.new(0.45, 1.5, 0.45),
			CFrame.new(0.1, 8.35, 0) * CFrame.Angles(0, math.rad(45), 0),
			Color3.fromRGB(255, 140, 255),
			Enum.Material.Neon
		)
	elseif skin.accessory == "gear" then
		part(
			model,
			Enum.PartType.Cylinder,
			Vector3.new(0.25, 1.4, 1.4),
			CFrame.new(0, 4.7, 1.45) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(220, 170, 80),
			Enum.Material.Metal
		)
	elseif skin.accessory == "bolts" then
		for _, side in { -1, 1 } do
			part(
				model,
				Enum.PartType.Cylinder,
				Vector3.new(0.6, 0.4, 0.4),
				CFrame.new(side * 1.3, 6.65, 0),
				Color3.fromRGB(180, 180, 190),
				Enum.Material.Metal
			)
		end
	end
	model.PrimaryPart = torso
	model.WorldPivot = CFrame.new(0, 4.4, 0)
	return model
end

return GolemPreview
