-- Everything the player spends Scrap on or claims: Power upgrades, gates, rebirth,
-- workshop, daily contract and the garage. Every rule is checked here on the server.
-- Handlers return (ok, message) for the client to show.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)

local StateService = require(script.Parent.StateService)
local MechService = require(script.Parent.MechService)
local Analytics = require(script.Parent.Analytics)

local ProgressService = {}

local TX = Enum.AnalyticsEconomyTransactionType

local function session(player: Player)
	return StateService.get(player)
end

function ProgressService.upgrade(player: Player): (boolean, string?)
	local s = session(player)
	if not s then
		return false, "Loading..."
	end
	local data = s.Data
	local nextUp = Economy.nextUpgrade(data.Level)
	if not nextUp then
		return false, "Max Power! Time to rebirth."
	end
	local formBefore = Economy.formIndex(data.Level)
	if not StateService.spend(player, nextUp.Cost) then
		return false, string.format("Need %s more Scrap", Economy.format(nextUp.Cost - data.Scrap))
	end
	data.Level += 1
	data.Stats.Upgrades += 1
	Analytics.economy(player, false, nextUp.Cost, data.Scrap, TX.Shop, "Upgrade" .. data.Level)
	Analytics.progression(player, "Power", data.Level, "Power " .. nextUp.Power)
	Analytics.funnel(player, data, "FirstUpgrade")
	local formAfter = Economy.formIndex(data.Level)
	if formAfter ~= formBefore then
		local form = Config.Forms[formAfter]
		StateService.notify(player, "Form", form.Name, "NEW FORM!")
		if form.Id == "Crusher" then
			Analytics.funnel(player, data, "CrusherForm")
			Analytics.badge(player, Config.Badges.CrusherForm)
		elseif form.Id == "MegaMech" then
			Analytics.funnel(player, data, "MegaMech")
			Analytics.badge(player, Config.Badges.MegaMech)
		end
	else
		StateService.notify(player, "Upgrade", "Power " .. Economy.format(nextUp.Power) .. "!", nextUp.Milestone)
	end
	StateService.LevelChanged:Fire(player, s)
	StateService.push(player)
	return true
end

function ProgressService.unlockGate(player: Player, area: number): (boolean, string?)
	local s = session(player)
	if not s or (area ~= 2 and area ~= 3) then
		return false
	end
	local data = s.Data
	if StateService.areaUnlocked(s, area) then
		return true
	end
	local check = Economy.checkGate(area, data.Level, data.Scrap, { [2] = data.Gates.Appliance })
	local def = Config.Areas[area]
	if check.needPrevious then
		return false, "Open Appliance Row first"
	elseif check.needPower then
		return false, string.format("Need Power %d (you have %s)", def.GatePower, Economy.format(StateService.power(s)))
	elseif not StateService.spend(player, def.GateScrap) then
		return false, string.format("Need %s more Scrap", Economy.format(def.GateScrap - data.Scrap))
	end
	if area == 2 then
		data.Gates.Appliance = true
		Analytics.funnel(player, data, "ApplianceRow")
	else
		data.Gates.Crusher = true
		Analytics.funnel(player, data, "CrusherYard")
	end
	Analytics.economy(player, false, def.GateScrap, data.Scrap, TX.Shop, "Gate" .. area)
	Analytics.progression(player, "Yards", area, def.Name)
	StateService.notify(
		player,
		"Gate",
		def.Name .. " unlocked!",
		string.format("%d HP junk · %d Scrap each", def.HP, def.Scrap)
	)
	StateService.push(player)
	return true
end

function ProgressService.rebirth(player: Player): (boolean, string?)
	local s = session(player)
	if not s then
		return false
	end
	local data = s.Data
	local check = Economy.checkRebirth(data.Level, data.CrusherDestroys, data.Scrap, data.Rebirths)
	if check.maxed then
		return false, "All five rebirths done!"
	elseif not check.powerOk then
		return false, "Reach Power " .. Economy.format(Economy.powerForLevel(Config.Rebirth.RequiredLevel)) .. " first"
	elseif not check.destroysOk then
		return false,
			string.format(
				"Smash %d more in Crusher Yard",
				Config.Rebirth.RequiredCrusherDestroys - data.CrusherDestroys
			)
	elseif not StateService.spend(player, check.fee) then
		return false, string.format("Need %s more Scrap", Economy.format(check.fee - data.Scrap))
	end
	-- Resets Power and gate access; keeps leftover Scrap, tools, finishes, passes and boosts.
	data.Rebirths += 1
	data.Level = 0
	data.Gates.Appliance = false
	data.Gates.Crusher = false
	data.CrusherDestroys = 0
	Analytics.economy(player, false, check.fee, data.Scrap, TX.Shop, "Rebirth" .. data.Rebirths)
	Analytics.progression(player, "Rebirth", data.Rebirths, "Rebirth " .. data.Rebirths)
	Analytics.funnel(player, data, "FirstRebirth")
	Analytics.badge(player, Config.Badges.Rebirth[data.Rebirths] or 0)
	StateService.notify(
		player,
		"Rebirth",
		"REBIRTH " .. data.Rebirths .. "!",
		string.format("+%d%% Scrap forever", math.floor(Config.Rebirth.BonusPerRebirth * data.Rebirths * 100 + 0.5))
	)
	StateService.LevelChanged:Fire(player, s)
	StateService.push(player)
	task.delay(0.2, MechService.sendToLane, player)
	return true
