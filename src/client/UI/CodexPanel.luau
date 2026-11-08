--!nonstrict
-- The Codex: every potion (silhouettes + hints until discovered), mastery progress, and reactions.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Ingredients = require(Shared.Data.Ingredients)
local Potions = require(Shared.Data.Potions)
local Reactions = require(Shared.Data.Reactions)

local Theme = require(script.Parent.Theme)
local C = require(script.Parent.Components)

local CodexPanel = {}

function CodexPanel:Mount(ui, controllers)
	self.ui, self.C = ui, controllers
	local modal = C.Modal({ parent = ui.modals, title = "📖 Alchemist's Codex", size = Vector2.new(1180, 700) })
	self.modal = modal
	modal.onClose = function()
		ui:PanelClosed("codex")
	end
	local body = modal.body
	self.tab = "potions"
	C.Tabs({
		parent = body,
		tabs = {
			{ id = "potions", label = "Potions", icon = "🧪" },
			{ id = "reactions", label = "Reactions", icon = "⚗️" },
		},
		onSelect = function(id)
			self.tab = id
			self:Refresh()
		end,
	})
	self.progress = C.Progress({
		parent = body,
		size = UDim2.fromOffset(420, 22),
		position = UDim2.new(1, 0, 0, 10),
		anchor = Vector2.new(1, 0),
		showLabel = true,
		color = Theme.Color.Accent.Magenta,
		color2 = Theme.Color.Accent.Gold,
	})
	self.grid = C.Scroll({ parent = body, size = UDim2.fromOffset(700, 540), position = UDim2.fromOffset(0, 60) })
	C.grid(self.grid, Vector2.new(128, 150), Theme.Space.SM)
	C.padding(self.grid, 4)

	local _, detail = C.card({
		parent = body,
		size = UDim2.fromOffset(400, 540),
		position = UDim2.fromOffset(730, 60),
		radius = Theme.Radius.LG,
	})
	self.detail = detail
	controllers.State.Changed:Connect(function(key)
		if modal.isOpen() and (key == "*" or key == "discovered" or key == "brewCount" or key == "reactions") then
			self:Refresh()
		end
	end)
end

function CodexPanel:_clearDetail()
	for _, child in self.detail:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

function CodexPanel:ShowPotion(potion)
	local data = self.C.State.data
	self:_clearDetail()
	local known = data.discovered[potion.id] ~= nil
	local color = Theme.rarityColor(potion.rarity)
	C.BottleIcon({
		parent = self.detail,
		potion = potion,
		silhouette = not known,
		size = UDim2.fromOffset(200, 200),
		position = UDim2.new(0.5, 0, 0, 10),
		anchor = Vector2.new(0.5, 0),
		spin = known,
	})
	C.text({
		parent = self.detail,
		text = if known then potion.name else "???",
		type = "Title",
		textSize = 32,
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 40),
		position = UDim2.fromOffset(0, 214),
		color = color,
	})
	local chip = C.frame({
		parent = self.detail,
		color = color,
		size = UDim2.fromOffset(130, 26),
		position = UDim2.new(0.5, 0, 0, 258),
		anchor = Vector2.new(0.5, 0),
		radius = Theme.Radius.Pill,
	})
	C.text({
		parent = chip,
		text = potion.rarity:upper(),
		type = "Caption",
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.fromScale(1, 1),
		color = Theme.Color.Text.Inverse,
		outline = false,
	})
	C.text({
		parent = self.detail,
		text = if known then potion.description else ("Hint: " .. potion.hint),
		type = "Body",
		textSize = 18,
		alignX = Enum.TextXAlignment.Center,
		wrap = true,
		size = UDim2.new(1, -40, 0, 80),
		position = UDim2.fromOffset(20, 294),
		color = Theme.Color.Text.Secondary,
	})
	if known and #potion.recipe > 0 then
		local parts = {}
		for _, id in potion.recipe do
			local ingredient = Ingredients.ById[id]
			table.insert(parts, ingredient.icon .. " " .. ingredient.name)
		end
		C.text({
			parent = self.detail,
			text = table.concat(parts, "  +  "),
			type = "Label",
			alignX = Enum.TextXAlignment.Center,
			wrap = true,
			size = UDim2.new(1, -30, 0, 50),
			position = UDim2.fromOffset(15, 380),
		})
		local brews = data.brewCount[potion.id] or 0
		local mastery = Config.Potions.MasteryBrews
		local bar = C.Progress({
			parent = self.detail,
			size = UDim2.new(1, -60, 0, 18),
			position = UDim2.fromOffset(30, 446),
			showLabel = true,
		})
		bar.set(
			math.min(brews / mastery, 1),
			if brews >= mastery
				then "⭐ MASTERED: infinite bottles"
				else ("Mastery %d / %d brews"):format(brews, mastery),
			true
		)
		C.text({
			parent = self.detail,
			text = ("Bottles: %s   ·   Throw radius: %d"):format(
				if brews >= mastery then "∞" else tostring(data.potions[potion.id] or 0),
				potion.radius
			),
			type = "Caption",
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 24),
			position = UDim2.fromOffset(0, 476),
			color = Theme.Color.Text.Muted,
		})
	elseif not known and potion.id == Potions.FinalId then
		C.text({
			parent = self.detail,
			text = "Needs the Philosopher's Stone from the final trial: the Magnum Opus.",
			type = "Label",
			alignX = Enum.TextXAlignment.Center,
			wrap = true,
			size = UDim2.new(1, -30, 0, 60),
			position = UDim2.fromOffset(15, 390),
			color = Theme.Color.Rarity.Mythic,
		})
	end
