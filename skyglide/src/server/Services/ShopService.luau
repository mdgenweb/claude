--!strict
-- Gliders (throwables), relic equip and trails. Wins are spent atomically on the server; the
-- client only names what it wants.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gliders = require(Shared.Definitions.Gliders)
local Relics = require(Shared.Definitions.Relics)
local Trails = require(Shared.Definitions.Trails)
local Map = require(Shared.Config.Map)
local Remotes = require(Shared.Net.Remotes)
local Format = require(Shared.Util.Format)

local Server = script.Parent.Parent
local Guard = require(Server.Util.Guard)
local DataService = require(script.Parent.DataService)
local StatService = require(script.Parent.StatService)
local MapService = require(script.Parent.MapService)

local ShopService = {}

local registry: { [string]: any } = {}

local PEDESTAL_REACH = 40

local function refreshCharacter(player: Player)
	local character = registry.CharacterService
	if character then
		character.Refresh(player)
	end
end

local function pedestalPosition(glider: Gliders.Glider): Vector3
	local index = 0
	for i, g in Gliders.ForWorld(glider.World) do
		if g.Id == glider.Id then
			index = i
			break
		end
	end
	return Map.Origin(glider.World) + Map.PedestalPosition(index)
end

local function buyGlider(player: Player, id: any): { [string]: any }
	if not Gliders.Exists(id) then
		return { ok = false, error = "Unknown glider." }
	end
	local glider = Gliders.Get(id) :: Gliders.Glider
	local profile = DataService.Get(player)
	if not profile then
		return { ok = false, error = "Still loading..." }
	end
	if profile.Gliders[glider.Id] then
		return { ok = false, error = "You already own this glider." }
	end
	if not profile.Worlds[tostring(glider.World)] then
		return { ok = false, error = "Unlock that world first!" }
	end
	if not MapService.Near(player, pedestalPosition(glider), PEDESTAL_REACH) then
		return { ok = false, error = "Walk up to the pedestal to buy it." }
	end
	if profile.Wins < glider.Price then
		return { ok = false, error = string.format("You need %s more Wins!", Format.Short(glider.Price - profile.Wins)) }
	end
	if not StatService.SpendWins(player, glider.Price) then
		return { ok = false, error = "Not enough Wins!" }
	end
	local equipped = false
	DataService.Update(player, function(p)
		p.Gliders[glider.Id] = true
		local current = Gliders.Get(p.Glider)
		if p.Relic == "" and (not current or glider.SkillPerRing > current.SkillPerRing) then
			p.Glider = glider.Id
			equipped = true
		end
		return true
	end)
	refreshCharacter(player)
	local tutorial = registry.TutorialService
	if tutorial then
		tutorial.Event(player, "BuyGlider")
	end
	return { ok = true, message = glider.Name .. (if equipped then " bought and equipped!" else " bought!") }
end

local function equipThrowable(player: Player, id: any): { [string]: any }
	if type(id) ~= "string" or #id > 48 then
		return { ok = false, error = "Unknown item." }
	end
	local profile = DataService.Get(player)
	if not profile then
		return { ok = false, error = "Still loading..." }
	end
	if registry.FlightService and registry.FlightService.IsFlying(player) then
		return { ok = false, error = "Wait until your glider lands." }
	end
	local relicId = string.match(id, "^relic:(.+)$")
	if relicId then
		if not Relics.Exists(relicId) or not profile.Relics[relicId] then
			return { ok = false, error = "You don't own that relic." }
		end
		DataService.Update(player, function(p)
			p.Relic = relicId
			return true
		end)
	elseif id == "relic:" or id == "norelic" then
		DataService.Update(player, function(p)
			p.Relic = ""
			return true
		end)
	else
		if not Gliders.Exists(id) or not profile.Gliders[id] then
			return { ok = false, error = "You don't own that glider." }
		end
		DataService.Update(player, function(p)
			p.Glider = id
			p.Relic = ""
			return true
		end)
	end
	refreshCharacter(player)
	return { ok = true }
end

local function trailAction(player: Player, action: any, id: any): { [string]: any }
	local profile = DataService.Get(player)
	if not profile then
		return { ok = false, error = "Still loading..." }
	end
	if action == "Unequip" then
		DataService.Update(player, function(p)
			p.Trail = ""
			return true
		end)
		refreshCharacter(player)
		return { ok = true }
	end
	if not Trails.Exists(id) then
		return { ok = false, error = "Unknown trail." }
	end
	local trail = Trails.Get(id) :: Trails.Trail
	if action == "Buy" then
		if profile.Trails[trail.Id] then
			return { ok = false, error = "You already own this trail." }
		end
		if not StatService.SpendWins(player, trail.Price) then
			return { ok = false, error = string.format("You need %s more Wins!", Format.Short(math.max(0, trail.Price - profile.Wins))) }
		end
		DataService.Update(player, function(p)
			p.Trails[trail.Id] = true
			p.Trail = trail.Id
			return true
		end)
		refreshCharacter(player)
		return { ok = true, message = trail.Name .. " equipped!" }
	elseif action == "Equip" then
		if not profile.Trails[trail.Id] then
			return { ok = false, error = "Buy this trail first." }
		end
		DataService.Update(player, function(p)
			p.Trail = trail.Id
			return true
		end)
		refreshCharacter(player)
		return { ok = true }
	end
	return { ok = false, error = "Unknown action." }
end

function ShopService.Init(reg: { [string]: any })
	registry = reg
end

function ShopService.Start()
	Guard.OnInvoke(Remotes.Function("RequestBuyThrowable"), 3, 5, buyGlider)
	Guard.OnInvoke(Remotes.Function("RequestEquipThrowable"), 3, 5, equipThrowable)
	Guard.OnInvoke(Remotes.Function("RequestTrailAction"), 3, 5, trailAction)
end

return ShopService
