--!prelude-before _rbxmock.luau
--!prelude-after _clientmock.luau
-- Boots the real client (every screen and controller, as Main.client.luau does) against the
-- Roblox API mock and a real world 1 map, then drives a whole session: data arrives, every menu
-- opens, the player trains on a pad, throws, rides a full flight with gust taps and ring payouts,
-- lands, hatches an egg, gets toasts, changes world and sees other players' pets. Any error inside
-- a handler, tween or scheduled task fails the spec.
local CLIENT = "StarterPlayer/StarterPlayerScripts/Client/"
local Schema = MODULE("ServerScriptService/Server/Data/Schema")
local Progression = MODULE("ReplicatedStorage/Shared/Sim/Progression")
local Economy = MODULE("ReplicatedStorage/Shared/Config/Economy")
local FlightSim = MODULE("ReplicatedStorage/Shared/Sim/FlightSim")
local Map = MODULE("ReplicatedStorage/Shared/Config/Map")
local Worlds = MODULE("ReplicatedStorage/Shared/Definitions/Worlds")
local Zones = MODULE("ReplicatedStorage/Shared/Definitions/Zones")
local MapBuilder = MODULE("ServerScriptService/Server/World/MapBuilder")

local failures, checks = 0, 0
local function check(cond, msg)
	checks += 1
	if not cond then
		failures += 1
		print("FAILED: " .. msg)
	end
end
local function sent(name)
	local n = 0
	for _, s in SENT do
		if s[1] == name then
			n += 1
		end
	end
	return n
