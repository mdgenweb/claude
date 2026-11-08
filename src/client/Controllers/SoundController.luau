--!nonstrict
-- Sound design using only audio that ships with the Roblox client (verified against the client
-- manifest) — each base sample is pitch-shifted and layered into many cues. Optional music IDs
-- can be added in Config.MusicIds.

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local SoundController = {}

local SAMPLES = {
	explosion = "rbxasset://sounds/impact_explosion_03.mp3",
	splash = "rbxasset://sounds/impact_water.mp3",
	land = "rbxasset://sounds/action_jump_land.mp3",
	jump = "rbxasset://sounds/action_jump.mp3",
	getup = "rbxasset://sounds/action_get_up.mp3",
	wind = "rbxasset://sounds/action_falling.ogg",
	swim = "rbxasset://sounds/action_swim.mp3",
	step = "rbxasset://sounds/action_footsteps_plastic.mp3",
	oof = "rbxasset://sounds/oof.ogg",
	ouch = "rbxasset://sounds/ouch.ogg",
	tick = "rbxasset://sounds/volume_slider.ogg",
}

-- cue = list of layers {sample, volume, pitchMin, pitchMax, delay?}
local CUES = {
	hover = { { "tick", 0.1, 2.2, 2.4 } },
	click = { { "tick", 0.4, 1.3, 1.4 } },
	open = { { "getup", 0.22, 1.5, 1.6 }, { "tick", 0.2, 1.8, 1.8 } },
	close = { { "getup", 0.18, 1.9, 2 } },
	error = { { "land", 0.35, 0.55, 0.6 } },
	coin = { { "tick", 0.32, 2.6, 3 } },
	reward = { { "tick", 0.4, 1.6, 1.6 }, { "tick", 0.4, 2, 2, 0.08 }, { "tick", 0.45, 2.4, 2.4, 0.16 } },
	levelup = {
		{ "tick", 0.5, 1.2, 1.2 },
		{ "tick", 0.5, 1.5, 1.5, 0.1 },
		{ "tick", 0.5, 1.8, 1.8, 0.2 },
		{ "tick", 0.55, 2.4, 2.4, 0.3 },
		{ "getup", 0.3, 1.2, 1.2, 0.3 },
	},
	discover = {
		{ "swim", 0.5, 0.7, 0.7 },
		{ "tick", 0.45, 1.5, 1.5, 0.15 },
		{ "tick", 0.45, 2, 2, 0.3 },
		{ "tick", 0.5, 2.6, 2.6, 0.45 },
	},
	glass = { { "splash", 0.5, 1.5, 1.8 }, { "tick", 0.32, 2.7, 3.1 } },
	splash = { { "splash", 0.45, 0.85, 1.05 } },
	explosion = { { "explosion", 0.8, 0.85, 1.05 } },
	bigExplosion = { { "explosion", 1, 0.55, 0.65 }, { "land", 0.6, 0.4, 0.45 } },
	thud = { { "land", 0.5, 0.75, 1 } },
	whoosh = { { "getup", 0.35, 0.8, 1.15 } },
	throw = { { "getup", 0.28, 1.25, 1.45 } },
	pop = { { "tick", 0.5, 0.5, 0.6 }, { "jump", 0.35, 1.4, 1.6 } },
	boing = { { "jump", 0.5, 0.75, 0.95 } },
	zap = { { "explosion", 0.32, 2.3, 2.7 }, { "tick", 0.3, 3, 3.4 } },
	thunder = { { "explosion", 0.55, 0.42, 0.5 } },
	freeze = { { "splash", 0.35, 2, 2.3 }, { "tick", 0.3, 3, 3.2 } },
	sizzle = { { "splash", 0.3, 2.5, 2.8 } },
	fire = { { "wind", 0.25, 1.4, 1.6 } },
	bubble = { { "swim", 0.4, 0.55, 0.75 } },
	brew = { { "swim", 0.6, 0.45, 0.5 }, { "tick", 0.4, 2.2, 2.2, 0.25 }, { "tick", 0.4, 2.8, 2.8, 0.38 } },
	ouch = { { "ouch", 0.5, 0.95, 1.1 } },
	oof = { { "oof", 0.5, 0.9, 1.1 } },
	groan = { { "oof", 0.45, 0.45, 0.55 } },
	squeak = { { "ouch", 0.45, 1.8, 2.1 } },
	heal = { { "tick", 0.35, 1.8, 1.8 }, { "tick", 0.35, 2.3, 2.3, 0.1 }, { "swim", 0.25, 1.3, 1.3 } },
	magic = { { "tick", 0.35, 2.2, 2.2 }, { "tick", 0.35, 2.7, 2.7, 0.07 }, { "getup", 0.2, 1.8, 1.8 } },
	step = { { "step", 0.35, 0.9, 1.1 } },
	crack = { { "splash", 0.35, 2.6, 3 } },
	crush = { { "land", 0.7, 0.35, 0.45 }, { "explosion", 0.3, 1.4, 1.5 } },
	spawn = { { "getup", 0.3, 1.1, 1.2 }, { "tick", 0.3, 2.4, 2.4, 0.05 } },
}
SoundController.Cues = CUES

local groups = {}
local fxRoot: Folder
local recent = {} :: { [string]: { number } }
local volumes = { sfx = 0.8, music = 0.5 }

function SoundController:Init(controllers)
	self.C = controllers
end

