--!nonstrict
-- Labs: one private 2D physics room per player (6 per server). Handles building rooms, map
-- switching, visiting, lab commands (heal / reset / slow-mo / pause / undo), the per-lab clock,
-- FX broadcasting and the single Heartbeat loop that drives every gameplay system.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Maps = require(Shared.Data.Maps)

local ServerRoot = script.Parent.Parent
local World = require(ServerRoot.Systems.World)
local Physics2D = require(ServerRoot.Systems.Physics2D)
local LabFurniture = require(ServerRoot.Systems.LabFurniture)
local Builder = require(ServerRoot.Maps.Builder)

local LabService = {}

local labsFolder: Folder

local COMMAND_COOLDOWN = 0.25

function LabService:Init(services)
	self.S = services
	self._commandTimes = {}
	Physics2D.setupCollisionGroups()
	labsFolder = Instance.new("Folder")
	labsFolder.Name = "Labs"
	labsFolder.Parent = Workspace
end

function LabService:Start()
	local S = self.S
	S.DataService.ProfileLoaded:Connect(function(player, data)
		self:CreateLab(player, data)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_onPlayerRemoving(player)
	end)

	Net.event("Command").OnServerEvent:Connect(function(player, command, arg)
		if typeof(command) ~= "string" then
			return
		end
		local now = os.clock()
		if now - (self._commandTimes[player] or 0) < COMMAND_COOLDOWN then
			return
		end
		self._commandTimes[player] = now
		self:HandleCommand(player, command, arg)
	end)

	Net.func("Visit").OnServerInvoke = function(player, ownerUserId)
		return self:Visit(player, ownerUserId)
	end

	RunService.Heartbeat:Connect(function(dt)
		self:_step(math.min(dt, 1 / 20))
	end)
end

-- ─────────────────────────────── lab lifecycle ───────────────────────────────

local function freeSlot(): number?
	for slot = 0, Config.MaxLabs - 1 do
		if not World.labs[slot] then
			return slot
		end
	end
	return nil
end

function LabService:CreateLab(owner: Player, data)
	if World.ownerLab[owner] then
		return World.ownerLab[owner]
	end
	local slot = freeSlot()
	if not slot then
		warn("[LabService] no free lab slot for", owner.Name)
		return nil
	end
	local origin = Vector3.new(slot * Config.LabSpacing, 0, 0)
	local model = Instance.new("Model")
	model.Name = "Lab_" .. owner.UserId
	model:SetAttribute("OwnerId", owner.UserId)
	model:SetAttribute("Slot", slot)
	model.Parent = labsFolder

	local dynamic = Instance.new("Folder")
	dynamic.Name = "Dynamic"
	dynamic.Parent = model
	local effects = Instance.new("Folder")
	effects.Name = "Effects"
	effects.Parent = model

	local lab: any = {
		slot = slot,
		owner = owner,
		ownerId = owner.UserId,
		model = model,
		dynamic = dynamic,
		effects = effects,
		origin = origin,
		planeOrigin = Physics2D.createLabAnchor(model, origin),
		golems = {},
		props = {},
		puddles = {},
		projectiles = {},
		fields = {},
		zones = {},
		groupUsed = {},
		timeScale = 1,
		paused = false,
		clock = 0,
		spawnHistory = {},
		lastSpawn = { kind = "golem", id = data.equippedSkin },
		privacy = data.settings.privacy or "everyone",
		maxGolems = Config.MaxGolems,
		lastActor = nil,
		lastActionTime = 0,
		mapId = nil,
		trial = nil,
	}
	if self.S.ShopService and self.S.ShopService:HasPass(owner, "LabExpansion") then
		lab.maxGolems = Config.MaxGolemsExpanded
	end
	World.labs[slot] = lab
	World.ownerLab[owner] = lab
	World.viewLab[owner] = lab

	self:BuildRoom(lab, Config.DefaultMap)
	self.S.GolemService:Spawn(lab, data.equippedSkin)
	self:RefreshRack(lab)
	self:BroadcastState(lab)
	return lab
end

function LabService:_onPlayerRemoving(player: Player)
	self._commandTimes[player] = nil
	local owned = World.ownerLab[player]
	World.viewLab[player] = nil
	if self.S.GrabService then
		self.S.GrabService:ReleaseAllFor(player)
	end
	if owned then
		-- Send visitors home before the lab disappears.
		for _, viewer in World.viewers(owned) do
			if viewer ~= player then
				local home = World.ownerLab[viewer]
				World.viewLab[viewer] = home
				self:SendState(viewer)
				self.S.ShopService:Notify(
					viewer,
					"toast",
					{ text = player.DisplayName .. "'s lab closed. Back home!", kind = "info" }
				)
			end
		end
		self:DestroyLab(owned)
		World.ownerLab[player] = nil
	end
	-- Update visitor lists of any lab this player was viewing.
	for _, lab in World.labs do
		self:BroadcastState(lab)
	end
