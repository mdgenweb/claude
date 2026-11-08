--!nonstrict
-- 2D physics on top of Roblox's 3D solver.
--  * PlaneConstraint keeps every dynamic part on its lab's Z plane (translation only).
--  * A rigid AlignOrientation (PrimaryAxisParallel) on free bodies keeps their local Z parallel
--    to world Z, so they only rotate around Z.
--  * A per-assembly VectorForce implements per-lab/per-object gravity scaling, which is how slow
--    motion (g·s²), levitation, gravity flip and low-gravity rooms work without touching
--    workspace.Gravity (which is global to the server).

local Workspace = game:GetService("Workspace")
local PhysicsService = game:GetService("PhysicsService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Physics2D = {}

-- Rotation whose X axis is world +Z (the plane normal) and Y axis is world up.
Physics2D.PlaneRotation = CFrame.fromMatrix(Vector3.zero, Vector3.zAxis, Vector3.yAxis)
-- Rotation whose X axis is world up; used by "keep upright" controllers.
Physics2D.UpRotation = CFrame.fromMatrix(Vector3.zero, Vector3.yAxis, -Vector3.xAxis)

Physics2D.GolemGroups = {} :: { string }

function Physics2D.setupCollisionGroups()
	local function register(name: string)
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	register("Static")
	register("Props")
	register("Debris")
	register("NoCollide")
	for i = 1, Config.MaxGolemsExpanded do
		local name = "Golem" .. i
		register(name)
		Physics2D.GolemGroups[i] = name
	end
	-- A golem's own limbs overlap in 2D, so they must not collide with each other.
	for i = 1, Config.MaxGolemsExpanded do
		PhysicsService:CollisionGroupSetCollidable("Golem" .. i, "Golem" .. i, false)
	end
	PhysicsService:CollisionGroupSetCollidable("Debris", "Debris", false)
	PhysicsService:CollisionGroupSetCollidable("Debris", "Props", false)
	for i = 1, Config.MaxGolemsExpanded do
		PhysicsService:CollisionGroupSetCollidable("Debris", "Golem" .. i, false)
	end
	for _, group in PhysicsService:GetRegisteredCollisionGroups() do
		PhysicsService:CollisionGroupSetCollidable("NoCollide", group.name, false)
	end
end

-- The anchored part that owns the plane origin attachment for one lab.
function Physics2D.createLabAnchor(parent: Instance, origin: Vector3): Attachment
	local anchor = Instance.new("Part")
	anchor.Name = "PlaneAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(origin)
	anchor.Parent = parent
	local attachment = Instance.new("Attachment")
	attachment.Name = "PlaneOrigin"
	attachment.CFrame = Physics2D.PlaneRotation
	attachment.Parent = anchor
	return attachment
end

-- Attachment at the part centre whose WORLD orientation is the plane frame (X = world Z).
local function planeAttachment(part: BasePart): Attachment
	local existing = part:FindFirstChild("Plane2D")
	if existing and existing:IsA("Attachment") then
		return existing
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "Plane2D"
	attachment.CFrame = part.CFrame:ToObjectSpace(CFrame.new(part.Position) * Physics2D.PlaneRotation)
	attachment.Parent = part
	return attachment
end
Physics2D.planeAttachment = planeAttachment

export type AttachOptions = {
	lockRotation: boolean?,
	gravity: boolean?,
}

-- Locks a part to the lab plane. Call while the part is already on the plane (Z = 0).
function Physics2D.attach(part: BasePart, planeOrigin: Attachment, options: AttachOptions?)
	local opts = options or {}
	local attachment = planeAttachment(part)

	local plane = Instance.new("PlaneConstraint")
	plane.Name = "Plane2D"
	plane.Attachment0 = planeOrigin
	plane.Attachment1 = attachment
	plane.Visible = false
	plane.Parent = part

	if opts.lockRotation ~= false then
		local lock = Instance.new("AlignOrientation")
		lock.Name = "Lock2D"
		lock.Mode = Enum.OrientationAlignmentMode.OneAttachment
		lock.AlignType = Enum.AlignType.PrimaryAxisParallel
		lock.Attachment0 = attachment
		lock.PrimaryAxis = Vector3.zAxis
		lock.RigidityEnabled = true
		lock.Parent = part
	end

	if opts.gravity ~= false then
		local force = Instance.new("VectorForce")
		force.Name = "Gravity2D"
		force.Attachment0 = attachment
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		force.ApplyAtCenterOfMass = true
		force.Force = Vector3.zero
		force.Parent = part
	end
	return attachment
end

-- Sets the effective gravity of one assembly to `scale * g` (negative = upwards).
function Physics2D.setGravityScale(part: BasePart, scale: number)
	local force = part:FindFirstChild("Gravity2D")
	if not force then
		return
	end
	-- Exactly one Gravity2D exists per assembly, so the whole assembly mass is compensated here.
	local g = Workspace.Gravity
	local mass = part.AssemblyMass
	if mass ~= mass or mass == math.huge then
		return -- anchored / invalid
	end
	local target = Vector3.new(0, mass * g * (1 - scale), 0)
	if (force.Force - target).Magnitude > 0.01 then
		force.Force = target
	end
end

function Physics2D.removePlane(part: BasePart)
	for _, name in { "Plane2D", "Lock2D", "Gravity2D" } do
		for _, child in part:GetChildren() do
			if child.Name == name and not child:IsA("Attachment") then
				child:Destroy()
			end
		end
	end
end

-- Server-authoritative impulse. Reclaims network ownership first so the impulse is not lost.
function Physics2D.impulse(part: BasePart, impulse: Vector3)
	if part.Anchored then
		return
	end
	if part:CanSetNetworkOwnership() then
		local owner = part:GetNetworkOwner()
		if owner ~= nil then
			pcall(part.SetNetworkOwner, part, nil)
		end
	end
	part:ApplyImpulse(Vector3.new(impulse.X, impulse.Y, 0))
end

function Physics2D.setVelocity(part: BasePart, velocity: Vector3)
	if part.Anchored then
		return
	end
	part.AssemblyLinearVelocity = Vector3.new(velocity.X, velocity.Y, 0)
end

function Physics2D.setOwner(parts: { BasePart }, player: Player?)
	for _, part in parts do
		if part.Parent and not part.Anchored and part:CanSetNetworkOwnership() then
			pcall(part.SetNetworkOwner, part, player)
		end
	end
end

-- Projects a world point onto the lab plane.
function Physics2D.flatten(position: Vector3, planeZ: number): Vector3
	return Vector3.new(position.X, position.Y, planeZ)
end

return Physics2D
