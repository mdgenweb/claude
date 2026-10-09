-- Progression math, definition integrity and profile sanitisation.
local Progression = MODULE("ReplicatedStorage/Shared/Sim/Progression")
local Economy = MODULE("ReplicatedStorage/Shared/Config/Economy")
local Flight = MODULE("ReplicatedStorage/Shared/Config/Flight")
local Monetization = MODULE("ReplicatedStorage/Shared/Config/Monetization")
local Gliders = MODULE("ReplicatedStorage/Shared/Definitions/Gliders")
local Relics = MODULE("ReplicatedStorage/Shared/Definitions/Relics")
local Pets = MODULE("ReplicatedStorage/Shared/Definitions/Pets")
local Eggs = MODULE("ReplicatedStorage/Shared/Definitions/Eggs")
local Trails = MODULE("ReplicatedStorage/Shared/Definitions/Trails")
local Training = MODULE("ReplicatedStorage/Shared/Definitions/Training")
local Boosts = MODULE("ReplicatedStorage/Shared/Definitions/Boosts")
local Rewards = MODULE("ReplicatedStorage/Shared/Definitions/Rewards")
local Tutorial = MODULE("ReplicatedStorage/Shared/Definitions/Tutorial")
local Worlds = MODULE("ReplicatedStorage/Shared/Definitions/Worlds")
local Zones = MODULE("ReplicatedStorage/Shared/Definitions/Zones")
local Rarity = MODULE("ReplicatedStorage/Shared/Config/Rarity")
local Format = MODULE("ReplicatedStorage/Shared/Util/Format")
local Schema = MODULE("ServerScriptService/Server/Data/Schema")

local failures, checks = 0, 0
local function check(cond, msg)
	checks += 1
	if not cond then
		failures += 1
		print("FAILED: " .. msg)
	end
end

local function profile()
	return Schema.Default()
end
local function ctx(passes, friends)
	return { Passes = passes or {}, Friends = friends or 0, Premium = false, Now = 1000 }
end

-- observed anchors from the reference screenshots
check(Economy.LevelCap(0) == 20, "level cap 20 at 0 rebirths")
check(Economy.LevelCap(2) == 60, "level cap 60 at 2 rebirths")
check(math.floor(50 / Economy.LevelCap(2) * 100) == 83, "level 50 at 2 rebirths shows 83%")
-- level curve fitted to the HUD: Level 50 with 25.29K Skill showing 3.07K / 4.05K
local w50 = Economy.XPToNext(50)
check(w50 > 3800 and w50 < 4300, "level 50 is ~4.05K Skill wide (" .. math.floor(w50) .. ")")
check(Economy.LevelForSkill(25290, 60) == 50, "25.29K Skill is level 50 (got " .. Economy.LevelForSkill(25290, 60) .. ")")
check(math.abs((25290 - Economy.SkillForLevel(50)) - 3070) < 800, "progress inside level 50 ~3.07K")
for level = 1, 400 do
	local s0 = Economy.SkillForLevel(level)
	check(Economy.LevelForSkill(s0, 1000) == level, "level boundary " .. level)
	if level > 1 then
		check(Economy.LevelForSkill(s0 - math.max(1e-9, s0 * 1e-12), 1000) == level - 1, "below boundary " .. level)
	end
end
check(Economy.LevelForSkill(0, 20) == 1 and Economy.LevelForSkill(1e300, 20) == 20, "level clamps")
check(Economy.RebirthMultiplier(0) == 1 and Economy.RebirthMultiplier(2) == 5, "x1 / x5 multipliers")

