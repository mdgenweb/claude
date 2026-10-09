--!strict
-- Runtime validators for untrusted remote arguments. Every server remote handler uses these.
local Validate = {}

function Validate.String(v: any, maxLen: number?): boolean
	return type(v) == "string" and #v <= (maxLen or 64) and utf8.len(v) ~= nil
end

function Validate.Id(v: any): boolean
	-- identifiers are short lowercase/uppercase alnum strings
	return type(v) == "string" and #v >= 1 and #v <= 40 and string.match(v, "^[%w_%-]+$") ~= nil
end

function Validate.Number(v: any, min: number?, max: number?): boolean
	if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
		return false
	end
	if min and v < min then
		return false
	end
	if max and v > max then
		return false
	end
	return true
end

function Validate.Integer(v: any, min: number?, max: number?): boolean
	return Validate.Number(v, min, max) and math.floor(v) == v
end

function Validate.OneOf(v: any, options: { string }): boolean
	if type(v) ~= "string" then
		return false
	end
	return table.find(options, v) ~= nil
end

function Validate.Boolean(v: any): boolean
	return type(v) == "boolean"
end

return Validate
