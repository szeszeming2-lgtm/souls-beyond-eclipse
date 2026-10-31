--!strict
-- A tiny test framework for Lune: describe / it / expect.

local TestKit = {}

local passed = 0
local failures: { string } = {}
local suite = ""

local function show(value: any): string
	if type(value) == "string" then
		return string.format("%q", value)
	elseif type(value) == "table" then
		local parts = {}
		for k, v in value do
			table.insert(parts, tostring(k) .. "=" .. show(v))
			if #parts > 8 then
				table.insert(parts, "...")
				break
			end
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(value)
end

local function deepEqual(a: any, b: any): boolean
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function fail(message: string)
	error(message, 3)
end

function TestKit.expect(actual: any)
	local m = {}
	function m.toBe(expected: any)
		if actual ~= expected then
			fail(`expected {show(expected)}, got {show(actual)}`)
		end
	end
	function m.toEqual(expected: any)
		if not deepEqual(actual, expected) then
			fail(`expected {show(expected)}, got {show(actual)}`)
		end
	end
	function m.toBeNear(expected: number, epsilon: number?)
		if math.abs(actual - expected) > (epsilon or 1e-6) then
			fail(`expected about {expected}, got {actual}`)
		end
	end
	function m.toBeTruthy()
		if not actual then
			fail(`expected a truthy value, got {show(actual)}`)
		end
	end
	function m.toBeFalsy()
		if actual then
			fail(`expected a falsy value, got {show(actual)}`)
		end
	end
	function m.toBeAtLeast(n: number)
		if not (actual >= n) then
			fail(`expected at least {n}, got {show(actual)}`)
		end
	end
	function m.toBeAtMost(n: number)
		if not (actual <= n) then
			fail(`expected at most {n}, got {show(actual)}`)
		end
	end
	function m.toBeGreaterThan(n: number)
		if not (actual > n) then
			fail(`expected more than {n}, got {show(actual)}`)
		end
	end
	function m.toBeLessThan(n: number)
		if not (actual < n) then
			fail(`expected less than {n}, got {show(actual)}`)
		end
	end
	function m.toContain(item: any)
		if type(actual) == "string" then
			if not string.find(actual, item, 1, true) then
				fail(`expected {show(actual)} to contain {show(item)}`)
			end
			return
		end
		for _, v in actual do
			if deepEqual(v, item) then
				return
			end
		end
		fail(`expected {show(actual)} to contain {show(item)}`)
	end
	function m.toThrow(fragment: string?)
		local ok, err = pcall(actual)
		if ok then
			fail("expected an error, but none was raised")
		elseif fragment and not string.find(tostring(err), fragment, 1, true) then
			fail(`expected an error containing {show(fragment)}, got {show(tostring(err))}`)
		end
	end
	return m
end

function TestKit.describe(name: string, body: () -> ())
	local previous = suite
	suite = if previous == "" then name else previous .. " > " .. name
	body()
	suite = previous
end

function TestKit.it(name: string, body: () -> ())
	local ok, err = pcall(body)
	if ok then
		passed += 1
	else
		table.insert(failures, `{suite} > {name}\n      {err}`)
	end
end

function TestKit.results(): (number, { string })
	return passed, failures
end

return TestKit
