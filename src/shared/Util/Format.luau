--!strict
-- Number / time formatting helpers shared by UI and server messages.
local Format = {}

function Format.Commas(n: number): string
	local s = tostring(math.floor(n))
	local negative = string.sub(s, 1, 1) == "-"
	if negative then
		s = string.sub(s, 2)
	end
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	if string.sub(out, 1, 1) == "," then
		out = string.sub(out, 2)
	end
	return (negative and "-" or "") .. out
end

-- 1234 -> "1.2K", 1500000 -> "1.5M"
function Format.Short(n: number): string
	local abs = math.abs(n)
	if abs < 10000 then
		return tostring(math.floor(n))
	end
	local values = { 1e12, 1e9, 1e6, 1e3 }
	local suffixes = { "T", "B", "M", "K" }
	for i, unit in values do
		if abs >= unit then
			local v = n / unit
			local str = if math.abs(v) >= 100 then string.format("%d", v) else string.format("%.1f", v)
			str = string.gsub(str, "%.0$", "")
			return str .. suffixes[i]
		end
	end
	return tostring(n)
end

-- seconds -> "13d 1h", "1h 16m", "4m 05s", "12s"
function Format.Duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local d = seconds // 86400
	local h = (seconds % 86400) // 3600
	local m = (seconds % 3600) // 60
	local sec = seconds % 60
	if d > 0 then
		return string.format("%dd %dh", d, h)
	elseif h > 0 then
		return string.format("%dh %dm", h, m)
	elseif m > 0 then
		return string.format("%dm %02ds", m, sec)
	end
	return string.format("%ds", sec)
end

function Format.Percent(p: number): string
	if p == math.floor(p) then
		return string.format("%.2f%%", p)
	end
	return string.format("%.2f%%", p)
end

return Format
