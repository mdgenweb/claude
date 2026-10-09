--!strict
-- Deterministic flight plans (pure Luau, shared by server, client and the headless tests).
--
-- The server builds a plan at launch and owns every reward derived from it (ring times, landing
-- time, distance, zone). Clients sample the very same plan to draw the glider, so what players see
-- and what the server pays always agree. Nothing here reads client input.
local Flight = require(script.Parent.Parent.Config.Flight)
local Rng = require(script.Parent.Parent.Util.Rng)

local FlightSim = {}

export type Plan = {
	Id: number,
	UserId: number,
	World: number,
	Seed: number,
	Distance: number, -- logical meters
	Duration: number, -- seconds
	Length: number, -- rendered studs along the channel
	Height: number, -- apex (studs)
	Rings: { number }, -- rendered fractions u_k in (0, 1)
	RingTimes: { number }, -- seconds from launch
	Sway: number, -- lateral sway amplitude (studs)
	SwayFreq: number,
	Glider: string,
	Trail: string?,
	Launch: number, -- launch meter value 0..1
	PerfectLaunch: boolean,
	Special: string?, -- Flight.Specials id (rare boosted throw) or nil
	Start: number, -- server time (workspace:GetServerTimeNow()) at launch
}

-- Distance in meters for a Skill value and a launch multiplier.
function FlightSim.DistanceFor(skill: number, launchMultiplier: number): number
	local s = math.max(0, skill)
	local d = (Flight.DistanceBase + Flight.DistanceScale * s ^ Flight.DistanceExponent) * launchMultiplier
	if d ~= d then
		return Flight.DistanceBase
	end
	return math.clamp(d, 1, Flight.MaxDistance)
end

-- Launch multiplier from the meter value (0..1).
function FlightSim.LaunchMultiplier(meter: number): (number, boolean)
	local m = math.clamp(meter, 0, 1)
	if m >= Flight.PerfectLaunchAt then
		return Flight.PerfectLaunchMultiplier, true
	end
	local a = m / Flight.PerfectLaunchAt
	return Flight.LaunchMin + (Flight.LaunchMax - Flight.LaunchMin) * a, false
end

-- Meter value after holding for `held` seconds (triangle wave 0 -> 1 -> 0).
function FlightSim.MeterAt(held: number): number
	local period = Flight.MeterPeriod
	local phase = (math.max(0, held) % period) / period
	return if phase < 0.5 then phase * 2 else (1 - phase) * 2
end

-- Logical meters -> rendered studs along the channel (monotonic, bounded slope).
function FlightSim.RenderZ(distance: number, worldScale: number): number
	local d0 = Flight.RenderD0 * worldScale
	return Flight.RenderScale * math.log(1 + math.max(0, distance) / d0)
end

-- Rendered studs -> logical meters (inverse of RenderZ).
function FlightSim.LogicalAt(z: number, worldScale: number): number
	local d0 = Flight.RenderD0 * worldScale
	local e = math.exp(math.max(0, z) / Flight.RenderScale) - 1
	return d0 * e
end

local function log2(x: number): number
	return math.log(x) / math.log(2)
end

function FlightSim.DurationFor(distance: number, worldScale: number): number
	local t = Flight.TimeBase + Flight.TimeLog * log2(1 + distance / (Flight.TimeD0 * worldScale))
	return math.clamp(t, Flight.TimeMin, Flight.TimeMax)
end

function FlightSim.RingCountFor(distance: number, worldScale: number): number
	local k = math.floor(Flight.RingBase + Flight.RingLog * log2(1 + distance / (Flight.RingD0 * worldScale)))
	return math.clamp(k, Flight.RingMin, Flight.RingMax)
end

function FlightSim.HeightFor(distance: number, worldScale: number): number
	local h = Flight.HeightBase + Flight.HeightLog * log2(1 + distance / (Flight.RingD0 * worldScale))
	return math.clamp(h, Flight.HeightMin, Flight.HeightMax)
end

-- Rendered progress (0..1) at time t.
function FlightSim.Progress(t: number, duration: number): number
	if duration <= 0 then
		return 1
	end
	local s = math.clamp(t / duration, 0, 1)
	return 1 - (1 - s) ^ Flight.EaseExponent
