--!strict
-- Server-authoritative match state machine shared by 1v1 and 2v2.
--
--   MatchIntro -> RoundStart -> BallSelection -> AimPhase -> Countdown -> Battling
--      -> RoundResolution -> (RoundStart | MatchVictory) -> Closed
--
-- Every transition is driven by server time (workspace:GetServerTimeNow) so clients can show
-- exact countdowns. Player input only *requests* actions; this module validates them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.Game)
local PhysicsConfig = require(Shared.Config.Physics)
local BallDefinitions = require(Shared.Definitions.BallDefinitions)
local ArenaGeometry = require(Shared.Visual.ArenaGeometry)
local Validate = require(Shared.Util.Validate)

local World = require(script.Parent.World)
local BotBrain = require(script.Parent.BotBrain)

export type Participant = {
	UserId: number,
	Name: string,
	Player: Player?,
	IsBot: boolean,
	Team: number,
	Pad: number,
	Slot: number,
	Connected: boolean,
	Offers: { string },
	Rerolls: number,
	Picked: boolean,
	Selected: string?,
	FreePicksUsed: number,
	Aim: number,
	Locked: boolean,
	BallId: number?,
	Explosion: string,
	Flyer: string,
	VsFriend: boolean,
	ThinkAt: number?,
}

export type ParticipantSpec = {
	Player: Player?,
	BotName: string?,
	BotId: number?,
	Team: number,
	Pad: number,
}

-- Services injected by MatchService (avoids require cycles).
export type Deps = {
	BallService: any,
	AbilityService: any,
	EconomyService: any,
	DataService: any,
	RewardService: any,
	ArenaService: any,
	Replicator: any,
	PrivateRemote: RemoteEvent,
	Notify: (Player, string) -> (),
	OnPublicChanged: (match: any) -> (),
	OnClosed: (match: any) -> (),
}

local Match = {}
Match.__index = Match

local T = GameConfig.Timings
local SEL = GameConfig.Selection

local nextMatchId = 0

export type Match = typeof(setmetatable(
	{} :: {
		Id: number,
		Station: any,
		Mode: string,
		Kind: string,
		Half: number,
		Practice: boolean,
		Participants: { Participant },
		Teams: { { Hearts: number } },
		Round: number,
		State: string,
		Deadline: number,
		World: World.World?,
		Seq: number,
		SnapshotClock: number,
		PendingEvents: { { [string]: any } },
		RoundResult: { [string]: any }?,
		WinnerTeam: number?,
		Forfeit: boolean,
		LastPublic: { [string]: any }?,
		Deps: Deps,
		Rng: Random,
		Closed: boolean,
	},
	Match
))

local function now(): number
	return Workspace:GetServerTimeNow()
end

function Match.new(deps: Deps, station: any, specs: { ParticipantSpec }, practice: boolean): Match
	nextMatchId += 1
	local kind = ArenaGeometry.KindForMode(station.Mode)
	local participants: { Participant } = {}
	local slots: { [number]: number } = {}
	for _, spec in specs do
		slots[spec.Team] = (slots[spec.Team] or 0) + 1
		local player = spec.Player
		local explosion, flyer = "classic", "basic"
		if player then
			local profile = deps.DataService.Get(player)
			if profile then
				explosion = profile.Equipped.Explosion
				flyer = profile.Equipped.Flyer
			end
		end
		table.insert(participants, {
			UserId = if player then player.UserId else (spec.BotId or -1),
			Name = if player then player.DisplayName else (spec.BotName or GameConfig.Bots.Name),
			Player = player,
			IsBot = player == nil,
			Team = spec.Team,
			Pad = spec.Pad,
			Slot = slots[spec.Team],
			Connected = player ~= nil,
			Offers = {},
			Rerolls = 0,
			Picked = false,
			Selected = nil,
			FreePicksUsed = 0,
			Aim = 0,
			Locked = false,
			BallId = nil,
			Explosion = explosion,
			Flyer = flyer,
			VsFriend = false,
			ThinkAt = nil,
		})
	end
	local self = setmetatable({
		Id = nextMatchId,
		Station = station,
		Mode = station.Mode,
		Kind = kind,
		Half = ArenaGeometry.Get(kind).Half,
		Practice = practice,
		Participants = participants,
		Teams = { { Hearts = GameConfig.Hearts }, { Hearts = GameConfig.Hearts } },
		Round = 0,
		State = "Created",
		Deadline = 0,
		World = nil,
		Seq = 0,
		SnapshotClock = 0,
		PendingEvents = {},
		RoundResult = nil,
		WinnerTeam = nil,
		Forfeit = false,
		LastPublic = nil,
		Deps = deps,
		Rng = Random.new(),
		Closed = false,
	}, Match)
	return self
