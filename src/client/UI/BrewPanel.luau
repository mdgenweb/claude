--!nonstrict
-- The cauldron: pick 2-3 ingredients, watch the brew colour mix, BREW, and get the result.
-- Known recipes on the right refill the cauldron in one click.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Ingredients = require(Shared.Data.Ingredients)
local Potions = require(Shared.Data.Potions)
local Recipes = require(Shared.Data.Recipes)

local Theme = require(script.Parent.Theme)
local C = require(script.Parent.Components)

local BrewPanel = {}

function BrewPanel:Mount(ui, controllers)
	self.ui, self.C = ui, controllers
	self.selected = {}
	local modal = C.Modal({ parent = ui.modals, title = "🧪 Cauldron", size = Vector2.new(1180, 700) })
	self.modal = modal
	modal.onClose = function()
		ui:PanelClosed("brew")
	end
	local body = modal.body

	-- Left: ingredient pouch.
	C.text({
		parent = body,
		text = "Ingredient Pouch",
		type = "Heading",
		size = UDim2.fromOffset(440, 30),
		color = Theme.Color.Text.Secondary,
	})
	local pouch = C.Scroll({ parent = body, size = UDim2.fromOffset(450, 540), position = UDim2.fromOffset(0, 40) })
	C.grid(pouch, Vector2.new(140, 132), Theme.Space.SM)
	C.padding(pouch, 4)
	self.pouch = pouch
	self.cards = {}
	for _, ingredient in Ingredients.List do
		self.cards[ingredient.id] = self:_ingredientCard(pouch, ingredient)
	end

	-- Centre: cauldron with slots and brew button.
	local center = C.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(360, 580),
		Position = UDim2.fromOffset(470, 0),
		Parent = body,
	})
	local _, bowl = C.card({
		parent = center,
		size = UDim2.fromOffset(340, 300),
		position = UDim2.fromOffset(10, 10),
		radius = UDim.new(0.5, 0),
		stroke = Theme.Color.Stroke.Strong,
	})
	local liquid = C.frame({
		parent = bowl,
		color = Color3.fromRGB(110, 255, 140),
		size = UDim2.fromOffset(250, 120),
		position = UDim2.fromScale(0.5, 0.42),
		anchor = Vector2.new(0.5, 0.5),
		radius = UDim.new(0.5, 0),
	})
	local liquidGradient = C.gradient(liquid, Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150))
	local _ = liquidGradient
	self.liquid = liquid
	self.bubbles = {}
	for i = 1, 7 do
		local bubble = C.frame({
			parent = liquid,
			color = Color3.new(1, 1, 1),
			transparency = 0.5,
			size = UDim2.fromOffset(14, 14),
			position = UDim2.fromScale(0.15 + i * 0.1, 0.6),
			anchor = Vector2.new(0.5, 0.5),
			radius = UDim.new(0.5, 0),
		})
		table.insert(self.bubbles, { frame = bubble, phase = i * 0.7 })
	end
	game:GetService("RunService").RenderStepped:Connect(function()
		if not modal.isOpen() then
			return
		end
		local t = os.clock()
		for _, b in self.bubbles do
			local y = 0.75 - ((t * 0.6 + b.phase) % 1) * 0.6
			b.frame.Position = UDim2.fromScale(b.frame.Position.X.Scale, y)
			b.frame.BackgroundTransparency = 0.3 + (1 - y) * 0.6
		end
	end)
	-- Ingredient slots.
	local slots = C.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(340, 90),
		Position = UDim2.fromOffset(10, 320),
		Parent = center,
	})
	C.list(slots, Enum.FillDirection.Horizontal, Theme.Space.MD, Enum.HorizontalAlignment.Center)
	self.slotButtons = {}
	for i = 1, 3 do
		local slot = C.new("TextButton", {
			Name = "Slot" .. i,
			AutoButtonColor = false,
			Text = "",
			BackgroundColor3 = Theme.Color.Surface.Sunken,
			Size = UDim2.fromOffset(90, 90),
			LayoutOrder = i,
			Parent = slots,
		})
		C.corner(slot, UDim.new(0.5, 0))
		local stroke = C.stroke(slot, Theme.Color.Stroke.Subtle, Theme.Stroke.Emphasis)
		local icon = C.text({
			parent = slot,
			text = "+",
			type = "Title",
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.fromScale(1, 1),
			color = Theme.Color.Text.Muted,
			outline = false,
		})
		C.interactive(slot)
		slot.Activated:Connect(function()
			if self.selected[i] then
				table.remove(self.selected, i)
				C.sound("click")
				self:Refresh()
			end
		end)
		self.slotButtons[i] = { button = slot, icon = icon, stroke = stroke }
	end
	self.mixLabel = C.text({
		parent = center,
		text = "Add 2 or 3 ingredients",
		type = "Label",
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 26),
		position = UDim2.fromOffset(0, 420),
		color = Theme.Color.Text.Secondary,
		wrap = true,
	})
	self.brewButton = C.Button({
		parent = center,
		text = "BREW!",
		icon = "✨",
		variant = "primary",
		size = "lg",
		width = 300,
		position = UDim2.fromOffset(30, 456),
		keybind = "Enter",
		onClick = function()
			self:Brew()
		end,
	})
	self.clearButton = C.Button({
		parent = center,
		text = "Empty cauldron",
		variant = "ghost",
		size = "sm",
		width = 200,
		position = UDim2.fromOffset(80, 530),
		onClick = function()
			table.clear(self.selected)
			self:Refresh()
		end,
	})
	self.resultLabel = C.text({
		parent = center,
		text = "",
		type = "Label",
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 40),
		position = UDim2.fromOffset(0, 566),
		wrap = true,
		color = Theme.Color.Accent.Gold,
	})

	-- Right: recipe book.
	C.text({
		parent = body,
		text = "Recipe Book",
		type = "Heading",
		size = UDim2.fromOffset(280, 30),
		position = UDim2.fromOffset(850, 0),
		color = Theme.Color.Text.Secondary,
	})
	local book = C.Scroll({ parent = body, size = UDim2.fromOffset(280, 500), position = UDim2.fromOffset(850, 40) })
	C.list(book, Enum.FillDirection.Vertical, Theme.Space.SM)
	C.padding(book, 4)
	self.book = book
	C.Button({
		parent = body,
		text = "Buy ingredients",
		icon = "🛒",
		size = "sm",
		width = 280,
		position = UDim2.fromOffset(850, 552),
		onClick = function()
			ui:Open("shop")
			local shop = ui.panels.shop
			if shop and shop.ShowTab then
				shop:ShowTab("ingredients")
			end
		end,
	})

	controllers.State.Changed:Connect(function(key)
		if key == "*" or key == "ingredients" or key == "discovered" or key == "level" then
			if modal.isOpen() then
				self:Refresh()
			end
		end
	end)
	game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
		if modal.isOpen() and not processed and input.KeyCode == Enum.KeyCode.Return then
			self:Brew()
		end
	end)