end

-- Time at which rendered progress reaches u.
function FlightSim.TimeAtProgress(u: number, duration: number): number
	local p = math.clamp(u, 0, 1)
	return duration * (1 - (1 - p) ^ (1 / Flight.EaseExponent))
end

-- Ring schedule: times (seconds) with an accelerating rhythm and a hard minimum gap, plus the
-- matching path fractions. The ring count is reduced if the flight is too short to fit it.
function FlightSim.RingSchedule(count: number, duration: number, seed: number): ({ number }, { number })
	local times, fractions = {}, {}
	if count <= 0 or duration <= 0 then
		return times, fractions
	end
	local first = math.max(Flight.RingFirstMin, duration * Flight.FirstRingTime)
	local last = math.max(first, duration * Flight.LastRingTime)
	local span = last - first
	local minGap = Flight.RingMinGap
	local maxCount = math.floor(span / (minGap * 1.06)) + 1
	local k = math.clamp(count, 1, math.max(1, maxCount))
	times[1] = first
	if k > 1 then
		local rng = Rng.new(seed)
		local jitter = table.create(k - 1)
		for i = 1, k - 1 do
			jitter[i] = rng:Range(0.95, 1.05)
		end
		-- relax the decay toward uniform spacing until the smallest gap fits
		local decay = Flight.RingSpacingDecay
		local gaps = table.create(k - 1)
		for _ = 1, 40 do
			local total = 0
			for i = 1, k - 1 do
				gaps[i] = decay ^ (i - 1) * jitter[i]
				total += gaps[i]
			end
			local smallest = math.huge
			for i = 1, k - 1 do
				gaps[i] = gaps[i] / total * span
				smallest = math.min(smallest, gaps[i])
			end
			if smallest >= minGap or decay >= 1 then
				break
			end
			decay = math.min(1, decay + 0.01)
		end
		local t = first
		for i = 1, k - 1 do
			t += gaps[i]
			times[i + 1] = t
		end
	end
	for i, t in times do
		fractions[i] = FlightSim.Progress(t, duration)
	end
	return times, fractions
end

export type BuildArgs = {
	Id: number,
	UserId: number,
	World: number,
	WorldScale: number,
	Skill: number,
	Launch: number,
	Seed: number,
	Glider: string,
	Trail: string?,
	Start: number,
	SpecialLuck: number?,
}

-- Rare special throw rolled from the seed (nil for a normal throw). `luck` scales the chances.
function FlightSim.RollSpecial(seed: number, luck: number?): Flight.Special?
	local roll = Rng.new(seed + 99991):Next()
	local scale = math.max(1, luck or 1)
	local acc = 0
	for _, special in Flight.Specials do
		acc += special.Chance * scale
		if roll < acc then
			return special
		end
	end
	return nil
end

-- Builds a complete plan. Pure: same args -> same plan.
function FlightSim.Build(a: BuildArgs): Plan
	local launchMul, perfect = FlightSim.LaunchMultiplier(a.Launch)
	local special = FlightSim.RollSpecial(a.Seed, a.SpecialLuck)
	local distance = FlightSim.DistanceFor(a.Skill, launchMul * (if special then special.Multiplier else 1))
	local duration = FlightSim.DurationFor(distance, a.WorldScale)
	local length = math.min(FlightSim.RenderZ(distance, a.WorldScale), Flight.RenderMaxZ)
	local count = FlightSim.RingCountFor(distance, a.WorldScale)
	local times, rings = FlightSim.RingSchedule(count, duration, a.Seed)
	local rng = Rng.new(a.Seed + 7919)
	return {
		Id = a.Id,
		UserId = a.UserId,
		World = a.World,
		Seed = a.Seed,
		Distance = distance,
		Duration = duration,
		Length = math.max(length, 30),
		Height = FlightSim.HeightFor(distance, a.WorldScale),
		Rings = rings,
		RingTimes = times,
		Sway = rng:Range(2, 7),
		SwayFreq = rng:Range(1.2, 2.4),
		Glider = a.Glider,
		Trail = a.Trail,
		Launch = math.clamp(a.Launch, 0, 1),
		PerfectLaunch = perfect,
		Special = if special then special.Id else nil,
		Start = a.Start,
	}
