--!nonstrict
-- First-session coach: grab → fling → open cauldron → brew Inferno Brew → throw it → heal.
-- Progress is saved in settings.tutorial so it never repeats once finished.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local Theme = require(script.Parent.Theme)
local C = require(script.Parent.Components)

local Tutorial = {}

local DONE = 99

local STEPS = {
	{
		id = "grab",
		text = "👋 Meet Clayton, your test golem! Click and DRAG him to grab him.",
		touch = "👋 Meet Clayton, your test golem! Touch and drag him to grab him.",
	},
	{ id = "fling", text = "Now FLING him! Drag fast and let go. 🤾" },
	{
		id = "openBrew",
		text = "Click the bubbling cauldron, or press B, to start brewing. 🧪",
		touch = "Tap the 🧪 Brew button to open the cauldron.",
	},
	{ id = "brewInferno", text = "Add 🔥 Ember Root twice, then press BREW!" },
	{
		id = "use",
		text = "Inferno Brew is ready! RIGHT-CLICK near Clayton to throw it. 🔥",
		touch = "Inferno Brew is ready! Tap near Clayton to throw it. 🔥",
	},
	{ id = "heal", text = "Ouch! Press H, or the 💖 button, to heal everyone." },
	{ id = "done", text = "You're a natural! Find all 31 potions in the Codex (C) and beat the Trials (J). 🏆" },
}

function Tutorial:Mount(ui, controllers)
	self.ui, self.C = ui, controllers
	local outer, card = C.card({
		parent = ui.hud,
		size = UDim2.fromOffset(470, 132),
		position = UDim2.new(0, 22, 1, -150),
		anchor = Vector2.new(0, 1),
		radius = Theme.Radius.LG,
		stroke = Theme.Color.Stroke.Gold,
		elevation = "E2",
	})
	outer.Visible = false
	self.outer = outer
	C.text({
		parent = card,
		text = "🧙",
		type = "Display",
		textSize = 54,
		alignX = Enum.TextXAlignment.Center,
		size = UDim2.fromOffset(80, 132),
		outline = false,
	})
	self.label = C.text({
		parent = card,
		text = "",
		type = "Body",
		textSize = 19,
		wrap = true,
		size = UDim2.new(1, -100, 0, 80),
		position = UDim2.fromOffset(84, 10),
	})
	self.dots = C.text({
		parent = card,
		text = "",
		type = "Caption",
		size = UDim2.fromOffset(200, 24),
		position = UDim2.new(0, 84, 1, -32),
		color = Theme.Color.Accent.Gold,
	})
	self.skip = C.Button({
		parent = card,
		text = "Skip",
		variant = "ghost",
		size = "sm",
		width = 90,
		position = UDim2.new(1, -12, 1, -10),
		anchor = Vector2.new(1, 1),
		onClick = function()
			self:Finish()
		end,
	})
	self.step = nil

	local function advance(id: string)
		if self.step and STEPS[self.step] and STEPS[self.step].id == id then
			self:Begin(self.step + 1)
		end
	end
	controllers.GrabController.Grabbed:Connect(function()
		advance("grab")
	end)
	controllers.GrabController.Released:Connect(function(speed)
		if speed > 45 then
			advance("fling")
		end
	end)
	ui.PanelOpened:Connect(function(name)
		if name == "brew" then
			advance("openBrew")
		end
	end)
	controllers.State.Changed:Connect(function(key)
		local data = controllers.State.data
		if (key == "discovered" or key == "brewCount") and data and data.discovered.inferno_brew then
			advance("brewInferno")
		end
	end)
	controllers.ToolController.Used:Connect(function()
		advance("use")
	end)
	controllers.InputController.Action:Connect(function(action)
		if action == "heal" then
			advance("heal")
		end
	end)

	local function maybeStart()
		local data = controllers.State.data
		if data and self.step == nil then
			local saved = data.settings.tutorial or 0
			if saved < #STEPS then
				task.delay(2, function()
					self:Begin(math.max(1, saved))
				end)
			end
		end
	end
	controllers.State.Ready:Connect(maybeStart)
	if controllers.State.ready then
		maybeStart()
	end
end

function Tutorial:Begin(step: number)
	if step > #STEPS then
		self:Finish()
		return
	end
	self.step = step
	local spec = STEPS[step]
	self.label.Text = if self.ui.touch and spec.touch then spec.touch else spec.text
	local dots = {}
	for i = 1, #STEPS do
		table.insert(dots, if i <= step then "●" else "○")
	end
	self.dots.Text = table.concat(dots, " ")
	self.outer.Visible = true
	C.pulse(self.outer, 1.06)
	Net.event("Settings"):FireServer("tutorial", step)
	if spec.id == "brewInferno" then
		-- Pre-fill the cauldron hint by selecting nothing; the brew panel shows the recipe book.
		self.C.State:Select(nil)
	end
	if spec.id == "done" then
		self.C.SoundController:Play("reward", nil, { ui = true })
		self.skip.setText("Got it!")
		task.delay(9, function()
			if self.step == step then
				self:Finish()
			end
		end)
	else
		self.skip.setText("Skip")
		if step > 1 then
			self.C.SoundController:Play("coin", nil, { ui = true })
		end
	end
end

function Tutorial:Finish()
	self.step = DONE
	self.outer.Visible = false
	Net.event("Settings"):FireServer("tutorial", DONE)
end

return Tutorial
