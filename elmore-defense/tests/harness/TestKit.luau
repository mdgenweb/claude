--[[
	TestKit: tiny describe/it/expect runner for the bundled spec files.
]]

local passed, failed = 0, 0
local failures = {}
local currentSuite = ""

function describe(name, fn)
	local previous = currentSuite
	currentSuite = if previous == "" then name else previous .. " > " .. name
	fn()
	currentSuite = previous
end

function it(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		table.insert(failures, string.format("FAIL %s > %s\n    %s", currentSuite, name, tostring(err)))
	end
end

local function fmt(value)
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

function expect(actual)
	local api = {}
	function api.toBe(expected)
		if actual ~= expected then
			error(string.format("expected %s to be %s", fmt(actual), fmt(expected)), 2)
		end
	end
	function api.toBeNear(expected, tolerance)
		tolerance = tolerance or 1e-6
		if type(actual) ~= "number" or math.abs(actual - expected) > tolerance then
			error(string.format("expected %s to be within %s of %s", fmt(actual), fmt(tolerance), fmt(expected)), 2)
		end
	end
	function api.toBeTruthy()
		if not actual then
			error(string.format("expected %s to be truthy", fmt(actual)), 2)
		end
	end
	function api.toBeFalsy()
		if actual then
			error(string.format("expected %s to be falsy", fmt(actual)), 2)
		end
	end
	function api.toBeGreaterThan(expected)
		if not (actual > expected) then
			error(string.format("expected %s > %s", fmt(actual), fmt(expected)), 2)
		end
	end
	function api.toBeAtMost(expected)
		if not (actual <= expected) then
			error(string.format("expected %s <= %s", fmt(actual), fmt(expected)), 2)
		end
	end
	function api.toBeAtLeast(expected)
		if not (actual >= expected) then
			error(string.format("expected %s >= %s", fmt(actual), fmt(expected)), 2)
		end
	end
	return api
end

function __runSpec(name, fn)
	currentSuite = name
	local ok, err = pcall(fn, __sharedRoot(), __shimRequire)
	if not ok then
		failed += 1
		table.insert(failures, string.format("ERROR loading %s\n    %s", name, tostring(err)))
	end
	currentSuite = ""
end

function __finish()
	for _, line in failures do
		print(line)
	end
	print(string.format("\n%d passed, %d failed", passed, failed))
	if failed > 0 then
		error("test failures", 0)
	end
end
