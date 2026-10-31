-- XP, level cap, rewards granted once, skill points, milestones.

local Progression = loader:require(Shared.Rules.Progression)
local Data = loader:require(Shared.Data)

local XP = Data.xpToNext
local CAP3000 = Progression.effectiveCap(3000, XP)

local function start(): any
	return { level = 1, xp = 0, total_xp = 0 }
end

describe("Progression", function()
	it("levels up exactly at the table's XP", function()
		local r = Progression.addXp(start(), XP[1] - 1, XP, 50)
		expect(r.progress.level).toBe(1)
		r = Progression.addXp(r.progress, 1, XP, 50)
		expect(r.progress.level).toBe(2)
		expect(r.progress.xp).toBe(0)
		expect(r.levelsGained).toBe(1)
	end)

	it("can gain several levels from one big reward", function()
		local r = Progression.addXp(start(), XP[1] + XP[2] + XP[3] + 7, XP, 50)
		expect(r.progress.level).toBe(4)
		expect(r.progress.xp).toBe(7)
		expect(r.levelsGained).toBe(3)
	end)

	it("never passes the build cap (50 in Phase 1)", function()
		expect(Data.progression.content_level_cap).toBe(50)
		local r = Progression.addXp(start(), 10 ^ 12, XP, Data.progression.content_level_cap)
		expect(r.progress.level).toBe(50)
		expect(r.progress.xp).toBe(0)
		expect(r.atCap).toBe(true)
		local again = Progression.addXp(r.progress, 5000, XP, 50)
		expect(again.progress.level).toBe(50)
		expect(again.added).toBe(0)
	end)

	it("can never exceed level 3000, however much XP arrives", function()
		expect(CAP3000).toBe(3000)
		local r = Progression.addXp(start(), 2 ^ 52, XP, CAP3000)
		expect(r.progress.level).toBe(3000)
		expect(Progression.xpToNext(3000, XP, CAP3000)).toBe(nil)
		expect(Progression.effectiveCap(5000, XP)).toBe(3000)
	end)

	it("ignores negative, NaN and infinite XP", function()
		for _, bad in { -100, 0 / 0, math.huge, -math.huge, 0 } do
			local r = Progression.addXp(start(), bad, XP, 50)
			expect(r.progress.level).toBe(1)
			expect(r.progress.xp).toBe(0)
			expect(r.added).toBe(0)
		end
	end)

	it("counts total XP", function()
		local r = Progression.addXp(start(), 1000, XP, 50)
		expect(r.progress.total_xp).toBe(1000)
	end)
end)

describe("Level-up rewards are granted only once", function()
	it("lists only levels not yet rewarded", function()
		expect(Progression.pendingRewardLevels(1, 4)).toEqual({ 2, 3, 4 })
		expect(Progression.pendingRewardLevels(4, 4)).toEqual({})
		expect(Progression.pendingRewardLevels(4, 3)).toEqual({})
	end)

	it("processing the same level-up twice grants nothing the second time", function()
		local grantedThrough = 1
		local granted = 0
		local function onLevel(level: number)
			for _ in Progression.pendingRewardLevels(grantedThrough, level) do
				granted += 1
			end
			grantedThrough = math.max(grantedThrough, level)
		end
		onLevel(5)
		onLevel(5)
		onLevel(3)
		expect(granted).toBe(4)
	end)
end)

describe("Skill points and milestones", function()
	local schedule = Data.progression.skill_points.schedule

	it("gives one point per level up to 100, then one every 10 levels", function()
		expect(Progression.skillPointsAt(1, schedule)).toBe(0)
		expect(Progression.skillPointsAt(2, schedule)).toBe(1)
		expect(Progression.skillPointsAt(100, schedule)).toBe(1)
		expect(Progression.skillPointsAt(101, schedule)).toBe(1)
		expect(Progression.skillPointsAt(105, schedule)).toBe(0)
		expect(Progression.skillPointsAt(111, schedule)).toBe(1)
	end)

	it("has a milestone every 50 levels and major ones at the brief's levels", function()
		local milestones = Data.progression.milestones
		expect(Progression.milestoneAt(49, milestones)).toBe(nil)
		local reward, major = Progression.milestoneAt(50, milestones)
		expect(reward ~= nil).toBe(true)
		expect(major).toBe(nil)
		for _, level in { 100, 500, 1000, 1500, 2000, 2500, 3000 } do
			local _, name = Progression.milestoneAt(level, milestones)
			expect(name ~= nil).toBe(true)
		end
	end)
end)

describe("Progress repair", function()
	it("fixes impossible saved values", function()
		local fixed = Progression.sanitize({ level = 9999, xp = 50, total_xp = -5 }, XP, 50)
		expect(fixed.level).toBe(50)
		expect(fixed.xp).toBe(0)
		expect(fixed.total_xp).toBe(0)
		local over = Progression.sanitize({ level = 3, xp = 10 ^ 9, total_xp = 10 }, XP, 50)
		expect(over.xp).toBe(XP[3] - 1)
	end)
end)
