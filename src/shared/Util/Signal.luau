--!nonstrict
-- Lightweight pure-Luau signal. Handlers run in their own thread (task.spawn) so a yielding
-- or erroring handler never blocks or breaks the emitter.

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	DisconnectAll: (self: Signal<T...>) -> (),
}

local Signal = {}
Signal.__index = Signal

local ConnectionClass = {}
ConnectionClass.__index = ConnectionClass

function ConnectionClass:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false
	local handlers = self._signal._handlers
	local index = table.find(handlers, self)
	if index then
		table.remove(handlers, index)
	end
end

function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({ _handlers = {} }, Signal)
	return (self :: any) :: Signal<T...>
end

function Signal:Connect(fn)
	local connection = setmetatable({ Connected = true, _signal = self, _fn = fn }, ConnectionClass)
	table.insert(self._handlers, connection)
	return connection
end

function Signal:Once(fn)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

function Signal:Fire(...)
	-- Snapshot so handlers can disconnect while iterating.
	local snapshot = table.clone(self._handlers)
	for _, connection in snapshot do
		if connection.Connected then
			task.spawn(connection._fn, ...)
		end
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:DisconnectAll()
	for _, connection in table.clone(self._handlers) do
		connection.Connected = false
	end
	table.clear(self._handlers)
end

return Signal
