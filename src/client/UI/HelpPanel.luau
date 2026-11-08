--!nonstrict
-- F1 help: every keybind plus touch and gamepad controls and a few pro tips.

local Theme = require(script.Parent.Theme)
local C = require(script.Parent.Components)

local HelpPanel = {}

local KEYS = {
	{ "LMB (drag)", "Grab & fling" },
	{ "RMB", "Throw / feed potion or place item" },
	{ "1–9", "Select potion" },
	{ "Q", "Switch Throw / Feed" },
	{ "G", "Slow motion" },
	{ "Space", "Stop time" },
	{ "H", "Heal every golem" },
	{ "R", "Reset the room" },
	{ "N", "Spawn last golem / item" },
	{ "Z", "Undo last spawn" },
	{ "K", "Cure all zombies" },
	{ "B", "Cauldron" },
	{ "C", "Codex" },
	{ "J", "Quests" },
	{ "O", "Shop" },
	{ "M", "World menu" },
	{ "F", "Follow hovered golem" },
	{ "P", "Photo mode" },
	{ "Wheel / WASD / MMB", "Zoom & pan camera" },
	{ "Esc", "Close / deselect" },
}

local OTHER = {
	"📱 Touch: drag a golem to grab it, tap empty space to use your potion, pinch to zoom, two fingers to pan.",
	"🎮 Gamepad: left stick moves the cursor, A grabs, X uses, Y switches mode, LB/RB cycle potions, D-pad controls time.",
	"💡 Frozen golems shatter on hard hits. Fire melts ice into a steam explosion.",
	"💡 Mix anything! Unknown mixes make Murky Sludge, but the cauldron gives you a hint.",
	"💡 Brew a potion 5 times to master it: infinite bottles and +25% power.",
	"💡 Thrown potions leave puddles: fire, ice, glue, trampoline goo...",
}

function HelpPanel:Mount(ui, controllers)
	self.ui, self.C = ui, controllers
	local modal = C.Modal({ parent = ui.modals, title = "❔ Controls & Tips", size = Vector2.new(1100, 680) })
	self.modal = modal
	modal.onClose = function()
		ui:PanelClosed("help")
	end
	local left = C.Scroll({ parent = modal.body, size = UDim2.new(0.5, -12, 1, 0) })
	C.list(left, Enum.FillDirection.Vertical, Theme.Space.XS)
	for index, entry in KEYS do
		local row = C.frame({
			parent = left,
			color = Theme.Color.Surface.Raised,
			transparency = if index % 2 == 0 then 0.4 else 0.15,
			size = UDim2.new(1, -8, 0, 34),
			order = index,
			radius = Theme.Radius.SM,
		})
		local key = C.frame({
			parent = row,
			color = Theme.Color.Surface.Base,
			size = UDim2.fromOffset(190, 26),
			position = UDim2.fromOffset(6, 4),
			radius = Theme.Radius.SM,
			stroke = Theme.Color.Stroke.Gold,
			strokeThickness = 1,
		})
		C.text({
			parent = key,
			text = entry[1],
			type = "Caption",
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.fromScale(1, 1),
			color = Theme.Color.Accent.Gold,
			outline = false,
		})
		C.text({
			parent = row,
			text = entry[2],
			type = "Label",
			size = UDim2.new(1, -220, 1, 0),
			position = UDim2.fromOffset(210, 0),
		})
	end
	local right =
		C.Scroll({ parent = modal.body, size = UDim2.new(0.5, -12, 1, 0), position = UDim2.new(0.5, 12, 0, 0) })
	C.list(right, Enum.FillDirection.Vertical, Theme.Space.MD)
	for index, line in OTHER do
		local _, card =
			C.card({ parent = right, size = UDim2.new(1, -8, 0, 84), order = index, radius = Theme.Radius.MD })
		C.text({
			parent = card,
			text = line,
			type = "Body",
			textSize = 17,
			wrap = true,
			size = UDim2.new(1, -24, 1, -12),
			position = UDim2.fromOffset(12, 6),
		})
	end
end

function HelpPanel:Open()
	self.modal.open()
end

function HelpPanel:Close()
	self.modal.close()
end

return HelpPanel
