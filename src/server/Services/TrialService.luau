--!nonstrict
-- Trials: handcrafted objective levels played inside the owner's lab. A trial sets up the room,
-- provides free potions, tracks one objective and awards 1-3 stars based on lab-time.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Challenges = require(Shared.Data.Challenges)

local Systems = script.Parent.Parent.Systems
local World = require(Systems.World)

local TrialService = {}

function TrialService:Init(services)
	self.S = services
end

function TrialService:Start()
	Net.func("TrialRequest").OnServerInvoke = function(player, action, trialId)
		if action == "start" and typeof(trialId) == "string" then
			return self:Begin(player, trialId)
		elseif action == "quit" then
			local lab = World.ownerLab[player]
			if lab and lab.trial then
				self:Abort(lab, "quit")
				self.S.LabService:Reset(lab)
			end
			return { ok = true }
		end
		return { ok = false }
	end
end

function TrialService:TotalStars(data): number
	local total = 0
	for _, record in data.trials do
		total += record.stars or 0
	end
	return total
end

function TrialService:CanStart(player: Player, trial): (boolean, string?)
	local data = self.S.DataService:Get(player)
	if not data then
		return false, "Loading..."
	end
	-- Trials unlock in order.
	for _, other in Challenges.Trials do
		if other.order < trial.order and not data.trials[other.id] then
			return false, "Clear " .. other.name .. " first."
		end
	end
	if trial.requiresStars and self:TotalStars(data) < trial.requiresStars then
		return false, ("Needs %d ★"):format(trial.requiresStars)
	end
	return true
end

local function zoneVisual(lab, zone)
	local model = Instance.new("Model")
	model.Name = "TrialZone_" .. zone.id
	local center = lab.origin + Vector3.new(zone.x, zone.y, 0)
	local function part(props)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		for key, value in props do
			(p :: any)[key] = value
		end
		p.Parent = model
		return p
	end
	if zone.visual == "basket" then
		local wicker = Color3.fromRGB(190, 140, 80)
		part({
			Size = Vector3.new(zone.w, 0.6, 6),
			CFrame = CFrame.new(center + Vector3.new(0, -zone.h / 2, 0)),
			Color = wicker,
			Material = Enum.Material.Fabric,
			CanCollide = true,
			CollisionGroup = "Static",
		})
		for _, side in { -1, 1 } do
			part({
				Size = Vector3.new(0.6, zone.h, 6),
				CFrame = CFrame.new(center + Vector3.new(side * zone.w / 2, 0, 0)),
				Color = wicker,
				Material = Enum.Material.Fabric,
				CanCollide = true,
				CollisionGroup = "Static",
			})
		end
		part({
			Size = Vector3.new(zone.w, zone.h, 0.2),
			CFrame = CFrame.new(center + Vector3.new(0, 0, -3)),
			Color = Color3.fromRGB(150, 100, 60),
			Material = Enum.Material.Fabric,
		})
	elseif zone.visual == "ring" then
		local ring = part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.6, zone.w, zone.w),
			CFrame = CFrame.new(center) * CFrame.Angles(0, math.rad(90), 0),
			Color = Color3.fromRGB(255, 210, 60),
			Material = Enum.Material.Neon,
			Transparency = 0.1,
		})
		part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.7, zone.w - 1.4, zone.w - 1.4),
			CFrame = CFrame.new(center) * CFrame.Angles(0, math.rad(90), 0),
			Color = Color3.fromRGB(40, 30, 60),
			Material = Enum.Material.Glass,
			Transparency = 0.8,
		})
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 220, 120)
		light.Range = 14
		light.Parent = ring
	elseif zone.visual == "target" then
		local colors = {
			Color3.fromRGB(255, 255, 255),
			Color3.fromRGB(230, 50, 50),
			Color3.fromRGB(255, 255, 255),
			Color3.fromRGB(230, 50, 50),
		}
		for i, color in colors do
			local d = zone.h * (1 - (i - 1) * 0.22)
			part({
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.3 + i * 0.05, d, d),
				CFrame = CFrame.new(center + Vector3.new(0, 0, -2 + i * 0.05)) * CFrame.Angles(0, math.rad(90), 0),
				Color = color,
				Material = Enum.Material.SmoothPlastic,
			})
		end
	end
	local glow = part({ Size = Vector3.new(zone.w, zone.h, 1), CFrame = CFrame.new(center), Transparency = 1 })
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Rate = 6
	sparkle.Lifetime = NumberRange.new(1, 1.6)
	sparkle.Speed = NumberRange.new(0.5, 1.5)
	sparkle.Size = NumberSequence.new(0.5, 0)
	sparkle.LightEmission = 1
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 230, 140))
	sparkle.Parent = glow
	model.Parent = lab.effects
	return model
