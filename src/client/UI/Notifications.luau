--!nonstrict
-- Feedback layer: toasts, level-up banner, the full-screen potion discovery reveal, reaction
-- discoveries, challenge completions, the daily streak popup and the endgame "Ascended" moment.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Potions = require(Shared.Data.Potions)
local Reactions = require(Shared.Data.Reactions)
local Rarity = require(Shared.Data.Rarity)

local Theme = require(script.Parent.Theme)
local C = require(script.Parent.Components)

local Notifications = {}

local TOAST_ICONS = { info = "💬", success = "✅", error = "⚠️", reward = "🎁", social = "👋" }
local MAX_TOASTS = 4

function Notifications:Mount(ui, controllers)
	self.ui, self.C = ui, controllers
	local root = ui.overlayScaled
	self.root = root
	self.toasts = {}
	self.queue = {}
	self.revealing = false

	local stack = C.new("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(Theme.Size.Toast.X, 400),
		Position = UDim2.new(1, -20, 0, 150),
		AnchorPoint = Vector2.new(1, 0),
		Parent = root,
	})
	C.list(stack, Enum.FillDirection.Vertical, Theme.Space.SM, Enum.HorizontalAlignment.Right)
	self.stack = stack

	controllers.State.Notified:Connect(function(kind, payload)
		self:_handle(kind, payload)
	end)
end

function Notifications:Toast(text: string, kind: string?)
	kind = kind or "info"
	local accent = Theme.Color.Toast[kind] or Theme.Color.Toast.info
	local outer, body = C.card({
		parent = self.stack,
		size = UDim2.fromOffset(Theme.Size.Toast.X, Theme.Size.Toast.Y),
		radius = Theme.Radius.MD,
		stroke = accent,
	})
	outer.LayoutOrder = -os.clock() * 1000
	local bar = C.frame({
		parent = body,
		color = accent,
		size = UDim2.new(0, 6, 1, -16),
		position = UDim2.fromOffset(8, 8),
		radius = Theme.Radius.Pill,
	})
	local _ = bar
	C.text({
		parent = body,
		text = TOAST_ICONS[kind] or "💬",
		type = "Heading",
		size = UDim2.fromOffset(40, 64),
		position = UDim2.fromOffset(18, 0),
		alignX = Enum.TextXAlignment.Center,
		outline = false,
	})
	C.text({
		parent = body,
		text = text,
		type = "Caption",
		textSize = 15,
		size = UDim2.new(1, -72, 1, -8),
		position = UDim2.fromOffset(62, 4),
		wrap = true,
	})
	local scale = C.new("UIScale", { Scale = 0.6, Parent = outer })
	C.tween(scale, Theme.Motion.ToastIn, { Scale = 1 })
	table.insert(self.toasts, outer)
	while #self.toasts > MAX_TOASTS do
		local oldest = table.remove(self.toasts, 1)
		oldest:Destroy()
	end
	if kind == "error" then
		self.C.SoundController:Play("error", nil, { ui = true })
	elseif kind == "reward" then
		self.C.SoundController:Play("coin", nil, { ui = true })
	end
	task.delay(Theme.Motion.ToastHold, function()
		if outer.Parent then
			C.tween(scale, Theme.Motion.ToastOut, { Scale = 0 })
			task.wait(Theme.Motion.ToastOut.Time)
			local index = table.find(self.toasts, outer)
			if index then
				table.remove(self.toasts, index)
			end
			outer:Destroy()
		end
	end)
end

