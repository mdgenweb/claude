--!prelude-before _rbxmock.luau
--!prelude-after _clientmock.luau
--!prelude-after _servermock.luau
--!prelude-after _guidump.luau
-- Drives the real client + server into every screen state and dumps the GUI tree on each device
-- (see tests/ui_render.py, which lays the dumps out like Roblox, draws them and lints them).
-- Not a spec: run it through ui_render.py.
local Map = MODULE("ReplicatedStorage/Shared/Config/Map")
local Flight = MODULE("ReplicatedStorage/Shared/Config/Flight")
local Eggs = MODULE("ReplicatedStorage/Shared/Definitions/Eggs")

BOOT_SERVER()
STEP(0.2)
BOOT_CLIENT()
STEP(1)

local CLIENT = "StarterPlayer/StarterPlayerScripts/Client/"
local UI = MODULE(CLIENT .. "Controllers/UIController")
local Throw = MODULE(CLIENT .. "Controllers/ThrowController")
local UIS = FAKE_GAME:GetService("UserInputService")

local function capture(label, settle)
	for _, device in DEVICE_NAMES do
		SET_DEVICE(device)
		STEP(settle or 0.35)
		DUMP_GUI(label)
	end
	SET_DEVICE("pc")
end
local function stand(position)
	MOVE_TO(position + Vector3.new(0, 3, 0))
	STEP(0.5)
end
local zone = Map.Origin(1) + Vector3.new(0, 0, (Map.ThrowZone.MinZ + Map.ThrowZone.MaxZ) / 2)

capture("hud_join")
STEP(3)
capture("gifts_autoopen")
UI.CloseMenus()
STEP(0.5)

stand(Map.Origin(1) + Map.PadPosition(1))
capture("hud_pad")

stand(zone)
capture("hud_zone")

-- hold THROW (the meter sweeps); captured quickly on each device before the max hold
local press = { UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.Unknown, Position = Vector3.zero }
BUTTON("Throw").InputBegan:Fire(press)
for _, device in DEVICE_NAMES do
	SET_DEVICE(device)
	STEP(0.05)
	DUMP_GUI("hud_charging")
end
SET_DEVICE("pc")
UIS.InputEnded:Fire(press, false)
for _ = 1, 60 do
	STEP(1 / 30)
	if Throw.ActivePlan() then
		break
	end
end
STEP(1.5)
capture("flight", 0.1)
local plan = Throw.ActivePlan()
while Throw.ActivePlan() ~= nil and plan and CLOCK < plan.Start + plan.Duration + 6 do
	STEP(0.1)
	local card = LOCAL_PLAYER:FindFirstChild("PlayerGui"):FindFirstChild("LandingCard", true)
	if card and SHOWN(card) then
		break
	end
end
STEP(0.6)
capture("landing", 0.05)
STEP(6)

-- some pets for the Pets menu
AS(LOCAL_PLAYER, "AdminRequest", "GrantWins", 1e6)
local egg = Eggs.ForWorld(1)[1]
local eggBase = FAKE_GAME:GetService("Workspace"):FindFirstChild("Worlds"):FindFirstChild("World_1"):FindFirstChild("Eggs"):FindFirstChild("Egg_" .. egg.Id):FindFirstChild("Base")
stand(eggBase.Position + Vector3.new(0, 0, 5))
for _ = 1, 4 do
	AS(LOCAL_PLAYER, "RequestHatchEgg", egg.Id, 1)
	STEP(0.6)
end
STEP(1)
capture("hatch_reveal", 0.2)
for _ = 1, 8 do
	STEP(2.5)
	local reveal = LOCAL_PLAYER:FindFirstChild("PlayerGui"):FindFirstChild("HatchReveal", true)
	if reveal and SHOWN(reveal) then
		CLICK(reveal)
	end
end
STEP(1)

local MENUS = {
	{ "menu_shop", "Shop" },
	{ "menu_rebirth", "Rebirth" },
	{ "menu_pets", "Pets" },
	{ "menu_index", "Index" },
	{ "menu_trails", "Trails" },
	{ "menu_inventory", "Inventory" },
	{ "menu_gifts", "Gifts" },
	{ "menu_world", "World", 2 },
	{ "menu_settings", "Settings" },
	{ "menu_admin", "Admin" },
	{ "menu_egg", "Egg", egg.Id },
}
for _, m in MENUS do
	UI.Open(m[2], m[3])
	STEP(0.5)
	capture(m[1])
	UI.CloseMenus()
	STEP(0.5)
end
UI.Open("Inventory")
STEP(0.3)
CLICK(BUTTON("Potions"))
capture("menu_inventory_potions")
UI.CloseMenus()
STEP(0.5)

-- toasts
local Net = MODULE(CLIENT .. "Controllers/Net")
task.spawn(Net.Invoke, "RequestRedeemCode", false, "LAUNCH")
STEP(0.3)
task.spawn(Net.Invoke, "RequestRedeemCode", false, "NOPE")
STEP(0.3)
capture("toasts", 0.1)

-- hover tooltip (mouse devices only)
for _, device in { "pc", "laptop" } do
	SET_DEVICE(device)
	STEP(0.3)
	BUTTON("Shop").MouseEnter:Fire()
	STEP(0.1)
	DUMP_GUI("tooltip")
	BUTTON("Shop").MouseLeave:Fire()
end
SET_DEVICE("pc")

for _, e in CLIENT_ERRORS do
	print("CLIENT ERROR: " .. e)
end
for _, e in NET_ERRORS do
	print("NET ERROR: " .. e)
end
