--!strict
-- Types for the shared-data entries that game code reads. They mirror shared-data/schemas.
-- Only the fields game code uses are listed; the schemas are the full definition.

export type Timing = { windup_s: number, active_s: number, recovery_s: number }

export type Area = {
	shape: string, -- "single_target" | "circle" | "cone" | "line" | "box" | "ring"
	radius_studs: number?,
	angle_deg: number?,
	length_studs: number?,
	width_studs: number?,
}

export type StatusApplication = { status_id: string, chance: number, duration_s: number? }
export type StatModifier = { stat: string, mode: string, value: number }
export type MaterialCost = { material_id: string, qty: number }

export type AttackStep = {
	id: string,
	power: number,
	hit_count: number?,
	damage_type: string,
	timing: Timing,
	range_studs: number,
	arc_deg: number,
	knockback_studs: number,
	poise_damage: number,
	dodge_cancel_after_s: number,
}

export type Moveset = {
	id: string,
	name: string,
	weapon_class: string,
	light_chain: { AttackStep },
	heavy_chain: { AttackStep },
	combo_reset_s: number,
}

export type Ability = {
	id: string,
	name: string,
	kind: string,
	cooldown_s: number,
	cost: { resource: string, amount: number },
	targeting: string,
	damage_type: string,
	power: number,
	range_studs: number,
	area: Area,
	timing: Timing,
	iframes_s: number?,
	movement: { distance_studs: number, duration_s: number }?,
	guard: { damage_reduction: number, parry_window_s: number }?,
	status_effects: { StatusApplication },
	passive: {
		trigger: string,
		effects: { StatModifier },
		spirit_gain: number?,
		duration_s: number?,
		internal_cooldown_s: number?,
	}?,
}

export type UpgradeTier = {
	tier: number,
	damage_bonus_pct: number,
	materials: { MaterialCost },
	currency_cost: number,
	min_level: number?,
}

export type Weapon = {
	id: string,
	name: string,
	weapon_class: string,
	rarity: string,
	level_req: number,
	base_stats: { damage: number, attack_speed: number, range_studs: number },
	moveset_id: string,
	special_ability_id: string,
	passive_ability_id: string,
	ultimate_ability_id: string?,
	upgrade_tiers: { UpgradeTier },
	presentation: { visual: string, animation: string, sound: string, vfx: string?, icon: string? },
}

export type Material = { id: string, name: string, rarity: string, max_stack: number }

export type EnemyAttack = {
	id: string,
	name: string,
	power: number,
	damage_type: string,
	timing: Timing,
	range_studs: number,
	area: Area,
	avoidable_by: { string },
	tell: { visual: string, audio_cue: boolean, unblockable_marker: boolean? },
	knockback_studs: number,
	poise_damage: number,
	cooldown_s: number,
	status_effects: { StatusApplication }?,
}

export type BossPhase = {
	id: string,
	name: string,
	starts_at_hp: number,
	attack_ids: { string },
	speed_mult: number,
	transition_invulnerable_s: number,
}

export type Boss = {
	title: string,
	arena_id: string,
	music: string,
	checkpoint_each_phase: boolean,
	suggested_level: number?,
	phases: { BossPhase },
	assist_tips: { string },
}

export type Drop = { item_id: string, chance: number, qty_min: number, qty_max: number }

export type Enemy = {
	id: string,
	name: string,
	family: string,
	rank: string,
	stats: {
		hp_mult: number,
		attack_mult: number,
		defense_mult: number,
		poise: number,
		move_speed_studs: number,
		aggro_range_studs: number,
		leash_range_studs: number,
	},
	ai_profile: string,
	attacks: { EnemyAttack },
	resistances: { [string]: number }?,
	rewards: { xp_base: number, currency_base: number, drops: { Drop } },
	boss: Boss?,
	presentation: { visual: string, animation: string, sound: string },
}

export type StatusEffect = {
	id: string,
	name: string,
	polarity: string,
	category: string,
	duration_s: number,
	max_stacks: number,
	tick_interval_s: number?,
	tick_power: number?,
	stat_modifiers: { StatModifier },
	cc: { type: string, slow_fraction: number? }?,
	show_on_hud: boolean,
}

export type Archetype = {
	id: string,
	name: string,
	faction_id: string,
	weapon_classes: { string },
	default_moveset_id: string?,
	defensive_ability_id: string?,
	mobility_ability_id: string?,
	starting_ability_id: string?,
	ultimate_ability_id: string?,
	dev_status: string,
}

export type LevelRange = { min: number, max: number }

export type Region = { id: string, name: string, band_id: string, level_range: LevelRange, map_ids: { string } }

export type Vec3 = { number }

