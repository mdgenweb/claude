--!strict
-- Number / time formatting helpers shared by server messages and client UI.

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T" }

-- 1234 -> "1,234"
function Format.commas(n: number): string
	local negative = n < 0
	local s = tostring(math.floor(math.abs(n)))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return if negative then "-" .. formatted else formatted
end

-- 15300 -> "15.3K"
function Format.short(n: number): string
	local abs = math.abs(n)
	if abs < 10000 then
		return Format.commas(n)
	end
	local tier = math.min(math.floor(math.log10(abs) / 3), #SUFFIXES - 1)
	local scaled = n / (1000 ^ tier)
	local text = string.format(if math.abs(scaled) >= 100 then "%.0f" else "%.1f", scaled)
	text = text:gsub("%.0$", "")
	return text .. SUFFIXES[tier + 1]
end

-- 3725 -> "1h 2m", 95 -> "1m 35s", 7 -> "7s"
function Format.duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%dh %dm", h, m)
	elseif m > 0 then
		return string.format("%dm %02ds", m, s)
	end
	return string.format("%ds", s)
end

-- 12.345 -> "12.3s"
function Format.seconds(seconds: number): string
	return string.format("%.1fs", seconds)
end

function Format.percent(fraction: number): string
	return string.format("%d%%", math.floor(fraction * 100 + 0.5))
end

return Format
