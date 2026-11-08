--!nonstrict
-- Quests: today's 3 daily challenges (with a reset countdown) and the Trials ladder.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Challenges = require(Shared.Data.Challenges)
local Format = require(Shared.Util.Format)

local Theme = require(script.Parent.Theme)
local C = require(script.Parent.Components)

local ChallengesPanel = {}

function ChallengesPanel:Mount(ui, controllers)
	self.ui, self.C = ui, controllers
	local modal = C.Modal({ parent = ui.modals, title = "🏆 Quests", size = Vector2.new(1100, 690) })
	self.modal = modal
	modal.onClose = function()
		ui:PanelClosed("challenges")
	end
	self.tab = "daily"
	self.tabs = C.Tabs({
		parent = modal.body,
		tabs = {
			{ id = "daily", label = "Daily", icon = "📅" },
			{ id = "trials", label = "Trials", icon = "⚔️" },
		},
		onSelect = function(id)
			self.tab = id
			self:Refresh()
		end,
	})
	self.reset = C.text({
		parent = modal.body,
		text = "",
		type = "Label",
		alignX = Enum.TextXAlignment.Right,
		size = UDim2.fromOffset(400, 30),
		position = UDim2.new(1, 0, 0, 8),
		anchor = Vector2.new(1, 0),
		color = Theme.Color.Text.Secondary,
	})
	self.content = C.Scroll({ parent = modal.body, size = UDim2.new(1, 0, 1, -60), position = UDim2.fromOffset(0, 60) })
	C.list(self.content, Enum.FillDirection.Vertical, Theme.Space.MD)
	C.padding(self.content, 4)
	controllers.State.Changed:Connect(function(key)
		if modal.isOpen() and (key == "*" or key == "daily" or key == "trials") then
			self:Refresh()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if modal.isOpen() and self.tab == "daily" then
				local secondsLeft = 86400 - (os.time() % 86400)
				self.reset.Text = "New challenges in " .. Format.duration(secondsLeft)
			end
		end
	end)
end

function ChallengesPanel:ShowTab(id: string)
	self.tabs.select(id)
end

function ChallengesPanel:_clear()
	for _, child in self.content:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

function ChallengesPanel:_daily(data)
	self.reset.Visible = true
	local done = 0
	for index, challenge in data.daily.list do
		local template = Challenges.DailyById[challenge.id]
		if not template then
			continue
		end
		if challenge.done then
			done += 1
		end
		local tierNames = { "Easy", "Medium", "Hard" }
		local tierColors = { Theme.Color.State.Success, Theme.Color.State.Warning, Theme.Color.State.Danger }
		local _, card = C.card({
			parent = self.content,
			size = UDim2.new(1, -12, 0, 118),
			order = index,
			radius = Theme.Radius.LG,
			stroke = if challenge.done then Theme.Color.State.Success else Theme.Color.Stroke.Subtle,
		})
		C.text({
			parent = card,
			text = template.icon,
			type = "Title",
			textSize = 52,
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.fromOffset(90, 118),
			outline = false,
		})
		C.text({
			parent = card,
			text = template.text:format(challenge.target),
			type = "Heading",
			size = UDim2.new(1, -330, 0, 34),
			position = UDim2.fromOffset(96, 16),
		})
		local chip = C.frame({
			parent = card,
			color = tierColors[challenge.tier] or Theme.Color.State.Info,
			size = UDim2.fromOffset(80, 24),
			position = UDim2.fromOffset(96, 54),
			radius = Theme.Radius.Pill,
		})
		C.text({
			parent = chip,
			text = tierNames[challenge.tier] or "",
			type = "Caption",
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.fromScale(1, 1),
			color = Theme.Color.Text.Inverse,
			outline = false,
		})
		local bar = C.Progress({
			parent = card,
			size = UDim2.new(1, -330, 0, 18),
			position = UDim2.fromOffset(96, 86),
			showLabel = true,
			color = Theme.Color.Accent.Lime,
			color2 = Theme.Color.State.Success,
		})
		bar.set(
			challenge.progress / math.max(challenge.target, 1),
			("%s / %s"):format(Format.commas(challenge.progress), Format.commas(challenge.target)),
			true
		)
		local coins = Challenges.DailyRewards.coins[challenge.tier] or 60
		local xp = Challenges.DailyRewards.xp[challenge.tier] or 50
		C.text({
			parent = card,
			text = if challenge.done then "✅ Done!" else ("+%d 🪙   +%d XP"):format(coins, xp),
			type = "Heading",
			alignX = Enum.TextXAlignment.Right,
			size = UDim2.fromOffset(220, 40),
			position = UDim2.new(1, -20, 0.5, 0),
			anchor = Vector2.new(1, 0.5),
			color = if challenge.done then Theme.Color.State.Success else Theme.Color.Accent.Gold,
		})
	end
	local _, bonus = C.card({
		parent = self.content,
		size = UDim2.new(1, -12, 0, 80),
		order = 10,
		radius = Theme.Radius.LG,
		stroke = if data.daily.bonusClaimed then Theme.Color.State.Success else Theme.Color.Stroke.Gold,
	})
	C.text({
		parent = bonus,
		text = ("🎁 Finish all 3 for a free Mystery Flask!  (%d/3)"):format(done),
		type = "Heading",
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.fromScale(1, 1),
		color = if data.daily.bonusClaimed then Theme.Color.State.Success else Theme.Color.Accent.Gold,
	})
