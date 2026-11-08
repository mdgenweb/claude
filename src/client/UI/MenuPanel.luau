--!nonstrict
-- World menu: switch labs (maps), spawn golems & items, visit other players' labs, settings.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Maps = require(Shared.Data.Maps)
local PropsData = require(Shared.Data.Props)
local Skins = require(Shared.Data.Skins)
local GolemPreview = require(Shared.Visual.GolemPreview)

local Theme = require(script.Parent.Theme)
local C = require(script.Parent.Components)

local MenuPanel = {}

function MenuPanel:Mount(ui, controllers)
	self.ui, self.C = ui, controllers
	local modal = C.Modal({ parent = ui.modals, title = "🗺️ World", size = Vector2.new(1180, 700) })
	self.modal = modal
	modal.onClose = function()
		ui:PanelClosed("menu")
	end
	self.tab = "maps"
	self.tabs = C.Tabs({
		parent = modal.body,
		tabs = {
			{ id = "maps", label = "Labs", icon = "🏰" },
			{ id = "spawn", label = "Spawn", icon = "🗿" },
			{ id = "visit", label = "Visit", icon = "🚪" },
			{ id = "settings", label = "Settings", icon = "⚙️" },
		},
		onSelect = function(id)
			self.tab = id
			self:Refresh()
		end,
	})
	self.content = C.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -60),
		Position = UDim2.fromOffset(0, 60),
		Parent = modal.body,
	})
	controllers.State.LabChanged:Connect(function()
		if modal.isOpen() and (self.tab == "maps" or self.tab == "visit") then
			self:Refresh()
		end
	end)
end

function MenuPanel:ShowTab(id: string)
	self.tabs.select(id)
end

function MenuPanel:_clear()
	for _, child in self.content:GetChildren() do
		child:Destroy()
	end
end

function MenuPanel:_maps(data, lab)
	local scroll = C.Scroll({ parent = self.content })
	C.grid(scroll, Vector2.new(270, 250), Theme.Space.MD)
	C.padding(scroll, 4)
	for _, map in Maps.List do
		local unlocked = data.level >= map.unlockLevel or data.maps[map.id] or self.C.State.passes.MasterKey
		local current = lab and lab.mapId == map.id
		local _, card = C.card({
			parent = scroll,
			order = map.order,
			radius = Theme.Radius.LG,
			stroke = if current then Theme.Color.Stroke.Gold else Theme.Color.Stroke.Subtle,
		})
		local sky = C.frame({
			parent = card,
			size = UDim2.new(1, -16, 0, 110),
			position = UDim2.fromOffset(8, 8),
			radius = Theme.Radius.MD,
			color = Color3.new(1, 1, 1),
		})
		C.gradient(sky, map.lighting.skyTop, map.lighting.skyBottom)
		C.text({
			parent = sky,
			text = map.icon,
			type = "Display",
			textSize = 64,
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.fromScale(1, 1),
			outline = false,
		})
		C.text({
			parent = card,
			text = map.name,
			type = "Heading",
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 30),
			position = UDim2.fromOffset(0, 122),
		})
		C.text({
			parent = card,
			text = map.description,
			type = "Caption",
			alignX = Enum.TextXAlignment.Center,
			wrap = true,
			size = UDim2.new(1, -20, 0, 44),
			position = UDim2.fromOffset(10, 152),
			color = Theme.Color.Text.Secondary,
		})
		local button = C.Button({
			parent = card,
			text = if current
				then "You're here"
				elseif unlocked then "Go!"
				else ("🔒 Level %d"):format(map.unlockLevel),
			variant = if current then "ghost" elseif unlocked then "primary" else "secondary",
			size = "sm",
			width = 200,
			position = UDim2.new(0.5, 0, 1, -12),
			anchor = Vector2.new(0.5, 1),
			onClick = function()
				if lab and not lab.isOwner then
					self.ui:Toast("You can only change maps in your own lab.", "error")
					return
				end
				Net.event("Command"):FireServer("setMap", map.id)
				self.ui:Close()
			end,
		})
		button.setDisabled(not unlocked or current)
	end
end

