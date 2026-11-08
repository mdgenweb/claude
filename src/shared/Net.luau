--!strict
-- Remote registry. The server creates every remote up-front; clients wait for them.
-- Keep this list as the single source of truth for networking.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"Data", -- S→C  ("init", snapshot) | ("patch", {key = value})
	"Notify", -- S→C  (kind, payload)
	"Lab", -- S→C  (state)
	"FX", -- S→C  (kind, payload)  reliable one-shot effects
	"Trial", -- S→C  (phase, payload)
	"Command", -- C→S  (command, arg)
	"GrabRelease", -- C→S  (flingVelocity)
	"Use", -- C→S  (payload)
	"Settings", -- C→S  (key, value)
	"Hover", -- C→S  ()  reserved
}

local FUNCTIONS = {
	"Grab", -- (part, localOffset) -> boolean
	"Brew", -- ({ingredientIds}) -> result
	"Shop", -- (action, ...) -> result
	"Visit", -- (ownerUserId) -> result
	"TrialRequest", -- (action, trialId?) -> result
}

local UNRELIABLE = {
	"Cursor", -- C→S (x, y, state) | S→C ({ {userId, x, y, state} })
	"FXU", -- S→C (kind, payload) cosmetic, droppable
}

local Net = {}

local folder: Folder? = nil

local function ensureFolder(): Folder
	local current = folder
	if current then
		return current
	end
	local result: Folder
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild("Remotes")
		if existing and existing:IsA("Folder") then
			result = existing
		else
			local created = Instance.new("Folder")
			created.Name = "Remotes"
			created.Parent = ReplicatedStorage
			result = created
		end
	else
		result = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	end
	folder = result
	return result
end

function Net.setup()
	assert(RunService:IsServer(), "Net.setup is server-only")
	local root = ensureFolder()
	local function make(className: string, name: string)
		if not root:FindFirstChild(name) then
			local remote = Instance.new(className)
			remote.Name = name
			remote.Parent = root
		end
	end
	for _, name in EVENTS do
		make("RemoteEvent", name)
	end
	for _, name in FUNCTIONS do
		make("RemoteFunction", name)
	end
	for _, name in UNRELIABLE do
		make("UnreliableRemoteEvent", name)
	end
end

function Net.event(name: string): RemoteEvent
	return ensureFolder():WaitForChild(name) :: RemoteEvent
end

function Net.func(name: string): RemoteFunction
	return ensureFolder():WaitForChild(name) :: RemoteFunction
end

function Net.unreliable(name: string): UnreliableRemoteEvent
	return ensureFolder():WaitForChild(name) :: UnreliableRemoteEvent
end

return Net
