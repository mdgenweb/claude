--!strict
-- Renders every battle this client can see (own match + nearby arenas).
--
-- * Snapshots (20 Hz, binary) are buffered and interpolated with a 100 ms render delay.
-- * Events carry the simulation time (`tm`) they happened at and are replayed exactly when the
--   interpolated timeline reaches them, so hit sparks line up with the visible collision.
-- * Orbs are camera-facing 2D art (OrbArt) on BillboardGuis anchored in the arena plane: they
--   read as perfect spheres from any angle and support squash/stretch, flashes and overlays.
-- * Heavy hits get a few frames of hit-stop, camera shake and an FOV punch (participants only).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Physics = require(Shared.Config.Physics)
local BallDefinitions = require(Shared.Definitions.BallDefinitions)
local SnapshotCodec = require(Shared.Net.SnapshotCodec)
local Remotes = require(Shared.Net.Remotes)
local ArenaGeometry = require(Shared.Visual.ArenaGeometry)
local Signal = require(Shared.Util.Signal)

local Client = script.Parent.Parent
local OrbArt = require(Client.UI.Components.OrbArt)
local Effects = require(Client.VFX.Effects)
local EntityVisuals = require(Client.VFX.EntityVisuals)
local Explosions = require(Client.VFX.Explosions)
local AudioController = require(script.Parent.AudioController)
local CameraController = require(script.Parent.CameraController)

local BattleRenderer = {}

BattleRenderer.Overtime = Signal.new() -- (stationIndex, level)
BattleRenderer.BallSpawned = Signal.new() -- (stationIndex, ballId, defId, owner)

local Flags = SnapshotCodec.Flags
local hex = Color3.fromHex

type BallView = {
	id: number,
	def: string,
	team: number,
	owner: number,
	minion: boolean,
	r: number,
	hp: number,
	maxHp: number,
	anchor: Part,
	gui: BillboardGui,
	group: CanvasGroup,
	art: OrbArt.Handle,
	hpLabel: TextLabel,
	overlays: { [string]: Frame },
	x: number,
	y: number,
	roll: number,
	flags: number,
	squash: number,
	squashAxis: number,
	detached: boolean,
	tail: { Vector3 }?,
	tailParts: { BasePart }?,
}

type EntityView = {
	vis: EntityVisuals.Visual,
	dynamic: boolean,
	armAt: number?,
}

type StationView = {
	index: number,
	cf: CFrame,
	kind: string,
	folder: Folder,
	balls: { [number]: BallView },
	entities: { [number]: EntityView },
	snaps: { SnapshotCodec.Snapshot },
	events: { { [string]: any } },
	offsetSamples: { number },
	offset: number?,
	frozenRT: number?,
	freezeUntil: number,
	extraDelay: number,
	lastRT: number,
	cosmetics: { [number]: { Explosion: string, Flyer: string } },
	participant: boolean,
}

local views: { [number]: StationView } = {}
local root: Folder

---------------------------------------------------------------------------------------------
-- Station lookup

local function stationModel(index: number): Model?
	for _, model in Workspace:WaitForChild("Lobby"):WaitForChild("Stations"):GetChildren() do
		if model:GetAttribute("StationIndex") == index then
			return model :: Model
		end
	end
	return nil
end

local function getView(index: number): StationView?
	local view = views[index]
	if view then
		return view
	end
	local model = stationModel(index)
	if model == nil then
		return nil
	end
	local kind = model:GetAttribute("Kind") :: string
	local floor = model:GetAttribute("Floor") :: Vector3
	local yaw = model:GetAttribute("Yaw") :: number
	local folder = Instance.new("Folder")
	folder.Name = "Station" .. index
	folder.Parent = root
	local v: StationView = {
		index = index,
		cf = ArenaGeometry.StationCFrame({ floor.X, floor.Y, floor.Z }, yaw, kind),
		kind = kind,
		folder = folder,
		balls = {},
		entities = {},
		snaps = {},
		events = {},
		offsetSamples = {},
		offset = nil,
		frozenRT = nil,
		freezeUntil = 0,
		extraDelay = 0,
		lastRT = 0,
		cosmetics = {},
		participant = false,
	}
	views[index] = v
	return v
