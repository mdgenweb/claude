--[[
	Grades
	Report-card stat grades. Each unit instance rolls three: Damage, Range, SPA (attack speed).
	Rerolled with Report Cards at Principal Brown's Office.
]]

export type Grade = { id: string, multiplier: number, weight: number, color: Color3 }

local list: { Grade } = {
	{ id = "D", multiplier = 0.88, weight = 6, color = Color3.fromRGB(150, 150, 160) },
	{ id = "D+", multiplier = 0.92, weight = 8, color = Color3.fromRGB(150, 150, 160) },
	{ id = "C-", multiplier = 0.96, weight = 11, color = Color3.fromRGB(110, 200, 120) },
	{ id = "C", multiplier = 1.00, weight = 14, color = Color3.fromRGB(110, 200, 120) },
	{ id = "C+", multiplier = 1.03, weight = 13, color = Color3.fromRGB(110, 200, 120) },
	{ id = "B-", multiplier = 1.06, weight = 12, color = Color3.fromRGB(79, 183, 242) },
	{ id = "B", multiplier = 1.09, weight = 11, color = Color3.fromRGB(79, 183, 242) },
	{ id = "B+", multiplier = 1.12, weight = 9, color = Color3.fromRGB(79, 183, 242) },
	{ id = "A-", multiplier = 1.15, weight = 7, color = Color3.fromRGB(176, 108, 255) },
	{ id = "A", multiplier = 1.18, weight = 5, color = Color3.fromRGB(176, 108, 255) },
	{ id = "A+", multiplier = 1.22, weight = 3, color = Color3.fromRGB(255, 196, 46) },
	{ id = "S", multiplier = 1.28, weight = 1, color = Color3.fromRGB(255, 92, 170) },
}

local byId: { [string]: Grade } = {}
for index, grade in list do
	byId[grade.id] = grade;
	(grade :: any).rank = index
end

local Grades = {
	list = list,
	byId = byId,
	STATS = { "Damage", "Range", "SPA" },
	STAT_LABELS = { Damage = "Damage", Range = "Range", SPA = "Speed" },
}

function Grades.multiplier(id: string?): number
	local grade = id and byId[id]
	return if grade then grade.multiplier else 1
end

function Grades.rank(id: string?): number
	local grade = id and byId[id]
	return if grade then (grade :: any).rank else 4
end

function Grades.entries(): { { id: string, weight: number } }
	local entries = {}
	for _, grade in list do
		table.insert(entries, { id = grade.id, weight = grade.weight })
	end
	return entries
end

return Grades