end

function BrewPanel:_ingredientCard(parent: Instance, ingredient)
	local button = C.new("TextButton", {
		Name = ingredient.id,
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = Theme.Color.Surface.Raised,
		LayoutOrder = ingredient.order,
		Parent = parent,
	})
	C.corner(button, Theme.Radius.MD)
	local stroke = C.stroke(button, Theme.rarityColor(ingredient.rarity), Theme.Stroke.Default)
	C.gradient(button, Theme.Color.Surface.Raised, Theme.Color.Surface.Sunken)
	C.text({
		parent = button,
		text = ingredient.icon,
		type = "Title",
		textSize = 44,
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 60),
		position = UDim2.fromOffset(0, 6),
		outline = false,
	})
	C.text({
		parent = button,
		text = ingredient.name,
		type = "Caption",
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.new(1, -8, 0, 34),
		position = UDim2.fromOffset(4, 66),
		wrap = true,
	})
	local count = C.text({
		parent = button,
		text = "x0",
		type = "Label",
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 24),
		position = UDim2.fromOffset(0, 102),
		color = Theme.Color.Accent.Gold,
	})
	local lock = C.text({
		parent = button,
		text = "",
		type = "Caption",
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 24),
		position = UDim2.fromOffset(0, 102),
		color = Theme.Color.Text.Muted,
		visible = false,
	})
	C.interactive(button)
	button.Activated:Connect(function()
		self:Add(ingredient.id)
	end)
	button.MouseEnter:Connect(function()
		C.showTooltip(
			ingredient.name .. "  ·  " .. ingredient.rarity,
			ingredient.description,
			Theme.rarityColor(ingredient.rarity)
		)
	end)
	button.MouseLeave:Connect(function()
		C.hideTooltip()
	end)
	return { button = button, count = count, lock = lock, stroke = stroke }