end

---------------------------------------------------------------------------------------------
-- Queries

function Match.Players(self: Match): { Player }
	local out = {}
	for _, p in self.Participants do
		if p.Player and p.Connected then
			table.insert(out, p.Player)
		end
	end
	return out
end

function Match.ParticipantOf(self: Match, player: Player): Participant?
	for _, p in self.Participants do
		if p.Player == player then
			return p
		end
	end
	return nil
end

local function autoControlled(p: Participant): boolean
	return p.IsBot or not p.Connected
end

function Match.Summary(self: Match): { [string]: any }
	local list = {}
	for _, p in self.Participants do
		table.insert(list, {
			UserId = p.UserId,
			Name = p.Name,
			Team = p.Team,
			Pad = p.Pad,
			Slot = p.Slot,
			IsBot = p.IsBot,
			Connected = p.Connected,
			Ball = if self.State == "BallSelection" then nil else p.Selected,
			Picked = p.Picked,
			Locked = p.Locked,
			BallId = p.BallId,
			Explosion = p.Explosion,
			Flyer = p.Flyer,
		})
	end
	return {
		MatchId = self.Id,
		Station = self.Station.Index,
		StationId = self.Station.Id,
		Mode = self.Mode,
		Kind = self.Kind,
		Practice = self.Practice,
		Round = self.Round,
		State = self.State,
		Deadline = self.Deadline,
		Hearts = { self.Teams[1].Hearts, self.Teams[2].Hearts },
		MaxHearts = GameConfig.Hearts,
		Participants = list,
	}
end

function Match.PublicState(self: Match): { [string]: any }?
	return self.LastPublic
end

function Match.FullState(self: Match): { [string]: any }?
	if self.World == nil then
		return nil
	end
	return (self.World :: World.World):FullState()
end

---------------------------------------------------------------------------------------------
-- Networking helpers

function Match._public(self: Match, kind: string, extra: { [string]: any }?)
	local payload: { [string]: any } = { Type = kind, Summary = self:Summary() }
	if extra then
		for k, v in extra do
			payload[k] = v
		end
	end
	-- remember the latest state snapshot for late spectators (without one-shot extras)
	self.LastPublic = { Type = "State", Summary = payload.Summary }
	self.Deps.Replicator.SendPublic(self.Station, payload)
	self.Deps.OnPublicChanged(self)
end

function Match._private(self: Match, p: Participant, payload: { [string]: any })
	local player = p.Player
	if player and p.Connected and player.Parent then
		payload.MatchId = self.Id
		payload.Station = self.Station.Index
		self.Deps.PrivateRemote:FireClient(player, payload)
	end
end

function Match._sendSelection(self: Match, p: Participant)
	self:_private(p, {
		Type = "Selection",
		Round = self.Round,
		Offers = p.Offers,
		Picked = p.Picked,
		Selected = p.Selected,
		RerollsLeft = SEL.MaxRerollsPerRound - p.Rerolls,
		RerollCost = SEL.RerollCost,
		FreePicksLeft = math.max(0, SEL.FreeCollectionPicksPerMatch - p.FreePicksUsed),
		CollectionCost = SEL.ExtraCollectionPickCost,
		Deadline = self.Deadline,
	})
end

function Match._flushEvents(self: Match)
	local world = self.World
	if world then
		local tm = world.time
		for _, e in world:DrainEvents() do
			e.tm = tm
			table.insert(self.PendingEvents, e)
		end
	end
	if #self.PendingEvents > 0 then
		self.Deps.Replicator.SendEvents(self.Station, self.PendingEvents)
		self.PendingEvents = {}
	end
end

---------------------------------------------------------------------------------------------
-- State machine

function Match.Start(self: Match)
	-- friend check for the "Duel with a friend" quest (async, non-blocking)
	task.spawn(function()
		for _, a in self.Participants do
			for _, b in self.Participants do
				local pa = a.Player
				if pa and b.Player and a ~= b and a.Team ~= b.Team then
					local ok, friends = pcall(function()
						return pa:IsFriendsWith(b.UserId)
					end)
					if ok and friends then
						a.VsFriend = true
					end
				end
			end
		end
	end)
	self:_enter("MatchIntro")