-- Centre banner (level up, challenge done...).
function Notifications:Banner(title: string, subtitle: string, color: Color3, chips: { string }?)
	local outer, body = C.card({
		parent = self.root,
		size = UDim2.fromOffset(620, if chips and #chips > 0 then 170 else 124),
		position = UDim2.new(0.5, 0, 0.22, 0),
		anchor = Vector2.new(0.5, 0.5),
		radius = Theme.Radius.LG,
		stroke = color,
		elevation = "E2",
	})
	C.text({
		parent = body,
		text = title,
		type = "Display",
		textSize = 52,
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 64),
		position = UDim2.fromOffset(0, 10),
		color = color,
	})
	C.text({
		parent = body,
		text = subtitle,
		type = "Heading",
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 32),
		position = UDim2.fromOffset(0, 74),
	})
	if chips and #chips > 0 then
		local row = C.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -40, 0, 36),
			Position = UDim2.fromOffset(20, 118),
			Parent = body,
		})
		C.list(row, Enum.FillDirection.Horizontal, Theme.Space.SM, Enum.HorizontalAlignment.Center)
		for index, chip in chips do
			local pill = C.frame({
				parent = row,
				color = Theme.Color.Surface.Raised,
				size = UDim2.fromOffset(0, 34),
				autoSize = Enum.AutomaticSize.X,
				radius = Theme.Radius.Pill,
				stroke = Theme.Color.Stroke.Gold,
				order = index,
			})
			C.padding(pill, 0, Theme.Space.MD)
			C.text({
				parent = pill,
				text = chip,
				type = "Caption",
				size = UDim2.fromOffset(0, 34),
				autoSize = Enum.AutomaticSize.X,
				alignX = Enum.TextXAlignment.Center,
			})
		end
	end
	local scale = C.new("UIScale", { Scale = 0.4, Parent = outer })
	C.tween(scale, Theme.Motion.Reveal, { Scale = 1 })
	task.delay(3.2, function()
		C.tween(scale, Theme.Motion.PanelOut, { Scale = 0 })
		task.wait(0.2)
		outer:Destroy()
	end)
end

-- Rotating light rays behind reveals.
local function rays(parent: Instance, color: Color3, z: number)
	local holder = C.new("Frame", {
		Name = "Rays",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(900, 900),
		Position = UDim2.fromScale(0.5, 0.42),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = z,
		Parent = parent,
	})
	for layer = 1, 2 do
		local fan =
			C.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z, Parent = holder })
		for i = 0, 11 do
			local ray = C.new("Frame", {
				BackgroundColor3 = color,
				BackgroundTransparency = 0.55 + layer * 0.12,
				BorderSizePixel = 0,
				Size = UDim2.new(0, 34 - layer * 8, 0.5, 0),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 1),
				Rotation = i * 30 + layer * 15,
				ZIndex = z,
				Parent = fan,
			})
			C.new("UIGradient", { Transparency = NumberSequence.new(0, 1), Rotation = -90, Parent = ray })
		end
		fan:SetAttribute("Speed", if layer == 1 then 20 else -14)
	end
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not holder.Parent then
			conn:Disconnect()
			return
		end
		for _, fan in holder:GetChildren() do
			if fan:IsA("Frame") then
				for _, ray in fan:GetChildren() do
					if ray:IsA("Frame") then
						ray.Rotation += (fan:GetAttribute("Speed") or 20) * dt
					end
				end
			end
		end
	end)
	return holder
end

