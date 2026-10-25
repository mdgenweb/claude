--[[
	ProgressionService
	Account XP, lifetime stats, daily/weekly quests, daily login calendar, Yearbook rewards, codes, settings.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Quests = require(Shared.Config.Quests)
local Units = require(Shared.Config.Units)
local Rarities = require(Shared.Config.Rarities)
local Rotation = require(Shared.Logic.Rotation)
local Levels = require(Shared.Logic.Levels)
local Codes = require(script.Parent.Parent.Config.Codes)

local ProgressionService = {}

local registry

local function refreshQuests(profile)
	local now = os.time()
	local day = Rotation.dayIndex(now)
	local week = Rotation.weekIndex(now)
	local quests = profile.quests
	if quests.day ~= day then
		quests.day = day
		quests.progress = {}
		quests.claimed = {}
	end
	if quests.week ~= week then
		quests.week = week
		quests.weeklyProgress = {}
		quests.weeklyClaimed = {}
	end
end

function ProgressionService.track(player: Player, profile, stat: string, amount: number)
	if amount <= 0 then
		return
	end
	refreshQuests(profile)
	profile.stats[stat] = (profile.stats[stat] or 0) + amount
	local quests = profile.quests
	quests.progress[stat] = (quests.progress[stat] or 0) + amount
	quests.weeklyProgress[stat] = (quests.weeklyProgress[stat] or 0) + amount
	registry.DataService.markDirty(player)
end

function ProgressionService.addPlayerXp(player: Player, profile, amount: number)
	local gained
	profile.level, profile.xp, gained = Levels.applyPlayerXp(profile.level, profile.xp, amount)
	if gained > 0 then
		registry.NetService.notify(player, "Level up! You're now level " .. profile.level, "levelup")
	end
	registry.DataService.markDirty(player)
end

local function questDef(id: string, weekly: boolean)
	local list = if weekly
		then Rotation.weeklyQuests(Rotation.weekIndex(os.time()))
		else Rotation.dailyQuests(Rotation.dayIndex(os.time()))
	for _, quest in list do
		if quest.id == id then
			return quest
		end
	end
	return nil
end

function ProgressionService.init(services)
	registry = services
end

function ProgressionService.start()
	local NetService = registry.NetService
	local EconomyService = registry.EconomyService

	registry.DataService.ProfileLoaded:Connect(function(_player, profile)
		refreshQuests(profile)
	end)

	NetService.addViewDecorator(function(_player, profile, view)
		refreshQuests(profile)
		local now = os.time()
		local today = Rotation.dayIndex(now)
		view.dailyQuests = Rotation.dailyQuests(today)
		view.weeklyQuests = Rotation.weeklyQuests(Rotation.weekIndex(now))
		view.dailyResetIn = Rotation.secondsUntilNextDay(now)
		view.weeklyResetIn = Rotation.secondsUntilNextWeek(now)
		view.canClaimDaily = profile.daily.lastDay ~= today
		view.serverTime = now
	end)

	NetService.handle("ClaimDaily", function(player, _payload, profile)
		local today = Rotation.dayIndex(os.time())
		local daily = profile.daily
		if daily.lastDay == today then
			return false, "Come back tomorrow!"
		end
		local streak = if daily.lastDay == today - 1 then (daily.streak % #Quests.DailyLogin) + 1 else 1
		daily.streak = streak
		daily.lastDay = today
		local reward = Quests.DailyLogin[streak]
		local granted = EconomyService.grant(player, profile, reward)
		return true, { day = streak, reward = granted }
	end, { rate = 1 })

	NetService.handle("ClaimQuest", function(player, payload, profile)
		refreshQuests(profile)
		local weekly = payload.weekly == true
		local quest = questDef(payload.id, weekly)
		if not quest then
			return false, "That quest isn't active."
		end
		local progress = if weekly then profile.quests.weeklyProgress else profile.quests.progress
		local claimed = if weekly then profile.quests.weeklyClaimed else profile.quests.claimed
		if claimed[quest.id] then
			return false, "Already claimed."
		end
		if (progress[quest.stat] or 0) < quest.goal then
			return false, "Not finished yet!"
		end
		claimed[quest.id] = true
		return true, EconomyService.grant(player, profile, quest.reward)
	end, { rate = 4 })

	NetService.handle("ClaimYearbook", function(player, payload, profile)
		if payload.unitId then
			local unit = Units.get(payload.unitId)
			if not unit or not profile.discovered[unit.id] then
				return false, "Discover this unit first."
			end
			if profile.yearbookClaimed[unit.id] then
				return false, "Already claimed."
			end
			profile.yearbookClaimed[unit.id] = true
			return true, EconomyService.grant(player, profile, { Gumballs = Rarities.get(unit.rarity).yearbookReward })
		end
		local index = tonumber(payload.milestone)
		local milestone = index and Quests.YearbookMilestones[index]
		if not milestone then
			return false, "Unknown milestone."
		end
		-- String keys: sparse numeric keys don't survive DataStore/remote serialisation.
		local key = tostring(index)
		if profile.yearbookMilestones[key] then
			return false, "Already claimed."
		end
		local discovered = 0
		for _ in profile.discovered do
			discovered += 1
		end
		if discovered < milestone.count then
			return false, "Discover more units first."
		end
		profile.yearbookMilestones[key] = true
		return true, EconomyService.grant(player, profile, milestone.reward)
	end, { rate = 6 })

	NetService.handle("RedeemCode", function(player, payload, profile)
		if type(payload.code) ~= "string" or #payload.code > 40 then
			return false, "Invalid code."
		end
		local code = string.upper((payload.code:gsub("%s", "")))
		local entry = Codes[code]
		if not entry then
			return false, "That code doesn't exist... yet."
		end
		if entry.expires and os.time() > entry.expires then
			return false, "That code has expired."
		end
		if profile.codes[code] then
			return false, "You already used that code!"
		end
		profile.codes[code] = os.time()
		return true, EconomyService.grant(player, profile, entry.reward)
	end, { rate = 1, burst = 3 })

	local SETTING_TYPES = {
		music = "number",
		sfx = "number",
		damageNumbers = "boolean",
		lowGraphics = "boolean",
		autoSkip = "boolean",
	}
	NetService.handle("UpdateSettings", function(_player, payload, profile)
		for key, value in payload do
			local expected = SETTING_TYPES[key]
			if expected and type(value) == expected then
				profile.settings[key] = if expected == "number" then math.clamp(value, 0, 1) else value
			end
		end
		return true, profile.settings
	end, { rate = 4 })

	NetService.handle("CompleteTutorial", function(_player, _payload, profile)
		profile.tutorialDone = true
		return true, nil
	end, { rate = 1 })
end

return ProgressionService