export type MapData = {
	id: string,
	region_id: string,
	name: string,
	bounds: { min: Vec3, max: Vec3 },
	player_spawn: { position: Vec3, facing_deg: number },
	hubs: { { id: string, name: string, position: Vec3, radius_studs: number, services: { string } } },
	fast_travel: { { id: string, name: string, position: Vec3, unlocked_by: string } },
	landmarks: { { id: string, name: string, position: Vec3, size: Vec3, description: string } },
	routes: { { id: string, kind: string, from: string, to: string, waypoints: { Vec3 }, width_studs: number } },
	spawn_zones: {
		{
			id: string,
			center: Vec3,
			radius_studs: number,
			enemy_ids: { string },
			level_range: LevelRange,
			max_alive: number,
			respawn_s: number,
		}
	},
	boss_arenas: { { id: string, boss_id: string, center: Vec3, radius_studs: number, checkpoint_position: Vec3 } },
	secrets: { { id: string, kind: string, position: Vec3, hint: string } },
	blockout: {
		{
			shape: string,
			role: string,
			position: Vec3,
			size: Vec3,
			rotation_deg: Vec3?,
			collide: boolean?,
			label: string?,
		}
	},
}

export type Reward = {
	xp_base: number?,
	currency: { { currency_id: string, amount: number } }?,
	items: { { item_id: string, qty: number } }?,
	cosmetics: { string }?,
	skill_points: number?,
	title: string?,
	unlocks: { string }?,
}

export type Progression = {
	level_cap: number,
	content_level_cap: number,
	xp_curve: { reference_xp_per_minute: number, reward_growth_per_level: number },
	milestones: { interval: number, standard_reward: Reward, major: { { level: number, name: string, reward: Reward } } },
	skill_points: { schedule: { { from: number, to: number, every: number } } },
	stat_scaling: {
		growth_per_level: number,
		player_base: { max_hp: number, attack: number, defense: number },
		enemy_base: { max_hp: number, attack: number, defense: number },
		spirit_max: number,
	},
	level_sync: { enabled: boolean, margin_levels: number, synced_reward_multiplier: number },
	catch_up: { below_recommended_by: number, bonus_per_level_below: number, max_bonus: number },
	anti_grind: { window_s: number, full_reward_kills: number, decay_per_kill: number, floor_multiplier: number },
	anti_exploit: { xp_rate_alarm_factor: number, max_reward_events_per_second: number },
	currencies: { { id: string, name: string, max: number } },
}

export type Combat = {
	damage: {
		defense_constant: number,
		level_gap_per_level: number,
		level_gap_min: number,
		level_gap_max: number,
		crit_chance_base: number,
		crit_multiplier: number,
		variance: number,
		min_damage: number,
	},
	spirit: {
		regen_per_s: number,
		gain_on_hit: number,
		gain_on_hit_taken: number,
		gain_on_parry: number,
		gain_on_perfect_dodge: number,
	},
	dodge: { perfect_window_s: number, chain_limit: number, chain_cooldown_s: number },
	guard: { guard_meter_max: number, guard_meter_regen_per_s: number, guard_break_stagger_s: number },
	poise: { player_poise: number, poise_regen_delay_s: number, stagger_s: number, stagger_immunity_s: number },
	crowd_control: {
		max_hard_cc_s: number,
		diminishing_window_s: number,
		diminishing_multipliers: { number },
		immunity_s: number,
	},
	readability: {
		min_telegraph_s: number,
		min_unblockable_telegraph_s: number,
		max_attackers_per_player: number,
		max_knockback_studs: number,
	},
	lock_on: { range_studs: number, break_range_studs: number },
	feedback: { damage_numbers_default: boolean, hitstop_s: number, camera_shake_default: number },
	movement: { walk_speed: number, sprint_speed: number, guard_walk_speed: number, jump_power: number },
	recovery: { out_of_combat_delay_s: number, regen_fraction_per_s: number, input_buffer_s: number },
}

export type DifficultyMode = {
	id: string,
	name: string,
	enemy_damage_mult: number,
	enemy_hp_mult: number,
	telegraph_time_mult: number,
	parry_window_mult: number,
	dodge_window_mult: number,
	max_attackers_per_player: number,
}

export type Difficulty = {
	default_mode: string,
	modes: { DifficultyMode },
	boss_assist: {
		offer_after_failures: { tip: number, suggested_level: number, training_challenge: number, support_buff: number },
		support_buff_status_id: string,
	},
}

export type InputAction = {
	id: string,
	label: string,
	context: string,
	kind: string,
	press: string?,
	bindings: { [string]: { string } },
	platform_overrides: { [string]: { [string]: { string } } }?,
	remappable: boolean,
}

export type InputActions = {
	actions: { InputAction },
	presets: { { id: string, overrides: { { action_id: string, device: string, bindings: { string } } } } },
	platform_reserved: { [string]: { string } },
}

export type SettingDef = {
	id: string,
	tab: string,
	label: string,
	help: string?,
	kind: string,
	default: any,
	min: number?,
	max: number?,
	step: number?,
	options: { { value: string, label: string } }?,
	platforms: { string },
}

export type Settings = { tabs: { { id: string, label: string } }, settings: { SettingDef } }

export type CosmeticOption = { id: string, category: string, name: string, color: string?, is_default: boolean }
export type Customization = { options: { CosmeticOption } }

return {}