end

function BattleRenderer.StationCFrame(index: number): (CFrame?, string?)
	local v = getView(index)
	if v then
		return v.cf, v.kind
	end
	return nil, nil
end

function BattleRenderer.SetSummary(index: number, summary: { [string]: any }, isParticipant: boolean)
	local v = getView(index)
	if v == nil then
		return
	end
	v.participant = isParticipant
	for _, p in summary.Participants do
		v.cosmetics[p.UserId] = { Explosion = p.Explosion, Flyer = p.Flyer }
	end
end

local function toWorld(v: StationView, x: number, y: number, z: number?): Vector3
	return ArenaGeometry.SimToWorld(v.cf, v.kind, x, y, z)
end

---------------------------------------------------------------------------------------------
-- Ball views

local function overlayCircle(parent: GuiObject, name: string, color: Color3, transparency: number, z: number, strokeOnly: boolean?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromScale(1 / OrbArt.Padding * 1.04, 1 / OrbArt.Padding * 1.04)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = if strokeOnly then 1 else transparency
	f.BorderSizePixel = 0
	f.ZIndex = z
	f.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = f
	if strokeOnly then
		local stroke = Instance.new("UIStroke")
		stroke.Color = color
		stroke.Thickness = 4
		stroke.Transparency = transparency
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = f
	end
	f.Parent = parent
	return f
end

local function destroyBall(v: StationView, id: number)
	local ball = v.balls[id]
	if ball == nil then
		return
	end
	v.balls[id] = nil
	ball.anchor:Destroy()
	if ball.tailParts then
		for _, p in ball.tailParts do
			p:Destroy()
		end
	end
end

local function createBall(v: StationView, e: { [string]: any }): BallView
	destroyBall(v, e.id)
	local r = e.r or 1.5
	local anchor = Effects.Part()
	anchor.Name = "Orb" .. e.id
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = CFrame.new(toWorld(v, e.x, e.y))
	anchor.Parent = v.folder

	local gui = Instance.new("BillboardGui")
	gui.Name = "OrbGui"
	gui.Adornee = anchor
	gui.Size = UDim2.new(2 * r * OrbArt.Padding, 0, 2 * r * OrbArt.Padding, 0)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.MaxDistance = 260
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = anchor

	local group = Instance.new("CanvasGroup")
	group.BackgroundTransparency = 1
	group.Size = UDim2.fromScale(1, 1)
	group.Parent = gui
	local art = OrbArt.Draw(group, e.def, 1, true)

	local hp = Instance.new("TextLabel")
	hp.Name = "HP"
	hp.BackgroundTransparency = 1
	hp.AnchorPoint = Vector2.new(0.5, 0.5)
	hp.Position = UDim2.fromScale(0.5, 0.52)
	hp.Size = UDim2.fromScale(0.5, 0.3)
	hp.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Heavy)
	hp.TextScaled = true
	hp.TextColor3 = Color3.new(1, 1, 1)
	hp.Text = tostring(math.ceil(e.hp or 100))
	hp.ZIndex = 40
	hp.Visible = not e.minion
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = hp
	hp:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		stroke.Thickness = math.clamp(hp.AbsoluteSize.Y * 0.08, 1, 5)
	end)
	hp.Parent = gui

	local overlays = {
		Frozen = overlayCircle(group, "Frozen", hex("#BDF3FF"), 0.35, 30),
		Slowed = overlayCircle(group, "Slowed", hex("#6EDB3A"), 0.7, 31),
		Snared = overlayCircle(group, "Snared", hex("#C9CCD3"), 0, 32, true),
		Latched = overlayCircle(group, "Latched", hex("#FF3D4F"), 0.1, 33, true),
		Charging = overlayCircle(group, "Charging", Color3.new(1, 1, 1), 0.2, 34, true),
	}

	-- motion streak
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, r * 0.55, 0)
	a0.Parent = anchor
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -r * 0.55, 0)
	a1.Parent = anchor
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	local def = BallDefinitions.Get(e.def)
	local base = if def then hex(def.Visual.Base) else Color3.new(1, 1, 1)
	trail.Color = ColorSequence.new(base)
	trail.Transparency = NumberSequence.new(0.55, 1)
	trail.Lifetime = 0.12
	trail.LightEmission = 0.3
	trail.FaceCamera = true
	trail.Parent = anchor

	local ball: BallView = {
		id = e.id,
		def = e.def,
		team = e.team,
		owner = e.owner,
		minion = e.minion == true,
		r = r,
		hp = e.hp or 100,
		maxHp = e.maxHp or 100,
		anchor = anchor,
		gui = gui,
		group = group,
		art = art,
		hpLabel = hp,
		overlays = overlays,
		x = e.x,
		y = e.y,
		roll = 0,
		flags = 0,
		squash = 0,
		squashAxis = 0,
		detached = false,
		tail = nil,
		tailParts = nil,
	}
	if def and def.AbilityId == "serpent" then
		ball.tail = {}
		ball.tailParts = {}
		for i = 1, 16 do
			local p = Effects.Part(Enum.PartType.Ball)
			p.Color = hex(def.Visual.Accent)
			p.Size = Vector3.one * (1.0 - i * 0.03)
			p.Transparency = 1
			p.Parent = v.folder
			table.insert(ball.tailParts :: { BasePart }, p)
		end
	end
	v.balls[e.id] = ball
	-- spawn pop
	local s = Instance.new("UIScale")
	s.Scale = 0.2
	s.Parent = group
	TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	BattleRenderer.BallSpawned:Fire(v.index, e.id, e.def, e.owner)
	return ball
