-- Builds the map once at startup and hands out references to its key parts.

local WorldBuilder = require(script.Parent.Parent.Builders.WorldBuilder)

local WorldService = {}

WorldService.world = nil :: WorldBuilder.World?

function WorldService.init()
	WorldService.world = WorldBuilder.build()
end

function WorldService.get(): WorldBuilder.World
	return WorldService.world :: WorldBuilder.World
end

return WorldService
