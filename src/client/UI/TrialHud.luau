--!nonstrict
-- Trial HUD: objective banner with live timer and star thresholds, plus the results screen.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Challenges = require(Shared.Data.Challenges)
local Ingredients = require(Shared.Data.Ingredients)
local Format = require(Shared.Util.Format)

local Theme = require(script.Parent.Theme)
local C = require(script.Parent.Components)

local TrialHud = {}

function TrialHud:Mount(ui, controllers)
	self.ui, self.C = ui, controllers
	local State = controllers.State
	local outer, body = C.card({
		parent = ui.hud,
		size = UDim2.fromOffset(560, 104),
		position = UDim2.new(0.5, 0, 0, 14),
		anchor = Vector2.new(0.5, 0),
		radius = Theme.Radius.LG,
		stroke = Theme.Color.Stroke.Gold,
	})
	outer.Visible = false
	self.outer = outer
	self.title = C.text({
		parent = body,
		text = "",
		type = "Heading",
		size = UDim2.new(1, -200, 0, 32),
		position = UDim2.fromOffset(18, 8),
		color = Theme.Color.Accent.Gold,
		truncate = true,
	})
	self.objective = C.text({
		parent = body,
		text = "",
		type = "Label",
		size = UDim2.new(1, -200, 0, 24),
		position = UDim2.fromOffset(18, 40),
		truncate = true,
	})
	self.progress = C.Progress({
		parent = body,
		size = UDim2.new(1, -200, 0, 12),
		position = UDim2.fromOffset(18, 74),
		color = Theme.Color.Accent.Lime,
		color2 = Theme.Color.State.Success,
	})
	self.timer = C.text({
		parent = body,
		text = "0.0s",
		type = "Title",
		alignX = Enum.TextXAlignment.Right,
		size = UDim2.fromOffset(160, 44),
		position = UDim2.new(1, -18, 0, 6),
		anchor = Vector2.new(1, 0),
	})
	self.starsLabel = C.text({
		parent = body,
		text = "",
		type = "Caption",
		alignX = Enum.TextXAlignment.Right,
		size = UDim2.fromOffset(170, 20),
		position = UDim2.new(1, -18, 0, 52),
		anchor = Vector2.new(1, 0),
		color = Theme.Color.Text.Secondary,
	})
	C.Button({
		parent = body,
		text = "Quit",
		width = 80,
		size = "sm",
		variant = "ghost",
		position = UDim2.new(1, -18, 1, -8),
		anchor = Vector2.new(1, 1),
		onClick = function()
			Net.func("TrialRequest"):InvokeServer("quit")
		end,
	})
	C.Button({
		parent = body,
		text = "Retry",
		width = 80,
		size = "sm",
		variant = "secondary",
		position = UDim2.new(1, -104, 1, -8),
		anchor = Vector2.new(1, 1),
		onClick = function()
			Net.event("Command"):FireServer("reset")
		end,
	})

	self.elapsed = 0
	State.TrialChanged:Connect(function(phase, payload)
		if phase == "start" then
			self:_start(payload)
		elseif phase == "progress" then
			self.progress.set(payload.progress / math.max(payload.target, 1))
			self.objective.Text = ("%s:  %s / %s"):format(
				self.def.objective.text,
				Format.commas(payload.progress),
				Format.commas(payload.target)
			)
			C.pulse(self.objective, 1.1)
			controllers.SoundController:Play("coin", nil, { ui = true })
		elseif phase == "end" then
			outer.Visible = false
			if not payload.aborted then
				self:_result(payload)
			end
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		if outer.Visible and self.def then
			self.elapsed += dt * State:TimeScale()
			local t = self.elapsed
			self.timer.Text = Format.seconds(t)
			local stars = Challenges.starsFor(self.def, t)
			self.timer.TextColor3 = if stars >= 3
				then Theme.Color.Accent.Gold
				elseif stars == 2 then Theme.Color.Text.Primary
				else Theme.Color.State.Warning
		end
	end)
end

function TrialHud:_start(payload)
	self.def = Challenges.TrialsById[payload.id]
	self.elapsed = 0
	self.outer.Visible = true
	self.title.Text = payload.icon .. "  " .. payload.name
	self.objective.Text = ("%s:  0 / %s"):format(payload.text, Format.commas(payload.target))
	self.progress.set(0, nil, true)
	local stars = payload.stars
	self.starsLabel.Text = ("★★★ ≤%ds  ★★ ≤%ds"):format(stars[3], stars[2])
	self.ui:Close()
	self.ui:Toast(payload.icon .. " Trial started: " .. payload.text, "info")
end

