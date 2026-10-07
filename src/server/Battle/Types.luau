--!strict
-- Types shared by the battle simulation, the ability modules and the match controller.
export type Status = {
	frozen: number,
	snared: number,
	slowed: number,
	slowFactor: number,
	phased: number,
	charging: number,
	latched: number,
	invuln: number,
}

export type Ball = {
	id: number,
	defId: string,
	def: any, -- BallDefinition (kept loose so headless tests can stub definitions)
	owner: number, -- userId (negative for bots)
	team: number,
	isMinion: boolean,
	x: number,
	y: number,
	vx: number,
	vy: number,
	r: number,
	baseR: number,
	mass: number,
	hp: number,
	maxHp: number,
	contact: number,
	speedMult: number,
	gravityScale: number,
	alive: boolean,
	launched: boolean,
	status: Status,
	frozenVuln: number,
	dmgTakenMult: number,
	dmgDealtMult: number,
	ability: Ability?,
	params: { [string]: any },
	state: { [string]: any },
	attrition: number,
	damageDealt: number,
	lastAttacker: number?,
}

export type Entity = {
	id: number,
	kind: string,
	shape: "circle" | "segment" | "none",
	x: number,
	y: number,
	x2: number,
	y2: number,
	r: number,
	vx: number,
	vy: number,
	rot: number,
	scale: number,
	owner: Ball?,
	team: number,
	life: number,
	age: number,
	armed: number,
	dynamic: boolean,
	gravity: number,
	dieOnWall: boolean,
	pierce: boolean,
	damage: number,
	damageKind: string,
	hitCooldown: number,
	hits: { [number]: number },
	persist: boolean,
	removed: boolean,
	data: { [string]: any },
	visual: { [string]: any },
	onHit: ((ctx: any, e: Entity, ball: Ball) -> ())?,
	onUpdate: ((ctx: any, e: Entity, dt: number) -> ())?,
	onExpire: ((ctx: any, e: Entity) -> ())?,
	onWall: ((ctx: any, e: Entity) -> ())?,
}

export type EntitySpec = {
	kind: string,
	shape: ("circle" | "segment" | "none")?,
	x: number,
	y: number,
	x2: number?,
	y2: number?,
	r: number?,
	vx: number?,
	vy: number?,
	rot: number?,
	scale: number?,
	owner: Ball?,
	team: number?,
	life: number?,
	armed: number?,
	dynamic: boolean?,
	gravity: number?,
	dieOnWall: boolean?,
	pierce: boolean?,
	damage: number?,
	damageKind: string?,
	hitCooldown: number?,
	persist: boolean?,
	data: { [string]: any }?,
	visual: { [string]: any }?,
	onHit: ((ctx: any, e: Entity, ball: Ball) -> ())?,
	onUpdate: ((ctx: any, e: Entity, dt: number) -> ())?,
	onExpire: ((ctx: any, e: Entity) -> ())?,
	onWall: ((ctx: any, e: Entity) -> ())?,
}

export type DamageInfo = {
	source: Ball?,
	kind: string, -- "contact" | "hazard" | "ability" | "overtime" | "drain"
	entity: Entity?,
	ignorePhase: boolean?,
	x: number?,
	y: number?,
}

-- Ability hooks. Every hook is optional. `ctx` is the World (see World.luau public helpers).
export type Ability = {
	Init: ((ctx: any, ball: Ball, params: { [string]: any }) -> ())?,
	OnLaunch: ((ctx: any, ball: Ball, params: { [string]: any }) -> ())?,
	OnTick: ((ctx: any, ball: Ball, params: { [string]: any }, dt: number) -> ())?,
	OnWallHit: ((ctx: any, ball: Ball, params: { [string]: any }, nx: number, ny: number, px: number, py: number) -> ())?,
	OnBallHit: ((ctx: any, ball: Ball, params: { [string]: any }, other: Ball, cx: number, cy: number) -> ())?,
	ModifyContact: ((ctx: any, ball: Ball, params: { [string]: any }, other: Ball, damage: number) -> number)?,
	OnDamageTaken: ((ctx: any, ball: Ball, params: { [string]: any }, amount: number, info: DamageInfo) -> number)?,
	OnDamageDealt: ((ctx: any, ball: Ball, params: { [string]: any }, target: Ball, amount: number, info: DamageInfo) -> ())?,
	OnHealthChanged: ((ctx: any, ball: Ball, params: { [string]: any }, old: number, new: number) -> ())?,
	OnDeath: ((ctx: any, ball: Ball, params: { [string]: any }, killer: Ball?) -> boolean?)?,
	OnKill: ((ctx: any, ball: Ball, params: { [string]: any }, victim: Ball) -> ())?,
}

export type BattleEvent = { [string]: any }

export type Result = { state: "ongoing" } | { state: "win", team: number } | { state: "draw" }

return {}
