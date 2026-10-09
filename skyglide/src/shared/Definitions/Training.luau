--!strict
-- Training pads. Standing on a pad and tapping (or AUTO) gives Skill = Multiplier x Skill
-- multiplier per rep. Matches the reference row: 1x/4x/10x/20x gated by 0/2/4/6 rebirths, plus
-- "ALL WORLDS" pads unlocked by game passes (3x/15x/50x in world 1, scaled in later worlds).
export type Pad = {
	Id: string,
	World: number,
	Slot: number, -- position in the row (Config/Map)
	Multiplier: number,
	Rebirths: number, -- rebirths required (0 = open)
	PassKey: string?, -- game pass that unlocks it in every world
	Color: string,
	Accent: string,
}

local list: { Pad } = {}
local byId: { [string]: Pad } = {}

local ROWS = {
	-- { base multipliers }, { rebirth gates }, pass base
	[1] = { mults = { 1, 4, 10, 20 }, gates = { 0, 2, 4, 6 }, passBase = 1 },
	[2] = { mults = { 40, 80, 160, 300 }, gates = { 1, 3, 5, 7 }, passBase = 40 },
	[3] = { mults = { 600, 1200, 2500, 5000 }, gates = { 4, 6, 8, 10 }, passBase = 600 },
	[4] = { mults = { 10000, 25000, 60000, 150000 }, gates = { 8, 11, 14, 18 }, passBase = 10000 },
}

local PAD_COLORS = { "#A0703C", "#3FA9FF", "#B65CFF", "#FF5A5A" }
local PASS_PADS = {
	{ key = "Pad3x", mult = 3, color = "#E9EEF5", accent = "#3FA9FF" },
	{ key = "Pad15x", mult = 15, color = "#FF7F50", accent = "#FFFFFF" },
	{ key = "Pad50x", mult = 50, color = "#FFC53D", accent = "#FF4F7B" },
}

for world, row in ROWS do
	for i, mult in row.mults do
		local pad: Pad = {
			Id = string.format("w%d_pad%d", world, i),
			World = world,
			Slot = i,
			Multiplier = mult,
			Rebirths = row.gates[i],
			Color = PAD_COLORS[i],
			Accent = "#FFFFFF",
		}
		table.insert(list, pad)
		byId[pad.Id] = pad
	end
	for j, pass in PASS_PADS do
		local pad: Pad = {
			Id = string.format("w%d_pass%d", world, j),
			World = world,
			Slot = #row.mults + j,
			Multiplier = pass.mult * row.passBase,
			Rebirths = 0,
			PassKey = pass.key,
			Color = pass.color,
			Accent = pass.accent,
		}
		table.insert(list, pad)
		byId[pad.Id] = pad
	end
end

local Training = {}
Training.List = list
Training.SlotsPerWorld = 7

function Training.Get(id: string): Pad?
	return byId[id]
end

function Training.ForWorld(world: number): { Pad }
	local out = {}
	for _, pad in list do
		if pad.World == world then
			table.insert(out, pad)
		end
	end
	table.sort(out, function(a, b)
		return a.Slot < b.Slot
	end)
	return out
end

return Training
