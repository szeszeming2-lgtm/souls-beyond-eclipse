--!strict
-- Phase 0 smoke test. NOT gameplay code.
-- It only proves that the generated GameData modules load inside Roblox.
-- Phase 1 replaces this with the real server bootstrap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameData")) :: any

local xpTable = GameData.Progression.XpTable
local weapon = GameData.Items.Weapons.entries[1]

assert(#xpTable.xp_to_next == xpTable.level_cap - 1, "XP table length does not match the level cap")
assert(table.isfrozen(weapon), "GameData tables should be frozen (read-only)")
assert(#weapon.upgrade_tiers == 5, "weapons must have 5 upgrade tiers")

print(
	string.format(
		"[SBE] Phase 0 smoke test PASSED on the server: %d weapon(s), %d enemies, %d regions, %d abilities, level cap %d.",
		#GameData.Items.Weapons.entries,
		#GameData.Enemies.entries,
		#GameData.Regions.entries,
		#GameData.Abilities.entries,
		xpTable.level_cap
	)
)
