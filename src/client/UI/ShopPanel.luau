--!nonstrict
-- Shop: ingredients, golem skins (3D previews), Mystery Flask spins (animated reel), Robux passes
-- and products, and code redemption.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)
local Ingredients = require(Shared.Data.Ingredients)
local Net = require(Shared.Net)
local Skins = require(Shared.Data.Skins)
local Spins = require(Shared.Data.Spins)
local GolemPreview = require(Shared.Visual.GolemPreview)

local Theme = require(script.Parent.Theme)
local C = require(script.Parent.Components)

local ShopPanel = {}

local PASSES = {
	{
		key = "VIP",
		icon = "👑",
		name = "VIP",
		body = "2x coins & XP, the Gold Golem skin and a golden name.",
		robux = 249,
	},
	{
		key = "Satchel",
		icon = "🎒",
		name = "Alchemist's Satchel",
		body = "+2 bottles every time you brew.",
		robux = 299,
	},
	{
		key = "LabExpansion",
		icon = "🏗️",
		name = "Lab Expansion",
		body = "Up to 12 golems in your lab at once.",
		robux = 199,
	},
	{ key = "MasterKey", icon = "🗝️", name = "Master Key", body = "Unlock every lab map right now.", robux = 399 },
}

local SOURCE_TEXT = {
	level = function(skin)
		return "Reach level " .. tostring(skin.level)
	end,
	spin = function()
		return "From Mystery Flasks"
	end,
	code = function()
		return "Code reward"
	end,
	vip = function()
		return "VIP pass"
	end,
	trial = function()
		return "Brew the Philosopher's Elixir"
	end,
}

local function invoke(...)
	local ok, result = pcall(function(...)
		return Net.func("Shop"):InvokeServer(...)
	end, ...)
	if ok then
		return result
	end
	return { ok = false, reason = "Connection hiccup, try again." }
end

function ShopPanel:Mount(ui, controllers)
	self.ui, self.C = ui, controllers
	local modal = C.Modal({ parent = ui.modals, title = "🛒 Alchemy Shop", size = Vector2.new(1180, 700) })
	self.modal = modal
	modal.onClose = function()
		ui:PanelClosed("shop")
	end
	self.tab = "ingredients"
	self.tabs = C.Tabs({
		parent = modal.body,
		tabs = {
			{ id = "ingredients", label = "Ingredients", icon = "🌿", width = 190 },
			{ id = "golems", label = "Golems", icon = "🗿", width = 160 },
			{ id = "flasks", label = "Flasks", icon = "🎁", width = 150 },
			{ id = "robux", label = "Robux", icon = "💎", width = 150 },
			{ id = "codes", label = "Codes", icon = "🏷️", width = 150 },
		},
		onSelect = function(id)
			self.tab = id
			self:Refresh()
		end,
	})
	self.coins = C.text({
		parent = modal.body,
		text = "",
		type = "Heading",
		alignX = Enum.TextXAlignment.Right,
		size = UDim2.fromOffset(260, 40),
		position = UDim2.new(1, 0, 0, 2),
		anchor = Vector2.new(1, 0),
		color = Theme.Color.Accent.Gold,
	})
	self.content = C.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -60),
		Position = UDim2.fromOffset(0, 60),
		Parent = modal.body,
	})
	controllers.State.Changed:Connect(function(key)
		if not modal.isOpen() then
			return
		end
		if key == "coins" or key == "*" then
			self.coins.Text = "🪙 " .. Format.commas(controllers.State.data.coins)
		end
		if
			not self.spinning
			and (key == "skins" or key == "equippedSkin" or key == "ingredients" or key == "spins" or key == "*")
		then
			self:Refresh()
		end
	end)
	controllers.State.Changed:Connect(function(key)
		if key == "passes" and modal.isOpen() and self.tab == "robux" then
			self:Refresh()
		end
	end)
end

function ShopPanel:ShowTab(id: string)
	self.tabs.select(id)
end

function ShopPanel:_clear()
	for _, child in self.content:GetChildren() do
		child:Destroy()
	end
end

