--!strict
-- Damage formula. Pure: no Roblox APIs, no randomness inside (pass the crit result in).
--
-- damage = attack x power x weaponFactor x mitigation x levelGap x difficulty x resistance
--          x (1 - guardReduction) x crit x bonus, rounded half up, never below min_damage
-- mitigation = 1 - defense / (defense + defense_constant x rewardScale(attackerLevel))

local Scaling = require(script.Parent.Scaling)

local DamageMath = {}

export type DamageRules = {
	defense_constant: number,
	level_gap_per_level: number,
	level_gap_min: number,
	level_gap_max: number,
	crit_multiplier: number,
	min_damage: number,
}

export type DamageInput = {
	attack: number,
	power: number,
	defense: number,
	attackerLevel: number,
	targetLevel: number,
	growthPerLevel: number,
	weaponDamage: number?, -- weapon power, 100 = baseline; nil for enemies
	weaponBonusPct: number?, -- upgrade tier bonus
	difficultyMult: number?, -- enemy damage multiplier when an enemy hits a player
	resistance: number?, -- target's multiplier for this damage type
	guardReduction: number?, -- 0..1 when guarding
	isCrit: boolean?,
	bonusMult: number?, -- buffs, e.g. 1.1 for +10% attack
}

function DamageMath.mitigation(defense: number, attackerLevel: number, rules: DamageRules, growth: number): number
	if defense <= 0 then
		return 1
	end
	local constant = rules.defense_constant * Scaling.rewardScale(attackerLevel, growth)
	return 1 - defense / (defense + constant)
end

function DamageMath.levelGap(attackerLevel: number, targetLevel: number, rules: DamageRules): number
	local gap = 1 + (attackerLevel - targetLevel) * rules.level_gap_per_level
	return math.clamp(gap, rules.level_gap_min, rules.level_gap_max)
end

function DamageMath.compute(input: DamageInput, rules: DamageRules): number
	local weaponFactor = (input.weaponDamage or 100) / 100 * (1 + (input.weaponBonusPct or 0) / 100)
	local raw = input.attack
		* input.power
		* weaponFactor
		* DamageMath.mitigation(input.defense, input.attackerLevel, rules, input.growthPerLevel)
		* DamageMath.levelGap(input.attackerLevel, input.targetLevel, rules)
		* (input.difficultyMult or 1)
		* (input.resistance or 1)
		* (1 - math.clamp(input.guardReduction or 0, 0, 1))
		* (if input.isCrit then rules.crit_multiplier else 1)
		* (input.bonusMult or 1)
	if raw ~= raw then
		return rules.min_damage
	end
	return math.max(rules.min_damage, Scaling.round(raw))
end

-- Decide a crit from a random number in [0, 1). The caller supplies the random number.
function DamageMath.isCrit(chance: number, roll: number): boolean
	return roll < chance
end

-- Sum of add_percent modifiers for one stat, as a multiplier (e.g. two +10% -> 1.2).
function DamageMath.percentMultiplier(
	modifiers: { { stat: string, mode: string, value: number } },
	stat: string
): number
	local total = 0
	for _, modifier in modifiers do
		if modifier.stat == stat and modifier.mode == "add_percent" then
			total += modifier.value
		end
	end
	return math.max(0, 1 + total / 100)
end

return DamageMath