function TrialHud:_result(payload)
	local modal = C.Modal({
		parent = self.ui.modals,
		title = if payload.success then "🏆 Trial Complete!" else "⏰ Time's up!",
		size = Vector2.new(720, 460),
	})
	local body = modal.body
	if payload.success then
		local row = C.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 120), Parent = body })
		C.list(
			row,
			Enum.FillDirection.Horizontal,
			Theme.Space.LG,
			Enum.HorizontalAlignment.Center,
			Enum.VerticalAlignment.Center
		)
		for i = 1, 3 do
			local earned = i <= payload.stars
			local star = C.text({
				parent = row,
				text = "★",
				type = "Display",
				textSize = 100,
				alignX = Enum.TextXAlignment.Center,
				size = UDim2.fromOffset(110, 110),
				order = i,
				color = if earned then Theme.Color.Accent.Gold else Theme.Color.State.Disabled,
			})
			local scale = C.new("UIScale", { Scale = 0, Parent = star })
			task.delay(0.25 + i * 0.22, function()
				C.tween(scale, Theme.Motion.Reveal, { Scale = 1 })
				if earned then
					self.C.SoundController:Play("coin", nil, { ui = true, pitch = 0.8 + i * 0.2 })
				end
			end)
		end
		C.text({
			parent = body,
			text = ("Time: %s%s"):format(
				Format.seconds(payload.time),
				if payload.newBest then "   🎉 New best!" else ""
			),
			type = "Heading",
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 34),
			position = UDim2.fromOffset(0, 130),
		})
		local rewards = {}
		if payload.rewards.coins > 0 then
			table.insert(rewards, "+" .. Format.commas(payload.rewards.coins) .. " 🪙")
		end
		if payload.rewards.xp > 0 then
			table.insert(rewards, "+" .. Format.commas(payload.rewards.xp) .. " XP")
		end
		for id, amount in payload.rewards.ingredients do
			local ingredient = Ingredients.ById[id]
			if ingredient then
				table.insert(rewards, ingredient.icon .. " " .. ingredient.name .. " x" .. amount)
			end
		end
		C.text({
			parent = body,
			text = if #rewards > 0 then table.concat(rewards, "    ") else "Beat your stars for more rewards!",
			type = "Body",
			alignX = Enum.TextXAlignment.Center,
			wrap = true,
			size = UDim2.new(1, 0, 0, 60),
			position = UDim2.fromOffset(0, 172),
			color = Theme.Color.Accent.Gold,
		})
		if payload.final then
			C.text({
				parent = body,
				text = "💎 You forged the Philosopher's Stone! Brew the Philosopher's Elixir: Dragon Scale + Stone + Star Shard.",
				type = "Label",
				alignX = Enum.TextXAlignment.Center,
				wrap = true,
				size = UDim2.new(1, 0, 0, 50),
				position = UDim2.fromOffset(0, 232),
				color = Theme.Color.Rarity.Mythic,
			})
		end
		self.C.SoundController:Play("levelup", nil, { ui = true })
	else
		C.text({
			parent = body,
			text = "So close! Try a different potion combo.",
			type = "Heading",
			alignX = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 40),
			position = UDim2.fromOffset(0, 60),
		})
	end
	local buttons = C.new(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 64), Position = UDim2.new(0, 0, 1, -64), Parent = body }
	)
	C.list(buttons, Enum.FillDirection.Horizontal, Theme.Space.MD, Enum.HorizontalAlignment.Center)
	C.Button({
		parent = buttons,
		text = "Retry",
		icon = "🔁",
		width = 180,
		size = "lg",
		order = 1,
		onClick = function()
			modal.close()
			Net.func("TrialRequest"):InvokeServer("start", payload.id)
		end,
	})
	local trial = Challenges.TrialsById[payload.id]
	local nextTrial
	for _, other in Challenges.Trials do
		if trial and other.order == trial.order + 1 then
			nextTrial = other
		end
	end
	if payload.success and nextTrial then
		C.Button({
			parent = buttons,
			text = "Next",
			icon = "➡️",
			width = 180,
			size = "lg",
			variant = "primary",
			order = 2,
			onClick = function()
				modal.close()
				local result = Net.func("TrialRequest"):InvokeServer("start", nextTrial.id)
				if result and not result.ok then
					self.ui:Toast(result.reason or "Locked", "error")
				end
			end,
		})
	end
	C.Button({
		parent = buttons,
		text = "Back to Lab",
		width = 200,
		size = "lg",
		variant = "ghost",
		order = 3,
		onClick = function()
			modal.close()
			Net.func("TrialRequest"):InvokeServer("quit")
		end,
	})
	modal.onClose = function()
		task.delay(0.3, function()
			modal.root:Destroy()
		end)
	end
	modal.open()
end

return TrialHud