end

function LabService:DestroyLab(lab)
	self:ClearDynamic(lab)
	if self.S.HazardService then
		self.S.HazardService:UnregisterLab(lab)
	end
	World.labs[lab.slot] = nil
	lab.destroyed = true
	lab.model:Destroy()
end

-- ─────────────────────────────── rooms ───────────────────────────────

function LabService:BuildRoom(lab, mapId: string)
	local info = Maps.get(mapId)
	if lab.room then
		if self.S.HazardService then
			self.S.HazardService:UnregisterLab(lab)
		end
		lab.room:Destroy()
	end
	local room = Instance.new("Model")
	room.Name = "Room"
	room.Parent = lab.model
	lab.room = room
	lab.mapId = info.id
	lab.map = info

	local builderModule = ServerRoot.Maps:FindFirstChild(info.builder)
	local build = require(builderModule)
	local b = Builder.new(room, CFrame.new(lab.origin))
	local layout = build(b, info, Random.new(lab.slot * 7919 + #info.id))
	lab.layout = layout

	lab.cauldron = LabFurniture.cauldron(room, CFrame.new(lab.origin + layout.cauldron))
	lab.rack = LabFurniture.rack(room, CFrame.new(lab.origin + layout.rack))
	lab.minX = -info.width / 2
	lab.maxX = info.width / 2

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { room }
	params.RespectCanCollide = true
	lab.staticRayParams = params
	local allParams = RaycastParams.new()
	allParams.FilterType = Enum.RaycastFilterType.Include
	allParams.FilterDescendantsInstances = { room, lab.dynamic }
	allParams.RespectCanCollide = true
	lab.worldRayParams = allParams

	lab.model:SetAttribute("MapId", info.id)
	lab.model:SetAttribute("Width", info.width)
	lab.model:SetAttribute("Height", info.height)
	if self.S.HazardService then
		self.S.HazardService:RegisterLab(lab)
	end
	self:RefreshRack(lab)
end

function LabService:CanUseMap(player: Player, mapId: string): (boolean, string?)
	local info = Maps.ById[mapId]
	if not info then
		return false, "Unknown lab"
	end
	local data = self.S.DataService:Get(player)
	if not data then
		return false, "Loading..."
	end
	if data.level >= info.unlockLevel or data.maps[mapId] or self.S.ShopService:HasPass(player, "MasterKey") then
		return true
	end
	return false, ("Unlocks at level %d"):format(info.unlockLevel)
end

function LabService:SetMap(lab, mapId: string, options)
	local opts = options or {}
	if self.S.TrialService and lab.trial and not opts.fromTrial then
		self.S.TrialService:Abort(lab, "map")
	end
	self:SetPaused(lab, false)
	self:SetTimeScale(lab, 1)
	self:ClearDynamic(lab)
	self:BuildRoom(lab, mapId)
	if not opts.noGolem then
		local data = self.S.DataService:Get(lab.owner)
		self.S.GolemService:Spawn(lab, data and data.equippedSkin)
	end
	self:BroadcastState(lab)
end

-- Removes golems, props, puddles, projectiles and field effects.
function LabService:ClearDynamic(lab)
	if self.S.GrabService then
		self.S.GrabService:ReleaseLab(lab)
	end
	if self.S.EffectsService then
		self.S.EffectsService:ClearLab(lab)
	end
	self.S.GolemService:ClearAll(lab)
	if self.S.PropService then
		self.S.PropService:ClearAll(lab)
	end
	table.clear(lab.projectiles)
	table.clear(lab.spawnHistory)
	lab.dynamic:ClearAllChildren()
	lab.effects:ClearAllChildren()
	lab.frozenParts = nil
end

function LabService:Reset(lab)
	local skin = if lab.lastSpawn.kind == "golem" then lab.lastSpawn.id else nil
	self:SetPaused(lab, false)
	self:SetTimeScale(lab, 1)
	self:ClearDynamic(lab)
	local data = self.S.DataService:Get(lab.owner)
	self.S.GolemService:Spawn(lab, skin or (data and data.equippedSkin))
	self:FX(lab, "reset", { p = lab.origin + Vector3.new(0, lab.map.height / 2, 0) })
	self:BroadcastState(lab)
end

-- Shows the owner's free ingredient stock as jars on the rack.
function LabService:RefreshRack(lab)
	local rack = lab.rack
	local data = self.S.DataService and self.S.DataService:Get(lab.owner)
	if not rack or not data then
		return
	end
	local stock = data.rack.stock
	local palette = {
		Color3.fromRGB(255, 122, 44),
		Color3.fromRGB(122, 214, 255),
		Color3.fromRGB(214, 247, 255),
		Color3.fromRGB(96, 232, 96),
		Color3.fromRGB(96, 146, 255),
		Color3.fromRGB(255, 140, 232),
	}
	for i = 1, 6 do
		local content = rack:FindFirstChild("JarContent" .. i)
		if content then
			content.Transparency = if i <= stock then 0.05 else 1
			content.Color = palette[i]
		end
	end
end

-- ─────────────────────────────── time control ───────────────────────────────

local function forEachAssembly(lab, fn: (BasePart) -> ())
	local seen = {}
	local function visit(object)
		for _, part in object.parts do
			if part.Parent and not part.Anchored then
				local root = part.AssemblyRootPart or part
				if not seen[root] then
					seen[root] = true
					fn(root)
				end
			end
		end
	end
	for _, golem in lab.golems do
		visit(golem)
	end
	for _, prop in lab.props do
		visit(prop)
	end
end

function LabService:SetTimeScale(lab, scale: number)
	local old = lab.timeScale
	if math.abs(old - scale) < 1e-3 then
		return
	end
	local ratio = scale / old
	lab.timeScale = scale
	if lab.paused and lab.frozenParts then
		for _, record in lab.frozenParts do
			record.v *= ratio
			record.w *= ratio
		end
	else
		forEachAssembly(lab, function(root)
			root.AssemblyLinearVelocity *= ratio
			root.AssemblyAngularVelocity *= ratio
		end)
	end
	-- Projectiles integrate in lab-time, so their velocities are already time-scale independent.
	for _, golem in lab.golems do
		self.S.GolemService:RefreshGravity(golem)
		self.S.GolemService:ApplyActuators(golem, true)
		self.S.GolemService:_updateUpright(golem)
		self.S.GolemService:ResetMotionHistory(golem, 0.2)
	end
	if self.S.PropService then
		self.S.PropService:RefreshGravity(lab)
	end
	if self.S.EffectsService then
		self.S.EffectsService:OnTimeScale(lab, ratio)
	end
	self:BroadcastState(lab)
end

function LabService:FreezeObject(lab, object)
	if not lab.paused then
		return
	end
	lab.frozenParts = lab.frozenParts or {}
	for _, part in object.parts do
		if part.Parent and not part.Anchored then
			lab.frozenParts[part] = { v = part.AssemblyLinearVelocity, w = part.AssemblyAngularVelocity }
			part.Anchored = true
		end
	end
end

function LabService:UnfreezeObject(lab, object)
	if not lab.frozenParts then
		return
	end
	for _, part in object.parts do
		local record = lab.frozenParts[part]
		if record then
			lab.frozenParts[part] = nil
			if part.Parent then
				part.Anchored = false
			end
		end
	end
end

function LabService:SetPaused(lab, paused: boolean)
	if lab.paused == paused then
		return
	end
	if paused then
		lab.paused = true
		lab.frozenParts = {}
		for _, golem in lab.golems do
			self:FreezeObject(lab, golem)
		end
		for _, prop in lab.props do
			if not prop.static then
				self:FreezeObject(lab, prop)
			end
		end
	else
		lab.paused = false
		local frozen = lab.frozenParts or {}
		lab.frozenParts = nil
		local parts = {}
		for part in frozen do
			if part.Parent then
				part.Anchored = false
				table.insert(parts, part)
			end
		end
		for part, record in frozen do
			if part.Parent then
				part.AssemblyLinearVelocity = record.v
				part.AssemblyAngularVelocity = record.w
			end
		end
		Physics2D.setOwner(parts, nil)
		for _, golem in lab.golems do
			self.S.GolemService:ResetMotionHistory(golem, 0.25)
		end
	end
	self:BroadcastState(lab)
end

-- ─────────────────────────────── commands ───────────────────────────────

function LabService:IsOwner(player: Player, lab): boolean
	return lab ~= nil and lab.owner == player
end

function LabService:MarkAction(lab, player: Player?)
	if player then
		lab.lastActor = player
		lab.lastActionTime = os.clock()
	end
end

function LabService:HandleCommand(player: Player, command: string, arg: any)
	local lab = World.viewLab[player]
	if not lab or lab.destroyed then
		return
	end
	local owner = self:IsOwner(player, lab)
	local inTrial = lab.trial ~= nil
	self:MarkAction(lab, player)

	if command == "heal" then
		self.S.GolemService:HealAll(lab)
		self:FX(lab, "healall", {})
	elseif command == "reset" then
		if not owner then
			self:_deny(player, "Only the lab owner can reset the room.")
			return
		end
		if inTrial then
			self.S.TrialService:Restart(lab)
		else
			self:Reset(lab)
		end
	elseif command == "slowmo" then
		if not owner then
			self:_deny(player, "Only the lab owner can bend time here.")
			return
		end
		self:SetTimeScale(lab, if lab.timeScale < 1 then 1 else Config.Physics.SlowMoScale)
	elseif command == "pause" then
		if not owner then
			self:_deny(player, "Only the lab owner can stop time here.")
			return
		end
		self:SetPaused(lab, not lab.paused)
	elseif command == "undo" then
		self:Undo(lab, player)
	elseif command == "spawnLast" then
		if inTrial then
			self:_deny(player, "Spawning is disabled during trials.")
			return
		end
		local last = lab.lastSpawn
		if last.kind == "golem" then
			self:SpawnGolemFor(player, lab, last.id, nil)
		elseif last.kind == "prop" and self.S.PropService then
			self.S.PropService:SpawnFor(player, lab, last.id, nil)
		end
	elseif command == "clearZombies" then
		if self.S.EffectsService then
			self.S.EffectsService:CureAllZombies(lab)
		end
	elseif command == "clearProps" then
		if not owner then
			return
		end
		if self.S.PropService then
			self.S.PropService:ClearAll(lab)
		end
	elseif command == "setMap" then
		if not owner or typeof(arg) ~= "string" then
			return
		end
		if inTrial then
			self:_deny(player, "Finish or quit the trial first.")
			return
		end
		local ok, reason = self:CanUseMap(player, arg)
		if not ok then
			self:_deny(player, reason or "Locked")
			return
		end
		self:SetMap(lab, arg)
	elseif command == "privacy" then
		if typeof(arg) ~= "string" or (arg ~= "everyone" and arg ~= "friends" and arg ~= "nobody") then
			return
		end
		local own = World.ownerLab[player]
		if own then
			own.privacy = arg
			local data = self.S.DataService:Get(player)
			if data then
				data.settings.privacy = arg
				self.S.DataService:Replicate(player, "settings")
			end
			if arg ~= "everyone" then
				for _, viewer in World.viewers(own) do
					if viewer ~= player and (arg == "nobody" or not viewer:IsFriendsWithAsync(player.UserId)) then
						self:GoHome(viewer, "The lab owner closed their lab.")
					end
				end
			end
			self:BroadcastState(own)
		end
	elseif command == "home" then
		self:GoHome(player)
	end
end

function LabService:_deny(player: Player, text: string)
	self.S.ShopService:Notify(player, "toast", { text = text, kind = "error" })
end

function LabService:SpawnGolemFor(player: Player, lab, skinId: string?, localPos: Vector3?)
	local data = self.S.DataService:Get(player)
	if not data then
		return nil
	end
	skinId = skinId or data.equippedSkin
	if not data.skins[skinId] then
		skinId = data.equippedSkin
	end
	local golem, err = self.S.GolemService:Spawn(lab, skinId, localPos, { source = player })
	if not golem then
		self:_deny(player, err or "Can't spawn")
		return nil
	end
	lab.lastSpawn = { kind = "golem", id = skinId }
	table.insert(lab.spawnHistory, { kind = "golem", ref = golem })
	data.stats.golemsSpawned += 1
	self:FX(lab, "spawn", { p = golem.byName.Torso.Position, c = golem.skin.accent })
	return golem
end

function LabService:Undo(lab, player: Player)
	while #lab.spawnHistory > 0 do
		local entry = table.remove(lab.spawnHistory)
		local ref = entry.ref
		if entry.kind == "golem" and ref and not ref.dead then
			local position = ref.byName.Torso and ref.byName.Torso.Position
			self.S.GolemService:Despawn(ref)
			if position then
				self:FX(lab, "poof", { p = position })
			end
			return
		elseif entry.kind == "prop" and ref and not ref.dead and self.S.PropService then
			local position = ref.root and ref.root.Position
			self.S.PropService:Despawn(ref)
			if position then
				self:FX(lab, "poof", { p = position })
			end
			return
		end
	end
	self:_deny(player, "Nothing to undo.")
end

-- ─────────────────────────────── visiting ───────────────────────────────

function LabService:Visit(player: Player, ownerUserId: any)
	if typeof(ownerUserId) ~= "number" then
		return { ok = false, reason = "Invalid lab" }
	end
	if ownerUserId == player.UserId then
		self:GoHome(player)
		return { ok = true }
	end
	local target
	for _, lab in World.labs do
		if lab.ownerId == ownerUserId then
			target = lab
		end
	end
	if not target then
		return { ok = false, reason = "That lab is closed." }
	end
	if target.privacy == "nobody" then
		return { ok = false, reason = "That lab is private." }
	end
	if target.privacy == "friends" then
		local ok, isFriend = pcall(player.IsFriendsWithAsync, player, ownerUserId)
		if not ok or not isFriend then
			return { ok = false, reason = "Friends only!" }
		end
	end
	if self.S.GrabService then
		self.S.GrabService:ReleaseAllFor(player)
	end
	local previous = World.viewLab[player]
	World.viewLab[player] = target
	self:SendState(player)
	self:BroadcastState(target)
	if previous and previous ~= target then
		self:BroadcastState(previous)
	end
	self.S.ShopService:Notify(
		target.owner,
		"toast",
		{ text = player.DisplayName .. " is visiting your lab!", kind = "social" }
	)
	return { ok = true }
end

function LabService:GoHome(player: Player, reason: string?)
	local home = World.ownerLab[player]
	if not home then
		return
	end
	if self.S.GrabService then
		self.S.GrabService:ReleaseAllFor(player)
	end
	local previous = World.viewLab[player]
	World.viewLab[player] = home
	self:SendState(player)
	if previous and previous ~= home then
		self:BroadcastState(previous)
	end
	if reason then
		self.S.ShopService:Notify(player, "toast", { text = reason, kind = "info" })
	end
end

-- ─────────────────────────────── replication ───────────────────────────────

function LabService:StateFor(lab, player: Player)
	local visitors = {}
	for _, viewer in World.viewers(lab) do
		table.insert(visitors, { userId = viewer.UserId, name = viewer.DisplayName })
	end
	local open = {}
	for _, other in World.labs do
		if other ~= lab then
			table.insert(
				open,
				{ userId = other.ownerId, name = other.owner.DisplayName, privacy = other.privacy, mapId = other.mapId }
			)
		end
	end
	return {
		slot = lab.slot,
		ownerId = lab.ownerId,
		ownerName = lab.owner.DisplayName,
		isOwner = lab.owner == player,
		origin = lab.origin,
		mapId = lab.mapId,
		width = lab.map.width,
		height = lab.map.height,
		paused = lab.paused,
		slowmo = lab.timeScale < 1,
		timeScale = lab.timeScale,
		privacy = lab.privacy,
		visitors = visitors,
		labs = open,
		golems = self.S.GolemService.Count(lab),
		maxGolems = lab.maxGolems,
		trial = if lab.trial then lab.trial.id else nil,
		cauldron = lab.origin + lab.layout.cauldron,
		rack = lab.origin + lab.layout.rack,
	}
end

function LabService:SendState(player: Player)
	local lab = World.viewLab[player]
	if lab and not lab.destroyed then
		Net.event("Lab"):FireClient(player, self:StateFor(lab, player))
	end
end

function LabService:BroadcastState(lab)
	if lab.destroyed then
		return
	end
	for _, viewer in World.viewers(lab) do
		Net.event("Lab"):FireClient(viewer, self:StateFor(lab, viewer))
	end
end

function LabService:FX(lab, kind: string, payload: { [string]: any })
	local remote = Net.event("FX")
	for _, viewer in World.viewers(lab) do
		remote:FireClient(viewer, kind, payload)
	end
end

function LabService:FXU(lab, kind: string, payload: { [string]: any })
	local remote = Net.unreliable("FXU")
	for _, viewer in World.viewers(lab) do
		remote:FireClient(viewer, kind, payload)
	end
end

-- ─────────────────────────────── main loop ───────────────────────────────

function LabService:_step(dt: number)
	local S = self.S
	for _, lab in World.labs do
		if lab.destroyed then
			continue
		end
		local labDt = if lab.paused then 0 else dt * lab.timeScale
		lab.clock += labDt
		local ok, err = pcall(function()
			S.GolemService:Update(lab, dt, labDt)
			if S.PropService then
				S.PropService:Update(lab, dt, labDt)
			end
			if S.EffectsService then
				S.EffectsService:Update(lab, dt, labDt)
			end
			if S.PotionService then
				S.PotionService:Update(lab, dt, labDt)
			end
			if S.HazardService then
				S.HazardService:Update(lab, dt, labDt)
			end
			if S.TrialService then
				S.TrialService:Update(lab, dt, labDt)
			end
		end)
		if not ok then
			warn("[LabService] update error in lab", lab.slot, err)
		end
	end
end

return LabService