end

function Match._enter(self: Match, state: string)
	if self.Closed then
		return
	end
	self.State = state
	local t = now()
	if state == "MatchIntro" then
		self.Deadline = t + T.MatchIntro
		self:_public("Intro")
	elseif state == "RoundStart" then
		self.Round += 1
		for _, p in self.Participants do
			p.Offers = self.Deps.BallService.RollOffers(p.Player, SEL.OfferCount)
			p.Rerolls = 0
			p.Picked = false
			p.Selected = nil
			p.Locked = false
			p.BallId = nil
			p.ThinkAt = nil
		end
		self:_enter("BallSelection")
	elseif state == "BallSelection" then
		self.Deadline = t + T.SelectionTime
		for _, p in self.Participants do
			self:_sendSelection(p)
		end
		self:_public("Selection")
	elseif state == "AimPhase" then
		self:_buildWorld()
		self.Deadline = t + T.AimTime
		self:_public("Aim")
		self:_flushEvents()
		local world = self.World :: World.World
		for _, p in self.Participants do
			local ball = if p.BallId then world.ballsById[p.BallId] else nil
			if ball then
				self:_private(p, {
					Type = "Aim",
					BallId = ball.id,
					X = ball.x,
					Y = ball.y,
					Radius = ball.r,
					DefaultAngle = p.Aim,
					Deadline = self.Deadline,
					Half = self.Half,
				})
			end
		end
	elseif state == "Countdown" then
		self.Deadline = t + T.Countdown
		self:_public("Countdown")
	elseif state == "Battling" then
		local world = self.World :: World.World
		for _, p in self.Participants do
			if p.BallId then
				world:Launch(p.BallId, p.Aim)
			end
		end
		self.SnapshotClock = 0
		self.Deadline = t + PhysicsConfig.RoundHardCap + 5
		self:_public("Battle")
		self:_flushEvents()
	elseif state == "RoundResolution" then
		self:_resolveRound()
	elseif state == "MatchVictory" then
		self:_victory()
	elseif state == "Closed" then
		self:_close()
	end
end

function Match._buildWorld(self: Match)
	local deps = self.Deps
	local world = World.new({
		seed = self.Rng:NextInteger(1, 2 ^ 30),
		half = self.Half,
		resolveAbility = deps.AbilityService.Get,
		resolveDefinition = BallDefinitions.Get,
		friendlyFire = GameConfig.FriendlyFire,
	})
	self.World = world
	local layout = GameConfig.SpawnLayout[self.Mode]
	for _, p in self.Participants do
		if p.Selected == nil then
			p.Selected = p.Offers[1] or "bumper"
		end
		local spot = layout[p.Team][p.Slot] or layout[p.Team][1]
		local ball = world:SpawnBall({ defId = p.Selected :: string, owner = p.UserId, team = p.Team, x = spot.x, y = spot.y })
		p.BallId = ball.id
		p.Aim = if p.Team == 1 then math.rad(30) else math.rad(150)
		p.Locked = false
		p.ThinkAt = nil
	end
end

function Match._resolveRound(self: Match)
	local world = self.World :: World.World
	local result = world:GetResult()
	world:Finish()
	self:_flushEvents()
	local t = now()
	if result.state == "win" then
		local winner = (result :: any).team :: number
		local loser = if winner == 1 then 2 else 1
		self.Teams[loser].Hearts = math.max(0, self.Teams[loser].Hearts - 1)
		local winnerBalls = {}
		local flyerOwner: Participant? = nil
		for _, ball in world.balls do
			if ball.alive and ball.team == winner then
				table.insert(winnerBalls, { Id = ball.id, X = ball.x, Y = ball.y, Def = ball.defId, R = ball.r })
			end
		end
		local losers = {}
		for _, p in self.Participants do
			if p.Team == loser then
				table.insert(losers, p.UserId)
			elseif flyerOwner == nil then
				local ball = if p.BallId then world.ballsById[p.BallId] else nil
				if ball and ball.alive then
					flyerOwner = p
				end
			end
		end
		if flyerOwner == nil then
			for _, p in self.Participants do
				if p.Team == winner then
					flyerOwner = p
					break
				end
			end
		end
		self.RoundResult = { Winner = winner, Loser = loser }
		self.Deadline = t + T.RoundResolution
		self:_public("RoundEnd", {
			Winner = winner,
			Loser = loser,
			Draw = false,
			WinnerBalls = winnerBalls,
			LoserUserIds = losers,
			Flyer = if flyerOwner then flyerOwner.Flyer else "basic",
		})
	else
		self.RoundResult = { Draw = true }
		self.Deadline = t + T.DrawResolution
		self:_public("RoundEnd", { Draw = true })
	end
