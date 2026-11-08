--!nonstrict
-- Trove: tracks things that need cleaning up (instances, connections, threads, functions)
-- and destroys them all at once.

export type Trove = {
	Add: <T>(self: Trove, item: T) -> T,
	Connect: (self: Trove, signal: RBXScriptSignal, fn: (...any) -> ()) -> RBXScriptConnection,
	Clean: (self: Trove) -> (),
	Destroy: (self: Trove) -> (),
	Extend: (self: Trove) -> Trove,
}

local Trove = {}
Trove.__index = Trove

local function cleanItem(item: any)
	local kind = typeof(item)
	if kind == "Instance" then
		item:Destroy()
	elseif kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "function" then
		item()
	elseif kind == "thread" then
		if coroutine.status(item) ~= "dead" then
			pcall(task.cancel, item)
		end
	elseif kind == "table" then
		if type(item.Destroy) == "function" then
			item:Destroy()
		elseif type(item.Disconnect) == "function" then
			item:Disconnect()
		elseif type(item.Clean) == "function" then
			item:Clean()
		end
	end
end

function Trove.new(): Trove
	local self = setmetatable({ _items = {} }, Trove)
	return (self :: any) :: Trove
end

function Trove:Add(item)
	table.insert(self._items, item)
	return item
end

function Trove:Connect(signal: RBXScriptSignal, fn)
	local connection = signal:Connect(fn)
	table.insert(self._items, connection)
	return connection
end

function Trove:Extend()
	local child = Trove.new()
	table.insert(self._items, child)
	return child
end

function Trove:Clean()
	local items = self._items
	self._items = {}
	-- Clean in reverse order of addition (LIFO), like a stack unwind.
	for i = #items, 1, -1 do
		local ok, err = pcall(cleanItem, items[i])
		if not ok then
			warn("[Trove] cleanup error:", err)
		end
	end
end

Trove.Destroy = Trove.Clean

return Trove
