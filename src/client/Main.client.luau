--!nonstrict
-- Client bootstrap: requires every controller, gives them a shared table and starts them in order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Potions = require(Shared.Data.Potions)
local Recipes = require(Shared.Data.Recipes)

local Controllers = script.Parent:WaitForChild("Controllers")
local UI = script.Parent:WaitForChild("UI")

local ORDER = {
	{ "State", Controllers },
	{ "CameraController", Controllers },
	{ "InputController", Controllers },
	{ "SoundController", Controllers },
	{ "LightingController", Controllers },
	{ "VFXController", Controllers },
	{ "AmbientController", Controllers },
	{ "GrabController", Controllers },
	{ "ToolController", Controllers },
	{ "UIController", UI },
	{ "CursorController", Controllers },
}

local controllers = {
	PotionIndex = Recipes.buildIndex(Potions.List),
}
for _, entry in ORDER do
	controllers[entry[1]] = require(entry[2]:WaitForChild(entry[1]))
end

-- State hooks up remotes first so nothing replicated early is missed.
controllers.State:Init()
for _, entry in ORDER do
	local controller = controllers[entry[1]]
	if entry[1] ~= "State" and controller.Init then
		controller:Init(controllers)
	end
end
for _, entry in ORDER do
	local controller = controllers[entry[1]]
	if controller.Start then
		local ok, err = pcall(controller.Start, controller)
		if not ok then
			warn(("[Main] %s failed to start: %s"):format(entry[1], tostring(err)))
		end
	end
end