end

local function flashBall(ball: BallView, color: Color3?)
	local flash = ball.art.Flash
	flash.BackgroundColor3 = color or Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 0.15
	TweenService:Create(flash, TweenInfo.new(0.18), { BackgroundTransparency = 1 }):Play()
end

local function squashBall(ball: BallView, nx: number, ny: number, amount: number)
	ball.squash = amount
	ball.squashAxis = if math.abs(nx) >= math.abs(ny) then 0 else 1
end

---------------------------------------------------------------------------------------------
-- Event playback

local function ballPos(v: StationView, id: number?): Vector3?
	if id == nil then
		return nil
	end
	local ball = v.balls[id]
	if ball then
		return toWorld(v, ball.x, ball.y, 0.6)
	end
	return nil
end

local function shakeIfMine(v: StationView, magnitude: number, punch: number?)
	if v.participant then
		CameraController.Shake(magnitude)
		if punch then
			CameraController.Punch(punch)
		end
	end
end

local fx: { [string]: (StationView, { [string]: any }) -> () } = {
	bump = function(v, e)
		Effects.Sparks(toWorld(v, e.x, e.y, 0.6), hex("#FFB347"), 12, 14, 0.5)
	end,
	boost = function(v, e)
		Effects.Sparks(toWorld(v, e.x, e.y, 0.6), hex("#9BE15D"), 10, 10, 0.5)
	end,
	sunburst = function(v, e)
		local pos = toWorld(v, e.x, e.y, 0.6)
		Effects.Flash(pos, 5, hex("#FFE14D"), 0.35)
		Effects.Ring(pos, -v.cf.LookVector, e.r or 6, hex("#FFD23F"), 0.45)
		AudioController.Play("Ability", pos)
	end,
	throw = function(v, e)
		local pos = ballPos(v, e.id)
		if pos then
			AudioController.Play("Whoosh", pos, 0.1, 0.5)
		end
	end,
	muzzle = function(v, e)
		local pos = toWorld(v, e.x, e.y, 0.6)
		Effects.Flash(pos, 1.6, hex("#FFE14D"), 0.12)
		Effects.Smoke(pos, hex("#9CA2AB"), 4)
		AudioController.Play("Shoot", pos)
	end,
	moonAdded = function(v, e)
		local pos = ballPos(v, e.id)
		if pos then
			Effects.Sparks(pos, hex("#C9D0FF"), 10, 8, 0.4)
		end
	end,
	tether = function(v, e)
		local a, b = v.balls[e.a], v.balls[e.b]
		if a and b then
			Effects.Tether(a.anchor, b.anchor, hex("#FF3D4F"), e.duration or 1)
			AudioController.Play("Ability", a.anchor.Position)
		end
	end,
	splat = function(v, e)
		local pos = toWorld(v, e.x, e.y, 0.6)
		Effects.Sparks(pos, hex("#6EDB3A"), 10, 8, 0.6)
		AudioController.Play("Splat", pos, 0.1)
	end,
	magnet = function(v, e)
		local pos = toWorld(v, e.x, e.y, 0.6)
		Effects.Ring(pos, -v.cf.LookVector, 7, hex("#D7263D"), 0.4)
		AudioController.Play("Ability", pos)
	end,
	freeze = function(v, e)
		local pos = ballPos(v, e.id) or toWorld(v, e.x, e.y)
		Effects.Sparks(pos, hex("#BDF3FF"), 18, 10, 0.5)
		AudioController.Play("Freeze", pos)
	end,
	explosion = function(v, e)
		local pos = toWorld(v, e.x, e.y, 0.6)
		local c = if e.color then hex(e.color) else hex("#FF5E1A")
		Effects.Flash(pos, (e.r or 3) * 2, c, 0.3)
		Effects.Ring(pos, -v.cf.LookVector, e.r or 3, c, 0.35)
		Effects.Sparks(pos, c, 30, 18, 0.7)
		AudioController.Play("Explosion", pos)
		shakeIfMine(v, 0.25)
	end,
	beamCharge = function(v, e)
		local pos = toWorld(v, e.x, e.y, 0.6)
		AudioController.Play("Laser", pos, 0.1)
	end,
	dice = function(v, e)
		local pos = ballPos(v, e.id)
		if pos then
			local six = e.roll == 6
			Effects.Popup(pos + Vector3.new(0, 2.2, 0), if six then "JACKPOT 6!" else tostring(e.roll), if six then hex("#FFE14D") else Color3.new(1, 1, 1), if six then 1.4 else 1)
		end
	end,
	phase = function(v, e)
		local pos = ballPos(v, e.id)
		if pos then
			AudioController.Play("Ability", pos, nil, 0.6)
		end
	end,
	unphase = function(v, e)
		if e.spook then
			local pos = toWorld(v, e.x, e.y, 0.6)
			Effects.Ring(pos, -v.cf.LookVector, 4, hex("#B9A8FF"), 0.35)
			Effects.Popup(pos + Vector3.new(0, 2, 0), "BOO!", hex("#CFC8FF"), 1.3)
		end
	end,
	haunt = function(v, e)
		Effects.Sparks(toWorld(v, e.x, e.y, 0.6), hex("#B9A8FF"), 10, 8, 0.5)
	end,
	forgeCharge = function(v, e)
		local pos = ballPos(v, e.id)
		if pos and e.charge ~= 0 then
			Effects.Popup(pos + Vector3.new(0, 2, 0), string.format("%d/%d", e.charge, e.max), hex("#FFB000"), 0.8)
		end
	end,
	shockwave = function(v, e)
		local pos = toWorld(v, e.x, e.y, 0.6)
		local c = if e.color then hex(e.color) else hex("#FFB000")
		Effects.Ring(pos, -v.cf.LookVector, e.r or 4.5, c, 0.4, 0.4)
		Effects.Flash(pos, 4, c, 0.25)
		Effects.Popup(pos + Vector3.new(0, 2.4, 0), "SMASH!", c, 1.4)
		AudioController.Play("HitHeavy", pos)
		shakeIfMine(v, 0.4, 4)
	end,
	shatter = function(v, e)
		AudioController.Play("Shatter", toWorld(v, e.x, e.y), 0.15, 0.6)
	end,
	lightning = function(v, e)
		local from = ballPos(v, e.from)
		local to = ballPos(v, e.to) or toWorld(v, e.x, e.y, 0.6)
		if from and to then
			Effects.Lightning(from, to, hex("#FFE14D"), 0.25)
			AudioController.Play("Zap", to)
		end
	end,
	enrage = function(v, e)
		local pos = ballPos(v, e.id)
		if pos then
			Effects.Popup(pos + Vector3.new(0, 2.4, 0), "SUPERCHARGED", hex("#FFE14D"), 1.2)
			Effects.Flash(pos, 4, hex("#8C8FFF"), 0.3)
		end
	end,
	grow = function(v, e)
		local pos = ballPos(v, e.id)
		if pos then
			Effects.Sparks(pos, hex("#FF7BD5"), 8, 6, 0.4)
		end
	end,
	split = function(v, e)
		local pos = toWorld(v, e.x, e.y, 0.6)
		Effects.Flash(pos, 5, hex("#FF7BD5"), 0.3)
		Effects.Popup(pos + Vector3.new(0, 2.4, 0), "SPLIT!", hex("#FF7BD5"), 1.2)
	end,
	windup = function(v, e)
		local pos = ballPos(v, e.id)
		if pos then
			Effects.Ring(pos, -v.cf.LookVector, 3, Color3.new(1, 1, 1), 0.3)
		end
	end,
	charge = function(v, e)
		local pos = ballPos(v, e.id)
		if pos then
			AudioController.Play("Whoosh", pos)
		end
	end,
	railLaid = function(v, e)
		AudioController.Play("Ability", toWorld(v, e.x, e.y), 0.2)
	end,
	train = function(v, e)
		local pos = ballPos(v, e.id) or v.cf.Position
		AudioController.Play("Train", pos)
	end,
	trainHit = function(v, e)
		local pos = toWorld(v, e.x, e.y, 0.6)
		Effects.Flash(pos, 4, hex("#FFCC00"), 0.25)
		AudioController.Play("HitHeavy", pos)
		shakeIfMine(v, 0.45, 5)
	end,
	chained = function(v, e)
		local pos = toWorld(v, e.x, e.y, 0.6)
		Effects.Sparks(pos, hex("#C9CCD3"), 12, 8, 0.4)
		AudioController.Play("Freeze", pos, nil, 0.7)
	end,
	trapsDropped = function(v, e)
		local pos = ballPos(v, e.id)
		if pos then
			AudioController.Play("Ability", pos, 0.2, 0.5)
		end
	end,
	lob = function(v, e)
		local pos = ballPos(v, e.id)
		if pos then
			AudioController.Play("Shoot", pos, nil, 0.6)
		end
	end,
}

