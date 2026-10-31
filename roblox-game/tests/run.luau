--!strict
-- Runs every tests/specs/*.spec.luau with Lune. From the repo root:
--     lune run roblox-game/tests/run.luau

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Loader = require("./Loader")
local TestKit = require("./TestKit")

local ROOT = "roblox-game"
local SPECS = ROOT .. "/tests/specs"

local loader = Loader.new(ROOT .. "/src")

local files = {}
for _, name in fs.readDir(SPECS) do
	if string.match(name, "%.spec%.luau$") then
		table.insert(files, name)
	end
end
table.sort(files)

for _, name in files do
	local path = SPECS .. "/" .. name
	local chunk = luau.load(fs.readFile(path), {
		debugName = path,
		environment = {
			describe = TestKit.describe,
			it = TestKit.it,
			expect = TestKit.expect,
			loader = loader,
			-- Same shape as ReplicatedStorage.Shared in the game.
			Shared = loader:instance("shared"),
			lune = { fs = fs, serde = serde },
		},
	})
	local ok, err = pcall(chunk)
	if not ok then
		print(`ERROR loading {name}: {err}`)
		process.exit(1)
	end
end

local passed, failures = TestKit.results()
for _, failure in failures do
	print("FAIL  " .. failure)
end
print(`{passed} passed, {#failures} failed ({#files} spec files)`)
process.exit(if #failures > 0 then 1 else 0)