function ShopPanel:_ingredients(data)
	local scroll = C.Scroll({ parent = self.content })
	C.grid(scroll, Vector2.new(214, 196), Theme.Space.MD)
	C.padding(scroll, 4)
	for _, ingredient in Ingredients.List do
		if ingredient.price <= 0 then
			continue
		end
		local locked = data.level < ingredient.unlockLevel
		local _, card = C.card({
			parent = scroll,
			order = ingredient.order,
			radius = Theme.Radius.LG,
			stroke = Theme.rarityColor(ingredient.rarity),
		})
		C.text({
			parent = card,
			text = ingredient.icon,
			type = "Title",
			textSize = 46,
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 58),
			position = UDim2.fromOffset(0, 8),
			outline = false,
		})
		C.text({
			parent = card,
			text = ingredient.name,
			type = "Label",
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 24),
			position = UDim2.fromOffset(0, 68),
		})
		C.text({
			parent = card,
			text = ("%s · owned %d"):format(ingredient.rarity, data.ingredients[ingredient.id] or 0),
			type = "Caption",
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 20),
			position = UDim2.fromOffset(0, 92),
			color = Theme.rarityColor(ingredient.rarity),
		})
		if locked then
			C.text({
				parent = card,
				text = "🔒 Unlocks at level " .. ingredient.unlockLevel,
				type = "Caption",
				alignX = Enum.TextXAlignment.Center,
				size = UDim2.new(1, 0, 0, 40),
				position = UDim2.fromOffset(0, 130),
				color = Theme.Color.Text.Muted,
			})
		else
			for i, qty in { 1, 5 } do
				local cost = ingredient.price * qty
				local button = C.Button({
					parent = card,
					text = ("x%d  %s"):format(qty, Format.short(cost)),
					icon = "🪙",
					size = "sm",
					width = 94,
					variant = if i == 2 then "primary" else "secondary",
					position = UDim2.new(if i == 1 then 0.27 else 0.73, 0, 1, -12),
					anchor = Vector2.new(0.5, 1),
					onClick = function()
						local result = invoke("buyIngredient", ingredient.id, qty)
						if result.ok then
							self.C.SoundController:Play("coin", nil, { ui = true })
						else
							self.ui:Toast(result.reason or "Can't buy that", "error")
						end
					end,
				})
				button.setDisabled(data.coins < cost)
			end
		end
	end
end

