-- Pick Your Mech! client entry point.

local Client = script.Parent
local UI = Client:WaitForChild("UI")
local Controllers = Client:WaitForChild("Controllers")
local Screens = UI:WaitForChild("Screens")

local Net = require(Client:WaitForChild("Net"))
local Gui = require(UI:WaitForChild("Gui"))
local Panels = require(UI:WaitForChild("Panels"))
local Hud = require(UI:WaitForChild("Hud"))
local Toasts = require(UI:WaitForChild("Toasts"))
local Effects = require(Controllers:WaitForChild("Effects"))
local AutoFarm = require(Controllers:WaitForChild("AutoFarm"))
local WorldUI = require(Controllers:WaitForChild("WorldUI"))
local ChatTags = require(Controllers:WaitForChild("ChatTags"))

Net.init()
Gui.init()
Panels.init()
Hud.init()
for _, name in { "Upgrade", "Shop", "Rebirth", "Garage", "Daily", "Gate", "ToolPicker" } do
	require(Screens:WaitForChild(name)).init()
end
Effects.init(Hud.flyScrap)
AutoFarm.init()
WorldUI.init()
ChatTags.init()

Net.Changed:Connect(Hud.update)

local CELEBRATE = { Form = true, Gate = true, Rebirth = true }
Net.Notified:Connect(function(kind, title, body)
	if CELEBRATE[kind] then
		Toasts.celebrate(kind, title, body)
	elseif kind == "Error" then
		Toasts.error(title .. (if body ~= "" then " " .. body else ""))
	else
		Toasts.show(kind, title, body)
	end
end)

-- If the server pushed state before we connected, ask for a fresh snapshot.
if not Net.State then
	task.delay(3, function()
		if not Net.State then
			Net.request("Sync")
		end
	end)
end
