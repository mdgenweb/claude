--!strict
-- Visual tokens for UI and world signage. See docs/DESIGN_SYSTEM.md.
-- Style: chunky simulator UI — saturated vertical gradients, thick ink outlines,
-- white cartoon type with ink stroke, glossy shine strip, hard drop shadow.

local Theme = {}

export type Swatch = { Top: Color3, Bottom: Color3, Deep: Color3 }

local function swatch(top: string, bottom: string, deep: string): Swatch
	return { Top = Color3.fromHex(top), Bottom = Color3.fromHex(bottom), Deep = Color3.fromHex(deep) }
end

Theme.Swatch = {
	Green = swatch("#8CF55A", "#2DBE2A", "#17721A"), -- buy / affordable / confirm
	Blue = swatch("#62CCFF", "#1F7BEA", "#123F8F"), -- info / garage
	Orange = swatch("#FFB24A", "#FF7417", "#A84500"), -- brand / upgrade / mech
	Purple = swatch("#CF92FF", "#8B3FF0", "#4A1A94"), -- rebirth / VIP
	Red = swatch("#FF7070", "#E02D2D", "#8A1212"), -- close / alerts
	Yellow = swatch("#FFE85E", "#FFB300", "#9E6600"), -- scrap currency / rewards
	Lime = swatch("#D4FF5A", "#7BD81E", "#3F7A0B"), -- lime paint
	Steel = swatch("#8A97AD", "#535F75", "#2A3242"), -- disabled / neutral
	Navy = swatch("#34405A", "#1E2638", "#0F1420"), -- panel body
}

Theme.Ink = Color3.fromHex("#0E1118") -- outlines, shadows, text stroke
Theme.White = Color3.fromHex("#FFFFFF")
Theme.Muted = Color3.fromHex("#B8C4DA")
Theme.ScrapGold = Color3.fromHex("#FFD12E")
Theme.PowerCyan = Color3.fromHex("#5BE7FF")
Theme.ScreenBlue = Color3.fromHex("#45D4FF")
Theme.Hazard = Color3.fromHex("#FFC61A")
Theme.Good = Color3.fromHex("#6CFF5C")
Theme.Bad = Color3.fromHex("#FF5A5A")

Theme.LaneColors = {
	Color3.fromHex("#FF5A5A"),
	Color3.fromHex("#FF9E2C"),
	Color3.fromHex("#FFE14D"),
	Color3.fromHex("#5DEB5A"),
	Color3.fromHex("#4FB8FF"),
	Color3.fromHex("#B57BFF"),
}

Theme.Font = {
	Display = Enum.Font.LuckiestGuy, -- titles, numbers, big buttons
	Body = Enum.Font.FredokaOne, -- labels, descriptions
}

Theme.Text = { Display = 48, H1 = 34, H2 = 26, Body = 20, Label = 16, Small = 13 }
Theme.Space = { XS = 4, S = 8, M = 12, L = 16, XL = 24, XXL = 32 }
Theme.Radius = { S = 8, M = 12, L = 18, Pill = 999 }
Theme.Stroke = { Thin = 2, Chunky = 3, Heavy = 4 }
Theme.ShadowOffset = 5

Theme.Motion = {
	Hover = 0.12,
	Press = 0.07,
	Release = 0.25,
	PanelIn = 0.32,
	PanelOut = 0.16,
	HoverScale = 1.07,
	PressScale = 0.92,
	HoverTilt = -3,
}

-- Text stroke thickness that reads well at a given text size.
function Theme.strokeFor(textSize: number): number
	return math.clamp(math.floor(textSize / 9 + 0.5), 1, 4)
end

return Theme
