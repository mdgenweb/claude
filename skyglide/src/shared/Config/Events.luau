--!strict
-- Live events ("Sky Festival"): server-wide boosts. ORIGINAL take on the reference's admin events
-- (LIKELY: those turn on server-wide Skill/Wins boosts and raise special-throw odds).
-- Scheduled windows are unix seconds (UTC). Admins can also start one from the Admin panel.
export type Window = { Name: string, StartsAt: number, EndsAt: number }

return {
	Name = "SKY FESTIVAL",
	SkillMultiplier = 2,
	WinsMultiplier = 2,
	SpecialLuck = 3, -- special throws x3 as likely
	Schedule = {} :: { Window },
}
