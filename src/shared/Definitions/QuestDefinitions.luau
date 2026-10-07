--!strict
-- Daily quests (CONFIRMED in the reference HUD: "Duel with a friend 0/1", "Win 3 times 1/3",
-- "Play 10 times 1/10", each paying x200 coins). Reset time is (LIKELY) daily at 00:00 UTC.
export type Quest = {
	Id: string,
	Title: string,
	Goal: number,
	Event: "FriendDuel" | "Win" | "Play",
	Reward: { Coins: number },
}

local QuestDefinitions = {}

QuestDefinitions.Daily = {
	{ Id = "friendDuel", Title = "Duel with a friend", Goal = 1, Event = "FriendDuel", Reward = { Coins = 200 } },
	{ Id = "win3", Title = "Win 3 times", Goal = 3, Event = "Win", Reward = { Coins = 200 } },
	{ Id = "play10", Title = "Play 10 times", Goal = 10, Event = "Play", Reward = { Coins = 200 } },
} :: { Quest }

function QuestDefinitions.DayIndex(unixTime: number): number
	return unixTime // 86400
end

function QuestDefinitions.Get(id: string): Quest?
	for _, q in QuestDefinitions.Daily do
		if q.Id == id then
			return q
		end
	end
	return nil
end

return QuestDefinitions
