--!strict
-- ORIGINAL DESIGN core loop: charge -> launch -> ride thermal rings -> land in a zone.
--
-- Throw state machine per player:
--   Idle --RequestThrowCharge--> Charging --RequestThrow / max hold--> Flying --T--> Landed
--   Landed --LandCooldown--> Idle          (Auto Throw: Idle --AutoThrowDelay--> Flying)
--
-- Everything that pays out is decided here from a server-built FlightSim plan:
--   * the launch meter is timed with the server clock (charge start -> release),
--   * each ring pays "+N Skill" (glider) x Skill multiplier, x2 when a PERFECT gust tap arrived in
--     the ring's window (judged with server time + a capped ping allowance),
--   * landing pays the zone's Wins x Wins multiplier and XP.
-- Clients only send intents and draw the same plan; they never report distance, rings or wins.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Flight = require(Shared.Config.Flight)
local FlightSim = require(Shared.Sim.FlightSim)
local Progression = require(Shared.Sim.Progression)
local Worlds = require(Shared.Definitions.Worlds)
local Zones = require(Shared.Definitions.Zones)
local Remotes = require(Shared.Net.Remotes)
local Validate = require(Shared.Util.Validate)
local Format = require(Shared.Util.Format)

local Server = script.Parent.Parent
local Guard = require(Server.Util.Guard)
local DataService = require(script.Parent.DataService)
local StatService = require(script.Parent.StatService)
local MapService = require(script.Parent.MapService)

local FlightService = {}

type Active = {
	Plan: FlightSim.Plan,
	WorldScale: number,
	SkillPerRing: number,
	Multiplier: number,
	Rings: { [number]: string }, -- index -> "Perfect" | "Miss"
	NextPay: number,
	TotalSkill: number,
	Perfects: number,
	Taps: number,
}

type State = {
	Charging: boolean,
	ChargeStart: number,
	Active: Active?,
	CooldownUntil: number,
	AutoNextAt: number,
}

local registry: { [string]: any } = {}
local states: { [Player]: State } = {}
local nextFlightId = 0
local seedRng = Random.new()

local remotes: {
	FlightStarted: RemoteEvent,
	FlightRing: RemoteEvent,
	FlightLanded: RemoteEvent,
	ChargeState: RemoteEvent,
} = {} :: any

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function stateOf(player: Player): State
	local s = states[player]
	if not s then
		s = { Charging = false, ChargeStart = 0, Active = nil, CooldownUntil = 0, AutoNextAt = 0 }
		states[player] = s
	end
	return s
end

function FlightService.IsFlying(player: Player): boolean
	local s = states[player]
	return s ~= nil and s.Active ~= nil
end

local function tutorial(player: Player, event: string, amount: number?)
	local t = registry.TutorialService
	if t then
		t.Event(player, event, amount)
	end
end

local function sendCharge(player: Player, charging: boolean, startedAt: number, reason: string?)
	remotes.ChargeState:FireClient(player, { Charging = charging, StartedAt = startedAt, Reason = reason })
end

-- Can this player start a throw right now? Returns (ok, reason)
local function canThrow(player: Player, s: State): (boolean, string?)
	local profile = DataService.Get(player)
	if not profile then
		return false, "Loading"
	end
	if s.Active then
		return false, "Flying"
	end
	if now() < s.CooldownUntil then
		return false, "Cooldown"
	end
	if not MapService.InThrowZone(player, profile.World) then
		return false, "NotInZone"
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false, "Dead"
	end
	return true, nil
end

