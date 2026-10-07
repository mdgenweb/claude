--!strict
-- Code redemption (Gift -> Codes menu in the reference). One use per player per code.
local Server = script.Parent.Parent
local Codes = require(Server.Data.Codes)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local CodeService = {}

local byCode: { [string]: Codes.Code } = {}
for _, code in Codes do
	byCode[string.upper(code.Code)] = code
end

function CodeService.Redeem(player: Player, raw: any): { [string]: any }
	if type(raw) ~= "string" or #raw > 32 then
		return { ok = false, error = "Invalid code." }
	end
	local key = string.upper((string.gsub(raw, "%s", "")))
	local code = byCode[key]
	if code == nil then
		return { ok = false, error = "That code doesn't exist." }
	end
	if code.Expires and os.time() >= code.Expires then
		return { ok = false, error = "That code has expired." }
	end
	local claimed = DataService.Update(player, function(profile)
		if profile.Codes[key] then
			return false
		end
		profile.Codes[key] = true
		return true
	end)
	if claimed == nil then
		return { ok = false, error = "Your data is still loading." }
	elseif claimed == false then
		return { ok = false, error = "You already redeemed this code." }
	end
	local parts = {}
	if code.Coins then
		EconomyService.AddCurrency(player, "Coins", code.Coins)
		table.insert(parts, string.format("+%d Coins", code.Coins))
	end
	if code.Gems then
		EconomyService.AddCurrency(player, "Gems", code.Gems)
		table.insert(parts, string.format("+%d Gems", code.Gems))
	end
	if code.Ticket then
		EconomyService.GrantItem(player, "Ticket", code.Ticket, 1)
		table.insert(parts, "+1 Gacha")
	end
	return { ok = true, message = "Redeemed! " .. table.concat(parts, ", ") }
end

return CodeService
