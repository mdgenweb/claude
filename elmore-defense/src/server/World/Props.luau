--[[
	Props
	Cartoon set dressing built from primitives. Bold silhouettes and saturated colours read well from the
	TD camera and match the show's simple shapes. Every builder returns a Model pivoted at its base.
]]

local Build = require(script.Parent.Build)

local Props = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local INK = rgb(40, 28, 60)

function Props.tree(parent: Instance, base: Vector3, scale: number?, leafColor: Color3?)
	scale = scale or 1
	local model = Build.model("Tree", parent)
	local trunkHeight = 5 * scale
	Build.cylinder(model, base + Vector3.new(0, trunkHeight / 2, 0), trunkHeight, 1.4 * scale, rgb(140, 92, 56), Enum.Material.Wood)
	local leaves = leafColor or rgb(92, 196, 92)
	Build.ball(model, base + Vector3.new(0, trunkHeight + 1.8 * scale, 0), 6 * scale, leaves, Enum.Material.SmoothPlastic)
	Build.ball(model, base + Vector3.new(1.8 * scale, trunkHeight + 0.8 * scale, 0.6 * scale), 4 * scale, leaves:Lerp(rgb(255, 255, 255), 0.08))
	Build.ball(model, base + Vector3.new(-1.6 * scale, trunkHeight + 1 * scale, -0.8 * scale), 4.4 * scale, leaves:Lerp(rgb(0, 0, 0), 0.08))
	return model
end

function Props.pine(parent: Instance, base: Vector3, scale: number?)
	scale = scale or 1
	local model = Build.model("Pine", parent)
	Build.cylinder(model, base + Vector3.new(0, 1.5 * scale, 0), 3 * scale, 1 * scale, rgb(120, 80, 50), Enum.Material.Wood)
	for tier = 0, 2 do
		local width = (6 - tier * 1.6) * scale
		local y = (3 + tier * 2.3) * scale
		local cone = Build.part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2.6 * scale, width, width),
			CFrame = CFrame.new(base + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = rgb(60, 150, 90):Lerp(rgb(110, 200, 120), tier / 3),
		}, model)
		cone.Name = "Tier"
	end
	return model
end

function Props.bush(parent: Instance, base: Vector3, color: Color3?)
	local model = Build.model("Bush", parent)
	local c = color or rgb(80, 180, 80)
	Build.ball(model, base + Vector3.new(0, 1.2, 0), 3, c)
	Build.ball(model, base + Vector3.new(1.2, 0.9, 0.4), 2.2, c:Lerp(rgb(255, 255, 255), 0.1))
	Build.ball(model, base + Vector3.new(-1.1, 0.9, -0.3), 2.4, c:Lerp(rgb(0, 0, 0), 0.08))
	return model
end

function Props.rock(parent: Instance, base: Vector3, scale: number?)
	scale = scale or 1
	local model = Build.model("Rock", parent)
	local rock = Build.ball(model, base + Vector3.new(0, 0.8 * scale, 0), 3 * scale, rgb(150, 150, 160), Enum.Material.Slate)
	rock.Size = Vector3.new(3.4 * scale, 2 * scale, 2.8 * scale)
	return model
end

