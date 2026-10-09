--!strict
-- Thin wrappers for client -> server intents. Invoke() shows the server's error/message as a
-- toast so every button gets consistent feedback.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Net.Remotes)

local Net = {}

local busy: { [string]: boolean } = {}

-- Invokes a RemoteFunction. Returns the result table ({ ok = boolean, error?, message? ... }).
-- `quiet` suppresses toasts. Concurrent invokes of the same remote are dropped (double clicks).
function Net.Invoke(name: string, quiet: boolean?, ...: any): { [string]: any }
	if busy[name] then
		return { ok = false, error = "busy" }
	end
	busy[name] = true
	local ok, result = pcall(function(...)
		return Remotes.Function(name):InvokeServer(...)
	end, ...)
	busy[name] = nil
	if not ok or type(result) ~= "table" then
		result = { ok = false, error = "Connection problem. Try again." }
	end
	if not quiet then
		local UIController = require(script.Parent.UIController)
		if result.ok == false and result.error and result.error ~= "busy" then
			UIController.Toast(result.error, "Error")
		elseif result.ok and result.message then
			UIController.Toast(result.message, "Success")
		end
	end
	return result
end

function Net.Fire(name: string, ...: any)
	Remotes.Event(name):FireServer(...)
end

return Net
