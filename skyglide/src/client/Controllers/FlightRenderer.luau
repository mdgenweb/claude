--!strict
-- Draws glider flights from the server's flight plans (cosmetic only; the server pays every ring
-- and landing from the same plan). Every flight in the local player's world gets a pooled glider
-- model and a trail, positioned each frame from t = GetServerTimeNow() - plan.Start. The local
-- player's own flight also gets thermal rings, gust windows, ring bursts with "+N" popups, zone
-- crossings, wind audio, speed lines and a big splash.
--
-- Bus events fired here: FlightStarted(plan, isLocal), FlightProgress(meters, plan),
-- ZoneEntered(zone), GustWindow(open, idx), RingPassed(idx, perfect, pos), RingResult(payload),
-- FlightLanded(owner payload), FlightEnded(plan, isLocal).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Flight = require(Shared.Config.Flight)
local Map = require(Shared.Config.Map)
local FlightSim = require(Shared.Sim.FlightSim)
local Remotes = require(Shared.Net.Remotes)
local Format = require(Shared.Util.Format)
local Worlds = require(Shared.Definitions.Worlds)
local Zones = require(Shared.Definitions.Zones)
local Trails = require(Shared.Definitions.Trails)
local Themes = require(Shared.Visual.Themes)
local GliderFactory = require(Shared.Visual.GliderFactory)

local Client = script.Parent.Parent
local Theme = require(Client.UI.Theme)
local Effects = require(Client.VFX.Effects)
local FlightFX = require(Client.VFX.FlightFX)
local ThermalRings = require(Client.VFX.ThermalRings)
local Bus = require(script.Parent.Bus)
local StateController = require(script.Parent.StateController)
local AudioController = require(script.Parent.AudioController)
local ThrowController = require(script.Parent.ThrowController)

local FlightRenderer = {}

local LocalPlayer = Players.LocalPlayer

local GLIDER_LENGTH = 4
local MAX_REMOTE = 10
local POOL_PER_GLIDER = 4
local HAND_BLEND = 0.3 -- seconds to blend from the hand onto the flight path
local LOOKAHEAD = 0.05 -- seconds ahead sampled for orientation / velocity
local LOCAL_END_DELAY = 0.8 -- splash hold before FlightEnded (local)
local REMOTE_END_DELAY = 0.6
local BURST_TIME = 0.35
local RING_SPIN = 0.6 -- rad/s
local SINK_SPEED = 2.2 -- studs/s the landed glider sinks
local WHITE = Color3.new(1, 1, 1)
local GOLD = Theme.Colors.Skill
local MISS_RED = Theme.Colors.Danger

export type LocalState = {
	Active: boolean,
	Plan: FlightSim.Plan?,
	Position: Vector3, -- glider position (world)
	Velocity: Vector3, -- studs/s along the path
	Speed: number,
	Landed: boolean,
	LandPosition: Vector3,
}

type Rig = {
	Id: string,
	Model: Model,
	Root: BasePart,
	Trail: Trail,
	A0: Attachment,
	A1: Attachment,
	Sparks: ParticleEmitter,
	Lift: ParticleEmitter,
	Aura: ParticleEmitter,
}

type RingView = {
	Ring: ThermalRings.Ring,
	Center: Vector3,
	State: string, -- "Idle" | "Open" | "Perfect" | "Miss" | "Burst"
	BurstAt: number,
	BurstScale: number,
	Released: boolean,
}

type View = {
	Plan: FlightSim.Plan,
	IsLocal: boolean,
	Scale: number, -- world DistanceScale
	Rig: Rig,
	Hand: Vector3?,
	Held: Model?, -- remote thrower's held glider (hidden during the flight)
	TrailArmed: boolean,
	LastCF: CFrame,
	Landed: boolean,
	LandPos: Vector3,
	LandedAt: number, -- os.clock()
	EndAt: number, -- os.clock(); 0 while flying
	WaterColor: Color3,
	-- local flight only
	Rings: { RingView },
	RingColor: Color3,
	NextPass: number,
	OpenRing: number, -- 0 = no gust window open
	Combo: number,
	Zones: { Zones.Zone },
	ZoneIndex: number,
	Shown: { [number]: string }, -- ring -> "plus" | "max" (what the pass popup showed)
	ShownPerfect: { [number]: boolean },
}

