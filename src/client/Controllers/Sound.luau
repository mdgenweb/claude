-- Plays the configurable sounds from Config.Sounds (skips any left blank).

local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local Sound = {}

local VOLUME = { Swing = 0.25, Hit = 0.35, Break = 0.5, Coin = 0.3, Click = 0.25, Upgrade = 0.6 }

function Sound.play(name: string, position: Vector3?, pitch: number?)
	local id = Config.Sounds[name]
	if not id or id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = VOLUME[name] or 0.4
	s.PlaybackSpeed = pitch or 1
	if position then
		local holder = Instance.new("Attachment")
		holder.WorldPosition = position
		holder.Parent = Workspace.Terrain
		s.RollOffMaxDistance = 90
		s.Parent = holder
		s.Ended:Once(function()
			holder:Destroy()
		end)
		s:Play()
		task.delay(6, function()
			if holder.Parent then
				holder:Destroy()
			end
		end)
	else
		s.Parent = SoundService
		SoundService:PlayLocalSound(s)
		task.delay(4, function()
			s:Destroy()
		end)
	end
end

return Sound