end

function TrialService:Begin(player: Player, trialId: string)
	local trial = Challenges.TrialsById[trialId]
	local lab = World.ownerLab[player]
	if not trial or not lab then
		return { ok = false, reason = "Unknown trial" }
	end
	local ok, reason = self:CanStart(player, trial)
	if not ok then
		return { ok = false, reason = reason }
	end
	if World.viewLab[player] ~= lab then
		self.S.LabService:GoHome(player)
	end
	if lab.trial then
		self:Abort(lab, "restart")
	end
	local LabService = self.S.LabService
	LabService:SetPaused(lab, false)
	LabService:SetTimeScale(lab, 1)
	if lab.mapId ~= trial.map then
		LabService:SetMap(lab, trial.map, { fromTrial = true, noGolem = true })
	else
		LabService:ClearDynamic(lab)
	end
	local data = self.S.DataService:Get(player)
	for _, spec in trial.golems do
		self.S.GolemService:Spawn(lab, spec.skin or (data and data.equippedSkin), Vector3.new(spec.x, spec.y or 0, 0))
	end
	for _, spec in trial.props do
		self.S.PropService:Spawn(lab, spec.id, Vector3.new(spec.x, spec.y or 0, 0))
	end
	local zones = {}
	for _, zone in trial.zones do
		table.insert(zones, { def = zone, model = zoneVisual(lab, zone) })
	end
	lab.trial = {
		id = trial.id,
		def = trial,
		potions = table.clone(trial.potions),
		startClock = lab.clock,
		progress = 0,
		uniques = {},
		zones = zones,
		zoneTimer = 0,
		ended = false,
	}
	self:_send(lab, "start", {
		id = trial.id,
		name = trial.name,
		icon = trial.icon,
		text = trial.objective.text,
		target = trial.objective.target,
		timeLimit = trial.timeLimit,
		stars = trial.stars,
		potions = self:_potionList(lab),
	})
	LabService:BroadcastState(lab)
	return { ok = true }
end

function TrialService:_potionList(lab)
	local list = {}
	for id, count in lab.trial.potions do
		table.insert(list, { id = id, count = if count == math.huge then -1 else count })
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return list
end

function TrialService:SendPotions(lab)
	if lab.trial then
		self:_send(lab, "potions", { potions = self:_potionList(lab) })
	end
end

function TrialService:_send(lab, phase: string, payload)
	local remote = Net.event("Trial")
	for _, viewer in World.viewers(lab) do
		remote:FireClient(viewer, phase, payload)
	end
end

function TrialService:Restart(lab)
	if lab.trial then
		local id = lab.trial.id
		self:Abort(lab, "restart")
		self:Begin(lab.owner, id)
	end
end

function TrialService:Abort(lab, reason: string)
	local trial = lab.trial
	if not trial then
		return
	end
	lab.trial = nil
	for _, zone in trial.zones do
		zone.model:Destroy()
	end
	self:_send(lab, "end", { id = trial.id, success = false, aborted = true, reason = reason })
	self.S.LabService:BroadcastState(lab)
end

