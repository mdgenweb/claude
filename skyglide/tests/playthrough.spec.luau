--!prelude-before _rbxmock.luau
--!prelude-after _clientmock.luau
--!prelude-after _servermock.luau
-- The Studio acceptance checklist (docs/TESTING.md), played end to end with the REAL server
-- (Main.server.luau) and the REAL client (Main.client.luau) talking through loopback remotes
-- with 60 ms of latency each way. Every step goes through the path a player uses: GUI buttons,
-- proximity prompts, keys, touch and gamepad input. The local player never calls server code.
-- Steps 1-15 follow the checklist; 16 adds a second player, 17 an exploiter fuzzing every remote.
local Map = MODULE("ReplicatedStorage/Shared/Config/Map")
local Flight = MODULE("ReplicatedStorage/Shared/Config/Flight")
local Economy = MODULE("ReplicatedStorage/Shared/Config/Economy")
local Monetization = MODULE("ReplicatedStorage/Shared/Config/Monetization")
local Zones = MODULE("ReplicatedStorage/Shared/Definitions/Zones")
local Gliders = MODULE("ReplicatedStorage/Shared/Definitions/Gliders")
local Worlds = MODULE("ReplicatedStorage/Shared/Definitions/Worlds")

local failures, checks = 0, 0
local function check(cond, msg)
	checks += 1
	if not cond then
		failures += 1
		print("FAILED: " .. msg)
	end
end
local function section(name)
	print("-- " .. name)
end

-- Two items get real (test) ids so the Robux flow runs exactly as on a live server: prompt,
-- ProcessReceipt, save, ownership check on rejoin. Everything else keeps id 0 (Studio test grants).
local PASS_ID, PRODUCT_ID = 900001, 900002
Monetization.Pass("DoubleWins").Id = PASS_ID
Monetization.Product("Skill100K").Id = PRODUCT_ID

-- Boot like Roblox: the server starts, then the client's scripts run ---------------------------------
BOOT_SERVER()
STEP(0.2)
BOOT_CLIENT()
STEP(2)

local CLIENT = "StarterPlayer/StarterPlayerScripts/Client/"
local SERVER = "ServerScriptService/Server/"
local State = MODULE(CLIENT .. "Controllers/StateController")
local UI = MODULE(CLIENT .. "Controllers/UIController")
local DataService = MODULE(SERVER .. "Services/DataService")
local playerGui = LOCAL_PLAYER:FindFirstChild("PlayerGui")
local Format = MODULE("ReplicatedStorage/Shared/Util/Format")
local Theme = MODULE(CLIENT .. "UI/Theme")

local function profile()
	return DataService.Get(LOCAL_PLAYER)
end

-- 1. Join -------------------------------------------------------------------------------------------------
section("1. join")
check(profile() ~= nil, "server loaded the profile from the DataStore")
check(State.Data ~= nil, "client received PlayerData")
check(State.Data and State.Data.Skill == 0 and State.Data.Wins == profile().Wins, "client mirror matches the server")
check(profile().World == 1 and LOCAL_PLAYER:GetAttribute("World") == 1, "spawned in world 1")
for _, name in { "Shop", "Rebirth", "Pets", "Trails", "Inventory", "Gifts" } do
	check(BUTTON(name) ~= nil, "left menu button visible: " .. name)
end

local shopTile = BUTTON("Shop")
check(shopTile ~= nil and shopTile:FindFirstChild("Base") ~= nil and shopTile:FindFirstChild("Face") ~= nil, "menu tiles are raised 3D keys (a face on a darker base)")

check(HAS_TEXT(playerGui, "1x SKILL pad"), "tutorial points at the 1x pad")
STEP(3.5)
check(UI.Get("Gifts"):IsOpen(), "the Gifts menu opens by itself when the daily reward is ready")
CLICK(BUTTON("Close"))
STEP(0.5)
check(not UI.AnyMenuOpen(), "the X button closes it")
do
	local giftsIcon = BUTTON("Gifts"):FindFirstChild("Icon", true)
	local swing = 0
	for _ = 1, 60 do
		STEP(0.05)
		swing = math.max(swing, math.abs(giftsIcon.Rotation or 0))
	end
	check(swing > 3, "the Gifts tile wiggles while a reward is waiting")
end

local UIS = FAKE_GAME:GetService("UserInputService")
local function input(kind, key)
	return { UserInputType = kind, KeyCode = key or Enum.KeyCode.Unknown, Position = Vector3.zero, UserInputState = Enum.UserInputState.Begin }
end
local function stand(position)
	MOVE_TO(position + Vector3.new(0, 3, 0))
	STEP(0.5)
end
local function settle(seconds)
	STEP(seconds or 0.5) -- latency both ways + the batched PlayerData sync
end
local function mapPart(...)
	local node = FAKE_GAME:GetService("Workspace"):FindFirstChild("Worlds")
	for _, name in { ... } do
		node = node and node:FindFirstChild(name)
	end
	return node
end
local function mapLabel(holder, name)
	local gui = holder and holder:FindFirstChild("Label")
	local label = gui and gui:FindFirstChild(name, true)
	return if label then label.Text else nil
end

local Throw = MODULE(CLIENT .. "Controllers/ThrowController")
local methods = { "space", "mouse", "touch", "gamepad" }
local function tap(method)
	if method == "space" then
		CAS_BINDINGS.SkyGlideGust("SkyGlideGust", Enum.UserInputState.Begin, input(Enum.UserInputType.Keyboard, Enum.KeyCode.Space))
	elseif method == "gamepad" then
		CAS_BINDINGS.SkyGlideGust("SkyGlideGust", Enum.UserInputState.Begin, input(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA))
	elseif method == "mouse" then
		UIS.InputBegan:Fire(input(Enum.UserInputType.MouseButton1), false)
	else
		UIS.InputBegan:Fire(input(Enum.UserInputType.Touch), false)
	end
end
local throws = 0
local camera = FAKE_GAME:GetService("Workspace").CurrentCamera
local Progression = MODULE("ReplicatedStorage/Shared/Sim/Progression")
local function admin(label)
	if not UI.Get("Admin"):IsOpen() then
		CLICK(BUTTON("Admin"))
		STEP(0.5)
	end
	local b = BUTTON(label, playerGui:FindFirstChild("SkyGlide_Menus"))
	CLICK(b)
	settle(1)
	return b
end

