-- Economy unit tests + a free-player first-cycle simulation.
-- Run with the Luau runner described in tests/README.md:
--   luau-runner run tests/Economy.spec
-- The runner maps `script.Parent...` like Roblox so shared modules load unchanged.

local Config = require(script.Parent.Parent.src.shared.Config)
local Economy = require(script.Parent.Parent.src.shared.Economy)

local passed, failed = 0, 0
local function check(name: string, cond: boolean, detail: string?)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL  " .. name .. (if detail then "  (" .. detail .. ")" else ""))
	end
end
local function eq(name: string, got: any, want: any)
	check(name, got == want, "got " .. tostring(got) .. ", want " .. tostring(want))
end

-- Power and upgrades ---------------------------------------------------------
eq("power at level 0", Economy.powerForLevel(0), 1)
eq("power at level 4", Economy.powerForLevel(4), 25)
eq("power at level 9", Economy.powerForLevel(9), 1000)
eq("next upgrade from 0 costs 5", (Economy.nextUpgrade(0) :: any).Cost, 5)
eq("no upgrade past 9", Economy.nextUpgrade(9), nil)

local upgradeTotal = 0
for _, u in Config.Upgrades do
	upgradeTotal += u.Cost
end
eq("upgrades total 25,135 Scrap", upgradeTotal, 25135)
eq("gates total 1,100 Scrap", Config.Areas[2].GateScrap + Config.Areas[3].GateScrap, 1100)
eq("first cycle spend 36,235", upgradeTotal + 1100 + (Economy.rebirthFee(0) :: number), 36235)

-- Forms ------------------------------------------------------------------------
eq("level 3 is Scrap Bot", Economy.formFor(3).Id, "ScrapBot")
eq("level 4 is Crusher", Economy.formFor(4).Id, "Crusher")
eq("level 7 is Mega Mech", Economy.formFor(7).Id, "MegaMech")

-- Payout -----------------------------------------------------------------------
eq("base payout", Economy.payout(4, 0, false, false), 4)
eq("either multiplier alone = 2x", Economy.payout(40, 0, true, false), 80)
eq("boost alone = 2x", Economy.payout(40, 0, false, true), 80)
eq("both = 4x", Economy.payout(40, 0, true, true), 160)
eq("rebirth 1 = +25%", Economy.payout(4, 1, false, false), 5)
eq("rebirth 5 + both = 9x", Economy.payout(250, 5, true, true), 2250)
eq("floors once after full calc", Economy.payout(4, 1, false, true), 10)
eq("rebirth factor capped at 5", Economy.rebirthFactor(9), 2.25)

-- Gates --------------------------------------------------------------------------
check("gate 2 needs power 10", not Economy.checkGate(2, 2, 500, {}).ok)
check("gate 2 opens at power 10 + 100", Economy.checkGate(2, 3, 100, {}).ok)
check("gate 3 needs gate 2 first", Economy.checkGate(3, 7, 5000, {}).needPrevious)
check("gate 3 opens with power 250", Economy.checkGate(3, 7, 1000, { [2] = true }).ok)
check("gate 3 blocked at power 100", not Economy.checkGate(3, 6, 5000, { [2] = true }).ok)

-- Rebirth ------------------------------------------------------------------------
check("rebirth ready", Economy.checkRebirth(9, 20, 10000, 0).ok)
check("rebirth needs 20 crusher destroys", not Economy.checkRebirth(9, 19, 10000, 0).ok)
check("rebirth needs power 1000", not Economy.checkRebirth(8, 20, 10000, 0).ok)
check("rebirth 2 fee 20k", not Economy.checkRebirth(9, 20, 19999, 1).ok)
check("rebirth maxed after 5", Economy.checkRebirth(9, 20, 1e9, 5).maxed)

-- Workshop -----------------------------------------------------------------------
eq("workshop 1h = 40", Economy.workshopStored(0, 0, 3600), 40)
eq("workshop capped at 240", Economy.workshopStored(0, 0, 3600 * 100), 240)
eq("workshop ignores clock skew", Economy.workshopStored(10, 100, 50), 10)

-- Formatting ---------------------------------------------------------------------
eq("format 0", Economy.format(0), "0")
eq("format 1234", Economy.format(1234), "1,234")
eq("format 15000", Economy.format(15000), "15K")
eq("format 15300", Economy.format(15300), "15.3K")
eq("format 2.5M", Economy.format(2500000), "2.5M")
eq("format 160K", Economy.format(160000), "160K")
eq("time 9:05", Economy.formatTime(545), "9:05")

-- Free-player first cycle simulation ----------------------------------------------
-- Same assumptions as the concept: one second of walking between targets, a hit every
-- 0.5 s starting after the first interval, greedy upgrades, gates as soon as possible.
local function simulate(hasDouble: boolean, boost: boolean, rebirths: number, startScrap: number)
	local t, scrap, level, crusher = 0, startScrap, 0, 0
	local unlocked: { [number]: boolean } = { [1] = true }
	local firstCrusherForm: number? = nil
	while true do
		local rb = Economy.checkRebirth(level, crusher, scrap, rebirths)
		if rb.ok then
			return t, firstCrusherForm
		end
		local bought = false
		for area = 2, 3 do
			if not unlocked[area] and Economy.checkGate(area, level, scrap, unlocked).ok then
				scrap -= Config.Areas[area].GateScrap
				unlocked[area] = true
				bought = true
			end
		end
		local nextUp = Economy.nextUpgrade(level)
		if nextUp and scrap >= nextUp.Cost then
			scrap -= nextUp.Cost
			level += 1
			bought = true
			if level == 4 and not firstCrusherForm then
				firstCrusherForm = t
			end
		end
		if not bought then
			local power = Economy.powerForLevel(level)
			local bestArea, bestRate = 1, 0
			for area = 1, 3 do
				if unlocked[area] then
					local secs = Economy.hitsToBreak(area, power) * Config.Combat.HitInterval + 1
					local rate = Economy.payout(Config.Areas[area].Scrap, rebirths, hasDouble, boost) / secs
					if rate > bestRate then
						bestArea, bestRate = area, rate
					end
				end
			end
			-- Rebirth needs Crusher Yard smashes, so farm there once it is open at max power.
			if unlocked[3] and level >= Config.Rebirth.RequiredLevel then
				bestArea = 3
			end
			t += Economy.hitsToBreak(bestArea, power) * Config.Combat.HitInterval + 1
			scrap += Economy.payout(Config.Areas[bestArea].Scrap, rebirths, hasDouble, boost)
			if bestArea == 3 then
				crusher += 1
			end
		end
		if t > 36000 then
			return t, firstCrusherForm
		end
	end
end

local freeTime, crusherAt = simulate(false, false, 0, 0)
print(string.format("Free first rebirth: %.2f min (Crusher form at %.1f min)", freeTime / 60, (crusherAt or 0) / 60))
check("free first rebirth lands in the 8-12 min target", freeTime >= 8 * 60 and freeTime <= 12 * 60, tostring(freeTime))
check("first Crusher form around 2 min", (crusherAt or 0) >= 60 and (crusherAt or 0) <= 180, tostring(crusherAt))
local paidTime = simulate(true, true, 0, 0)
print(string.format("2x pass + boost first rebirth: %.2f min", paidTime / 60))
check("4x paid cycle is faster", paidTime < freeTime)

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	error("economy tests failed")
end