end

local function blend(ids: { string }): Color3
	if #ids == 0 then
		return Color3.fromRGB(110, 255, 140)
	end
	local r, g, b = 0, 0, 0
	for _, id in ids do
		local color = Ingredients.ById[id].color
		r += color.R
		g += color.G
		b += color.B
	end
	return Color3.new(r / #ids, g / #ids, b / #ids)
end

function BrewPanel:Add(id: string)
	local data = self.C.State.data
	if not data then
		return
	end
	if #self.selected >= 3 then
		self.ui:Toast("The cauldron holds 3 ingredients max.", "info")
		return
	end
	local need = Recipes.requirements(self.selected)
	if (data.ingredients[id] or 0) <= (need[id] or 0) then
		C.sound("error")
		self.ui:Toast("Not enough " .. Ingredients.ById[id].name .. ". Buy more in the shop!", "error")
		return
	end
	table.insert(self.selected, id)
	C.sound("click")
	self.C.SoundController:Play("bubble", nil, { ui = true, pitch = 1 + #self.selected * 0.15 })
	C.pulse(self.liquid, 1.08)
	self:Refresh()
end

function BrewPanel:Brew()
	if #self.selected < 2 or self.brewing then
		if #self.selected < 2 then
			self.ui:Toast("Add at least 2 ingredients.", "info")
		end
		return
	end
	self.brewing = true
	self.brewButton.setDisabled(true)
	self.brewButton.setText("Brewing...")
	self.C.SoundController:Play("brew", nil, { ui = true })
	-- Swirl animation while the server resolves the brew.
	for _ = 1, 3 do
		C.pulse(self.liquid, 1.15)
		task.wait(0.18)
	end
	local ids = table.clone(self.selected)
	local result = Net.func("Brew"):InvokeServer(ids)
	self.brewing = false
	self.brewButton.setDisabled(false)
	self.brewButton.setText("BREW!")
	if not result or not result.ok then
		self.ui:Toast(result and result.reason or "The brew fizzled.", "error")
		return
	end
	local potion = Potions.ById[result.potionId]
	self.liquid.BackgroundColor3 = potion.color
	if result.potionId == Potions.FallbackId then
		self.resultLabel.Text = "💩 Murky Sludge... " .. (if result.hint then "Hint: " .. result.hint else "")
		self.resultLabel.TextColor3 = Theme.Color.Text.Secondary
	else
		self.resultLabel.Text = ("Brewed %d× %s!%s"):format(
			result.bottles,
			potion.name,
			if result.mastered then "  ⭐ MASTERED (∞)" else ""
		)
		self.resultLabel.TextColor3 = Theme.rarityColor(potion.rarity)
	end
	-- Keep the same recipe ready if the player can afford it again.
	local data = self.C.State.data
	if data and not Recipes.canAfford(data.ingredients, ids) then
		table.clear(self.selected)
	end
	self:Refresh()
	-- Select the new potion for quick testing.
	if result.potionId ~= Potions.FallbackId then
		self.C.State:Select({ kind = "potion", id = result.potionId })
	end
	if result.discovered then
		self.ui:Close()
	end
end

function BrewPanel:Refresh()
	local data = self.C.State.data
	if not data then
		return
	end
	local need = Recipes.requirements(self.selected)
	for id, card in self.cards do
		local ingredient = Ingredients.ById[id]
		local owned = data.ingredients[id] or 0
		local left = owned - (need[id] or 0)
		local locked = ingredient.price > 0 and data.level < ingredient.unlockLevel and owned == 0
		card.count.Text = "x" .. left
		card.count.Visible = not locked
		card.lock.Visible = locked
		card.lock.Text = "🔒 Lv " .. ingredient.unlockLevel
		card.button.BackgroundTransparency = if left <= 0 then 0.55 else 0
		card.button.Visible = not (ingredient.price == 0 and owned == 0)
	end
	for i, slot in self.slotButtons do
		local id = self.selected[i]
		if id then
			local ingredient = Ingredients.ById[id]
			slot.icon.Text = ingredient.icon
			slot.icon.TextColor3 = Theme.Color.Text.Primary
			slot.stroke.Color = ingredient.color
		else
			slot.icon.Text = "+"
			slot.icon.TextColor3 = Theme.Color.Text.Muted
			slot.stroke.Color = Theme.Color.Stroke.Subtle
		end
	end
	C.tween(self.liquid, Theme.Motion.Count, { BackgroundColor3 = blend(self.selected) })
	if #self.selected >= 2 then
		local known = Recipes.resolve(self.C.PotionIndex, self.selected)
		if known and data.discovered[known] then
			self.mixLabel.Text = "Known recipe: " .. Potions.ById[known].name
		else
			self.mixLabel.Text = "Unknown mix... what will happen?"
		end
	else
		self.mixLabel.Text = "Add 2 or 3 ingredients"
	end
	self.brewButton.setDisabled(#self.selected < 2)

	-- Recipe book.
	for _, child in self.book:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local count = 0
	for _, potion in Potions.List do
		if data.discovered[potion.id] and #potion.recipe >= 2 then
			count += 1
			local affordable = Recipes.canAfford(data.ingredients, potion.recipe)
			local icons = {}
			for _, id in potion.recipe do
				table.insert(icons, Ingredients.ById[id].icon)
			end
			local row = C.new("TextButton", {
				AutoButtonColor = false,
				Text = "",
				BackgroundColor3 = Theme.Color.Surface.Raised,
				BackgroundTransparency = if affordable then 0 else 0.5,
				Size = UDim2.new(1, -8, 0, 64),
				LayoutOrder = potion.order,
				Parent = self.book,
			})
			C.corner(row, Theme.Radius.MD)
			C.stroke(row, Theme.rarityColor(potion.rarity), 1)
			C.BottleIcon({
				parent = row,
				potion = potion,
				size = UDim2.fromOffset(56, 56),
				position = UDim2.fromOffset(4, 4),
			})
			C.text({
				parent = row,
				text = potion.name,
				type = "Caption",
				size = UDim2.new(1, -70, 0, 26),
				position = UDim2.fromOffset(64, 6),
				color = Theme.rarityColor(potion.rarity),
				truncate = true,
			})
			C.text({
				parent = row,
				text = table.concat(icons, " + ") .. (if self.C.State:IsMastered(potion.id) then "   ⭐" else ""),
				type = "Label",
				size = UDim2.new(1, -70, 0, 26),
				position = UDim2.fromOffset(64, 32),
				outline = false,
			})
			C.interactive(row)
			row.Activated:Connect(function()
				if not affordable then
					C.sound("error")
					self.ui:Toast("Missing ingredients for " .. potion.name, "error")
					return
				end
				C.sound("click")
				self.selected = table.clone(potion.recipe)
				self:Refresh()
			end)
		end
	end
	if count == 0 then
		C.text({
			parent = self.book,
			text = "Discovered recipes show up here. Try mixing two of the same ingredient first!",
			type = "Caption",
			wrap = true,
			size = UDim2.new(1, -8, 0, 80),
			color = Theme.Color.Text.Muted,
		})
	end
end

function BrewPanel:Open()
	self.resultLabel.Text = ""
	self:Refresh()
	self.modal.open()
end

function BrewPanel:Close()
	self.modal.close()
end

return BrewPanel
