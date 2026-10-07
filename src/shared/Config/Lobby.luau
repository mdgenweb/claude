--!strict
-- Lobby layout (studs). +X east, +Z south, floor top at Y = 0.
-- See docs/RESEARCH.md section D for the top-down plan this mirrors.
export type StationConfig = {
	Id: string,
	Mode: "1v1" | "2v2",
	Position: { number }, -- floor point directly under the arena centre
	Yaw: number, -- degrees; 0 = station front faces world +Z
}

export type PropConfig = {
	Id: string,
	Kind: string,
	Position: { number },
	Yaw: number,
	Label: string?,
	OpenUI: string?, -- client UI route opened by the prompt, e.g. "Store:Balls"
}

local Lobby = {}

Lobby.Colors = {
	Floor = "#1E2A45",
	FloorDark = "#172036",
	Trim = "#3D7BE0",
	TrimGlow = "#59A8FF",
	Void = "#C7C8CE",
	ArenaFrame = "#2B2E36",
	ArenaInterior = "#050608",
	ArenaInnerWall = "#16181D",
	Ledge = "#22304F",
	LedgeBand = "#2F74E8",
	Pad = "#5FD3FF",
	Chevron = "#F4F6FA",
	TeamRed = "#FF2B2B",
	TeamBlue = "#19B6FF",
}

Lobby.Plaza = { Center = { 0, 0, 0 }, Size = { 200, 150 }, Height = 6 }
Lobby.Hall = { Center = { 230, 0, 40 }, Size = { 200, 90 }, Height = 6 }
Lobby.Bridge = { From = { 100, 0, 40 }, To = { 130, 0, 40 }, Width = 30 }
Lobby.Spawn = { Position = { 0, 0, 52 }, Yaw = 160 }

Lobby.Stations = {
	{ Id = "D1", Mode = "1v1", Position = { 160, 0, -1 }, Yaw = 0 },
	{ Id = "D2", Mode = "1v1", Position = { 206, 0, -1 }, Yaw = 0 },
	{ Id = "D3", Mode = "1v1", Position = { 252, 0, -1 }, Yaw = 0 },
	{ Id = "D4", Mode = "1v1", Position = { 298, 0, -1 }, Yaw = 0 },
	{ Id = "D5", Mode = "1v1", Position = { 160, 0, 81 }, Yaw = 180 },
	{ Id = "D6", Mode = "1v1", Position = { 206, 0, 81 }, Yaw = 180 },
	{ Id = "D7", Mode = "1v1", Position = { 252, 0, 81 }, Yaw = 180 },
	{ Id = "D8", Mode = "1v1", Position = { 298, 0, 81 }, Yaw = 180 },
	{ Id = "T1", Mode = "2v2", Position = { 0, 0, -60 }, Yaw = 0 },
} :: { StationConfig }

Lobby.Props = {
	{ Id = "OrbMachine", Kind = "GachaMachine", Position = { 66, 0, -22 }, Yaw = -70, Label = "Orbs", OpenUI = "Store:Balls" },
	{ Id = "ExplosionMachine", Kind = "CrateDisplay", Position = { 72, 0, 12 }, Yaw = -90, Label = "Explosions", OpenUI = "Store:Explosions" },
	{ Id = "FlyerDisplay", Kind = "FlyerDisplay", Position = { -66, 0, -22 }, Yaw = 70, Label = "Flyers", OpenUI = "Store:Flyers" },
	{ Id = "EventDisplay", Kind = "EventDisplay", Position = { -62, 0, 18 }, Yaw = 90, Label = "Event", OpenUI = "Store:Events" },
	{ Id = "GroupPedestal", Kind = "GroupPedestal", Position = { 0, 0, 24 }, Yaw = 0, Label = "Like + Join Group" },
	{ Id = "BoardAllTime", Kind = "Leaderboard", Position = { -60, 0, -66 }, Yaw = 15, Label = "AllTime" },
	{ Id = "BoardWeekly", Kind = "Leaderboard", Position = { 60, 0, -66 }, Yaw = -15, Label = "Weekly" },
	{ Id = "DecorOrb", Kind = "DecorOrb", Position = { -48, 34, -50 }, Yaw = 30 },
} :: { PropConfig }

Lobby.Chevrons = {
	Path = { { 8, 0, 46 }, { 60, 0, 42 }, { 100, 0, 40 }, { 140, 0, 40 }, { 150, 0, 40 } },
	Spacing = 7,
}

Lobby.Leaderboards = {
	Stat = "Wins", -- "Wins" (default) or "RobuxSpent" to mirror the reference's spender boards
	AllTimeTitle = "Top Winners",
	WeeklyTitle = "Weekly Top Winners",
	Size = 10,
	RefreshSeconds = 60,
	WeekEpochOffset = 345600, -- shifts week boundaries to Monday 00:00 UTC
}

return Lobby
