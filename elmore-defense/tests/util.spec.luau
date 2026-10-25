local PathMath = require(Shared.Util.PathMath)
local SnapshotCodec = require(Shared.Util.SnapshotCodec)
local Format = require(Shared.Util.Format)
local WeightedRandom = require(Shared.Util.WeightedRandom)
local TableUtil = require(Shared.Util.TableUtil)

describe("PathMath", function()
	local path = PathMath.build({ Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), Vector3.new(10, 0, 10) })
	it("measures length", function()
		expect(path.length).toBeNear(20)
	end)
	it("samples positions along segments", function()
		local p = PathMath.sample(path, 5)
		expect(p.X).toBeNear(5)
		local q, dir = PathMath.sample(path, 15)
		expect(q.X).toBeNear(10)
		expect(q.Z).toBeNear(5)
		expect(dir.Z).toBeNear(1)
		local finish = PathMath.sample(path, 999)
		expect(finish.Z).toBeNear(10)
	end)
	it("measures distance to path", function()
		expect(PathMath.distanceToPath(path, Vector3.new(5, 0, 3))).toBeNear(3)
		expect(PathMath.distanceToPath(path, Vector3.new(13, 0, 5))).toBeNear(3)
	end)
end)

describe("SnapshotCodec", function()
	it("round-trips and fits an unreliable packet", function()
		local records = {}
		for index = 1, 200 do
			table.insert(records, { id = index, distance = index * 1.5, speed = 5.25, hp = 0.5, flags = 3 })
		end
		local nextIndex = 1
		local decodedTotal = 0
		while nextIndex <= #records do
			local buf
			buf, nextIndex = SnapshotCodec.encode(records, nextIndex, 123.5)
			expect(buffer.len(buf)).toBeAtMost(900)
			local time, decoded = SnapshotCodec.decode(buf)
			expect(time).toBeNear(123.5)
			for _, record in decoded do
				local original = records[record.id]
				expect(record.distance).toBeNear(original.distance, 1e-3)
				expect(record.speed).toBeNear(5.25, 0.01)
				expect(record.hp).toBeNear(0.5, 1e-4)
				expect(record.flags).toBe(3)
			end
			decodedTotal += #decoded
		end
		expect(decodedTotal).toBe(200)
	end)
end)

describe("Format", function()
	it("formats numbers", function()
		expect(Format.number(1234)).toBe("1,234")
		expect(Format.number(999)).toBe("999")
		expect(Format.number(1500000)).toBe("1.5M")
		expect(Format.number(100000000)).toBe("100M")
		expect(Format.number(25000, true)).toBe("25K")
	end)
	it("formats percents and clocks", function()
		expect(Format.percent(69.85)).toBe("69.85%")
		expect(Format.percent(25)).toBe("25%")
		expect(Format.percent(0.05)).toBe("0.05%")
		expect(Format.percent(0.2)).toBe("0.2%")
		expect(Format.clock(2738)).toBe("45:38")
		expect(Format.clock(3700)).toBe("1:01:40")
	end)
end)

describe("WeightedRandom", function()
	it("boost keeps the total constant", function()
		local entries = { { id = "a", weight = 90 }, { id = "b", weight = 10 } }
		local boosted = WeightedRandom.boost(entries, { b = 2 }, "a")
		expect(WeightedRandom.total(boosted)).toBeNear(100)
		local pct = WeightedRandom.toPercentages(boosted)
		expect(pct.b).toBeNear(20)
	end)
end)

describe("TableUtil", function()
	it("reconciles missing keys without clobbering", function()
		local data = { a = 1, nested = { x = 5 } }
		TableUtil.reconcile(data, { a = 0, b = 2, nested = { x = 0, y = 3 }, list = { 1, 2 } })
		expect(data.a).toBe(1)
		expect(data.b).toBe(2)
		expect(data.nested.x).toBe(5)
		expect(data.nested.y).toBe(3)
		expect(#data.list).toBe(2)
	end)
end)
