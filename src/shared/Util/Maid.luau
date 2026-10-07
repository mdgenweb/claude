--!strict
-- Maid: collects connections, instances, threads and cleanup callbacks and releases them together.
export type Task = RBXScriptConnection | Instance | thread | () -> () | { Destroy: (any) -> () }

local Maid = {}
Maid.__index = Maid

export type Maid = typeof(setmetatable({} :: { _tasks: { [any]: Task? } }, Maid))

function Maid.new(): Maid
	return setmetatable({ _tasks = {} :: { [any]: Task? } }, Maid)
end

local function cleanup(task: any)
	local kind = typeof(task)
	if kind == "RBXScriptConnection" then
		task:Disconnect()
	elseif kind == "Instance" then
		task:Destroy()
	elseif kind == "thread" then
		if coroutine.status(task) ~= "dead" then
			pcall(task.cancel, task)
		end
	elseif kind == "function" then
		task()
	elseif kind == "table" and type(task.Destroy) == "function" then
		task:Destroy()
	end
end

function Maid.Give<T>(self: Maid, task: T): T
	table.insert(self._tasks, task :: any)
	return task
end

function Maid.Set(self: Maid, key: string, task: Task?)
	local old = self._tasks[key]
	if old ~= nil and old ~= task then
		self._tasks[key] = nil
		cleanup(old)
	end
	self._tasks[key] = task
end

function Maid.Clean(self: Maid)
	local tasks = self._tasks
	self._tasks = {}
	for _, task in tasks do
		cleanup(task)
	end
end

Maid.Destroy = Maid.Clean

return Maid