local function launch(player: Player, s: State, meter: number)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local world = Worlds.Get(profile.World) or Worlds.List[1]
	nextFlightId += 1
	local gliderId = if profile.Relic ~= "" then "relic:" .. profile.Relic else profile.Glider
	local plan = FlightSim.Build({
		Id = nextFlightId,
		UserId = player.UserId,
		World = world.Id,
		WorldScale = world.DistanceScale,
		Skill = profile.Skill,
		Launch = meter,
		Seed = seedRng:NextInteger(1, 2 ^ 30),
		Glider = gliderId,
		Trail = if profile.Trail ~= "" then profile.Trail else nil,
		Start = now(),
		SpecialLuck = if registry.EventService then registry.EventService.SpecialLuck() else 1,
	})
	s.Charging = false
	s.Active = {
		Plan = plan,
		WorldScale = world.DistanceScale,
		SkillPerRing = Progression.SkillPerRing(profile),
		Multiplier = StatService.SkillMultiplier(player),
		Rings = {},
		NextPay = 1,
		TotalSkill = 0,
		Perfects = 0,
		Taps = 0,
	}
	sendCharge(player, false, 0, "Launched")
	remotes.FlightStarted:FireAllClients(FlightSim.Serialize(plan))
	if plan.Special then
		local special = FlightSim.SpecialInfo(plan.Special)
		local notify = registry.NotifyService
		if notify and special then
			notify.All(string.format("%s triggered a %s throw!", player.DisplayName, special.Name), "Rare")
		end
	end
	tutorial(player, "Throw")
end

local function onCharge(player: Player)
	local s = stateOf(player)
	local ok, reason = canThrow(player, s)
	if not ok then
		sendCharge(player, false, 0, reason)
		return
	end
	if s.Charging then
		return
	end
	s.Charging = true
	s.ChargeStart = now()
	sendCharge(player, true, s.ChargeStart, nil)
end

local function onRelease(player: Player)
	local s = stateOf(player)
	local ok, reason = canThrow(player, s)
	if not ok then
		s.Charging = false
		sendCharge(player, false, 0, reason)
		return
	end
	local meter = if s.Charging then FlightSim.MeterAt(now() - s.ChargeStart) else Flight.TapLaunchMeter
	launch(player, s, meter)
end

local function onGust(player: Player, flightId: any, ringIndex: any)
	if not (Validate.Integer(flightId, 1, 1e12) and Validate.Integer(ringIndex, 1, Flight.RingMax)) then
		return
	end
	local s = states[player]
	local active = s and s.Active
	if not active or active.Plan.Id ~= flightId then
		return
	end
	if active.Rings[ringIndex] ~= nil or ringIndex < active.NextPay then
		return -- already decided or already paid
	end
	active.Taps += 1
	if active.Taps > ringIndex + Flight.GustTapSlack then
		active.Rings[ringIndex] = "Miss" -- spam: more taps than rings
		return
	end
	local t = now() - active.Plan.Start
	local ping = 0
	pcall(function()
		ping = player:GetNetworkPing()
	end)
	local verdict = FlightSim.JudgeGust(active.Plan, ringIndex, t, ping)
	if verdict then
		active.Rings[ringIndex] = verdict
	end
end

local function land(player: Player, s: State, active: Active)
	s.Active = nil
	s.CooldownUntil = now() + Flight.LandCooldown
	s.AutoNextAt = now() + Flight.AutoThrowDelay
	local plan = active.Plan
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local zone = Zones.At(plan.World, plan.Distance)
	local winsMultiplier = StatService.WinsMultiplier(player)
	local wins = zone.Wins * winsMultiplier
	local worldKey = tostring(plan.World)
	local lastZone = Zones.Last(plan.World)
	local nextWorld = Worlds.Get(plan.World + 1)
	local unlockedWorld: Worlds.World? = nil
	local gatedWorld: Worlds.World? = nil
	local newBest = false
	local newZone = false
	DataService.Update(player, function(p)
		p.Stats.Throws += 1
		p.Stats.Rings += #plan.Rings
		p.Stats.Perfects += active.Perfects
		if plan.Distance > (p.Best[worldKey] or 0) then
			p.Best[worldKey] = plan.Distance
			newBest = true
		end
		if plan.Distance > p.Stats.BestDistance then
			p.Stats.BestDistance = plan.Distance
		end
		if not p.Zones[zone.Id] then
			p.Zones[zone.Id] = true
			newZone = true
		end
		-- reaching the end of the river opens the next world (once the rebirth gate is met too;
		-- otherwise the portal opens it later)
		if lastZone and zone.Id == lastZone.Id and nextWorld and not p.Worlds[tostring(nextWorld.Id)] then
			if p.Rebirths >= nextWorld.UnlockRebirths then
				p.Worlds[tostring(nextWorld.Id)] = true
				unlockedWorld = nextWorld
			else
				gatedWorld = nextWorld
			end
		end
		return true
	end)
	StatService.AddWins(player, wins, "Landing")

	local public = { Id = plan.Id, UserId = plan.UserId, World = plan.World, Distance = plan.Distance, Zone = zone.Id }
	local private = {
		Id = plan.Id,
		UserId = plan.UserId,
		World = plan.World,
		Distance = plan.Distance,
		Zone = zone.Id,
		Wins = wins,
		Skill = active.TotalSkill,
		Special = plan.Special,
		UnlockedWorld = if unlockedWorld then unlockedWorld.Id else nil,
		Perfects = active.Perfects,
		Rings = #plan.Rings,
		NewBest = newBest,
		NewZone = newZone,
		Owner = true,
	}
	for _, other in Players:GetPlayers() do
		remotes.FlightLanded:FireClient(other, if other == player then private else public)
	end
	local notify = registry.NotifyService
	if notify then
		if unlockedWorld then
			notify.All(string.format("%s reached the end of the river and unlocked %s!", player.DisplayName, unlockedWorld.Name), "Rare")
		elseif gatedWorld then
			notify.Toast(player, string.format("End of the river! Reach %d rebirths to open %s.", gatedWorld.UnlockRebirths, gatedWorld.Name), "Info")
		elseif newZone then
			notify.Toast(player, "New zone discovered: " .. zone.Name .. "!", "Success")
		end
	end
	local _ = Format