function MenuPanel:_spawn(data)
	local scroll = C.Scroll({ parent = self.content })
	C.list(scroll, Enum.FillDirection.Vertical, Theme.Space.MD)
	C.padding(scroll, 4)
	C.text({
		parent = scroll,
		text = "Golems: pick one, then right-click / tap in the lab to place it",
		type = "Heading",
		size = UDim2.new(1, 0, 0, 30),
		order = 1,
		color = Theme.Color.Text.Secondary,
	})
	local golemRow = C.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = scroll,
	})
	C.grid(golemRow, Vector2.new(170, 210), Theme.Space.SM)
	for _, skin in Skins.List do
		if data.skins[skin.id] then
			local button = C.new("TextButton", {
				AutoButtonColor = false,
				Text = "",
				BackgroundColor3 = Theme.Color.Surface.Raised,
				LayoutOrder = skin.order,
				Parent = golemRow,
			})
			C.corner(button, Theme.Radius.MD)
			C.stroke(button, Theme.rarityColor(skin.rarity), Theme.Stroke.Default)
			local _, spin = C.Viewport({
				parent = button,
				model = GolemPreview.build(skin),
				size = UDim2.new(1, -10, 0, 160),
				position = UDim2.fromOffset(5, 5),
				zoom = 0.95,
			})
			C.text({
				parent = button,
				text = skin.name,
				type = "Caption",
				alignX = Enum.TextXAlignment.Center,
				size = UDim2.new(1, 0, 0, 30),
				position = UDim2.fromOffset(0, 172),
			})
			C.interactive(button)
			button.MouseEnter:Connect(function()
				spin(true)
			end)
			button.MouseLeave:Connect(function()
				spin(false)
			end)
			button.Activated:Connect(function()
				C.sound("click")
				self.C.State:Select({ kind = "golem", id = skin.id })
				self.ui:Close()
			end)
		end
	end
	C.text({
		parent = scroll,
		text = "Items",
		type = "Heading",
		size = UDim2.new(1, 0, 0, 30),
		order = 3,
		color = Theme.Color.Text.Secondary,
	})
	local propRow = C.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 4,
		Parent = scroll,
	})
	C.grid(propRow, Vector2.new(170, 150), Theme.Space.SM)
	for _, prop in PropsData.List do
		local locked = data.level < prop.unlockLevel
		local button = C.new("TextButton", {
			AutoButtonColor = false,
			Text = "",
			BackgroundColor3 = Theme.Color.Surface.Raised,
			BackgroundTransparency = if locked then 0.5 else 0,
			LayoutOrder = prop.order,
			Parent = propRow,
		})
		C.corner(button, Theme.Radius.MD)
		C.stroke(button, Theme.Color.Stroke.Strong, Theme.Stroke.Default)
		C.text({
			parent = button,
			text = prop.icon,
			type = "Display",
			textSize = 52,
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 70),
			position = UDim2.fromOffset(0, 8),
			outline = false,
		})
		C.text({
			parent = button,
			text = prop.name,
			type = "Label",
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 24),
			position = UDim2.fromOffset(0, 80),
		})
		C.text({
			parent = button,
			text = if locked then ("🔒 Level %d"):format(prop.unlockLevel) else prop.description,
			type = "Caption",
			textSize = 12,
			alignX = Enum.TextXAlignment.Center,
			wrap = true,
			size = UDim2.new(1, -10, 0, 40),
			position = UDim2.fromOffset(5, 104),
			color = Theme.Color.Text.Secondary,
		})
		C.interactive(button)
		button.Activated:Connect(function()
			if locked then
				C.sound("error")
				return
			end
			C.sound("click")
			self.C.State:Select({ kind = "prop", id = prop.id })
			self.ui:Close()
		end)
	end
	C.Button({
		parent = scroll,
		text = "Clear all items",
		icon = "🧹",
		variant = "danger",
		size = "md",
		width = 260,
		order = 5,
		onClick = function()
			Net.event("Command"):FireServer("clearProps")
		end,
	})
end

