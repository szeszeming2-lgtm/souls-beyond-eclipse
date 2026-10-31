-- Inventory and equip rules.

local Inventory = loader:require(Shared.Rules.Inventory)
local EquipRules = loader:require(Shared.Rules.EquipRules)
local Data = loader:require(Shared.Data)

describe("Inventory", function()
	it("stacks materials up to their max", function()
		local inv = Inventory.new()
		local added, overflow = Inventory.addMaterial(inv, "mat_warden_steel", 150, 99)
		expect(added).toBe(99)
		expect(overflow).toBe(51)
		expect(Inventory.count(inv, "mat_warden_steel")).toBe(99)
	end)

	it("ignores zero or negative amounts", function()
		local inv = Inventory.new()
		expect(Inventory.addMaterial(inv, "mat_gloam_dust", -5, 999)).toBe(0)
		expect(Inventory.removeMaterial(inv, "mat_gloam_dust", -5)).toBe(false)
	end)

	it("removes exactly, or not at all", function()
		local inv = Inventory.new()
		Inventory.addMaterial(inv, "mat_gloam_dust", 10, 999)
		expect(Inventory.removeMaterial(inv, "mat_gloam_dust", 11)).toBe(false)
		expect(Inventory.count(inv, "mat_gloam_dust")).toBe(10)
		expect(Inventory.removeMaterial(inv, "mat_gloam_dust", 10)).toBe(true)
		expect(inv.materials["mat_gloam_dust"]).toBe(nil)
	end)

	it("spends a whole upgrade cost atomically", function()
		local inv = Inventory.new()
		Inventory.addMaterial(inv, "mat_gloam_dust", 10, 999)
		Inventory.addMaterial(inv, "mat_wick_thread", 1, 999)
		local tier2 = Data.weapons["wpn_hearthwick"].upgrade_tiers[2].materials
		expect(Inventory.spendMaterials(inv, tier2)).toBe(false)
		expect(Inventory.count(inv, "mat_gloam_dust")).toBe(10)
		Inventory.addMaterial(inv, "mat_wick_thread", 1, 999)
		expect(Inventory.spendMaterials(inv, tier2)).toBe(true)
		expect(Inventory.count(inv, "mat_gloam_dust")).toBe(0)
	end)

	it("needs a unique id for every weapon copy", function()
		local inv = Inventory.new()
		expect(Inventory.addWeapon(inv, "a", "wpn_hearthwick")).toBe(true)
		local ok, reason = Inventory.addWeapon(inv, "a", "wpn_hearthwick")
		expect(ok).toBe(false)
		expect(reason).toBe("duplicate_uid")
		expect(Inventory.addWeapon(inv, "", "wpn_hearthwick")).toBe(false)
		expect(Inventory.findWeapon(inv, "a").tier).toBe(0)
	end)
end)

describe("Equip rules", function()
	local hearthwick = Data.weapons["wpn_hearthwick"]
	local classes = Data.archetypes["arc_lanternblade"].weapon_classes
	local owned = { uid = "u1", id = "wpn_hearthwick", tier = 0 }

	it("allows an owned weapon the style can use", function()
		expect(EquipRules.canEquipWeapon({
			level = 1,
			weapon = owned,
			weaponDef = hearthwick,
			archetypeWeaponClasses = classes,
		})).toBe(true)
	end)

	it("refuses a weapon you do not own", function()
		local ok, reason = EquipRules.canEquipWeapon({
			level = 1,
			weapon = nil,
			weaponDef = hearthwick,
			archetypeWeaponClasses = classes,
		})
		expect(ok).toBe(false)
		expect(reason).toBe("not_owned")
	end)

	it("refuses an unknown weapon id", function()
		local _, reason =
			EquipRules.canEquipWeapon({ level = 1, weapon = owned, weaponDef = nil, archetypeWeaponClasses = classes })
		expect(reason).toBe("unknown_weapon")
	end)

	it("refuses if the level is too low", function()
		local _, reason = EquipRules.canEquipWeapon({
			level = 4,
			weapon = owned,
			weaponDef = { level_req = 5, weapon_class = "katana" },
			archetypeWeaponClasses = classes,
		})
		expect(reason).toBe("level_too_low")
	end)

	it("refuses a weapon class the style cannot use", function()
		local _, reason = EquipRules.canEquipWeapon({
			level = 50,
			weapon = owned,
			weaponDef = { level_req = 1, weapon_class = "bow" },
			archetypeWeaponClasses = classes,
		})
		expect(reason).toBe("wrong_weapon_class")
	end)
end)
