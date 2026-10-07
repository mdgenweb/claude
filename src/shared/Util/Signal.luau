--!strict
-- Lightweight synchronous signal (no Roblox instances; usable in headless tests).
export type Connection = { Connected: boolean, Disconnect: (Connection) -> () }

local Signal = {}
Signal.__index = Signal

type Listener = { fn: (...any) -> (), conn: Connection }

export type Signal = typeof(setmetatable({} :: { _listeners: { Listener } }, Signal))

function Signal.new(): Signal
	return setmetatable({ _listeners = {} }, Signal)
end

function Signal.Connect(self: Signal, fn: (...any) -> ()): Connection
	local listeners = self._listeners
	local conn: Connection
	conn = {
		Connected = true,
		Disconnect = function(c: Connection)
			if not c.Connected then
				return
			end
			c.Connected = false
			for i, l in listeners do
				if l.conn == c then
					table.remove(listeners, i)
					break
				end
			end
		end,
	}
	table.insert(listeners, { fn = fn, conn = conn })
	return conn
end

function Signal.Once(self: Signal, fn: (...any) -> ()): Connection
	local conn: Connection
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end

function Signal.Fire(self: Signal, ...: any)
	-- Snapshot so listeners may disconnect while firing.
	local snapshot = table.clone(self._listeners)
	for _, l in snapshot do
		if l.conn.Connected then
			l.fn(...)
		end
	end
end

function Signal.DisconnectAll(self: Signal)
	for _, l in self._listeners do
		l.conn.Connected = false
	end
	table.clear(self._listeners)
end

Signal.Destroy = Signal.DisconnectAll

return Signal
