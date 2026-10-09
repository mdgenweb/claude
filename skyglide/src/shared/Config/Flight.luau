--!strict
-- ORIGINAL DESIGN: the glider flight model (replaces stone skipping).
--
-- A throw becomes a deterministic "flight plan" computed on the server from the player's Skill,
-- the launch meter, and a seed. Logical distance (meters, unbounded) is kept separate from the
-- rendered path (studs, bounded) through a log mapping, so a 10-million-meter throw still fits in
-- the channel without float precision problems. See docs/DESIGN.md §Flight.
local Flight = {}

-- Distance from Skill: D = Base + Scale * Skill ^ Exponent (meters), then x launch multiplier.
Flight.DistanceBase = 6
Flight.DistanceScale = 4.5
Flight.DistanceExponent = 0.4
Flight.MaxDistance = 1e300

-- Launch meter (server-timed): value pings 0 -> 1 -> 0 every MeterPeriod seconds of holding.
Flight.MeterPeriod = 1.3
Flight.MeterMaxHold = 8 -- seconds; longer holds are released automatically
Flight.LaunchMin = 0.85 -- multiplier at meter 0
Flight.LaunchMax = 1.15 -- multiplier at meter just below the perfect band
Flight.PerfectLaunchAt = 0.9 -- meter >= this = PERFECT LAUNCH
Flight.PerfectLaunchMultiplier = 1.25
Flight.TapLaunchMeter = 0.55 -- a quick tap without holding
Flight.AutoLaunchMeter = 0.7 -- auto-throw quality

-- Rendered path: Z(d) = RenderScale * ln(1 + d / (RenderD0 * world.DistanceScale)) studs.
Flight.RenderScale = 900
Flight.RenderD0 = 40
Flight.RenderMaxZ = 8000 -- channel length; extreme throws are clamped visually, never logically

-- Timing: T = clamp(TimeBase + TimeLog * log2(1 + D / (TimeD0 * world.DistanceScale)), TimeMin, TimeMax)
Flight.TimeBase = 2.8
Flight.TimeLog = 1.0
Flight.TimeD0 = 15
Flight.TimeMin = 2.8
Flight.TimeMax = 12
Flight.EaseExponent = 1.5 -- rendered progress = 1 - (1 - t/T)^EaseExponent (fast launch, soft landing)

-- Thermal rings: K = clamp(floor(RingBase + RingLog * log2(1 + D / (RingD0 * world.DistanceScale))), RingMin, RingMax)
Flight.RingBase = 2
Flight.RingLog = 1.5
Flight.RingD0 = 12
Flight.RingMin = 2
Flight.RingMax = 14
-- Rings are scheduled in TIME so they stay humanly tappable: the first ring comes at
-- FirstRingTime x T, the last at LastRingTime x T, gaps shrink by RingSpacingDecay (the rhythm
-- speeds up) but never below RingMinGap seconds. RingMinGap >= GustEarly + GustLate +
-- GustMaxLatency makes spam-tapping useless: the first tap aimed at the next ring always lands in
-- its "too early" window even after network delay (FlightService also caps taps per ring).
Flight.FirstRingTime = 0.12
Flight.LastRingTime = 0.86
Flight.RingFirstMin = 0.6 -- seconds; never earlier than this
Flight.RingSpacingDecay = 0.9
Flight.RingMinGap = 0.75

-- Gust taps (PERFECT catches). Times are seconds relative to the ring time.
Flight.GustEarly = 0.3 -- tap may come this long before the ring
Flight.GustLate = 0.12 -- ...or this long after it
Flight.GustMaxLatency = 0.3 -- extra lateness allowed for the player's measured ping
Flight.GustTooEarly = 0.9 -- a tap this long before a ring "spends" that ring as a miss
Flight.PerfectMultiplier = 2
Flight.GustTapSlack = 3 -- taps allowed beyond one per ring before further taps count as misses

-- Visual altitude (studs): apex H = clamp(HeightBase + HeightLog * log2(1 + D/(…)), HeightMin, HeightMax)
Flight.HeightBase = 16
Flight.HeightLog = 4
Flight.HeightMin = 14
Flight.HeightMax = 60
Flight.ThermalLift = 0.22 -- bump size as a fraction of H
Flight.ThermalDecay = 0.92

-- Special throws (LIKELY in the reference: a rare "secret" x3 throw and a 1/1000 giant one).
-- Ours: rolled from the server seed at launch. Listed rarest first.
export type Special = { Id: string, Name: string, Chance: number, Multiplier: number, Color: string }
Flight.Specials = {
	{ Id = "SkyTitan", Name = "SKY TITAN", Chance = 0.001, Multiplier = 8, Color = "#FFD447" },
	{ Id = "JetStream", Name = "JET STREAM", Chance = 0.01, Multiplier = 3, Color = "#7FE7FF" },
} :: { Special }

Flight.LandCooldown = 0.7 -- seconds after landing before the next throw is accepted
Flight.AutoThrowDelay = 1.2 -- auto throw waits this long after landing

return Flight
