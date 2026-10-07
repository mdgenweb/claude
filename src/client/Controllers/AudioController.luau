--!strict
-- Plays sounds from Config/Audio. 2D for UI, 3D (positioned) for battle events so spectators
-- hear fights from where they happen. Sound instances are pooled per spec.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local AudioConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.Audio)

local AudioController = {}

local rng = Random.new()
local pools: { [string]: { Sound } } = {}
local lastPlayed: { [string]: number } = {}
local group: SoundGroup
local emitterFolder: Folder

local function ensure()
	if group then
		return
	end
	local g = Instance.new("SoundGroup")
	g.Name = "OrbClashSFX"
	g.Volume = 0.9
	g.Parent = SoundService
	group = g
	local f = Instance.new("Folder")
	f.Name = "SoundEmitters"
	f.Parent = Workspace
	emitterFolder = f
end

local function acquire(name: string, parent: Instance): Sound?
	local spec = AudioConfig.Sounds[name]
	if spec == nil then
		return nil
	end
	local pool = pools[name]
	if pool == nil then
		pool = {}
		pools[name] = pool
	end
	for _, s in pool do
		if not s.IsPlaying and s.Parent == parent then
			return s
		end
	end
	if #pool >= 8 then
		local oldest = table.remove(pool, 1) :: Sound
		oldest:Destroy()
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = spec.Id
	sound.Volume = spec.Volume
	sound.SoundGroup = group
	sound.RollOffMaxDistance = 160
	sound.RollOffMinDistance = 18
	sound.Parent = parent
	table.insert(pool, sound)
	return sound
end

-- Plays a named sound. `position` makes it 3D. `throttle` (seconds) skips spammy repeats.
function AudioController.Play(name: string, position: Vector3?, throttle: number?, volumeScale: number?)
	ensure()
	local now = os.clock()
	if throttle and lastPlayed[name] and now - lastPlayed[name] < throttle then
		return
	end
	lastPlayed[name] = now
	local spec = AudioConfig.Sounds[name]
	if spec == nil then
		return
	end
	local parent: Instance = SoundService
	if position then
		local emitter = Instance.new("Part")
		emitter.Anchored = true
		emitter.CanCollide = false
		emitter.CanQuery = false
		emitter.CanTouch = false
		emitter.Transparency = 1
		emitter.Size = Vector3.one
		emitter.Position = position
		emitter.Parent = emitterFolder
		parent = emitter
		task.delay(3, function()
			emitter:Destroy()
		end)
	end
	local sound = acquire(name, parent)
	if sound == nil then
		return
	end
	sound.PlaybackSpeed = rng:NextNumber(spec.Pitch[1], spec.Pitch[2])
	sound.Volume = spec.Volume * (volumeScale or 1)
	sound.TimePosition = 0
	sound:Play()
end

return AudioController
