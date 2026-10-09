--!strict
-- Sound library. Defaults use sound files that ship with every Roblox client
-- (rbxasset://sounds/...), so no audio is borrowed from the reference game. Replace any entry with
-- your own uploaded "rbxassetid://<id>" to upgrade the mix.
export type SoundSpec = {
	Id: string,
	Volume: number,
	Pitch: { number }, -- {min, max} random playback speed
	Looped: boolean?,
}

local function s(id: string, volume: number, pmin: number, pmax: number, looped: boolean?): SoundSpec
	return { Id = id, Volume = volume, Pitch = { pmin, pmax }, Looped = looped }
end

local Audio = {}

Audio.Sounds = {
	-- UI
	Hover = s("rbxasset://sounds/clickfast.wav", 0.12, 1.3, 1.4),
	Click = s("rbxasset://sounds/clickfast.wav", 0.45, 0.95, 1.05),
	Error = s("rbxasset://sounds/clickfast.wav", 0.5, 0.55, 0.6),
	Purchase = s("rbxasset://sounds/electronicpingshort.wav", 0.5, 1.5, 1.5),
	Reward = s("rbxasset://sounds/victory.wav", 0.45, 1.1, 1.1),
	Open = s("rbxasset://sounds/swoosh.wav", 0.3, 1.2, 1.3),
	Close = s("rbxasset://sounds/swoosh.wav", 0.22, 0.9, 1.0),
	LevelUp = s("rbxasset://sounds/victory.wav", 0.55, 1.4, 1.4),
	Rebirth = s("rbxasset://sounds/victory.wav", 0.7, 0.85, 0.85),

	-- Training
	Train = s("rbxasset://sounds/electronicpingshort.wav", 0.18, 1.6, 1.8),

	-- Flight
	Charge = s("rbxasset://sounds/electronicpingshort.wav", 0.25, 0.7, 0.7),
	Launch = s("rbxasset://sounds/swoosh.wav", 0.75, 0.75, 0.85),
	PerfectLaunch = s("rbxasset://sounds/victory.wav", 0.4, 1.6, 1.6),
	Wind = s("rbxasset://sounds/action_falling.mp3", 0.35, 1.0, 1.0, true),
	Ring = s("rbxasset://sounds/electronicpingshort.wav", 0.5, 1.0, 1.0), -- pitch raised per combo
	Perfect = s("rbxasset://sounds/electronicpingshort.wav", 0.65, 1.5, 1.5),
	Miss = s("rbxasset://sounds/clickfast.wav", 0.4, 0.5, 0.55),
	ZoneEnter = s("rbxasset://sounds/swoosh.wav", 0.45, 1.5, 1.6),
	Splash = s("rbxasset://sounds/impact_water.mp3", 0.8, 0.9, 1.1),
	NewBest = s("rbxasset://sounds/victory.wav", 0.55, 1.25, 1.25),

	-- Meta
	EggShake = s("rbxasset://sounds/swoosh.wav", 0.35, 1.6, 1.8),
	EggCrack = s("rbxasset://sounds/glassbreak.wav", 0.4, 1.2, 1.3),
	RareHatch = s("rbxasset://sounds/victory.wav", 0.6, 1.2, 1.2),
	Portal = s("rbxasset://sounds/swoosh.wav", 0.6, 0.6, 0.65),
} :: { [string]: SoundSpec }

return Audio
