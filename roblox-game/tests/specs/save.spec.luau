-- Save format: defaults, round trips, corrupted saves, newer versions.

local SaveSchema = loader:require(Shared.Rules.SaveSchema)
local Data = loader:require(Shared.Data)

local ctx = { xpToNext = Data.xpToNext, cap = Data.progression.content_level_cap }

local function fresh(): any
	return SaveSchema.default(nil)
end

local function contains(list: { string }, fragment: string): boolean
	for _, item in list do
		if string.find(item, fragment, 1, true) then
			return true
		end
	end
	return false
end

describe("Save defaults", function()
	it("a new save is valid", function()
		local ok, problems = SaveSchema.validate(fresh(), ctx)
		expect(ok).toBe(true)
		expect(#problems).toBe(0)
	end)

	it("an empty profile is treated as a new player", function()
		local data, report = SaveSchema.load({}, ctx)
		expect(report.isNew).toBe(true)
		expect(data.level).toBe(1)
		local _, report2 = SaveSchema.load(nil, ctx)
		expect(report2.isNew).toBe(true)
	end)

	it("uses the starter appearance from customization defaults", function()
		local data = fresh()
		for _, option in Data.customization.options do
			if option.is_default and data.appearance[option.category] ~= nil then
				expect(data.appearance[option.category]).toBe(option.id)
			end
		end
	end)
end)

describe("Save round trip", function()
	it("a saved and reloaded profile is unchanged", function()
		local data = fresh()
		data.level = 12
		data.xp = 30
		data.total_xp = 5000
		data.rewards_granted_through = 12
		data.inventory.materials["mat_gloam_dust"] = 42
		table.insert(data.inventory.weapons, { uid = "w1", id = "wpn_hearthwick", tier = 2 })
		data.equipment.weapon_uid = "w1"
		data.settings["difficulty"] = "story"
		local loaded, report = SaveSchema.load(SaveSchema.snapshot(data), ctx)
		expect(#report.repaired).toBe(0)
		expect(#report.filled).toBe(0)
		expect(loaded).toEqual(data)
	end)

	it("a snapshot is independent of the live data", function()
		local data = fresh()
		local snap = SaveSchema.snapshot(data)
		data.inventory.materials["mat_gloam_dust"] = 5
		expect(snap.inventory.materials["mat_gloam_dust"]).toBe(nil)
	end)
end)

describe("Corrupted saves", function()
	it("repairs a bad field and keeps everything else", function()
		local data = fresh()
		data.level = 7
		data.xp = 3
		data.rewards_granted_through = 7
		data.inventory.materials["mat_gloam_dust"] = 9
		(data :: any).skill_points = "lots"
		local loaded, report = SaveSchema.load(data, ctx)
		expect(loaded.skill_points).toBe(0)
		expect(loaded.level).toBe(7)
		expect(loaded.inventory.materials["mat_gloam_dust"]).toBe(9)
		expect(contains(report.repaired, "skill_points")).toBe(true)
	end)

	it("drops only the broken items from a list, keeping rare items", function()
		local data = fresh()
		data.inventory.weapons = {
			{ uid = "good", id = "wpn_hearthwick", tier = 5 },
			{ uid = "bad", id = 12345, tier = 1 } :: any,
			{ uid = "good2", id = "wpn_hearthwick", tier = 9 }, -- tier out of range
		}
		local loaded, report = SaveSchema.load(data, ctx)
		expect(#loaded.inventory.weapons).toBe(1)
		expect(loaded.inventory.weapons[1].uid).toBe("good")
		expect(#report.repaired).toBe(2)
	end)

	it("records what it repaired in the quarantine list (capped)", function()
		local data = fresh() :: any
		for i = 1, 40 do
			data.inventory.materials["mat_x" .. i] = -1
		end
		local loaded = SaveSchema.load(data, ctx)
		expect(#loaded.quarantine).toBe(SaveSchema.MAX_QUARANTINE)
		expect(loaded.quarantine[1].reason).toBe("invalid entry")
	end)

	it("survives a save that is not even a table", function()
		local loaded, report = SaveSchema.load("garbage" :: any, ctx)
		expect(loaded.level).toBe(1)
		expect(contains(report.repaired, "(whole save)")).toBe(true)
	end)

	it("fixes impossible progress", function()
		local data = fresh()
		data.level = 3000
		data.xp = 5
		local loaded = SaveSchema.load(data, ctx)
		expect(loaded.level).toBe(ctx.cap)
		expect(loaded.xp).toBe(0)
	end)

	it("never lowers rewards_granted_through (no double rewards)", function()
		local data = fresh()
		data.level = 3
		data.rewards_granted_through = 20
		local loaded = SaveSchema.load(data, ctx)
		expect(loaded.rewards_granted_through).toBe(20)
	end)

	it("unequips a weapon that is not in the inventory", function()
		local data = fresh()
		data.equipment.weapon_uid = "ghost"
		local loaded = SaveSchema.load(data, ctx)
		expect(loaded.equipment.weapon_uid).toBe("")
	end)

	it("fills fields that are missing (e.g. added by an update)", function()
		local data = fresh() :: any
		data.boss_failures = nil
		data.flags = nil
		local loaded, report = SaveSchema.load(data, ctx)
		expect(loaded.flags.starter_kit_given).toBe(false)
		expect(contains(report.filled, "flags")).toBe(true)
		expect(#report.repaired).toBe(0)
	end)

	it("validation catches broken live data before it can be saved", function()
		local data = fresh() :: any
		data.inventory.materials["mat_gloam_dust"] = 0 / 0
		local ok, problems = SaveSchema.validate(data, ctx)
		expect(ok).toBe(false)
		expect(contains(problems, "inventory.materials")).toBe(true)
		local ok2 = SaveSchema.validate({ level = 5 }, ctx)
		expect(ok2).toBe(false)
	end)
end)

describe("Save versions", function()
	it("refuses a save from a newer game version instead of downgrading it", function()
		local data = fresh() :: any
		data.schema_version = SaveSchema.VERSION + 1
		local loaded, report = SaveSchema.load(data, ctx)
		expect(loaded).toBe(nil)
		expect(report.refused).toBe("newer_version")
	end)

	it("treats a save with no version as version 1", function()
		local data = fresh() :: any
		data.schema_version = nil
		local loaded = SaveSchema.load(data, ctx)
		expect(loaded.schema_version).toBe(SaveSchema.VERSION)
	end)
end)
