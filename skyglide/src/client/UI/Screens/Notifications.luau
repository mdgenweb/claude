--!strict
-- Server toasts: every Notify remote ({ Text, Kind }) relayed by StateController.Notified becomes
-- a UIController toast. Kinds: Info, Success, Error, Level, Rare. Identical messages arriving in a
-- burst (e.g. several level-ups in one second) are collapsed so the stack never floods.
local Client = script.Parent.Parent.Parent
local StateController = require(Client.Controllers.StateController)
local UIController = require(Client.Controllers.UIController)

local Notifications = {}

local KINDS: { [string]: boolean } = { Info = true, Success = true, Error = true, Level = true, Rare = true }
local REPEAT_WINDOW = 1.2 -- seconds: the same text inside this window is shown once
local MAX_LENGTH = 200

local lastText = ""
local lastAt = -math.huge

function Notifications.Init()
	StateController.Notified:Connect(function(payload: any)
		if type(payload) ~= "table" or type(payload.Text) ~= "string" or payload.Text == "" then
			return
		end
		local text = string.sub(payload.Text, 1, MAX_LENGTH)
		local kind = if type(payload.Kind) == "string" and KINDS[payload.Kind] then payload.Kind else "Info"
		local now = os.clock()
		if text == lastText and now - lastAt < REPEAT_WINDOW then
			return
		end
		lastText = text
		lastAt = now
		UIController.Toast(text, kind)
	end)
end

return Notifications
