--!strict
-- Battle simulation tuning. The simulation is a deterministic 2D fixed-step model that
-- runs on the server (see ServerScriptService/Server/Battle/World.luau). Units are studs and seconds.
--
-- UNKNOWN in research: whether the original arena has gravity. Default ON (energy conserving
-- arcs). Set Gravity = 0 for pure billiard motion; everything else keeps working.
return {
	TickRate = 60, -- simulation steps per second
	SnapshotRate = 20, -- network snapshots per second
	InterpolationDelay = 0.1, -- client render delay (seconds)

	Gravity = 14, -- studs/s^2 pulling toward -Y of the arena plane
	CruiseSpeed = 16, -- launch speed and the speed the energy governor restores
	GovernorRate = 2.2, -- how fast (1/s) total energy is restored toward the cruise energy
	MinSpeed = 5,
	MaxSpeed = 46,

	WallRestitution = 1.0,
	WallJitterDegrees = 2.5, -- tiny deterministic deflection prevents perfectly periodic loops
	BallRestitution = 1.0,
	ContactCooldown = 0.22, -- seconds before the same pair can deal contact damage again
	SpawnImmunity = 0.35,

	-- Overtime (our own rule: round duration is not documented publicly)
	OvertimeStart = 40,
	OvertimeStep = 5,
	OvertimeDamageBonus = 0.25, -- +25% damage per step
	OvertimeAttrition = 1.0, -- HP per second lost by every ball during overtime
	RoundHardCap = 120, -- seconds; lowest HP % loses

	MaxEntities = 140,
	MaxSnapshotEntities = 88, -- keeps snapshots under ~780 bytes
}
