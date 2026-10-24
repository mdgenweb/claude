--!strict
-- Pure economy rules shared by server (authoritative) and client (display only).
-- No Roblox services here so the module can be unit-tested outside Studio.

local Config = require(script.Parent.Config)

local Economy = {}

Economy.MaxLevel = #Config.Upgrades
Economy.MaxRebirths = #Config.Rebirth.Fees

function Economy.powerForLevel(level: number): number
	if level <= 0 then
		return Config.StartPower
	end
	return Config.Upgrades[math.min(level, Economy.MaxLevel)].Power
end

-- The upgrade the player would buy next, or nil at max level.
function Economy.nextUpgrade(level: number): Config.Upgrade?
	return Config.Upgrades[level + 1]
end

function Economy.formIndex(level: number): number
	local index = 1
	for i, form in Config.Forms do
		if level >= form.FromLevel then
			index = i
		end
	end
	return index
end

function Economy.formFor(level: number)
	return Config.Forms[Economy.formIndex(level)]
end

function Economy.bodyScale(level: number): number
	return Config.BodyScale[math.clamp(level, 0, Economy.MaxLevel)] or 1
end

function Economy.rebirthFactor(rebirths: number): number
	return 1 + Config.Rebirth.BonusPerRebirth * math.clamp(rebirths, 0, Economy.MaxRebirths)
end

function Economy.totalMultiplier(rebirths: number, hasDoubleScrap: boolean, boostActive: boolean): number
	local permanent = if hasDoubleScrap then Config.DoubleScrapMultiplier else 1
	local temporary = if boostActive then Config.Boost.Multiplier else 1
	return Economy.rebirthFactor(rebirths) * permanent * temporary
end

-- Payout = base x rebirth factor x permanent factor x temporary factor, floored once.
function Economy.payout(baseScrap: number, rebirths: number, hasDoubleScrap: boolean, boostActive: boolean): number
	return math.floor(baseScrap * Economy.totalMultiplier(rebirths, hasDoubleScrap, boostActive) + 1e-9)
end

function Economy.hitsToBreak(areaIndex: number, power: number): number
	return math.ceil(Config.Areas[areaIndex].HP / math.max(power, 1))
end

export type GateCheck = { ok: boolean, needPower: boolean, needScrap: boolean, needPrevious: boolean }

-- Area 1 is always open. Area n requires area n-1, the Power threshold and the Scrap fee.
function Economy.checkGate(areaIndex: number, level: number, scrap: number, unlocked: { [number]: boolean }): GateCheck
	local area = Config.Areas[areaIndex]
	local needPrevious = areaIndex > 2 and not unlocked[areaIndex - 1]
	local needPower = Economy.powerForLevel(level) < area.GatePower
	local needScrap = scrap < area.GateScrap
	return {
		ok = not (needPrevious or needPower or needScrap),
		needPower = needPower,
		needScrap = needScrap,
		needPrevious = needPrevious,
	}
end

function Economy.rebirthFee(rebirths: number): number?
	return Config.Rebirth.Fees[rebirths + 1]
end

export type RebirthCheck = {
	ok: boolean,
	maxed: boolean,
	powerOk: boolean,
	destroysOk: boolean,
	scrapOk: boolean,
	fee: number,
}

function Economy.checkRebirth(level: number, crusherDestroys: number, scrap: number, rebirths: number): RebirthCheck
	local fee = Economy.rebirthFee(rebirths)
	if fee == nil then
		return { ok = false, maxed = true, powerOk = true, destroysOk = true, scrapOk = true, fee = 0 }
	end
	local powerOk = level >= Config.Rebirth.RequiredLevel
	local destroysOk = crusherDestroys >= Config.Rebirth.RequiredCrusherDestroys
	local scrapOk = scrap >= fee
	return {
		ok = powerOk and destroysOk and scrapOk,
		maxed = false,
		powerOk = powerOk,
		destroysOk = destroysOk,
		scrapOk = scrapOk,
		fee = fee,
	}
end

-- Workshop accrues continuously (including offline) up to the cap.
function Economy.workshopStored(stored: number, updatedAt: number, now: number): number
	local elapsed = math.max(0, now - updatedAt)
	return math.min(Config.Workshop.Cap, stored + elapsed * Config.Workshop.RatePerHour / 3600)
end

function Economy.dayIndex(unixTime: number): number
	return math.floor(unixTime / 86400)
end

-- 1234 -> "1,234"; 15300 -> "15.3K"; 2.5e6 -> "2.5M"
local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi" }

function Economy.format(n: number): string
	n = math.floor(n)
	if math.abs(n) < 10000 then
		local s = tostring(math.abs(n))
		local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
		if formatted:sub(1, 1) == "," then
			formatted = formatted:sub(2)
		end
		return (if n < 0 then "-" else "") .. formatted
	end
	local value = n
	local suffix = ""
	for _, s in SUFFIXES do
		if math.abs(value) < 1000 then
			break
		end
		value /= 1000
		suffix = s
	end
	local text = if math.abs(value) < 100 then string.format("%.1f", value) else string.format("%d", value)
	text = text:gsub("%.0$", "")
	return text .. suffix
end

function Economy.formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local m = seconds // 60
	local s = seconds % 60
	if m >= 60 then
		return string.format("%dh %02dm", m // 60, m % 60)
	end
	return string.format("%d:%02d", m, s)
end

return Economy