end

function ProgressService.claimWorkshop(player: Player): (boolean, string?)
	local s = session(player)
	if not s then
		return false
	end
	local w = s.Data.Workshop
	local now = os.time()
	local stored = Economy.workshopStored(w.Stored, w.Updated, now)
	local amount = math.floor(stored)
	if amount < 1 then
		return false, "The workshop is still working. Check back soon!"
	end
	w.Stored = stored - amount
	w.Updated = now
	StateService.addScrap(player, amount, "Workshop")
	Analytics.economy(player, true, amount, s.Data.Scrap, TX.TimedReward, "Workshop")
	StateService.notify(player, "Reward", "+" .. amount .. " Scrap", "Workshop delivery")
	return true
end

function ProgressService.claimDaily(player: Player): (boolean, string?)
	local s = session(player)
	if not s then
		return false
	end
	local data = s.Data
	StateService.rollDaily(data)
	if data.Daily.Claimed then
		return false, "Already claimed today. New contract tomorrow!"
	elseif data.Daily.Progress < Config.Daily.Goal then
		return false, string.format("Smash %d more junk first", Config.Daily.Goal - data.Daily.Progress)
	end
	data.Daily.Claimed = true
	data.Stamps += 1
	StateService.addScrap(player, Config.Daily.RewardScrap, "Daily")
	Analytics.economy(player, true, Config.Daily.RewardScrap, data.Scrap, TX.TimedReward, "Daily")
	if data.Stamps >= Config.Daily.StampsForFinish and not data.Finishes.Chrome then
		data.Finishes.Chrome = true
		StateService.notify(player, "Unlock", "Stamped Chrome unlocked!", "Equip it in the Garage.")
	else
		StateService.notify(
			player,
			"Reward",
			"+" .. Config.Daily.RewardScrap .. " Scrap",
			string.format(
				"Stamp %d/%d",
				math.min(data.Stamps, Config.Daily.StampsForFinish),
				Config.Daily.StampsForFinish
			)
		)
	end
	StateService.push(player)
	return true
end

local VALID_TOOLS = {}
for _, tool in Config.Tools do
	VALID_TOOLS[tool.Id] = true
end

function ProgressService.selectTool(player: Player, toolId: string): (boolean, string?)
	local s = session(player)
	if not s or not VALID_TOOLS[toolId] then
		return false
	end
	s.Data.Tool = toolId
	s.Data.ToolChosen = true
	Analytics.funnel(player, s.Data, "PickedTool")
	StateService.LookChanged:Fire(player, s)
	StateService.push(player)
	return true
end

local VALID_FINISHES = {}
for _, finish in Config.Finishes do
	VALID_FINISHES[finish.Id] = true
end

function ProgressService.selectFinish(player: Player, finishId: string): (boolean, string?)
	local s = session(player)
	if not s or not VALID_FINISHES[finishId] then
		return false
	end
	if not s.Data.Finishes[finishId] then
		return false, "You don't own that finish yet"
	end
	s.Data.Finish = finishId
	StateService.LookChanged:Fire(player, s)
	StateService.push(player)
	return true
end

function ProgressService.craftWorker(player: Player): (boolean, string?)
	local s = session(player)
	if not s then
		return false
	end
	if s.Data.Finishes.Worker then
		return false, "You already own the Worker Shell"
	end
	if not StateService.spend(player, Config.WorkerShellCraftCost) then
		return false, string.format("Need %s more Scrap", Economy.format(Config.WorkerShellCraftCost - s.Data.Scrap))
	end
	s.Data.Finishes.Worker = true
	Analytics.economy(player, false, Config.WorkerShellCraftCost, s.Data.Scrap, TX.Shop, "WorkerShell")
	StateService.notify(player, "Unlock", "Worker Shell crafted!", "Equip it in the Garage.")
	StateService.push(player)
	return true
end

return ProgressService
