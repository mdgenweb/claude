--!strict
-- First-session guide. The server advances steps from real gameplay events (never from the
-- client saying "done"); the client draws the hint and an arrow to the target.
export type Step = {
	Id: string,
	Text: string,
	Target: string?, -- map anchor name (MapService registers anchors per world)
	Event: string, -- server event that completes the step
	Count: number?,
}

local steps: { Step } = {
	{ Id = "train", Text = "Stand on the 1x SKILL pad and tap to train!", Target = "Pad1", Event = "Train", Count = 15 },
	{ Id = "zone", Text = "Walk into the THROW ZONE.", Target = "ThrowZone", Event = "EnterThrowZone" },
	{ Id = "throw", Text = "Hold THROW, release in the green for a PERFECT launch!", Target = "ThrowZone", Event = "Throw" },
	{ Id = "gust", Text = "Tap when your glider hits a ring for a PERFECT catch (x2 Skill)!", Target = nil, Event = "Ring", Count = 3 },
	{ Id = "glider", Text = "Spend Wins on a better glider at the shop!", Target = "GliderShop", Event = "BuyGlider" },
	{ Id = "egg", Text = "Hatch an egg for a pet that boosts your Skill.", Target = "Egg1", Event = "Hatch" },
}

return {
	Steps = steps,
}
