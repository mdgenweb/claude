-- Flight model: determinism, bounds, ring schedule, gust judging, rendering map.
local FlightSim = MODULE("ReplicatedStorage/Shared/Sim/FlightSim")
local Flight = MODULE("ReplicatedStorage/Shared/Config/Flight")
local Zones = MODULE("ReplicatedStorage/Shared/Definitions/Zones")
local Worlds = MODULE("ReplicatedStorage/Shared/Definitions/Worlds")

local failures = 0
local checks = 0
local function check(cond, msg)
	checks += 1
	if not cond then
		failures += 1
		print("FAILED: " .. msg)
	end
end
local function finite(x)
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

-- distance curve
local prev = -1
for e = 0, 300, 3 do
	local skill = if e == 0 then 0 else 10 ^ e
	local d = FlightSim.DistanceFor(skill, 1)
	check(finite(d) and d > 0, "distance finite for skill 1e" .. e)
	check(d >= prev, "distance monotonic at 1e" .. e)
	prev = d
end
check(FlightSim.DistanceFor(-5, 1) == FlightSim.DistanceFor(0, 1), "negative skill clamps")
check(finite(FlightSim.DistanceFor(0 / 0, 1)), "NaN skill handled")

-- launch meter
check(FlightSim.MeterAt(0) == 0, "meter starts at 0")
check(math.abs(FlightSim.MeterAt(Flight.MeterPeriod / 2) - 1) < 1e-9, "meter peaks at half period")
for i = 0, 200 do
	local m = FlightSim.MeterAt(i * 0.037)
	check(m >= 0 and m <= 1, "meter within [0,1]")
end
local lmin = FlightSim.LaunchMultiplier(0)
local lmax, perfect = FlightSim.LaunchMultiplier(1)
check(math.abs(lmin - Flight.LaunchMin) < 1e-9, "launch min")
check(perfect and lmax == Flight.PerfectLaunchMultiplier, "perfect launch at 1")
local _, notPerfect = FlightSim.LaunchMultiplier(Flight.PerfectLaunchAt - 0.01)
check(not notPerfect, "not perfect just below threshold")

-- render mapping round trip
for _, world in Worlds.List do
	for _, d in { 0, 1, 25, 400, 3500, 1e5, 1e7 } do
		local z = FlightSim.RenderZ(d, world.DistanceScale)
		local back = FlightSim.LogicalAt(z, world.DistanceScale)
		check(math.abs(back - d) <= math.max(1e-6, d * 1e-9), "render round trip " .. d)
	end
end