end

function Match._victory(self: Match)
	local winner = self.WinnerTeam
	if winner == nil then
		winner = if self.Teams[1].Hearts > self.Teams[2].Hearts then 1 else 2
		self.WinnerTeam = winner
	end
	self.Deadline = now() + T.MatchVictory
	self:_public("Victory", { WinnerTeam = winner, Forfeit = self.Forfeit })
	for _, p in self.Participants do
		local player = p.Player
		if player and p.Connected and player.Parent then
			local won = p.Team == winner
			local ok, summary = pcall(self.Deps.RewardService.GrantMatch, player, {
				Won = won,
				Forfeit = self.Forfeit,
				Practice = self.Practice,
				VsFriend = p.VsFriend,
			})
			self:_private(p, {
				Type = "Results",
				Won = won,
				Forfeit = self.Forfeit,
				Practice = self.Practice,
				Rewards = if ok then summary else nil,
				Hearts = { self.Teams[1].Hearts, self.Teams[2].Hearts },
				Team = p.Team,
			})
		end
	end
end

function Match._close(self: Match)
	if self.Closed then
		return
	end
	self.Closed = true
	self.World = nil
	self.Deps.Replicator.SendEvents(self.Station, { { t = "Clear" } })
	self:_public("Closed")
	self.Deps.OnClosed(self)
end

function Match.Abort(self: Match, reason: string)
	warn(string.format("[Match %d] aborted: %s", self.Id, reason))
	self:_enter("Closed")
end

---------------------------------------------------------------------------------------------
-- Per-frame update

local function allPicked(self: Match): boolean
	for _, p in self.Participants do
		if not p.Picked then
			return false
		end
	end
	return true
end

local function allLocked(self: Match): boolean
	for _, p in self.Participants do
		if not p.Locked then
			return false
		end
	end
	return true
end

