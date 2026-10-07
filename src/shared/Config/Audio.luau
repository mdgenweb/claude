--!strict
-- Sound library. Defaults use sound files that ship with every Roblox client
-- (rbxasset://sounds/...), so nothing is borrowed from the reference game. Replace any
-- entry with your own uploaded "rbxassetid://<id>" to upgrade the mix.
export type SoundSpec = {
	Id: string,
	Volume: number,
	Pitch: { number }, -- {min, max} random playback speed
}

local function s(id: string, volume: number, pmin: number, pmax: number): SoundSpec
	return { Id = id, Volume = volume, Pitch = { pmin, pmax } }
end

local Audio = {}

Audio.Sounds = {
	-- UI
	Hover = s("rbxasset://sounds/clickfast.wav", 0.15, 1.3, 1.4),
	Click = s("rbxasset://sounds/clickfast.wav", 0.45, 0.95, 1.05),
	Select = s("rbxasset://sounds/electronicpingshort.wav", 0.35, 1.15, 1.2),
	Countdown = s("rbxasset://sounds/electronicpingshort.wav", 0.6, 0.9, 0.9),
	CountdownGo = s("rbxasset://sounds/electronicpingshort.wav", 0.7, 1.35, 1.35),
	Error = s("rbxasset://sounds/clickfast.wav", 0.5, 0.55, 0.6),
	Purchase = s("rbxasset://sounds/electronicpingshort.wav", 0.5, 1.5, 1.5),
	Reward = s("rbxasset://sounds/victory.wav", 0.45, 1.1, 1.1),
	Open = s("rbxasset://sounds/swoosh.wav", 0.35, 1.2, 1.3),
	Close = s("rbxasset://sounds/swoosh.wav", 0.25, 0.9, 1.0),

	-- Battle
	Launch = s("rbxasset://sounds/swoosh.wav", 0.7, 0.8, 0.9),
	Bounce = s("rbxasset://sounds/collide.wav", 0.25, 1.1, 1.4),
	HitLight = s("rbxasset://sounds/collide.wav", 0.55, 0.8, 0.95),
	HitHeavy = s("rbxasset://sounds/bass.wav", 0.8, 0.9, 1.05),
	Ability = s("rbxasset://sounds/electronicpingshort.wav", 0.3, 0.7, 0.8),
	Laser = s("rbxasset://sounds/electronicpingshort.wav", 0.35, 0.45, 0.5),
	Shoot = s("rbxasset://sounds/Rocket shot.wav", 0.35, 1.4, 1.6),
	Explosion = s("rbxasset://sounds/Rocket shot.wav", 0.6, 0.6, 0.7),
	Zap = s("rbxasset://sounds/HalloweenThunder.wav", 0.35, 1.6, 1.8),
	Freeze = s("rbxasset://sounds/glassbreak.wav", 0.35, 1.5, 1.7),
	Shatter = s("rbxasset://sounds/glassbreak.wav", 0.45, 1.0, 1.2),
	Splat = s("rbxasset://sounds/splat.wav", 0.4, 0.9, 1.1),
	Death = s("rbxasset://sounds/Rocket shot.wav", 0.8, 0.45, 0.5),
	HeartBreak = s("rbxasset://sounds/glassbreak.wav", 0.7, 0.75, 0.8),
	Whoosh = s("rbxasset://sounds/swoosh.wav", 0.6, 0.7, 0.75),
	Train = s("rbxasset://sounds/Launching rocket.wav", 0.4, 1.3, 1.4),

	-- Meta
	GachaShake = s("rbxasset://sounds/swoosh.wav", 0.4, 1.6, 1.7),
	GachaReveal = s("rbxasset://sounds/electronicpingshort.wav", 0.6, 1.0, 1.0),
	RarePull = s("rbxasset://sounds/victory.wav", 0.5, 1.25, 1.25),
	LegendaryPull = s("rbxasset://sounds/victory.wav", 0.7, 0.9, 0.9),
	Victory = s("rbxasset://sounds/victory.wav", 0.7, 1.0, 1.0),
	Defeat = s("rbxasset://sounds/uuhhh.mp3", 0.5, 0.9, 0.9),
	LevelUp = s("rbxasset://sounds/victory.wav", 0.6, 1.4, 1.4),
} :: { [string]: SoundSpec }

return Audio