-- zone signs are ordered along the channel and Zones.At is consistent
for _, world in Worlds.List do
	local zones = Zones.ForWorld(world.Id)
	check(#zones >= 10, "world has zones")
	local lastZ = -1
	for i, zone in zones do
		local z = FlightSim.RenderZ(zone.Distance, world.DistanceScale)
		check(z > lastZ or (i == 1 and z == 0), "zone signs ordered " .. zone.Id)
		lastZ = z
		check(Zones.At(world.Id, zone.Distance) == zone, "Zones.At boundary " .. zone.Id)
		if i > 1 then
			check(Zones.At(world.Id, zone.Distance - 0.001) == zones[i - 1], "Zones.At below boundary " .. zone.Id)
		end
	end
	local farZ = FlightSim.RenderZ(zones[#zones].Distance, world.DistanceScale)
	check(farZ < Flight.RenderMaxZ, "last zone sign inside the channel (" .. math.floor(farZ) .. ")")
end

-- plans
local minGapSeen = math.huge
local maxRings = 0
local plans = 0
for _, world in Worlds.List do
	for e = 0, 18 do
		for _, launch in { 0, 0.4, 0.7, 0.95 } do
			local skill = (10 ^ e) * world.DistanceScale ^ 2.5
			local args = {
				Id = 1,
				UserId = 1,
				World = world.Id,
				WorldScale = world.DistanceScale,
				Skill = skill,
				Launch = launch,
				Seed = 1000 + e * 7 + world.Id,
				Glider = "paper_dart",
				Start = 100,
			}
			local plan = FlightSim.Build(args)
			local again = FlightSim.Build(args)
			plans += 1
			check(plan.Distance == again.Distance and #plan.Rings == #again.Rings, "deterministic")
			for i = 1, #plan.Rings do
				check(plan.Rings[i] == again.Rings[i] and plan.RingTimes[i] == again.RingTimes[i], "deterministic rings")
			end
			check(finite(plan.Distance) and finite(plan.Duration) and finite(plan.Length), "finite plan")
			check(plan.Duration >= Flight.TimeMin and plan.Duration <= Flight.TimeMax, "duration bounds")
			check(plan.Length <= Flight.RenderMaxZ, "length capped")
			check(#plan.Rings >= 1 and #plan.Rings <= Flight.RingMax, "ring count bounds")
			check(#plan.Rings == #plan.RingTimes, "rings/times match")
			maxRings = math.max(maxRings, #plan.Rings)
			for i, t in plan.RingTimes do
				check(t > 0 and t < plan.Duration, "ring time inside flight")
				check(plan.Rings[i] > 0 and plan.Rings[i] < 1, "ring fraction inside path")
				if i > 1 then
					local gap = t - plan.RingTimes[i - 1]
					minGapSeen = math.min(minGapSeen, gap)
					check(gap >= Flight.RingMinGap - 1e-9, "ring gap >= min gap")
					check(plan.Rings[i] > plan.Rings[i - 1], "ring fractions increasing")
				end
			end
			-- sampling
			local lastD = -1
			for s = 0, 60 do
				local t = plan.Duration * s / 60
				local sample = FlightSim.Sample(plan, t, world.DistanceScale)
				check(finite(sample.Y) and sample.Y >= 0, "altitude finite and >= 0")
				check(finite(sample.Z) and finite(sample.X), "position finite")
				check(sample.Distance >= lastD - 1e-6, "counter never decreases")
				lastD = sample.Distance
			end
			local final = FlightSim.Sample(plan, plan.Duration + 1, world.DistanceScale)
			check(final.Landed and final.Distance == plan.Distance, "lands on the exact distance")
		end
	end
end

-- gust judging
local plan = FlightSim.Build({
	Id = 5,
	UserId = 1,
	World = 1,
	WorldScale = 1,
	Skill = 1e6,
	Launch = 0.7,
	Seed = 42,
	Glider = "paper_dart",
	Start = 0,
})
local rt = plan.RingTimes[2]
check(FlightSim.JudgeGust(plan, 2, rt, 0) == "Perfect", "perfect on the ring")
check(FlightSim.JudgeGust(plan, 2, rt - Flight.GustEarly + 0.01, 0) == "Perfect", "perfect just inside early window")
check(FlightSim.JudgeGust(plan, 2, rt - Flight.GustEarly - 0.05, 0) == "Miss", "too early spends the ring")
check(FlightSim.JudgeGust(plan, 2, rt - Flight.GustTooEarly - 0.05, 0) == nil, "far too early ignored")
check(FlightSim.JudgeGust(plan, 2, rt + Flight.GustLate + 0.05, 0) == nil, "late without ping ignored")
check(FlightSim.JudgeGust(plan, 2, rt + Flight.GustLate + 0.05, 0.1) == "Perfect", "late within ping allowance")
check(FlightSim.JudgeGust(plan, 2, rt + Flight.GustLate + Flight.GustMaxLatency + 0.05, 5) == nil, "ping allowance capped")
check(FlightSim.JudgeGust(plan, 99, rt, 0) == nil, "unknown ring ignored")
check(FlightSim.RingSettleTime(plan, 2) > rt + Flight.GustLate, "settles after the window")

-- spam tapper simulation: taps every 1/60 s at the next ring, with network delay up to the cap.
-- It must never earn a PERFECT (the first tap aimed at each ring is always too early).
for _, delay in { 0, 0.1, 0.2, Flight.GustMaxLatency } do
	local decided = {}
	local perfects = 0
	local t = 0
	while t < plan.Duration do
		local idx = FlightSim.NextRing(plan, t)
		if idx and decided[idx] == nil then
			local verdict = FlightSim.JudgeGust(plan, idx, t + delay, delay)
			if verdict then
				decided[idx] = verdict
				if verdict == "Perfect" then
					perfects += 1
				end
			end
		end
		t += 1 / 60
	end
	check(perfects == 0, "spam tapping earns no perfects (delay " .. delay .. ", got " .. perfects .. ")")
end

-- a well-timed player gets every ring
local good = 0
for i, t in plan.RingTimes do
	if FlightSim.JudgeGust(plan, i, t + 0.08, 0.08) == "Perfect" then
		good += 1
	end
end
check(good == #plan.RingTimes, "timed taps are all perfect")

print(string.format("flight.spec: %d plans, max rings %d, min ring gap %.3fs, %d checks, %d failures", plans, maxRings, minGapSeen, checks, failures))
