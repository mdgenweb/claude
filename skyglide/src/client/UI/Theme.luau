--!strict
-- Design tokens for the HUD and menus: bright, chunky "+1 simulator" style (ORIGINAL palette).
-- Big rounded display font with heavy dark strokes, saturated gradient buttons, deep-blue panels.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarity = require(ReplicatedStorage:WaitForChild("Shared").Config.Rarity)

local Theme = {}

local hex = Color3.fromHex

Theme.Colors = {
	Panel = hex("#1E3F9E"),
	PanelDeep = hex("#132B73"),
	PanelLight = hex("#2C56C9"),
	PanelBorder = hex("#0B1A4A"),
	PanelEdge = hex("#7FB2FF"),
	Card = hex("#2A50B8"),
	CardDeep = hex("#183A91"),
	CardBorder = hex("#0B1A4A"),
	Text = hex("#FFFFFF"),
	TextDim = hex("#CFE0FF"),
	TextMuted = hex("#8FA6D9"),
	Stroke = hex("#0B0F24"),
	Skill = hex("#FFD447"),
	Wins = hex("#FFC53D"),
	Rebirth = hex("#FF5FB0"),
	Gem = hex("#4FC3FF"),
	Success = hex("#5BE05B"),
	Danger = hex("#FF4F5E"),
	Warning = hex("#FFB300"),
	LevelTrack = hex("#0E1F57"),
	LevelFillTop = hex("#5FB8FF"),
	LevelFillBottom = hex("#2563EB"),
	Locked = hex("#FF4F5E"),
	Unlocked = hex("#5BE05B"),
	Meter = hex("#1B1F3B"),
	MeterGood = hex("#5BE05B"),
	MeterPerfect = hex("#FFD447"),
	Overlay = hex("#000000"),
}

Theme.Fonts = {
	Display = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular),
	Body = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
	BodyHeavy = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy),
	Numbers = Font.new("rbxasset://fonts/families/LuckiestGuy.json", Enum.FontWeight.Regular),
}

export type ButtonStyle = { Top: Color3, Bottom: Color3, Border: Color3, Text: Color3 }

Theme.Buttons = {
	Green = { Top = hex("#7BEA4A"), Bottom = hex("#2FA80F"), Border = hex("#124A05"), Text = hex("#FFFFFF") },
	Blue = { Top = hex("#5FB8FF"), Bottom = hex("#2563EB"), Border = hex("#0B2266"), Text = hex("#FFFFFF") },
	Red = { Top = hex("#FF6B6B"), Bottom = hex("#D7263D"), Border = hex("#5E0A14"), Text = hex("#FFFFFF") },
	Gold = { Top = hex("#FFE27A"), Bottom = hex("#F2A900"), Border = hex("#6B4300"), Text = hex("#FFFFFF") },
	Orange = { Top = hex("#FFB86B"), Bottom = hex("#F07800"), Border = hex("#6B3000"), Text = hex("#FFFFFF") },
	Purple = { Top = hex("#C98CFF"), Bottom = hex("#7A2BD6"), Border = hex("#33106B"), Text = hex("#FFFFFF") },
	Pink = { Top = hex("#FF8FC8"), Bottom = hex("#E8357F"), Border = hex("#6B1035"), Text = hex("#FFFFFF") },
	Grey = { Top = hex("#F2F5FA"), Bottom = hex("#AEB8C8"), Border = hex("#3A4256"), Text = hex("#FFFFFF") },
	Dark = { Top = hex("#2C56C9"), Bottom = hex("#183A91"), Border = hex("#0B1A4A"), Text = hex("#FFFFFF") },
	Disabled = { Top = hex("#8C93A3"), Bottom = hex("#5A6070"), Border = hex("#2A2E38"), Text = hex("#DDE1E8") },
} :: { [string]: ButtonStyle }

-- Rainbow gradient (the "+1M" pack button, mythic items)
Theme.Rainbow = ColorSequence.new({
	ColorSequenceKeypoint.new(0, hex("#FF4F4F")),
	ColorSequenceKeypoint.new(0.25, hex("#FFC53D")),
	ColorSequenceKeypoint.new(0.5, hex("#5BE05B")),
	ColorSequenceKeypoint.new(0.75, hex("#3FA9FF")),
	ColorSequenceKeypoint.new(1, hex("#B65CFF")),
})

-- Emoji icons (rendered by Roblox's emoji font; no image assets needed).
Theme.Icons = {
	Skill = "⚡",
	Wins = "🏆",
	Rebirth = "🌀",
	Shop = "🛒",
	Pets = "🐾",
	Trails = "💫",
	Inventory = "🎒",
	Gifts = "🎁",
	Settings = "⚙️",
	Codes = "🎟️",
	Daily = "📅",
	Egg = "🥚",
	Lock = "🔒",
	Check = "✅",
	Potion = "🧪",
	Luck = "🍀",
	Star = "⭐",
	Friends = "👥",
	Auto = "🔁",
	World = "🌍",
	Glider = "🪁",
	Relic = "🔥",
	Robux = "R$",
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

-- Base design resolution. Screens are authored in these pixels; UIController scales them.
Theme.DesignSize = Vector2.new(1800, 920)

return Theme
