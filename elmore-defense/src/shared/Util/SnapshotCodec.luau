--[[
	SnapshotCodec
	Packs enemy state into a compact buffer for UnreliableRemoteEvent (payloads must stay < ~900 bytes).

	Record layout (11 bytes):
		u16 id | f32 distance | u16 speed*100 | u16 hpFraction*65535 | u8 flags
	flags: bit0 stunned, bit1 slowed, bit2 burning, bit3 shielded, bit4 shredded
]]

local SnapshotCodec = {}

SnapshotCodec.RECORD_SIZE = 11
SnapshotCodec.HEADER_SIZE = 8 -- f64 server time
SnapshotCodec.MAX_PER_PACKET = 78 -- 8 + 78*11 = 866 bytes

SnapshotCodec.FLAG_STUNNED = 1
SnapshotCodec.FLAG_SLOWED = 2
SnapshotCodec.FLAG_BURNING = 4
SnapshotCodec.FLAG_SHIELDED = 8
SnapshotCodec.FLAG_SHREDDED = 16

export type Record = {
	id: number,
	distance: number,
	speed: number,
	hp: number, -- 0..1
	flags: number,
}

-- Encodes up to MAX_PER_PACKET records starting at `startIndex`. Returns buffer and next index.
function SnapshotCodec.encode(records: { Record }, startIndex: number, serverTime: number): (buffer, number)
	local count = math.min(#records - startIndex + 1, SnapshotCodec.MAX_PER_PACKET)
	count = math.max(count, 0)
	local buf = buffer.create(SnapshotCodec.HEADER_SIZE + count * SnapshotCodec.RECORD_SIZE)
	buffer.writef64(buf, 0, serverTime)
	local offset = SnapshotCodec.HEADER_SIZE
	for index = startIndex, startIndex + count - 1 do
		local record = records[index]
		buffer.writeu16(buf, offset, record.id % 65536)
		buffer.writef32(buf, offset + 2, record.distance)
		buffer.writeu16(buf, offset + 6, math.clamp(math.floor(record.speed * 100 + 0.5), 0, 65535))
		buffer.writeu16(buf, offset + 8, math.clamp(math.floor(record.hp * 65535 + 0.5), 0, 65535))
		buffer.writeu8(buf, offset + 10, record.flags % 256)
		offset += SnapshotCodec.RECORD_SIZE
	end
	return buf, startIndex + count
end

function SnapshotCodec.decode(buf: buffer): (number, { Record })
	local length = buffer.len(buf)
	if length < SnapshotCodec.HEADER_SIZE then
		return 0, {}
	end
	local serverTime = buffer.readf64(buf, 0)
	local records = {}
	local offset = SnapshotCodec.HEADER_SIZE
	while offset + SnapshotCodec.RECORD_SIZE <= length do
		table.insert(records, {
			id = buffer.readu16(buf, offset),
			distance = buffer.readf32(buf, offset + 2),
			speed = buffer.readu16(buf, offset + 6) / 100,
			hp = buffer.readu16(buf, offset + 8) / 65535,
			flags = buffer.readu8(buf, offset + 10),
		})
		offset += SnapshotCodec.RECORD_SIZE
	end
	return serverTime, records
end

return SnapshotCodec
