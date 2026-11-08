--!nonstrict
-- Brewing (recipe resolution, discovery, mastery) and using potions: thrown bottles are simulated
-- server-side as ballistic projectiles (lab-time integrated, so slow-mo and pause just work) and
-- rendered client-side from the launch parameters.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Potions = require(Shared.Data.Potions)
local Ingredients = require(Shared.Data.Ingredients)
local Recipes = require(Shared.Data.Recipes)
local Rarity = require(Shared.Data.Rarity)

local Systems = script.Parent.Parent.Systems
local World = require(Systems.World)

local PotionService = {}

local recipeIndex = Recipes.buildIndex(Potions.List)
PotionService.RecipeIndex = recipeIndex

function PotionService:Init(services)
	self.S = services
	self._lastUse = {}
	self._lastBrew = {}
end

function PotionService:Start()
	Net.func("Brew").OnServerInvoke = function(player, ids)
		return self:Brew(player, ids)
	end
	Net.event("Use").OnServerEvent:Connect(function(player, payload)
		local ok, err = pcall(self.Use, self, player, payload)
		if not ok then
			warn("[PotionService] use error:", err)
		end
	end)
end

-- ─────────────────────────────── inventory helpers ───────────────────────────────

function PotionService:IsMastered(data, potionId: string): boolean
	return (data.brewCount[potionId] or 0) >= Config.Potions.MasteryBrews
end

-- Returns available, infinite, potency.
function PotionService:Availability(player: Player, lab, potionId: string): (boolean, boolean, number)
	local data = self.S.DataService:Get(player)
	if not data then
		return false, false, 1
	end
	if lab and lab.trial then
		local provided = lab.trial.potions[potionId]
		if lab.owner ~= player then
			return false, false, 1
		end
		if provided and provided > 0 then
			return true, provided == math.huge, 1
		end
		return false, false, 1
	end
	if self:IsMastered(data, potionId) then
		return true, true, Config.Potions.MasteryPotency
	end
	return (data.potions[potionId] or 0) > 0, false, 1
end

local function consume(self, player: Player, lab, potionId: string)
	if lab and lab.trial then
		local provided = lab.trial.potions[potionId]
		if provided and provided ~= math.huge then
			lab.trial.potions[potionId] = provided - 1
			self.S.TrialService:SendPotions(lab)
		end
		return
	end
	local data = self.S.DataService:Get(player)
	if data and not self:IsMastered(data, potionId) then
		data.potions[potionId] = math.max(0, (data.potions[potionId] or 0) - 1)
		if data.potions[potionId] == 0 then
			data.potions[potionId] = nil
		end
		self.S.DataService:Replicate(player, "potions")
	end
end

-- ─────────────────────────────── brewing ───────────────────────────────