function ShopPanel:_golems(data)
	local scroll = C.Scroll({ parent = self.content })
	C.grid(scroll, Vector2.new(214, 290), Theme.Space.MD)
	C.padding(scroll, 4)
	for _, skin in Skins.List do
		local owned = data.skins[skin.id] == true
		local equipped = data.equippedSkin == skin.id
		local _, card = C.card({
			parent = scroll,
			order = skin.order,
			radius = Theme.Radius.LG,
			stroke = if equipped then Theme.Color.Stroke.Gold else Theme.rarityColor(skin.rarity),
		})
		local _, spin = C.Viewport({
			parent = card,
			model = GolemPreview.build(skin),
			size = UDim2.new(1, -16, 0, 160),
			position = UDim2.fromOffset(8, 8),
			zoom = 0.95,
			spinSpeed = 1,
		})
		card.MouseEnter:Connect(function()
			spin(true)
		end)
		card.MouseLeave:Connect(function()
			spin(false)
		end)
		C.text({
			parent = card,
			text = skin.name,
			type = "Label",
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 24),
			position = UDim2.fromOffset(0, 170),
		})
		local traits = {}
		for trait in skin.traits do
			table.insert(traits, trait)
		end
		C.text({
			parent = card,
			text = skin.rarity .. (if #traits > 0 then " · " .. table.concat(traits, ", ") else ""),
			type = "Caption",
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.new(1, -8, 0, 20),
			position = UDim2.fromOffset(4, 194),
			color = Theme.rarityColor(skin.rarity),
			truncate = true,
		})
		local label, variant, action
		if equipped then
			label, variant = "Equipped ✓", "ghost"
		elseif owned then
			label, variant, action = "Equip", "secondary", "equipSkin"
		elseif skin.source == "shop" and skin.price then
			label, variant, action = "🪙 " .. Format.commas(skin.price), "primary", "buySkin"
		else
			local describe = SOURCE_TEXT[skin.source]
			label, variant = if describe then describe(skin) else "Locked", "ghost"
		end
		local button = C.Button({
			parent = card,
			text = label,
			size = "sm",
			width = 190,
			variant = variant,
			position = UDim2.new(0.5, 0, 1, -12),
			anchor = Vector2.new(0.5, 1),
			onClick = function()
				if not action then
					return
				end
				local result = invoke(action, skin.id)
				if result.ok then
					self.C.SoundController:Play(if action == "buySkin" then "reward" else "click", nil, { ui = true })
					if action == "buySkin" then
						self.ui:Toast("New golem: " .. skin.name .. "! Spawn it from World > Spawn.", "reward")
					end
				else
					self.ui:Toast(result.reason or "Can't do that", "error")
				end
			end,
		})
		if action == "buySkin" then
			button.setDisabled(data.coins < (skin.price or 0))
		end
		if spin then
			spin(false)
		end
	end
end

function ShopPanel:_flasks(data)
	local holder = self.content
	C.text({
		parent = holder,
		text = "🎁",
		type = "Display",
		textSize = 110,
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 130),
		position = UDim2.fromOffset(0, 0),
		outline = false,
	})
	C.text({
		parent = holder,
		text = ("You have %d Mystery Flask%s"):format(data.spins, if data.spins == 1 then "" else "s"),
		type = "Heading",
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 34),
		position = UDim2.fromOffset(0, 130),
	})
	C.text({
		parent = holder,
		text = "Earn them from daily quests, level ups, login streaks and codes.",
		type = "Caption",
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 22),
		position = UDim2.fromOffset(0, 164),
		color = Theme.Color.Text.Secondary,
	})
	-- Reel.
	local window = C.frame({
		parent = holder,
		color = Theme.Color.Surface.Sunken,
		size = UDim2.new(1, -40, 0, 150),
		position = UDim2.fromOffset(20, 200),
		radius = Theme.Radius.LG,
		stroke = Theme.Color.Stroke.Strong,
		clip = true,
	})
	local reel = C.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 130),
		Position = UDim2.fromOffset(0, 10),
		Parent = window,
	})
	local cellWidth, gap = 130, 10
	local cells = 50
	local entries = {}
	for i = 1, cells do
		local entry = Spins.List[(i - 1) % #Spins.List + 1]
		entries[i] = entry
	end
	local function buildCell(i: number, entry)
		local cell = C.frame({
			parent = reel,
			color = Theme.Color.Surface.Raised,
			size = UDim2.fromOffset(cellWidth, 130),
			position = UDim2.fromOffset((i - 1) * (cellWidth + gap), 0),
			radius = Theme.Radius.MD,
			stroke = Theme.rarityColor(entry.tier),
			strokeThickness = 3,
		})
		C.text({
			parent = cell,
			text = entry.icon,
			type = "Title",
			textSize = 50,
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 70),
			position = UDim2.fromOffset(0, 8),
			outline = false,
		})
		C.text({
			parent = cell,
			text = entry.label,
			type = "Caption",
			alignX = Enum.TextXAlignment.Center,
			wrap = true,
			size = UDim2.new(1, -8, 0, 44),
			position = UDim2.fromOffset(4, 78),
		})
		return cell
	end
	for i, entry in entries do
		buildCell(i, entry)
	end
	local marker = C.frame({
		parent = window,
		color = Theme.Color.Accent.Gold,
		size = UDim2.new(0, 4, 1, 0),
		position = UDim2.fromScale(0.5, 0),
		anchor = Vector2.new(0.5, 0),
		radius = false,
	})
	local _ = marker
	local resultLabel = C.text({
		parent = holder,
		text = "",
		type = "Heading",
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 36),
		position = UDim2.fromOffset(0, 362),
		color = Theme.Color.Accent.Gold,
	})
	local spinButton
	spinButton = C.Button({
		parent = holder,
		text = "Open a Mystery Flask",
		icon = "✨",
		variant = "primary",
		size = "lg",
		width = 380,
		position = UDim2.new(0.5, 0, 0, 410),
		anchor = Vector2.new(0.5, 0),
		onClick = function()
			if self.spinning then
				return
			end
			self.spinning = true
			spinButton.setDisabled(true)
			resultLabel.Text = ""
			local result = invoke("spin")
			if not result.ok then
				self.spinning = false
				spinButton.setDisabled(false)
				self.ui:Toast(result.reason or "No flasks", "error")
				return
			end
			-- Land on a cell showing the won prize, far enough along the reel.
			local landing = 38 + (result.index - 1) % #Spins.List
			while entries[landing] ~= Spins.List[result.index] do
				landing += 1
			end
			local windowWidth = window.AbsoluteSize.X
				/ math.max(self.ui.modals:FindFirstChildOfClass("UIScale").Scale, 0.01)
			local targetX = -((landing - 1) * (cellWidth + gap) + cellWidth / 2 - windowWidth / 2)
				+ math.random(-40, 40)
			reel.Position = UDim2.fromOffset(0, 10)
			local tween = TweenService:Create(
				reel,
				TweenInfo.new(4.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
				{ Position = UDim2.fromOffset(targetX, 10) }
			)
			tween:Play()
			task.spawn(function()
				local last = 0
				while tween.PlaybackState == Enum.PlaybackState.Playing do
					local index = math.floor(-reel.Position.X.Offset / (cellWidth + gap))
					if index ~= last then
						last = index
						self.C.SoundController:Play("hover", nil, { ui = true, pitch = 1.2 })
					end
					task.wait()
				end
			end)
			tween.Completed:Wait()
			local prize = result.prize
			resultLabel.Text = ("You got: %s %s%s"):format(
				prize.icon,
				prize.label,
				if prize.duplicate then " (duplicate → +500 🪙)" else ""
			)
			resultLabel.TextColor3 = Theme.rarityColor(Spins.List[result.index].tier)
			self.C.SoundController:Play("discover", nil, { ui = true })
			self.spinning = false
			spinButton.setDisabled((self.C.State.data.spins or 0) <= 0)
		end,
	})
	spinButton.setDisabled(data.spins <= 0)
	local productId = 0
	for _, entry in Config.ProductCatalog do
		if entry.spins and entry.productId ~= 0 then
			productId = entry.productId
		end
	end
	if productId ~= 0 then
		C.Button({
			parent = holder,
			text = "Get 5 more",
			icon = "💎",
			size = "md",
			width = 240,
			position = UDim2.new(0.5, 0, 0, 488),
			anchor = Vector2.new(0.5, 0),
			onClick = function()
				MarketplaceService:PromptProductPurchase(Players.LocalPlayer, productId)
			end,
		})
	end
end

function ShopPanel:_robux()
	local scroll = C.Scroll({ parent = self.content })
	C.grid(scroll, Vector2.new(268, 270), Theme.Space.MD)
	C.padding(scroll, 4)
	local State = self.C.State
	for index, pass in PASSES do
		local id = Config.GamePasses[pass.key] or 0
		local owned = State.passes[pass.key] == true
		local _, card =
			C.card({ parent = scroll, order = index, radius = Theme.Radius.LG, stroke = Theme.Color.Stroke.Gold })
		C.text({
			parent = card,
			text = pass.icon,
			type = "Display",
			textSize = 60,
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 80),
			position = UDim2.fromOffset(0, 10),
			outline = false,
		})
		C.text({
			parent = card,
			text = pass.name,
			type = "Heading",
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 30),
			position = UDim2.fromOffset(0, 92),
			color = Theme.Color.Accent.Gold,
		})
		C.text({
			parent = card,
			text = pass.body,
			type = "Caption",
			alignX = Enum.TextXAlignment.Center,
			wrap = true,
			size = UDim2.new(1, -24, 0, 60),
			position = UDim2.fromOffset(12, 126),
			color = Theme.Color.Text.Secondary,
		})
		local button = C.Button({
			parent = card,
			text = if owned then "Owned ✓" elseif id == 0 then "Coming soon" else ("R$ %d"):format(pass.robux),
			variant = if owned or id == 0 then "ghost" else "primary",
			size = "md",
			width = 220,
			position = UDim2.new(0.5, 0, 1, -14),
			anchor = Vector2.new(0.5, 1),
			onClick = function()
				if id ~= 0 and not owned then
					MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, id)
				end
			end,
		})
		button.setDisabled(id == 0)
	end
	for index, product in Config.ProductCatalog do
		local _, card = C.card({
			parent = scroll,
			order = 10 + index,
			radius = Theme.Radius.LG,
			stroke = Theme.Color.Stroke.Strong,
		})
		C.text({
			parent = card,
			text = if product.spins then "🎁" else "🪙",
			type = "Display",
			textSize = 60,
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 80),
			position = UDim2.fromOffset(0, 10),
			outline = false,
		})
		C.text({
			parent = card,
			text = product.name,
			type = "Heading",
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 30),
			position = UDim2.fromOffset(0, 92),
		})
		C.text({
			parent = card,
			text = if product.spins
				then (product.spins .. " Mystery Flasks")
				else (Format.commas(product.coins or 0) .. " coins"),
			type = "Caption",
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 30),
			position = UDim2.fromOffset(0, 126),
			color = Theme.Color.Text.Secondary,
		})
		local button = C.Button({
			parent = card,
			text = if product.productId == 0 then "Coming soon" else ("R$ %d"):format(product.robux),
			variant = if product.productId == 0 then "ghost" else "primary",
			size = "md",
			width = 220,
			position = UDim2.new(0.5, 0, 1, -14),
			anchor = Vector2.new(0.5, 1),
			onClick = function()
				if product.productId ~= 0 then
					MarketplaceService:PromptProductPurchase(Players.LocalPlayer, product.productId)
				end
			end,
		})
		button.setDisabled(product.productId == 0)
	end