end
local function guarded(label, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		table.insert(CLIENT_ERRORS, label .. ": " .. tostring(err))
	end
end

-- world 1 map (the client reads labels/prompts/pads from it)
local workspaceService = FAKE_GAME:GetService("Workspace")
local worldsFolder = Instance.new("Folder")
worldsFolder.Name = "Worlds"
worldsFolder.Parent = workspaceService
MapBuilder.Build(Worlds.Get(1), worldsFolder)

-- boot like Main.client.luau
local StateController = MODULE(CLIENT .. "Controllers/StateController")
local UIController = MODULE(CLIENT .. "Controllers/UIController")
guarded("StateController.Start", StateController.Start)
guarded("UIController.Init", UIController.Init)
local SCREENS = { "Notifications", "HUD", "ShopScreen", "RebirthScreen", "PetsScreen", "EggScreen", "TrailsScreen", "InventoryScreen", "GiftsScreen", "WorldScreen", "SettingsScreen", "AdminScreen", "EventBanner" }
for _, name in SCREENS do
	guarded(name .. ".Init", function()
		MODULE(CLIENT .. "UI/Screens/" .. name).Init()
	end)
end
local CONTROLLERS = { "CameraController", "WorldController", "TrainingController", "ThrowController", "FlightRenderer", "PetFollowController", "TutorialController" }
for _, name in CONTROLLERS do
	guarded(name .. ".Start", function()
		MODULE(CLIENT .. "Controllers/" .. name).Start()
	end)
end
STEP(0.5)
check(#CLIENT_ERRORS == 0, "boot without errors")

-- first PlayerData packet (built like the server: PublicView + decorators)
local profile = Schema.Default()
profile.Skill = 500
profile.Wins = 2500
profile.Rebirths = 1
Progression.SyncLevel(profile)
profile.Pets["1"] = { Id = "golden_gull", Locked = false }
profile.Pets["2"] = { Id = "sandy_crab", Locked = true }
profile.EquippedPets = { "1" }
profile.Potions.skill_potion = 2
profile.Boosts.wins_potion = 1000 + 300
profile.Trails.bubble = true
profile.Gliders.notebook_glider = true
local function view()
	local v = Schema.PublicView(profile)
	local ctx = { Passes = { AutoThrow = true }, Friends = 1, Premium = false, Now = 1000 }
	local breakdown = Progression.SkillBreakdown(profile, ctx)
	v.Derived = {
		SkillMultiplier = breakdown.Total,
		Breakdown = breakdown,
		WinsMultiplier = Progression.WinsMultiplier(profile, ctx),
		Luck = 1,
		FriendBoost = 0.1,
		Friends = 1,
		LevelCap = Progression.LevelCap(profile),
		XPToNext = Economy.XPToNext(profile.Level),
		RebirthProgress = Progression.RebirthProgress(profile),
		CanRebirth = Progression.CanRebirth(profile),
		NextRebirthMultiplier = Economy.RebirthMultiplier(profile.Rebirths + 1),
		SkillPerRing = Progression.SkillPerRing(profile),
		PetSlots = 3,
		Passes = { AutoThrow = true },
		ServerTime = 1000,
	}
	v.Session = { Playtime = 90, GiftsClaimed = {} }
	v.DailyReady = true
	v.IsAdmin = true
	return v
end
SERVER_FIRE("PlayerData", view())
SERVER_FIRE("ServerInfo", { Kind = "Relics", Relics = { aurora_relic = { Sold = 3, Stock = 1000 } } })
SERVER_FIRE("ServerInfo", { Kind = "Leaderboards", Boards = { Wins = { { Name = "A", Value = 10 } } } })
SERVER_FIRE("ServerInfo", { Kind = "Event", Active = true, Name = "SKY FESTIVAL", EndsAt = CLOCK + 600 })
SERVER_FIRE("WorldChanged", 1)
STEP(4) -- gifts auto-open after 3 s when the daily reward is ready
check(#CLIENT_ERRORS == 0, "first data packet without errors")
check(StateController.Data ~= nil and StateController.Data.Skill == 500, "state mirrored")
check(UIController.Get("Gifts") ~= nil and UIController.Get("Gifts"):IsOpen(), "gifts auto-open when the daily reward is ready")
UIController.CloseMenus()

-- every menu opens and closes cleanly
local MENUS = {
	{ "Shop" },
	{ "Rebirth" },
	{ "Pets" },
	{ "Trails" },
	{ "Inventory" },
	{ "Inventory", "Potions" },
	{ "Gifts" },
	{ "Settings" },
	{ "Admin" },
	{ "Egg", "beach_egg" },
	{ "Egg", "overlord_egg" },
	{ "World", 2 },
}
for _, entry in MENUS do
	local name = entry[1]
	check(UIController.Get(name) ~= nil, "screen registered: " .. name)
	guarded("open " .. name, UIController.Open, name, entry[2])
	STEP(0.4)
	check(UIController.Get(name) ~= nil and UIController.Get(name):IsOpen(), "screen opens: " .. name)
	guarded("close " .. name, UIController.Close, name)
	STEP(0.3)
end
check(#CLIENT_ERRORS == 0, "menus without errors")

-- data changes while menus are open (live refresh paths)
UIController.Open("Pets")
profile.EquippedPets = { "1", "2" }
SERVER_FIRE("PlayerData", view())
STEP(0.3)
UIController.Close("Pets")

-- training: stand on the 1x pad
local root = LOCAL_PLAYER.Character:FindFirstChild("HumanoidRootPart")
local padPos = Map.Origin(1) + Map.PadPosition(1)
root.CFrame = CFrame.new(padPos.X, padPos.Y + 3, padPos.Z)
STEP(0.6)
local Training = MODULE(CLIENT .. "Controllers/TrainingController")
local before = sent("RequestTrain")
guarded("train", Training.Train)
check(sent("RequestTrain") == before + 1, "TRAIN sends one RequestTrain intent")
SERVER_FIRE("TrainResult", { Amount = 3, Pad = "w1_pad1" })
STEP(0.5)
-- at max level the client stops sending reps (the server would refuse them anyway)
local savedSkill = profile.Skill
profile.Skill = Economy.SkillForLevel(Progression.LevelCap(profile)) + 1
Progression.SyncLevel(profile)
SERVER_FIRE("PlayerData", view())
STEP(0.3)
local atCap = sent("RequestTrain")
guarded("train at cap", Training.Train)
check(sent("RequestTrain") == atCap, "no training intents at max level")
profile.Skill = savedSkill
Progression.SyncLevel(profile)
SERVER_FIRE("PlayerData", view())
STEP(0.3)

-- throw: walk into the throw zone, hold and release
local zoneCenter = Map.Origin(1) + Vector3.new(0, 3, (Map.ThrowZone.MinZ + Map.ThrowZone.MaxZ) / 2)
root.CFrame = CFrame.new(zoneCenter.X, zoneCenter.Y, zoneCenter.Z)
STEP(0.6)
local Throw = MODULE(CLIENT .. "Controllers/ThrowController")
check(Throw.InZone(), "client detects the throw zone")
guarded("press", Throw.Press)
check(sent("RequestThrowCharge") == 1, "press sends RequestThrowCharge")
SERVER_FIRE("ChargeState", { Charging = true, StartedAt = CLOCK })
STEP(0.5)
guarded("release", Throw.Release)
check(sent("RequestThrow") == 1, "release sends RequestThrow")
SERVER_FIRE("ChargeState", { Charging = false, StartedAt = 0, Reason = "Launched" })

-- the server's flight plan arrives; tap on every ring
local plan = FlightSim.Build({
	Id = 7,
	UserId = 42,
	World = 1,
	WorldScale = 1,
	Skill = profile.Skill,
	Launch = 0.95,
	Seed = 99,
	Glider = "notebook_glider",
	Trail = "bubble",
	Start = CLOCK,
})
SERVER_FIRE("FlightStarted", FlightSim.Serialize(plan))
local t = 0
local ring = 1
while t < plan.Duration + 0.5 do
	STEP(1 / 30)
	t = CLOCK - plan.Start
	local rt = plan.RingTimes[ring]
	if rt and t >= rt - 0.05 then
		guarded("tap", Throw.Tap)
		SERVER_FIRE("FlightRing", { Id = plan.Id, Index = ring, Perfect = true, Amount = 6 })
		ring += 1
	end
end
check(sent("RequestGust") >= 1 and sent("RequestGust") <= #plan.RingTimes, "gust taps sent at most once per ring (" .. sent("RequestGust") .. ")")
local zone = Zones.At(1, plan.Distance)
SERVER_FIRE("FlightLanded", {
	Id = plan.Id,
	UserId = 42,
	World = 1,
	Distance = plan.Distance,
	Zone = zone.Id,
	Wins = zone.Wins,
	Skill = 36,
	Perfects = #plan.RingTimes,
	Rings = #plan.RingTimes,
	NewBest = true,
	NewZone = true,
	Owner = true,
})
STEP(4)
check(#CLIENT_ERRORS == 0, "flight without errors")

-- a special throw and a cancelled flight
local special = FlightSim.Build({ Id = 8, UserId = 42, World = 1, WorldScale = 1, Skill = 1e6, Launch = 0.5, Seed = 3, Glider = "relic:aurora_relic", Start = CLOCK })
special.Special = "JetStream"
SERVER_FIRE("FlightStarted", FlightSim.Serialize(special))
STEP(1)
SERVER_FIRE("FlightLanded", { Id = 8, UserId = 42, Cancelled = true })
STEP(2)

-- hatch reveal (egg + gift), dismissed with gamepad A
SERVER_FIRE("HatchResult", { Egg = "beach_egg", Pets = { { Uid = "5", Id = "coral_fox" }, { Uid = "6", Id = "sea_pup" }, { Uid = "7", Id = "golden_gull" } } })
SERVER_FIRE("HatchResult", { Egg = "", Pets = { { Uid = "", Id = "gift_bear" } }, Source = "Gift" })
local UIS = FAKE_GAME:GetService("UserInputService")
for _ = 1, 2 do
	STEP(2.5)
	UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.ButtonA, UserInputType = Enum.UserInputType.Gamepad1 }, false)
	STEP(0.5)
end
check(#CLIENT_ERRORS == 0, "hatch reveal without errors")

-- toasts, level/rebirth state, world change, other players' pets
SERVER_FIRE("Notify", { Text = "Hello", Kind = "Success" })
SERVER_FIRE("Notify", { Text = "Oops", Kind = "Error" })
profile.Skill = Economy.SkillForLevel(Progression.LevelCap(profile)) + 10
Progression.SyncLevel(profile)
SERVER_FIRE("PlayerData", view())
STEP(1)
UIController.Open("Rebirth")
STEP(0.5)
UIController.Close("Rebirth")
local other = Instance.new("Player")
other.Name = "Friend"
other.UserId = 77
other.Parent = FAKE_GAME:GetService("Players")
other.Character = Instance.new("Model")
local otherRoot = Instance.new("Part")
otherRoot.Name = "HumanoidRootPart"
otherRoot.CFrame = CFrame.new(5, 3, 150)
otherRoot.AssemblyLinearVelocity = Vector3.new(10, 0, 0)
otherRoot.Parent = other.Character
other:SetAttribute("World", 1)
FAKE_GAME:GetService("Players").PlayerAdded:Fire(other)
other:SetAttribute("Pets", "sun_turtle,golden_gull")
LOCAL_PLAYER:SetAttribute("Pets", "golden_gull")
STEP(1.5)
SERVER_FIRE("WorldChanged", 2)
STEP(1)
check(#CLIENT_ERRORS == 0, "late session without errors")

for _, e in CLIENT_ERRORS do
	print("CLIENT ERROR: " .. e)
end
check(#CLIENT_ERRORS == 0, "no client errors at all")
print(string.format("client.spec: %d intents sent, %d checks, %d failures", #SENT, checks, failures))