local views: { [number]: View } = {}
local localView: View? = nil
local ending: { View } = {}
local rigPool: { [string]: { Rig } } = {}
local trailCache: { [string]: ColorSequence } = {}
local flightsFolder: Folder? = nil

local localState: LocalState = {
	Active = false,
	Plan = nil,
	Position = Vector3.zero,
	Velocity = Vector3.zero,
	Speed = 0,
	Landed = false,
	LandPosition = Vector3.zero,
}

--------------------------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------------------------

local function getFolder(): Folder
	local f = flightsFolder
	if f and f.Parent then
		return f
	end
	local created = Instance.new("Folder")
	created.Name = "Flights"
	created.Parent = Effects.Folder()
	flightsFolder = created
	return created
end

local function currentWorld(): number?
	local data = StateController.Data
	if data and type(data.World) == "number" then
		return data.World
	end
	return nil
end

local function themeFor(worldId: number): Themes.Theme
	local world = Worlds.Get(worldId) or Worlds.List[1]
	return Themes[world.Theme] or Themes.Isles
end

-- Same path as FlightSim.Sample (lateral sway, altitude, distance along the channel) without
-- allocating a sample table. Returns the world position and the lateral offset.
local function pathPoint(plan: FlightSim.Plan, t: number): (Vector3, number)
	local u = FlightSim.Progress(t, plan.Duration)
	local x = plan.Sway * math.sin(u * math.pi * plan.SwayFreq * 2) * (1 - u)
	return Map.ChannelPoint(plan.World, x, FlightSim.Altitude(plan, u), plan.Length * u), x
end

local function ringCenter(plan: FlightSim.Plan, u: number): Vector3
	local x = plan.Sway * math.sin(u * math.pi * plan.SwayFreq * 2) * (1 - u)
	return Map.ChannelPoint(plan.World, x, FlightSim.Altitude(plan, u), u * plan.Length)
end

-- Where the thrower's glider leaves the hand (held glider, then hand), plus the held glider model.
local function handOf(userId: number): (Vector3?, Model?)
	local player = Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	if not character then
		return nil, nil
	end
	local held = character:FindFirstChild("HeldGlider")
	if held and held:IsA("Model") then
		return held:GetPivot().Position, held
	end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if hand and hand:IsA("BasePart") then
		return hand.Position, nil
	end
	return nil, nil
end

-- Local-only hide of a remote thrower's held glider while their thrown copy flies.
local function setHeldHidden(model: Model, hidden: boolean)
	local value = if hidden then 1 else 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = value
		end
	end
end

