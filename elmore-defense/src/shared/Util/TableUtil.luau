--[[
	TableUtil
	Deep copy / reconcile helpers used for profile templates and config defaults.
]]

local TableUtil = {}

function TableUtil.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in value :: any do
		copy[TableUtil.deepCopy(key)] = TableUtil.deepCopy(inner)
	end
	return copy :: any
end

-- Fills missing keys in `target` from `template` (recursively). Existing values are kept.
function TableUtil.reconcile(target: { [any]: any }, template: { [any]: any })
	for key, value in template do
		if target[key] == nil then
			target[key] = TableUtil.deepCopy(value)
		elseif type(value) == "table" and type(target[key]) == "table" and next(value) ~= nil then
			-- Only recurse into dictionary-style templates; arrays are owned by the player data.
			if #value == 0 then
				TableUtil.reconcile(target[key], value)
			end
		end
	end
	return target
end

function TableUtil.count(dict: { [any]: any }): number
	local n = 0
	for _ in dict do
		n += 1
	end
	return n
end

function TableUtil.keys(dict: { [any]: any }): { any }
	local list = {}
	for key in dict do
		table.insert(list, key)
	end
	return list
end

function TableUtil.map<T, U>(list: { T }, fn: (T, number) -> U): { U }
	local out = table.create(#list)
	for index, value in list do
		out[index] = fn(value, index)
	end
	return out
end

function TableUtil.filter<T>(list: { T }, fn: (T) -> boolean): { T }
	local out = {}
	for _, value in list do
		if fn(value) then
			table.insert(out, value)
		end
	end
	return out
end

return TableUtil
