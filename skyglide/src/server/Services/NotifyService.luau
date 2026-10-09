--!strict
-- Toasts to one player or everyone. Kinds: Info | Success | Error | Level | Rare
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Net.Remotes)

local NotifyService = {}

local remote: RemoteEvent

function NotifyService.Toast(player: Player, text: string, kind: string?)
	if remote and player.Parent then
		remote:FireClient(player, { Text = text, Kind = kind or "Info" })
	end
end

function NotifyService.All(text: string, kind: string?)
	if remote then
		remote:FireAllClients({ Text = text, Kind = kind or "Info" })
	end
end

function NotifyService.Init()
	remote = Remotes.Event("Notify")
end

return NotifyService
