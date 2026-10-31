--!strict
-- Enemy decisions, one tick at a time. Pure: the server passes in what the enemy can see and
-- gets back what to do. Keeping this pure makes enemy behaviour testable without Roblox.

local EnemyBrain = {}

export type AttackOption = { id: string, range: number, readyAt: number }

export type Input = {
	now: number,
	distanceToTarget: number?, -- nil = no target in sight
	distanceFromHome: number,
	leashRange: number,
	attacks: { AttackOption }, -- usable now (already filtered by boss phase)
	hasAttackToken: boolean, -- only a few enemies may attack one player at a time
	busy: boolean, -- winding up, attacking, recovering or staggered
}

export type Decision = { kind: "idle" | "chase" | "attack" | "wait" | "return", attackId: string? }

-- Picks the shortest-range ready attack that reaches the target, so close-up swipes are
-- preferred and long lunges are used from further away.
function EnemyBrain.pickAttack(attacks: { AttackOption }, distance: number, now: number): string?
	local best: AttackOption? = nil
	for _, option in attacks do
		if now >= option.readyAt and distance <= option.range then
			if best == nil or option.range < best.range then
				best = option
			end
		end
	end
	return if best then best.id else nil
end

function EnemyBrain.decide(input: Input): Decision
	if input.busy then
		return { kind = "wait" }
	end
	if input.distanceFromHome > input.leashRange then
		return { kind = "return" }
	end
	local distance = input.distanceToTarget
	if distance == nil then
		return if input.distanceFromHome > 4 then { kind = "return" } else { kind = "idle" }
	end
	local attackId = EnemyBrain.pickAttack(input.attacks, distance, input.now)
	if attackId then
		if input.hasAttackToken then
			return { kind = "attack", attackId = attackId }
		end
		return { kind = "wait" }
	end
	return { kind = "chase" }
end

return EnemyBrain
