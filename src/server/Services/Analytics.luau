-- Thin, failure-proof wrappers around AnalyticsService and BadgeService.
-- Tracks the concept's funnel: first smash, first upgrade, first form, each gate, rebirth.

local AnalyticsService = game:GetService("AnalyticsService")
local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")

local Analytics = {}

-- In the order a free player reaches them (Gate 1 needs Power 10, the Crusher form
-- Power 25; the Mega Mech form is Power 250, which is also Gate 2's requirement).
local FUNNEL = {
	Joined = 1,
	PickedTool = 2,
	FirstSmash = 3,
	FirstUpgrade = 4,
	ApplianceRow = 5,
	CrusherForm = 6,
	MegaMech = 7,
	CrusherYard = 8,
	FirstRebirth = 9,
}

-- Logs a funnel step once per player (remembered in saved data).
function Analytics.funnel(player: Player, data, step: string)
	if data.Funnel[step] then
		return
	end
	data.Funnel[step] = true
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, FUNNEL[step], step)
	end)
end

function Analytics.economy(
	player: Player,
	isSource: boolean,
	amount: number,
	balance: number,
	transactionType: Enum.AnalyticsEconomyTransactionType,
	sku: string
)
	if amount <= 0 then
		return
	end
	pcall(function()
		AnalyticsService:LogEconomyEvent(
			player,
			if isSource then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink,
			"Scrap",
			amount,
			balance,
			transactionType.Name,
			sku
		)
	end)
end

function Analytics.progression(player: Player, path: string, level: number, name: string)
	pcall(function()
		AnalyticsService:LogProgressionCompleteEvent(player, path, level, name)
	end)
end

function Analytics.badge(player: Player, badgeId: number)
	if badgeId == 0 then
		return
	end
	task.spawn(function()
		local ok, has = pcall(function()
			return BadgeService:UserHasBadgeAsync(player.UserId, badgeId)
		end)
		if ok and not has then
			pcall(function()
				BadgeService:AwardBadge(player.UserId, badgeId)
			end)
		end
	end)
end

-- Smash income is frequent, so it is summed and logged once a minute per player.
local pendingSmash: { [Player]: number } = {}

function Analytics.smashIncome(player: Player, amount: number)
	pendingSmash[player] = (pendingSmash[player] or 0) + amount
end

function Analytics.flush(getBalance: (Player) -> number?)
	for player, amount in pendingSmash do
		pendingSmash[player] = nil
		local balance = getBalance(player)
		if balance and player.Parent then
			Analytics.economy(player, true, amount, balance, Enum.AnalyticsEconomyTransactionType.Gameplay, "Smash")
		end
	end
end

Players.PlayerRemoving:Connect(function(player)
	pendingSmash[player] = nil
end)

return Analytics
