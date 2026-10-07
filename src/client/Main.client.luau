--!strict
-- Client bootstrap: state mirror, UI layers + screens, then runtime controllers.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Remotes")

local Controllers = script.Parent.Controllers
local Screens = script.Parent.UI.Screens

local StateController = require(Controllers.StateController)
local UIController = require(Controllers.UIController)
local CameraController = require(Controllers.CameraController)
local BattleRenderer = require(Controllers.BattleRenderer)
local MatchController = require(Controllers.MatchController)
local LobbyController = require(Controllers.LobbyController)

StateController.Start()
UIController.Init()

for _, name in {
	"HUD",
	"StoreScreen",
	"InventoryScreen",
	"RevealScreen",
	"CodesScreen",
	"GemShop",
	"TradeScreen",
	"Notifications",
	"SelectionScreen",
	"BattleHUD",
	"ResultsScreen",
} do
	local screen = (require :: any)(Screens:WaitForChild(name))
	local ok, err = pcall(screen.Init)
	if not ok then
		warn(string.format("[Client] %s.Init failed: %s", name, tostring(err)))
	end
end

CameraController.Start()
BattleRenderer.Start()
MatchController.Start()
LobbyController.Start()
