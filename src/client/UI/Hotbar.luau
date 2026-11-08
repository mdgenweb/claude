--!nonstrict
-- Potion hotbar: 3D bottles in viewport slots, counts / ∞ mastery, rarity borders, 1-9 keys,
-- paging, the Throw/Feed mode toggle and the "placing" chip for golems/props.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Potions = require(Shared.Data.Potions)
local PropsData = require(Shared.Data.Props)
local Skins = require(Shared.Data.Skins)

local Theme = require(script.Parent.Theme)
local C = require(script.Parent.Components)

local Hotbar = {}

local SLOTS = 9

function Hotbar:Mount(ui, controllers)
	self.ui, self.C = ui, controllers
	local root = ui.hud
	local State = controllers.State
	local touch = ui.touch
	local slotSize = if touch then Theme.Size.SlotTouch else Theme.Size.Slot
	self.page = 0
	self.slots = {}

	local bar = C.new("Frame", {
		Name = "Hotbar",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(SLOTS * (slotSize + Theme.Size.SlotGap) + 220, slotSize + 40),
		Position = UDim2.new(0.5, 0, 1, -16),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = root,
	})
	self.bar = bar
	local _, background = C.card({
		parent = bar,
		size = UDim2.new(1, 0, 0, slotSize + 24),
		position = UDim2.fromOffset(0, 16),
		radius = Theme.Radius.LG,
	})
	local _ = background

	-- Mode toggle (Throw / Feed).
	local mode = C.IconButton({
		parent = bar,
		icon = "🧪",
		caption = "Throw",
		keybind = if touch then nil else "Q",
		sizePx = slotSize,
		position = UDim2.fromOffset(12, 28),
		onClick = function()
			controllers.InputController.Action:Fire("mode")
		end,
		tooltip = "Throw / Feed",
		tooltipBody = "Throw: splash everything nearby and leave a puddle.\nFeed: one golem drinks it (1.5x duration).",
	})
	State.ModeChanged:Connect(function(value)
		mode.setIcon(if value == "feed" then "🥄" else "🧪")
		mode.setCaption(if value == "feed" then "Feed" else "Throw")
		mode.setActive(value == "feed")
	end)

	local row = C.new("Frame", {
		Name = "Slots",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(SLOTS * (slotSize + Theme.Size.SlotGap), slotSize),
		Position = UDim2.fromOffset(slotSize + 28, 28),
		Parent = bar,
	})
	C.list(row, Enum.FillDirection.Horizontal, Theme.Size.SlotGap)
	for index = 1, SLOTS do
		self.slots[index] = self:_slot(row, index, slotSize, touch)
	end

	-- Paging arrows.
	local pager = C.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(70, slotSize),
		Position = UDim2.new(1, -82, 0, 28),
		Parent = bar,
	})
	local up = C.Button({
		parent = pager,
		text = "▲",
		width = 70,
		size = "sm",
		variant = "ghost",
		onClick = function()
			self:Page(-1)
		end,
	})
	local down = C.Button({
		parent = pager,
		text = "▼",
		width = 70,
		size = "sm",
		variant = "ghost",
		position = UDim2.new(0, 0, 1, -36),
		onClick = function()
			self:Page(1)
		end,
	})
	self.pageLabel = C.text({
		parent = pager,
		text = "1/1",
		type = "Caption",
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 20),
		position = UDim2.new(0, 0, 0.5, -10),
		color = Theme.Color.Text.Muted,
	})
	local _ = up
	local _2 = down

	-- Placing chip (golem / prop tool).
	local chipOuter, chip = C.card({
		parent = root,
		size = UDim2.fromOffset(360, 48),
		position = UDim2.new(0.5, 0, 1, -(slotSize + 72)),
		anchor = Vector2.new(0.5, 1),
		radius = Theme.Radius.Pill,
		stroke = Theme.Color.Accent.Cyan,
	})
	chipOuter.Visible = false
	local chipLabel = C.text({
		parent = chip,
		text = "",
		type = "Label",
		size = UDim2.new(1, -60, 1, 0),
		position = UDim2.fromOffset(18, 0),
	})
	C.Button({
		parent = chip,
		text = "✕",
		width = 40,
		size = "sm",
		variant = "ghost",
		position = UDim2.new(1, -6, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		onClick = function()
			State:Select(nil)
		end,
	})
	self.chip, self.chipLabel = chipOuter, chipLabel
	self.empty = C.text({
		parent = bar,
		text = "No potions yet. Open the cauldron (B) and brew something!",
		type = "Label",
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.new(1, -200, 0, slotSize),
		position = UDim2.fromOffset(slotSize + 28, 28),
		color = Theme.Color.Text.Secondary,
		z = 3,
	})

	State.Changed:Connect(function(key)
		if key == "*" or key == "potions" or key == "brewCount" then
			self:Refresh()
		end
	end)
	State.TrialChanged:Connect(function()
		self.page = 0
		self:Refresh()
	end)
	State.LabChanged:Connect(function()
		self:Refresh()
	end)
	State.SelectionChanged:Connect(function()
		self:_highlight()
	end)
	controllers.InputController.Action:Connect(function(action)
		local index = tonumber(action:match("^slot(%d)$"))
		if index then
			self:SelectIndex(index)
		elseif action == "slotNext" or action == "slotPrev" then
			self:Cycle(if action == "slotNext" then 1 else -1)
		end
	end)
	controllers.ToolController.Used:Connect(function(selection)
		for _, slot in self.slots do
			if slot.potionId and selection.kind == "potion" and slot.potionId == selection.id then
				C.pulse(slot.button, 0.9)
			end
		end
	end)
	self:Refresh()
end

function Hotbar:_slot(parent: Instance, index: number, size: number, touch: boolean)
	local button = C.new("TextButton", {
		Name = "Slot" .. index,
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = Theme.Color.Surface.Raised,
		BackgroundTransparency = 0.1,
		Size = UDim2.fromOffset(size, size),
		LayoutOrder = index,
		Parent = parent,
	})
	C.corner(button, Theme.Radius.MD)
	local stroke = C.stroke(button, Theme.Color.Rarity.Common, Theme.Stroke.Emphasis)
	C.gradient(button, Theme.Color.Surface.Raised, Theme.Color.Surface.Sunken)
	local holder = C.new("Frame", {
		Name = "Holder",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 1, -8),
		Position = UDim2.fromOffset(4, 4),
		Parent = button,
	})
	if not touch then
		C.text({
			parent = button,
			text = tostring(index),
			type = "Caption",
			size = UDim2.fromOffset(20, 18),
			position = UDim2.fromOffset(6, 4),
			color = Theme.Color.Text.Secondary,
			z = 4,
		})
	end
	local countBadge = C.frame({
		parent = button,
		color = Theme.Color.Surface.Base,
		transparency = 0.1,
		size = UDim2.fromOffset(34, 22),
		position = UDim2.new(1, -4, 1, -4),
		anchor = Vector2.new(1, 1),
		radius = Theme.Radius.Pill,
		z = 4,
	})
	local countLabel = C.text({
		parent = countBadge,
		text = "",
		type = "Caption",
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.fromScale(1, 1),
		z = 5,
	})
	local scale = C.interactive(button)
	local slot = {
		button = button,
		stroke = stroke,
		holder = holder,
		count = countLabel,
		countBadge = countBadge,
		scale = scale,
		potionId = nil,
		viewport = nil,
		spin = nil,
		selected = false,
	}
	button.Activated:Connect(function()
		C.sound("click")
		if slot.potionId then
			local State = self.C.State
			if State.selected and State.selected.kind == "potion" and State.selected.id == slot.potionId then
				State:Select(nil)
			else
				State:Select({ kind = "potion", id = slot.potionId })
			end
		end
	end)
	button.MouseEnter:Connect(function()
		if slot.potionId then
			local potion = Potions.ById[slot.potionId]
			local count = self.C.State:PotionCount(slot.potionId)
			local body = potion.description
				.. "\n"
				.. (if count < 0 then "∞ Mastered" else ("%d bottles"):format(count))
			C.showTooltip(potion.name .. "  ·  " .. potion.rarity, body, Theme.rarityColor(potion.rarity))
			if slot.spin then
				slot.spin(true)
			end
		end
	end)
	button.MouseLeave:Connect(function()
		C.hideTooltip()
		if slot.spin and not slot.selected then
			slot.spin(false)
		end
	end)
	return slot
