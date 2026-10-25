--[[
	Net
	Single source of truth for remote names. The server creates the instances; clients wait for them.

	Remotes:
		Request   (RemoteFunction)        client -> server actions, routed by name, returns { ok, data | err }
		Profile   (RemoteEvent)           server -> client full profile view (throttled)
		Match     (RemoteEvent)           server -> client reliable match events (spawn/death/place/...)
		Notify    (RemoteEvent)           server -> client toast notifications
		Lobby     (RemoteEvent)           server -> client party room updates
		EnemySync (UnreliableRemoteEvent) server -> client packed enemy snapshots
		Fx        (UnreliableRemoteEvent) server -> client cosmetic attack events
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

Net.FOLDER_NAME = "Remotes"

Net.Definitions = {
	Request = "RemoteFunction",
	Profile = "RemoteEvent",
	Match = "RemoteEvent",
	Notify = "RemoteEvent",
	Lobby = "RemoteEvent",
	EnemySync = "UnreliableRemoteEvent",
	Fx = "UnreliableRemoteEvent",
}

local folder: Folder? = nil

-- Server: create all remotes once.
function Net.setupServer(): Folder
	assert(RunService:IsServer(), "Net.setupServer is server-only")
	local existing = ReplicatedStorage:FindFirstChild(Net.FOLDER_NAME)
	if existing then
		existing:Destroy()
	end
	local newFolder = Instance.new("Folder")
	newFolder.Name = Net.FOLDER_NAME
	for name, className in Net.Definitions do
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = newFolder
	end
	newFolder.Parent = ReplicatedStorage
	folder = newFolder
	return newFolder
end

function Net.get(name: string): any
	if not folder then
		folder = ReplicatedStorage:WaitForChild(Net.FOLDER_NAME) :: Folder
	end
	return (folder :: Folder):WaitForChild(name)
end

return Net