function PotionService:Brew(player: Player, ids: any)
	local data = self.S.DataService:Get(player)
	if not data then
		return { ok = false, reason = "Still loading..." }
	end
	if typeof(ids) ~= "table" or #ids < Recipes.MinIngredients or #ids > Recipes.MaxIngredients then
		return { ok = false, reason = "Add 2 or 3 ingredients." }
	end
	local clean = {}
	for i = 1, #ids do
		local id = ids[i]
		if typeof(id) ~= "string" or not Ingredients.ById[id] then
			return { ok = false, reason = "Unknown ingredient." }
		end
		table.insert(clean, id)
	end
	local now = os.clock()
	if now - (self._lastBrew[player] or 0) < 0.8 then
		return { ok = false, reason = "The cauldron is still bubbling!" }
	end
	self._lastBrew[player] = now
	if not Recipes.canAfford(data.ingredients, clean) then
		return { ok = false, reason = "You don't have those ingredients." }
	end
	for id, amount in Recipes.requirements(clean) do
		data.ingredients[id] -= amount
		if data.ingredients[id] <= 0 then
			data.ingredients[id] = nil
		end
	end

	local potionId = Recipes.resolve(recipeIndex, clean) or Potions.FallbackId
	local potion = Potions.ById[potionId]
	local bottles = Config.Potions.BottlesPerBrew
	if self.S.ShopService:HasPass(player, "Satchel") then
		bottles += Config.Potions.SatchelBonus
	end
	data.potions[potionId] = (data.potions[potionId] or 0) + bottles
	data.brewCount[potionId] = (data.brewCount[potionId] or 0) + 1
	data.stats.brews += 1

	local discovered = data.discovered[potionId] == nil
	local rewardXp, rewardCoins = 6, 0
	if discovered then
		data.discovered[potionId] = os.time()
		local rarity = Rarity[potion.rarity]
		if potionId ~= Potions.FallbackId and rarity then
			rewardXp += rarity.discoverXp
			rewardCoins += rarity.discoverCoins
		end
	end
	local mastered = data.brewCount[potionId] == Config.Potions.MasteryBrews

	local hint
	if potionId == Potions.FallbackId then
		local closest = Recipes.closestUndiscovered(Potions.List, data.discovered, clean)
		if closest then
			hint = Potions.ById[closest].hint
		end
	end

	self.S.DataService:Replicate(player, "ingredients", "potions", "brewCount", "discovered", "stats")
	if rewardCoins > 0 then
		self.S.EconomyService:AddCoins(player, rewardCoins, "discover")
	end
	self.S.EconomyService:AddXp(player, rewardXp)
	self.S.ChallengeService:Event(player, "brew", 1, { potion = potionId })
	if discovered and potionId ~= Potions.FallbackId then
		self.S.ChallengeService:Event(player, "discover", 1, { potion = potionId })
		self.S.ShopService:OnDiscovery(player, potionId)
	end

	local lab = World.viewLab[player]
	if lab then
		self.S.LabService:FX(lab, "brew", { p = lab.origin + lab.layout.cauldron, c = potion.color, pid = potionId, who = player.UserId })
	end
	return {
		ok = true,
		potionId = potionId,
		discovered = discovered and potionId ~= Potions.FallbackId,
		mastered = mastered,
		bottles = bottles,
		hint = hint,
		xp = rewardXp,
		coins = rewardCoins,
	}
end

-- ─────────────────────────────── using items ───────────────────────────────

local function finite(n: any): boolean
	return typeof(n) == "number" and n == n and n > -1e6 and n < 1e6
end