end

function Hotbar:_list(): { string }
	return self.C.State:HotbarPotions()
end

function Hotbar:Refresh()
	local list = self:_list()
	local pages = math.max(1, math.ceil(#list / SLOTS))
	self.page = math.clamp(self.page, 0, pages - 1)
	self.pageLabel.Text = ("%d/%d"):format(self.page + 1, pages)
	self.empty.Visible = #list == 0
	for index, slot in self.slots do
		local potionId = list[self.page * SLOTS + index]
		if slot.potionId ~= potionId then
			if slot.viewport then
				slot.viewport:Destroy()
				slot.viewport, slot.spin = nil, nil
			end
			slot.potionId = potionId
			if potionId then
				local potion = Potions.ById[potionId]
				slot.viewport, slot.spin =
					C.BottleIcon({ parent = slot.holder, potion = potion, size = UDim2.fromScale(1, 1), zoom = 1.25 })
				slot.stroke.Color = Theme.rarityColor(potion.rarity)
			else
				slot.stroke.Color = Theme.Color.Stroke.Subtle
			end
		end
		slot.button.Visible = #list > 0
		if potionId then
			local count = self.C.State:PotionCount(potionId)
			slot.count.Text = if count < 0 then "∞" else tostring(count)
			slot.count.TextColor3 = if count < 0
				then Theme.Color.Accent.Gold
				elseif count == 0 then Theme.Color.State.Danger
				else Theme.Color.Text.Primary
			slot.countBadge.Visible = true
			slot.button.BackgroundTransparency = if count == 0 then 0.6 else 0.1
		else
			slot.countBadge.Visible = false
			slot.button.BackgroundTransparency = 0.6
		end
	end
	-- Drop the selection if the selected potion is no longer available.
	local State = self.C.State
	if State.selected and State.selected.kind == "potion" and State:PotionCount(State.selected.id) == 0 then
		State:Select(nil)
	end
	self:_highlight()
end

function Hotbar:_highlight()
	local selection = self.C.State.selected
	for _, slot in self.slots do
		local selected = selection ~= nil and selection.kind == "potion" and slot.potionId == selection.id
		slot.selected = selected
		slot.scale.Scale = if selected then 1.1 else 1
		if slot.potionId then
			local potion = Potions.ById[slot.potionId]
			slot.stroke.Color = if selected then Theme.Color.Accent.Gold else Theme.rarityColor(potion.rarity)
			slot.stroke.Thickness = if selected then 4 else Theme.Stroke.Emphasis
		end
		if slot.spin then
			slot.spin(selected)
		end
	end
	if selection and selection.kind ~= "potion" then
		local label
		if selection.kind == "golem" then
			label = "🗿 Placing: " .. Skins.get(selection.id).name
		else
			local prop = PropsData.ById[selection.id]
			label = (if prop then prop.icon .. " Placing: " .. prop.name else "Placing")
		end
		self.chipLabel.Text = label .. (if self.ui.touch then "  (tap)" else "  (right-click)")
		self.chip.Visible = true
	else
		self.chip.Visible = false
	end
end

function Hotbar:SelectIndex(index: number)
	local slot = self.slots[index]
	if slot and slot.potionId then
		local State = self.C.State
		if State.selected and State.selected.kind == "potion" and State.selected.id == slot.potionId then
			State:Select(nil)
		else
			State:Select({ kind = "potion", id = slot.potionId })
			self.C.SoundController:Play("click", nil, { ui = true })
		end
	end
end

function Hotbar:Cycle(direction: number)
	local list = self:_list()
	if #list == 0 then
		return
	end
	local State = self.C.State
	local current = 0
	if State.selected and State.selected.kind == "potion" then
		current = table.find(list, State.selected.id) or 0
	end
	local nextIndex = (current - 1 + direction) % #list + 1
	State:Select({ kind = "potion", id = list[nextIndex] })
	self.page = (nextIndex - 1) // SLOTS
	self:Refresh()
end

function Hotbar:Page(direction: number)
	self.page += direction
	self:Refresh()
end

return Hotbar