local function clearView(v: StationView)
	for id in v.balls do
		destroyBall(v, id)
	end
	for _, ent in v.entities do
		ent.vis.Destroy()
	end
	table.clear(v.entities)
	table.clear(v.snaps)
	table.clear(v.events)
	table.clear(v.offsetSamples)
	v.offset = nil
	v.frozenRT = nil
	v.extraDelay = 0
end

local function spawnEntity(v: StationView, e: { [string]: any })
	local existing = v.entities[e.id]
	if existing then
		existing.vis.Destroy()
	end
	local vis = EntityVisuals.Create(v.cf, v.kind, e, v.folder)
	if vis == nil then
		return
	end
	local armAt: number? = nil
	if (e.armed or 0) > 0 then
		armAt = (e.tm or 0) + e.armed
		if v.offset == nil then
			-- no timeline yet (aim phase): arm on a wall-clock delay instead
			local armFn = vis.Arm
			if armFn then
				task.delay(e.armed, armFn)
			end
			armAt = nil
		end
	elseif vis.Arm then
		vis.Arm()
	end
	v.entities[e.id] = { vis = vis, dynamic = e.dynamic == true, armAt = armAt }
end

local function applyEvent(v: StationView, e: { [string]: any })
	local t = e.t
	if t == "BallSpawn" then
		createBall(v, e)
	elseif t == "Launch" then
		local ball = v.balls[e.id]
		if ball then
			AudioController.Play("Launch", ball.anchor.Position, 0.05)
			Effects.Sparks(ball.anchor.Position, Color3.new(1, 1, 1), 12, 12, 0.5)
		end
	elseif t == "Wall" then
		local ball = v.balls[e.id]
		if ball then
			local pos = toWorld(v, e.x, e.y, 0.4)
			AudioController.Play("Bounce", pos, 0.06)
			Effects.Sparks(pos, Color3.fromRGB(220, 225, 235), 4, 6, 0.3)
			squashBall(ball, e.nx, e.ny, 0.16)
		end
	elseif t == "Hit" then
		local a, b = v.balls[e.a], v.balls[e.b]
		local pos = toWorld(v, e.x, e.y, 0.7)
		if e.friendly then
			AudioController.Play("Bounce", pos, 0.05)
			return
		end
		local heavy = e.heavy == true
		Effects.Sparks(pos, if heavy then hex("#FFE14D") else Color3.new(1, 1, 1), if heavy then 28 else 14, if heavy then 22 else 14, if heavy then 0.8 else 0.5)
		if heavy then
			Effects.Flash(pos, 3, hex("#FFF2B3"), 0.18)
		end
		AudioController.Play(if heavy then "HitHeavy" else "HitLight", pos)
		for _, ball in { a, b } do
			if ball then
				flashBall(ball)
				squashBall(ball, e.nx or 1, e.ny or 0, if heavy then 0.28 else 0.18)
			end
		end
		if heavy then
			shakeIfMine(v, 0.35, 3)
			if v.participant and v.offset then
				v.freezeUntil = os.clock() + 0.07
			end
		end
	elseif t == "Damage" then
		local ball = v.balls[e.id]
		if ball then
			flashBall(ball, hex("#FF5A6A"))
			ball.hp = math.max(0, ball.hp - (e.amount or 0))
			ball.hpLabel.Text = tostring(math.ceil(ball.hp))
			if (e.amount or 0) >= 1 and not ball.minion then
				local pos = toWorld(v, ball.x, ball.y, 0.8) + Vector3.new(0, ball.r * 1.1, 0)
				Effects.Popup(pos, "-" .. math.floor(e.amount + 0.5), if e.amount >= 10 then hex("#FFB347") else hex("#FF6B7F"), if e.amount >= 10 then 1.2 else 0.8)
			end
		end
	elseif t == "Heal" then
		local ball = v.balls[e.id]
		if ball and (e.amount or 0) >= 1 then
			ball.hp = math.min(ball.maxHp, ball.hp + e.amount)
			ball.hpLabel.Text = tostring(math.ceil(ball.hp))
			Effects.Popup(toWorld(v, ball.x, ball.y, 0.8) + Vector3.new(0, ball.r * 1.1, 0), "+" .. math.floor(e.amount + 0.5), hex("#7CFF6B"), 0.8)
		end
	elseif t == "Death" then
		local ball = v.balls[e.id]
		local pos = toWorld(v, e.x, e.y, 0.6)
		local cosmetics = if ball then v.cosmetics[ball.owner] else nil
		if ball and not ball.minion then
			Explosions.Play(if cosmetics then cosmetics.Explosion else "classic", pos, v.cf, ball.r)
			AudioController.Play("Death", pos)
			shakeIfMine(v, 0.5, 6)
		else
			Effects.Flash(pos, 2, Color3.new(1, 1, 1), 0.2)
			Effects.Sparks(pos, Color3.new(1, 1, 1), 10, 10, 0.4)
		end
		destroyBall(v, e.id)
	elseif t == "EntitySpawn" then
		spawnEntity(v, e)
	elseif t == "EntityRemove" then
		local ent = v.entities[e.id]
		if ent then
			v.entities[e.id] = nil
			ent.vis.Destroy()
		end
	elseif t == "Status" then
		local ball = v.balls[e.id]
		if ball and e.status == "frozen" then
			flashBall(ball, hex("#BDF3FF"))
		end
	elseif t == "Overtime" then
		BattleRenderer.Overtime:Fire(v.index, e.level)
	elseif t == "Fx" then
		local handler = fx[e.kind]
		if handler then
			handler(v, e)
		end
	elseif t == "Full" then
		clearView(v)
		local state = e.state
		for _, b in state.balls do
			createBall(v, { id = b.id, def = b.def, team = b.team, owner = b.owner, x = b.x, y = b.y, r = b.r, hp = b.hp, maxHp = b.maxHp, minion = b.minion })
		end
		for _, ent in state.entities do
			spawnEntity(v, ent)
		end
	elseif t == "Clear" then
		clearView(v)
	end
