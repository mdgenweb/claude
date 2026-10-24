-- Free auto-hit: while a player stands within reach of their own junk, they hit it
-- every 0.5 s for their current Power. The first hit lands one interval after a target
-- comes into reach. Open blocking menus pause salvage.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local StateService = require(script.Parent.StateService)
local TargetService = require(script.Parent.TargetService)

local CombatService = {}

type HitState = { target: Model?, nextHit: number? }
local states: { [Player]: HitState } = {}

local function step(now: number)
	local interval = Config.Combat.HitInterval
	for player, session in StateService.all() do
		local st = states[player]
		if not st then
			st = { target = nil, nextHit = nil }
			states[player] = st
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 or not session.Lane or session.InMenu then
			st.target, st.nextHit = nil, nil
			continue
		end
		local position = root.Position
		local target = st.target
		if target and not TargetService.inReach(session, target, position) then
			target = nil
		end
		if not target then
			target = TargetService.nearestInReach(session, position)
		end
		if target ~= st.target then
			st.target = target
			st.nextHit = if target then now + interval else nil
		end
		if target and st.nextHit and now >= st.nextHit then
			TargetService.damage(player, session, target, StateService.power(session))
			local nextHit = st.nextHit + interval
			st.nextHit = if nextHit < now then now + interval else nextHit
		end
	end
end

function CombatService.init()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < Config.Combat.TickRate then
			return
		end
		accumulator = 0
		step(os.clock())
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return CombatService