-- levels derived from Skill
local p = profile()
p.Skill = 1e9
local gained = Progression.SyncLevel(p)
check(p.Level == Economy.LevelCap(0), "level capped at max level")
check(gained == Economy.LevelCap(0) - 1, "levels gained count")
check(Progression.CanRebirth(p), "can rebirth at cap")
check(Progression.RebirthProgress(p) == 1, "100% at cap")
check(not Progression.SourcePays(p, "Train") and not Progression.SourcePays(p, "Ring"), "training and rings stop at the cap")
check(Progression.SourcePays(p, "Product") and Progression.SourcePays(p, "Gift"), "purchases and gifts still pay at the cap")
local q = profile()
q.Skill = Economy.SkillForLevel(2) - 0.01
Progression.SyncLevel(q)
check(q.Level == 1, "just below level 2")
q.Skill = Economy.SkillForLevel(2)
check(Progression.SyncLevel(q) == 1 and q.Level == 2, "exact threshold levels up")
q.Skill = 0 / 0
Progression.SyncLevel(q)
check(q.Level == 1, "NaN skill -> level 1")

-- multipliers
local m = profile()
check(Progression.SkillMultiplier(m, ctx()) == 1, "fresh multiplier x1")
m.Rebirths = 2
check(Progression.SkillMultiplier(m, ctx()) == 5, "rebirth multiplier")
check(Progression.SkillMultiplier(m, ctx({ DoubleSkill = true })) == 10, "2x skill pass")
check(math.abs(Progression.SkillMultiplier(m, ctx({}, 2)) - 6) < 1e-9, "2 friends = +20%")
check(math.abs(Progression.FriendBoost(99) - Economy.FriendBoostMax) < 1e-9, "friend boost capped")
m.Boosts.skill_potion = 2000
check(Progression.SkillMultiplier(m, ctx()) == 10, "active skill potion")
m.Boosts.skill_potion = 500
check(Progression.SkillMultiplier(m, ctx()) == 5, "expired potion ignored")
m.Pets["1"] = { Id = "golden_gull", Locked = false }
m.Pets["2"] = { Id = "sandy_crab", Locked = false }
m.EquippedPets = { "1", "2" }
local petSkill, petWins = Progression.PetBoosts(m)
check(math.abs(petSkill - 11) < 1e-9 and math.abs(petWins - 0.25) < 1e-9, "pet boosts add up (x11 + x2)")
check(math.abs(Progression.WinsMultiplier(m, ctx({ DoubleWins = true })) - 2.5) < 1e-9, "wins multiplier")
check(Progression.SkillMultiplier(m, ctx()) == 5 * 12, "pets multiply skill (x5 rebirth x x12 pets)")
check(Progression.PetSlots(ctx()) == Economy.PetSlots and Progression.PetSlots(ctx({ PetSlots = true })) == Economy.PetSlots + Economy.PetSlotsPass, "pet slots")

-- relic: always 125% better than the best owned glider
local r = profile()
r.Gliders.balsa_wing = true
r.Glider = "paper_dart"
check(Progression.SkillPerRing(r) == 1, "equipped glider skill")
r.Relics.aurora_relic = true
r.Relic = "aurora_relic"
check(math.abs(Progression.SkillPerRing(r) - 30 * 2.25) < 1e-9, "relic = best glider x 2.25")

-- definitions
local function unique(list, field, what)
	local seen = {}
	for _, item in list do
		check(not seen[item[field]], "duplicate " .. what .. " " .. tostring(item[field]))
		seen[item[field]] = true
	end
end
unique(Gliders.List, "Id", "glider")
unique(Pets.List, "Id", "pet")
unique(Eggs.List, "Id", "egg")
unique(Trails.List, "Id", "trail")
unique(Training.List, "Id", "pad")
unique(Monetization.Passes, "Key", "pass")
unique(Monetization.Products, "Key", "product")