local function group(name: string, volume: number): SoundGroup
	local g = SoundService:FindFirstChild(name) :: SoundGroup?
	if not g then
		local created = Instance.new("SoundGroup")
		created.Name = name
		created.Volume = volume
		created.Parent = SoundService
		g = created
	end
	return g :: SoundGroup
end

function SoundController:Start()
	groups.SFX = group("SFX", 0.8)
	groups.UI = group("UI", 0.8)
	groups.Ambience = group("Ambience", 0.6)
	groups.Music = group("Music", 0.5)
	fxRoot = Instance.new("Folder")
	fxRoot.Name = "ClientSounds"
	fxRoot.Parent = Workspace

	local State = self.C.State
	State.Changed:Connect(function(key)
		if (key == "settings" or key == "*") and State.data then
			volumes.sfx = State.data.settings.sfx or 0.8
			volumes.music = State.data.settings.music or 0.5
			groups.SFX.Volume = volumes.sfx
			groups.UI.Volume = volumes.sfx
			groups.Ambience.Volume = volumes.sfx * 0.8
			groups.Music.Volume = volumes.music
		end
	end)
	State.LabChanged:Connect(function(lab, previous)
		if not previous or previous.ownerId ~= lab.ownerId or previous.mapId ~= lab.mapId then
			self:_setAmbience(lab)
		end
	end)
	self:_startMusic()
end

local anchorPart: Part? = nil
local function positionedHost(position: Vector3): Attachment
	if not anchorPart then
		local part = Instance.new("Part")
		part.Name = "SoundAnchor"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.Size = Vector3.one
		part.CFrame = CFrame.new()
		part.Parent = fxRoot
		anchorPart = part
	end
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = anchorPart
	return attachment
end

local function throttled(cue: string): boolean
	local now = os.clock()
	local list = recent[cue]
	if not list then
		list = {}
		recent[cue] = list
	end
	for i = #list, 1, -1 do
		if now - list[i] > 0.15 then
			table.remove(list, i)
		end
	end
	if #list >= 6 then
		return true
	end
	table.insert(list, now)
	return false
end

-- Plays a cue. opts: {pitch = multiplier, volume = multiplier, ui = bool}
function SoundController:Play(cue: string, position: Vector3?, opts)
	local layers = CUES[cue]
	if not layers or throttled(cue) then
		return
	end
	opts = opts or {}
	local isUi = opts.ui == true or position == nil
	local timeScale = self.C.State:TimeScale()
	local slow = if not isUi and timeScale > 0 and timeScale < 1 then 0.62 else 1
	for _, layer in layers do
		local sample, volume, pMin, pMax, delay = layer[1], layer[2], layer[3], layer[4], layer[5]
		local function fire()
			local sound = Instance.new("Sound")
			sound.SoundId = SAMPLES[sample]
			sound.Volume = volume * (opts.volume or 1)
			sound.PlaybackSpeed = (pMin + math.random() * (pMax - pMin)) * (opts.pitch or 1) * slow
			sound.SoundGroup = if isUi then groups.UI else groups.SFX
			local host: Instance
			if position and not isUi then
				local attachment = positionedHost(position)
				sound.RollOffMode = Enum.RollOffMode.InverseTapered
				sound.RollOffMinDistance = 110
				sound.RollOffMaxDistance = 600
				host = attachment
				Debris:AddItem(attachment, 6)
			else
				host = groups.UI
			end
			sound.Parent = host
			sound:Play()
			Debris:AddItem(sound, 6)
		end
		if delay and delay > 0 then
			task.delay(delay, fire)
		else
			fire()
		end
	end
end

-- Cauldron bubbling and per-map ambient loops.
function SoundController:_setAmbience(lab)
	if self._ambient then
		for _, sound in self._ambient do
			sound:Destroy()
		end
	end
	self._ambient = {}
	local function loop(sample: string, position: Vector3?, volume: number, pitch: number)
		local sound = Instance.new("Sound")
		sound.SoundId = SAMPLES[sample]
		sound.Looped = true
		sound.Volume = volume
		sound.PlaybackSpeed = pitch
		sound.SoundGroup = groups.Ambience
		if position then
			local attachment = positionedHost(position)
			sound.RollOffMode = Enum.RollOffMode.InverseTapered
			sound.RollOffMinDistance = 60
			sound.RollOffMaxDistance = 400
			sound.Parent = attachment
			table.insert(self._ambient, attachment)
		else
			sound.Parent = groups.Ambience
		end
		sound:Play()
		table.insert(self._ambient, sound)
	end
	if lab.cauldron then
		loop("swim", lab.cauldron + Vector3.new(0, 6, 0), 0.28, 0.42)
	end
	if lab.mapId == "storm" or lab.mapId == "sky" then
		loop("wind", nil, 0.18, 0.55)
	elseif lab.mapId == "lava" then
		loop("swim", lab.origin, 0.2, 0.3)
	elseif lab.mapId == "frost" or lab.mapId == "void" then
		loop("wind", nil, 0.1, 0.4)
	end
end

function SoundController:_startMusic()
	local ids = Config.MusicIds
	if #ids == 0 then
		return
	end
	local index = 0
	local music = Instance.new("Sound")
	music.Name = "Music"
	music.SoundGroup = groups.Music
	music.Volume = 0.5
	music.Parent = groups.Music
	local function nextTrack()
		index = index % #ids + 1
		music.SoundId = ids[index]
		music:Play()
	end
	music.Ended:Connect(nextTrack)
	nextTrack()
end

return SoundController