-- 2. Train --------------------------------------------------------------------------------------------------
section("2. train")
do
	stand(Map.Origin(1) + Map.PadPosition(1))
	local train = BUTTON("Train")
	check(train ~= nil and SHOWN(train), "TRAIN button appears on the 1x pad")
	local skill0 = profile().Skill
	for _ = 1, 15 do
		CLICK(train)
		STEP(0.25) -- a fast human: 4 taps per second
	end
	settle()
	check(profile().Skill > skill0, "training pays Skill on the server")
	check(State.Data.Skill == profile().Skill, "client shows the server's Skill")
	check(profile().Tutorial.Step == 2, "15 reps finish tutorial step 1")
	check(HAS_TEXT(playerGui, "THROW ZONE"), "tutorial now points at the throw zone")
	-- spam beyond the rate limit is refused, not counted
	local skillBeforeSpam = profile().Skill
	for _ = 1, 40 do
		CLICK(train)
	end
	settle()
	local spamGain = profile().Skill - skillBeforeSpam
	check(spamGain > 0 and spamGain <= (Economy.TrainManualRate + 2) * profile().Skill, "spam clicks are rate limited")
	-- AUTO train
	CLICK(BUTTON("Auto"))
	settle()
	check(profile().Settings.AutoTrain == true, "AUTO toggled on the server")
	local skillAuto = profile().Skill
	STEP(3)
	check(profile().Skill > skillAuto, "AUTO keeps training while standing on the pad")
	CLICK(BUTTON("Auto"))
	settle()
	check(profile().Settings.AutoTrain == false, "AUTO toggled off")
	check(mapLabel(mapPart("World_1", "Pads", "Pad_w1_pad2"), "Status") == "LOCKED", "the 4x pad shows LOCKED")
end

