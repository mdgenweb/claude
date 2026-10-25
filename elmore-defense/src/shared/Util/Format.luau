--[[
	Format
	Display helpers shared by UI and server messages.
]]

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T" }

-- 1234 -> "1,234"; 1234567 -> "1.23M" (compact when >= 1e6 or when compact=true and >= 1e4)
function Format.number(value: number, compact: boolean?): string
	value = math.floor(value + 0.5)
	local absolute = math.abs(value)
	if absolute >= 1e6 or (compact and absolute >= 1e4) then
		local tier = math.min(math.floor(math.log10(absolute) / 3), #SUFFIXES - 1)
		local scaled = value / (1000 ^ tier)
		local text = string.format(scaled >= 100 and "%.0f" or (scaled >= 10 and "%.1f" or "%.2f"), scaled)
		if text:find(".", 1, true) then
			text = text:gsub("0+$", ""):gsub("%.$", "")
		end
		return text .. SUFFIXES[tier + 1]
	end
	local text = tostring(absolute)
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return (value < 0 and "-" or "") .. formatted
end

function Format.cash(value: number): string
	return "$" .. Format.number(value)
end

-- Seconds -> "mm:ss" (or "h:mm:ss" for long durations)
function Format.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60
	local secs = seconds % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%02d:%02d", minutes, secs)
end

-- Percent with sensible precision: 69.85 -> "69.85%", 0.05 -> "0.05%", 25 -> "25%"
function Format.percent(value: number): string
	local text = string.format(if value >= 0.1 then "%.2f" else "%.3f", value)
	text = text:gsub("(%..-)0+$", "%1"):gsub("%.$", "")
	return text .. "%"
end

-- "+25% dmg" style modifier text
function Format.signedPercent(fraction: number): string
	local pct = math.floor(fraction * 1000 + 0.5) / 10
	local sign = pct >= 0 and "+" or ""
	local text = tostring(pct):gsub("%.0$", "")
	return sign .. text .. "%"
end

return Format
