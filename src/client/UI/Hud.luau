--!nonstrict
-- HUD: player card (level, rank, XP, coins, flasks), chaos combo meter, lab bar (owner, visitors,
-- home/visit), left menu rail and right lab-control rail.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)

local Theme = require(script.Parent.Theme)
local C = require(script.Parent.Components)

local Hud = {}

function Hud:Mount(ui, controllers)
	self.ui, self.C = ui, controllers
	local root = ui.hud
	local State = controllers.State
	local touch = ui.touch

	-- ── Player card (top-left) ──
	local cardOuter, card = C.card({
		parent = root,
		size = UDim2.fromOffset(380, 112),
		position = UDim2.fromOffset(20, 16),
		radius = Theme.Radius.LG,
	})
	local badge = C.frame({
		parent = card,
		color = Theme.Color.Accent.Gold,
		size = UDim2.fromOffset(74, 74),
		position = UDim2.fromOffset(14, 14),
		radius = Theme.Radius.Pill,
		stroke = Theme.Color.Stroke.Gold,
		strokeThickness = 3,
	})
	C.gradient(badge, Theme.Color.Accent.Gold, Theme.Color.Accent.GoldDeep)
	local levelLabel = C.text({
		parent = badge,
		text = "1",
		type = "Title",
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.fromScale(1, 1),
		color = Theme.Color.Text.Inverse,
		outline = false,
	})
	local _nameLabel = C.text({
		parent = card,
		text = controllers.State and game:GetService("Players").LocalPlayer.DisplayName or "",
		type = "Heading",
		size = UDim2.new(1, -110, 0, 30),
		position = UDim2.fromOffset(100, 10),
		truncate = true,
	})
	local rankLabel = C.text({
		parent = card,
		text = "Apprentice",
		type = "Caption",
		size = UDim2.new(1, -110, 0, 20),
		position = UDim2.fromOffset(100, 40),
		color = Theme.Color.Accent.Gold,
	})
	local xpBar = C.Progress({
		parent = card,
		size = UDim2.new(1, -116, 0, 16),
		position = UDim2.fromOffset(100, 66),
		showLabel = true,
		color = Theme.Color.Accent.Cyan,
		color2 = Color3.fromRGB(80, 140, 255),
	})
	local _ = cardOuter
	local pills = C.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(420, 40),
		Position = UDim2.fromOffset(20, 136),
		Parent = root,
	})
	C.list(pills, Enum.FillDirection.Horizontal, Theme.Space.SM)
	local coinPill, coinLabel = C.Pill({
		parent = pills,
		icon = "🪙",
		text = "0",
		size = UDim2.fromOffset(170, 40),
		order = 1,
		stroke = Theme.Color.Stroke.Gold,
	})
	local flaskPill, flaskLabel =
		C.Pill({ parent = pills, icon = "🎁", text = "0", size = UDim2.fromOffset(110, 40), order = 2 })
	local coinButton =
		C.new("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), Parent = coinPill })
	coinButton.Activated:Connect(function()
		ui:Open("shop")
	end)
	local flaskButton =
		C.new("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), Parent = flaskPill })
	flaskButton.Activated:Connect(function()
		ui:Open("shop")
		local shop = ui.panels.shop
		if shop and shop.ShowTab then
			shop:ShowTab("flasks")
		end
	end)
	self.coinPill = coinPill

	local shownCoins = 0
	local function refresh(key)
		local data = State.data
		if not data then
			return
		end
		if key == "*" or key == "level" or key == "xp" then
			levelLabel.Text = tostring(data.level)
			rankLabel.Text = (if data.title ~= "" then data.title .. " · " else "") .. Config.rankForLevel(data.level)
			local need = Config.xpForLevel(data.level)
			xpBar.set(data.xp / need, ("%s / %s XP"):format(Format.short(data.xp), Format.short(need)))
		end
		if key == "*" or key == "coins" then
			local target = data.coins
			if key == "*" then
				coinLabel.Text = Format.commas(target)
			else
				C.countTo(coinLabel, shownCoins, target, function(v)
					return Format.commas(math.floor(v))
				end)
				if target > shownCoins then
					C.pulse(coinPill, 1.12)
				end
			end
			shownCoins = target
		end
		if key == "*" or key == "spins" then
			flaskLabel.Text = tostring(data.spins)
		end
		if key == "*" or key == "title" then
			rankLabel.Text = (if data.title ~= "" then data.title .. " · " else "") .. Config.rankForLevel(data.level)
		end
	end
	State.Changed:Connect(refresh)
	if State.data then
		refresh("*")
	end

	-- ── Chaos meter (top-centre) ──
	local chaosOuter, chaos = C.card({
		parent = root,
		size = UDim2.fromOffset(460, 86),
		position = UDim2.new(0.5, 0, 0, 14),
		anchor = Vector2.new(0.5, 0),
		radius = Theme.Radius.LG,
	})
	local chaosGroup = C.new(
		"CanvasGroup",
		{ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), GroupTransparency = 1, Parent = chaosOuter }
	)
	chaos.Parent = chaosGroup
	local shadow = chaosOuter:FindFirstChild("Shadow")
	if shadow then
		shadow.Parent = chaosGroup
		shadow.ZIndex = 0
	end
	C.text({
		parent = chaos,
		text = "CHAOS",
		type = "Label",
		size = UDim2.fromOffset(120, 24),
		position = UDim2.fromOffset(20, 10),
		color = Theme.Color.Text.Secondary,
	})
	local chaosValue = C.text({
		parent = chaos,
		text = "0",
		type = "Title",
		textSize = 40,
		size = UDim2.new(1, -150, 0, 44),
		position = UDim2.fromOffset(20, 30),
		color = Theme.Color.Text.Primary,
	})
	local multiplier = C.frame({
		parent = chaos,
		color = Theme.comboColor(1),
		size = UDim2.fromOffset(96, 56),
		position = UDim2.new(1, -16, 0, 14),
		anchor = Vector2.new(1, 0),
		radius = Theme.Radius.MD,
	})
	local multiplierLabel = C.text({
		parent = multiplier,
		text = "x1",
		type = "Title",
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.fromScale(1, 1),
		color = Theme.Color.Text.Inverse,
		outline = false,
	})
	local decay = C.Progress({
		parent = chaos,
		size = UDim2.new(1, -40, 0, 6),
		position = UDim2.new(0, 20, 1, -12),
		color = Theme.Color.Accent.Magenta,
		color2 = Theme.Color.Accent.Gold,
	})
	self.chaosGroup = chaosGroup
	local sessionChaos = 0
	local lastGain = 0
	local comboWindow = Config.Economy.ComboWindow
	controllers.VFXController.HudEvent:Connect(function(kind, payload)
		if kind == "chaos" then
			if payload.g and payload.g > 0 then
				local from = sessionChaos
				sessionChaos += payload.g
				C.countTo(chaosValue, from, sessionChaos, function(v)
					return Format.commas(math.floor(v))
				end)
				C.pulse(chaosValue, 1.18)
				lastGain = os.clock()
			end
			local level = payload.c or 1
			comboWindow = payload.w or comboWindow
			if multiplierLabel.Text ~= "x" .. level then
				multiplierLabel.Text = "x" .. level
				multiplier.BackgroundColor3 = Theme.comboColor(level)
				C.pulse(multiplier, 1.35)
				if level > 1 then
					controllers.SoundController:Play("coin", nil, { pitch = 0.7 + level * 0.15, ui = true })
				end
			end
		elseif kind == "coins" then
			C.pulse(coinPill, 1.15)
			local pop = C.text({
				parent = root,
				text = "+" .. Format.commas(payload.a),
				type = "Heading",
				size = UDim2.fromOffset(200, 30),
				position = UDim2.fromOffset(200, 176),
				color = Theme.Color.Accent.Gold,
				z = 5,
			})
			C.tween(
				pop,
				TweenInfo.new(1, Enum.EasingStyle.Quad),
				{ Position = UDim2.fromOffset(200, 150), TextTransparency = 1 }
			)
			task.delay(1, function()
				pop:Destroy()
			end)
		end
	end)
	RunService.RenderStepped:Connect(function()
		local since = os.clock() - lastGain
		local visible = since < 4 and not State.trial
		local target = if visible then 0 else 1
		chaosGroup.GroupTransparency += (target - chaosGroup.GroupTransparency) * 0.12
		decay.set(math.clamp(1 - since / comboWindow, 0, 1), nil, true)
		if since > comboWindow and multiplierLabel.Text ~= "x1" then
			multiplierLabel.Text = "x1"
			multiplier.BackgroundColor3 = Theme.comboColor(1)
		end
	end)

	-- ── Lab bar (top-right) ──
	local labOuter, lab = C.card({
		parent = root,
		size = UDim2.fromOffset(400, 64),
		position = UDim2.new(1, -20, 0, 16),
		anchor = Vector2.new(1, 0),
		radius = Theme.Radius.LG,
	})
	local labTitle = C.text({
		parent = lab,
		text = "🧪 Lab",
		type = "Label",
		size = UDim2.new(1, -150, 0, 26),
		position = UDim2.fromOffset(16, 8),
		truncate = true,
	})
	local labInfo = C.text({
		parent = lab,
		text = "",
		type = "Caption",
		size = UDim2.new(1, -150, 0, 20),
		position = UDim2.fromOffset(16, 34),
		color = Theme.Color.Text.Secondary,
		truncate = true,
	})
	local homeButton = C.Button({
		parent = lab,
		text = "Visit",
		icon = "🚪",
		width = 120,
		size = "sm",
		position = UDim2.new(1, -12, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		variant = "secondary",
		onClick = function()
			local labState = State.lab
			if labState and not labState.isOwner then
				Net.event("Command"):FireServer("home")
			else
				ui:Open("menu")
				local menu = ui.panels.menu
				if menu and menu.ShowTab then
					menu:ShowTab("visit")
				end
			end
		end,
	})
	local _ = labOuter
	State.LabChanged:Connect(function(labState)
		local mapName = require(Shared.Data.Maps).get(labState.mapId).name
		labTitle.Text = (if labState.isOwner then "🏠 Your Lab" else "🔍 " .. labState.ownerName .. "'s Lab")
			.. "  ·  "
			.. mapName
		local status = {}
		table.insert(status, ("🗿 %d/%d"):format(labState.golems, labState.maxGolems))
		if #labState.visitors > 1 then
			table.insert(status, ("👥 %d here"):format(#labState.visitors))
		end
		if labState.paused then
			table.insert(status, "⏸️ Paused")
		elseif labState.slowmo then
			table.insert(status, "🐌 Slow-mo")
		end
		labInfo.Text = table.concat(status, "   ")
		homeButton.setText(if labState.isOwner then "Visit" else "Home")
	end)

	-- ── Left rail: menus ──
	local leftRail = C.new("Frame", {
		Name = "LeftRail",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(90, 560),
		Position = UDim2.new(0, 22, 0.5, 30),
		AnchorPoint = Vector2.new(0, 0.5),
		Parent = root,
	})
	C.list(leftRail, Enum.FillDirection.Vertical, Theme.Space.MD)
	local size = if touch then Theme.Size.IconButtonTouch else Theme.Size.IconButton
	local leftButtons = {
		{ id = "brew", icon = "🧪", caption = "Brew", key = "B" },
		{ id = "codex", icon = "📖", caption = "Codex", key = "C" },
		{ id = "challenges", icon = "🏆", caption = "Quests", key = "J" },
		{ id = "shop", icon = "🛒", caption = "Shop", key = "O" },
		{ id = "menu", icon = "🗺️", caption = "World", key = "M" },
		{ id = "help", icon = "❔", caption = "Keys", key = "F1" },
	}
	self.railButtons = {}
	for index, spec in leftButtons do
		local handle = C.IconButton({
			parent = leftRail,
			icon = spec.icon,
			caption = spec.caption,
			keybind = if touch then nil else spec.key,
			sizePx = size,
			order = index,
			onClick = function()
				ui:Toggle(spec.id)
			end,
		})
		self.railButtons[spec.id] = handle
	end

	-- ── Right rail: lab controls ──
	local rightRail = C.new("Frame", {
		Name = "RightRail",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(90, 640),
		Position = UDim2.new(1, -22, 0.5, 30),
		AnchorPoint = Vector2.new(1, 0.5),
		Parent = root,
	})
	C.list(rightRail, Enum.FillDirection.Vertical, Theme.Space.MD, Enum.HorizontalAlignment.Right)
	local rightButtons = {
		{ id = "slowmo", icon = "🐌", caption = "Slow-mo", key = "G" },
		{ id = "pause", icon = "⏸️", caption = "Pause", key = "Space" },
		{ id = "heal", icon = "💖", caption = "Heal", key = "H" },
		{ id = "spawnLast", icon = "🗿", caption = "Spawn", key = "N" },
		{ id = "undo", icon = "↩️", caption = "Undo", key = "Z" },
		{ id = "reset", icon = "🔄", caption = "Reset", key = "R" },
		{ id = "photo", icon = "📷", caption = "Photo", key = "P" },
	}
	self.controlButtons = {}
	for index, spec in rightButtons do
		local handle = C.IconButton({
			parent = rightRail,
			icon = spec.icon,
			caption = spec.caption,
			keybind = if touch then nil else spec.key,
			sizePx = size,
			order = index,
			onClick = function()
				controllers.InputController.Action:Fire(spec.id)
			end,
		})
		self.controlButtons[spec.id] = handle
	end
	State.LabChanged:Connect(function(labState)
		self.controlButtons.slowmo.setActive(labState.slowmo)
		self.controlButtons.pause.setActive(labState.paused)
		self.controlButtons.pause.setIcon(if labState.paused then "▶️" else "⏸️")
	end)

	-- Notification dots on the rail.
	local function badges()
		local data = State.data
		if not data then
			return
		end
		local dailyLeft = 0
		for _, challenge in data.daily.list do
			if not challenge.done then
				dailyLeft += 1
			end
		end
		self.railButtons.challenges.setBadge(if dailyLeft > 0 then tostring(dailyLeft) else nil)
		self.railButtons.shop.setBadge(if data.spins > 0 then tostring(data.spins) else nil)
		local stock = data.rack and data.rack.stock or 0
		self.railButtons.brew.setBadge(if stock > 0 then "🌿" else nil)
	end
	State.Changed:Connect(function(key)
		if key == "*" or key == "daily" or key == "spins" or key == "rack" then
			badges()
		end
	end)
end

return Hud
