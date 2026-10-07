--!strict
-- Compact binary encoding of battle snapshots (sent over UnreliableRemoteEvent, which caps
-- payloads near 900 bytes). Layout:
--   u8  stationIndex
--   u16 sequence
--   f32 simTime
--   u8  ballCount, then per ball:   u8 id, i16 x, i16 y, u16 hp, u8 radius*20, u8 flags
--   u8  entityCount, then per ent:  u16 id, i16 x, i16 y, u8 rotation, u8 scale*20
-- Positions are quantised to 1/2000 stud (range +-16 studs).
local SnapshotCodec = {}

local POS_SCALE = 2000
local POS_LIMIT = 32767
local BALL_BYTES = 9
local ENT_BYTES = 8
local HEADER_BYTES = 1 + 2 + 4 + 1 + 1

SnapshotCodec.Flags = {
	Frozen = 1,
	Snared = 2,
	Phased = 4,
	Slowed = 8,
	Charging = 16,
	Latched = 32,
	Invulnerable = 64,
	Dead = 128,
}

export type BallState = { id: number, x: number, y: number, hp: number, r: number, flags: number }
export type EntityState = { id: number, x: number, y: number, rot: number, scale: number }
export type Snapshot = {
	station: number,
	seq: number,
	time: number,
	balls: { BallState },
	entities: { EntityState },
}

local function qpos(v: number): number
	return math.clamp(math.floor(v * POS_SCALE + 0.5), -POS_LIMIT, POS_LIMIT)
end

local function qbyte(v: number): number
	return math.clamp(math.floor(v + 0.5), 0, 255)
end

function SnapshotCodec.Encode(s: Snapshot): buffer
	local ballCount = math.min(#s.balls, 255)
	local entCount = math.min(#s.entities, 255)
	local b = buffer.create(HEADER_BYTES + ballCount * BALL_BYTES + entCount * ENT_BYTES)
	local o = 0
	buffer.writeu8(b, o, s.station)
	o += 1
	buffer.writeu16(b, o, s.seq % 65536)
	o += 2
	buffer.writef32(b, o, s.time)
	o += 4
	buffer.writeu8(b, o, ballCount)
	o += 1
	for i = 1, ballCount do
		local ball = s.balls[i]
		buffer.writeu8(b, o, ball.id % 256)
		buffer.writei16(b, o + 1, qpos(ball.x))
		buffer.writei16(b, o + 3, qpos(ball.y))
		buffer.writeu16(b, o + 5, math.clamp(math.ceil(ball.hp), 0, 65535))
		buffer.writeu8(b, o + 7, qbyte(ball.r * 20))
		buffer.writeu8(b, o + 8, ball.flags % 256)
		o += BALL_BYTES
	end
	buffer.writeu8(b, o, entCount)
	o += 1
	for i = 1, entCount do
		local e = s.entities[i]
		buffer.writeu16(b, o, e.id % 65536)
		buffer.writei16(b, o + 2, qpos(e.x))
		buffer.writei16(b, o + 4, qpos(e.y))
		buffer.writeu8(b, o + 6, math.floor(((e.rot % (2 * math.pi)) / (2 * math.pi)) * 256) % 256)
		buffer.writeu8(b, o + 7, qbyte(e.scale * 20))
		o += ENT_BYTES
	end
	return b
end

function SnapshotCodec.Decode(b: buffer): Snapshot?
	local len = buffer.len(b)
	if len < HEADER_BYTES then
		return nil
	end
	local o = 0
	local station = buffer.readu8(b, o)
	o += 1
	local seq = buffer.readu16(b, o)
	o += 2
	local time = buffer.readf32(b, o)
	o += 4
	local ballCount = buffer.readu8(b, o)
	o += 1
	if len < o + ballCount * BALL_BYTES + 1 then
		return nil
	end
	local balls: { BallState } = table.create(ballCount)
	for _ = 1, ballCount do
		table.insert(balls, {
			id = buffer.readu8(b, o),
			x = buffer.readi16(b, o + 1) / POS_SCALE,
			y = buffer.readi16(b, o + 3) / POS_SCALE,
			hp = buffer.readu16(b, o + 5),
			r = buffer.readu8(b, o + 7) / 20,
			flags = buffer.readu8(b, o + 8),
		})
		o += BALL_BYTES
	end
	local entCount = buffer.readu8(b, o)
	o += 1
	if len < o + entCount * ENT_BYTES then
		return nil
	end
	local entities: { EntityState } = table.create(entCount)
	for _ = 1, entCount do
		table.insert(entities, {
			id = buffer.readu16(b, o),
			x = buffer.readi16(b, o + 2) / POS_SCALE,
			y = buffer.readi16(b, o + 4) / POS_SCALE,
			rot = buffer.readu8(b, o + 6) / 256 * 2 * math.pi,
			scale = buffer.readu8(b, o + 7) / 20,
		})
		o += ENT_BYTES
	end
	return { station = station, seq = seq, time = time, balls = balls, entities = entities }
end

SnapshotCodec.MaxBytes = function(balls: number, entities: number): number
	return HEADER_BYTES + balls * BALL_BYTES + entities * ENT_BYTES
end

return SnapshotCodec
