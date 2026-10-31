-- Damage math, plus a balance check using the real Phase 1 data.

local DamageMath = loader:require(Shared.Rules.DamageMath)
local Scaling = loader:require(Shared.Rules.Scaling)
local Data = loader:require(Shared.Data)

local rules = Data.combat.damage
local growth = Data.progression.stat_scaling.growth_per_level

local function base(overrides: { [string]: any }?): any
	local input = {
		attack = 100,
		power = 1,
		defense = 0,
		attackerLevel = 1,
		targetLevel = 1,
		growthPerLevel = growth,
	}
	for k, v in overrides or {} do
		input[k] = v
	end
	return input
end

describe("DamageMath", function()
	it("with no defense, damage is attack x power", function()
		expect(DamageMath.compute(base(), rules)).toBe(100)
		expect(DamageMath.compute(base({ power = 2.5 }), rules)).toBe(250)
	end)

	it("defense reduces damage the same way at level 1 and level 2000", function()
		local d1 = DamageMath.mitigation(25, 1, rules, growth)
		local def2000 = Scaling.statAt(25, 2000, growth)
		local d2000 = DamageMath.mitigation(def2000, 2000, rules, growth)
		expect(d1).toBeNear(d2000, 1e-9)
		expect(d1).toBeNear(0.8, 1e-9)
	end)

	it("weapon power and upgrade bonus multiply in", function()
		expect(DamageMath.compute(base({ weaponDamage = 150 }), rules)).toBe(150)
		expect(DamageMath.compute(base({ weaponDamage = 100, weaponBonusPct = 52 }), rules)).toBe(152)
	end)

	it("level gap is capped both ways", function()
		expect(DamageMath.levelGap(1, 1, rules)).toBe(1)
		expect(DamageMath.levelGap(10, 1, rules)).toBeNear(1.18)
		expect(DamageMath.levelGap(500, 1, rules)).toBe(rules.level_gap_max)
		expect(DamageMath.levelGap(1, 500, rules)).toBe(rules.level_gap_min)
	end)

	it("guard, difficulty, resistance and crits apply", function()
		expect(DamageMath.compute(base({ guardReduction = 0.75 }), rules)).toBe(25)
		expect(DamageMath.compute(base({ difficultyMult = 0.5 }), rules)).toBe(50)
		expect(DamageMath.compute(base({ resistance = 1.25 }), rules)).toBe(125)
		expect(DamageMath.compute(base({ isCrit = true }), rules)).toBe(150)
	end)

	it("never goes below min damage, even for bad input", function()
		expect(DamageMath.compute(base({ attack = 0 }), rules)).toBe(rules.min_damage)
		expect(DamageMath.compute(base({ guardReduction = 5 }), rules)).toBe(rules.min_damage)
		expect(DamageMath.compute(base({ attack = 0 / 0 }), rules)).toBe(rules.min_damage)
	end)

	it("crit decision uses the supplied roll", function()
		expect(DamageMath.isCrit(0.05, 0.01)).toBe(true)
		expect(DamageMath.isCrit(0.05, 0.5)).toBe(false)
	end)

	it("adds percent modifiers", function()
		expect(DamageMath.percentMultiplier({
			{ stat = "attack", mode = "add_percent", value = 10 },
			{ stat = "attack", mode = "add_percent", value = 20 },
		}, "attack")).toBeNear(1.3)
		expect(
			DamageMath.percentMultiplier(
				{ { stat = "damage_taken", mode = "add_percent", value = -20 } },
				"damage_taken"
			)
		).toBeNear(0.8)
	end)
end)

describe("Phase 1 balance (real data)", function()
	local stats = Data.progression.stat_scaling
	local gloamling = Data.enemies["enm_gloamling"]
	local chain = Data.movesets["mvs_lanternblade_katana"].light_chain

	local function lightChainDamage(level: number): number
		local total = 0
		for _, step in chain do
			total += DamageMath.compute({
				attack = Scaling.statAt(stats.player_base.attack, level, growth),
				power = step.power,
				defense = Scaling.statAt(stats.enemy_base.defense, level, growth) * gloamling.stats.defense_mult,
				attackerLevel = level,
				targetLevel = level,
				growthPerLevel = growth,
				weaponDamage = 100,
			}, rules)
		end
		return total
	end

	it("a same-level Gloamling falls to one or two full light chains", function()
		for _, level in { 1, 25, 50 } do
			local hp = Scaling.statAt(stats.enemy_base.max_hp, level, growth) * gloamling.stats.hp_mult
			local chains = hp / lightChainDamage(level)
			expect(chains).toBeGreaterThan(0.8)
			expect(chains).toBeLessThan(2.5)
		end
	end)

	it("a Gloamling swipe takes well under a tenth of a same-level player's health", function()
		local swipe = gloamling.attacks[1]
		local dmg = DamageMath.compute({
			attack = Scaling.statAt(stats.enemy_base.attack, 1, growth) * gloamling.stats.attack_mult,
			power = swipe.power,
			defense = stats.player_base.defense,
			attackerLevel = 1,
			targetLevel = 1,
			growthPerLevel = growth,
			difficultyMult = 1,
		}, rules)
		expect(dmg / stats.player_base.max_hp).toBeLessThan(0.1)
	end)
end)