function Props.lamp(parent: Instance, base: Vector3, color: Color3?)
	local model = Build.model("Lamp", parent)
	Build.cylinder(model, base + Vector3.new(0, 4, 0), 8, 0.5, rgb(60, 60, 80), Enum.Material.Metal)
	local bulb = Build.ball(model, base + Vector3.new(0, 8.4, 0), 1.6, color or rgb(255, 236, 160), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Range = 14
	light.Brightness = 1.2
	light.Color = bulb.Color
	light.Parent = bulb
	return model
end

function Props.bench(parent: Instance, cframe: CFrame)
	local model = Build.model("Bench", parent)
	local wood = rgb(196, 120, 70)
	Build.block(model, cframe * CFrame.new(0, 1.2, 0), Vector3.new(5, 0.4, 1.6), wood, Enum.Material.WoodPlanks)
	Build.block(model, cframe * CFrame.new(0, 2.2, 0.7), Vector3.new(5, 1.4, 0.3), wood, Enum.Material.WoodPlanks)
	Build.block(model, cframe * CFrame.new(-2.1, 0.6, 0), Vector3.new(0.4, 1.2, 1.4), INK)
	Build.block(model, cframe * CFrame.new(2.1, 0.6, 0), Vector3.new(0.4, 1.2, 1.4), INK)
	return model
end

function Props.fence(parent: Instance, from: Vector3, to: Vector3, color: Color3?)
	local model = Build.model("Fence", parent)
	local c = color or rgb(255, 255, 255)
	local delta = to - from
	local length = delta.Magnitude
	local mid = from + delta / 2
	local look = CFrame.lookAt(mid, mid + delta)
	Build.block(model, look * CFrame.new(0, 1.6, 0), Vector3.new(0.3, 0.4, length), c)
	Build.block(model, look * CFrame.new(0, 0.8, 0), Vector3.new(0.3, 0.4, length), c)
	local posts = math.max(2, math.floor(length / 3))
	for index = 0, posts do
		local p = from + delta * (index / posts)
		Build.block(model, CFrame.lookAt(p, p + delta) * CFrame.new(0, 1.1, 0), Vector3.new(0.5, 2.2, 0.5), c)
	end
	return model
end

function Props.house(parent: Instance, cframe: CFrame, wallColor: Color3, roofColor: Color3?)
	local model = Build.model("House", parent)
	local roof = roofColor or rgb(200, 80, 70)
	Build.block(model, cframe * CFrame.new(0, 5, 0), Vector3.new(14, 10, 12), wallColor)
	Build.wedge(model, cframe * CFrame.new(0, 12.5, 3) * CFrame.Angles(0, math.rad(180), 0), Vector3.new(15, 5, 6.5), roof)
	Build.wedge(model, cframe * CFrame.new(0, 12.5, -3), Vector3.new(15, 5, 6.5), roof)
	Build.block(model, cframe * CFrame.new(0, 2.5, -6.05), Vector3.new(3, 5, 0.2), rgb(120, 70, 40))
	for _, x in { -4.5, 4.5 } do
		Build.block(model, cframe * CFrame.new(x, 6, -6.05), Vector3.new(2.6, 2.6, 0.2), rgb(170, 220, 255), Enum.Material.Glass)
		Build.block(model, cframe * CFrame.new(x, 6, -6.15), Vector3.new(2.9, 0.3, 0.1), rgb(255, 255, 255))
	end
	Build.block(model, cframe * CFrame.new(4, 13, 2), Vector3.new(1.6, 4, 1.6), rgb(150, 80, 60), Enum.Material.Brick)
	return model
end

function Props.wattersonHouse(parent: Instance, cframe: CFrame)
	local model = Props.house(parent, cframe, rgb(255, 214, 120), rgb(70, 140, 220))
	model.Name = "WattersonHouse"
	Build.label(model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart"), "THE WATTERSONS", {
		offset = Vector3.new(0, 9, 0),
		size = UDim2.fromOffset(300, 60),
		color = rgb(79, 183, 242),
	})
	return model
end

function Props.school(parent: Instance, cframe: CFrame)
	local model = Build.model("ElmoreJuniorHigh", parent)
	local brick = rgb(214, 120, 90)
	local main = Build.block(model, cframe * CFrame.new(0, 9, 0), Vector3.new(44, 18, 16), brick, Enum.Material.Brick)
	Build.block(model, cframe * CFrame.new(0, 18.6, 0), Vector3.new(46, 1.2, 18), rgb(240, 240, 240))
	Build.block(model, cframe * CFrame.new(0, 4.5, -8.2), Vector3.new(8, 9, 0.6), rgb(90, 160, 220))
	Build.block(model, cframe * CFrame.new(0, 4.5, -8.6), Vector3.new(0.3, 9, 0.2), INK)
	for _, x in { -16, -9, 9, 16 } do
		for _, y in { 6, 13 } do
			Build.block(model, cframe * CFrame.new(x, y, -8.05), Vector3.new(4, 3.2, 0.2), rgb(190, 230, 255), Enum.Material.Glass)
		end
	end
	local sign = Build.block(model, cframe * CFrame.new(0, 15.5, -8.3), Vector3.new(26, 3.4, 0.4), rgb(255, 214, 70))
	Build.label(sign, "ELMORE JUNIOR HIGH", { surface = true, face = Enum.NormalId.Front, color = rgb(40, 28, 60), strokeThickness = 0 })
	-- Clock tower
	Build.block(model, cframe * CFrame.new(0, 23, 0), Vector3.new(7, 9, 7), brick, Enum.Material.Brick)
	Build.cylinder(model, (cframe * CFrame.new(0, 24, -3.6)).Position, 0.4, 4.2, rgb(255, 255, 255))
	Build.wedge(model, cframe * CFrame.new(0, 29.5, 1.9) * CFrame.Angles(0, math.rad(180), 0), Vector3.new(8, 4, 3.8), rgb(70, 140, 220))
	Build.wedge(model, cframe * CFrame.new(0, 29.5, -1.9), Vector3.new(8, 4, 3.8), rgb(70, 140, 220))
	model.PrimaryPart = main
	return model