local function confetti(parent: Instance, z: number)
	local colors =
		{ Theme.Color.Accent.Gold, Theme.Color.Accent.Magenta, Theme.Color.Accent.Cyan, Theme.Color.Accent.Lime }
	for _ = 1, 60 do
		local piece = C.new("Frame", {
			BackgroundColor3 = colors[math.random(1, #colors)],
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(math.random(8, 16), math.random(6, 12)),
			Position = UDim2.new(0.5, 0, 0.45, 0),
			Rotation = math.random(0, 360),
			ZIndex = z,
			Parent = parent,
		})
		local angle = math.random() * math.pi * 2
		local distance = math.random(250, 700)
		local target = UDim2.new(0.5, math.cos(angle) * distance, 0.45, math.sin(angle) * distance * 0.7 + 200)
		C.tween(
			piece,
			TweenInfo.new(math.random(10, 18) / 10, Enum.EasingStyle.Quart),
			{ Position = target, Rotation = piece.Rotation + math.random(-360, 360), BackgroundTransparency = 1 }
		)
		task.delay(2, function()
			piece:Destroy()
		end)
	end
end

function Notifications:Reveal(potionId: string)
	local potion = Potions.ById[potionId]
	if not potion then
		return
	end
	if self.revealing then
		table.insert(self.queue, potionId)
		return
	end
	self.revealing = true
	local color = Theme.rarityColor(potion.rarity)
	local screen = C.new("Frame", {
		Name = "Reveal",
		BackgroundColor3 = Theme.Color.Surface.Base,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 250,
		Active = true,
		Parent = self.root,
	})
	C.tween(screen, Theme.Motion.Fade, { BackgroundTransparency = 0.25 })
	rays(screen, color, 251)
	local viewport, spin = C.BottleIcon({
		parent = screen,
		potion = potion,
		size = UDim2.fromOffset(300, 300),
		position = UDim2.fromScale(0.5, 0.42),
		anchor = Vector2.new(0.5, 0.5),
		z = 253,
		spin = true,
		zoom = 1.1,
	})
	local _ = spin
	local vscale = C.new("UIScale", { Scale = 0.2, Parent = viewport })
	C.tween(vscale, Theme.Motion.Reveal, { Scale = 1 })
	C.text({
		parent = screen,
		text = "NEW POTION DISCOVERED!",
		type = "Title",
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 44),
		position = UDim2.fromScale(0.5, 0.13),
		anchor = Vector2.new(0.5, 0.5),
		color = Theme.Color.Accent.Gold,
		z = 254,
	})
	local chip = C.frame({
		parent = screen,
		color = color,
		size = UDim2.fromOffset(170, 34),
		position = UDim2.fromScale(0.5, 0.62),
		anchor = Vector2.new(0.5, 0.5),
		radius = Theme.Radius.Pill,
		z = 254,
	})
	C.text({
		parent = chip,
		text = potion.rarity:upper(),
		type = "Label",
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.fromScale(1, 1),
		color = Theme.Color.Text.Inverse,
		outline = false,
		z = 255,
	})
	C.text({
		parent = screen,
		text = potion.name,
		type = "Display",
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 72),
		position = UDim2.fromScale(0.5, 0.7),
		anchor = Vector2.new(0.5, 0.5),
		color = color,
		z = 254,
	})
	C.text({
		parent = screen,
		text = potion.description,
		type = "Body",
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.new(0, 760, 0, 60),
		position = UDim2.fromScale(0.5, 0.78),
		anchor = Vector2.new(0.5, 0.5),
		wrap = true,
		color = Theme.Color.Text.Secondary,
		z = 254,
	})
	local rarity = Rarity[potion.rarity]
	C.text({
		parent = screen,
		text = ("+%d XP   +%d 🪙"):format(rarity and rarity.discoverXp or 0, rarity and rarity.discoverCoins or 0),
		type = "Heading",
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 34),
		position = UDim2.fromScale(0.5, 0.84),
		anchor = Vector2.new(0.5, 0.5),
		color = Theme.Color.Accent.Gold,
		z = 254,
	})
	confetti(screen, 252)
	self.C.SoundController:Play("discover", nil, { ui = true })
	local function close()
		if not screen.Parent then
			return
		end
		C.tween(screen, Theme.Motion.PanelOut, { BackgroundTransparency = 1 })
		screen:Destroy()
		self.revealing = false
		local nextId = table.remove(self.queue, 1)
		if nextId then
			task.delay(0.2, function()
				self:Reveal(nextId)
			end)
		end
	end
	C.Button({
		parent = screen,
		text = "Awesome!",
		icon = "✨",
		variant = "primary",
		size = "lg",
		width = 260,
		position = UDim2.fromScale(0.5, 0.92),
		anchor = Vector2.new(0.5, 0.5),
		z = 256,
		onClick = close,
	})
	task.delay(7, close)
end

