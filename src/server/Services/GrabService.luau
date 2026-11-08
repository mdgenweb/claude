--!nonstrict
-- Grab & fling. The grabbing client receives network ownership of the object so dragging is
-- latency-free (the client drives an AlignPosition locally). Ownership returns to the server
-- shortly after release so potion effects stay server-authoritative.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local Systems = script.Parent.Parent.Systems
local World = require(Systems.World)
local Physics2D = require(Systems.Physics2D)

local P = Config.Physics
local GrabService = {
	held = {} :: { [Player]: any },
}

function GrabService:Init(services)
	self.S = services
	self._lastGrab = {}
end

function GrabService:Start()
	Net.func("Grab").OnServerInvoke = function(player, part, offset)
		return self:_grab(player, part, offset)
	end
	Net.event("GrabRelease").OnServerEvent:Connect(function(player)
		self:Release(player)
	end)
end

local function rootOf(object): BasePart?
	if object.kind == "golem" then
		return object.byName and object.byName.Torso
	end
	return object.root
end

function GrabService:_grab(player: Player, part: any, offset: any)
	if typeof(part) ~= "Instance" or not part:IsA("BasePart") then
		return false
	end
	if offset ~= nil and typeof(offset) ~= "Vector3" then
		return false
	end
	local now = os.clock()
	if now - (self._lastGrab[player] or 0) < 0.08 then
		return false
	end
	self._lastGrab[player] = now

	local object = World.objectFromPart(part)
	local lab = World.viewLab[player]
	if not object or object.dead or object.static or object.lab ~= lab then
		return false
	end
	if object.grabbedBy and object.grabbedBy ~= player then
		return false
	end
	if object.kind == "golem" and object.rigid and object.statuses.stasis then
		return false
	end
	local current = self.held[player]
	if current and current ~= object then
		self:Release(player)
	end

	if lab.paused then
		self.S.LabService:UnfreezeObject(lab, object)
	end
	object.grabbedBy = player
	object.ownerToken = nil
	self.held[player] = object
	Physics2D.setOwner(object.parts, player)
	self.S.LabService:MarkAction(lab, player)

	if object.kind == "golem" then
		local golems = self.S.GolemService
		golems:Touch(object, player)
		golems:ResetMotionHistory(object, 0.25)
		if object.state ~= "ko" and object.state ~= "controlled" then
			golems:Stun(object, P.StunTime)
		end
		golems:_updateUpright(object)
	else
		object.lastActor = player
		object.lastActorTime = now
	end
	return true
end

function GrabService:Release(player: Player)
	local object = self.held[player]
	if not object then
		return
	end
	self.held[player] = nil
	if object.grabbedBy ~= player then
		return
	end
	object.grabbedBy = nil
	object.lastGrabber = player
	local lab = object.lab

	if object.kind == "golem" then
		self.S.GolemService:Touch(object, player)
		self.S.GolemService:_updateUpright(object)
		self.S.GolemService:ResetMotionHistory(object, 0.2)
	end

	if lab.paused then
		-- Time is stopped: the object freezes where it was dropped.
		Physics2D.setOwner(object.parts, nil)
		self.S.LabService:FreezeObject(lab, object)
		return
	end

	-- Measure the fling a moment later (the client applies its fling velocity on release).
	task.delay(0.12, function()
		if object.dead or not player.Parent then
			return
		end
		local root = rootOf(object)
		if root and root.Parent then
			local speed = root.AssemblyLinearVelocity.Magnitude / math.max(lab.timeScale, 0.05)
			if object.kind == "golem" then
				self.S.ChallengeService:Event(player, "fling", speed)
				if speed > 120 then
					self.S.EconomyService:AddChaos(player, math.floor(speed * 0.6), lab)
				end
			end
		end
	end)

	local token = {}
	object.ownerToken = token
	task.delay(P.OwnershipReturnDelay, function()
		if object.ownerToken == token and not object.grabbedBy and not object.dead then
			object.ownerToken = nil
			Physics2D.setOwner(object.parts, nil)
			if object.kind == "golem" then
				self.S.GolemService:ResetMotionHistory(object, 0.15)
			end
		end
	end)
end

-- Server needs authority right now (e.g. an explosion hits a held object).
function GrabService:ForceRelease(object)
	local player = object.grabbedBy
	if player then
		self.held[player] = nil
		object.grabbedBy = nil
		if player.Parent then
			Net.event("FX"):FireClient(player, "drop", {})
		end
	end
	object.ownerToken = nil
	if not object.dead then
		Physics2D.setOwner(object.parts, nil)
		if object.kind == "golem" then
			self.S.GolemService:ResetMotionHistory(object, 0.15)
			self.S.GolemService:_updateUpright(object)
		end
	end
end

function GrabService:ReleaseAllFor(player: Player)
	local object = self.held[player]
	if object then
		self:ForceRelease(object)
	end
	self.held[player] = nil
	self._lastGrab[player] = nil
end

function GrabService:ReleaseLab(lab)
	for player, object in table.clone(self.held) do
		if object.lab == lab then
			self:ForceRelease(object)
			self.held[player] = nil
		end
	end
end

-- Ensures the server can apply impulses to this object (reclaims ownership if needed).
function GrabService:Claim(object)
	if object.grabbedBy then
		self:ForceRelease(object)
	elseif object.ownerToken then
		object.ownerToken = nil
		Physics2D.setOwner(object.parts, nil)
	end
end

return GrabService
