--!strict
-- Match rules and timings. Values marked (TUNABLE) are not publicly documented for the
-- reference game; see docs/RESEARCH.md section F.
return {
	Hearts = 3, -- CONFIRMED: three hearts per side

	Timings = {
		MatchFoundCountdown = 3,
		MatchIntro = 2.6,
		SelectionTime = 15, -- (TUNABLE)
		SelectionGrace = 0.6, -- pause after everyone picked
		AimTime = 12, -- (TUNABLE)
		Countdown = 3,
		RoundResolution = 3.6, -- explosion + flyer + heart break
		DrawResolution = 2.2,
		MatchVictory = 3.8,
		ReleaseDelay = 0.4,
	},

	Selection = {
		OfferCount = 3, -- CONFIRMED
		OfferSource = "Global", -- "Global" (default, see research) or "Owned"
		RerollCost = 10, -- gems (TUNABLE)
		MaxRerollsPerRound = 3,
		FreeCollectionPicksPerMatch = 1, -- CONFIRMED: free once per match
		ExtraCollectionPickCost = 25, -- gems for further collection picks (TUNABLE)
	},

	Modes = {
		["1v1"] = { TeamSize = 1, ArenaKind = "Duel", Label = "1V1" },
		["2v2"] = { TeamSize = 2, ArenaKind = "Team", Label = "2V2" },
	},

	-- Ball spawn points (arena-plane coordinates, studs from the arena centre).
	SpawnLayout = {
		["1v1"] = {
			[1] = { { x = -4.5, y = 0 } },
			[2] = { { x = 4.5, y = 0 } },
		},
		["2v2"] = {
			[1] = { { x = -5.5, y = 3.5 }, { x = -5.5, y = -3.5 } },
			[2] = { { x = 5.5, y = 3.5 }, { x = 5.5, y = -3.5 } },
		},
	},

	FriendlyFire = false,

	-- Practice bot: OUR ADDITION (not part of the reference). Lets solo players test and
	-- fills quiet servers. Rewards are reduced.
	Bots = {
		Enabled = true,
		RewardMultiplier = 0.2,
		Name = "Practice Bot",
	},

	-- Characters are held on their pad while waiting/battling.
	LockCharactersOnPads = true,
	SpectatorRange = 150, -- studs; players inside receive live battle snapshots
	InviteTimeout = 20,
}