for _, world in Worlds.List do
	local list = Gliders.ForWorld(world.Id)
	check(#list >= 6 and #list <= 12, "glider count per world " .. world.Id)
	for i = 2, #list do
		check(list[i].Price > list[i - 1].Price and list[i].SkillPerRing > list[i - 1].SkillPerRing, "gliders get better and pricier " .. list[i].Id)
	end
	check(#Training.ForWorld(world.Id) == Training.SlotsPerWorld, "7 pads per world")
	check(#Eggs.ForWorld(world.Id) >= 2, "eggs per world")
	if world.Id > 1 then
		local prevWorld = Worlds.Get(world.Id - 1)
		check(world.UnlockRebirths > prevWorld.UnlockRebirths, "world rebirth gates increase")
		local last = Zones.Last(prevWorld.Id)
		check(world.UnlockZone == last.Id, "world unlocks at the end of the previous river")
		check(world.DistanceScale > prevWorld.DistanceScale, "worlds get longer")
	end
end
for _, g in Gliders.List do
	check(Rarity.Exists(g.Rarity), "glider rarity " .. g.Id)
end
for _, pad in Training.List do
	if pad.PassKey then
		check(Monetization.Pass(pad.PassKey) ~= nil, "pad pass exists " .. pad.Id)
	end
end
for _, relic in Relics.List do
	local product = Monetization.Product(relic.ProductKey)
	check(product ~= nil and product.Kind == "Relic" and product.Ref == relic.Id, "relic product " .. relic.Id)
end
for _, egg in Eggs.List do
	local total = 0
	for _, entry in Eggs.Odds(egg, 1) do
		total += entry.Chance
	end
	check(math.abs(total - 1) < 1e-9, "odds sum to 1 " .. egg.Id)
	if egg.ProductKey then
		local product = Monetization.Product(egg.ProductKey)
		check(product ~= nil and product.Kind == "Egg" and product.Ref == egg.Id, "egg product " .. egg.Id)
	else
		check(egg.Price > 0, "egg price " .. egg.Id)
	end
	-- luck makes rare tiers more likely
	local base, lucky = 0, 0
	local minOrder = math.huge
	for _, entry in egg.Pets do
		minOrder = math.min(minOrder, Rarity.Order(Pets.Get(entry.Pet).Rarity))
	end
	for i, entry in Eggs.Odds(egg, 1) do
		local pet = Pets.Get(entry.Pet)
		if Rarity.Order(pet.Rarity) > minOrder then
			base += entry.Chance
			lucky += Eggs.Odds(egg, 2)[i].Chance
		end
	end
	check(lucky > base, "luck helps " .. egg.Id)
end
for _, product in Monetization.Products do
	if product.Kind == "Potion" then
		check(Boosts.Exists(product.Ref), "potion product ref " .. product.Key)
	end
end
check(Pets.Exists(Monetization.StarterPack.Pet), "starter pack pet")
local function validReward(reward, where)
	if reward.Kind == "Potion" then
		check(Boosts.Exists(reward.Id), "reward potion " .. where)
	elseif reward.Kind == "Pet" then
		check(Pets.Exists(reward.Id), "reward pet " .. where)
	else
		check(reward.Kind == "Wins" or reward.Kind == "Skill", "reward kind " .. where)
	end
end
for i, gift in Rewards.Gifts do
	validReward(gift.Reward, "gift " .. i)
	if i > 1 then
		check(gift.Minutes > Rewards.Gifts[i - 1].Minutes, "gift times increase")
	end
end
for i, reward in Rewards.Daily do
	validReward(reward, "daily " .. i)
end
for _, step in Tutorial.Steps do
	check(step.Target == nil or step.Target == "Pad1" or step.Target == "ThrowZone" or step.Target == "GliderShop" or step.Target == "Egg1", "tutorial target " .. step.Id)
end
-- the tutorial's "buy a glider" step must be reachable: first upgrade affordable with a few throws
check(Gliders.ForWorld(1)[2].Price <= Zones.ForWorld(1)[1].Wins * 5, "first glider affordable early")

-- formatting
check(Format.Short(999) == "999", "short 999")
check(Format.Short(25290) == "25.29K", "short 25.29K")
check(Format.Short(1e6) == "1M", "short 1M")
check(Format.Short(3.07e3) == "3.07K", "short 3.07K")
check(type(Format.Short(1e300)) == "string", "short huge")
check(Format.Meters(144) == "144 m", "meters")

-- schema sanitisation
local garbage = { Skill = "lots", Wins = -5, Level = 9999, Rebirths = 0 / 0, Glider = "nope", Gliders = { nope = true, balsa_wing = true },
	Pets = { ["1"] = { Id = "golden_gull" }, ["2"] = { Id = "fake_pet" }, [3] = "x" }, EquippedPets = { "1", "1", "2", "9" },
	Worlds = { ["1"] = true, ["9"] = true, ["2"] = true }, World = 7, Version = 1, Boosts = { skill_potion = 1e30, bogus = 5 },
	Receipts = { "a", 5 }, Codes = { LAUNCH = true, [5] = true }, Settings = { AutoTrain = "yes", Sfx = false } }
local s = Schema.Sanitize(garbage)
check(s.Skill == 0, "bad skill reset")
check(s.Wins == 0, "negative wins clamped")
check(s.Rebirths == 0 and s.Level == 1, "stored level ignored; derived from skill")
check(s.Glider == Gliders.Default and s.Gliders.balsa_wing and not s.Gliders.nope and s.Gliders[Gliders.Default], "gliders sanitized")
check(s.Pets["1"] ~= nil and s.Pets["2"] == nil, "unknown pets dropped")
check(#s.EquippedPets == 1 and s.EquippedPets[1] == "1", "equipped pets deduped and validated")
check(s.Worlds["1"] and s.Worlds["2"] and not s.Worlds["9"], "worlds sanitized")
check(s.World == 1, "invalid current world reset")
check(s.Boosts.bogus == nil and (s.Boosts.skill_potion or 0) <= os.time() + Boosts.MaxStackSeconds, "boosts sanitized")
check(#s.Receipts == 1, "receipts sanitized")
check(s.Codes.LAUNCH == true, "codes kept")
check(s.Settings.AutoTrain == false and s.Settings.Sfx == false, "settings sanitized")
local fresh = Schema.Sanitize(nil)
check(fresh.Skill == 0 and fresh.Level == 1 and fresh.Gliders[Gliders.Default], "nil -> default")
local view = Schema.PublicView(s)
check(view.Receipts == nil and view.TestPasses == nil, "private fields not exposed")
-- round trip stays stable
local again = Schema.Sanitize(s)
check(again.Wins == s.Wins and again.Glider == s.Glider and #again.EquippedPets == #s.EquippedPets, "sanitize is idempotent")

-- special throws: rare, deterministic per seed, rarest first
do
	local FlightSim = MODULE("ReplicatedStorage/Shared/Sim/FlightSim")
	local jet, titan = 0, 0
	for seed = 1, 200000 do
		local s = FlightSim.RollSpecial(seed, 1)
		if s and s.Id == "JetStream" then
			jet += 1
		elseif s and s.Id == "SkyTitan" then
			titan += 1
		end
	end
	check(jet > 1600 and jet < 2400, "jet stream ~1% (" .. jet .. ")")
	check(titan > 120 and titan < 290, "sky titan ~0.1% (" .. titan .. ")")
	check(FlightSim.RollSpecial(12345, 1) == FlightSim.RollSpecial(12345, 1), "special roll deterministic")
end

-- economy simulation: a player who trains, throws (60% perfect taps), buys the best affordable
-- glider, hatches eggs, rebirths at the cap and moves on when a river end is reached.
do
	local Economy2 = Economy
	local FlightSim = MODULE("ReplicatedStorage/Shared/Sim/FlightSim")
	local sim = profile()
	local seconds = 0
	local throws = 0
	local log = {}
	local cycleStart = 0
	local reached = {}
	local function bestPad()
		local pad = 1
		for _, def in Training.ForWorld(sim.World) do
			if not def.PassKey and sim.Rebirths >= def.Rebirths then
				pad = math.max(pad, def.Multiplier)
			end
		end
		return pad
	end
	local seed = 1
	while seconds < 40 * 3600 do
		local c = ctx()
		local mult = Progression.SkillMultiplier(sim, c)
		-- 15 s of tapping at 3 reps/s on the best open pad
		if Progression.SourcePays(sim, "Train") then
			sim.Skill += 15 * 3 * bestPad() * mult
			Progression.SyncLevel(sim)
		end
		seed += 1
		local world = MODULE("ReplicatedStorage/Shared/Definitions/Worlds").Get(sim.World)
		local plan = FlightSim.Build({ Id = 1, UserId = 1, World = sim.World, WorldScale = world.DistanceScale, Skill = sim.Skill, Launch = 0.7, Seed = seed, Glider = sim.Glider, Start = 0 })
		local zone = Zones.At(sim.World, plan.Distance)
		if Progression.SourcePays(sim, "Ring") then
			sim.Skill += #plan.Rings * 1.6 * Progression.SkillPerRing(sim) * mult
			Progression.SyncLevel(sim)
		end
		sim.Wins += zone.Wins * Progression.WinsMultiplier(sim, c)
		throws += 1
		seconds += 15 + plan.Duration + 1
		-- shopping: best affordable glider in this world, then eggs with spare wins
		for _, g in Gliders.ForWorld(sim.World) do
			if not sim.Gliders[g.Id] and sim.Wins >= g.Price and g.SkillPerRing > Progression.SkillPerRing(sim) then
				sim.Wins -= g.Price
				sim.Gliders[g.Id] = true
				sim.Glider = g.Id
			end
		end
		for _, egg in Eggs.ForWorld(sim.World) do
			if not egg.ProductKey and sim.Wins >= egg.Price * 4 then
				sim.Wins -= egg.Price
				-- expected pet: take the median entry
				local entry = egg.Pets[2]
				local uid = tostring(sim.NextPetId)
				sim.NextPetId += 1
				sim.Pets[uid] = { Id = entry.Pet, Locked = false }
				table.insert(sim.EquippedPets, uid)
				table.sort(sim.EquippedPets, function(a, b)
					return Pets.Get(sim.Pets[a].Id).SkillBoost > Pets.Get(sim.Pets[b].Id).SkillBoost
				end)
				while #sim.EquippedPets > Economy2.PetSlots do
					table.remove(sim.EquippedPets)
				end
			end
		end
		-- river end -> next world
		local last = Zones.Last(sim.World)
		local nextWorld = MODULE("ReplicatedStorage/Shared/Definitions/Worlds").Get(sim.World + 1)
		if last and zone.Id == last.Id and not reached[sim.World] and (not nextWorld or sim.Rebirths >= nextWorld.UnlockRebirths) then
			reached[sim.World] = true
			table.insert(log, string.format("  reached end of world %d at %.1f h (rebirth %d)", sim.World, seconds / 3600, sim.Rebirths))
			if sim.World < 4 then
				sim.World += 1
			else
				break
			end
		end
		if Progression.CanRebirth(sim) then
			table.insert(log, string.format("  rebirth %d after %.1f min (cycle %.1f min, world %d, skill %s, %s, wins %s, glider %s)", sim.Rebirths + 1, seconds / 60, (seconds - cycleStart) / 60, sim.World, Format.Short(sim.Skill), Format.Meters(plan.Distance), Format.Short(sim.Wins), sim.Glider))
			cycleStart = seconds
			sim.Rebirths += 1
			sim.Skill = 0
			Progression.SyncLevel(sim)
		end
	end
	print("progression sim (" .. throws .. " throws):")
	for _, line in log do
		print(line)
	end
	check(#log >= 2, "sim progresses")
end

print(string.format("progression.spec: %d checks, %d failures", checks, failures))