end

function ShopPanel:_codes()
	local holder = self.content
	C.text({
		parent = holder,
		text = "🏷️ Redeem a code",
		type = "Title",
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 50),
		position = UDim2.fromOffset(0, 40),
		color = Theme.Color.Accent.Gold,
	})
	C.text({
		parent = holder,
		text = "New codes drop when the game hits like & visit milestones. Check the game description!",
		type = "Body",
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 30),
		position = UDim2.fromOffset(0, 96),
		color = Theme.Color.Text.Secondary,
	})
	local box = C.new("TextBox", {
		PlaceholderText = "ENTER CODE",
		Text = "",
		ClearTextOnFocus = false,
		FontFace = Theme.Font.Title,
		TextSize = 34,
		TextColor3 = Theme.Color.Text.Primary,
		PlaceholderColor3 = Theme.Color.Text.Muted,
		BackgroundColor3 = Theme.Color.Surface.Sunken,
		Size = UDim2.fromOffset(520, 72),
		Position = UDim2.new(0.5, 0, 0, 160),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = holder,
	})
	C.corner(box, Theme.Radius.LG)
	C.stroke(box, Theme.Color.Stroke.Gold, Theme.Stroke.Emphasis)
	local status = C.text({
		parent = holder,
		text = "",
		type = "Heading",
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 36),
		position = UDim2.fromOffset(0, 330),
	})
	local function redeem()
		local code = box.Text
		if #code < 2 then
			return
		end
		local result = invoke("redeemCode", code)
		if result.ok then
			status.Text = "✅ Code redeemed! Enjoy your rewards."
			status.TextColor3 = Theme.Color.State.Success
			box.Text = ""
			self.C.SoundController:Play("reward", nil, { ui = true })
		else
			status.Text = "❌ " .. (result.reason or "Invalid code")
			status.TextColor3 = Theme.Color.State.Danger
			self.C.SoundController:Play("error", nil, { ui = true })
		end
	end
	box.FocusLost:Connect(function(enter)
		if enter then
			redeem()
		end
	end)
	C.Button({
		parent = holder,
		text = "Redeem",
		icon = "🎉",
		variant = "primary",
		size = "lg",
		width = 260,
		position = UDim2.new(0.5, 0, 0, 252),
		anchor = Vector2.new(0.5, 0),
		onClick = redeem,
	})
end

function ShopPanel:Refresh()
	local data = self.C.State.data
	if not data then
		return
	end
	self.coins.Text = "🪙 " .. Format.commas(data.coins)
	self:_clear()
	if self.tab == "ingredients" then
		self:_ingredients(data)
	elseif self.tab == "golems" then
		self:_golems(data)
	elseif self.tab == "flasks" then
		self:_flasks(data)
	elseif self.tab == "robux" then
		self:_robux()
	else
		self:_codes()
	end
end

function ShopPanel:Open()
	self:Refresh()
	self.modal.open()
end

function ShopPanel:Close()
	self.modal.close()
end

return ShopPanel
