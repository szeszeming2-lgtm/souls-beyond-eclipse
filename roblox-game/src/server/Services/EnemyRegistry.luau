--!strict
-- The list of living enemies. CombatService finds targets here and hits them through the
-- functions each enemy carries, so it never needs to require EnemyService (no require loops).

local DataTypes =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Rules"):WaitForChild("DataTypes"))

export type Hit = {
	amount: number,
	poiseDamage: number,
	knockback: number,
	direction: Vector3,
	attacker: Player?,
	isCrit: boolean,
	statusEffects: { DataTypes.StatusApplication }?,
	sourceAttack: number, -- attacker's attack stat, for damage-over-time ticks
}

export type Enemy = {
	def: DataTypes.Enemy,
	model: Model,
	root: BasePart,
	level: number,
	maxHp: number,
	hp: number,
	defense: number,
	radius: number,
	alive: boolean,
	isBoss: boolean,
	takeHit: (hit: Hit) -> boolean,
	stagger: (seconds: number) -> boolean,
}

local EnemyRegistry = {}

local live: { [Enemy]: boolean } = {}

function EnemyRegistry.add(enemy: Enemy)
	live[enemy] = true
end

function EnemyRegistry.remove(enemy: Enemy)
	live[enemy] = nil
end

-- Living enemies whose centre is within `radius` (plus their own size) of `position`.
function EnemyRegistry.near(position: Vector3, radius: number): { Enemy }
	local out = {}
	for enemy in live do
		if enemy.alive and (enemy.root.Position - position).Magnitude <= radius + enemy.radius then
			table.insert(out, enemy)
		end
	end
	return out
end

function EnemyRegistry.all(): { Enemy }
	local out = {}
	for enemy in live do
		table.insert(out, enemy)
	end
	return out
end

return EnemyRegistry
