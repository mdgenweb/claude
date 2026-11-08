--!strict
-- Design tokens. Mirrors docs/UI_DESIGN_SYSTEM.md 1:1 — UI code must read values from here.

local function hex(value: string): Color3
	return Color3.fromHex(value)
end

local Theme = {}

Theme.Color = {
	Surface = {
		Base = hex("#120D24"),
		Panel = hex("#1E1638"),
		Raised = hex("#2A2050"),
		Sunken = hex("#150F2B"),
	},
	PanelTransparency = 0.08,
	Stroke = {
		Subtle = hex("#3E3170"),
		Strong = hex("#6A55B8"),
		Gold = hex("#E8B653"),
	},
	Text = {
		Primary = hex("#FFF7E8"),
		Secondary = hex("#C9BEEA"),
		Muted = hex("#8F84B8"),
		Inverse = hex("#1A1230"),
		Outline = hex("#120A22"),
	},
	Accent = {
		Gold = hex("#FFD45E"),
		GoldDeep = hex("#E89A2C"),
		Magenta = hex("#FF4FA3"),
		Cyan = hex("#4FE3FF"),
		Lime = hex("#8CFF6B"),
	},
	State = {
		Success = hex("#6BFF8E"),
		Warning = hex("#FFB13B"),
		Danger = hex("#FF5A6A"),
		Info = hex("#6BB8FF"),
		Disabled = hex("#4A4268"),
	},
	Rarity = {
		Common = hex("#CDD4DE"),
		Uncommon = hex("#6BFF8E"),
		Rare = hex("#4FA8FF"),
		Epic = hex("#B36BFF"),
		Legendary = hex("#FFB13B"),
		Mythic = hex("#FF4F7A"),
	},
	Combo = {
		hex("#8F84B8"),
		hex("#4FE3FF"),
		hex("#8CFF6B"),
		hex("#FFC94A"),
		hex("#FF4FA3"),
	},
	Toast = {
		info = hex("#4FE3FF"),
		success = hex("#6BFF8E"),
		error = hex("#FF5A6A"),
		reward = hex("#FFD45E"),
		social = hex("#FF4FA3"),
	},
}

Theme.Font = {
	Title = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
	UI = Font.new("rbxasset://fonts/families/FredokaOne.json"),
}

Theme.Type = {
	Display = { font = Theme.Font.Title, size = 64 },
	Title = { font = Theme.Font.Title, size = 36 },
	Heading = { font = Theme.Font.UI, size = 26 },
	Body = { font = Theme.Font.UI, size = 20 },
	Label = { font = Theme.Font.UI, size = 16 },
	Caption = { font = Theme.Font.UI, size = 14 },
}

Theme.Space = { XS = 4, SM = 8, MD = 12, LG = 16, XL = 24, XXL = 32 }

Theme.Radius = {
	SM = UDim.new(0, 8),
	MD = UDim.new(0, 12),
	LG = UDim.new(0, 18),
	Pill = UDim.new(0.5, 0),
}

Theme.Stroke = { Hairline = 1, Default = 2, Emphasis = 3 }

Theme.Elevation = {
	E1 = { offset = 3, transparency = 0.6 },
	E2 = { offset = 6, transparency = 0.5 },
}

local function tween(duration: number, style: Enum.EasingStyle, direction: Enum.EasingDirection?): TweenInfo
	return TweenInfo.new(duration, style, direction or Enum.EasingDirection.Out)
end

Theme.Motion = {
	Hover = tween(0.12, Enum.EasingStyle.Quad),
	Press = tween(0.06, Enum.EasingStyle.Quad),
	Release = tween(0.22, Enum.EasingStyle.Back),
	PanelIn = tween(0.24, Enum.EasingStyle.Back),
	PanelOut = tween(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	ToastIn = tween(0.3, Enum.EasingStyle.Quint),
	ToastOut = tween(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	ToastHold = 3.2,
	Reveal = tween(0.45, Enum.EasingStyle.Back),
	Count = tween(0.5, Enum.EasingStyle.Quart),
	Pulse = tween(0.18, Enum.EasingStyle.Back),
	Fade = tween(0.2, Enum.EasingStyle.Quad),
}

Theme.Size = {
	Button = { sm = 36, md = 48, lg = 64 },
	IconButton = 72,
	IconButtonTouch = 80,
	Slot = 84,
	SlotTouch = 72,
	SlotGap = 8,
	Modal = Vector2.new(1100, 680),
	Toast = Vector2.new(360, 64),
}

Theme.DesignResolution = Vector2.new(1920, 1080)

function Theme.rarityColor(rarity: string?): Color3
	return (rarity and Theme.Color.Rarity[rarity]) or Theme.Color.Rarity.Common
end

function Theme.comboColor(level: number): Color3
	return Theme.Color.Combo[math.clamp(level, 1, #Theme.Color.Combo)]
end

return Theme