end

-- Altitude (studs above the water) at rendered progress u.
function FlightSim.Altitude(plan: Plan, u: number): number
	local H = plan.Height
	local rise = math.clamp(u / 0.1, 0, 1)
	local base = H * (1 - (1 - rise) ^ 2) * (1 - u) ^ 0.8
	local launchHeight = 6 * (1 - rise)
	local bump = 0
	local width = 0.035
	for i, ru in plan.Rings do
		local x = (u - ru - width * 0.6) / width
		if x > -3 and x < 3 then
			bump += H * Flight.ThermalLift * Flight.ThermalDecay ^ (i - 1) * math.exp(-x * x)
		end
	end
	return math.max(0, base + launchHeight + bump * (1 - u) ^ 0.3)
end

export type Sample = {
	Progress: number, -- rendered fraction 0..1
	Z: number, -- studs along the channel
	X: number, -- lateral offset (studs)
	Y: number, -- altitude (studs)
	Distance: number, -- logical meters flown so far
	Landed: boolean,
}

function FlightSim.SpecialInfo(id: string?): Flight.Special?
	if not id then
		return nil
	end
	for _, special in Flight.Specials do
		if special.Id == id then
			return special
		end
	end
	return nil
end

-- Glider state at `t` seconds after launch.
function FlightSim.Sample(plan: Plan, t: number, worldScale: number): Sample
	local u = FlightSim.Progress(t, plan.Duration)
	local z = plan.Length * u
	local logical: number
	if u >= 1 then
		logical = plan.Distance
	else
		-- map the rendered position back to meters, scaled so the counter ends exactly on Distance
		local full = FlightSim.RenderZ(plan.Distance, worldScale)
		logical = FlightSim.LogicalAt(full * u, worldScale)
		logical = math.min(logical, plan.Distance)
	end
	local sway = plan.Sway * math.sin(u * math.pi * plan.SwayFreq * 2) * (1 - u)
	return {
		Progress = u,
		Z = z,
		X = sway,
		Y = FlightSim.Altitude(plan, u),
		Distance = logical,
		Landed = t >= plan.Duration,
	}
end

-- Index of the ring the player should be aiming for at time t (first ring not yet passed), or nil.
function FlightSim.NextRing(plan: Plan, t: number): number?
	for i, rt in plan.RingTimes do
		if t <= rt + Flight.GustLate then
			return i
		end
	end
	return nil
end

-- Judges a gust tap for ring `index` at flight time `t`. `latency` is extra allowance in seconds.
-- Returns "Perfect", "Miss" (too early: spends the ring), or nil (ignored / too late).
function FlightSim.JudgeGust(plan: Plan, index: number, t: number, latency: number): string?
	local rt = plan.RingTimes[index]
	if rt == nil then
		return nil
	end
	local allowance = math.clamp(latency, 0, Flight.GustMaxLatency)
	if t >= rt - Flight.GustEarly and t <= rt + Flight.GustLate + allowance then
		return "Perfect"
	end
	if t < rt - Flight.GustEarly and t >= rt - Flight.GustTooEarly then
		return "Miss"
	end
	return nil
end

-- Moment after which ring `index` can no longer change (server pays it then).
function FlightSim.RingSettleTime(plan: Plan, index: number): number
	return (plan.RingTimes[index] or 0) + Flight.GustLate + Flight.GustMaxLatency
end

-- Plain table safe for RemoteEvents.
function FlightSim.Serialize(plan: Plan): { [string]: any }
	return table.clone(plan) :: any
end

-- Rebuilds a plan received over the network, validating shapes (clients only render it).
function FlightSim.Deserialize(raw: any): Plan?
	if type(raw) ~= "table" then
		return nil
	end
	local function n(v: any): boolean
		return type(v) == "number" and v == v
	end
	if not (n(raw.Id) and n(raw.UserId) and n(raw.World) and n(raw.Distance) and n(raw.Duration) and n(raw.Length) and n(raw.Height) and n(raw.Start)) then
		return nil
	end
	if type(raw.Rings) ~= "table" or type(raw.RingTimes) ~= "table" or type(raw.Glider) ~= "string" then
		return nil
	end
	return raw :: Plan
end

return FlightSim
