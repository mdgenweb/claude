--[[
	Sounds
	`id` = your uploaded/licensed asset ("rbxassetid://123"). When empty, `fallback` (a file shipped with the
	Roblox client) is used so the game is never silent in Studio. Volumes are 0..1 before the player setting.
]]

local Sounds = {
	Click = { id = "", fallback = "rbxasset://sounds/button.wav", volume = 0.5 },
	Hover = { id = "", fallback = "rbxasset://sounds/clickfast.wav", volume = 0.25 },
	Open = { id = "", fallback = "rbxasset://sounds/clickfast.wav", volume = 0.4 },
	Place = { id = "", fallback = "rbxasset://sounds/snap.wav", volume = 0.7 },
	Upgrade = { id = "", fallback = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6 },
	Sell = { id = "", fallback = "rbxasset://sounds/unsheath.wav", volume = 0.5 },
	Error = { id = "", fallback = "rbxasset://sounds/clickfast.wav", volume = 0.6, pitch = 0.6 },
	Hit = { id = "", fallback = "rbxasset://sounds/swordslash.wav", volume = 0.18 },
	Boom = { id = "", fallback = "rbxasset://sounds/collide.wav", volume = 0.45 },
	Zap = { id = "", fallback = "rbxasset://sounds/electronicpingshort.wav", volume = 0.25, pitch = 1.6 },
	Pop = { id = "", fallback = "rbxasset://sounds/snap.wav", volume = 0.3, pitch = 1.4 },
	Coin = { id = "", fallback = "rbxasset://sounds/electronicpingshort.wav", volume = 0.2, pitch = 2 },
	Leak = { id = "", fallback = "rbxasset://sounds/uuhhh.mp3", volume = 0.4 },
	BossWarn = { id = "", fallback = "rbxasset://sounds/swordlunge.wav", volume = 0.8, pitch = 0.5 },
	Wave = { id = "", fallback = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5, pitch = 0.8 },
	Victory = { id = "", fallback = "rbxasset://sounds/electronicpingshort.wav", volume = 0.8, pitch = 1.2 },
	Defeat = { id = "", fallback = "rbxasset://sounds/uuhhh.mp3", volume = 0.7 },
	SummonCrank = { id = "", fallback = "rbxasset://sounds/clickfast.wav", volume = 0.6, pitch = 0.7 },
	SummonReveal = { id = "", fallback = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6 },
	SummonRare = { id = "", fallback = "rbxasset://sounds/electronicpingshort.wav", volume = 0.9, pitch = 0.6 },
	TraitRoll = { id = "", fallback = "rbxasset://sounds/clickfast.wav", volume = 0.35 },
	TraitWin = { id = "", fallback = "rbxasset://sounds/electronicpingshort.wav", volume = 0.9, pitch = 0.8 },
	Reward = { id = "", fallback = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5, pitch = 1.5 },
}

-- Background music (leave empty until you have licensed tracks; e.g. from the Roblox audio library).
local Music = {
	Lobby = { id = "", volume = 0.35 },
	Match = { id = "", volume = 0.3 },
	Boss = { id = "", volume = 0.4 },
}

return { Sfx = Sounds, Music = Music }
