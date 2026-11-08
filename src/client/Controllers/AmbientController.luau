--!nonstrict
-- Ambient life: spinning fans and sigils, scrolling conveyor chevrons, flickering candles, disco
-- lights, golem name/health/status billboards, eyes that follow your cursor, golem voices and
-- rainbow/disco highlights.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Theme = require(script.Parent.Parent.UI.Theme)

local AmbientController = {}

local STATUS_ICONS = {
	burning = "🔥",
	frozen = "🧊",
	levitating = "☁️",
	bouncy = "🟢",
	rocket = "🚀",
	shocked = "⚡",
	wet = "💧",
	hyper = "🌀",
	giant = "⏫",
	tiny = "⏬",
	gravityflip = "🙃",
	ghost = "👻",
	zombie = "🧟",
	golden = "💰",
	magnetic = "🧲",
	disco = "🎶",
	acid = "🧪",
	dragonbreath = "🐉",
	balloons = "🎈",
	sticky = "🍯",
	stinky = "🤢",
	stasis = "⏳",
	ascension = "😇",
}

local spinners = {}
local scrollers = {}
local flickers = {}
local discoLights = {}
local golems = {} :: { [Model]: any }

function AmbientController:Init(controllers)
	self.C = controllers
end

local function watchTag(tag: string, onAdd: (Instance) -> ())
	for _, instance in CollectionService:GetTagged(tag) do
		task.spawn(onAdd, instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(onAdd)
end

local function labOriginX(instance: Instance): number
	local current = instance.Parent
	while current and current ~= workspace do
		local slot = current:GetAttribute("Slot")
		if typeof(slot) == "number" then
			return slot * Config.LabSpacing
		end
		current = current.Parent
	end
	return 0
end

-- ─────────────────────────────── golem billboards ───────────────────────────────

local function buildBillboard(model: Model)
	local head = model:FindFirstChild("Head") :: BasePart?
	if not head then
		return nil
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "GolemTag"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(170, 54)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.8, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 500
	gui.ResetOnSpawn = false
	gui.Parent = model
	local icons = Instance.new("TextLabel")
	icons.Name = "Icons"
	icons.BackgroundTransparency = 1
	icons.Size = UDim2.new(1, 0, 0, 28)
	icons.FontFace = Theme.Font.UI
	icons.TextSize = 24
	icons.Text = ""
	icons.Parent = gui
	local track = Instance.new("Frame")
	track.Name = "Health"
	track.BackgroundColor3 = Theme.Color.Surface.Sunken
	track.BackgroundTransparency = 0.15
	track.BorderSizePixel = 0
	track.Size = UDim2.new(0.7, 0, 0, 10)
	track.Position = UDim2.new(0.15, 0, 0, 34)
	track.Visible = false
	track.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = track
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Color.Text.Outline
	stroke.Thickness = 1.5
	stroke.Parent = track
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = Theme.Color.State.Success
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = track
	local fillCorner = corner:Clone()
	fillCorner.Parent = fill
	return { gui = gui, icons = icons, track = track, fill = fill, lastDamage = 0 }
end

local function refreshIcons(entry)
	local model = entry.model
	local text = {}
	for id, icon in STATUS_ICONS do
		if model:GetAttribute("S_" .. id) then
			table.insert(text, icon)
		end
	end
	table.sort(text)
	if model:GetAttribute("State") == "ko" then
		table.insert(text, 1, "💫")
	end
	entry.tag.icons.Text = table.concat(text, " ")
end

local function refreshHealth(entry)
	local model = entry.model
	local health = model:GetAttribute("Health") or 100
	local max = model:GetAttribute("MaxHealth") or 100
	local fraction = math.clamp(health / max, 0, 1)
	entry.tag.fill.Size = UDim2.fromScale(fraction, 1)
	entry.tag.fill.BackgroundColor3 = if fraction > 0.5
		then Theme.Color.State.Success
		elseif fraction > 0.2 then Theme.Color.State.Warning
		else Theme.Color.State.Danger
end

function AmbientController:_trackGolem(model: Model)
	if golems[model] or not model:GetAttribute("GolemId") then
		return
	end
	local tag = buildBillboard(model)
	if not tag then
		return
	end
	local entry =
		{ model = model, tag = tag, pupils = {}, highlight = nil, lastHealth = model:GetAttribute("Health") or 100 }
	golems[model] = entry
	for _, name in { "PupilL", "PupilR" } do
		local pupil = model:FindFirstChild(name)
		local weld = pupil and pupil:FindFirstChild("PupilWeld") :: Weld?
		if weld then
			table.insert(entry.pupils, { weld = weld, rest = weld.C0 })
		end
	end
	refreshIcons(entry)
	refreshHealth(entry)
	entry.conn = model.AttributeChanged:Connect(function(attribute)
		if attribute == "Health" then
			local health = model:GetAttribute("Health") or 100
			if health < entry.lastHealth then
				tag.lastDamage = os.clock()
			end
			entry.lastHealth = health
			refreshHealth(entry)
		elseif attribute == "State" then
			local state = model:GetAttribute("State")
			local head = model:FindFirstChild("Head") :: BasePart?
			if head and (state == "stunned" or state == "ko") and math.random() < 0.7 then
				local squeaky = model:GetAttribute("Squeaky")
				local scale = model:GetAttribute("Scale") or 1
				local pitch = if squeaky then 1.9 else math.clamp(1.15 / math.sqrt(scale), 0.5, 1.4)
				self.C.SoundController:Play(if state == "ko" then "oof" else "ouch", head.Position, { pitch = pitch })
			end
			refreshIcons(entry)
		elseif attribute:sub(1, 2) == "S_" then
			refreshIcons(entry)
		end
		if attribute == "Disco" or attribute == "Rainbow" or attribute == "S_disco" then
			self:_updateHighlight(entry)
		end
	end)
	self:_updateHighlight(entry)
end

function AmbientController:_updateHighlight(entry)
	local model = entry.model
	local wants = model:GetAttribute("Disco") or model:GetAttribute("Rainbow")
	if wants and not entry.highlight then
		local highlight = Instance.new("Highlight")
		highlight.Name = "RainbowGlow"
		highlight.FillTransparency = if model:GetAttribute("Disco") then 0.35 else 0.55
		highlight.OutlineTransparency = 0.4
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Adornee = model
		highlight.Parent = model
		entry.highlight = highlight
	elseif not wants and entry.highlight then
		entry.highlight:Destroy()
		entry.highlight = nil
	end
end

function AmbientController:_untrack(model: Model)
	local entry = golems[model]
	if entry then
		if entry.conn then
			entry.conn:Disconnect()
		end
		golems[model] = nil
	end
end

function AmbientController:_watchLab()
	if self._labConns then
		for _, conn in self._labConns do
			conn:Disconnect()
		end
	end
	self._labConns = {}
	for model in table.clone(golems) do
		self:_untrack(model)
	end
	local labModel = self.C.State:LabModel()
	local dynamic = labModel and labModel:WaitForChild("Dynamic", 5)
	if not dynamic then
		return
	end
	local function consider(child: Instance)
		if child:IsA("Model") then
			-- Attributes replicate with the instance; wait a frame for children too.
			task.defer(function()
				if child.Parent and child:GetAttribute("GolemId") then
					child:WaitForChild("Head", 3)
					self:_trackGolem(child)
				end
			end)
		end
	end
	for _, child in dynamic:GetChildren() do
		consider(child)
	end
	table.insert(self._labConns, dynamic.ChildAdded:Connect(consider))
	table.insert(
		self._labConns,
		dynamic.ChildRemoved:Connect(function(child)
			if child:IsA("Model") then
				self:_untrack(child)
			end
		end)
	)
end

-- ─────────────────────────────── start ───────────────────────────────

function AmbientController:Start()
	local State = self.C.State
	State.LabChanged:Connect(function(lab, previous)
		if not previous or previous.ownerId ~= lab.ownerId then
			task.spawn(self._watchLab, self)
		end
	end)

	watchTag("Spinner", function(part)
		if part:IsA("BasePart") and part.Anchored then
			spinners[part] = {
				base = part.CFrame,
				speed = part:GetAttribute("SpinSpeed") or 1,
				axis = part:GetAttribute("SpinAxis") or "X",
			}
		end
	end)
	watchTag("Scroller", function(part)
		if part:IsA("BasePart") then
			local originX = labOriginX(part)
			local min = part:GetAttribute("ScrollMin") or 0
			local max = part:GetAttribute("ScrollMax") or 10
			scrollers[part] = {
				base = part.CFrame,
				speed = part:GetAttribute("ScrollSpeed") or 10,
				min = min,
				max = max,
				startLocal = part.Position.X - originX,
			}
		end
	end)
	watchTag("Flicker", function(light)
		if light:IsA("Light") then
			flickers[light] = { base = light.Brightness, seed = math.random() * 100 }
		end
	end)
	watchTag("DiscoLight", function(light)
		if light:IsA("Light") then
			discoLights[light] = math.random()
		end
	end)

	local pupilTimer = 0
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		for part, entry in spinners do
			if not part.Parent then
				spinners[part] = nil
				continue
			end
			local angle = t * entry.speed
			local rotation = if entry.axis == "Y"
				then CFrame.Angles(0, angle, 0)
				elseif entry.axis == "Z" then CFrame.Angles(0, 0, angle)
				else CFrame.Angles(angle, 0, 0)
			part.CFrame = entry.base * rotation
		end
		local timeScale = State:TimeScale()
		for part, entry in scrollers do
			if not part.Parent then
				scrollers[part] = nil
				continue
			end
			entry.offset = (entry.offset or 0) + entry.speed * dt * timeScale
			local travel = entry.max - entry.min
			local localX = (entry.startLocal - entry.min + entry.offset) % travel + entry.min
			part.CFrame = entry.base + Vector3.new(localX - entry.startLocal, 0, 0)
		end
		for light, entry in flickers do
			if not light.Parent then
				flickers[light] = nil
				continue
			end
			light.Brightness = entry.base * (0.8 + 0.3 * (math.noise(t * 7, entry.seed) + 0.5))
		end
		for light, seed in discoLights do
			if not light.Parent then
				discoLights[light] = nil
				continue
			end
			light.Color = Color3.fromHSV((t * 0.6 + seed) % 1, 0.75, 1)
		end
		for _, entry in golems do
			local highlight = entry.highlight
			if highlight then
				local hue = (t * 0.5 + entry.model:GetAttribute("GolemId") * 0.13) % 1
				highlight.FillColor = Color3.fromHSV(hue, 0.8, 1)
				highlight.OutlineColor = Color3.fromHSV((hue + 0.5) % 1, 0.6, 1)
			end
			local tag = entry.tag
			local showHealth = (t - tag.lastDamage) < 3
				or (entry.lastHealth < (entry.model:GetAttribute("MaxHealth") or 100))
			tag.track.Visible = showHealth
		end

		-- Eyes follow the cursor (cheap, 20 Hz).
		pupilTimer -= dt
		if pupilTimer <= 0 then
			pupilTimer = 0.05
			local pointer = self.C.CameraController:ScreenToPlane(self.C.InputController.pointer)
			if pointer then
				for model, entry in golems do
					local head = model:FindFirstChild("Head") :: BasePart?
					if head and model:GetAttribute("Face") ~= "ko" then
						local localTarget = head.CFrame:PointToObjectSpace(pointer)
						local dir = Vector3.new(localTarget.X, localTarget.Y, 0)
						local offset = if dir.Magnitude > 0.01
							then dir.Unit * math.min(dir.Magnitude * 0.02, 0.12)
							else Vector3.zero
						for _, pupil in entry.pupils do
							if pupil.weld.Parent then
								pupil.weld.C0 = pupil.rest * CFrame.new(offset.X, offset.Y, 0)
							end
						end
					end
				end
			end
		end
	end)
end

return AmbientController
