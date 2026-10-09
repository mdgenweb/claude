-- Server services driven end-to-end with stubbed Roblox APIs: throw state machine, ring payouts,
-- gust judging, landing rewards, training, shop, pets, rebirth, worlds, rewards, monetization.
local failures, checks = 0, 0
local function check(cond, msg)
	checks += 1
	if not cond then
		failures += 1
		print("FAILED: " .. msg)
	end
end

local Data = makeDataStub()
local Remotes = makeRemotesStub()
local inZone = true
local padUnder = nil
local MapStub = {
	InThrowZone = function()
		return inZone
	end,
	PadAt = function()
		return padUnder
	end,
	Near = function()
		return true
	end,
	SpawnCFrame = function()
		return Vector3.new(0, 0, 0)
	end,
	Anchor = function()
		return nil
	end,
}
local Notes = {}
local NotifyStub = {
	Toast = function(player, text, kind)
		table.insert(Notes, { player, text, kind })
	end,
	All = function(text, kind)
		table.insert(Notes, { "all", text, kind })
	end,
}
STUB("ServerScriptService/Server/Services/DataService", Data)
STUB("ServerScriptService/Server/Services/MapService", MapStub)
STUB("ServerScriptService/Server/Services/NotifyService", NotifyStub)
STUB("ServerScriptService/Server/Util/Guard", GuardStub)
STUB("ReplicatedStorage/Shared/Net/Remotes", Remotes)

local Flight = MODULE("ReplicatedStorage/Shared/Config/Flight")
local FlightSim = MODULE("ReplicatedStorage/Shared/Sim/FlightSim")
local Zones = MODULE("ReplicatedStorage/Shared/Definitions/Zones")
local Economy = MODULE("ReplicatedStorage/Shared/Config/Economy")
local Training = MODULE("ReplicatedStorage/Shared/Definitions/Training")
local Progression = MODULE("ReplicatedStorage/Shared/Sim/Progression")

local registry = {}
local function load(name)
	local m = MODULE("ServerScriptService/Server/Services/" .. name)
	registry[name] = m
	return m
end
registry.DataService = Data
registry.MapService = MapStub
registry.NotifyService = NotifyStub
local Monetization = load("MonetizationService")
local Stat = load("StatService")
local Tutorial = load("TutorialService")
local FlightService = load("FlightService")
local TrainingService = load("TrainingService")
local Shop = load("ShopService")
local PetService = load("PetService")
local Rebirth = load("RebirthService")
local WorldService = load("WorldService")
local Reward = load("RewardService")
local Settings = load("SettingsService")
for _, name in { "MonetizationService", "StatService", "TutorialService", "FlightService", "TrainingService", "ShopService", "PetService", "RebirthService", "WorldService", "RewardService", "SettingsService" } do
	local s = registry[name]
	if s.Init then
		s.Init(registry)
	end
end
for _, name in { "FlightService", "TrainingService", "ShopService", "PetService", "RebirthService", "WorldService", "RewardService", "SettingsService", "TutorialService", "MonetizationService" } do
	registry[name].Start()
end
local step = FAKE_GAME:GetService("RunService").Heartbeat.handlers[1]
check(step ~= nil, "flight heartbeat connected")

local player = makePlayer(1)
local profile = Data.Load(player)
FAKE_GAME:GetService("Players").PlayerAdded:Fire(player)

local function advance(seconds)
	local steps = math.ceil(seconds / 0.05)
	for _ = 1, steps do
		CLOCK += 0.05
		step()
	end
end
local function untilLanded()
	for _ = 1, 2000 do
		if not FlightService.IsFlying(player) then
			return
		end
		CLOCK += 0.05
		step()
	end
end

-- 1. throwing outside the zone is refused --------------------------------------------------
inZone = false
HANDLERS.RequestThrowCharge(player)
local cs = Remotes.Last("ChargeState", player)
check(cs and cs.Charging == false and cs.Reason == "NotInZone", "charge refused outside zone")
check(not FlightService.IsFlying(player), "no flight outside zone")

-- 2. charge + perfect release ----------------------------------------------------------------
inZone = true
profile.Rebirths = 1 -- cap 40, x3 multiplier
profile.Skill = 1000
Progression.SyncLevel(profile)
HANDLERS.RequestThrowCharge(player)
check(Remotes.Last("ChargeState", player).Charging == true, "charging started")
CLOCK += Flight.MeterPeriod * 0.48 -- meter ~0.96
HANDLERS.RequestThrow(player)
local plan = Remotes.Last("FlightStarted")
check(plan ~= nil and plan.UserId == 1, "flight broadcast")
check(plan.PerfectLaunch == true, "perfect launch from server-timed meter")
check(FlightService.IsFlying(player), "flying")
HANDLERS.RequestThrow(player)
check(Remotes.Count("FlightStarted") == 1, "second throw while flying refused")