local function trailSequence(id: string?): ColorSequence?
	if not id then
		return nil
	end
	local cached = trailCache[id]
	if cached then
		return cached
	end
	local def = Trails.Get(id)
	if not def or #def.Colors == 0 then
		return nil
	end
	local seq: ColorSequence
	if #def.Colors == 1 then
		seq = ColorSequence.new(Color3.fromHex(def.Colors[1]))
	else
		local points = table.create(#def.Colors)
		for i, hex in def.Colors do
			points[i] = ColorSequenceKeypoint.new((i - 1) / (#def.Colors - 1), Color3.fromHex(hex))
		end
		seq = ColorSequence.new(points)
	end
	trailCache[id] = seq
	return seq
end

local function predictedRingSkill(perfect: boolean): (number, boolean)
	local data = StateController.Data
	local derived = StateController.Derived()
	local level = if data then tonumber(data.Level) else nil
	local cap = tonumber(derived.LevelCap)
	if level and cap and level >= cap then
		return 0, true
	end
	local perRing = tonumber(derived.SkillPerRing) or 1
	local multiplier = tonumber(derived.SkillMultiplier) or 1
	return perRing * multiplier * (if perfect then Flight.PerfectMultiplier else 1), false
end

--------------------------------------------------------------------------------------------------
-- Glider rigs (pooled per glider id)
--------------------------------------------------------------------------------------------------

local function emitter(name: string, parent: Instance): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Enabled = false
	e.Rate = 0
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Parent = parent
	return e
end

local function buildRig(id: string): Rig
	local model = GliderFactory.ForId(id, GLIDER_LENGTH, true)
	local root = model.PrimaryPart
	if not root then
		local fallback = Effects.Part()
		fallback.Name = "Root"
		fallback.Transparency = 1
		fallback.Size = Vector3.one * 0.2
		fallback.Parent = model
		model.PrimaryPart = fallback
		root = fallback
	end
	local r = root :: BasePart
	local a0 = Instance.new("Attachment")
	a0.Name = "SGTrailL"
	a0.Parent = r
	local a1 = Instance.new("Attachment")
	a1.Name = "SGTrailR"
	a1.Parent = r
	local trail = Instance.new("Trail")
	trail.Name = "SGTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.FaceCamera = true
	trail.MinLength = 0.1
	trail.LightInfluence = 0
	trail.Enabled = false
	trail.Parent = r
	local fx = Instance.new("Attachment")
	fx.Name = "SGFx"
	fx.Parent = r
	local sparks = emitter("SGSparks", fx)
	sparks.Speed = NumberRange.new(16, 30)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Lifetime = NumberRange.new(0.35, 0.6)
	sparks.Drag = 3
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	sparks.Transparency = NumberSequence.new(0, 1)
	local lift = emitter("SGLift", fx)
	lift.EmissionDirection = Enum.NormalId.Top
	lift.Orientation = Enum.ParticleOrientation.VelocityParallel
	lift.Speed = NumberRange.new(14, 26)
	lift.SpreadAngle = Vector2.new(25, 25)
	lift.Lifetime = NumberRange.new(0.4, 0.65)
	lift.Acceleration = Vector3.new(0, 24, 0)
	lift.Size = NumberSequence.new(0.35)
	lift.Squash = NumberSequence.new(2.4)
	lift.Transparency = NumberSequence.new(0.2, 1)
	local aura = emitter("SGAura", fx)
	aura.Rate = 40
	aura.Speed = NumberRange.new(2, 6)
	aura.SpreadAngle = Vector2.new(180, 180)
	aura.Lifetime = NumberRange.new(0.4, 0.8)
	aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	aura.Transparency = NumberSequence.new(0.1, 1)
	return { Id = id, Model = model, Root = r, Trail = trail, A0 = a0, A1 = a1, Sparks = sparks, Lift = lift, Aura = aura }
end

local function acquireRig(id: string): Rig
	local list = rigPool[id]
	local rig = if list then table.remove(list) else nil
	if not rig then
		rig = buildRig(id)
	end
	return rig :: Rig
end

local function releaseRig(rig: Rig)
	rig.Trail.Enabled = false
	rig.Trail:Clear()
	rig.Aura.Enabled = false
	rig.Model.Parent = nil
	local list = rigPool[rig.Id]
	if not list then
		list = {}
		rigPool[rig.Id] = list
	end
	if #list < POOL_PER_GLIDER then
		table.insert(list, rig)
	else
		rig.Model:Destroy()
	end
end

-- Trail look for this flight: special (thick, coloured) > equipped trail > white wisps.
local function styleRig(rig: Rig, plan: FlightSim.Plan, isLocal: boolean)
	local trail = rig.Trail
	trail.Enabled = false
	trail:Clear()
	rig.Aura.Enabled = false
	local special = FlightSim.SpecialInfo(plan.Special)
	local seq = trailSequence(plan.Trail)
	if special then
		local color = Color3.fromHex(special.Color)
		trail.Color = ColorSequence.new(color, WHITE)
		trail.Transparency = NumberSequence.new(0.05, 1)
		trail.WidthScale = NumberSequence.new(1, 0.35)
		trail.Lifetime = 0.9
		trail.LightEmission = 1
		rig.A0.Position = Vector3.new(-2.4, 0, 1.2)
		rig.A1.Position = Vector3.new(2.4, 0, 1.2)
		rig.Aura.Color = ColorSequence.new(color)
		rig.Aura.Rate = if FlightFX.Low() then 10 else 40
		rig.Aura.Enabled = true
	elseif seq then
		trail.Color = seq
		trail.Transparency = NumberSequence.new(0.15, 1)
		trail.WidthScale = NumberSequence.new(1, 0.25)
		trail.Lifetime = if isLocal then 0.6 else 0.45
		trail.LightEmission = 0.7
		rig.A0.Position = Vector3.new(-1.2, 0, 1.2)
		rig.A1.Position = Vector3.new(1.2, 0, 1.2)
	else
		trail.Color = ColorSequence.new(WHITE)
		trail.Transparency = NumberSequence.new(0.55, 1)
		trail.WidthScale = NumberSequence.new(1, 0.1)
		trail.Lifetime = 0.35
		trail.LightEmission = 0.3
		rig.A0.Position = Vector3.new(-0.9, 0, 1.2)
		rig.A1.Position = Vector3.new(0.9, 0, 1.2)
	end
end

--------------------------------------------------------------------------------------------------
-- Rings (local flight)
--------------------------------------------------------------------------------------------------

local function ringLook(view: View, rv: RingView, state: string)
	rv.State = state
	if state == "Open" then
		ThermalRings.SetLook(rv.Ring, view.RingColor:Lerp(WHITE, 0.6), 0, 0.72)
	elseif state == "Perfect" then
		ThermalRings.SetLook(rv.Ring, GOLD, 0, 0.6)
	elseif state == "Miss" then
		ThermalRings.SetLook(rv.Ring, MISS_RED, 0.25, 0.9)
	else
		ThermalRings.SetLook(rv.Ring, view.RingColor, 0.05, 0.88)
	end
end

local function spawnRings(view: View)
	local plan = view.Plan
	local clock = os.clock()
	for k, u in plan.Rings do
		local center = ringCenter(plan, u)
		local ring = ThermalRings.Acquire(center, view.RingColor, clock * RING_SPIN + k)
		view.Rings[k] = { Ring = ring, Center = center, State = "Idle", BurstAt = 0, BurstScale = 1, Released = false }
	end
end

local function releaseRings(view: View)
	for _, rv in view.Rings do
		if not rv.Released then
			rv.Released = true
			ThermalRings.Release(rv.Ring)
		end
	end
end

local function stepRings(view: View, clock: number)
	local spin = clock * RING_SPIN
	local nearLimit = view.NextPass + 3
	for k, rv in view.Rings do
		if rv.Released then
			continue
		end
		if rv.State == "Burst" then
			local a = (clock - rv.BurstAt) / BURST_TIME
			if a >= 1 then
				rv.Released = true
				ThermalRings.Release(rv.Ring)
			else
				for _, p in rv.Ring.Parts do
					p.Transparency = a
				end
				rv.Ring.Disc.Transparency = 0.85 + 0.15 * a
				ThermalRings.Step(rv.Ring, spin + k, 1 + a * rv.BurstScale)
			end
		elseif k <= nearLimit then
			local pulse = if k == view.OpenRing then 1 + 0.07 * math.sin(clock * 18) else 1
			ThermalRings.Step(rv.Ring, spin + k, pulse)
		end
	end
end

local function passRing(view: View, k: number, perfect: boolean, clock: number)
	local rig = view.Rig
	local rv = view.Rings[k]
	local pos = if rv then rv.Center else rig.Root.Position
	Bus.RingPassed:Fire(k, perfect, pos)
	AudioController.PlayPitched("Ring", 1 + 0.06 * view.Combo)
	view.Combo += 1
	if perfect then
		AudioController.Play("Perfect")
		rig.Sparks.Color = Theme.Rainbow
		rig.Sparks:Emit(FlightFX.Count(40))
		FlightFX.Popup(rig.Root, "PERFECT!", GOLD, 1.5, 4.4, 0.9)
	else
		rig.Sparks.Color = ColorSequence.new(view.RingColor, WHITE)
		rig.Sparks:Emit(FlightFX.Count(14))
	end
	rig.Lift:Emit(FlightFX.Count(if perfect then 16 else 8))
	local amount, atCap = predictedRingSkill(perfect)
	if atCap then
		FlightFX.Popup(rig.Root, "MAX LEVEL", Theme.Colors.Rebirth, 1, 2.4, 0.8)
		view.Shown[k] = "max"
	else
		FlightFX.Popup(rig.Root, "+" .. Format.Short(amount), Theme.Colors.Skill, if perfect then 1.3 else 1, 2.2, 0.8)
		view.Shown[k] = "plus"
	end
	view.ShownPerfect[k] = perfect
	if rv and not rv.Released then
		rv.State = "Burst"
		rv.BurstAt = clock
		rv.BurstScale = if perfect then 1.8 else 0.9
		ThermalRings.SetLook(rv.Ring, if perfect then GOLD else view.RingColor:Lerp(WHITE, 0.4), 0, 0.85)
	end
end

local function setGustWindow(view: View, index: number)
	if index == view.OpenRing then
		return
	end
	local old = view.OpenRing
	if old > 0 then
		local rv = view.Rings[old]
		if rv and rv.State == "Open" then
			ringLook(view, rv, "Idle")
		end
		Bus.GustWindow:Fire(false, old)
	end
	view.OpenRing = index
	if index > 0 then
		local rv = view.Rings[index]
		if rv and rv.State == "Idle" then
			ringLook(view, rv, "Open")
		end
		Bus.GustWindow:Fire(true, index)
	end
end

--------------------------------------------------------------------------------------------------
-- Flight lifecycle
--------------------------------------------------------------------------------------------------

local function finish(view: View)
	local plan = view.Plan
	if views[plan.Id] ~= view then
		return
	end
	views[plan.Id] = nil
	releaseRings(view)
	releaseRig(view.Rig)
	local held = view.Held
	if held and held.Parent then
		setHeldHidden(held, false)
	end
	if view.IsLocal then
		setGustWindow(view, 0)
		if localView == view then
			localView = nil
			localState.Active = false
			localState.Plan = nil
			localState.Landed = false
		end
		AudioController.Loop("Wind", false)
		FlightFX.SetSpeedLines(0)
		ThrowController.SetActive(nil)
	end
	Bus.FlightEnded:Fire(plan, view.IsLocal)
end

local function land(view: View, clock: number)
	view.Landed = true
	view.LandedAt = clock
	local plan = view.Plan
	local p = pathPoint(plan, plan.Duration)
	view.LandPos = p
	view.Rig.Trail.Enabled = false
	view.Rig.Aura.Enabled = false
	FlightFX.Splash(p, view.WaterColor, view.IsLocal)
	if view.IsLocal then
		AudioController.Play("Splash")
		AudioController.Loop("Wind", false)
		FlightFX.SetSpeedLines(0)
		setGustWindow(view, 0)
		localState.Landed = true
		localState.LandPosition = p
		localState.Position = p
		localState.Velocity = Vector3.zero
		localState.Speed = 0
		Bus.FlightProgress:Fire(plan.Distance, plan)
		view.EndAt = clock + LOCAL_END_DELAY
	else
		AudioController.Play("Splash", p, 0.25, 0.6)
		view.EndAt = clock + REMOTE_END_DELAY
	end
end

-- Positions the glider along the path (blending out of the hand at the start). Returns the path
-- velocity in studs/s.
local function placeGlider(view: View, t: number): Vector3
	local plan = view.Plan
	local p, x = pathPoint(plan, t)
	local p2, x2 = pathPoint(plan, t + LOOKAHEAD)
	local velocity = (p2 - p) / LOOKAHEAD
	local hand = view.Hand
	if hand and t < HAND_BLEND then
		local k = 1 - math.max(t, 0) / HAND_BLEND
		p = p:Lerp(hand, k * k)
	end
	local dir = p2 - p
	local cf: CFrame
	if dir.Magnitude > 1e-3 then
		local bank = math.clamp(-(x2 - x) / LOOKAHEAD * 0.06, -0.55, 0.55)
		cf = CFrame.lookAt(p, p + dir) * CFrame.Angles(0, 0, bank)
	else
		cf = view.LastCF.Rotation + p
	end
	view.Rig.Model:PivotTo(cf)
	view.LastCF = cf
	if not view.TrailArmed then
		view.TrailArmed = true
		view.Rig.Trail:Clear()
		view.Rig.Trail.Enabled = true
	end
	if view.IsLocal then
		localState.Position = p
		localState.Velocity = velocity
		localState.Speed = velocity.Magnitude
	end
	return velocity
end

local function updateLocal(view: View, t: number, clock: number)
	local plan = view.Plan
	local sample = FlightSim.Sample(plan, t, view.Scale)
	Bus.FlightProgress:Fire(sample.Distance, plan)

	local zones = view.Zones
	while view.ZoneIndex < #zones and sample.Distance >= zones[view.ZoneIndex + 1].Distance do
		view.ZoneIndex += 1
		Bus.ZoneEntered:Fire(zones[view.ZoneIndex])
		AudioController.Play("ZoneEnter", nil, 0.25)
	end

	-- gust window of the next ring: [t_k - GustEarly, t_k + GustLate]
	local idx = FlightSim.NextRing(plan, t)
	local open = 0
	if idx and t >= plan.RingTimes[idx] - Flight.GustEarly then
		open = idx
	end
	setGustWindow(view, open)

	-- ring passes: wait out the late part of the window unless the tap already landed PERFECT
	local times = plan.RingTimes
	while view.NextPass <= #times do
		local k = view.NextPass
		local rt = times[k]
		if t < rt then
			break
		end
		local perfect = ThrowController.IsPerfect(k)
		if not perfect and t < rt + Flight.GustLate then
			break
		end
		passRing(view, k, perfect, clock)
		view.NextPass += 1
	end

	local speedK = math.clamp(localState.Speed / 280, 0, 1)
	AudioController.Loop("Wind", true, 0.3 + 0.7 * speedK, 0.85 + 0.35 * speedK)
	FlightFX.SetSpeedLines((localState.Speed - 120) / 180)
end

local function updateView(view: View, now: number, clock: number)
	local plan = view.Plan
	local t = math.max(0, now - plan.Start)
	if not view.Landed then
		placeGlider(view, math.min(t, plan.Duration))
		if view.IsLocal then
			updateLocal(view, math.min(t, plan.Duration), clock)
		end
		if t >= plan.Duration then
			land(view, clock)
		end
	else
		-- bob down into the water, nose dipping
		local k = clock - view.LandedAt
		local cf = CFrame.new(view.LandPos - Vector3.new(0, k * SINK_SPEED, 0)) * view.LastCF.Rotation * CFrame.Angles(-math.min(k, 0.6) * 0.6, 0, 0)
		view.Rig.Model:PivotTo(cf)
	end
	if view.IsLocal then
		stepRings(view, clock)
	end
	if view.EndAt > 0 and clock >= view.EndAt then
		table.insert(ending, view)
	end
end

local function step(dt: number)
	FlightFX.Step(dt)
	if next(views) == nil then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local clock = os.clock()
	for _, view in views do
		updateView(view, now, clock)
	end
	if #ending > 0 then
		for _, view in ending do
			finish(view)
		end
		table.clear(ending)
	end
end

local function remoteCount(): number
	local n = 0
	for _, view in views do
		if not view.IsLocal then
			n += 1
		end
	end
	return n
end

local function onFlightStarted(raw: any)
	local plan = FlightSim.Deserialize(raw)
	if not plan or views[plan.Id] then
		return
	end
	local loose = plan :: any
	if type(loose.Sway) ~= "number" then
		loose.Sway = 0
	end
	if type(loose.SwayFreq) ~= "number" then
		loose.SwayFreq = 1
	end
	local isLocal = plan.UserId == LocalPlayer.UserId
	if isLocal then
		local old = localView
		if old then
			finish(old) -- a new throw (auto throw) replaces a flight still splashing
		end
	else
		local world = currentWorld()
		if world == nil or plan.World ~= world or remoteCount() >= MAX_REMOTE then
			return
		end
	end

	local world = Worlds.Get(plan.World) or Worlds.List[1]
	local theme = themeFor(plan.World)
	local rig = acquireRig(plan.Glider)
	styleRig(rig, plan, isLocal)
	local hand, held = handOf(plan.UserId)
	if hand and (hand - Map.ChannelPoint(plan.World, 0, 6, 0)).Magnitude > 150 then
		hand = nil -- thrower isn't near the channel start (respawned, teleported)
	end
	if isLocal then
		held = nil -- ThrowController hides the local one
	elseif held then
		setHeldHidden(held, true)
	end
	local start = hand or pathPoint(plan, 0)
	rig.Model:PivotTo(CFrame.new(start))
	rig.Model.Parent = getFolder()

	local view: View = {
		Plan = plan,
		IsLocal = isLocal,
		Scale = world.DistanceScale,
		Rig = rig,
		Hand = hand,
		Held = held,
		TrailArmed = false,
		LastCF = CFrame.new(start),
		Landed = false,
		LandPos = start,
		LandedAt = 0,
		EndAt = 0,
		WaterColor = Color3.fromHex(theme.Water),
		Rings = {},
		RingColor = Color3.fromHex(theme.Accent):Lerp(WHITE, 0.3),
		NextPass = 1,
		OpenRing = 0,
		Combo = 0,
		Zones = Zones.ForWorld(plan.World),
		ZoneIndex = 1,
		Shown = {},
		ShownPerfect = {},
	}
	views[plan.Id] = view

	local ahead = pathPoint(plan, 0.15)
	local direction = if (ahead - start).Magnitude > 0.01 then (ahead - start).Unit else Vector3.new(0, 0, -1)
	FlightFX.Launch(start, direction, plan.PerfectLaunch, isLocal)
	local special = FlightSim.SpecialInfo(plan.Special)
	if special then
		FlightFX.SpecialBurst(start, direction, Color3.fromHex(special.Color))
	end

	if isLocal then
		localView = view
		localState.Active = true
		localState.Plan = plan
		localState.Position = start
		localState.Velocity = Vector3.zero
		localState.Speed = 0
		localState.Landed = false
		localState.LandPosition = start
		spawnRings(view)
		ThrowController.SetActive(plan)
		AudioController.Loop("Wind", true, 0.3, 0.85)
	end
	Bus.FlightStarted:Fire(plan, isLocal)
end

local function onFlightRing(payload: any)
	if type(payload) ~= "table" then
		return
	end
	Bus.RingResult:Fire(payload)
	local view = localView
	local index = payload.Index
	if not view or view.Plan.Id ~= payload.Id or type(index) ~= "number" then
		return
	end
	local adornee = view.Rig.Root
	if payload.Amount == 0 and view.Shown[index] == "plus" then
		view.Shown[index] = "max"
		FlightFX.Popup(adornee, "MAX LEVEL", Theme.Colors.Rebirth, 1, 3, 0.9)
	end
	if payload.Perfect == true and view.ShownPerfect[index] == false then
		-- the server's ping allowance accepted a tap this client judged late
		view.ShownPerfect[index] = true
		FlightFX.Popup(adornee, "PERFECT!", GOLD, 1.2, 4.4, 0.8)
		AudioController.Play("Perfect")
	end
end

local function onFlightLanded(payload: any)
	if type(payload) ~= "table" then
		return
	end
	if payload.Cancelled == true then
		local view = if type(payload.Id) == "number" then views[payload.Id] else nil
		if view then
			finish(view)
		end
		return
	end
	if payload.Owner == true then
		Bus.FlightLanded:Fire(payload)
	end
end

-- Remote flights from another world stop rendering when the local player changes world.
local function onWorldChanged(worldId: number)
	for _, view in views do
		if not view.IsLocal and view.Plan.World ~= worldId then
			table.insert(ending, view)
		end
	end
	for _, view in ending do
		finish(view)
	end
	table.clear(ending)
end

local function onTapped(index: number, verdict: string)
	local view = localView
	if not view or view.Landed then
		return
	end
	local rv = view.Rings[index]
	if verdict == "Perfect" then
		if rv and not rv.Released and rv.State ~= "Burst" then
			ringLook(view, rv, "Perfect")
		end
	elseif verdict == "Miss" then
		if rv and not rv.Released and rv.State ~= "Burst" then
			ringLook(view, rv, "Miss")
		end
		AudioController.Play("Miss", nil, 0.1)
		FlightFX.Popup(view.Rig.Root, "TOO EARLY", Theme.Colors.TextMuted, 0.8, 3.2, 0.6)
	end
end

--------------------------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------------------------

-- Live state of the local flight (one shared table; read it, don't keep or modify it).
function FlightRenderer.LocalState(): LocalState
	return localState
end

function FlightRenderer.IsLocalFlying(): boolean
	return localState.Active and not localState.Landed
end

function FlightRenderer.Start()
	Remotes.Event("FlightStarted").OnClientEvent:Connect(onFlightStarted)
	Remotes.Event("FlightRing").OnClientEvent:Connect(onFlightRing)
	Remotes.Event("FlightLanded").OnClientEvent:Connect(onFlightLanded)
	ThrowController.Tapped:Connect(onTapped)
	Bus.WorldChanged:Connect(function(worldId)
		if type(worldId) == "number" then
			onWorldChanged(worldId)
		end
	end)
	StateController.DataChanged:Connect(function(data, previous)
		if type(data) == "table" and type(previous) == "table" and data.World ~= previous.World and type(data.World) == "number" then
			onWorldChanged(data.World)
		end
	end)
	RunService:BindToRenderStep("SkyGlideFlights", Enum.RenderPriority.Camera.Value - 2, step)
end

return FlightRenderer
