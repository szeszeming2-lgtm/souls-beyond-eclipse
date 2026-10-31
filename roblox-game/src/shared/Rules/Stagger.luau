--!strict
-- Poise, stagger and crowd-control limits. Pure: no Roblox APIs. Times are seconds.
--
-- Anti-frustration rules built in here:
--   * After a stagger the target cannot be staggered again for stagger_immunity_s.
--   * Repeated hard crowd control in a short window lasts less each time, then the target is
--     briefly immune. No single effect lasts longer than max_hard_cc_s.

local Stagger = {}

export type PoiseRules = { stagger_s: number, stagger_immunity_s: number, poise_regen_delay_s: number }
export type PoiseState = { current: number, max: number, lastHitAt: number, immuneUntil: number }

function Stagger.newPoise(maxPoise: number): PoiseState
	return { current = maxPoise, max = maxPoise, lastHitAt = -math.huge, immuneUntil = -math.huge }
end

-- Applies poise damage. Returns true if this hit staggers the target.
function Stagger.hit(state: PoiseState, poiseDamage: number, now: number, rules: PoiseRules): boolean
	if state.max <= 0 then
		return false
	end
	if now - state.lastHitAt >= rules.poise_regen_delay_s then
		state.current = state.max
	end
	state.lastHitAt = now
	if now < state.immuneUntil then
		return false
	end
	state.current -= math.max(0, poiseDamage)
	if state.current <= 0 then
		state.current = state.max
		state.immuneUntil = now + rules.stagger_s + rules.stagger_immunity_s
		return true
	end
	return false
end

-- Forces a stagger (a parry or guard break), still respecting immunity. Returns true if applied.
function Stagger.force(state: PoiseState, now: number, durationS: number, rules: PoiseRules): boolean
	if now < state.immuneUntil then
		return false
	end
	state.current = state.max
	state.lastHitAt = now
	state.immuneUntil = now + durationS + rules.stagger_immunity_s
	return true
end

export type CcRules = {
	max_hard_cc_s: number,
	diminishing_window_s: number,
	diminishing_multipliers: { number },
	immunity_s: number,
}
export type CcState = { count: number, windowStart: number, immuneUntil: number }

function Stagger.newCc(): CcState
	return { count = 0, windowStart = -math.huge, immuneUntil = -math.huge }
end

-- How long a hard crowd-control effect actually lasts (0 = resisted).
function Stagger.ccDuration(state: CcState, baseDuration: number, now: number, rules: CcRules): number
	if now < state.immuneUntil then
		return 0
	end
	if now - state.windowStart > rules.diminishing_window_s then
		state.count = 0
		state.windowStart = now
	end
	state.count += 1
	local multiplier = rules.diminishing_multipliers[state.count]
	if multiplier == nil then
		state.immuneUntil = now + rules.immunity_s
		state.count = 0
		return 0
	end
	local duration = math.min(baseDuration * multiplier, rules.max_hard_cc_s)
	if state.count >= #rules.diminishing_multipliers then
		state.immuneUntil = now + duration + rules.immunity_s
		state.count = 0
	end
	return duration
end

return Stagger