-- 3. rings: perfect tap on ring 1, nothing on ring 2, spam is punished -----------------------
local start = plan.Start
local skillBefore = profile.Skill
CLOCK = start + plan.RingTimes[1] - 0.05
step()
HANDLERS.RequestGust(player, plan.Id, 1)
HANDLERS.RequestGust(player, "x", 1) -- invalid args ignored
HANDLERS.RequestGust(player, plan.Id, 0 / 0)
HANDLERS.RequestGust(player, plan.Id + 99, 2) -- wrong flight ignored
advance(plan.RingTimes[2] + 1 - (CLOCK - start))
local r1, r2
for _, f in Remotes.fired do
	if f.Name == "FlightRing" and f.Payload.Index == 1 then
		r1 = f.Payload
	elseif f.Name == "FlightRing" and f.Payload.Index == 2 then
		r2 = f.Payload
	end
end
check(r1 and r1.Perfect == true, "ring 1 perfect")
check(r2 and r2.Perfect == false, "ring 2 normal")
check(r1 and r2 and math.abs(r1.Amount - 2 * r2.Amount) < 1e-6, "perfect pays x2")
check(r2 and math.abs(r2.Amount - 1 * Stat.SkillMultiplier(player)) < 1e-6, "ring pays glider skill x multiplier")
check(profile.Skill > skillBefore, "skill increased from rings")
-- spam on ring 3 (well before it, as an autoclicker would)
local spamRing = #plan.RingTimes
if spamRing >= 3 then
	CLOCK = start + plan.RingTimes[spamRing] - 0.6
	for _ = 1, 10 do
		HANDLERS.RequestGust(player, plan.Id, spamRing)
	end
end

-- 4. landing pays the zone ------------------------------------------------------------------
local winsBefore = profile.Wins
untilLanded()
check(not FlightService.IsFlying(player), "landed")
local landed = Remotes.Last("FlightLanded", player)
local zone = Zones.At(1, plan.Distance)
check(landed and landed.Owner == true and landed.Zone == zone.Id, "owner landing payload")
check(math.abs(profile.Wins - winsBefore - zone.Wins) < 1e-6, "zone wins paid (" .. tostring(profile.Wins - winsBefore) .. ")")
check(profile.Stats.Throws == 1 and profile.Best["1"] == plan.Distance, "stats + best updated")
check(profile.Zones[zone.Id] == true, "zone discovered")
check(profile.Level > 1, "level derived from skill")
if spamRing >= 3 then
	local r3
	for _, f in Remotes.fired do
		if f.Name == "FlightRing" and f.Payload.Index == spamRing then
			r3 = f.Payload
		end
	end
	check(r3 and r3.Perfect == false, "spammed ring is not perfect")
end
-- cooldown
HANDLERS.RequestThrow(player)
check(Remotes.Last("ChargeState", player).Reason == "Cooldown", "cooldown after landing")
advance(Flight.LandCooldown + 0.1)

-- 5. auto throw needs the pass ----------------------------------------------------------------
HANDLERS.RequestToggle(player, "AutoThrow", true)
check(profile.Settings.AutoThrow == false, "auto throw refused without pass")
local starts = Remotes.Count("FlightStarted")
local res = HANDLERS.RequestPurchase(player, "Pass", "AutoThrow")
check(res.ok and profile.TestPasses.AutoThrow, "studio test pass granted")
HANDLERS.RequestToggle(player, "AutoThrow", true)
check(profile.Settings.AutoThrow == true, "auto throw enabled with pass")
advance(Flight.AutoThrowDelay + 0.2)
check(Remotes.Count("FlightStarted") == starts + 1 and FlightService.IsFlying(player), "auto throw launched")
local autoPlan = Remotes.Last("FlightStarted")
check(math.abs(autoPlan.Launch - Flight.AutoLaunchMeter) < 1e-9, "auto launch quality")
HANDLERS.RequestToggle(player, "AutoThrow", false)
untilLanded()
advance(3)
check(not FlightService.IsFlying(player), "auto throw stops when toggled off")

