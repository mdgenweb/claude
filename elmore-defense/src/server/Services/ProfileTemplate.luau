--[[
	ProfileTemplate
	Shape of a saved player profile. New keys added here are reconciled into existing saves on load.
	Bump SCHEMA and add a migration in DataService when a key changes meaning.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local ProfileTemplate = {}

ProfileTemplate.SCHEMA = 1

function ProfileTemplate.new()
	return {
		schema = ProfileTemplate.SCHEMA,
		currencies = {
			Gumballs = GameConfig.Starting.Gumballs,
			VoidShards = GameConfig.Starting.VoidShards,
			ReportCards = GameConfig.Starting.ReportCards,
		},
		-- Portion of each currency that was bought with Robux (paid-random-item compliance).
		paid = { Gumballs = 0, VoidShards = 0, ReportCards = 0 },
		items = { JoyfulCoupons = 0, RainbowSprinkles = 0, VoidCores = 0, StickerPages = 0 },
		units = {}, -- [uid] = { uid, id, level, xp, trait, grades, shiny, locked, at }
		nextUid = 1,
		team = {}, -- array of uids, max GameConfig.Inventory.TeamSize
		autoDelete = { Rare = false, Epic = false, Legendary = false },
		pity = {}, -- [bannerId] = { legendary, mythic }
		discovered = {}, -- [unitId] = true
		yearbookClaimed = {}, -- [unitId] = true
		yearbookMilestones = {}, -- [index] = true
		story = {}, -- [stageKey] = stars
		infiniteBest = {}, -- [worldId] = wave
		challengesDone = {}, -- [challengeId] = true (pruned)
		level = 1,
		xp = 0,
		pass = { season = "", xp = 0, premium = false, free = {}, prem = {} },
		daily = { streak = 0, lastDay = -1 },
		quests = { day = -1, week = -1, progress = {}, claimed = {}, weeklyProgress = {}, weeklyClaimed = {} },
		stats = {},
		codes = {},
		receipts = {}, -- [purchaseId] = unix time (bounded)
		oneTime = {}, -- [productKey] = true
		devPasses = {}, -- Studio-only granted passes
		settings = { music = 0.6, sfx = 0.8, damageNumbers = true, lowGraphics = false, autoSkip = false },
		tutorialDone = false,
		createdAt = os.time(),
		lastLogin = os.time(),
	}
end

return ProfileTemplate