function Notifications:_handle(kind: string, payload)
	local State = self.C.State
	if kind == "toast" then
		self:Toast(payload.text, payload.kind)
	elseif kind == "levelup" then
		local chips = {}
		for _, unlock in payload.unlocks or {} do
			table.insert(chips, unlock.icon .. " " .. unlock.name)
		end
		self:Banner(
			"LEVEL " .. payload.level .. "!",
			payload.rank .. "  ·  +" .. payload.coins .. " 🪙",
			Theme.Color.Accent.Gold,
			chips
		)
		self.C.SoundController:Play("levelup", nil, { ui = true })
	elseif kind == "discover" then
		self:Reveal(payload.id)
	elseif kind == "reactionDiscovered" then
		local reaction = Reactions.ById[payload.id]
		if reaction then
			self:Banner(
				reaction.icon .. " NEW REACTION!",
				reaction.name .. ": " .. reaction.description,
				reaction.color
			)
			self.C.SoundController:Play("discover", nil, { ui = true })
		end
	elseif kind == "challenge" then
		self:Toast(
			("%s Challenge complete: %s  (+%d 🪙  +%d XP)"):format(
				payload.icon or "🏆",
				payload.text,
				payload.coins,
				payload.xp
			),
			"reward"
		)
		self.C.SoundController:Play("reward", nil, { ui = true })
	elseif kind == "welcome" then
		if payload.temporary then
			self:Toast("Saving is unavailable right now. Your progress this session may not be kept.", "error")
		end
		if payload.streakReady then
			task.delay(1.5, function()
				self:StreakPopup()
			end)
		end
	elseif kind == "ascended" then
		self:Banner(
			"ASCENDED!",
			"You are a Grand Alchemist. The Ascended Golem skin is yours.",
			Theme.Color.Rarity.Mythic,
			{ "😇 Ascended Golem", "👑 Grand Alchemist title" }
		)
	end
	local _ = State
end

function Notifications:StreakPopup()
	local State = self.C.State
	local data = State.data
	if not data then
		return
	end
	local today = math.floor(os.time() / 86400)
	local nextCount = if data.streak.day == today - 1 then data.streak.count + 1 else 1
	local modal = C.Modal({ parent = self.ui.modals, title = "🎁 Daily Reward", size = Vector2.new(860, 420) })
	local row = C.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 170), Parent = modal.body })
	C.list(row, Enum.FillDirection.Horizontal, Theme.Space.SM, Enum.HorizontalAlignment.Center)
	for day, reward in Config.DailyStreakRewards do
		local cycleDay = (nextCount - 1) % #Config.DailyStreakRewards + 1
		local isToday = day == cycleDay
		local claimed = day < cycleDay
		local _, cell = C.card({
			parent = row,
			size = UDim2.fromOffset(104, 160),
			order = day,
			radius = Theme.Radius.MD,
			stroke = if isToday then Theme.Color.Stroke.Gold else Theme.Color.Stroke.Subtle,
		})
		C.text({
			parent = cell,
			text = "Day " .. day,
			type = "Label",
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 26),
			position = UDim2.fromOffset(0, 8),
			color = if isToday then Theme.Color.Accent.Gold else Theme.Color.Text.Secondary,
		})
		C.text({
			parent = cell,
			text = if claimed then "✅" elseif reward.spins then "🎁" else "🪙",
			type = "Title",
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 50),
			position = UDim2.fromOffset(0, 40),
			outline = false,
		})
		C.text({
			parent = cell,
			text = tostring(reward.coins or 0),
			type = "Label",
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 24),
			position = UDim2.fromOffset(0, 96),
		})
		if reward.spins then
			C.text({
				parent = cell,
				text = "+" .. reward.spins .. " flask",
				type = "Caption",
				alignX = Enum.TextXAlignment.Center,
				size = UDim2.new(1, 0, 0, 20),
				position = UDim2.fromOffset(0, 122),
				color = Theme.Color.Accent.Magenta,
			})
		end
	end
	C.text({
		parent = modal.body,
		text = ("Streak: %d day%s. Come back tomorrow for more!"):format(nextCount, if nextCount == 1 then "" else "s"),
		type = "Body",
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 30),
		position = UDim2.fromOffset(0, 190),
		color = Theme.Color.Text.Secondary,
	})
	C.Button({
		parent = modal.body,
		text = "Claim!",
		icon = "🎁",
		variant = "primary",
		size = "lg",
		width = 280,
		position = UDim2.new(0.5, 0, 0, 236),
		anchor = Vector2.new(0.5, 0),
		onClick = function()
			local result = Net.func("Shop"):InvokeServer("claimDaily")
			if result and result.ok then
				self:Toast(("Day %d reward claimed!"):format(result.day), "reward")
				self.C.SoundController:Play("reward", nil, { ui = true })
			elseif result then
				self:Toast(result.reason or "Already claimed", "info")
			end
			modal.close()
		end,
	})
	modal.onClose = function()
		task.delay(0.3, function()
			modal.root:Destroy()
		end)
	end
	modal.open()
	local _ = TweenService
end

return Notifications