end

function CodexPanel:Refresh()
	local data = self.C.State.data
	if not data then
		return
	end
	for _, child in self.grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if self.tab == "potions" then
		local discovered, total = 0, 0
		local first
		for _, potion in Potions.List do
			total += 1
			local known = data.discovered[potion.id] ~= nil
			if known then
				discovered += 1
			end
			local card = C.new("TextButton", {
				AutoButtonColor = false,
				Text = "",
				BackgroundColor3 = Theme.Color.Surface.Raised,
				LayoutOrder = potion.order,
				Parent = self.grid,
			})
			C.corner(card, Theme.Radius.MD)
			C.stroke(
				card,
				if known then Theme.rarityColor(potion.rarity) else Theme.Color.Stroke.Subtle,
				Theme.Stroke.Default
			)
			C.gradient(card, Theme.Color.Surface.Raised, Theme.Color.Surface.Sunken)
			C.BottleIcon({
				parent = card,
				potion = potion,
				silhouette = not known,
				size = UDim2.fromOffset(96, 96),
				position = UDim2.new(0.5, 0, 0, 6),
				anchor = Vector2.new(0.5, 0),
			})
			C.text({
				parent = card,
				text = if known then potion.name else "???",
				type = "Caption",
				alignX = Enum.TextXAlignment.Center,
				wrap = true,
				size = UDim2.new(1, -8, 0, 40),
				position = UDim2.fromOffset(4, 104),
				color = if known then Theme.Color.Text.Primary else Theme.Color.Text.Muted,
			})
			if self.C.State:IsMastered(potion.id) then
				C.text({
					parent = card,
					text = "⭐",
					type = "Label",
					size = UDim2.fromOffset(24, 24),
					position = UDim2.fromOffset(6, 4),
					outline = false,
				})
			end
			C.interactive(card)
			card.Activated:Connect(function()
				C.sound("click")
				self:ShowPotion(potion)
			end)
			first = first or potion
		end
		self.progress.set(discovered / total, ("%d / %d potions discovered"):format(discovered, total))
		if first then
			self:ShowPotion(first)
		end
	else
		local found, total = 0, #Reactions.List
		self:_clearDetail()
		C.text({
			parent = self.detail,
			text = "Reactions happen when effects collide. Discover them all for bonus XP!",
			type = "Body",
			wrap = true,
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.new(1, -40, 0, 120),
			position = UDim2.fromOffset(20, 30),
			color = Theme.Color.Text.Secondary,
		})
		for index, reaction in Reactions.List do
			local known = data.reactions[reaction.id] == true
			if known then
				found += 1
			end
			local card = C.frame({
				parent = self.grid,
				color = Theme.Color.Surface.Raised,
				order = index,
				stroke = if known then reaction.color else Theme.Color.Stroke.Subtle,
			})
			C.text({
				parent = card,
				text = if known then reaction.icon else "❔",
				type = "Title",
				textSize = 46,
				alignX = Enum.TextXAlignment.Center,
				size = UDim2.new(1, 0, 0, 70),
				position = UDim2.fromOffset(0, 8),
				outline = false,
			})
			C.text({
				parent = card,
				text = if known then reaction.name else "???",
				type = "Caption",
				alignX = Enum.TextXAlignment.Center,
				size = UDim2.new(1, -8, 0, 24),
				position = UDim2.fromOffset(4, 80),
				color = if known then reaction.color else Theme.Color.Text.Muted,
			})
			C.text({
				parent = card,
				text = if known then reaction.description else "",
				type = "Caption",
				textSize = 11,
				alignX = Enum.TextXAlignment.Center,
				wrap = true,
				size = UDim2.new(1, -8, 0, 44),
				position = UDim2.fromOffset(4, 102),
				color = Theme.Color.Text.Secondary,
				outline = false,
			})
		end
		self.progress.set(found / total, ("%d / %d reactions found"):format(found, total))
	end
end

function CodexPanel:Open()
	self:Refresh()
	self.modal.open()
end

function CodexPanel:Close()
	self.modal.close()
end

return CodexPanel
