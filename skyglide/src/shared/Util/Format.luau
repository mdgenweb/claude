--!strict
-- Number / time formatting shared by UI and server messages. Handles the very large values an
-- incremental game reaches (up to ~1e303) with short suffixes: 1.2K, 3.4M ... 5.6Dc.
local Format = {}

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg" }

function Format.Commas(n: number): string
	if n ~= n or math.abs(n) >= 1e15 then
		return Format.Short(n)
	end
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

local function trim(str: string): string
	-- "12.50" -> "12.5", "3.00" -> "3"
	if string.find(str, "%.") then
		str = string.gsub(str, "0+$", "")
		str = string.gsub(str, "%.$", "")
	end
	return str
end

-- 999 -> "999", 1234 -> "1.23K", 25290 -> "25.29K", 1.5e6 -> "1.5M"
function Format.Short(n: number): string
	if n ~= n then
		return "0"
	end
	if n == math.huge then
		return "inf"
	end
	local abs = math.abs(n)
	if abs < 1000 then
		if abs == math.floor(abs) then
			return tostring(math.floor(n))
		end
		return trim(string.format("%.1f", n))
	end
	local tier = math.floor(math.log10(abs) / 3)
	if tier > #SUFFIXES then
		return string.format("%.2e", n)
	end
	local v = n / 10 ^ (tier * 3)
	local str
	if math.abs(v) >= 100 then
		str = string.format("%.0f", math.floor(v))
	elseif math.abs(v) >= 10 then
		str = trim(string.format("%.2f", math.floor(v * 100) / 100))
	else
		str = trim(string.format("%.2f", math.floor(v * 100) / 100))
	end
	return str .. SUFFIXES[tier]
end

-- Distance in meters for the flight counter: "144 m", "12.4K m"
function Format.Meters(m: number): string
	if m < 1000 then
		return string.format("%d m", math.floor(m))
	end
	return Format.Short(m) .. " m"
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

-- "05:12" style countdown
function Format.Clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%02d:%02d", seconds // 60, seconds % 60)
end

function Format.Multiplier(m: number): string
	return "x" .. Format.Short(math.floor(m * 100 + 0.5) / 100)
end

function Format.Percent(p: number): string
	return string.format("%d%%", math.floor(p + 0.5))
end

return Format