function PotionService:Use(player: Player, payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	local kind, id = payload.kind, payload.id
	if typeof(kind) ~= "string" or typeof(id) ~= "string" or not finite(payload.x) or not finite(payload.y) then
		return
	end
	local lab = World.viewLab[player]
	if not lab or lab.destroyed then
		return
	end
	local now = os.clock()
	if now - (self._lastUse[player] or 0) < Config.Potions.ThrowCooldown then
		return
	end
	self._lastUse[player] = now

	-- Clamp the target into the room (local coordinates).
	local lx = math.clamp(payload.x - lab.origin.X, lab.minX + 1, lab.maxX - 1)
	local ly = math.clamp(payload.y - lab.origin.Y, 0.5, lab.map.height - 1)
	local target = lab.origin + Vector3.new(lx, ly, 0)
	self.S.LabService:MarkAction(lab, player)

	if kind == "potion" then
		local potion = Potions.ById[id]
		if not potion then
			return
		end
		local available, _infinite, potency = self:Availability(player, lab, id)
		if not available then
			self.S.ShopService:Notify(player, "toast", { text = "Out of " .. potion.name .. "! Brew more at the cauldron.", kind = "error" })
			return
		end
		local mode = if payload.mode == "feed" then "feed" else "throw"
		if mode == "feed" then
			local golem
			local part = payload.target
			if typeof(part) == "Instance" then
				local object = World.objectFromPart(part)
				if object and object.kind == "golem" and object.lab == lab then
					golem = object
				end
			end
			golem = golem or self.S.GolemService:Nearest(lab, target, 7)
			if golem then
				consume(self, player, lab, id)
				self:_feed(player, lab, golem, potion, potency)
				return
			end
		end
		if self:_countProjectiles(lab) >= Config.MaxProjectiles then
			return
		end
		consume(self, player, lab, id)
		self:_throw(player, lab, potion, target, potency)
		local data = self.S.DataService:Get(player)
		if data then
			data.stats.potionsUsed += 1
		end
	elseif kind == "golem" then
		if lab.trial then
			self.S.ShopService:Notify(player, "toast", { text = "Spawning is disabled during trials.", kind = "error" })
			return
		end
		local feetY = math.max(0, ly - 4.6)
		self.S.LabService:SpawnGolemFor(player, lab, id, Vector3.new(lx, feetY, 0))
	elseif kind == "prop" then
		if lab.trial then
			self.S.ShopService:Notify(player, "toast", { text = "Spawning is disabled during trials.", kind = "error" })
			return
		end
		self.S.PropService:SpawnFor(player, lab, id, Vector3.new(lx, ly, 0))
	end
end

function PotionService:_countProjectiles(lab): number
	local n = 0
	for _ in lab.projectiles do
		n += 1
	end
	return n
end

-- Lobs a bottle from just below the ceiling so it lands exactly on the target.
function PotionService:_throw(player: Player, lab, potion, target: Vector3, potency: number)
	local localX = target.X - lab.origin.X
	local side = if localX > 0 then -1 else 1
	local originLocal = Vector3.new(
		math.clamp(localX + side * 16, lab.minX + 2, lab.maxX - 2),
		math.min(lab.map.height - 3, (target.Y - lab.origin.Y) + 26),
		0
	)
	local origin = lab.origin + originLocal
	local g = Workspace.Gravity * lab.map.gravityScale
	local gravity = Vector3.new(0, -g, 0)
	local distance = (target - origin).Magnitude
	local flight = math.clamp(distance / 70, 0.38, 0.75)
	local velocity = (target - origin - gravity * (0.5 * flight * flight)) / flight
	-- Velocity is in studs per lab-second; Update integrates with lab time (dt × timeScale), so
	-- slow motion and pause affect flight without changing the trajectory.
	local projectile = {
		id = World.nextId(),
		potion = potion,
		owner = player,
		position = origin,
		velocity = velocity,
		gravity = gravity,
		age = 0,
		potency = potency,
	}
	lab.projectiles[projectile.id] = projectile
	self.S.LabService:FX(lab, "throw", { id = projectile.id, o = origin, v = velocity, g = g, pid = potion.id })
end

function PotionService:_feed(player: Player, lab, golem, potion, potency: number)
	local torso = golem.byName.Torso
	self.S.LabService:FX(lab, "feed", { golem = golem.id, pid = potion.id, p = torso and torso.Position })
	local data = self.S.DataService:Get(player)
	if data then
		data.stats.potionsUsed += 1
	end
	task.delay(0.55, function()
		if golem.dead or lab.destroyed then
			return
		end
		local at = golem.byName.Torso and golem.byName.Torso.Position or lab.origin
		self.S.EffectsService:ApplyPotion(lab, potion, at, { mode = "feed", target = golem, source = player, potency = potency })
	end)
end

function PotionService:_shatter(lab, projectile, position: Vector3, normal: Vector3?, hitPart: Instance?)
	lab.projectiles[projectile.id] = nil
	self.S.LabService:FX(lab, "shatter", { id = projectile.id, p = position, n = normal or Vector3.yAxis, pid = projectile.potion.id })
	self.S.EffectsService:ApplyPotion(lab, projectile.potion, position, {
		mode = "throw",
		source = projectile.owner,
		potency = projectile.potency,
		normal = normal,
		hitPart = hitPart,
	})
end

-- Ballistic integration in lab time with a raycast per step for hit detection.
function PotionService:Update(lab, _dt: number, labDt: number)
	if labDt <= 0 then
		return
	end
	for _, projectile in table.clone(lab.projectiles) do
		if not lab.projectiles[projectile.id] then
			continue
		end
		local velocity = projectile.velocity
		local step = velocity * labDt + projectile.gravity * (0.5 * labDt * labDt)
		local hit = Workspace:Raycast(projectile.position, step, lab.worldRayParams)
		projectile.age += labDt
		if hit then
			self:_shatter(lab, projectile, hit.Position, hit.Normal, hit.Instance)
		else
			projectile.position += step
			projectile.velocity = velocity + projectile.gravity * labDt
			local p = projectile.position - lab.origin
			if projectile.age > 4 or p.Y < -5 or p.X < lab.minX - 5 or p.X > lab.maxX + 5 then
				self:_shatter(lab, projectile, projectile.position, nil, nil)
			end
		end
	end
end

return PotionService
