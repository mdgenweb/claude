-- Match state machine spec: drives complete 1v1 / 2v2 matches through the real Match module
-- with stubbed services, a fake clock and simulated player input.
local Rng = MODULE("ReplicatedStorage/Shared/Util/Rng")

-- Roblox globals the match module touches
local clock = 0
task = {
	spawn = function(f, ...)
		f(...)
	end,
	defer = function(f, ...)
		f(...)
	end,
	delay = function() end,
}
Random = {
	new = function(seed)
		local r = Rng.new(seed or 7)
		return {
			NextInteger = function(_, a, b)
				return r:Int(a, b)
			end,
			NextNumber = function(_, a, b)
				a = a or 0
				b = b or 1
				return a + (b - a) * r:Next()
			end,
		}
	end,
}
local workspace = FAKE_GAME:GetService("Workspace")
rawset(workspace, "GetServerTimeNow", function()
	return clock
end)

local Match = MODULE("ServerScriptService/Server/Battle/Match")
local GameConfig = MODULE("ReplicatedStorage/Shared/Config/Game")

local failures = 0
local function check(cond, message)
	if not cond then
		failures += 1
		print("FAILED: " .. message)
	end
end

local function makeDeps(log)
	return {
		BallService = {
			RollOffers = function(_player, count)
				local pool = { "bumper", "thorn", "titan", "frost", "storm", "cannon" }
				local out = {}
				for i = 1, count do
					table.insert(out, pool[((log.rolls + i) % #pool) + 1])
				end
				log.rolls += 1
				return out
			end,
			Owns = function()
				return true
			end,
		},
		AbilityService = {
			Get = function(id)
				return MODULE("ServerScriptService/Server/Battle/Abilities/" .. id)
			end,
		},
		EconomyService = {
			TrySpend = function(_player, _currency, amount)
				log.spent += amount
				return true
			end,
		},
		DataService = {
			Get = function()
				return { Equipped = { Explosion = "classic", Flyer = "basic" } }
			end,
		},
		RewardService = {
			GrantMatch = function(player, outcome)
				table.insert(log.rewards, { player = player, outcome = outcome })
				return { Coins = if outcome.Won then 100 else 20, XP = 10 }
			end,
		},
		ArenaService = {},
		Replicator = {
			SendPublic = function(_station, payload)
				table.insert(log.public, payload.Type)
			end,
			SendEvents = function(_station, events)
				log.events += #events
			end,
			SendSnapshot = function()
				log.snapshots += 1
			end,
		},
		PrivateRemote = {
			FireClient = function(_self, player, payload)
				table.insert(log.private, { player = player, payload = payload })
			end,
		},
		Notify = function() end,
		OnPublicChanged = function() end,
		OnClosed = function()
			log.closed = true
		end,
	}
end

local function newLog()
	return { rolls = 0, spent = 0, rewards = {}, public = {}, private = {}, events = 0, snapshots = 0, closed = false }
end

local function fakePlayer(id)
	return {
		UserId = id,
		DisplayName = "Tester" .. id,
		Name = "Tester" .. id,
		Parent = true,
		IsFriendsWith = function()
			return id == 1
		end,
	}
end

local function run(match, log, humanAction, maxSeconds)
	local dt = 1 / 60
	local handled = 0
	local steps = 0
	while not log.closed and steps < maxSeconds * 60 do
		clock += dt
		steps += 1
		match:Update(dt)
		while handled < #log.private do
			handled += 1
			local msg = log.private[handled]
			if humanAction then
				humanAction(match, msg.player, msg.payload)
			end
		end
	end
	return steps / 60
end

local function count(list, value)
	local n = 0
	for _, v in list do
		if v == value then
			n += 1
		end
	end
	return n
end

-------------------------------------------------------------------------------- 1v1 bots only
do
	local log = newLog()
	local match = Match.new(makeDeps(log), { Index = 1, Id = "D1", Mode = "1v1" }, {
		{ BotName = "A", BotId = -1, Team = 1, Pad = 1 },
		{ BotName = "B", BotId = -2, Team = 2, Pad = 2 },
	}, true)
	match:Start()
	local t = run(match, log, nil, 900)
	check(log.closed, "bot match did not close")
	check(match.WinnerTeam ~= nil, "no winner")
	local loser = if match.WinnerTeam == 1 then 2 else 1
	check(match.Teams[loser].Hearts == 0, "loser should have 0 hearts")
	check(match.Round >= GameConfig.Hearts, "too few rounds: " .. match.Round)
	check(#log.rewards == 0, "bots must not receive rewards")
	check(count(log.public, "RoundEnd") == match.Round, "one RoundEnd per round")
	check(log.snapshots > 0 and log.events > 0, "battle never replicated")
	print(string.format("1v1 bots: %d rounds, %.0fs, winner team %d, %d snapshots", match.Round, t, match.WinnerTeam, log.snapshots))
end

-------------------------------------------------------------------------------- 1v1 human vs bot
do
	local log = newLog()
	local human = fakePlayer(1)
	local match = Match.new(makeDeps(log), { Index = 2, Id = "D2", Mode = "1v1" }, {
		{ Player = human, Team = 1, Pad = 1 },
		{ BotName = "Bot", BotId = -1, Team = 2, Pad = 2 },
	}, true)
	match:Start()
	local usedCollection = false
	local rerolled = false
	local aims = 0
	run(match, log, function(m, player, payload)
		if payload.Type == "Selection" and not payload.Picked then
			if not rerolled then
				rerolled = true
				m:HandleSelection(player, "Reroll", nil)
			elseif not usedCollection then
				usedCollection = true
				m:HandleSelection(player, "Collection", "storm")
			else
				m:HandleSelection(player, "Pick", 2)
				-- invalid / repeated input must be ignored
				m:HandleSelection(player, "Pick", 99)
				m:HandleSelection(player, "Collection", "not_a_ball")
			end
		elseif payload.Type == "Aim" then
			aims += 1
			m:HandleAim(player, 0 / 0, false) -- NaN rejected
			m:HandleAim(player, 0.8, true)
			m:HandleAim(player, 2.0, true) -- already locked: ignored
		end
	end, 900)
	check(log.closed, "human match did not close")
	check(#log.rewards == 1 and log.rewards[1].player == human, "human should get exactly one reward grant")
	check(log.rewards[1] and log.rewards[1].outcome.Practice == true, "practice flag missing")
	check(log.rewards[1] and log.rewards[1].outcome.VsFriend == false, "bots are never friends")
	check(log.spent == GameConfig.Selection.RerollCost, "reroll should cost gems once (free collection pick is free)")
	check(aims == match.Round, "aim phase once per round")
	local p = match.Participants[1]
	check(p.FreePicksUsed == 1, "collection pick not recorded")
	print(string.format("human vs bot: %d rounds, winner team %d, gems spent %d", match.Round, match.WinnerTeam, log.spent))
end

-------------------------------------------------------------------------------- forfeit
do
	local log = newLog()
	local a, b = fakePlayer(1), fakePlayer(2)
	local match = Match.new(makeDeps(log), { Index = 3, Id = "D3", Mode = "1v1" }, {
		{ Player = a, Team = 1, Pad = 1 },
		{ Player = b, Team = 2, Pad = 2 },
	}, false)
	match:Start()
	-- run into the first battle, then player 2 leaves
	local left = false
	run(match, log, function(m, player, payload)
		if payload.Type == "Selection" and not payload.Picked then
			m:HandleSelection(player, "Pick", 1)
		elseif payload.Type == "Aim" then
			m:HandleAim(player, 1.0, true)
			if player == b and not left then
				left = true
				m:OnPlayerLeft(b)
			end
		end
	end, 300)
	check(log.closed, "forfeit match did not close")
	check(match.Forfeit == true and match.WinnerTeam == 1, "remaining player should win by forfeit")
	check(#log.rewards == 1 and log.rewards[1].player == a and log.rewards[1].outcome.Won, "only the remaining player is rewarded")
	print("forfeit: OK")
end

-------------------------------------------------------------------------------- 2v2
do
	local log = newLog()
	local match = Match.new(makeDeps(log), { Index = 9, Id = "T1", Mode = "2v2" }, {
		{ BotName = "A1", BotId = -1, Team = 1, Pad = 1 },
		{ BotName = "A2", BotId = -2, Team = 1, Pad = 2 },
		{ BotName = "B1", BotId = -3, Team = 2, Pad = 3 },
		{ BotName = "B2", BotId = -4, Team = 2, Pad = 4 },
	}, true)
	match:Start()
	run(match, log, nil, 900)
	check(log.closed, "2v2 did not close")
	check(match.Half == 10, "2v2 should use the team arena")
	print(string.format("2v2 bots: %d rounds, winner team %d", match.Round, match.WinnerTeam or 0))
end

if failures == 0 then
	print("match.spec: OK")
else
	print(string.format("match.spec: %d FAILED checks", failures))
end
