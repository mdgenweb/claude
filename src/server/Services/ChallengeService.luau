--!nonstrict
-- Daily challenges (3 per UTC day, deterministic per player) and the gameplay event bus that also
-- feeds the TrialService.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Challenges = require(Shared.Data.Challenges)

local ChallengeService = {}

local function today(): number
	return math.floor(os.time() / 86400)
end
ChallengeService.Today = today

function ChallengeService:Init(services)
	self.S = services
	self._dirty = {}
end

function ChallengeService:Start()
	self.S.DataService.ProfileLoaded:Connect(function(player, data)
		self:_ensureDaily(player, data)
		self.S.DataService:Replicate(player, "daily")
	end)
	Players.PlayerRemoving:Connect(function(player)
		self._dirty[player] = nil
	end)
	-- Batch "daily" replication and roll over at midnight UTC.
	task.spawn(function()
		while true do
			task.wait(0.5)
			for player in table.clone(self._dirty) do
				self._dirty[player] = nil
				if player.Parent then
					self.S.DataService:Replicate(player, "daily")
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(30)
			for _, player in Players:GetPlayers() do
				local data = self.S.DataService:Get(player)
				if data and data.daily.day ~= today() then
					self:_ensureDaily(player, data)
					self.S.DataService:Replicate(player, "daily")
					self.S.ShopService:Notify(player, "toast", { text = "New daily challenges are in!", kind = "info" })
				end
			end
		end
	end)
end

function ChallengeService:_ensureDaily(player: Player, data)
	local day = today()
	if data.daily.day == day and #data.daily.list == Challenges.DailyCount then
		return
	end
	local rng = Random.new(day * 7919 + player.UserId % 100000)
	local eligible = {}
	for _, template in Challenges.Daily do
		if data.level >= template.minLevel then
			table.insert(eligible, template)
		end
	end
	local list = {}
	for tier = 1, Challenges.DailyCount do
		if #eligible == 0 then
			break
		end
		local index = rng:NextInteger(1, #eligible)
		local template = table.remove(eligible, index)
		local effectiveTier = tier
		if template.id == "height" and data.level < 7 then
			effectiveTier = math.min(tier, 2) -- the hard target needs the Sky Shaft
		end
		table.insert(list, {
			id = template.id,
			tier = tier,
			target = template.targets[effectiveTier],
			progress = 0,
			done = false,
		})
	end
	data.daily = { day = day, list = list, bonusClaimed = false }
end

-- Re-rolls nothing; just makes sure today's list exists (e.g. after a level up).
function ChallengeService:RefreshDaily(player: Player)
	local data = self.S.DataService:Get(player)
	if data then
		self:_ensureDaily(player, data)
	end
end

-- Gameplay event entry point. `extra` may contain status / golem / potion / reaction ids.
function ChallengeService:Event(player: Player, event: string, value: number, extra)
	if not player or not player.Parent then
		return
	end
	local data = self.S.DataService:Get(player)
	if not data then
		return
	end
	extra = extra or {}
	self:_ensureDaily(player, data)
	for _, challenge in data.daily.list do
		if challenge.done then
			continue
		end
		local template = Challenges.DailyById[challenge.id]
		if not template or template.event ~= event then
			continue
		end
		if template.filter and template.filter ~= extra.status then
			continue
		end
		if template.mode == "max" then
			challenge.progress = math.max(challenge.progress, math.floor(value))
		else
			challenge.progress += value
		end
		if challenge.progress >= challenge.target then
			challenge.progress = challenge.target
			challenge.done = true
			self:_reward(player, data, challenge, template)
		end
		self._dirty[player] = true
	end
	if self.S.TrialService then
		self.S.TrialService:Event(player, event, value, extra)
	end
end

function ChallengeService:_reward(player: Player, data, challenge, template)
	local coins = Challenges.DailyRewards.coins[challenge.tier] or 60
	local xp = Challenges.DailyRewards.xp[challenge.tier] or 50
	self.S.EconomyService:AddCoins(player, coins, "challenge")
	self.S.EconomyService:AddXp(player, xp)
	self.S.ShopService:Notify(player, "challenge", {
		text = template.text:format(challenge.target),
		icon = template.icon,
		coins = coins,
		xp = xp,
	})
	local allDone = true
	for _, other in data.daily.list do
		if not other.done then
			allDone = false
		end
	end
	if allDone and not data.daily.bonusClaimed then
		data.daily.bonusClaimed = true
		data.spins += 1
		self.S.DataService:Replicate(player, "spins")
		self.S.ShopService:Notify(player, "toast", { text = "All daily challenges done! +1 Mystery Flask", kind = "reward" })
	end
end

return ChallengeService
