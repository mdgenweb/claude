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
	g.Name = "SkyGlideSFX"
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
local enabled = true

-- Global SFX toggle (Settings).
function AudioController.SetEnabled(on: boolean)
	enabled = on
	ensure()
	group.Volume = if on then 0.9 else 0
end

-- Plays with an explicit playback speed (rising ring chimes).
function AudioController.PlayPitched(name: string, speed: number, volumeScale: number?)
	ensure()
	local spec = AudioConfig.Sounds[name]
	if spec == nil or not enabled then
		return
	end
	local sound = acquire(name, SoundService)
	if sound then
		sound.PlaybackSpeed = speed
		sound.Volume = spec.Volume * (volumeScale or 1)
		sound.TimePosition = 0
		sound:Play()
	end
end

local loops: { [string]: Sound } = {}

-- Starts/stops a looped sound (flight wind). `volumeScale` can be updated while playing.
function AudioController.Loop(name: string, on: boolean, volumeScale: number?, speed: number?)
	ensure()
	local spec = AudioConfig.Sounds[name]
	if spec == nil then
		return
	end
	local sound = loops[name]
	if on then
		if not sound then
			local s = Instance.new("Sound")
			s.Name = name .. "Loop"
			s.SoundId = spec.Id
			s.Looped = true
			s.SoundGroup = group
			s.Parent = SoundService
			loops[name] = s
			sound = s
		end
		local s = sound :: Sound
		s.Volume = spec.Volume * (volumeScale or 1)
		s.PlaybackSpeed = speed or 1
		if not s.IsPlaying then
			s:Play()
		end
	elseif sound then
		sound:Stop()
	end
end

function AudioController.Play(name: string, position: Vector3?, throttle: number?, volumeScale: number?)
	ensure()
	if not enabled then
		return
	end
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