end

local function payRing(player: Player, active: Active, index: number)
	local perfect = active.Rings[index] == "Perfect"
	local amount = active.SkillPerRing * active.Multiplier * (if perfect then Flight.PerfectMultiplier else 1)
	if perfect then
		active.Perfects += 1
	end
	local added = StatService.AddSkill(player, amount, "Ring")
	active.TotalSkill += added
	remotes.FlightRing:FireClient(player, { Id = active.Plan.Id, Index = index, Perfect = perfect, Amount = added })
	tutorial(player, "Ring")
end

local function step()
	local t0 = now()
	for player, s in states do
		if player.Parent == nil then
			continue
		end
		local active = s.Active
		if active then
			local t = t0 - active.Plan.Start
			while active.NextPay <= #active.Plan.RingTimes and t >= FlightSim.RingSettleTime(active.Plan, active.NextPay) do
				payRing(player, active, active.NextPay)
				active.NextPay += 1
			end
			if t >= active.Plan.Duration and active.NextPay > #active.Plan.RingTimes then
				land(player, s, active)
			end
		elseif s.Charging then
			if t0 - s.ChargeStart >= Flight.MeterMaxHold then
				onRelease(player)
			end
		else
			local profile = DataService.Get(player)
			if profile and profile.Settings.AutoThrow and t0 >= s.AutoNextAt and t0 >= s.CooldownUntil then
				local passes = registry.MonetizationService
				if passes and passes.HasPass(player, "AutoThrow") then
					local ok = canThrow(player, s)
					if ok then
						launch(player, s, Flight.AutoLaunchMeter)
					else
						s.AutoNextAt = t0 + 0.5
					end
				end
			end
		end
	end
end

-- Cancels a flight without rewards (player teleported / reset).
function FlightService.Cancel(player: Player)
	local s = states[player]
	if s then
		s.Charging = false
		if s.Active then
			local id = s.Active.Plan.Id
			s.Active = nil
			remotes.FlightLanded:FireAllClients({ Id = id, UserId = player.UserId, Cancelled = true })
		end
	end
end

function FlightService.Init(reg: { [string]: any })
	registry = reg
	remotes.FlightStarted = Remotes.Event("FlightStarted")
	remotes.FlightRing = Remotes.Event("FlightRing")
	remotes.FlightLanded = Remotes.Event("FlightLanded")
	remotes.ChargeState = Remotes.Event("ChargeState")
end

function FlightService.Start()
	Guard.OnEvent(Remotes.Event("RequestThrowCharge"), 4, 6, onCharge)
	Guard.OnEvent(Remotes.Event("RequestThrow"), 4, 6, onRelease)
	Guard.OnEvent(Remotes.Event("RequestGust"), 8, 10, onGust)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	RunService.Heartbeat:Connect(step)
end

-- Exposed for diagnostics.
function FlightService.ActiveCount(): number
	local n = 0
	for _, s in states do
		if s.Active then
			n += 1
		end
	end
	return n
end

return FlightService