end

local function onEvents(index: number, events: { { [string]: any } })
	local v = getView(index)
	if v == nil then
		return
	end
	for _, e in events do
		if e.t == "Full" or e.t == "Clear" or e.tm == nil or v.offset == nil then
			applyEvent(v, e)
		else
			table.insert(v.events, e)
		end
	end
end

local function onSnapshot(payload: buffer)
	local snap = SnapshotCodec.Decode(payload)
	if snap == nil then
		return
	end
	local v = getView(snap.station)
	if v == nil then
		return
	end
	local last = v.snaps[#v.snaps]
	if last and snap.time <= last.time then
		return -- out of order / duplicate
	end
	table.insert(v.snaps, snap)
	while #v.snaps > 30 do
		table.remove(v.snaps, 1)
	end
	-- local clock offset estimate: minimum over a sliding window (least delayed packet)
	table.insert(v.offsetSamples, os.clock() - snap.time)
	while #v.offsetSamples > 40 do
		table.remove(v.offsetSamples, 1)
	end
	local best = math.huge
	for _, s in v.offsetSamples do
		best = math.min(best, s)
	end
	v.offset = best
end

---------------------------------------------------------------------------------------------
-- Per-frame rendering

local function renderTime(v: StationView, dt: number): number
	local now = os.clock()
	local rt = now - (v.offset :: number) - Physics.InterpolationDelay
	if now < v.freezeUntil then
		if v.frozenRT == nil then
			v.frozenRT = v.lastRT
		end
		return v.frozenRT :: number
	elseif v.frozenRT then
		v.extraDelay = math.max(v.extraDelay, rt - (v.frozenRT :: number))
		v.frozenRT = nil
	end
	if v.extraDelay > 0 then
		v.extraDelay = math.max(0, v.extraDelay - dt * 0.35)
	end
	return rt - v.extraDelay
end

local function sample(v: StationView, rt: number): (SnapshotCodec.Snapshot?, SnapshotCodec.Snapshot?, number)
	local snaps = v.snaps
	local n = #snaps
	if n == 0 then
		return nil, nil, 0
	end
	if rt <= snaps[1].time then
		return snaps[1], snaps[1], 0
	end
	for i = n - 1, 1, -1 do
		local a, b = snaps[i], snaps[i + 1]
		if rt >= a.time then
			local span = b.time - a.time
			local alpha = if span > 0 then math.clamp((rt - a.time) / span, 0, 1) else 1
			return a, b, alpha
		end
	end
	return snaps[n], snaps[n], 0
end

local function updateView(v: StationView, dt: number, camPos: Vector3)
	local rt = v.lastRT
	if v.offset then
		rt = renderTime(v, dt)
		v.lastRT = rt
		-- replay events up to the render time
		while #v.events > 0 and (v.events[1].tm or 0) <= rt do
			applyEvent(v, table.remove(v.events, 1) :: { [string]: any })
		end
		local a, b, alpha = sample(v, rt)
		if a and b then
			local bBalls: { [number]: SnapshotCodec.BallState } = {}
			for _, s in b.balls do
				bBalls[s.id] = s
			end
			for _, s0 in a.balls do
				local ball = v.balls[s0.id]
				if ball and not ball.detached then
					local s1 = bBalls[s0.id] or s0
					local x = s0.x + (s1.x - s0.x) * alpha
					local y = s0.y + (s1.y - s0.y) * alpha
					local dx = x - ball.x
					ball.roll += math.deg(dx / math.max(ball.r, 0.3))
					ball.x, ball.y = x, y
					ball.flags = s1.flags
					if math.abs(s1.r - ball.r) > 0.01 then
						ball.r = s1.r
						ball.gui.Size = UDim2.new(2 * ball.r * OrbArt.Padding, 0, 2 * ball.r * OrbArt.Padding, 0)
					end
					local hp = s1.hp
					if math.abs(hp - ball.hp) >= 1 then
						ball.hp = hp
						ball.hpLabel.Text = tostring(math.ceil(hp))
					end
				end
			end
			local bEnts: { [number]: SnapshotCodec.EntityState } = {}
			for _, s in b.entities do
				bEnts[s.id] = s
			end
			for _, s0 in a.entities do
				local ent = v.entities[s0.id]
				if ent and ent.dynamic then
					local s1 = bEnts[s0.id] or s0
					local drot = math.atan2(math.sin(s1.rot - s0.rot), math.cos(s1.rot - s0.rot))
					ent.vis.Update(s0.x + (s1.x - s0.x) * alpha, s0.y + (s1.y - s0.y) * alpha, s0.rot + drot * alpha, s0.scale + (s1.scale - s0.scale) * alpha)
				end
			end
		end
		for _, ent in v.entities do
			if ent.armAt and rt >= ent.armAt then
				ent.armAt = nil
				if ent.vis.Arm then
					ent.vis.Arm()
				end
			end
		end
	end

	-- ball presentation
	for _, ball in v.balls do
		if ball.detached then
			continue
		end
		local center = toWorld(v, ball.x, ball.y, 0)
		local toCam = camPos - center
		local offset = if toCam.Magnitude > 0.01 then toCam.Unit * (ball.r * 0.9) else Vector3.zero
		ball.anchor.CFrame = CFrame.new(center + offset)
		ball.art:SetRotation(ball.roll % 360)
		-- squash & stretch (decays quickly)
		ball.squash = ball.squash * math.exp(-dt * 14)
		local sq = ball.squash
		local size = 2 * ball.r * OrbArt.Padding
		if ball.squashAxis == 0 then
			ball.gui.Size = UDim2.new(size * (1 - sq), 0, size * (1 + sq * 0.6), 0)
		else
			ball.gui.Size = UDim2.new(size * (1 + sq * 0.6), 0, size * (1 - sq), 0)
		end
		-- status overlays from snapshot flags
		local f = ball.flags
		ball.overlays.Frozen.Visible = bit32.band(f, Flags.Frozen) ~= 0
		ball.overlays.Slowed.Visible = bit32.band(f, Flags.Slowed) ~= 0
		ball.overlays.Snared.Visible = bit32.band(f, Flags.Snared) ~= 0
		ball.overlays.Latched.Visible = bit32.band(f, Flags.Latched) ~= 0
		ball.overlays.Charging.Visible = bit32.band(f, Flags.Charging) ~= 0
		ball.group.GroupTransparency = if bit32.band(f, Flags.Phased) ~= 0 then 0.6 else 0
		-- serpent tail
		local tail = ball.tail
		local parts = ball.tailParts
		if tail and parts then
			table.insert(tail, 1, toWorld(v, ball.x, ball.y, -0.3))
			while #tail > 60 do
				table.remove(tail)
			end
			for i, p in parts do
				local pt = tail[i * 3 + 3]
				if pt then
					p.Position = pt
					p.Transparency = 0.1 + i * 0.04
				else
					p.Transparency = 1
				end
			end
		end
	end
end

function BattleRenderer.GetBallAnchor(index: number, ballId: number): BasePart?
	local v = views[index]
	local ball = v and v.balls[ballId]
	return if ball then ball.anchor else nil
end

function BattleRenderer.DetachBall(index: number, ballId: number): BasePart?
	local v = views[index]
	local ball = v and v.balls[ballId]
	if ball then
		ball.detached = true
		return ball.anchor
	end
	return nil
end

function BattleRenderer.Start()
	root = Instance.new("Folder")
	root.Name = "ClientBattles"
	root.Parent = Workspace
	Remotes.Event("BattleEvent").OnClientEvent:Connect(onEvents)
	Remotes.Unreliable("BattleSnapshot").OnClientEvent:Connect(onSnapshot)
	RunService.RenderStepped:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end
		local camPos = camera.CFrame.Position
		for _, v in views do
			if next(v.balls) or next(v.entities) or #v.events > 0 then
				updateView(v, dt, camPos)
			end
		end
	end)
end

return BattleRenderer