-- 6. training -----------------------------------------------------------------------------------
local skill0 = profile.Skill
padUnder = nil
HANDLERS.RequestTrain(player)
check(profile.Skill == skill0, "no rep off-pad")
padUnder = Training.Get("w1_pad2") -- 4x, needs 2 rebirths
HANDLERS.RequestTrain(player)
check(profile.Skill == skill0, "locked pad refuses")
padUnder = Training.Get("w1_pad1")
HANDLERS.RequestTrain(player)
check(math.abs(profile.Skill - skill0 - Stat.SkillMultiplier(player)) < 1e-6, "1x pad pays multiplier")
check(Remotes.Last("TrainResult", player) ~= nil, "train result sent")
padUnder = Training.Get("w1_pass1")
local before = profile.Skill
HANDLERS.RequestTrain(player)
check(profile.Skill == before, "pass pad locked without pass")
HANDLERS.RequestPurchase(player, "Pass", "Pad3x")
HANDLERS.RequestTrain(player)
check(math.abs(profile.Skill - before - 3 * Stat.SkillMultiplier(player)) < 1e-6, "pass pad pays 3x")

-- 7. shop -----------------------------------------------------------------------------------------
profile.Wins = 1
local buy = HANDLERS.RequestBuyThrowable(player, "notebook_glider")
check(not buy.ok and not profile.Gliders.notebook_glider, "can't afford glider")
profile.Wins = 10
buy = HANDLERS.RequestBuyThrowable(player, "notebook_glider")
check(buy.ok and profile.Gliders.notebook_glider and profile.Wins == 8 and profile.Glider == "notebook_glider", "glider bought and auto-equipped")
check(not HANDLERS.RequestBuyThrowable(player, "notebook_glider").ok, "can't buy twice")
check(not HANDLERS.RequestBuyThrowable(player, "ash_dart").ok, "locked world glider refused")
check(not HANDLERS.RequestBuyThrowable(player, { "hack" }).ok, "bad id refused")
check(HANDLERS.RequestEquipThrowable(player, "paper_dart").ok and profile.Glider == "paper_dart", "equip owned")
check(not HANDLERS.RequestEquipThrowable(player, "breeze_jet").ok, "equip unowned refused")
check(not HANDLERS.RequestEquipThrowable(player, "relic:aurora_relic").ok, "relic not owned")
profile.Wins = 1000
check(HANDLERS.RequestTrailAction(player, "Buy", "bubble").ok and profile.Trail == "bubble" and profile.Wins == 900, "trail bought")