end

function Props.lockers(parent: Instance, cframe: CFrame, count: number?)
	local model = Build.model("Lockers", parent)
	for index = 0, (count or 4) - 1 do
		local x = (index - ((count or 4) - 1) / 2) * 1.9
		local color = if index % 2 == 0 then rgb(80, 150, 230) else rgb(100, 170, 240)
		Build.block(model, cframe * CFrame.new(x, 2.6, 0), Vector3.new(1.8, 5.2, 1.6), color, Enum.Material.Metal)
		Build.block(model, cframe * CFrame.new(x + 0.5, 3, -0.82), Vector3.new(0.2, 0.6, 0.1), rgb(230, 230, 240))
		for slit = 0, 2 do
			Build.block(model, cframe * CFrame.new(x, 4.4 - slit * 0.3, -0.82), Vector3.new(1.1, 0.1, 0.1), INK)
		end
	end
	return model
end

function Props.bus(parent: Instance, cframe: CFrame)
	local model = Build.model("SchoolBus", parent)
	local yellow = rgb(255, 204, 40)
	Build.block(model, cframe * CFrame.new(0, 3.6, 0), Vector3.new(6.4, 5, 18), yellow)
	Build.block(model, cframe * CFrame.new(0, 2.6, -10), Vector3.new(6.2, 3, 3), yellow)
	Build.block(model, cframe * CFrame.new(0, 2.2, 0), Vector3.new(6.6, 0.4, 18.2), INK)
	for z = -6, 6, 3 do
		for _, x in { -3.25, 3.25 } do
			Build.block(model, cframe * CFrame.new(x, 4.6, z), Vector3.new(0.2, 1.6, 2.2), rgb(170, 220, 255), Enum.Material.Glass)
		end
	end
	for _, z in { -7, 6 } do
		for _, x in { -3.2, 3.2 } do
			local wheel = Build.cylinder(model, (cframe * CFrame.new(x, 1.2, z)).Position, 2.4, 2.4, INK)
			wheel.CFrame = cframe * CFrame.new(x, 1.2, z)
		end
	end
	return model
end

function Props.shop(parent: Instance, cframe: CFrame, name: string, color: Color3)
	local model = Build.model("Shop_" .. name, parent)
	Build.block(model, cframe * CFrame.new(0, 6, 0), Vector3.new(16, 12, 8), rgb(250, 245, 235))
	Build.block(model, cframe * CFrame.new(0, 4, -4.05), Vector3.new(12, 6, 0.2), rgb(190, 230, 255), Enum.Material.Glass)
	for index = 0, 5 do
		local stripe = if index % 2 == 0 then color else rgb(255, 255, 255)
		Build.wedge(
			model,
			cframe * CFrame.new(-6.66 + index * 2.66, 8.2, -5.2) * CFrame.Angles(0, math.rad(180), 0),
			Vector3.new(2.66, 1.4, 2.4),
			stripe
		)
	end
	local sign = Build.block(model, cframe * CFrame.new(0, 10.4, -4.2), Vector3.new(14, 2.4, 0.4), color)
	Build.label(sign, name, { surface = true, face = Enum.NormalId.Front, color = rgb(255, 255, 255) })
	return model
end