-- 3-5. Throw, rings, landing -------------------------------------------------------------------------------
section("3. throw")
do
	stand(Map.Origin(1) + Vector3.new(0, 0, (Map.ThrowZone.MinZ + Map.ThrowZone.MaxZ) / 2))
	check(Throw.InZone(), "client knows it is in the throw zone")
	local throwButton = BUTTON("Throw")
	check(throwButton ~= nil, "THROW button shows in the zone")
	local winsBefore, skillBefore = profile().Wins, profile().Skill
	local press = input(Enum.UserInputType.MouseButton1)
	throwButton.InputBegan:Fire(press)
	STEP(0.65) -- release near the top of the meter
	UIS.InputEnded:Fire(press, false)
	local plan = nil
	for _ = 1, 60 do
		STEP(1 / 30)
		plan = Throw.ActivePlan()
		if plan then
			break
		end
	end
	check(plan ~= nil, "the server's flight plan reached the client")
	check(plan and plan.PerfectLaunch == true, "a 0.65 s hold is a PERFECT LAUNCH on the server")
	check(FAKE_GAME:GetService("Workspace").CurrentCamera.CameraType == Enum.CameraType.Scriptable, "camera follows the glider")

	section("4. rings")
	local ring = 1
	local counterSeen = {}
	if plan then
		while Throw.ActivePlan() ~= nil and CLOCK < plan.Start + plan.Duration + 6 do
			STEP(1 / 30)
			local rt = plan.RingTimes[ring]
			if rt and CLOCK - plan.Start >= rt - 0.03 then
				tap(methods[(ring - 1) % #methods + 1])
				ring += 1
			end
			local counter = playerGui:FindFirstChild("FlightDistance", true)
			if counter and SHOWN(counter) then
				counterSeen[counter.Text] = true
			end
		end
	end
	local perfects, paid = 0, 0
	for _, sent in SERVER_SENT do
		if sent[1] == "FlightRing" and sent[2] == LOCAL_PLAYER then
			paid += 1
			if sent[3].Perfect then
				perfects += 1
			end
		end
	end
	check(plan ~= nil and paid == #plan.RingTimes, "every ring paid (" .. paid .. ")")
	check(plan ~= nil and perfects == #plan.RingTimes, "on-time taps with 60 ms latency are all PERFECT (" .. perfects .. "/" .. (plan and #plan.RingTimes or 0) .. ")")
	local distinctCounters = 0
	for _ in counterSeen do
		distinctCounters += 1
	end
	check(distinctCounters > 3, "the distance counter climbs during the flight")

	section("5. landing")
	settle(1)
	local landed = LAST_SENT("FlightLanded", LOCAL_PLAYER)
	check(landed ~= nil and landed.Owner == true, "landing reported to the owner")
	check(profile().Wins > winsBefore, "landing paid Wins")
	check(profile().Skill > skillBefore, "rings paid Skill")
	check(State.Data.Wins == profile().Wins, "client shows the new Wins")
	local card = playerGui:FindFirstChild("LandingCard", true)
	check(card ~= nil and SHOWN(card), "result card shows")
	check(card ~= nil and string.sub(card:FindFirstChild("Wins", true).Text, 1, 1) == "+", "result card lists the Wins earned")
	local rays = playerGui:FindFirstChild("LandingCardRays", true)
	check(landed ~= nil and landed.NewBest == true and rays ~= nil and SHOWN(rays), "a new best lights the sunburst behind the card")
	local fx = playerGui:FindFirstChild("FxRewards", true)
	check(fx ~= nil and #fx:GetChildren() > 0, "the Wins earned fly into the Wins counter")
	STEP(5)
	local winsValue = playerGui:FindFirstChild("Counters", true):FindFirstChild("Wins"):FindFirstChild("Value")
	check(winsValue.Text == Format.Short(profile().Wins), "the Wins counter rolls up to the new total (" .. winsValue.Text .. ")")
	check(rays ~= nil and not SHOWN(rays), "the sunburst goes with the card")
	check(FAKE_GAME:GetService("Workspace").CurrentCamera.CameraType == Enum.CameraType.Custom, "camera returns to the player")
end

-- a complete throw (hold for PERFECT, tap every ring with Space), used by later steps
local function throwOnce(hold)
	stand(Map.Origin(profile().World) + Vector3.new(0, 0, (Map.ThrowZone.MinZ + Map.ThrowZone.MaxZ) / 2))
	STEP(Flight.LandCooldown + 0.2)
	local button = BUTTON("Throw")
	if button == nil then
		return nil
	end
	local p = input(Enum.UserInputType.MouseButton1)
	button.InputBegan:Fire(p)
	STEP(hold or 0.65)
	UIS.InputEnded:Fire(p, false)
	local active = nil
	for _ = 1, 60 do
		STEP(1 / 30)
		active = Throw.ActivePlan()
		if active then
			break
		end
	end
	if not active then
		return nil
	end
	local index = 1
	while Throw.ActivePlan() ~= nil and CLOCK < active.Start + active.Duration + 6 do
		STEP(1 / 30)
		local rt = active.RingTimes[index]
		if rt and CLOCK - active.Start >= rt - 0.03 then
			tap("space")
			index += 1
		end
	end
	settle(1)
	return active
end
local function menu(name)
	CLICK(BUTTON(name))
	STEP(0.5)
	return UI.Get(name)
end
local function closeMenus()
	UI.CloseMenus()
	STEP(0.4)
end

-- 6. Shop: buy the Notebook Glider at its pedestal -----------------------------------------------------------
section("6. shop")
do
	local notebook = Gliders.Get("notebook_glider")
	while profile().Wins < notebook.Price and throws < 8 do
		throwOnce()
		throws += 1
	end
	check(profile().Wins >= notebook.Price, "earned enough Wins for the Notebook Glider (" .. throws .. " more throws)")
	local pedestal = mapPart("World_1", "Pedestals", "Pedestal_notebook_glider", "Base")
	check(pedestal ~= nil, "the Notebook Glider pedestal exists")
	stand(pedestal.Position + Vector3.new(0, 0, 4))
	local winsBeforeBuy = profile().Wins
	TRIGGER_PROMPT(pedestal:FindFirstChild("BuyPrompt"))
	settle(1)
	check(profile().Gliders.notebook_glider == true, "bought through the pedestal prompt")
	check(profile().Wins == winsBeforeBuy - notebook.Price, "the price was charged once")
	check(profile().Glider == "notebook_glider", "the new glider is equipped")
	check(mapLabel(pedestal, "Status") == "EQUIPPED", "the pedestal shows EQUIPPED")
	check(LOCAL_PLAYER:GetAttribute("Glider") == "notebook_glider", "the character holds the new glider")
	local held = LOCAL_PLAYER.Character:FindFirstChild("HeldGlider")
	check(held ~= nil, "a HeldGlider model is welded to the hand")
	TRIGGER_PROMPT(pedestal:FindFirstChild("BuyPrompt"))
	settle(1)
	check(profile().Wins == winsBeforeBuy - notebook.Price, "triggering it again does not charge twice")
	-- the Inventory lists owned gliders as soon as it opens (regression: it used to open on no tab)
	menu("Inventory")
	local inventoryRoot = playerGui:FindFirstChild("SkyGlide_Menus"):FindFirstChild("Root"):FindFirstChild("Inventory")
	local slot = inventoryRoot:FindFirstChild("notebook_glider", true)
	check(slot ~= nil and SHOWN(slot), "Inventory opens on the Gliders tab and lists the new glider")
	closeMenus()
	-- the prompt from far away is refused by the server
	stand(Map.Origin(1) + Map.Spawn)
	local farPedestal = mapPart("World_1", "Pedestals", "Pedestal_palm_leaf", "Base")
	local winsFar = profile().Wins
	TRIGGER_PROMPT(farPedestal:FindFirstChild("BuyPrompt"))
	settle(1)
	check(profile().Gliders.palm_leaf == nil and profile().Wins == winsFar, "buying from across the map is refused")
end

-- 8. Gifts and the daily reward ------------------------------------------------------------------------------
section("8. gifts")
do
	local Rewards = MODULE("ReplicatedStorage/Shared/Definitions/Rewards")
	local firstGift = Rewards.Gifts[1]
	STEP(firstGift.Minutes * 60 + 1, 10)
	local gifts = menu("Gifts")
	check(gifts ~= nil and gifts:IsOpen(), "Gifts menu opens from the left menu")
	local giftCard = playerGui:FindFirstChild("Gift1", true)
	local claim = giftCard and BUTTON("Action", giftCard)
	check(claim ~= nil and BUTTON_TEXT(claim) == "CLAIM", "gift 1 is claimable after " .. firstGift.Minutes .. " min")
	local potionsBefore = table.clone(profile().Potions)
	local winsBeforeGift = profile().Wins
	CLICK(claim)
	settle(1)
	check(BUTTON_TEXT(BUTTON("Action", giftCard)) == "CLAIMED", "gift 1 shows CLAIMED")
	local gotSomething = profile().Wins > winsBeforeGift
	for id, n in profile().Potions do
		if n > (potionsBefore[id] or 0) then
			gotSomething = true
		end
	end
	check(gotSomething, "gift 1 paid its reward")
	CLICK(claim)
	settle(1)
	check(BUTTON_TEXT(BUTTON("Action", giftCard)) == "CLAIMED", "a claimed gift can't be claimed again")
	CLICK(BUTTON("ClaimDaily"))
	settle(1)
	check(profile().Daily.Streak == 1, "daily reward claimed (streak 1)")
	check(BUTTON_TEXT(playerGui:FindFirstChild("ClaimDaily", true)) == "COME BACK TOMORROW", "daily button says come back tomorrow")
	closeMenus()
	-- the next day the streak continues
	TIME_OFFSET += 86400
	STEP(16, 10) -- the server refreshes every player's view at least every 15 s
	SERVER_SENT = {}
	local gifts2 = menu("Gifts")
	check(BUTTON_TEXT(playerGui:FindFirstChild("ClaimDaily", true)) == "CLAIM", "a new day makes the daily reward claimable")
	CLICK(BUTTON("ClaimDaily"))
	settle(1)
	check(profile().Daily.Streak == 2, "streak 2 the next day")
	local _ = gifts2
	closeMenus()
end

-- 9. Codes and potions ---------------------------------------------------------------------------------------
section("9. codes")
do
	menu("Shop")
	local codeBox = playerGui:FindFirstChild("CodeInput", true)
	check(codeBox ~= nil and SHOWN(codeBox), "code box is visible in the Shop")
	local winsBeforeCode = profile().Wins
	local skillPotions = profile().Potions.skill_potion or 0
	codeBox.Text = " launch "
	CLICK(BUTTON("Redeem"))
	settle(1)
	check(profile().Codes.LAUNCH == true, "LAUNCH redeemed (case and spaces ignored)")
	check(profile().Wins > winsBeforeCode, "LAUNCH gives Wins")
	check((profile().Potions.skill_potion or 0) == skillPotions + 1, "LAUNCH gives a Skill potion")
	codeBox.Text = "LAUNCH"
	local winsAfterCode = profile().Wins
	CLICK(BUTTON("Redeem"))
	settle(1)
	check(profile().Wins == winsAfterCode, "a code works only once")
	local errorToast = false
	for _, toast in playerGui:FindFirstChild("SkyGlide_Toasts"):FindFirstChild("Root"):FindFirstChild("Toasts"):GetChildren() do
		local icon = toast:FindFirstChild("Icon", true)
		if icon and icon.Text == Theme.Toasts.Error.Icon then
			errorToast = true
		end
	end
	check(errorToast, "the refused code shows a red error toast")
	closeMenus()
	local multBefore = State.Data.Derived.SkillMultiplier
	menu("Inventory")
	CLICK(BUTTON("Potions"))
	STEP(0.5)
	local inventoryRoot = playerGui:FindFirstChild("SkyGlide_Menus"):FindFirstChild("Root"):FindFirstChild("Inventory")
	local potionCard = inventoryRoot:FindFirstChild("skill_potion", true)
	check(potionCard ~= nil and SHOWN(potionCard), "the Skill potion is listed in Inventory")
	CLICK(BUTTON("Action", potionCard))
	settle(1)
	check((profile().Boosts.skill_potion or 0) > os.time(), "the potion is active on the server")
	check(math.abs(State.Data.Derived.SkillMultiplier - multBefore * 2) < 1e-6, "the Skill multiplier doubles (" .. tostring(multBefore) .. " -> " .. tostring(State.Data.Derived.SkillMultiplier) .. ")")
	closeMenus()
end

-- 7. Eggs and pets -----------------------------------------------------------------------------------------------
section("7. eggs")
do
	local Eggs = MODULE("ReplicatedStorage/Shared/Definitions/Eggs")
	local egg = Eggs.ForWorld(1)[1]
	while profile().Wins < egg.Price and throws < 30 do
		throwOnce()
		throws += 1
	end
	check(profile().Wins >= egg.Price, "enough Wins for the " .. egg.Name)
	local eggBase = mapPart("World_1", "Eggs", "Egg_" .. egg.Id, "Base")
	check(eggBase ~= nil, "the egg is on the egg row")
	stand(eggBase.Position + Vector3.new(0, 0, 5))
	TRIGGER_PROMPT(eggBase:FindFirstChild("HatchPrompt"))
	STEP(0.5)
	check(UI.Get("Egg"):IsOpen(), "the egg prompt opens the Egg screen")
	local petsBefore = 0
	for _ in profile().Pets do
		petsBefore += 1
	end
	local winsBeforeHatch = profile().Wins
	CLICK(BUTTON("HatchOne"))
	STEP(1)
	local reveal = playerGui:FindFirstChild("HatchReveal", true)
	check(reveal ~= nil and SHOWN(reveal), "the hatch reveal plays")
	STEP(3)
	local newBadge = reveal and reveal:FindFirstChild("NewBadge", true)
	check(newBadge ~= nil and SHOWN(newBadge), "a pet hatched for the first time shows NEW!")
	CLICK(reveal)
	STEP(1)
	local petsAfter, newUid = 0, nil
	for uid in profile().Pets do
		petsAfter += 1
		newUid = uid
	end
	check(petsAfter == petsBefore + 1, "one pet hatched")
	local hatchedId = if newUid then profile().Pets[newUid].Id else nil
	check(hatchedId ~= nil and profile().Index[hatchedId] == true and State.Data.Index[hatchedId] == true, "the pet is recorded in the Index (server and client)")
	check(profile().Wins == winsBeforeHatch - egg.Price, "the egg price was charged")
	check(#profile().EquippedPets >= 1, "the new pet is equipped automatically")
	STEP(1)
	local followers = FAKE_GAME:GetService("Workspace"):FindFirstChild("PetFollowers")
	check(followers ~= nil and #followers:GetChildren() >= 1, "the pet follows the player")
	closeMenus()
	menu("Pets")
	local slot = newUid and playerGui:FindFirstChild("Pet_" .. newUid, true)
	check(slot ~= nil and SHOWN(slot), "the pet is in the Pets menu")
	CLICK(slot)
	STEP(0.3)
	CLICK(BUTTON("Lock"))
	settle()
	check(newUid ~= nil and profile().Pets[newUid].Locked == true, "LOCK locks the pet on the server")
	CLICK(BUTTON("Equip"))
	settle()
	check(newUid ~= nil and table.find(profile().EquippedPets, newUid) == nil, "the EQUIP button toggles it off")
	CLICK(BUTTON("EquipBest"))
	settle()
	check(#profile().EquippedPets >= 1, "EQUIP BEST equips it again")
	CLICK(BUTTON("OpenIndex"))
	STEP(0.5)
	check(UI.Get("Index"):IsOpen(), "INDEX in the Pets menu opens the Index")
	local indexRoot = playerGui:FindFirstChild("SkyGlide_Menus"):FindFirstChild("Root"):FindFirstChild("Index")
	local PetDefs = MODULE("ReplicatedStorage/Shared/Definitions/Pets")
	local found = hatchedId and indexRoot:FindFirstChild(hatchedId, true)
	check(found ~= nil and SHOWN(found) and HAS_TEXT(found, PetDefs.Get(hatchedId).Name), "the Index card shows the hatched pet")
	local unknownCard = nil
	for _, entry in egg.Pets do
		if not profile().Index[entry.Pet] then
			unknownCard = indexRoot:FindFirstChild(entry.Pet, true)
			break
		end
	end
	check(unknownCard ~= nil and HAS_TEXT(unknownCard, "???"), "pets not found yet show ??? in the Index")
	check(HAS_TEXT(indexRoot, "Discovered "), "the Index counts the pets discovered")
	closeMenus()
end

-- 10. Rebirth (Admin -> Max Level, then the Rebirth menu) ------------------------------------------------------
section("10. rebirth")
do
	check(State.Data.IsAdmin == true, "Studio sessions get the admin panel")
	admin("Max Level")
	check(profile().Level == Progression.LevelCap(profile()), "Max Level reaches the level cap")
	closeMenus()
	local petsKept, glidersKept, winsKept = #profile().EquippedPets, profile().Gliders.notebook_glider, profile().Wins
	check(State.Data.Derived.CanRebirth == true, "the client sees that rebirth is ready")
	menu("Rebirth")
	CLICK(BUTTON("RebirthButton"))
	settle(1)
	check(profile().Rebirths == 1, "rebirth done on the server")
	check(profile().Skill == 0 and profile().Level == 1, "Skill and Level reset")
	check(Progression.LevelCap(profile()) == 40, "the level cap rises to 40")
	check(State.Data.Derived.Breakdown.Rebirth == 3, "the rebirth multiplier goes x1 -> x3")
	check(#profile().EquippedPets == petsKept and profile().Gliders.notebook_glider == glidersKept and profile().Wins == winsKept, "pets, gliders and Wins are kept")
	CLICK(BUTTON("RebirthButton"))
	settle(1)
	check(profile().Rebirths == 1, "a second click without max level does nothing")
	closeMenus()
end

-- 16. A second player (Test -> Clients and Servers with 2 players) ---------------------------------------------
section("16. second player")
do
	FRIENDS["42:77"] = true
	local friend = JOIN(77, "Friend")
	STEP(2)
	check(DataService.Get(friend) ~= nil, "the second player's profile loads")
	check(math.abs(State.Data.Derived.FriendBoost - 0.1) < 1e-9, "a friend in the server gives +10% (" .. tostring(State.Data.Derived.FriendBoost) .. ")")
	check(HAS_TEXT(playerGui, "Friends +10%"), "the HUD shows the +10% friend boost")
	-- the friend hatches a pet next to us; we see it follow them
	local friendRoot = friend.Character:FindFirstChild("HumanoidRootPart")
	local Eggs = MODULE("ReplicatedStorage/Shared/Definitions/Eggs")
	local egg = Eggs.ForWorld(1)[1]
	local eggBase = mapPart("World_1", "Eggs", "Egg_" .. egg.Id, "Base")
	friendRoot.CFrame = CFrame.new(eggBase.Position + Vector3.new(0, 3, 5))
	stand(eggBase.Position + Vector3.new(4, 0, 5))
	AS(friend, "AdminRequest", "GrantWins", 1e6)
	local hatch = AS(friend, "RequestHatchEgg", egg.Id, 1)
	STEP(1)
	check(hatch and hatch.ok, "the friend hatches through the same intent")
	check(type(friend:GetAttribute("Pets")) == "string" and friend:GetAttribute("Pets") ~= "", "the friend's pets replicate as an attribute")
	local followers = FAKE_GAME:GetService("Workspace"):FindFirstChild("PetFollowers")
	local mine = #string.split(LOCAL_PLAYER:GetAttribute("Pets") or "", ",")
	check(followers ~= nil and #followers:GetChildren() > mine, "we see the friend's pet following them")
	-- the friend throws; we see their glider fly
	friendRoot.CFrame = CFrame.new(Map.Origin(1) + Vector3.new(4, 3, (Map.ThrowZone.MinZ + Map.ThrowZone.MaxZ) / 2))
	stand(Map.Origin(1) + Vector3.new(-6, 0, (Map.ThrowZone.MinZ + Map.ThrowZone.MaxZ) / 2))
	AS(friend, "RequestThrowCharge")
	STEP(0.5)
	AS(friend, "RequestThrow")
	STEP(1)
	local started = LAST_SENT("FlightStarted")
	check(started ~= nil and started.UserId == 77, "the friend's flight is broadcast")
	local flights = FAKE_GAME:GetService("Workspace"):FindFirstChild("Flights", true)
	check(flights ~= nil and #flights:GetChildren() >= 1, "their glider is rendered on our screen")
	STEP(started and started.Duration + 4 or 4)
	check(not MODULE(SERVER .. "Services/FlightService").IsFlying(friend), "their flight lands")
	-- global leaderboards (OrderedDataStores) list both players after the next 2-minute refresh
	STEP(121, 5)
	local ordered = ORDERED["SkyGlide_LB_Wins_v1"]
	check(ordered ~= nil and ordered["42"] ~= nil and ordered["77"] ~= nil, "both players are written to the global Wins board")
	local board = mapPart("World_1", "Boards", "Board_Wins")
	local list = board and board:FindFirstChild("List", true)
	check(list ~= nil and list:FindFirstChild("Row1") ~= nil and list:FindFirstChild("Row2") ~= nil, "the hub board shows the top players")
	LEAVE(friend)
	STEP(1)
	check(State.Data.Derived.FriendBoost == 0, "the boost goes away when the friend leaves")
	local saved = DATASTORES["SkyGlide_PlayerData_v1"]["player_77"]
	check(saved ~= nil and saved.Lock == nil and saved.Data.Wins > 0, "the friend's progress was saved on leave")
	check(followers ~= nil and #followers:GetChildren() <= mine, "their pets leave with them")
end

-- 11. Worlds: reach the river end with 5 rebirths, then take the portal --------------------------------------------
section("11. worlds")
do
	local world2 = Worlds.Get(2)
	while profile().Rebirths < world2.UnlockRebirths do
		admin("Max Level")
		closeMenus()
		menu("Rebirth")
		CLICK(BUTTON("RebirthButton"))
		settle(1.2)
		closeMenus()
	end
	check(profile().Rebirths == world2.UnlockRebirths, "rebirthed " .. world2.UnlockRebirths .. " times")
	admin("Max Level")
	closeMenus()
	local portal = mapPart("World_1", "Portals", "Portal_2", "Frame")
	check(portal ~= nil, "the world 2 portal exists")
	check(string.find(mapLabel(portal, "Requirement") or "", "Reach", 1, true) ~= nil, "the portal says which zone to reach")
	stand(portal.Position + Vector3.new(0, 0, 6))
	TRIGGER_PROMPT(portal:FindFirstChild("PortalPrompt"))
	STEP(0.5)
	check(UI.Get("World"):IsOpen(), "the portal prompt opens the World screen")
	CLICK(BUTTON("Travel"))
	settle(1)
	check(profile().World == 1, "travel is refused before the river end is reached")
	closeMenus()
	local farPlan = throwOnce()
	local lastZone = Zones.Last(1)
	check(farPlan ~= nil and profile().Zones[lastZone.Id] == true, "a max-level throw reaches the river end (" .. lastZone.Name .. ")")
	check(profile().Worlds["2"] == true, "reaching it unlocks world 2")
	local unlockedBanner = playerGui:FindFirstChild("WorldUnlocked", true)
	check(unlockedBanner ~= nil and SHOWN(unlockedBanner), "the result card announces the new world")
	STEP(5)
	local lighting = FAKE_GAME:GetService("Lighting")
	local clockBefore = lighting.ClockTime
	stand(portal.Position + Vector3.new(0, 0, 6))
	TRIGGER_PROMPT(portal:FindFirstChild("PortalPrompt"))
	STEP(0.5)
	CLICK(BUTTON("Travel"))
	settle(1.5)
	check(profile().World == 2 and LOCAL_PLAYER:GetAttribute("World") == 2, "travelled to " .. world2.Name)
	local here = LOCAL_PLAYER.Character:FindFirstChild("HumanoidRootPart").Position
	check((here - (Map.Origin(2) + Map.Spawn)).Magnitude < 20, "the character stands at the world 2 spawn")
	check(lighting.ClockTime ~= clockBefore, "the lighting changes with the world")
	check(mapLabel(mapPart("World_2", "Pads", "Pad_w2_pad1"), "Status") == "UNLOCKED", "world 2 pads show their state")
	closeMenus()
end

-- 12. Purchases ---------------------------------------------------------------------------------------------------
section("12. purchases")
do
	-- Studio test grant (id 0): Auto Throw
	local autoButton = BUTTON("AutoThrow")
	check(autoButton ~= nil, "AUTO THROW offer at the top of the HUD")
	CLICK(autoButton)
	settle(1)
	check(profile().TestPasses.AutoThrow == true, "Studio grants the Auto Throw pass for testing")
	CLICK(BUTTON("AutoThrow"))
	settle(1)
	check(profile().Settings.AutoThrow == true, "AUTO THROW switched on")
	local flightsBefore = COUNT_SENT("FlightStarted", LOCAL_PLAYER)
	stand(Map.Origin(2) + Vector3.new(0, 0, (Map.ThrowZone.MinZ + Map.ThrowZone.MaxZ) / 2))
	STEP(Flight.AutoThrowDelay + 2)
	check(COUNT_SENT("FlightStarted", LOCAL_PLAYER) > flightsBefore, "it throws by itself in the zone")
	CLICK(BUTTON("AutoThrow"))
	settle(1)
	check(profile().Settings.AutoThrow == false, "AUTO THROW switched off")
	for _ = 1, 600 do
		if Throw.ActivePlan() == nil then
			break
		end
		STEP(0.1)
	end
	STEP(2)
	-- Studio test grant: a Skill pack
	local packs = playerGui:FindFirstChild("Packs", true)
	local skillBeforePack = profile().Skill
	CLICK(BUTTON("Skill10K", packs))
	settle(1)
	check(profile().Skill > skillBeforePack, "the +10K Skill pack adds Skill")
	-- Real product (non-zero id): prompt -> receipt -> grant once -> saved
	PROMPTS = {}
	local skillBeforeRobux = profile().Skill
	CLICK(BUTTON("Skill100K", packs))
	settle(1)
	check(#PROMPTS == 1 and PROMPTS[1].Kind == "Product" and PROMPTS[1].Id == PRODUCT_ID, "a configured product opens the Roblox purchase prompt")
	check(profile().Skill == skillBeforeRobux, "nothing is granted before the receipt")
	DATASTORE_FAIL = 2 -- the save after the grant hits two DataStore errors
	local decision, purchaseId = COMPLETE_PURCHASE(PROMPTS[1])
	check(decision == Enum.ProductPurchaseDecision.PurchaseGranted, "receipt granted after the save retried through DataStore errors")
	local skillAfterRobux = profile().Skill
	check(skillAfterRobux > skillBeforeRobux, "the Robux Skill pack paid")
	local again = COMPLETE_PURCHASE(PROMPTS[1], purchaseId)
	check(again == Enum.ProductPurchaseDecision.PurchaseGranted and profile().Skill == skillAfterRobux, "a repeated receipt is not granted twice")
	DATASTORE_FAIL = 99 -- DataStores down: the purchase must not be confirmed
	local failed = COMPLETE_PURCHASE(PROMPTS[1])
	DATASTORE_FAIL = 0
	check(failed == Enum.ProductPurchaseDecision.NotProcessedYet, "with DataStores down the receipt is left for Roblox to retry")
	-- that failure is expected to be logged; take it out of the "no warnings" check
	local logged = false
	for i = #SERVER_WARNINGS, 1, -1 do
		if string.find(SERVER_WARNINGS[i], "save player_42 failed", 1, true) then
			logged = true
			table.remove(SERVER_WARNINGS, i)
		end
	end
	check(logged, "the failed save is logged")
	-- Real game pass
	PROMPTS = {}
	local winsMultBefore = State.Data.Derived.WinsMultiplier
	menu("Shop")
	local passCard = playerGui:FindFirstChild("SkyGlide_Menus"):FindFirstChild("DoubleWins", true)
	CLICK(BUTTON("Action", passCard))
	settle(1)
	check(#PROMPTS == 1 and PROMPTS[1].Kind == "Pass" and PROMPTS[1].Id == PASS_ID, "a configured pass opens the Roblox pass prompt")
	COMPLETE_PURCHASE(PROMPTS[1])
	settle(1)
	check(math.abs(State.Data.Derived.WinsMultiplier - winsMultBefore * 2) < 1e-6, "buying 2x Wins doubles the Wins multiplier")
	closeMenus()
	-- the limited relic (Studio grant) counts down the global stock
	local relicBase = mapPart("World_" .. profile().World, "Pedestals", "Relic_aurora_relic", "Base")
	local stockBefore = mapLabel(relicBase, "Stock")
	stand(relicBase.Position + Vector3.new(0, 0, 5))
	TRIGGER_PROMPT(relicBase:FindFirstChild("BuyPrompt"))
	settle(2)
	check(profile().Relics.aurora_relic == true and profile().Relic == "aurora_relic", "the Aurora Relic is granted and equipped")
	check(DATASTORES["SkyGlide_Global_v1"]["RelicSold_aurora_relic"] == 1, "the global relic counter went up")
	check(mapLabel(relicBase, "Stock") ~= stockBefore, "the relic stock label counts down (" .. tostring(stockBefore) .. " -> " .. tostring(mapLabel(relicBase, "Stock")) .. ")")
	closeMenus()
end

-- 13. Rejoin: everything persists; session locks hold -------------------------------------------------------------
section("13. rejoin")
do
	local before = {
		Skill = profile().Skill,
		Wins = profile().Wins,
		Rebirths = profile().Rebirths,
		World = profile().World,
		Glider = profile().Glider,
		Relic = profile().Relic,
		Pets = 0,
		Codes = profile().Codes.LAUNCH,
		Streak = profile().Daily.Streak,
		AutoThrow = profile().TestPasses.AutoThrow,
	}
	for _ in profile().Pets do
		before.Pets += 1
	end
	LEAVE(LOCAL_PLAYER)
	STEP(1)
	local record = DATASTORES["SkyGlide_PlayerData_v1"]["player_42"]
	check(record ~= nil and record.Lock == nil, "leaving saves and releases the session lock")
	check(record and record.Data.Wins == before.Wins and record.Data.Skill == before.Skill, "the saved record has the latest Skill and Wins")
	-- another server can't take the profile while this one holds it
	local ProfileStore = MODULE(SERVER .. "Data/ProfileStore")
	local otherServer = ProfileStore.new("SkyGlide_PlayerData_v1")
	REJOIN(LOCAL_PLAYER)
	STEP(2)
	check(profile() ~= nil, "rejoined and loaded")
	local otherSession, otherDone = nil, false
	task.spawn(function()
		otherSession = otherServer:Load("player_42", function()
			return true
		end)
		otherDone = true
	end)
	for _ = 1, 400 do
		if otherDone then
			break
		end
		STEP(0.25, 4)
	end
	check(otherDone and otherSession == nil, "a second server can't load a profile that is in use")
	local same = profile().Skill == before.Skill and profile().Wins == before.Wins and profile().Rebirths == before.Rebirths and profile().World == before.World and profile().Glider == before.Glider and profile().Relic == before.Relic and profile().Codes.LAUNCH == before.Codes and profile().Daily.Streak == before.Streak and profile().TestPasses.AutoThrow == before.AutoThrow
	local petsNow = 0
	for _ in profile().Pets do
		petsNow += 1
	end
	check(same and petsNow == before.Pets, "Skill, Wins, rebirths, world, glider, relic, pets, codes, streak and passes all persist")
	check(State.Data.Wins == before.Wins and State.Data.World == before.World, "the client shows the restored data")
	check(State.Data.Derived.Passes.DoubleWins == true, "the bought pass is still owned after rejoining")
	check(LOCAL_PLAYER:GetAttribute("World") == before.World, "rejoining puts you back in your world")
	-- a server that lost its lock (another server stole a stale lock) stops saving and kicks
	DATASTORES["SkyGlide_PlayerData_v1"]["player_42"].Lock = { JobId = "someone-else", Time = os.time() }
	KICKED = {}
	DataService.SaveNow(LOCAL_PLAYER)
	check(#KICKED == 1 and KICKED[1].Player == LOCAL_PLAYER, "losing the session lock kicks instead of overwriting")
	DATASTORES["SkyGlide_PlayerData_v1"]["player_42"].Lock = nil
	LEAVE(LOCAL_PLAYER)
	STEP(1)
	REJOIN(LOCAL_PLAYER)
	STEP(2)
	check(profile() ~= nil and profile().Wins == before.Wins, "the next join loads the last good save")
	-- server shutdown saves everyone
	local shutdownOk = SHUTDOWN(30)
	record = DATASTORES["SkyGlide_PlayerData_v1"]["player_42"]
	check(shutdownOk and record.Lock == nil, "BindToClose saves and releases every profile")
	REJOIN(LOCAL_PLAYER)
	STEP(2)
	check(profile() ~= nil, "loaded again after the shutdown test")
	STEP(2)
	closeMenus()
end

-- 14. Mobile ------------------------------------------------------------------------------------------------------
section("14. mobile")
do
	UIS.TouchEnabled = true
	UIS.KeyboardEnabled = false
	UIS.MouseEnabled = false
	UIS.GetLastInputType = function()
		return Enum.UserInputType.Touch
	end
	camera.ViewportSize = Vector2.new(844, 390)
	camera:GetPropertyChangedSignal("ViewportSize"):Fire()
	UIS.LastInputTypeChanged:Fire(Enum.UserInputType.Touch)
	STEP(0.5)
	local expectedScale = math.clamp(math.min(844 / 1800, 390 / 920) * 1.22, 0.42, 1.6)
	check(math.abs(UI.Scale - expectedScale) < 1e-6, "UI scales for a phone with bigger tap targets (" .. string.format("%.3f", UI.Scale) .. ")")
	stand(Map.Origin(profile().World) + Vector3.new(0, 0, (Map.ThrowZone.MinZ + Map.ThrowZone.MaxZ) / 2))
	STEP(Flight.LandCooldown)
	local keyHint = playerGui:FindFirstChild("KeyHint", true)
	check(keyHint ~= nil and keyHint.Text == "HOLD", "the THROW hint switches to touch wording (no key)")
	local touch = input(Enum.UserInputType.Touch)
	BUTTON("Throw").InputBegan:Fire(touch)
	STEP(0.4)
	UIS.InputEnded:Fire(touch, false)
	local touchPlan = nil
	for _ = 1, 60 do
		STEP(1 / 30)
		touchPlan = Throw.ActivePlan()
		if touchPlan then
			break
		end
	end
	check(touchPlan ~= nil, "a touch hold on THROW launches")
	local touchTaps = 0
	if touchPlan then
		local index = 1
		while Throw.ActivePlan() ~= nil and CLOCK < touchPlan.Start + touchPlan.Duration + 6 do
			STEP(1 / 30)
			local rt = touchPlan.RingTimes[index]
			if rt and CLOCK - touchPlan.Start >= rt - 0.03 then
				tap("touch")
				touchTaps += 1
				index += 1
			end
		end
	end
	settle(1)
	local touchLanding = LAST_SENT("FlightLanded", LOCAL_PLAYER)
	check(touchLanding ~= nil and touchLanding.Perfects == touchTaps and touchTaps > 0, "tapping anywhere on the screen catches rings (" .. tostring(touchLanding and touchLanding.Perfects) .. "/" .. touchTaps .. ")")
end

-- 15. Gamepad -----------------------------------------------------------------------------------------------------
section("15. gamepad")
do
	UIS.TouchEnabled = false
	UIS.GamepadEnabled = true
	UIS.GetLastInputType = function()
		return Enum.UserInputType.Gamepad1
	end
	camera.ViewportSize = Vector2.new(1920, 1080)
	camera:GetPropertyChangedSignal("ViewportSize"):Fire()
	UIS.LastInputTypeChanged:Fire(Enum.UserInputType.Gamepad1)
	STEP(Flight.LandCooldown + 0.5)
	check(HAS_TEXT(playerGui, "HOLD [R2]"), "the THROW hint shows R2")
	local r2 = input(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR2)
	check(CAS_BINDINGS.SkyGlideThrow ~= nil, "R2 is bound in the throw zone")
	CAS_BINDINGS.SkyGlideThrow("SkyGlideThrow", Enum.UserInputState.Begin, r2)
	STEP(0.6)
	CAS_BINDINGS.SkyGlideThrow("SkyGlideThrow", Enum.UserInputState.End, r2)
	local padPlan = nil
	for _ = 1, 60 do
		STEP(1 / 30)
		padPlan = Throw.ActivePlan()
		if padPlan then
			break
		end
	end
	check(padPlan ~= nil, "holding and releasing R2 throws")
	if padPlan then
		local index = 1
		while Throw.ActivePlan() ~= nil and CLOCK < padPlan.Start + padPlan.Duration + 6 do
			STEP(1 / 30)
			local rt = padPlan.RingTimes[index]
			if rt and CLOCK - padPlan.Start >= rt - 0.03 then
				tap("gamepad")
				index += 1
			end
		end
	end
	settle(1)
	local padLanding = LAST_SENT("FlightLanded", LOCAL_PLAYER)
	check(padLanding ~= nil and padPlan ~= nil and padLanding.Perfects == #padPlan.RingTimes, "button A catches every ring")
	-- menus: select a HUD button with the controller, press A, navigate, B closes
	local GuiService = FAKE_GAME:GetService("GuiService")
	local shopTile = BUTTON("Shop")
	GuiService.SelectedObject = shopTile
	shopTile.Activated:Fire(input(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA))
	STEP(0.5)
	check(UI.Get("Shop"):IsOpen(), "A on a selected HUD button opens the menu")
	local selected = GuiService.SelectedObject
	check(selected ~= nil and selected ~= shopTile and selected:IsDescendantOf(playerGui:FindFirstChild("SkyGlide_Menus")), "the controller selection moves into the menu")
	check(CAS_BINDINGS.SkyGlideMenu_Shop ~= nil, "B is bound while the menu is open")
	CAS_BINDINGS.SkyGlideMenu_Shop("SkyGlideMenu_Shop", Enum.UserInputState.Begin, input(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonB))
	STEP(0.5)
	check(not UI.Get("Shop"):IsOpen(), "B closes the menu")
end

-- 17. Exploits: garbage and out-of-order intents can't break or cheat anything --------------------------------
section("17. exploits")
do
	local exploiter = JOIN(666, "Exploiter")
	STEP(2)
	local ep = DataService.Get(exploiter)
	check(ep ~= nil, "exploiter joined")
	-- diagnostics are refused for normal players once Studio-wide access is off
	local Admin = MODULE("ReplicatedStorage/Shared/Config/Admin")
	Admin.StudioAll = false
	local adminTry = AS(exploiter, "AdminRequest", "GrantWins", 1e9)
	check(adminTry ~= nil and adminTry.ok == false and ep.Wins == 0, "AdminRequest is refused for a normal player")
	Admin.StudioAll = true
	-- targeted cheats
	local function snapshot()
		local pets = 0
		for _ in ep.Pets do
			pets += 1
		end
		return { ep.Wins, ep.Skill, ep.Rebirths, pets, ep.Worlds["2"] == true, ep.Gliders[Gliders.ForWorld(4)[1].Id] == true }
	end
	local start = snapshot()
	local Remotes = MODULE("ReplicatedStorage/Shared/Net/Remotes")
	local function fire(name, ...)
		local r = FAKE_GAME:GetService("ReplicatedStorage"):FindFirstChild("Remotes"):FindFirstChild(name)
		if Remotes.Spec[name] == "RemoteFunction" then
			local ok, result = pcall(r.OnServerInvoke, exploiter, ...)
			return ok, result
		end
		r.OnServerEvent:Fire(exploiter, ...)
		return true, nil
	end
	local cheats = {
		{ "RequestEnterWorld", 4 },
		{ "RequestEnterWorld", 2 },
		{ "RequestBuyThrowable", Gliders.ForWorld(4)[1].Id },
		{ "RequestEquipThrowable", "relic:aurora_relic" },
		{ "RequestHatchEgg", "overlord_egg", 1 },
		{ "RequestHatchEgg", "beach_egg", 1000 },
		{ "RequestClaimGift", 12 },
		{ "RequestClaimGift", 0 },
		{ "RequestRebirth" },
		{ "RequestTrain" },
		{ "RequestToggle", "AutoThrow", true },
		{ "RequestGust", 1, 1 },
		{ "RequestUseBoost", "skill_potion" },
		{ "RequestRedeemCode", "LAUNCH" },
		{ "RequestPetAction", "Delete", { "1" } },
		{ "RequestTrailAction", "Buy", "rainbow" },
	}
	for _, c in cheats do
		fire(table.unpack(c))
		STEP(0.6, 5)
	end
	local after = snapshot()
	-- only the code (a legitimate free reward) may have changed Wins
	check(after[2] == start[2] and after[3] == start[3] and after[4] == start[4] and after[5] == false and after[6] == false, "out-of-order intents grant nothing (Skill, rebirths, pets, worlds, gliders)")
	-- fuzz every client->server remote with values Roblox can carry
	local junk = { {}, { 0 / 0 }, { math.huge }, { -math.huge }, { -1 }, { 1e308 }, { string.rep("A", 100000) }, { {} }, { { 1, 2, 3 } }, { { a = { b = { c = {} } } } }, { LOCAL_PLAYER }, { Vector3.new(1, 2, 3) }, { true }, { "Delete", 0 / 0 }, { "Buy", math.huge } }
	local warningsBefore = #SERVER_WARNINGS
	local remoteErrors = 0
	for name in Remotes.Spec do
		if string.sub(name, 1, 7) == "Request" or name == "AdminRequest" then
			for _, args in junk do
				local ok = fire(name, table.unpack(args))
				if not ok then
					remoteErrors += 1
				end
				STEP(0.4, 5)
			end
		end
	end
	local handlerErrors = 0
	for i = warningsBefore + 1, #SERVER_WARNINGS do
		if string.find(SERVER_WARNINGS[i], "handler error", 1, true) then
			handlerErrors += 1
			print("FUZZ: " .. SERVER_WARNINGS[i])
		end
	end
	check(remoteErrors == 0 and handlerErrors == 0, "no handler errors from fuzzed arguments (" .. handlerErrors .. ")")
	local function finite(n)
		return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
	end
	check(finite(ep.Wins) and finite(ep.Skill) and finite(ep.Level) and finite(ep.Rebirths), "the exploiter's numbers stay finite")
	LEAVE(exploiter)
	STEP(1)
	local saved = DATASTORES["SkyGlide_PlayerData_v1"]["player_666"]
	check(saved ~= nil and saved.Lock == nil, "the fuzzed profile still saves (valid DataStore data)")
	check(profile() ~= nil and State.Data ~= nil, "our own session is unaffected")
end

-- results ---------------------------------------------------------------------------------------------------
for _, e in CLIENT_ERRORS do
	print("CLIENT ERROR: " .. e)
end
for _, e in NET_ERRORS do
	print("NET ERROR: " .. e)
end
for _, w in SERVER_WARNINGS do
	print("WARNING: " .. w)
end
check(#CLIENT_ERRORS == 0, "no errors in any handler, task or render step")
check(#NET_ERRORS == 0, "every remote payload follows Roblox's network rules")
check(#SERVER_WARNINGS == 0, "no warnings from any module")
print(string.format("playthrough.spec: %d checks, %d failures", checks, failures))
