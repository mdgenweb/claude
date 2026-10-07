--!strict
-- Design tokens reverse-engineered from the reference screenshots (see docs/RESEARCH.md §C).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarity = require(ReplicatedStorage:WaitForChild("Shared").Config.Rarity)

local Theme = {}

local hex = Color3.fromHex

Theme.Colors = {
	Panel = hex("#151B2C"),
	PanelDeep = hex("#0E1220"),
	PanelBorder = hex("#3A6FD6"),
	ModalBorder = hex("#3366CC"),
	Card = hex("#1B2236"),
	CardInner = hex("#222B44"),
	SubBar = hex("#1A2134"),
	Tile = hex("#0E1220"),
	TileBorder = hex("#3D7BE0"),
	Text = hex("#FFFFFF"),
	TextDim = hex("#AEB6C8"),
	TextMuted = hex("#7D869C"),
	Stroke = hex("#0A0C14"),
	Gold = hex("#FFC72C"),
	GoldDark = hex("#B86E00"),
	GemText = hex("#D8ECFF"),
	Heart = hex("#EF2B3C"),
	HeartEmpty = hex("#3A3F52"),
	TeamRed = hex("#FF2B2B"),
	TeamBlue = hex("#19B6FF"),
	Success = hex("#4CD420"),
	Danger = hex("#FF3D4F"),
	LevelTrack = hex("#2B2B2B"),
	LevelFill = hex("#A9ADB5"),
}

Theme.Fonts = {
	Display = Font.new("rbxasset://fonts/families/Michroma.json", Enum.FontWeight.Regular),
	Body = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
	BodyHeavy = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Heavy),
	BodySemi = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.SemiBold),
}

export type ButtonStyle = { Top: Color3, Bottom: Color3, Border: Color3, Text: Color3 }

Theme.Buttons = {
	Green = { Top = hex("#7BE52A"), Bottom = hex("#3A9A06"), Border = hex("#1F4D05"), Text = hex("#FFFFFF") },
	Blue = { Top = hex("#4F8BFF"), Bottom = hex("#2457E0"), Border = hex("#13307A"), Text = hex("#FFFFFF") },
	Grey = { Top = hex("#E6E9EE"), Bottom = hex("#9CA2AB"), Border = hex("#3A3F4A"), Text = hex("#FFFFFF") },
	Red = { Top = hex("#FF6170"), Bottom = hex("#D21E33"), Border = hex("#6B0A15"), Text = hex("#FFFFFF") },
	Purple = { Top = hex("#C27BFF"), Bottom = hex("#7A2BD6"), Border = hex("#3A0F70"), Text = hex("#FFFFFF") },
	Orange = { Top = hex("#FFC14D"), Bottom = hex("#F08C00"), Border = hex("#7A4300"), Text = hex("#FFFFFF") },
	Pink = { Top = hex("#FF7A9C"), Bottom = hex("#E83563"), Border = hex("#7A1031"), Text = hex("#FFFFFF") },
	Dark = { Top = hex("#2A3350"), Bottom = hex("#161C2E"), Border = hex("#3A6FD6"), Text = hex("#FFFFFF") },
	Disabled = { Top = hex("#6B707A"), Bottom = hex("#474B53"), Border = hex("#24262B"), Text = hex("#C7CAD1") },
} :: { [string]: ButtonStyle }

-- Store tab colours (screenshot 1)
Theme.Tabs = {
	Events = { Top = hex("#5AA6FF"), Bottom = hex("#2F78E0") },
	Balls = { Top = hex("#FFB627"), Bottom = hex("#E08A00") },
	Explosions = { Top = hex("#B967FF"), Bottom = hex("#8A33E0") },
	Flyers = { Top = hex("#FF6B8E"), Bottom = hex("#E83563") },
}

function Theme.Rarity(id: string): Color3
	return hex(Rarity.Get(id).Color)
end

function Theme.RarityDark(id: string): Color3
	return hex(Rarity.Get(id).Dark)
end

function Theme.RarityLight(id: string): Color3
	return hex(Rarity.Get(id).Light)
end

-- Base design resolution (the reference HUD screenshot is 1795 x 914).
Theme.DesignSize = Vector2.new(1800, 920)

return Theme