function Props.fountain(parent: Instance, base: Vector3)
	local model = Build.model("Fountain", parent)
	Build.cylinder(model, base + Vector3.new(0, 0.8, 0), 1.6, 12, rgb(230, 230, 240), Enum.Material.Marble)
	local water = Build.cylinder(model, base + Vector3.new(0, 1.5, 0), 0.4, 10.8, rgb(90, 190, 255), Enum.Material.Glass)
	water.Transparency = 0.25
	Build.cylinder(model, base + Vector3.new(0, 3, 0), 3, 1.6, rgb(230, 230, 240), Enum.Material.Marble)
	Build.cylinder(model, base + Vector3.new(0, 4.6, 0), 0.5, 5, rgb(230, 230, 240), Enum.Material.Marble)
	local spout = Build.ball(model, base + Vector3.new(0, 5.6, 0), 1.6, rgb(120, 210, 255), Enum.Material.Glass)
	spout.Transparency = 0.2
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(rgb(180, 230, 255))
	emitter.Size = NumberSequence.new(0.5, 0.1)
	emitter.Speed = NumberRange.new(6, 9)
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.Acceleration = Vector3.new(0, -20, 0)
	emitter.Lifetime = NumberRange.new(0.8, 1.1)
	emitter.Rate = 25
	emitter.Parent = spout
	return model
end

function Props.lake(parent: Instance, base: Vector3, diameter: number)
	local model = Build.model("Lake", parent)
	Build.cylinder(model, base + Vector3.new(0, 0.05, 0), 0.3, diameter + 2, rgb(220, 200, 150), Enum.Material.Sand)
	local water = Build.cylinder(model, base + Vector3.new(0, 0.2, 0), 0.3, diameter, rgb(70, 160, 230), Enum.Material.Glass)
	water.Transparency = 0.15
	return model
end

function Props.floatingJunk(parent: Instance, base: Vector3, seed: number)
	local rng = Random.new(seed)
	local model = Build.model("VoidJunk", parent)
	local kind = rng:NextInteger(1, 4)
	local height = rng:NextNumber(3, 9)
	local cf = CFrame.new(base + Vector3.new(0, height, 0))
		* CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, 6.28), rng:NextNumber(-0.6, 0.6))
	if kind == 1 then -- old TV
		Build.block(model, cf, Vector3.new(4, 3.2, 3), rgb(90, 80, 110))
		Build.block(model, cf * CFrame.new(0, 0, -1.55), Vector3.new(3, 2.2, 0.1), rgb(180, 255, 230), Enum.Material.Neon)
	elseif kind == 2 then -- floppy disk
		Build.block(model, cf, Vector3.new(3.4, 0.3, 3.4), rgb(40, 40, 60))
		Build.block(model, cf * CFrame.new(0, 0.2, -0.8), Vector3.new(2, 0.1, 1.4), rgb(200, 200, 210), Enum.Material.Metal)
	elseif kind == 3 then -- lost sock
		Build.block(model, cf, Vector3.new(1.2, 3, 1.2), rgb(255, 255, 255), Enum.Material.Fabric)
		Build.block(model, cf * CFrame.new(0, -1.2, -0.9), Vector3.new(1.2, 1, 2), rgb(255, 90, 100), Enum.Material.Fabric)
	else -- glitch cube
		local cube = Build.block(model, cf, Vector3.new(2.4, 2.4, 2.4), rgb(200, 100, 255), Enum.Material.Neon)
		cube.Transparency = 0.2
	end
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
	return model
end

