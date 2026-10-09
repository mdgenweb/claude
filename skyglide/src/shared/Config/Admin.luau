--!strict
-- Diagnostics access. Normal players never see or reach admin tools: the server rejects
-- AdminRequest from anyone not listed here (Studio test sessions are allowed when StudioAll).
return {
	UserIds = {} :: { number }, -- add your user id(s) before publishing
	StudioAll = true,
}
