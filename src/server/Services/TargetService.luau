-- Spawns every lane's targets, applies server-owned damage and grants each target's
-- fixed Scrap exactly once. Targets in a lane only ever pay that lane's owner.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Layout = require(Shared.Layout)

local TargetModels = require(script.Parent.Parent.Builders.TargetModels)
local StateService = require(script.Parent.StateService)
local LaneService = require(script.Parent.LaneService)
local WorldService = require(script.Parent.WorldService)
local Analytics = require(script.Parent.Analytics)

local Fx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fx")

local TargetService = {}

-- registry[lane][area][slot] = Model (nil while respawning)
local registry: { [number]: { [number]: { [number]: Model? } } } = {}
local spawnCount: { [string]: number } = {}
local laneFolders: { [number]: Folder } = {}

local function ownerId(lane: number): number
	local owner = LaneService.ownerOf(lane)
	return if owner then owner.UserId else 0
end

local function spawnTarget(lane: number, area: number, slot: number)
	local key = string.format("%d:%d:%d", lane, area, slot)
	spawnCount[key] = (spawnCount[key] or 0) + 1
	local count = spawnCount[key]
	local def = Config.Areas[area]
	local kindIndex = lane * 2 + slot * 3 + count
	local model = TargetModels.build(
		area,
		kindIndex,
		Layout.slotPosition(area, lane, slot),
		lane * 100000 + area * 1000 + slot * 37 + count
	)
	model:SetAttribute("Lane", lane)
	model:SetAttribute("Area", area)
	model:SetAttribute("Slot", slot)
	model:SetAttribute("HP", def.HP)
	model:SetAttribute("MaxHP", def.HP)
	model:SetAttribute("Reward", def.Scrap)
	model:SetAttribute("OwnerId", ownerId(lane))
	model.Parent = laneFolders[lane]
	registry[lane][area][slot] = model
end

function TargetService.init()
	local world = WorldService.get()
	for lane = 1, Layout.Lanes do
		local f = Instance.new("Folder")
		f.Name = "Lane" .. lane
		f.Parent = world.Targets
		laneFolders[lane] = f
		registry[lane] = {}
		for area = 1, 3 do
			registry[lane][area] = {}
			for slot = 1, Layout.slotCount(area) do
				spawnTarget(lane, area, slot)
			end
		end
	end
	local function setOwner(lane: number)
		local id = ownerId(lane)
		for _, areaSlots in registry[lane] do
			for _, model in areaSlots do
				if model then
					model:SetAttribute("OwnerId", id)
				end
			end
		end
	end
	LaneService.Assigned:Connect(function(_, lane)
		setOwner(lane)
	end)
	LaneService.Freed:Connect(setOwner)
end

-- Nearest living target within reach in the player's own lane and unlocked areas.
function TargetService.nearestInReach(session: StateService.Session, position: Vector3): Model?
	local lane = session.Lane
	if not lane then
		return nil
	end
	local best, bestDistance = nil, Config.Combat.Reach
	for area = 1, 3 do
		if StateService.areaUnlocked(session, area) then
			for _, model in registry[lane][area] do
				if model and model.PrimaryPart and not model:GetAttribute("Dead") then
					local d = Layout.reachDistance(position, model.PrimaryPart)
					if d <= bestDistance then
						best, bestDistance = model, d
					end
				end
			end
		end
	end
	return best
end

function TargetService.inReach(session: StateService.Session, model: Model, position: Vector3): boolean
	if not model.Parent or model:GetAttribute("Dead") or not model.PrimaryPart then
		return false
	end
	if
		model:GetAttribute("Lane") ~= session.Lane or not StateService.areaUnlocked(session, model:GetAttribute("Area"))
	then
		return false
	end
	return Layout.reachDistance(position, model.PrimaryPart) <= Config.Combat.Reach
end

local function grantReward(player: Player, session: StateService.Session, area: number)
	local data = session.Data
	local def = Config.Areas[area]
	local payout =
		Economy.payout(def.Scrap, data.Rebirths, session.Passes.DoubleScrap == true, StateService.boostActive(session))
	StateService.addScrap(player, payout, "Smash")
	Analytics.smashIncome(player, payout)
	data.Stats.Destroys += 1
	if area == 3 then
		data.CrusherDestroys += 1
	end
	StateService.rollDaily(data)
	if not data.Daily.Claimed and data.Daily.Progress < Config.Daily.Goal then
		data.Daily.Progress += 1
		if data.Daily.Progress == Config.Daily.Goal then
			StateService.notify(
				player,
				"Daily",
				"Daily contract done!",
				string.format("Claim %d Scrap + a stamp in Daily.", Config.Daily.RewardScrap)
			)
		end
	end
	if not data.Funnel.FirstSmash then
		Analytics.funnel(player, data, "FirstSmash")
		Analytics.badge(player, Config.Badges.FirstSmash)
	end
	return payout
end

-- Applies one hit. The target's lane must belong to the attacker (checked by caller).
function TargetService.damage(player: Player, session: StateService.Session, model: Model, power: number)
	if model:GetAttribute("Dead") or not model.Parent then
		return
	end
	local hp = (model:GetAttribute("HP") :: number) - power
	Fx:FireAllClients("Hit", player.UserId, model, power)
	if hp > 0 then
		model:SetAttribute("HP", hp)
		return
	end
	model:SetAttribute("HP", 0)
	model:SetAttribute("Dead", true)
	local lane, area, slot = model:GetAttribute("Lane"), model:GetAttribute("Area"), model:GetAttribute("Slot")
	local hitbox = model.PrimaryPart :: BasePart
	local payout = grantReward(player, session, area)
	Fx:FireAllClients("Break", player.UserId, hitbox.Position, hitbox.Size, TargetModels.colors(model), area)
	Fx:FireClient(player, "Reward", payout, hitbox.Position + Vector3.new(0, hitbox.Size.Y / 2, 0))
	registry[lane][area][slot] = nil
	model:Destroy()
	task.delay(Config.Areas[area].Respawn, function()
		if registry[lane][area][slot] == nil then
			spawnTarget(lane, area, slot)
		end
	end)
end

return TargetService