end

function ChallengesPanel:_trials(data)
	self.reset.Visible = true
	local totalStars = 0
	for _, record in data.trials do
		totalStars += record.stars or 0
	end
	self.reset.Text = ("Total: %d ★  ·  Magnum Opus needs %d ★"):format(totalStars, 20)
	local previousCleared = true
	for _, trial in Challenges.Trials do
		local record = data.trials[trial.id]
		local starsOk = not trial.requiresStars or totalStars >= trial.requiresStars
		local unlocked = previousCleared and starsOk
		local _, card = C.card({
			parent = self.content,
			size = UDim2.new(1, -12, 0, 104),
			order = trial.order,
			radius = Theme.Radius.LG,
			stroke = if trial.final
				then Theme.Color.Rarity.Mythic
				elseif record then Theme.Color.Stroke.Gold
				else Theme.Color.Stroke.Subtle,
		})
		C.text({
			parent = card,
			text = if unlocked then trial.icon else "🔒",
			type = "Title",
			textSize = 48,
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.fromOffset(90, 104),
			outline = false,
		})
		C.text({
			parent = card,
			text = ("%d. %s"):format(trial.order, trial.name),
			type = "Heading",
			size = UDim2.new(1, -420, 0, 32),
			position = UDim2.fromOffset(96, 12),
			color = if trial.final then Theme.Color.Rarity.Mythic else Theme.Color.Text.Primary,
		})
		C.text({
			parent = card,
			text = trial.description,
			type = "Caption",
			wrap = true,
			size = UDim2.new(1, -420, 0, 40),
			position = UDim2.fromOffset(96, 46),
			color = Theme.Color.Text.Secondary,
		})
		local stars = record and record.stars or 0
		C.text({
			parent = card,
			text = string.rep("★", stars) .. string.rep("☆", 3 - stars),
			type = "Title",
			textSize = 34,
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.fromOffset(140, 40),
			position = UDim2.new(1, -330, 0, 14),
			color = Theme.Color.Accent.Gold,
		})
		C.text({
			parent = card,
			text = if record then "Best " .. Format.seconds(record.best) else ("3★ ≤ %ds"):format(trial.stars[3]),
			type = "Caption",
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.fromOffset(140, 22),
			position = UDim2.new(1, -330, 0, 58),
			color = Theme.Color.Text.Muted,
		})
		local button = C.Button({
			parent = card,
			text = if not unlocked
				then (if not previousCleared then "Locked" else ("Needs %d★"):format(trial.requiresStars or 0))
				elseif record then "Replay"
				else "Start",
			icon = if unlocked then "▶" else nil,
			variant = if unlocked and not record then "primary" else "secondary",
			width = 160,
			size = "md",
			position = UDim2.new(1, -20, 0.5, 0),
			anchor = Vector2.new(1, 0.5),
			onClick = function()
				local result = Net.func("TrialRequest"):InvokeServer("start", trial.id)
				if result and result.ok then
					self.ui:Close()
				elseif result then
					self.ui:Toast(result.reason or "Locked", "error")
				end
			end,
		})
		button.setDisabled(not unlocked)
		previousCleared = record ~= nil
	end
end

function ChallengesPanel:Refresh()
	local data = self.C.State.data
	if not data then
		return
	end
	self:_clear()
	if self.tab == "daily" then
		self:_daily(data)
	else
		self:_trials(data)
	end
end

function ChallengesPanel:Open()
	self:Refresh()
	self.modal.open()
end

function ChallengesPanel:Close()
	self.modal.close()
end

return ChallengesPanel