-- 8. pets ------------------------------------------------------------------------------------------
local eggPrice = MODULE("ReplicatedStorage/Shared/Definitions/Eggs").Get("beach_egg").Price
profile.Wins = eggPrice - 1
local hatch = HANDLERS.RequestHatchEgg(player, "beach_egg", 1)
check(not hatch.ok, "egg too expensive")
profile.Wins = eggPrice * 40
local counts = {}
for _ = 1, 30 do
	local h = HANDLERS.RequestHatchEgg(player, "beach_egg", 1)
	check(h.ok and #h.pets == 1, "hatch ok")
	counts[h.pets[1].Id] = (counts[h.pets[1].Id] or 0) + 1
end
check(profile.Wins == eggPrice * 10, "hatch cost charged")
check(#profile.EquippedPets == Economy.PetSlots, "pets auto-equipped up to slots")
check(type(player:GetAttribute("Pets")) == "string" and #player:GetAttribute("Pets") > 0, "pets mirrored to attribute")
check(not HANDLERS.RequestHatchEgg(player, "beach_egg", 3).ok, "triple hatch needs pass")
check(not HANDLERS.RequestHatchEgg(player, "overlord_egg", 1).ok, "robux egg not hatchable with wins")
check(not HANDLERS.RequestHatchEgg(player, "ember_egg", 1).ok, "other world egg refused")
local anyUid = profile.EquippedPets[1]
check(HANDLERS.RequestPetAction(player, "Lock", anyUid).ok and profile.Pets[anyUid].Locked, "lock pet")
local del = HANDLERS.RequestPetAction(player, "Delete", { anyUid })
check(profile.Pets[anyUid] ~= nil, "locked pet not deleted")
check(HANDLERS.RequestPetAction(player, "EquipBest").ok and #profile.EquippedPets == Economy.PetSlots, "equip best")
check(not HANDLERS.RequestPetAction(player, "Equip", "nope").ok, "equip unknown pet refused")
check(not HANDLERS.RequestPetAction(player, "Delete", "notatable").ok, "bad delete args refused")

-- 9. rebirth ----------------------------------------------------------------------------------------
check(not HANDLERS.RequestRebirth(player).ok, "rebirth needs max level")
profile.Skill = Economy.SkillForLevel(Progression.LevelCap(profile)) + 1
Progression.SyncLevel(profile)
check(profile.Level == Progression.LevelCap(profile), "reached the cap")
local capSkill = profile.Skill
padUnder = Training.Get("w1_pad1")
HANDLERS.RequestTrain(player)
check(profile.Skill == capSkill, "training stops at max level")
local wins = profile.Wins
local rb = HANDLERS.RequestRebirth(player)
check(rb.ok and profile.Rebirths == 2 and profile.Skill == 0 and profile.Level == 1, "rebirth resets")
check(profile.Wins == wins and profile.Gliders.notebook_glider, "rebirth keeps wins and gliders")
check(Progression.SkillBreakdown(profile, Stat.Context(player)).Rebirth == Economy.RebirthMultiplier(2), "rebirth multiplier applied")

-- 10. worlds: reaching the end of the river unlocks the next one ------------------------------------
check(not HANDLERS.RequestEnterWorld(player, 2).ok and not profile.Worlds["2"], "world 2 locked before the river end")
-- a huge throw reaches the last zone of world 1 (the rebirth gate is met)
profile.Rebirths = 5
profile.Skill = 1e12
padUnder = nil
inZone = true
advance(3)
HANDLERS.RequestThrow(player)
local bigPlan = Remotes.Last("FlightStarted")
check(bigPlan and bigPlan.Distance >= Zones.Last(1).Distance, "throw reaches the river end")
untilLanded()
local bigLanding = Remotes.Last("FlightLanded", player)
check(bigLanding and bigLanding.UnlockedWorld == 2 and profile.Worlds["2"], "river end unlocks world 2")
local winsBeforeTravel = profile.Wins
local ew = HANDLERS.RequestEnterWorld(player, 2)
check(ew.ok and profile.World == 2 and profile.Wins == winsBeforeTravel, "travel to world 2 (free)")
check(not HANDLERS.RequestEnterWorld(player, 4).ok, "skipping worlds refused")
check(not HANDLERS.RequestEnterWorld(player, 99).ok, "unknown world refused")
check(HANDLERS.RequestEnterWorld(player, 1).ok and profile.World == 1, "travel back")

-- 11. rewards ------------------------------------------------------------------------------------------
check(not HANDLERS.RequestClaimGift(player, 1).ok, "gift not ready at 0 min")
local d = HANDLERS.RequestClaimDaily(player)
check(d.ok and profile.Daily.Streak == 1, "daily claimed")
check(not HANDLERS.RequestClaimDaily(player).ok, "daily once per day")
local code = HANDLERS.RequestRedeemCode(player, " launch ")
check(code.ok and profile.Codes.LAUNCH, "code redeemed case-insensitively")
check(not HANDLERS.RequestRedeemCode(player, "LAUNCH").ok, "code once")
check(not HANDLERS.RequestRedeemCode(player, "NOPE").ok, "bad code")
local potions = profile.Potions.skill_potion or 0
check(potions >= 1, "potion from code")
local use = HANDLERS.RequestUseBoost(player, "skill_potion")
check(use.ok and (profile.Boosts.skill_potion or 0) > os.time(), "potion activated")
check(Progression.SkillBreakdown(profile, Stat.Context(player)).Potion == 2, "potion doubles skill")

-- 12. monetization (Studio test grants) ---------------------------------------------------------------
local sp = HANDLERS.RequestPurchase(player, "Product", "StarterPack")
check(sp.ok and profile.Flags.StarterPack, "starter pack granted")
check(not HANDLERS.RequestPurchase(player, "Product", "StarterPack").ok, "starter pack once")
local skillBeforePack = profile.Skill
HANDLERS.RequestPurchase(player, "Product", "Skill10K")
check(profile.Skill - skillBeforePack == 10000, "skill pack in world 1 = 10K")
local relic = HANDLERS.RequestPurchase(player, "Product", "AuroraRelic")
check(relic.ok and profile.Relics.aurora_relic and profile.Relic == "aurora_relic", "relic granted and equipped")
check(not HANDLERS.RequestPurchase(player, "Product", "AuroraRelic").ok, "relic once")
check(not HANDLERS.RequestPurchase(player, "Product", "Nope").ok and not HANDLERS.RequestPurchase(player, "Hack", "x").ok, "bad purchase refused")

-- 13. tutorial advanced only by server events -----------------------------------------------------------
local fresh = makePlayer(2)
local fp = Data.Load(fresh)
padUnder = Training.Get("w1_pad1")
for i = 1, 14 do
	HANDLERS.RequestTrain(fresh)
end
check(fp.Tutorial.Step == 1 and fp.Tutorial.Progress == 14, "tutorial counts reps")
HANDLERS.RequestTrain(fresh)
check(fp.Tutorial.Step == 2 and fp.Tutorial.Progress == 0, "tutorial advances after 15 reps")
Tutorial.Event(fresh, "Throw")
check(fp.Tutorial.Step == 2, "out-of-order events ignored")
Tutorial.Event(fresh, "EnterThrowZone")
check(fp.Tutorial.Step == 3, "zone step")

print(string.format("services.spec: %d checks, %d failures", checks, failures))
