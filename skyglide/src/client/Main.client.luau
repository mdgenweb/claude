--!strict
-- Client bootstrap: state mirror, UI layers + screens, then runtime controllers.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Remotes")

local Controllers = script.Parent.Controllers
local Screens = script.Parent.UI.Screens

local StateController = require(Controllers.StateController)
local UIController = require(Controllers.UIController)

StateController.Start()
UIController.Init()

local SCREENS = {
	"Notifications",
	"HUD",
	"ShopScreen",
	"RebirthScreen",
	"PetsScreen",
	"EggScreen",
	"TrailsScreen",
	"InventoryScreen",
	"GiftsScreen",
	"WorldScreen",
	"SettingsScreen",
	"AdminScreen",
	"EventBanner",
}

for _, name in SCREENS do
	local module = Screens:FindFirstChild(name)
	if not module then
		warn("[Client] missing screen " .. name)
		continue
	end
	local screen = (require :: any)(module)
	local ok, err = pcall(screen.Init)
	if not ok then
		warn(string.format("[Client] %s.Init failed: %s", name, tostring(err)))
	end
end

local CONTROLLERS = {
	"CameraController",
	"WorldController",
	"TrainingController",
	"ThrowController",
	"FlightRenderer",
	"PetFollowController",
	"TutorialController",
}

for _, name in CONTROLLERS do
	local module = Controllers:FindFirstChild(name)
	if not module then
		warn("[Client] missing controller " .. name)
		continue
	end
	local controller = (require :: any)(module)
	local ok, err = pcall(controller.Start)
	if not ok then
		warn(string.format("[Client] %s.Start failed: %s", name, tostring(err)))
	end
end
