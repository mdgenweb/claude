--!nonstrict
-- Live multiplayer cursors: every player streams their in-lab cursor (unreliable, ~12 Hz) and the
-- server relays it to everyone else viewing the same lab.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local World = require(script.Parent.Parent.Systems.World)

local CursorService = {}

function CursorService:Init(services)
	self.S = services
	self._cursors = {}
end

function CursorService:Start()
	local remote = Net.unreliable("Cursor")
	remote.OnServerEvent:Connect(function(player, x, y, state)
		if typeof(x) ~= "number" or typeof(y) ~= "number" or x ~= x or y ~= y then
			return
		end
		self._cursors[player] = { x = x, y = y, s = if typeof(state) == "string" then state:sub(1, 8) else "" , t = os.clock() }
	end)
	Players.PlayerRemoving:Connect(function(player)
		self._cursors[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1 / 12)
			local now = os.clock()
			for _, lab in World.labs do
				local viewers = World.viewers(lab)
				if #viewers < 2 then
					continue
				end
				local list = {}
				for _, viewer in viewers do
					local cursor = self._cursors[viewer]
					if cursor and now - cursor.t < 2 then
						table.insert(list, { viewer.UserId, cursor.x, cursor.y, cursor.s, viewer.DisplayName })
					end
				end
				if #list > 0 then
					for _, viewer in viewers do
						remote:FireClient(viewer, list)
					end
				end
			end
		end
	end)
end

return CursorService
