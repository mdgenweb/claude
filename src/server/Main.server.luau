-- Pick Your Mech! server entry point. Services start in dependency order.

local Services = script.Parent.Services

local order = {
	"DataService",
	"WorldService",
	"StateService",
	"LaneService",
	"MechService",
	"TargetService",
	"CombatService",
	"ShopService",
	"NetService",
}

for _, name in order do
	local service = require(Services:WaitForChild(name))
	if service.init then
		local started = os.clock()
		service.init()
		if os.clock() - started > 0.5 then
			print(string.format("[PickYourMech] %s took %.2fs", name, os.clock() - started))
		end
	end
end

require(Services.StateService).start()
print("[PickYourMech] Server ready")
