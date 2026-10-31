--!strict
-- Boss phase logic. Pure. Phases are listed from full HP down; phase i begins when HP falls to
-- phases[i].starts_at_hp (a fraction of max HP).

local DataTypes = require(script.Parent.DataTypes)

local BossPhases = {}

type Phase = DataTypes.BossPhase

-- The phase index for an HP fraction (0..1).
function BossPhases.indexFor(phases: { Phase }, hpFraction: number): number
	local index = 1
	for i, phase in phases do
		if hpFraction <= phase.starts_at_hp then
			index = i
		end
	end
	return index
end

-- Checkpoint: if everyone falls, the boss restarts at the start of the furthest phase reached,
-- not at full HP (when checkpoint_each_phase is on).
function BossPhases.resetHp(
	phases: { Phase },
	furthestPhase: number,
	maxHp: number,
	checkpointEachPhase: boolean
): number
	if not checkpointEachPhase then
		return maxHp
	end
	local phase = phases[math.clamp(furthestPhase, 1, #phases)]
	return math.max(1, math.floor(maxHp * phase.starts_at_hp))
end

-- Which assist offers a player has earned after `failures` defeats.
function BossPhases.assistOffers(
	failures: number,
	thresholds: { tip: number, suggested_level: number, support_buff: number }
): { string }
	local offers = {}
	if failures >= thresholds.tip then
		table.insert(offers, "tip")
	end
	if failures >= thresholds.suggested_level then
		table.insert(offers, "suggested_level")
	end
	if failures >= thresholds.support_buff then
		table.insert(offers, "support_buff")
	end
	return offers
end

return BossPhases
