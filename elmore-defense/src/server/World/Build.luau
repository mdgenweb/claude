--[[
	Build
	Tiny helpers for procedural geometry: anchored, smooth, cartoon-friendly parts.
]]

local Build = {}

local DEFAULTS = {
	Anchored = true,
	CanCollide = true,
	CanTouch = false,
	TopSurface = Enum.SurfaceType.Smooth,
	BottomSurface = Enum.SurfaceType.Smooth,
	Material = Enum.Material.SmoothPlastic,
}

function Build.part(props: { [string]: any }, parent: Instance?): BasePart
	local className = props.ClassName or "Part"
	local part = Instance.new(className) :: any
	for key, value in DEFAULTS do
		if props[key] == nil then
			part[key] = value
		end
	end
	for key, value in props do
		if key ~= "ClassName" and key ~= "Parent" then
			part[key] = value
		end
	end
	part.Parent = parent or props.Parent
	return part
end

function Build.block(parent: Instance, cframe: CFrame, size: Vector3, color: Color3, material: Enum.Material?): BasePart
	return Build.part({
		CFrame = cframe,
		Size = size,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	}, parent)
end

function Build.ball(parent: Instance, position: Vector3, diameter: number, color: Color3, material: Enum.Material?): BasePart
	return Build.part({
		Shape = Enum.PartType.Ball,
		CFrame = CFrame.new(position),
		Size = Vector3.new(diameter, diameter, diameter),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	}, parent)
end

-- Upright cylinder (Roblox cylinders are along X, so rotate onto Y).
function Build.cylinder(parent: Instance, position: Vector3, height: number, diameter: number, color: Color3, material: Enum.Material?): BasePart
	return Build.part({
		Shape = Enum.PartType.Cylinder,
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Size = Vector3.new(height, diameter, diameter),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	}, parent)
end

function Build.wedge(parent: Instance, cframe: CFrame, size: Vector3, color: Color3, material: Enum.Material?): BasePart
	return Build.part({
		ClassName = "WedgePart",
		CFrame = cframe,
		Size = size,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	}, parent)
end

function Build.model(name: string, parent: Instance?): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

function Build.folder(name: string, parent: Instance?): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

-- Billboard / surface text in the game's display font with an ink outline.
function Build.label(parent: Instance, text: string, options: { [string]: any }?)
	options = options or {}
	local gui
	if options.surface then
		gui = Instance.new("SurfaceGui")
		gui.Face = options.face or Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = options.pixelsPerStud or 30
		gui.LightInfluence = 0
	else
		gui = Instance.new("BillboardGui")
		gui.Size = options.size or UDim2.fromOffset(260, 70)
		gui.StudsOffset = options.offset or Vector3.new(0, 4, 0)
		gui.AlwaysOnTop = options.alwaysOnTop == true
		gui.MaxDistance = options.maxDistance or 120
		gui.LightInfluence = 0
	end
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
	label.TextColor3 = options.color or Color3.fromRGB(255, 255, 255)
	local stroke = Instance.new("UIStroke")
	stroke.Color = options.strokeColor or Color3.fromRGB(30, 20, 51)
	stroke.Thickness = options.strokeThickness or 3
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = parent
	return gui, label
end

return Build
