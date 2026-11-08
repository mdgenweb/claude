--!nonstrict
-- Shared server-side registries: labs, which lab each player is viewing, and the mapping from
-- physical parts back to the golem/prop object they belong to.

local World = {
	labs = {} :: { [number]: any }, -- [slot] = Lab
	ownerLab = {} :: { [Player]: any }, -- lab owned by player
	viewLab = {} :: { [Player]: any }, -- lab the player is currently in (own or visiting)
	partToObject = (setmetatable({}, { __mode = "k" }) :: any) :: { [BasePart]: any },
	_nextId = 0,
}

function World.nextId(): number
	World._nextId += 1
	return World._nextId
end

function World.register(object)
	for _, part in object.parts do
		World.partToObject[part] = object
	end
end

function World.unregister(object)
	for _, part in object.parts do
		World.partToObject[part] = nil
	end
end

function World.objectFromPart(part: Instance?)
	if not part or not part:IsA("BasePart") then
		return nil
	end
	return World.partToObject[part]
end

-- Everyone currently looking at a lab (owner + visitors).
function World.viewers(lab): { Player }
	local list = {}
	for player, viewing in World.viewLab do
		if viewing == lab and player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

function World.labOf(player: Player)
	return World.viewLab[player]
end

return World