function MenuPanel:_visit(lab)
	local holder = self.content
	local State = self.C.State
	if not lab then
		return
	end
	if not lab.isOwner then
		C.text({
			parent = holder,
			text = ("You're visiting %s's lab."):format(lab.ownerName),
			type = "Heading",
			size = UDim2.new(1, 0, 0, 34),
		})
		C.Button({
			parent = holder,
			text = "Go home",
			icon = "🏠",
			variant = "primary",
			width = 220,
			position = UDim2.fromOffset(0, 44),
			onClick = function()
				Net.event("Command"):FireServer("home")
				self.ui:Close()
			end,
		})
	else
		C.text({ parent = holder, text = "Who can visit your lab?", type = "Heading", size = UDim2.new(1, 0, 0, 34) })
		local row = C.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 48),
			Position = UDim2.fromOffset(0, 40),
			Parent = holder,
		})
		C.list(row, Enum.FillDirection.Horizontal, Theme.Space.SM)
		for index, option in
			{ { "everyone", "🌍 Everyone" }, { "friends", "🤝 Friends" }, { "nobody", "🔒 Nobody" } }
		do
			C.Button({
				parent = row,
				text = option[2],
				width = 180,
				order = index,
				variant = if lab.privacy == option[1] then "primary" else "secondary",
				onClick = function()
					Net.event("Command"):FireServer("privacy", option[1])
					task.delay(0.3, function()
						self:Refresh()
					end)
				end,
			})
		end
	end
	C.text({
		parent = holder,
		text = "Labs on this server",
		type = "Heading",
		size = UDim2.new(1, 0, 0, 34),
		position = UDim2.fromOffset(0, 110),
		color = Theme.Color.Text.Secondary,
	})
	local list = C.Scroll({ parent = holder, size = UDim2.new(1, 0, 1, -160), position = UDim2.fromOffset(0, 150) })
	C.list(list, Enum.FillDirection.Vertical, Theme.Space.SM)
	if #lab.labs == 0 then
		C.text({
			parent = list,
			text = "No other labs yet. Invite a friend!",
			type = "Body",
			size = UDim2.new(1, 0, 0, 40),
			color = Theme.Color.Text.Muted,
		})
	end
	for index, other in lab.labs do
		local _, card =
			C.card({ parent = list, size = UDim2.new(1, -12, 0, 72), order = index, radius = Theme.Radius.MD })
		local map = Maps.get(other.mapId)
		C.text({
			parent = card,
			text = ("%s  %s's Lab"):format(map.icon, other.name),
			type = "Heading",
			size = UDim2.new(1, -260, 0, 32),
			position = UDim2.fromOffset(16, 8),
		})
		C.text({
			parent = card,
			text = map.name .. "  ·  " .. (if other.privacy == "everyone"
				then "Open"
				elseif other.privacy == "friends" then "Friends only"
				else "Private"),
			type = "Caption",
			size = UDim2.new(1, -260, 0, 22),
			position = UDim2.fromOffset(16, 40),
			color = Theme.Color.Text.Secondary,
		})
		local button = C.Button({
			parent = card,
			text = if other.userId == lab.ownerId then "Here" else "Visit",
			icon = "🚪",
			width = 160,
			variant = "primary",
			position = UDim2.new(1, -14, 0.5, 0),
			anchor = Vector2.new(1, 0.5),
			onClick = function()
				local result = Net.func("Visit"):InvokeServer(other.userId)
				if result and result.ok then
					self.ui:Close()
					self.ui:Toast("Welcome to " .. other.name .. "'s lab! 👋", "social")
				else
					self.ui:Toast(result and result.reason or "Can't visit right now.", "error")
				end
			end,
		})
		button.setDisabled(other.privacy == "nobody" or other.userId == lab.ownerId)
	end
	local _ = State
end

function MenuPanel:_settings(data)
	local scroll = C.Scroll({ parent = self.content })
	C.list(scroll, Enum.FillDirection.Vertical, Theme.Space.LG)
	C.padding(scroll, 8, 40)
	local settings = data.settings
	local function send(key, value)
		Net.event("Settings"):FireServer(key, value)
	end
	C.Slider({
		parent = scroll,
		label = "🔊 Sound effects",
		value = settings.sfx or 0.8,
		order = 1,
		onChange = function(v)
			send("sfx", v)
		end,
	})
	C.Slider({
		parent = scroll,
		label = "🎵 Music",
		value = settings.music or 0.5,
		order = 2,
		onChange = function(v)
			send("music", v)
		end,
	})
	C.Slider({
		parent = scroll,
		label = "📳 Screen shake",
		value = settings.shake or 1,
		order = 3,
		onChange = function(v)
			send("shake", v)
		end,
	})
	local qualityRow =
		C.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 50), LayoutOrder = 4, Parent = scroll })
	C.text({ parent = qualityRow, text = "✨ Graphics", type = "Label", size = UDim2.fromOffset(200, 50) })
	for index, option in { { "high", "High" }, { "low", "Performance" } } do
		C.Button({
			parent = qualityRow,
			text = option[2],
			width = 180,
			position = UDim2.fromOffset(200 + (index - 1) * 190, 0),
			variant = if (settings.quality or "high") == option[1] then "primary" else "secondary",
			onClick = function()
				send("quality", option[1])
				task.delay(0.3, function()
					self:Refresh()
				end)
			end,
		})
	end
	C.Button({
		parent = scroll,
		text = "Replay the tutorial",
		icon = "🎓",
		width = 300,
		order = 5,
		onClick = function()
			send("tutorial", 0)
			self.ui:Close()
			self.ui.Tutorial:Begin(1)
		end,
	})
	C.text({
		parent = scroll,
		text = "Flask Fiasco · an original potion sandbox. Have fun experimenting!",
		type = "Caption",
		size = UDim2.new(1, 0, 0, 24),
		order = 6,
		color = Theme.Color.Text.Muted,
	})
end

function MenuPanel:Refresh()
	local State = self.C.State
	local data, lab = State.data, State.lab
	if not data then
		return
	end
	self:_clear()
	if self.tab == "maps" then
		self:_maps(data, lab)
	elseif self.tab == "spawn" then
		self:_spawn(data)
	elseif self.tab == "visit" then
		self:_visit(lab)
	else
		self:_settings(data)
	end
end

function MenuPanel:Open()
	self:Refresh()
	self.modal.open()
end

function MenuPanel:Close()
	self.modal.close()
end

return MenuPanel
