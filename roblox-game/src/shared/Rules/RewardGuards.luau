--!strict
-- Fair-reward guards. Pure: the caller passes the time.
--   * Anti-grind: killing the same enemy type over and over slowly gives less XP (normal varied
--     play never notices it).
--   * XP rate alarm: XP per minute far above what any real play can earn is clamped and logged.
--     It never bans or wipes anyone.

local RewardGuards = {}

export type GrindRules =
	{ window_s: number, full_reward_kills: number, decay_per_kill: number, floor_multiplier: number }
export type GrindState = { [string]: { number } } -- enemyId -> kill times

function RewardGuards.newGrind(): GrindState
	return {}
end

-- Records a kill and returns the XP multiplier for it.
function RewardGuards.grindMultiplier(state: GrindState, enemyId: string, now: number, rules: GrindRules): number
	local kills: { number } = state[enemyId] or {}
	local kept: { number } = {}
	for _, t in kills do
		if now - t < rules.window_s then
			table.insert(kept, t)
		end
	end
	local extra = #kept - rules.full_reward_kills + 1
	table.insert(kept, now)
	state[enemyId] = kept
	if extra <= 0 then
		return 1
	end
	return math.max(rules.floor_multiplier, rules.decay_per_kill ^ extra)
end

export type RateState = { windowStart: number, amount: number }

function RewardGuards.newRate(): RateState
	return { windowStart = -math.huge, amount = 0 }
end

-- Returns (amountAllowed, alarmed). Window is 60 seconds.
function RewardGuards.clampXp(
	state: RateState,
	amount: number,
	now: number,
	expectedPerMinute: number,
	alarmFactor: number
): (number, boolean)
	if now - state.windowStart >= 60 then
		state.windowStart = now
		state.amount = 0
	end
	local limit = expectedPerMinute * alarmFactor
	local room = math.max(0, limit - state.amount)
	local allowed = math.min(amount, room)
	state.amount += allowed
	return allowed, allowed < amount
end

return RewardGuards
