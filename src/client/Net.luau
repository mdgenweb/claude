-- Client-side state store fed by the server's snapshots, plus request helpers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Economy)
local Signal = require(Shared.Signal)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Request = Remotes:WaitForChild("Request") :: RemoteFunction

local Net = {}

Net.State = nil :: any
Net.Changed = Signal.new() -- (state, previous)
Net.Notified = Signal.new() -- (kind, title, body)
Net.Fx = Signal.new() -- (name, ...)
Net.MenuChanged = Signal.new() -- (panelName?)

local receivedAt = os.clock()

function Net.serverNow(): number
	if not Net.State then
		return os.time()
	end
	return Net.State.ServerTime + (os.clock() - receivedAt)
end

-- Boost seconds left, counted down locally while the server says the clock is running.
function Net.boostRemaining(): number
	local s = Net.State
	if not s then
		return 0
	end
	if s.BoostTicking then
		return math.max(0, s.BoostRemaining - (os.clock() - receivedAt))
	end
	return s.BoostRemaining
end

function Net.workshopStored(): number
	local s = Net.State
	if not s then
		return 0
	end
	return Economy.workshopStored(s.Workshop.Stored, s.Workshop.Updated, Net.serverNow())
end

-- Returns ok, message. Never throws.
function Net.request(action: string, arg: any?): (boolean, string?)
	local ok, result, message = pcall(function()
		return Request:InvokeServer(action, arg)
	end)
	if not ok then
		return false, "Connection hiccup. Try again."
	end
	return result == true, message
end

function Net.unlocked(area: number): boolean
	local s = Net.State
	if not s then
		return area == 1
	end
	if area == 2 then
		return s.Gates.Appliance == true
	elseif area == 3 then
		return s.Gates.Crusher == true
	end
	return area == 1
end

function Net.init()
	Remotes:WaitForChild("State").OnClientEvent:Connect(function(snapshot)
		local previous = Net.State
		Net.State = snapshot
		receivedAt = os.clock()
		Net.Changed:Fire(snapshot, previous)
	end)
	Remotes:WaitForChild("Notify").OnClientEvent:Connect(function(kind, title, body)
		Net.Notified:Fire(kind, title, body)
	end)
	Remotes:WaitForChild("Fx").OnClientEvent:Connect(function(...)
		Net.Fx:Fire(...)
	end)
end

return Net