function Props.voidPortal(parent: Instance, cframe: CFrame, color: Color3?)
	local model = Build.model("VoidPortal", parent)
	local c = color or rgb(170, 80, 255)
	local segments = 16
	local radius = 4.2
	for index = 1, segments do
		local angle = (index / segments) * math.pi * 2
		local offset = Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius + radius + 0.5, 0)
		Build.part({
			Size = Vector3.new(1.8, 1.2, 1.2),
			CFrame = cframe * CFrame.new(offset) * CFrame.Angles(0, 0, angle + math.pi / 2),
			Color = c,
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, model)
	end
	local disc = Build.part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, radius * 2 - 1, radius * 2 - 1),
		CFrame = cframe * CFrame.new(0, radius + 0.5, 0) * CFrame.Angles(0, math.rad(90), 0),
		Color = rgb(30, 10, 50),
		Material = Enum.Material.Neon,
		Transparency = 0.15,
		CanCollide = false,
	}, model)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(c, rgb(255, 255, 255))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(0.8, 0)
	emitter.Speed = NumberRange.new(2, 5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Rate = 30
	emitter.Parent = disc
	local light = Instance.new("PointLight")
	light.Color = c
	light.Range = 18
	light.Brightness = 2
	light.Parent = disc
	return model
end

-- Big lobby Gumball Machine: glass globe full of gumballs on a red base.
function Props.gumballMachine(parent: Instance, base: Vector3, scale: number?)
	scale = scale or 1
	local model = Build.model("GumballMachine", parent)
	local red = rgb(230, 50, 60)
	Build.cylinder(model, base + Vector3.new(0, 1 * scale, 0), 2 * scale, 12 * scale, red)
	Build.block(model, CFrame.new(base + Vector3.new(0, 6 * scale, 0)), Vector3.new(9, 8, 9) * scale, red)
	Build.block(model, CFrame.new(base + Vector3.new(0, 5 * scale, -4.6 * scale)), Vector3.new(3, 3, 0.4) * scale, rgb(200, 200, 210), Enum.Material.Metal)
	local chute = Build.block(model, CFrame.new(base + Vector3.new(0, 2.6 * scale, -4.8 * scale)), Vector3.new(2.6, 1.4, 1.2) * scale, rgb(220, 220, 230), Enum.Material.Metal)
	chute.Name = "Chute"
	local crank = Build.cylinder(model, base + Vector3.new(0, 6.6 * scale, -4.9 * scale), 0.6 * scale, 2.6 * scale, rgb(255, 214, 70), Enum.Material.Metal)
	crank.CFrame = CFrame.new(base + Vector3.new(0, 6.6 * scale, -4.9 * scale)) * CFrame.Angles(0, math.rad(90), 0)
	crank.Name = "Crank"
	local globeCenter = base + Vector3.new(0, 16 * scale, 0)
	local globe = Build.ball(model, globeCenter, 14 * scale, rgb(220, 240, 255), Enum.Material.Glass)
	globe.Transparency = 0.55
	globe.Name = "Globe"
	local colors = {
		rgb(255, 84, 84),
		rgb(255, 166, 48),
		rgb(255, 232, 64),
		rgb(96, 226, 108),
		rgb(72, 190, 255),
		rgb(176, 108, 255),
		rgb(255, 120, 200),
	}
	local rng = Random.new(42)
	for index = 1, 46 do
		local r = 5 * scale * rng:NextNumber() ^ 0.5
		local theta = rng:NextNumber(0, math.pi * 2)
		local y = rng:NextNumber(-5.2, 1.5) * scale
		local position = globeCenter + Vector3.new(math.cos(theta) * r, y, math.sin(theta) * r)
		if (position - globeCenter).Magnitude < 6.2 * scale then
			Build.ball(model, position, 1.6 * scale, colors[(index % #colors) + 1])
		end
	end
	Build.cylinder(model, globeCenter + Vector3.new(0, 7 * scale, 0), 1 * scale, 3 * scale, red)
	model.PrimaryPart = globe
	return model
end

function Props.archSign(parent: Instance, cframe: CFrame, text: string)
	local model = Build.model("ArchSign", parent)
	local colors = { rgb(255, 84, 84), rgb(255, 166, 48), rgb(255, 232, 64), rgb(96, 226, 108), rgb(72, 190, 255), rgb(176, 108, 255) }
	for _, x in { -12, 12 } do
		Build.cylinder(model, (cframe * CFrame.new(x, 6, 0)).Position, 12, 1.6, rgb(255, 255, 255))
	end
	for index, color in colors do
		local y = 12 + index * 0.6
		Build.block(model, cframe * CFrame.new(0, y, 0), Vector3.new(26 - index * 0.4, 0.6, 1.2), color)
	end
	local board = Build.block(model, cframe * CFrame.new(0, 17.5, 0), Vector3.new(20, 4, 0.8), rgb(255, 248, 231))
	Build.label(board, text, { surface = true, face = Enum.NormalId.Front, color = rgb(79, 183, 242) })
	Build.label(board, text, { surface = true, face = Enum.NormalId.Back, color = rgb(79, 183, 242) })
	return model
end

return Props
