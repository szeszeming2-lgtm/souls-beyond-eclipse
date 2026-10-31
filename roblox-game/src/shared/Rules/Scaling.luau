--!strict
-- Level scaling formulas shared by every system. Pure: no Roblox APIs.
-- Players and enemies grow at the same rate, so same-level fights feel the same at any level.

local Scaling = {}

-- 1 at level 1, growing in a straight line.
function Scaling.rewardScale(level: number, growthPerLevel: number): number
	return 1 + (level - 1) * growthPerLevel
end

function Scaling.statAt(base: number, level: number, growthPerLevel: number): number
	return base * Scaling.rewardScale(level, growthPerLevel)
end

-- Round half up: the same rule as the Python tools, so every engine gets identical numbers.
function Scaling.round(value: number): number
	return math.floor(value + 0.5)
end

-- Data stores rewards as level-1 amounts; this scales one to the content's level.
function Scaling.scaledReward(baseAmount: number, level: number, growthPerLevel: number): number
	return Scaling.round(baseAmount * Scaling.rewardScale(level, growthPerLevel))
end

-- Soft level-sync: in an area below you, your stats act as if you were at the area's top level
-- plus a margin. Returns the level to use for stats.
function Scaling.syncedLevel(playerLevel: number, areaMaxLevel: number, marginLevels: number): number
	return math.min(playerLevel, areaMaxLevel + marginLevels)
end

return Scaling