function Match._autoPick(self: Match, p: Participant, index: number)
	if p.Picked then
		return
	end
	p.Selected = p.Offers[math.clamp(index, 1, math.max(1, #p.Offers))]
	p.Picked = true
	self:_sendSelection(p)
	self:_public("Selection")
	if allPicked(self) then
		self.Deadline = math.min(self.Deadline, now() + T.SelectionGrace)
	end
end

function Match.Update(self: Match, dt: number)
	if self.Closed then
		return
	end
	local t = now()
	local state = self.State

	if state == "BallSelection" then
		for _, p in self.Participants do
			if autoControlled(p) and not p.Picked then
				local index = BotBrain.Selection(p :: any, t)
				if index then
					self:_autoPick(p, index)
				end
			end
		end
		if t >= self.Deadline then
			for _, p in self.Participants do
				if not p.Picked then
					p.Selected = p.Offers[self.Rng:NextInteger(1, math.max(1, #p.Offers))]
					p.Picked = true
				end
			end
			self:_enter("AimPhase")
		end
	elseif state == "AimPhase" then
		local world = self.World :: World.World
		for _, p in self.Participants do
			if autoControlled(p) and not p.Locked and p.BallId then
				local ball = world.ballsById[p.BallId]
				-- aim at the first enemy ball
				local tx, ty = 0, 0
				for _, other in world.balls do
					if other.team ~= p.Team then
						tx, ty = other.x, other.y
						break
					end
				end
				local angle = BotBrain.Aim(p :: any, t, ball.x, ball.y, tx, ty)
				if angle then
					p.Aim = angle
					p.Locked = true
					self:_public("AimLock", { UserId = p.UserId })
					if allLocked(self) then
						self.Deadline = math.min(self.Deadline, t + 0.6)
					end
				end
			end
		end
		if t >= self.Deadline then
			self:_enter("Countdown")
		end
	elseif state == "Battling" then
		local world = self.World :: World.World
		world:Advance(dt)
		self.SnapshotClock += dt
		if self.SnapshotClock >= 1 / PhysicsConfig.SnapshotRate then
			self.SnapshotClock = 0
			self.Seq += 1
			self:_flushEvents()
			self.Deps.Replicator.SendSnapshot(self.Station, world:Snapshot(self.Station.Index, self.Seq))
		end
		if world:GetResult().state ~= "ongoing" or t >= self.Deadline then
			self.Seq += 1
			self.Deps.Replicator.SendSnapshot(self.Station, world:Snapshot(self.Station.Index, self.Seq))
			self:_enter("RoundResolution")
		end
	elseif t >= self.Deadline then
		if state == "MatchIntro" then
			self:_enter("RoundStart")
		elseif state == "Countdown" then
			self:_enter("Battling")
		elseif state == "RoundResolution" then
			self.Deps.Replicator.SendEvents(self.Station, { { t = "Clear" } })
			self.World = nil
			if self.Teams[1].Hearts <= 0 or self.Teams[2].Hearts <= 0 then
				self.WinnerTeam = if self.Teams[1].Hearts > 0 then 1 else 2
				self:_enter("MatchVictory")
			else
				self:_enter("RoundStart")
			end
		elseif state == "MatchVictory" then
			self:_enter("Closed")
		end
	end
end

---------------------------------------------------------------------------------------------
-- Player requests (validated)

function Match.HandleSelection(self: Match, player: Player, action: any, arg: any)
	if self.State ~= "BallSelection" then
		return
	end
	local p = self:ParticipantOf(player)
	if p == nil or p.Picked then
		return
	end
	local deps = self.Deps
	if action == "Pick" then
		if not Validate.Integer(arg, 1, #p.Offers) then
			return
		end
		self:_autoPick(p, arg)
		return
	elseif action == "Reroll" then
		if p.Rerolls >= SEL.MaxRerollsPerRound then
			deps.Notify(player, "No rerolls left this round.")
			return
		end
		if not deps.EconomyService.TrySpend(player, "Gems", SEL.RerollCost) then
			deps.Notify(player, string.format("You need %d Gems to reroll.", SEL.RerollCost))
			return
		end
		p.Rerolls += 1
		p.Offers = deps.BallService.RollOffers(player, SEL.OfferCount, p.Offers)
		self:_sendSelection(p)
		return
	elseif action == "Collection" then
		if not BallDefinitions.Exists(arg) or not deps.BallService.Owns(player, arg) then
			deps.Notify(player, "You don't own that Orb.")
			return
		end
		local free = p.FreePicksUsed < SEL.FreeCollectionPicksPerMatch
		if not free and not deps.EconomyService.TrySpend(player, "Gems", SEL.ExtraCollectionPickCost) then
			deps.Notify(player, string.format("Collection picks cost %d Gems after your free one.", SEL.ExtraCollectionPickCost))
			return
		end
		p.FreePicksUsed += 1
		p.Selected = arg
		p.Picked = true
		self:_sendSelection(p)
		self:_public("Selection")
		if allPicked(self) then
			self.Deadline = math.min(self.Deadline, now() + T.SelectionGrace)
		end
	end
end

local function wrapAngle(a: number): number
	return math.atan2(math.sin(a), math.cos(a))
end

function Match.HandleAim(self: Match, player: Player, angle: any, lock: boolean)
	if self.State ~= "AimPhase" then
		return
	end
	local p = self:ParticipantOf(player)
	if p == nil or p.Locked or not Validate.Number(angle, -100, 100) then
		return
	end
	p.Aim = wrapAngle(angle)
	if lock then
		p.Locked = true
		self:_public("AimLock", { UserId = p.UserId })
		if allLocked(self) then
			self.Deadline = math.min(self.Deadline, now() + 0.6)
		end
	end
end

function Match.OnPlayerLeft(self: Match, player: Player)
	local p = self:ParticipantOf(player)
	if p == nil then
		return
	end
	p.Connected = false
	p.Player = nil
	if self.Closed or self.State == "MatchVictory" then
		return
	end
	local humansLeft = { 0, 0 }
	for _, other in self.Participants do
		if other.Connected and not other.IsBot then
			humansLeft[other.Team] += 1
		end
	end
	if humansLeft[1] + humansLeft[2] == 0 then
		self:_enter("Closed")
		return
	end
	if humansLeft[p.Team] == 0 then
		-- whole team gone: the other side wins by forfeit
		if self.World then
			(self.World :: World.World):Finish()
			self.Deps.Replicator.SendEvents(self.Station, { { t = "Clear" } })
			self.World = nil
		end
		self.Forfeit = true
		self.WinnerTeam = if p.Team == 1 then 2 else 1
		self:_enter("MatchVictory")
	else
		self:_public("Update")
	end
end

return Match