-- Gameplay events forwarded by ChallengeService.
function TrialService:Event(player: Player, event: string, value: number, extra)
	local lab = World.ownerLab[player]
	local trial = lab and lab.trial
	if not trial or trial.ended then
		return
	end
	local objective = trial.def.objective
	if objective.event ~= event then
		return
	end
	if objective.filter and objective.filter ~= (extra.status or extra.zone) then
		return
	end
	if objective.unique then
		local key = extra.golem
		if key == nil or trial.uniques[key] then
			return
		end
		trial.uniques[key] = true
		trial.progress += 1
	elseif objective.mode == "max" then
		trial.progress = math.max(trial.progress, math.floor(value))
	else
		trial.progress += value
	end
	self:_send(lab, "progress", { progress = math.min(trial.progress, objective.target), target = objective.target })
	if trial.progress >= objective.target then
		self:_complete(lab)
	end
end

function TrialService:_complete(lab)
	local trial = lab.trial
	if not trial or trial.ended then
		return
	end
	trial.ended = true
	local player = lab.owner
	local def = trial.def
	local elapsed = lab.clock - trial.startClock
	local stars = Challenges.starsFor(def, elapsed)
	local data = self.S.DataService:Get(player)
	local rewards = { coins = 0, xp = 0, ingredients = {}, skin = nil }
	local firstClear = false
	local newBest = false
	if data then
		local record = data.trials[def.id]
		local previousStars = if record then record.stars else 0
		firstClear = record == nil
		if not record or elapsed < record.best then
			newBest = true
		end
		data.trials[def.id] = {
			stars = math.max(previousStars, stars),
			best = if record then math.min(record.best, elapsed) else elapsed,
		}
		if firstClear then
			rewards.coins = def.reward.coins
			rewards.xp = def.reward.xp
			for id, amount in def.reward.ingredients or {} do
				data.ingredients[id] = (data.ingredients[id] or 0) + amount
				rewards.ingredients[id] = amount
			end
			if def.reward.skin then
				data.skins[def.reward.skin] = true
				rewards.skin = def.reward.skin
			end
		elseif stars > previousStars then
			rewards.coins = 60 * (stars - previousStars)
			rewards.xp = 40 * (stars - previousStars)
		end
		if rewards.coins > 0 then
			self.S.EconomyService:AddCoins(player, rewards.coins, "trial")
		end
		if rewards.xp > 0 then
			self.S.EconomyService:AddXp(player, rewards.xp)
		end
		self.S.DataService:Replicate(player, "trials", "ingredients", "skins")
	end
	for _, zone in trial.zones do
		zone.model:Destroy()
	end
	lab.trial = nil
	self:_send(lab, "end", {
		id = def.id,
		success = true,
		stars = stars,
		time = elapsed,
		firstClear = firstClear,
		newBest = newBest,
		rewards = rewards,
		final = def.final == true,
	})
	self.S.LabService:FX(lab, "confetti", { p = lab.origin + Vector3.new(0, lab.map.height * 0.6, 0) })
	self.S.LabService:BroadcastState(lab)
end

function TrialService:_fail(lab)
	local trial = lab.trial
	if not trial then
		return
	end
	trial.ended = true
	for _, zone in trial.zones do
		zone.model:Destroy()
	end
	lab.trial = nil
	self:_send(lab, "end", { id = trial.id, success = false, timeout = true })
	self.S.LabService:BroadcastState(lab)
end

function TrialService:Update(lab, _dt: number, labDt: number)
	local trial = lab.trial
	if not trial or trial.ended then
		return
	end
	local elapsed = lab.clock - trial.startClock
	if elapsed > trial.def.timeLimit then
		self:_fail(lab)
		return
	end
	if labDt <= 0 or #trial.zones == 0 then
		return
	end
	trial.zoneTimer -= labDt
	if trial.zoneTimer > 0 then
		return
	end
	trial.zoneTimer = 0.1
	for _, zone in trial.zones do
		local def = zone.def
		local center = lab.origin + Vector3.new(def.x, def.y, 0)
		for _, golem in lab.golems do
			local torso = golem.byName.Torso
			if torso and not golem.grabbedBy then
				local offset = torso.Position - center
				if math.abs(offset.X) < def.w / 2 and math.abs(offset.Y) < def.h / 2 then
					self:Event(lab.owner, "zone", 1, { zone = def.id, golem = golem.id })
					if not lab.trial then
						return
					end
				end
			end
		end
	end
end

return TrialService
