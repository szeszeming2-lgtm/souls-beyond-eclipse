--!strict
-- XP, levels, level-up rewards and milestones. Pure: no Roblox APIs.
--
-- Level-up rewards are tracked with one number, rewards_granted_through: the highest level whose
-- rewards were already given. A level's rewards can therefore only ever be granted once, even if
-- the same XP event were processed twice or a save were reloaded.

local DataTypes = require(script.Parent.DataTypes)

local Progression = {}

export type Progress = { level: number, xp: number, total_xp: number }

export type AddResult = {
	progress: Progress,
	levelsGained: number,
	added: number,
	atCap: boolean,
}

local function isUsableNumber(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

-- The highest level reachable: the build's cap, but never more than the XP table supports.
function Progression.effectiveCap(contentCap: number, xpToNext: { number }): number
	return math.min(contentCap, #xpToNext + 1)
end

-- XP still needed for the next level, or nil at the cap.
function Progression.xpToNext(level: number, xpToNext: { number }, cap: number): number?
	if level >= cap then
		return nil
	end
	return xpToNext[level]
end

-- Adds XP and levels up as many times as needed. Never passes the cap; XP beyond it is dropped.
-- Negative, NaN and infinite amounts add nothing.
function Progression.addXp(progress: Progress, amount: number, xpToNext: { number }, cap: number): AddResult
	local level, xp, total = progress.level, progress.xp, progress.total_xp
	local startLevel = level
	if not isUsableNumber(amount) or amount <= 0 or level >= cap then
		return {
			progress = { level = level, xp = if level >= cap then 0 else xp, total_xp = total },
			levelsGained = 0,
			added = 0,
			atCap = level >= cap,
		}
	end
	local remaining = math.floor(amount)
	local added = 0
	while remaining > 0 and level < cap do
		local need = xpToNext[level] - xp
		if remaining >= need then
			remaining -= need
			added += need
			level += 1
			xp = 0
		else
			xp += remaining
			added += remaining
			remaining = 0
		end
	end
	return {
		progress = { level = level, xp = if level >= cap then 0 else xp, total_xp = total + added },
		levelsGained = level - startLevel,
		added = added,
		atCap = level >= cap,
	}
end

-- Levels whose rewards are still owed: grantedThrough + 1 .. level.
function Progression.pendingRewardLevels(grantedThrough: number, level: number): { number }
	local out = {}
	for l = grantedThrough + 1, level do
		table.insert(out, l)
	end
	return out
end

-- Skill points earned on reaching `level`.
function Progression.skillPointsAt(level: number, schedule: { { from: number, to: number, every: number } }): number
	for _, range in schedule do
		if level >= range.from and level <= range.to then
			return if (level - range.from) % range.every == 0 then 1 else 0
		end
	end
	return 0
end

-- The milestone reward for reaching `level`, if any, and whether it is a major one.
function Progression.milestoneAt(
	level: number,
	milestones: {
		interval: number,
		standard_reward: DataTypes.Reward,
		major: { { level: number, name: string, reward: DataTypes.Reward } },
	}
): (DataTypes.Reward?, string?)
	if level % milestones.interval ~= 0 then
		return nil, nil
	end
	for _, major in milestones.major do
		if major.level == level then
			return major.reward, major.name
		end
	end
	return milestones.standard_reward, nil
end

-- Repairs impossible progress values from a save (for example xp larger than the level needs).
function Progression.sanitize(progress: Progress, xpToNext: { number }, cap: number): Progress
	local level = math.clamp(math.floor(progress.level), 1, cap)
	local xp = math.max(0, math.floor(progress.xp))
	if level >= cap then
		xp = 0
	elseif xp >= xpToNext[level] then
		xp = xpToNext[level] - 1
	end
	local total = math.max(0, math.floor(progress.total_xp))
	return { level = level, xp = xp, total_xp = total }
end

return Progression
