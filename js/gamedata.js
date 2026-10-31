// Souls Beyond: Eclipse - game data (names, stats, map, XP curve).
// Tweak values here to rebalance the game. Original content; see README.md.
export default {
 "abilities": [
  {
   "id": "abl_wickflare",
   "name": "Wickflare",
   "description": "Hearthwick's special. A crescent wave of lantern flame rolls forward and can set enemies Burning.",
   "kind": "special",
   "cooldown_s": 8,
   "cost": {
    "resource": "spirit",
    "amount": 25
   },
   "targeting": "direction",
   "damage_type": "flame",
   "power": 2.2,
   "range_studs": 40,
   "area": {
    "shape": "line",
    "length_studs": 40,
    "width_studs": 6
   },
   "timing": {
    "windup_s": 0.25,
    "active_s": 0.3,
    "recovery_s": 0.35
   },
   "status_effects": [
    {
     "status_id": "sts_burning",
     "chance": 0.35
    }
   ],
   "upgrade_levels": [
    {
     "level": 2,
     "changes": {
      "power": 2.5
     },
     "materials": [
      {
       "material_id": "mat_gloam_dust",
       "qty": 10
      }
     ],
     "currency_cost": 500
    },
    {
     "level": 3,
     "changes": {
      "cooldown_s": 7
     },
     "materials": [
      {
       "material_id": "mat_wick_thread",
       "qty": 5
      }
     ],
     "currency_cost": 1500
    }
   ],
   "replication": {
    "authority": "server",
    "client_prediction": "visual_only",
    "network_notes": "The casting client plays the swing and wave effect instantly. The server checks cooldown and spirit, sweeps the line once, and applies damage and Burning. Other clients receive one cast event (origin + direction) and replay the effect locally."
   },
   "presentation": {
    "animation": "ast_anim_lanternblade_moveset",
    "vfx": "ast_vfx_wickflare",
    "sound": "ast_sfx_lanternblade"
   },
   "balance_notes": "Main ranged option for a melee style. 25 spirit = roughly two parries' worth.",
   "dev_status": "data_only"
  },
  {
   "id": "abl_kindled_edge",
   "name": "Kindled Edge",
   "description": "Hearthwick's passive. A successful parry refills spirit and briefly sharpens your attacks.",
   "kind": "passive",
   "cooldown_s": 0,
   "cost": {
    "resource": "none",
    "amount": 0
   },
   "targeting": "self",
   "damage_type": "none",
   "power": 0,
   "range_studs": 0,
   "area": {
    "shape": "single_target"
   },
   "timing": {
    "windup_s": 0,
    "active_s": 0,
    "recovery_s": 0
   },
   "status_effects": [],
   "passive": {
    "trigger": "on_parry",
    "effects": [
     {
      "stat": "attack",
      "mode": "add_percent",
      "value": 10
     }
    ],
    "spirit_gain": 15,
    "duration_s": 5,
    "internal_cooldown_s": 3
   },
   "upgrade_levels": [],
   "replication": {
    "authority": "server",
    "client_prediction": "none",
    "network_notes": "The server applies the buff when it confirms a parry. Clients only show the buff icon and a glow on the blade."
   },
   "presentation": {
    "animation": "ast_anim_lanternblade_moveset",
    "vfx": "ast_vfx_wickflare"
   },
   "dev_status": "data_only"
  },
  {
   "id": "abl_flash_step",
   "name": "Flash Step",
   "description": "A near-instant dash in any direction, invulnerable for a split second.",
   "kind": "mobility",
   "cooldown_s": 0.35,
   "cost": {
    "resource": "none",
    "amount": 0
   },
   "targeting": "direction",
   "damage_type": "none",
   "power": 0,
   "range_studs": 14,
   "area": {
    "shape": "single_target"
   },
   "timing": {
    "windup_s": 0,
    "active_s": 0.18,
    "recovery_s": 0.12
   },
   "iframes_s": 0.28,
   "movement": {
    "distance_studs": 14,
    "duration_s": 0.18
   },
   "status_effects": [],
   "upgrade_levels": [],
   "replication": {
    "authority": "server",
    "client_prediction": "movement",
    "network_notes": "The dashing client moves itself immediately so it feels responsive. The server checks distance and cooldown and corrects the position if they don't match. The server owns the invulnerability window."
   },
   "presentation": {
    "animation": "ast_anim_lanternblade_moveset",
    "sound": "ast_sfx_lanternblade"
   },
   "dev_status": "data_only"
  },
  {
   "id": "abl_lantern_guard",
   "name": "Lantern Guard",
   "description": "Hold to guard. Guard just as a hit lands to parry: no damage, and the attacker is knocked off balance.",
   "kind": "defensive",
   "cooldown_s": 0,
   "cost": {
    "resource": "none",
    "amount": 0
   },
   "targeting": "self",
   "damage_type": "none",
   "power": 0,
   "range_studs": 0,
   "area": {
    "shape": "single_target"
   },
   "timing": {
    "windup_s": 0,
    "active_s": 0,
    "recovery_s": 0.1
   },
   "guard": {
    "damage_reduction": 0.75,
    "parry_window_s": 0.2
   },
   "status_effects": [],
   "upgrade_levels": [],
   "replication": {
    "authority": "server",
    "client_prediction": "visual_only",
    "network_notes": "The server decides guard and parry using the time it received the guard input, with a small latency allowance so laggy players can still parry."
   },
   "presentation": {
    "animation": "ast_anim_lanternblade_moveset",
    "sound": "ast_sfx_lanternblade"
   },
   "dev_status": "data_only"
  },
  {
   "id": "abl_cinder_rush",
   "name": "Cinder Rush",
   "description": "Dash forward through enemies, slashing everything along the path.",
   "kind": "active",
   "cooldown_s": 10,
   "cost": {
    "resource": "spirit",
    "amount": 20
   },
   "targeting": "direction",
   "damage_type": "flame",
   "power": 1.6,
   "range_studs": 18,
   "area": {
    "shape": "line",
    "length_studs": 18,
    "width_studs": 5
   },
   "timing": {
    "windup_s": 0.15,
    "active_s": 0.25,
    "recovery_s": 0.4
   },
   "movement": {
    "distance_studs": 18,
    "duration_s": 0.25
   },
   "status_effects": [],
   "upgrade_levels": [
    {
     "level": 2,
     "changes": {
      "power": 1.9
     },
     "materials": [
      {
       "material_id": "mat_gloam_dust",
       "qty": 15
      }
     ],
     "currency_cost": 800
    }
   ],
   "replication": {
    "authority": "server",
    "client_prediction": "movement",
    "network_notes": "Client moves itself along the dash. The server validates the path (no passing through walls), then hits every enemy within the line once."
   },
   "presentation": {
    "animation": "ast_anim_lanternblade_moveset",
    "vfx": "ast_vfx_wickflare",
    "sound": "ast_sfx_lanternblade"
   },
   "dev_status": "data_only"
  },
  {
   "id": "abl_lantern_volley",
   "name": "Lantern Volley",
   "description": "Release three small lanterns that drift toward the nearest enemies and burst.",
   "kind": "active",
   "cooldown_s": 14,
   "cost": {
    "resource": "spirit",
    "amount": 30
   },
   "targeting": "nearest_enemy",
   "damage_type": "flame",
   "power": 0.9,
   "range_studs": 35,
   "area": {
    "shape": "circle",
    "radius_studs": 5
   },
   "timing": {
    "windup_s": 0.3,
    "active_s": 1.5,
    "recovery_s": 0.3
   },
   "status_effects": [
    {
     "status_id": "sts_burning",
     "chance": 0.5
    }
   ],
   "upgrade_levels": [],
   "replication": {
    "authority": "server",
    "client_prediction": "visual_only",
    "network_notes": "Server spawns three projectiles and simulates them at a low tick rate; clients interpolate their positions from start/target info instead of receiving per-frame updates."
   },
   "presentation": {
    "animation": "ast_anim_lanternblade_moveset",
    "vfx": "ast_vfx_wickflare"
   },
   "dev_status": "concept"
  },
  {
   "id": "abl_eclipse_form",
   "name": "Eclipse Form",
   "description": "Your living shadow rises and wraps around you. For a short time you move faster, hit harder and shrug off damage.",
   "kind": "ultimate",
   "cooldown_s": 120,
   "cost": {
    "resource": "spirit",
    "amount": 100
   },
   "targeting": "self",
   "damage_type": "shadow",
   "power": 3,
   "range_studs": 14,
   "area": {
    "shape": "circle",
    "radius_studs": 14
   },
   "timing": {
    "windup_s": 0.8,
    "active_s": 0,
    "recovery_s": 0.2
   },
   "iframes_s": 1,
   "transformation": {
    "duration_s": 15,
    "stat_modifiers": [
     {
      "stat": "attack",
      "mode": "add_percent",
      "value": 30
     },
     {
      "stat": "move_speed",
      "mode": "add_percent",
      "value": 15
     },
     {
      "stat": "damage_taken",
      "mode": "add_percent",
      "value": -15
     }
    ],
    "visual": "ast_vfx_eclipse_form"
   },
   "status_effects": [],
   "upgrade_levels": [],
   "replication": {
    "authority": "server",
    "client_prediction": "visual_only",
    "network_notes": "Server starts and ends the form and owns the stat changes. Clients get start/end events and play the transformation locally. The effect must never darken the screen."
   },
   "presentation": {
    "animation": "ast_anim_lanternblade_moveset",
    "vfx": "ast_vfx_eclipse_form"
   },
   "balance_notes": "Invulnerable during the 0.8 s transformation so it can be used as an emergency escape.",
   "dev_status": "data_only"
  }
 ],
 "enemies": [
  {
   "id": "enm_gloamling",
   "name": "Gloamling",
   "family": "gloam_beast",
   "rank": "minion",
   "description": "A hunched shadow the size of a large dog, with a single dim ember for an eye. It hunts light.",
   "region_ids": [
    "reg_akeboshi_city"
   ],
   "stats": {
    "hp_mult": 1,
    "attack_mult": 1,
    "defense_mult": 1,
    "poise": 30,
    "move_speed_studs": 16,
    "aggro_range_studs": 45,
    "leash_range_studs": 90
   },
   "ai_profile": "melee_skirmisher",
   "attacks": [
    {
     "id": "swipe",
     "name": "Claw Swipe",
     "power": 0.9,
     "damage_type": "slash",
     "timing": {
      "windup_s": 0.55,
      "active_s": 0.12,
      "recovery_s": 0.6
     },
     "range_studs": 6,
     "area": {
      "shape": "cone",
      "radius_studs": 6,
      "angle_deg": 90
     },
     "avoidable_by": [
      "dodge",
      "guard",
      "parry"
     ],
     "tell": {
      "visual": "wind_up_pose",
      "audio_cue": true
     },
     "knockback_studs": 1,
     "poise_damage": 15,
     "cooldown_s": 2.5
    },
    {
     "id": "pounce",
     "name": "Ember Pounce",
     "power": 1.3,
     "damage_type": "blunt",
     "timing": {
      "windup_s": 0.9,
      "active_s": 0.3,
      "recovery_s": 1.0
     },
     "range_studs": 18,
     "area": {
      "shape": "circle",
      "radius_studs": 4
     },
     "avoidable_by": [
      "dodge",
      "move_out"
     ],
     "tell": {
      "visual": "body_glow",
      "audio_cue": true,
      "unblockable_marker": true
     },
     "knockback_studs": 6,
     "poise_damage": 30,
     "cooldown_s": 7
    }
   ],
   "resistances": {
    "flame": 1.25,
    "shadow": 0.5
   },
   "rewards": {
    "xp_base": 12,
    "currency_base": 3,
    "drops": [
     {
      "item_id": "mat_gloam_dust",
      "chance": 0.6,
      "qty_min": 1,
      "qty_max": 3
     },
     {
      "item_id": "mat_wick_thread",
      "chance": 0.08,
      "qty_min": 1,
      "qty_max": 1
     }
    ]
   },
   "presentation": {
    "visual": "ast_enm_gloamling",
    "animation": "ast_anim_gloamling",
    "sound": "ast_sfx_gloamling"
   },
   "dev_status": "data_only"
  },
  {
   "id": "enm_lampeater",
   "name": "Lampeater",
   "family": "gloam_beast",
   "rank": "boss",
   "description": "A long-limbed Gloam that swallowed every street lamp on the harbor promenade. The lamps still glow inside its ribs, which is how you see it coming.",
   "region_ids": [
    "reg_akeboshi_city"
   ],
   "stats": {
    "hp_mult": 12,
    "attack_mult": 1.4,
    "defense_mult": 1.2,
    "poise": 400,
    "move_speed_studs": 20,
    "aggro_range_studs": 80,
    "leash_range_studs": 200
   },
   "ai_profile": "boss_scripted",
   "attacks": [
    {
     "id": "lamp_swipe",
     "name": "Lamp Swipe",
     "power": 1.2,
     "damage_type": "slash",
     "timing": {
      "windup_s": 0.6,
      "active_s": 0.15,
      "recovery_s": 0.7
     },
     "range_studs": 12,
     "area": {
      "shape": "cone",
      "radius_studs": 12,
      "angle_deg": 120
     },
     "avoidable_by": [
      "dodge",
      "guard",
      "parry"
     ],
     "tell": {
      "visual": "body_glow",
      "audio_cue": true
     },
     "knockback_studs": 3,
     "poise_damage": 20,
     "cooldown_s": 2
    },
    {
     "id": "twin_swipe",
     "name": "Twin Swipe",
     "power": 1.0,
     "damage_type": "slash",
     "timing": {
      "windup_s": 0.5,
      "active_s": 0.4,
      "recovery_s": 0.9
     },
     "range_studs": 12,
     "area": {
      "shape": "cone",
      "radius_studs": 12,
      "angle_deg": 150
     },
     "avoidable_by": [
      "dodge",
      "guard",
      "parry"
     ],
     "tell": {
      "visual": "wind_up_pose",
      "audio_cue": true
     },
     "knockback_studs": 2,
     "poise_damage": 25,
     "cooldown_s": 4
    },
    {
     "id": "light_lunge",
     "name": "Swallowed-Light Lunge",
     "power": 1.8,
     "damage_type": "blunt",
     "timing": {
      "windup_s": 0.9,
      "active_s": 0.35,
      "recovery_s": 1.4
     },
     "range_studs": 30,
     "area": {
      "shape": "line",
      "length_studs": 30,
      "width_studs": 8
     },
     "avoidable_by": [
      "dodge",
      "move_out"
     ],
     "tell": {
      "visual": "ground_marker",
      "audio_cue": true,
      "unblockable_marker": true
     },
     "knockback_studs": 8,
     "poise_damage": 40,
     "cooldown_s": 9
    },
    {
     "id": "blackout_ring",
     "name": "Blackout Ring",
     "power": 1.5,
     "damage_type": "shadow",
     "timing": {
      "windup_s": 1.2,
      "active_s": 0.4,
      "recovery_s": 1.5
     },
     "range_studs": 24,
     "area": {
      "shape": "ring",
      "radius_studs": 24,
      "width_studs": 6
     },
     "avoidable_by": [
      "dodge",
      "move_out"
     ],
     "tell": {
      "visual": "ground_marker",
      "audio_cue": true,
      "unblockable_marker": true
     },
     "knockback_studs": 4,
     "poise_damage": 30,
     "cooldown_s": 14,
     "status_effects": [
      {
       "status_id": "sts_dimmed",
       "chance": 1
      }
     ]
    },
    {
     "id": "spat_lanterns",
     "name": "Spat Lanterns",
     "power": 0.8,
     "damage_type": "flame",
     "timing": {
      "windup_s": 0.7,
      "active_s": 1.2,
      "recovery_s": 1.0
     },
     "range_studs": 50,
     "area": {
      "shape": "circle",
      "radius_studs": 5
     },
     "avoidable_by": [
      "dodge",
      "guard",
      "move_out"
     ],
     "tell": {
      "visual": "ground_marker",
      "audio_cue": true
     },
     "knockback_studs": 1,
     "poise_damage": 10,
     "cooldown_s": 10,
     "status_effects": [
      {
       "status_id": "sts_burning",
       "chance": 0.5
      }
     ]
    }
   ],
   "resistances": {
    "shadow": 0.5,
    "light": 1.5
   },
   "rewards": {
    "xp_base": 600,
    "currency_base": 150,
    "drops": [
     {
      "item_id": "mat_eclipse_ember",
      "chance": 1,
      "qty_min": 1,
      "qty_max": 1
     },
     {
      "item_id": "mat_warden_steel",
      "chance": 0.5,
      "qty_min": 1,
      "qty_max": 2
     },
     {
      "item_id": "mat_wick_thread",
      "chance": 1,
      "qty_min": 3,
      "qty_max": 6
     }
    ]
   },
   "boss": {
    "title": "Devourer of the Promenade Lights",
    "arena_id": "arn_promenade_plaza",
    "music": "ast_music_lampeater",
    "intro_skippable": true,
    "checkpoint_each_phase": true,
    "suggested_level": 15,
    "phases": [
     {
      "id": "hungry",
      "name": "Hungry",
      "starts_at_hp": 1,
      "attack_ids": [
       "lamp_swipe",
       "twin_swipe",
       "light_lunge"
      ],
      "speed_mult": 1,
      "transition_invulnerable_s": 0
     },
     {
      "id": "lights_out",
      "name": "Lights Out",
      "starts_at_hp": 0.6,
      "attack_ids": [
       "lamp_swipe",
       "twin_swipe",
       "light_lunge",
       "blackout_ring"
      ],
      "speed_mult": 1.1,
      "transition_invulnerable_s": 2,
      "notes": "Arena lamps dim but the boss's ribs glow brighter, so it stays easy to see. Never full-screen darkness."
     },
     {
      "id": "overfed",
      "name": "Overfed",
      "starts_at_hp": 0.25,
      "attack_ids": [
       "twin_swipe",
       "light_lunge",
       "blackout_ring",
       "spat_lanterns"
      ],
      "speed_mult": 1.15,
      "transition_invulnerable_s": 2
     }
    ],
    "assist_tips": [
     "The Lunge cannot be blocked: watch for the orange line on the ground and dodge sideways.",
     "For the Blackout Ring, stand in its centre or dodge through its edge.",
     "Parrying a Lamp Swipe refills spirit fast. Spend it on Wickflare."
    ]
   },
   "presentation": {
    "visual": "ast_enm_lampeater",
    "animation": "ast_anim_lampeater",
    "sound": "ast_sfx_lampeater"
   },
   "dev_status": "data_only"
  }
 ],
 "statusEffects": [
  {
   "id": "sts_burning",
   "name": "Burning",
   "description": "Takes flame damage every second.",
   "polarity": "debuff",
   "category": "damage_over_time",
   "duration_s": 4,
   "max_stacks": 3,
   "tick_interval_s": 1,
   "tick_power": 0.1,
   "stat_modifiers": [],
   "dispellable": true,
   "show_on_hud": true,
   "dev_status": "data_only"
  },
  {
   "id": "sts_staggered",
   "name": "Staggered",
   "description": "Off balance and unable to act for a moment. Followed by stagger immunity.",
   "polarity": "debuff",
   "category": "hard_cc",
   "duration_s": 0.8,
   "max_stacks": 1,
   "stat_modifiers": [],
   "cc": {
    "type": "stun"
   },
   "dispellable": false,
   "show_on_hud": true,
   "dev_status": "data_only"
  },
  {
   "id": "sts_dimmed",
   "name": "Dimmed",
   "description": "The Gloam swallows some of your light: you move more slowly.",
   "polarity": "debuff",
   "category": "soft_cc",
   "duration_s": 3,
   "max_stacks": 1,
   "stat_modifiers": [],
   "cc": {
    "type": "slow",
    "slow_fraction": 0.25
   },
   "dispellable": true,
   "show_on_hud": true,
   "dev_status": "data_only"
  },
  {
   "id": "sts_resolve",
   "name": "Resolve",
   "description": "Optional support buff offered after repeated boss defeats: take less damage, hit a little harder.",
   "polarity": "buff",
   "category": "stat_modifier",
   "duration_s": 600,
   "max_stacks": 1,
   "stat_modifiers": [
    {
     "stat": "damage_taken",
     "mode": "add_percent",
     "value": -20
    },
    {
     "stat": "attack",
     "mode": "add_percent",
     "value": 10
    }
   ],
   "dispellable": false,
   "show_on_hud": true,
   "dev_status": "data_only"
  }
 ],
 "weapons": [
  {
   "id": "wpn_hearthwick",
   "name": "Hearthwick",
   "category": "weapon",
   "weapon_class": "katana",
   "rarity": "common",
   "level_req": 1,
   "description": "A Lantern Warden's training katana. A thin line of flame runs down the blade like a lantern wick and flares brighter whenever you parry.",
   "base_stats": {
    "damage": 100,
    "attack_speed": 1.0,
    "range_studs": 7.5
   },
   "moveset_id": "mvs_lanternblade_katana",
   "special_ability_id": "abl_wickflare",
   "passive_ability_id": "abl_kindled_edge",
   "upgrade_tiers": [
    {
     "tier": 1,
     "damage_bonus_pct": 8,
     "materials": [
      {
       "material_id": "mat_gloam_dust",
       "qty": 5
      }
     ],
     "currency_cost": 200
    },
    {
     "tier": 2,
     "damage_bonus_pct": 16,
     "min_level": 10,
     "materials": [
      {
       "material_id": "mat_gloam_dust",
       "qty": 10
      },
      {
       "material_id": "mat_wick_thread",
       "qty": 2
      }
     ],
     "currency_cost": 600
    },
    {
     "tier": 3,
     "damage_bonus_pct": 26,
     "min_level": 20,
     "materials": [
      {
       "material_id": "mat_wick_thread",
       "qty": 6
      }
     ],
     "currency_cost": 1500
    },
    {
     "tier": 4,
     "damage_bonus_pct": 38,
     "min_level": 35,
     "materials": [
      {
       "material_id": "mat_wick_thread",
       "qty": 10
      },
      {
       "material_id": "mat_warden_steel",
       "qty": 2
      }
     ],
     "currency_cost": 4000
    },
    {
     "tier": 5,
     "damage_bonus_pct": 52,
     "min_level": 50,
     "materials": [
      {
       "material_id": "mat_warden_steel",
       "qty": 5
      },
      {
       "material_id": "mat_eclipse_ember",
       "qty": 1
      }
     ],
     "currency_cost": 9000,
     "note": "Needs the Lampeater's Eclipse Ember."
    }
   ],
   "unlock_source": {
    "type": "story",
    "ref_id": "qst_main_seven_minutes",
    "note": "Handed over by Lieutenant Haneda at the end of the opening quest."
   },
   "presentation": {
    "visual": "ast_wpn_hearthwick",
    "animation": "ast_anim_lanternblade_moveset",
    "sound": "ast_sfx_lanternblade",
    "vfx": "ast_vfx_wickflare"
   },
   "balance_notes": "Baseline weapon (damage 100); other katanas are balanced against it. Tier 5 (+52%) keeps it usable through the harbor district, but it should fall behind rare weapons found after level 60.",
   "dev_status": "data_only"
  }
 ],
 "materials": [
  {
   "id": "mat_gloam_dust",
   "name": "Gloam Dust",
   "category": "material",
   "rarity": "common",
   "description": "Grey dust left behind when a Gloamling fades.",
   "max_stack": 999,
   "sources": [
    {
     "type": "drop",
     "ref_id": "enm_gloamling"
    }
   ],
   "sell_value": 2,
   "dev_status": "data_only"
  },
  {
   "id": "mat_wick_thread",
   "name": "Wick Thread",
   "category": "material",
   "rarity": "uncommon",
   "description": "Still-glowing thread from street lanterns that went out during the eclipse.",
   "max_stack": 999,
   "sources": [
    {
     "type": "exploration",
     "ref_id": "reg_akeboshi_city"
    },
    {
     "type": "drop",
     "ref_id": "enm_gloamling",
     "note": "Rare drop."
    }
   ],
   "sell_value": 10,
   "dev_status": "data_only"
  },
  {
   "id": "mat_warden_steel",
   "name": "Warden Steel",
   "category": "material",
   "rarity": "rare",
   "description": "Shrine-tempered steel issued by the Lantern Wardens.",
   "max_stack": 99,
   "sources": [
    {
     "type": "quest",
     "ref_id": "qst_side_lamplighter"
    },
    {
     "type": "shop",
     "ref_id": "hub_ferry_terminal",
     "note": "Warden quartermaster, after the opening quest."
    }
   ],
   "sell_value": 50,
   "dev_status": "data_only"
  },
  {
   "id": "mat_eclipse_ember",
   "name": "Eclipse Ember",
   "category": "material",
   "rarity": "epic",
   "description": "A coal that burns black. The Lampeater carries one in its throat.",
   "max_stack": 99,
   "sources": [
    {
     "type": "boss",
     "ref_id": "enm_lampeater"
    }
   ],
   "sell_value": 200,
   "dev_status": "data_only"
  }
 ],
 "movesets": [
  {
   "id": "mvs_lanternblade_katana",
   "name": "Lanternblade Katana Forms",
   "weapon_class": "katana",
   "light_chain": [
    {
     "id": "light_1",
     "power": 0.8,
     "damage_type": "slash",
     "timing": {
      "windup_s": 0.12,
      "active_s": 0.08,
      "recovery_s": 0.22
     },
     "range_studs": 7,
     "arc_deg": 100,
     "knockback_studs": 0.5,
     "poise_damage": 10,
     "dodge_cancel_after_s": 0.12
    },
    {
     "id": "light_2",
     "power": 0.85,
     "damage_type": "slash",
     "timing": {
      "windup_s": 0.12,
      "active_s": 0.08,
      "recovery_s": 0.24
     },
     "range_studs": 7,
     "arc_deg": 110,
     "knockback_studs": 0.5,
     "poise_damage": 10,
     "dodge_cancel_after_s": 0.12
    },
    {
     "id": "light_3",
     "power": 1.0,
     "damage_type": "slash",
     "timing": {
      "windup_s": 0.16,
      "active_s": 0.1,
      "recovery_s": 0.28
     },
     "range_studs": 7.5,
     "arc_deg": 140,
     "knockback_studs": 1,
     "poise_damage": 14,
     "dodge_cancel_after_s": 0.16
    },
    {
     "id": "light_4",
     "power": 1.5,
     "damage_type": "flame",
     "timing": {
      "windup_s": 0.22,
      "active_s": 0.12,
      "recovery_s": 0.45
     },
     "range_studs": 8,
     "arc_deg": 180,
     "knockback_studs": 6,
     "poise_damage": 30,
     "dodge_cancel_after_s": 0.22
    }
   ],
   "heavy_chain": [
    {
     "id": "heavy_1",
     "power": 1.8,
     "damage_type": "slash",
     "timing": {
      "windup_s": 0.35,
      "active_s": 0.12,
      "recovery_s": 0.5
     },
     "charge_s": 0.8,
     "range_studs": 8.5,
     "arc_deg": 120,
     "knockback_studs": 4,
     "poise_damage": 35,
     "dodge_cancel_after_s": 0.2
    },
    {
     "id": "heavy_2",
     "power": 2.4,
     "damage_type": "flame",
     "timing": {
      "windup_s": 0.4,
      "active_s": 0.15,
      "recovery_s": 0.6
     },
     "range_studs": 9,
     "arc_deg": 200,
     "knockback_studs": 10,
     "poise_damage": 55,
     "dodge_cancel_after_s": 0.25
    }
   ],
   "dash_attack": {
    "id": "dash",
    "power": 1.2,
    "damage_type": "slash",
    "timing": {
     "windup_s": 0.1,
     "active_s": 0.15,
     "recovery_s": 0.35
    },
    "range_studs": 10,
    "arc_deg": 60,
    "knockback_studs": 2,
    "poise_damage": 20,
    "dodge_cancel_after_s": 0.15
   },
   "air_attack": {
    "id": "air",
    "power": 1.1,
    "damage_type": "slash",
    "timing": {
     "windup_s": 0.15,
     "active_s": 0.1,
     "recovery_s": 0.3
    },
    "range_studs": 7,
    "arc_deg": 120,
    "knockback_studs": 3,
    "poise_damage": 15,
    "dodge_cancel_after_s": 0.15
   },
   "combo_reset_s": 0.9,
   "animation_set": "ast_anim_lanternblade_moveset",
   "dev_status": "data_only"
  }
 ],
 "regions": [
  {
   "id": "reg_akeboshi_city",
   "name": "Akeboshi City",
   "theme": "Modern Japanese-inspired coastal city at night: shopping arcades, ferry piers, rooftops.",
   "description": "Where the Seven-Minute Eclipse struck. The harbor clocktower stopped at 12:07 and has not moved since. Phase 1 builds one district of it: the harbor.",
   "band_id": "bnd_opening_city",
   "level_range": {
    "min": 1,
    "max": 120
   },
   "map_ids": [
    "map_akeboshi_harbor"
   ],
   "connects_to": [
    "reg_ura_akeboshi"
   ],
   "boss_ids": [
    "enm_lampeater"
   ],
   "landmark_summary": "The stopped Harbor Clocktower and the broken Sunrise Bridge.",
   "story_beats": [
    "The eclipse and the sleeping city",
    "The player's shadow moves on its own",
    "Joining the Lantern Wardens",
    "The Lampeater"
   ],
   "dev_status": "data_only"
  },
  {
   "id": "reg_ura_akeboshi",
   "name": "Ura-Akeboshi",
   "theme": "The city's spirit-side reflection: flooded streets, floating lanterns, buildings hanging upside down overhead.",
   "description": "A mirror of Akeboshi that only the awakened can enter. The Omokage Troupe holds a festival here that never ends.",
   "band_id": "bnd_opening_city",
   "level_range": {
    "min": 121,
    "max": 250
   },
   "map_ids": [],
   "connects_to": [
    "reg_akeboshi_city",
    "reg_amagiri_capital"
   ],
   "boss_ids": [],
   "landmark_summary": "The Upside-Down Shrine Gate.",
   "dev_status": "concept"
  },
  {
   "id": "reg_amagiri_capital",
   "name": "Amagiri, the Mistbound Capital",
   "theme": "Hidden spiritual capital in a canyon of endless rain mist: terraced shrines, lantern bridges, council halls.",
   "description": "Seat of the six-faction council. Politics, trials and the first signs of a conspiracy.",
   "band_id": "bnd_hidden_capital",
   "level_range": {
    "min": 251,
    "max": 480
   },
   "map_ids": [],
   "connects_to": [
    "reg_ura_akeboshi",
    "reg_thousand_stacks",
    "reg_shirokane_peaks"
   ],
   "boss_ids": [],
   "landmark_summary": "The Council of Six Lanterns.",
   "dev_status": "concept"
  },
  {
   "id": "reg_thousand_stacks",
   "name": "The Thousand Stacks",
   "theme": "Paper Court archive maze carved into the canyon walls below the capital.",
   "description": "Somewhere in these shelves is the erased star chart that predicted the eclipse.",
   "band_id": "bnd_hidden_capital",
   "level_range": {
    "min": 481,
    "max": 700
   },
   "map_ids": [],
   "connects_to": [
    "reg_amagiri_capital"
   ],
   "boss_ids": [],
   "landmark_summary": "The Folded Tower.",
   "dev_status": "concept"
  },
  {
   "id": "reg_shirokane_peaks",
   "name": "Shirokane Peaks",
   "theme": "Frozen mountain range with the Bellhold Monastery; avalanches of frozen sound.",
   "description": "Side arc: the monastery's great bell has fallen silent, and the mountain is listening.",
   "band_id": "bnd_silent_bell",
   "level_range": {
    "min": 701,
    "max": 1000
   },
   "map_ids": [],
   "connects_to": [
    "reg_amagiri_capital",
    "reg_inverse_tide"
   ],
   "boss_ids": [],
   "landmark_summary": "The Silent Bell.",
   "dev_status": "concept"
  },
  {
   "id": "reg_inverse_tide",
   "name": "The Inverse Tide",
   "theme": "Enemy realm: an endless shallow sea of ink under a black sun.",
   "description": "Home of the Penumbral Synod. Their citadel is built on the shell of a sleeping leviathan.",
   "band_id": "bnd_tide_of_ink",
   "level_range": {
    "min": 1001,
    "max": 1350
   },
   "map_ids": [],
   "connects_to": [
    "reg_shirokane_peaks",
    "reg_kurogane_caldera"
   ],
   "boss_ids": [],
   "landmark_summary": "The Leviathan Citadel.",
   "dev_status": "concept"
  },
  {
   "id": "reg_kurogane_caldera",
   "name": "Kurogane Caldera",
   "theme": "Volcanic wasteland and the Synod's war forges.",
   "description": "The front line of the war. Rivers of lava have been rerouted to feed the forges that shape Gloam soldiers.",
   "band_id": "bnd_tide_of_ink",
   "level_range": {
    "min": 1351,
    "max": 1700
   },
   "map_ids": [],
   "connects_to": [
    "reg_inverse_tide",
    "reg_tenkyu_palace"
   ],
   "boss_ids": [],
   "landmark_summary": "The Great Forge.",
   "dev_status": "concept"
  },
  {
   "id": "reg_tenkyu_palace",
   "name": "Tenkyu, the Floating Palace",
   "theme": "Sky palace above the clouds with gravity-shifting courtyards.",
   "description": "Where the player finally faces their own shadow and gains a second power.",
   "band_id": "bnd_two_suns",
   "level_range": {
    "min": 1701,
    "max": 2000
   },
   "map_ids": [],
   "connects_to": [
    "reg_kurogane_caldera",
    "reg_hakumei_rift"
   ],
   "boss_ids": [],
   "landmark_summary": "The Mirror Throne.",
   "dev_status": "concept"
  },
  {
   "id": "reg_hakumei_rift",
   "name": "The Hakumei Rift",
   "theme": "Alternate dimension of permanent twilight where fragments of every realm overlap.",
   "description": "The final war spreads across realms. Pieces of every earlier region drift here, changed by the war.",
   "band_id": "bnd_hakumei_war",
   "level_range": {
    "min": 2001,
    "max": 2350
   },
   "map_ids": [],
   "connects_to": [
    "reg_tenkyu_palace",
    "reg_sun_below"
   ],
   "boss_ids": [],
   "landmark_summary": "The Overlap.",
   "dev_status": "concept"
  },
  {
   "id": "reg_sun_below",
   "name": "The Sun Below",
   "theme": "The dimming hidden sun that relights every soul.",
   "description": "The last battlefield of the war, and the answer to what the eclipse really was.",
   "band_id": "bnd_hakumei_war",
   "level_range": {
    "min": 2351,
    "max": 2700
   },
   "map_ids": [],
   "connects_to": [
    "reg_hakumei_rift",
    "reg_corona_abyss"
   ],
   "boss_ids": [],
   "landmark_summary": "The Heartflame.",
   "dev_status": "concept"
  },
  {
   "id": "reg_corona_abyss",
   "name": "The Corona Abyss",
   "theme": "Endgame region inside the corona of the eclipsed sun.",
   "description": "Dungeons, raids, a boss rush and secret bosses for players after the story.",
   "band_id": "bnd_corona",
   "level_range": {
    "min": 2701,
    "max": 3000
   },
   "map_ids": [],
   "connects_to": [
    "reg_sun_below"
   ],
   "boss_ids": [],
   "landmark_summary": "The Corona Gate.",
   "dev_status": "concept"
  }
 ],
 "progression": {
  "version": 1,
  "level_cap": 3000,
  "content_level_cap": 50,
  "xp_curve": {
   "reference_xp_per_minute": 100,
   "reward_growth_per_level": 0.05,
   "pace_points": [
    [
     1,
     0.5
    ],
    [
     10,
     1.3
    ],
    [
     30,
     2.6
    ],
    [
     60,
     3.5
    ],
    [
     100,
     4.0
    ],
    [
     250,
     4.15
    ],
    [
     500,
     4.25
    ],
    [
     1000,
     4.4
    ],
    [
     1700,
     4.6
    ],
    [
     2000,
     4.7
    ],
    [
     2700,
     4.9
    ],
    [
     2999,
     5.0
    ]
   ],
   "round_to": 5
  },
  "level_bands": [
   {
    "id": "bnd_opening_city",
    "name": "Seven Minutes of Night",
    "min": 1,
    "max": 250,
    "summary": "The eclipse over Akeboshi City, awakening, the Lantern Wardens, and the mirror city Ura-Akeboshi."
   },
   {
    "id": "bnd_hidden_capital",
    "name": "Lanterns in the Mist",
    "min": 251,
    "max": 700,
    "summary": "The hidden capital Amagiri, the six-faction council, trials, and a conspiracy hidden in the archives."
   },
   {
    "id": "bnd_silent_bell",
    "name": "The Silent Bell",
    "min": 701,
    "max": 1000,
    "summary": "Side arc in the frozen Shirokane Peaks: the Bellhold Monastery and the rival's companion story."
   },
   {
    "id": "bnd_tide_of_ink",
    "name": "Tide of Ink",
    "min": 1001,
    "max": 1700,
    "summary": "The Penumbral Synod invades. The war moves into the Inverse Tide and the Kurogane Caldera forges."
   },
   {
    "id": "bnd_two_suns",
    "name": "Two Suns",
    "min": 1701,
    "max": 2000,
    "summary": "In the floating palace the player faces their own shadow and gains a second power."
   },
   {
    "id": "bnd_hakumei_war",
    "name": "Hakumei",
    "min": 2001,
    "max": 2700,
    "summary": "Final war across overlapping realms, ending at the Sun Below."
   },
   {
    "id": "bnd_corona",
    "name": "Corona",
    "min": 2701,
    "max": 3000,
    "summary": "Endgame: dungeons, raids, a boss rush and secret bosses."
   }
  ],
  "milestones": {
   "interval": 50,
   "standard_reward": {
    "skill_points": 2,
    "currency": [
     {
      "currency_id": "cur_marks",
      "amount": 500
     }
    ]
   },
   "major": [
    {
     "level": 100,
     "name": "Kindled",
     "reward": {
      "skill_points": 5,
      "title": "Kindled",
      "cosmetics": [
       "cos_aura_milestone_gold"
      ],
      "unlocks": [
       "Second loadout slot"
      ]
     }
    },
    {
     "level": 500,
     "name": "Lantern-Bearer",
     "reward": {
      "skill_points": 8,
      "title": "Lantern-Bearer",
      "unlocks": [
       "Third loadout slot"
      ]
     }
    },
    {
     "level": 1000,
     "name": "Thousandfold Flame",
     "reward": {
      "skill_points": 10,
      "title": "Thousandfold Flame"
     }
    },
    {
     "level": 1500,
     "name": "Ink-Walker",
     "reward": {
      "skill_points": 10,
      "title": "Ink-Walker"
     }
    },
    {
     "level": 2000,
     "name": "Twin Sun",
     "reward": {
      "skill_points": 12,
      "title": "Twin Sun"
     }
    },
    {
     "level": 2500,
     "name": "Hakumei Veteran",
     "reward": {
      "skill_points": 12,
      "title": "Hakumei Veteran"
     }
    },
    {
     "level": 3000,
     "name": "Eclipse Eternal",
     "reward": {
      "skill_points": 15,
      "title": "Eclipse Eternal",
      "unlocks": [
       "Secret boss gallery"
      ]
     }
    }
   ]
  },
  "skill_points": {
   "schedule": [
    {
     "from": 2,
     "to": 100,
     "every": 1
    },
    {
     "from": 101,
     "to": 3000,
     "every": 10
    }
   ]
  },
  "stat_scaling": {
   "growth_per_level": 0.05,
   "player_base": {
    "max_hp": 500,
    "attack": 50,
    "defense": 25
   },
   "enemy_base": {
    "max_hp": 250,
    "attack": 40,
    "defense": 20
   },
   "spirit_max": 100
  },
  "level_sync": {
   "enabled": true,
   "margin_levels": 15,
   "synced_reward_multiplier": 0.8
  },
  "catch_up": {
   "below_recommended_by": 10,
   "bonus_per_level_below": 0.03,
   "max_bonus": 0.75,
   "returning_player": {
    "days_away": 14,
    "bonus_multiplier": 1.5,
    "bonus_minutes": 120
   }
  },
  "anti_grind": {
   "window_s": 600,
   "full_reward_kills": 20,
   "decay_per_kill": 0.85,
   "floor_multiplier": 0.25
  },
  "anti_exploit": {
   "xp_rate_alarm_factor": 8,
   "max_reward_events_per_second": 10,
   "action": "log_and_clamp"
  },
  "xp_sources": [
   {
    "id": "story_mission",
    "name": "Story mission",
    "kind": "story_mission",
    "base_xp": 2400,
    "typical_minutes": 18,
    "repeatable": false
   },
   {
    "id": "side_quest",
    "name": "Side quest",
    "kind": "side_quest",
    "base_xp": 900,
    "typical_minutes": 9,
    "repeatable": false
   },
   {
    "id": "discovery",
    "name": "Landmark or secret found",
    "kind": "exploration",
    "base_xp": 250,
    "typical_minutes": 3,
    "repeatable": false
   },
   {
    "id": "field_enemy",
    "name": "Field enemy defeated",
    "kind": "combat",
    "base_xp": 12,
    "typical_minutes": 0.25,
    "repeatable": true
   },
   {
    "id": "boss",
    "name": "Boss defeated (first time)",
    "kind": "boss",
    "base_xp": 1500,
    "typical_minutes": 8,
    "repeatable": false
   },
   {
    "id": "dungeon",
    "name": "Dungeon run",
    "kind": "dungeon",
    "base_xp": 3600,
    "typical_minutes": 25,
    "repeatable": true
   },
   {
    "id": "training",
    "name": "Training challenge",
    "kind": "training",
    "base_xp": 300,
    "typical_minutes": 4,
    "repeatable": true
   },
   {
    "id": "faction_mission",
    "name": "Faction mission",
    "kind": "faction_mission",
    "base_xp": 1400,
    "typical_minutes": 12,
    "repeatable": true
   },
   {
    "id": "group_activity",
    "name": "Optional group activity",
    "kind": "group_activity",
    "base_xp": 2000,
    "typical_minutes": 15,
    "repeatable": true
   }
  ],
  "respec": {
   "allowed_anytime": true,
   "currency_cost": 0
  },
  "currencies": [
   {
    "id": "cur_marks",
    "name": "Marks",
    "description": "Warden-issued coins, accepted everywhere the lanterns still burn.",
    "max": 1000000000000
   }
  ]
 },
 "xpToNext": [
  50,
  60,
  75,
  90,
  105,
  120,
  135,
  150,
  170,
  190,
  205,
  220,
  240,
  255,
  275,
  295,
  315,
  335,
  360,
  380,
  405,
  425,
  450,
  475,
  500,
  525,
  555,
  580,
  610,
  635,
  660,
  680,
  700,
  720,
  745,
  765,
  785,
  810,
  830,
  855,
  880,
  905,
  925,
  950,
  975,
  1000,
  1025,
  1050,
  1080,
  1105,
  1130,
  1155,
  1185,
  1210,
  1240,
  1270,
  1295,
  1325,
  1355,
  1385,
  1405,
  1430,
  1450,
  1475,
  1495,
  1520,
  1545,
  1565,
  1590,
  1615,
  1635,
  1660,
  1685,
  1710,
  1735,
  1760,
  1780,
  1805,
  1830,
  1855,
  1880,
  1905,
  1930,
  1955,
  1985,
  2010,
  2035,
  2060,
  2085,
  2110,
  2140,
  2165,
  2190,
  2220,
  2245,
  2270,
  2300,
  2325,
  2355,
  2380,
  2400,
  2420,
  2440,
  2460,
  2485,
  2505,
  2525,
  2545,
  2565,
  2585,
  2605,
  2630,
  2650,
  2670,
  2690,
  2710,
  2730,
  2750,
  2775,
  2795,
  2815,
  2835,
  2855,
  2875,
  2900,
  2920,
  2940,
  2960,
  2980,
  3000,
  3025,
  3045,
  3065,
  3085,
  3105,
  3130,
  3150,
  3170,
  3190,
  3210,
  3235,
  3255,
  3275,
  3295,
  3315,
  3340,
  3360,
  3380,
  3400,
  3420,
  3445,
  3465,
  3485,
  3505,
  3530,
  3550,
  3570,
  3590,
  3615,
  3635,
  3655,
  3675,
  3695,
  3720,
  3740,
  3760,
  3780,
  3805,
  3825,
  3845,
  3865,
  3890,
  3910,
  3930,
  3955,
  3975,
  3995,
  4015,
  4040,
  4060,
  4080,
  4100,
  4125,
  4145,
  4165,
  4190,
  4210,
  4230,
  4255,
  4275,
  4295,
  4315,
  4340,
  4360,
  4380,
  4405,
  4425,
  4445,
  4470,
  4490,
  4510,
  4535,
  4555,
  4575,
  4600,
  4620,
  4640,
  4665,
  4685,
  4705,
  4730,
  4750,
  4770,
  4795,
  4815,
  4835,
  4860,
  4880,
  4900,
  4925,
  4945,
  4965,
  4990,
  5010,
  5035,
  5055,
  5075,
  5100,
  5120,
  5140,
  5165,
  5185,
  5210,
  5230,
  5250,
  5275,
  5295,
  5315,
  5340,
  5360,
  5385,
  5405,
  5425,
  5450,
  5470,
  5495,
  5515,
  5540,
  5560,
  5580,
  5605,
  5625,
  5645,
  5665,
  5690,
  5710,
  5730,
  5750,
  5775,
  5795,
  5815,
  5835,
  5860,
  5880,
  5900,
  5925,
  5945,
  5965,
  5985,
  6010,
  6030,
  6050,
  6070,
  6095,
  6115,
  6135,
  6160,
  6180,
  6200,
  6220,
  6245,
  6265,
  6285,
  6310,
  6330,
  6350,
  6370,
  6395,
  6415,
  6435,
  6460,
  6480,
  6500,
  6520,
  6545,
  6565,
  6585,
  6610,
  6630,
  6650,
  6675,
  6695,
  6715,
  6735,
  6760,
  6780,
  6800,
  6825,
  6845,
  6865,
  6890,
  6910,
  6930,
  6950,
  6975,
  6995,
  7015,
  7040,
  7060,
  7080,
  7105,
  7125,
  7145,
  7170,
  7190,
  7210,
  7235,
  7255,
  7275,
  7300,
  7320,
  7340,
  7360,
  7385,
  7405,
  7425,
  7450,
  7470,
  7490,
  7515,
  7535,
  7555,
  7580,
  7600,
  7620,
  7645,
  7665,
  7685,
  7710,
  7730,
  7750,
  7775,
  7795,
  7815,
  7840,
  7860,
  7880,
  7905,
  7925,
  7950,
  7970,
  7990,
  8015,
  8035,
  8055,
  8080,
  8100,
  8120,
  8145,
  8165,
  8185,
  8210,
  8230,
  8250,
  8275,
  8295,
  8320,
  8340,
  8360,
  8385,
  8405,
  8425,
  8450,
  8470,
  8490,
  8515,
  8535,
  8560,
  8580,
  8600,
  8625,
  8645,
  8665,
  8690,
  8710,
  8730,
  8755,
  8775,
  8800,
  8820,
  8840,
  8865,
  8885,
  8910,
  8930,
  8950,
  8975,
  8995,
  9015,
  9040,
  9060,
  9085,
  9105,
  9125,
  9150,
  9170,
  9195,
  9215,
  9235,
  9260,
  9280,
  9300,
  9325,
  9345,
  9370,
  9390,
  9410,
  9435,
  9455,
  9480,
  9500,
  9520,
  9545,
  9565,
  9590,
  9610,
  9635,
  9655,
  9675,
  9700,
  9720,
  9745,
  9765,
  9785,
  9810,
  9830,
  9855,
  9875,
  9895,
  9920,
  9940,
  9965,
  9985,
  10010,
  10030,
  10050,
  10075,
  10095,
  10120,
  10140,
  10165,
  10185,
  10205,
  10230,
  10250,
  10275,
  10295,
  10320,
  10340,
  10360,
  10385,
  10405,
  10430,
  10450,
  10475,
  10495,
  10515,
  10540,
  10560,
  10585,
  10605,
  10630,
  10650,
  10675,
  10695,
  10715,
  10740,
  10760,
  10785,
  10805,
  10830,
  10850,
  10875,
  10895,
  10915,
  10940,
  10960,
  10985,
  11005,
  11030,
  11050,
  11075,
  11095,
  11115,
  11140,
  11160,
  11185,
  11205,
  11225,
  11250,
  11270,
  11295,
  11315,
  11335,
  11360,
  11380,
  11405,
  11425,
  11450,
  11470,
  11490,
  11515,
  11535,
  11560,
  11580,
  11605,
  11625,
  11645,
  11670,
  11690,
  11715,
  11735,
  11755,
  11780,
  11800,
  11825,
  11845,
  11870,
  11890,
  11910,
  11935,
  11955,
  11980,
  12000,
  12025,
  12045,
  12065,
  12090,
  12110,
  12135,
  12155,
  12180,
  12200,
  12225,
  12245,
  12265,
  12290,
  12310,
  12335,
  12355,
  12380,
  12400,
  12420,
  12445,
  12465,
  12490,
  12510,
  12535,
  12555,
  12580,
  12600,
  12625,
  12645,
  12665,
  12690,
  12710,
  12735,
  12755,
  12780,
  12800,
  12825,
  12845,
  12865,
  12890,
  12910,
  12935,
  12955,
  12980,
  13000,
  13025,
  13045,
  13070,
  13090,
  13115,
  13135,
  13155,
  13180,
  13200,
  13225,
  13245,
  13270,
  13290,
  13315,
  13335,
  13360,
  13380,
  13405,
  13425,
  13450,
  13470,
  13490,
  13515,
  13535,
  13560,
  13580,
  13605,
  13625,
  13650,
  13670,
  13695,
  13715,
  13740,
  13760,
  13785,
  13805,
  13830,
  13850,
  13875,
  13895,
  13920,
  13940,
  13965,
  13985,
  14010,
  14030,
  14050,
  14075,
  14095,
  14120,
  14140,
  14165,
  14185,
  14210,
  14230,
  14255,
  14275,
  14300,
  14320,
  14345,
  14365,
  14390,
  14410,
  14435,
  14455,
  14480,
  14500,
  14525,
  14545,
  14570,
  14590,
  14615,
  14635,
  14660,
  14680,
  14705,
  14725,
  14750,
  14770,
  14795,
  14815,
  14840,
  14860,
  14885,
  14905,
  14930,
  14950,
  14975,
  14995,
  15020,
  15040,
  15065,
  15090,
  15110,
  15135,
  15155,
  15180,
  15200,
  15225,
  15245,
  15270,
  15290,
  15315,
  15335,
  15360,
  15380,
  15405,
  15425,
  15450,
  15470,
  15495,
  15515,
  15540,
  15560,
  15585,
  15610,
  15630,
  15655,
  15675,
  15700,
  15720,
  15745,
  15765,
  15790,
  15810,
  15835,
  15855,
  15880,
  15900,
  15925,
  15950,
  15970,
  15995,
  16015,
  16040,
  16060,
  16085,
  16105,
  16130,
  16150,
  16175,
  16195,
  16220,
  16245,
  16265,
  16290,
  16310,
  16335,
  16355,
  16380,
  16400,
  16425,
  16445,
  16470,
  16495,
  16515,
  16540,
  16560,
  16585,
  16605,
  16630,
  16650,
  16675,
  16700,
  16720,
  16745,
  16765,
  16790,
  16810,
  16835,
  16860,
  16880,
  16905,
  16925,
  16950,
  16970,
  16995,
  17015,
  17040,
  17065,
  17085,
  17110,
  17130,
  17155,
  17175,
  17200,
  17225,
  17245,
  17270,
  17290,
  17315,
  17335,
  17360,
  17385,
  17405,
  17430,
  17450,
  17475,
  17495,
  17520,
  17545,
  17565,
  17590,
  17610,
  17635,
  17660,
  17680,
  17705,
  17725,
  17750,
  17770,
  17795,
  17820,
  17840,
  17865,
  17885,
  17910,
  17935,
  17955,
  17980,
  18000,
  18025,
  18050,
  18070,
  18095,
  18115,
  18140,
  18165,
  18185,
  18210,
  18230,
  18255,
  18275,
  18300,
  18325,
  18345,
  18370,
  18390,
  18415,
  18440,
  18460,
  18485,
  18510,
  18530,
  18555,
  18575,
  18600,
  18625,
  18645,
  18670,
  18690,
  18715,
  18740,
  18760,
  18785,
  18805,
  18830,
  18855,
  18875,
  18900,
  18920,
  18945,
  18970,
  18990,
  19015,
  19040,
  19060,
  19085,
  19105,
  19130,
  19155,
  19175,
  19200,
  19225,
  19245,
  19270,
  19290,
  19315,
  19340,
  19360,
  19385,
  19410,
  19430,
  19455,
  19475,
  19500,
  19525,
  19545,
  19570,
  19595,
  19615,
  19640,
  19665,
  19685,
  19710,
  19730,
  19755,
  19780,
  19800,
  19825,
  19850,
  19870,
  19895,
  19920,
  19940,
  19965,
  19985,
  20010,
  20035,
  20055,
  20080,
  20105,
  20125,
  20150,
  20175,
  20195,
  20220,
  20245,
  20265,
  20290,
  20315,
  20335,
  20360,
  20380,
  20405,
  20430,
  20450,
  20475,
  20500,
  20520,
  20545,
  20570,
  20590,
  20615,
  20640,
  20660,
  20685,
  20710,
  20730,
  20755,
  20780,
  20800,
  20825,
  20850,
  20870,
  20895,
  20920,
  20940,
  20965,
  20990,
  21010,
  21035,
  21060,
  21080,
  21105,
  21130,
  21150,
  21175,
  21200,
  21220,
  21245,
  21270,
  21290,
  21315,
  21340,
  21360,
  21385,
  21410,
  21430,
  21455,
  21480,
  21505,
  21525,
  21550,
  21575,
  21595,
  21620,
  21645,
  21665,
  21690,
  21715,
  21735,
  21760,
  21785,
  21805,
  21830,
  21855,
  21880,
  21900,
  21925,
  21950,
  21970,
  21995,
  22020,
  22040,
  22065,
  22090,
  22110,
  22135,
  22160,
  22185,
  22205,
  22230,
  22255,
  22275,
  22300,
  22325,
  22345,
  22370,
  22395,
  22420,
  22440,
  22465,
  22490,
  22510,
  22535,
  22560,
  22580,
  22605,
  22630,
  22655,
  22675,
  22700,
  22725,
  22745,
  22770,
  22795,
  22815,
  22840,
  22865,
  22890,
  22910,
  22935,
  22960,
  22980,
  23005,
  23030,
  23050,
  23075,
  23100,
  23125,
  23145,
  23170,
  23195,
  23215,
  23240,
  23265,
  23290,
  23310,
  23335,
  23360,
  23380,
  23405,
  23430,
  23455,
  23475,
  23500,
  23525,
  23545,
  23570,
  23595,
  23620,
  23640,
  23665,
  23690,
  23710,
  23735,
  23760,
  23785,
  23805,
  23830,
  23855,
  23880,
  23900,
  23925,
  23950,
  23970,
  23995,
  24020,
  24045,
  24065,
  24090,
  24115,
  24140,
  24160,
  24185,
  24210,
  24235,
  24255,
  24280,
  24305,
  24325,
  24350,
  24375,
  24400,
  24420,
  24445,
  24470,
  24495,
  24515,
  24540,
  24565,
  24590,
  24610,
  24635,
  24660,
  24685,
  24705,
  24730,
  24755,
  24780,
  24800,
  24825,
  24850,
  24875,
  24895,
  24920,
  24945,
  24970,
  24990,
  25015,
  25040,
  25065,
  25085,
  25110,
  25135,
  25160,
  25180,
  25205,
  25230,
  25255,
  25275,
  25300,
  25325,
  25350,
  25370,
  25395,
  25420,
  25445,
  25470,
  25490,
  25515,
  25540,
  25565,
  25585,
  25610,
  25635,
  25660,
  25680,
  25705,
  25730,
  25755,
  25780,
  25800,
  25825,
  25850,
  25875,
  25895,
  25920,
  25945,
  25970,
  25990,
  26015,
  26040,
  26065,
  26090,
  26110,
  26135,
  26160,
  26185,
  26205,
  26230,
  26255,
  26280,
  26305,
  26325,
  26350,
  26375,
  26400,
  26425,
  26445,
  26470,
  26495,
  26520,
  26545,
  26565,
  26590,
  26615,
  26640,
  26660,
  26685,
  26710,
  26735,
  26760,
  26780,
  26805,
  26830,
  26855,
  26880,
  26900,
  26925,
  26950,
  26975,
  27000,
  27020,
  27045,
  27070,
  27095,
  27120,
  27140,
  27165,
  27190,
  27215,
  27240,
  27260,
  27285,
  27310,
  27335,
  27360,
  27385,
  27405,
  27430,
  27455,
  27480,
  27505,
  27525,
  27550,
  27575,
  27600,
  27625,
  27645,
  27670,
  27695,
  27720,
  27745,
  27770,
  27790,
  27815,
  27840,
  27865,
  27890,
  27915,
  27935,
  27960,
  27985,
  28010,
  28035,
  28055,
  28080,
  28105,
  28130,
  28155,
  28180,
  28200,
  28225,
  28250,
  28275,
  28300,
  28325,
  28345,
  28370,
  28395,
  28420,
  28445,
  28470,
  28490,
  28515,
  28540,
  28565,
  28590,
  28615,
  28635,
  28660,
  28685,
  28710,
  28735,
  28760,
  28785,
  28805,
  28830,
  28855,
  28880,
  28905,
  28930,
  28950,
  28975,
  29000,
  29025,
  29050,
  29075,
  29100,
  29120,
  29145,
  29170,
  29195,
  29220,
  29245,
  29265,
  29290,
  29315,
  29340,
  29365,
  29390,
  29415,
  29435,
  29460,
  29485,
  29510,
  29535,
  29560,
  29585,
  29610,
  29630,
  29655,
  29680,
  29705,
  29730,
  29755,
  29780,
  29800,
  29825,
  29850,
  29875,
  29900,
  29925,
  29950,
  29975,
  29995,
  30020,
  30045,
  30070,
  30095,
  30120,
  30145,
  30170,
  30190,
  30215,
  30240,
  30265,
  30290,
  30315,
  30340,
  30365,
  30385,
  30410,
  30435,
  30460,
  30485,
  30510,
  30535,
  30560,
  30585,
  30605,
  30630,
  30655,
  30680,
  30705,
  30730,
  30755,
  30780,
  30805,
  30825,
  30850,
  30875,
  30900,
  30925,
  30950,
  30975,
  31000,
  31025,
  31045,
  31070,
  31095,
  31120,
  31145,
  31170,
  31195,
  31220,
  31245,
  31270,
  31290,
  31315,
  31340,
  31365,
  31390,
  31415,
  31440,
  31465,
  31490,
  31515,
  31535,
  31560,
  31585,
  31610,
  31635,
  31660,
  31685,
  31710,
  31735,
  31760,
  31785,
  31810,
  31830,
  31855,
  31880,
  31905,
  31930,
  31955,
  31980,
  32005,
  32030,
  32055,
  32080,
  32105,
  32125,
  32150,
  32175,
  32200,
  32225,
  32250,
  32275,
  32300,
  32325,
  32350,
  32375,
  32400,
  32425,
  32445,
  32470,
  32495,
  32520,
  32545,
  32570,
  32595,
  32620,
  32645,
  32670,
  32695,
  32720,
  32745,
  32770,
  32795,
  32815,
  32840,
  32865,
  32890,
  32915,
  32940,
  32965,
  32990,
  33015,
  33040,
  33065,
  33090,
  33115,
  33140,
  33165,
  33190,
  33215,
  33240,
  33260,
  33285,
  33310,
  33335,
  33360,
  33385,
  33410,
  33435,
  33460,
  33485,
  33510,
  33535,
  33560,
  33585,
  33610,
  33635,
  33660,
  33685,
  33710,
  33735,
  33760,
  33785,
  33805,
  33830,
  33855,
  33880,
  33905,
  33930,
  33955,
  33980,
  34005,
  34030,
  34055,
  34080,
  34105,
  34130,
  34155,
  34180,
  34205,
  34230,
  34255,
  34280,
  34305,
  34330,
  34355,
  34380,
  34405,
  34430,
  34455,
  34480,
  34505,
  34530,
  34555,
  34580,
  34605,
  34625,
  34650,
  34675,
  34700,
  34725,
  34750,
  34775,
  34800,
  34825,
  34850,
  34875,
  34900,
  34925,
  34950,
  34975,
  35000,
  35025,
  35050,
  35075,
  35100,
  35125,
  35150,
  35175,
  35200,
  35225,
  35250,
  35275,
  35300,
  35325,
  35350,
  35375,
  35400,
  35425,
  35450,
  35475,
  35500,
  35525,
  35550,
  35575,
  35600,
  35625,
  35650,
  35675,
  35700,
  35725,
  35750,
  35775,
  35800,
  35825,
  35850,
  35875,
  35900,
  35925,
  35950,
  35975,
  36000,
  36025,
  36050,
  36075,
  36100,
  36125,
  36150,
  36175,
  36200,
  36225,
  36250,
  36275,
  36300,
  36325,
  36350,
  36375,
  36400,
  36430,
  36455,
  36480,
  36505,
  36530,
  36555,
  36580,
  36605,
  36630,
  36655,
  36680,
  36705,
  36730,
  36755,
  36780,
  36805,
  36830,
  36855,
  36880,
  36905,
  36930,
  36955,
  36980,
  37005,
  37030,
  37055,
  37080,
  37105,
  37130,
  37155,
  37180,
  37205,
  37230,
  37260,
  37285,
  37310,
  37335,
  37360,
  37385,
  37410,
  37435,
  37460,
  37485,
  37510,
  37535,
  37560,
  37585,
  37610,
  37635,
  37660,
  37685,
  37710,
  37735,
  37760,
  37785,
  37815,
  37840,
  37865,
  37890,
  37915,
  37940,
  37965,
  37990,
  38015,
  38040,
  38065,
  38090,
  38115,
  38140,
  38165,
  38190,
  38215,
  38240,
  38270,
  38295,
  38320,
  38345,
  38370,
  38395,
  38420,
  38445,
  38470,
  38495,
  38520,
  38545,
  38570,
  38595,
  38620,
  38650,
  38675,
  38700,
  38725,
  38750,
  38775,
  38800,
  38825,
  38850,
  38875,
  38900,
  38925,
  38950,
  38980,
  39005,
  39030,
  39055,
  39080,
  39105,
  39130,
  39155,
  39180,
  39205,
  39230,
  39255,
  39285,
  39310,
  39335,
  39360,
  39385,
  39410,
  39435,
  39460,
  39485,
  39510,
  39535,
  39565,
  39590,
  39615,
  39640,
  39665,
  39690,
  39720,
  39745,
  39770,
  39795,
  39820,
  39850,
  39875,
  39900,
  39925,
  39950,
  39975,
  40005,
  40030,
  40055,
  40080,
  40105,
  40135,
  40160,
  40185,
  40210,
  40235,
  40265,
  40290,
  40315,
  40340,
  40365,
  40390,
  40420,
  40445,
  40470,
  40495,
  40520,
  40550,
  40575,
  40600,
  40625,
  40650,
  40680,
  40705,
  40730,
  40755,
  40780,
  40810,
  40835,
  40860,
  40885,
  40915,
  40940,
  40965,
  40990,
  41015,
  41045,
  41070,
  41095,
  41120,
  41145,
  41175,
  41200,
  41225,
  41250,
  41275,
  41305,
  41330,
  41355,
  41380,
  41410,
  41435,
  41460,
  41485,
  41510,
  41540,
  41565,
  41590,
  41615,
  41645,
  41670,
  41695,
  41720,
  41750,
  41775,
  41800,
  41825,
  41850,
  41880,
  41905,
  41930,
  41955,
  41985,
  42010,
  42035,
  42060,
  42090,
  42115,
  42140,
  42165,
  42195,
  42220,
  42245,
  42270,
  42295,
  42325,
  42350,
  42375,
  42400,
  42430,
  42455,
  42480,
  42505,
  42535,
  42560,
  42585,
  42610,
  42640,
  42665,
  42690,
  42715,
  42745,
  42770,
  42795,
  42820,
  42850,
  42875,
  42900,
  42930,
  42955,
  42980,
  43005,
  43035,
  43060,
  43085,
  43110,
  43140,
  43165,
  43190,
  43215,
  43245,
  43270,
  43295,
  43320,
  43350,
  43375,
  43400,
  43430,
  43455,
  43480,
  43505,
  43535,
  43560,
  43585,
  43615,
  43640,
  43665,
  43690,
  43720,
  43745,
  43770,
  43795,
  43825,
  43850,
  43875,
  43905,
  43930,
  43955,
  43980,
  44010,
  44035,
  44060,
  44090,
  44115,
  44140,
  44165,
  44195,
  44220,
  44245,
  44275,
  44300,
  44325,
  44355,
  44380,
  44405,
  44430,
  44460,
  44485,
  44510,
  44540,
  44565,
  44590,
  44620,
  44645,
  44670,
  44695,
  44725,
  44750,
  44775,
  44805,
  44830,
  44855,
  44885,
  44910,
  44935,
  44960,
  44990,
  45015,
  45040,
  45070,
  45095,
  45120,
  45150,
  45175,
  45200,
  45230,
  45255,
  45280,
  45310,
  45335,
  45360,
  45390,
  45415,
  45440,
  45470,
  45495,
  45520,
  45545,
  45575,
  45600,
  45625,
  45655,
  45680,
  45705,
  45735,
  45760,
  45785,
  45815,
  45840,
  45865,
  45895,
  45920,
  45945,
  45975,
  46000,
  46025,
  46055,
  46080,
  46105,
  46135,
  46160,
  46190,
  46215,
  46240,
  46270,
  46295,
  46320,
  46350,
  46375,
  46400,
  46430,
  46455,
  46480,
  46510,
  46535,
  46560,
  46590,
  46615,
  46640,
  46670,
  46695,
  46720,
  46750,
  46775,
  46805,
  46830,
  46855,
  46885,
  46910,
  46935,
  46965,
  46990,
  47015,
  47045,
  47070,
  47100,
  47125,
  47150,
  47180,
  47205,
  47230,
  47260,
  47285,
  47310,
  47340,
  47365,
  47395,
  47420,
  47445,
  47475,
  47500,
  47525,
  47550,
  47580,
  47605,
  47630,
  47660,
  47685,
  47710,
  47735,
  47765,
  47790,
  47815,
  47845,
  47870,
  47895,
  47920,
  47950,
  47975,
  48000,
  48030,
  48055,
  48080,
  48105,
  48135,
  48160,
  48185,
  48215,
  48240,
  48265,
  48290,
  48320,
  48345,
  48370,
  48400,
  48425,
  48450,
  48480,
  48505,
  48530,
  48555,
  48585,
  48610,
  48635,
  48665,
  48690,
  48715,
  48745,
  48770,
  48795,
  48820,
  48850,
  48875,
  48900,
  48930,
  48955,
  48980,
  49010,
  49035,
  49060,
  49090,
  49115,
  49140,
  49170,
  49195,
  49220,
  49245,
  49275,
  49300,
  49325,
  49355,
  49380,
  49405,
  49435,
  49460,
  49485,
  49515,
  49540,
  49565,
  49595,
  49620,
  49645,
  49675,
  49700,
  49725,
  49755,
  49780,
  49805,
  49835,
  49860,
  49885,
  49915,
  49940,
  49965,
  49995,
  50020,
  50045,
  50075,
  50100,
  50125,
  50155,
  50180,
  50205,
  50235,
  50260,
  50285,
  50315,
  50340,
  50365,
  50395,
  50420,
  50445,
  50475,
  50500,
  50525,
  50555,
  50580,
  50605,
  50635,
  50660,
  50685,
  50715,
  50740,
  50765,
  50795,
  50820,
  50845,
  50875,
  50900,
  50925,
  50955,
  50980,
  51010,
  51035,
  51060,
  51090,
  51115,
  51140,
  51170,
  51195,
  51220,
  51250,
  51275,
  51300,
  51330,
  51355,
  51385,
  51410,
  51435,
  51465,
  51490,
  51515,
  51545,
  51570,
  51595,
  51625,
  51650,
  51680,
  51705,
  51730,
  51760,
  51785,
  51810,
  51840,
  51865,
  51895,
  51920,
  51945,
  51975,
  52000,
  52025,
  52055,
  52080,
  52110,
  52135,
  52160,
  52190,
  52215,
  52240,
  52270,
  52295,
  52325,
  52350,
  52375,
  52405,
  52430,
  52455,
  52485,
  52510,
  52540,
  52565,
  52590,
  52620,
  52645,
  52675,
  52700,
  52725,
  52755,
  52780,
  52805,
  52835,
  52860,
  52890,
  52915,
  52940,
  52970,
  52995,
  53025,
  53050,
  53075,
  53105,
  53130,
  53160,
  53185,
  53210,
  53240,
  53265,
  53295,
  53320,
  53345,
  53375,
  53400,
  53430,
  53455,
  53480,
  53510,
  53535,
  53565,
  53590,
  53620,
  53645,
  53670,
  53700,
  53725,
  53755,
  53780,
  53805,
  53835,
  53860,
  53890,
  53915,
  53940,
  53970,
  53995,
  54025,
  54050,
  54080,
  54105,
  54130,
  54160,
  54185,
  54215,
  54240,
  54265,
  54295,
  54320,
  54350,
  54375,
  54405,
  54430,
  54455,
  54485,
  54510,
  54540,
  54565,
  54595,
  54620,
  54645,
  54675,
  54700,
  54730,
  54755,
  54785,
  54810,
  54835,
  54865,
  54890,
  54920,
  54945,
  54975,
  55000,
  55030,
  55055,
  55080,
  55110,
  55135,
  55165,
  55190,
  55220,
  55245,
  55275,
  55300,
  55325,
  55355,
  55380,
  55410,
  55435,
  55465,
  55490,
  55520,
  55545,
  55570,
  55600,
  55625,
  55655,
  55680,
  55710,
  55735,
  55765,
  55790,
  55815,
  55845,
  55870,
  55900,
  55925,
  55955,
  55980,
  56010,
  56035,
  56065,
  56090,
  56120,
  56145,
  56170,
  56200,
  56225,
  56255,
  56280,
  56310,
  56335,
  56365,
  56390,
  56420,
  56445,
  56475,
  56500,
  56530,
  56555,
  56580,
  56610,
  56635,
  56665,
  56690,
  56720,
  56745,
  56775,
  56800,
  56830,
  56855,
  56885,
  56910,
  56940,
  56965,
  56995,
  57020,
  57050,
  57075,
  57105,
  57130,
  57155,
  57185,
  57210,
  57240,
  57265,
  57295,
  57320,
  57350,
  57375,
  57405,
  57430,
  57460,
  57485,
  57515,
  57540,
  57570,
  57595,
  57625,
  57650,
  57680,
  57705,
  57735,
  57760,
  57790,
  57815,
  57845,
  57870,
  57900,
  57925,
  57955,
  57980,
  58010,
  58035,
  58065,
  58090,
  58120,
  58145,
  58175,
  58200,
  58230,
  58255,
  58285,
  58310,
  58340,
  58365,
  58395,
  58420,
  58450,
  58475,
  58505,
  58530,
  58560,
  58585,
  58615,
  58640,
  58670,
  58695,
  58725,
  58750,
  58780,
  58805,
  58835,
  58865,
  58890,
  58920,
  58945,
  58975,
  59000,
  59030,
  59055,
  59085,
  59110,
  59140,
  59165,
  59195,
  59220,
  59250,
  59275,
  59305,
  59330,
  59360,
  59385,
  59415,
  59445,
  59470,
  59500,
  59525,
  59555,
  59580,
  59610,
  59635,
  59665,
  59690,
  59720,
  59745,
  59775,
  59800,
  59830,
  59860,
  59885,
  59915,
  59940,
  59970,
  59995,
  60025,
  60050,
  60080,
  60105,
  60135,
  60165,
  60190,
  60220,
  60245,
  60275,
  60300,
  60330,
  60355,
  60385,
  60410,
  60440,
  60470,
  60495,
  60525,
  60550,
  60580,
  60605,
  60635,
  60660,
  60690,
  60720,
  60745,
  60775,
  60800,
  60830,
  60855,
  60885,
  60910,
  60940,
  60970,
  60995,
  61025,
  61050,
  61080,
  61105,
  61135,
  61165,
  61190,
  61220,
  61245,
  61275,
  61300,
  61330,
  61360,
  61385,
  61415,
  61440,
  61470,
  61495,
  61525,
  61555,
  61580,
  61610,
  61635,
  61665,
  61690,
  61720,
  61750,
  61775,
  61805,
  61830,
  61860,
  61885,
  61915,
  61945,
  61970,
  62000,
  62025,
  62055,
  62085,
  62110,
  62140,
  62165,
  62195,
  62220,
  62250,
  62280,
  62305,
  62335,
  62360,
  62390,
  62420,
  62445,
  62475,
  62500,
  62530,
  62560,
  62585,
  62615,
  62640,
  62670,
  62700,
  62725,
  62755,
  62780,
  62810,
  62840,
  62865,
  62895,
  62920,
  62950,
  62980,
  63005,
  63035,
  63060,
  63090,
  63120,
  63145,
  63175,
  63200,
  63230,
  63260,
  63285,
  63315,
  63340,
  63370,
  63400,
  63425,
  63455,
  63480,
  63510,
  63540,
  63565,
  63595,
  63625,
  63650,
  63680,
  63705,
  63735,
  63765,
  63790,
  63820,
  63850,
  63875,
  63905,
  63930,
  63960,
  63990,
  64015,
  64045,
  64070,
  64100,
  64130,
  64155,
  64185,
  64215,
  64240,
  64270,
  64300,
  64325,
  64355,
  64380,
  64410,
  64440,
  64465,
  64495,
  64525,
  64550,
  64580,
  64605,
  64635,
  64665,
  64690,
  64720,
  64750,
  64775,
  64805,
  64835,
  64860,
  64890,
  64920,
  64945,
  64975,
  65000,
  65030,
  65060,
  65085,
  65115,
  65145,
  65170,
  65200,
  65230,
  65255,
  65285,
  65315,
  65340,
  65370,
  65400,
  65425,
  65455,
  65480,
  65510,
  65540,
  65565,
  65595,
  65625,
  65650,
  65680,
  65710,
  65735,
  65765,
  65795,
  65820,
  65850,
  65880,
  65905,
  65935,
  65965,
  65990,
  66020,
  66050,
  66075,
  66105,
  66135,
  66160,
  66190,
  66220,
  66245,
  66275,
  66305,
  66330,
  66360,
  66390,
  66415,
  66445,
  66475,
  66500,
  66530,
  66560,
  66585,
  66615,
  66645,
  66675,
  66705,
  66730,
  66760,
  66790,
  66820,
  66850,
  66875,
  66905,
  66935,
  66965,
  66995,
  67020,
  67050,
  67080,
  67110,
  67140,
  67170,
  67195,
  67225,
  67255,
  67285,
  67315,
  67345,
  67370,
  67400,
  67430,
  67460,
  67490,
  67520,
  67545,
  67575,
  67605,
  67635,
  67665,
  67695,
  67720,
  67750,
  67780,
  67810,
  67840,
  67870,
  67895,
  67925,
  67955,
  67985,
  68015,
  68045,
  68070,
  68100,
  68130,
  68160,
  68190,
  68220,
  68245,
  68275,
  68305,
  68335,
  68365,
  68395,
  68425,
  68450,
  68480,
  68510,
  68540,
  68570,
  68600,
  68630,
  68655,
  68685,
  68715,
  68745,
  68775,
  68805,
  68835,
  68860,
  68890,
  68920,
  68950,
  68980,
  69010,
  69040,
  69065,
  69095,
  69125,
  69155,
  69185,
  69215,
  69245,
  69275,
  69300,
  69330,
  69360,
  69390,
  69420,
  69450,
  69480,
  69510,
  69535,
  69565,
  69595,
  69625,
  69655,
  69685,
  69715,
  69745,
  69770,
  69800,
  69830,
  69860,
  69890,
  69920,
  69950,
  69980,
  70005,
  70035,
  70065,
  70095,
  70125,
  70155,
  70185,
  70215,
  70245,
  70270,
  70300,
  70330,
  70360,
  70390,
  70420,
  70450,
  70480,
  70510,
  70540,
  70565,
  70595,
  70625,
  70655,
  70685,
  70715,
  70745,
  70775,
  70805,
  70835,
  70860,
  70890,
  70920,
  70950,
  70980,
  71010,
  71040,
  71070,
  71100,
  71130,
  71160,
  71190,
  71215,
  71245,
  71275,
  71305,
  71335,
  71365,
  71395,
  71425,
  71455,
  71485,
  71515,
  71545,
  71570,
  71600,
  71630,
  71660,
  71690,
  71720,
  71750,
  71780,
  71810,
  71840,
  71870,
  71900,
  71930,
  71955,
  71985,
  72015,
  72045,
  72075,
  72105,
  72135,
  72165,
  72195,
  72225,
  72255,
  72285,
  72315,
  72345,
  72375,
  72405,
  72430,
  72460,
  72490,
  72520,
  72550,
  72580,
  72610,
  72640,
  72670,
  72700,
  72730,
  72760,
  72790,
  72820,
  72850,
  72880,
  72910,
  72940,
  72970,
  72995,
  73025,
  73055,
  73085,
  73115,
  73145,
  73175,
  73205,
  73235,
  73265,
  73295,
  73325,
  73355,
  73385,
  73415,
  73445,
  73475,
  73505,
  73535,
  73565,
  73595,
  73625,
  73655,
  73685,
  73715,
  73745,
  73775,
  73800,
  73830,
  73860,
  73890,
  73920,
  73950,
  73980,
  74010,
  74040,
  74070,
  74100,
  74130,
  74160,
  74190,
  74220,
  74250,
  74280,
  74310,
  74340,
  74370,
  74400,
  74430,
  74460,
  74490,
  74520,
  74550,
  74580,
  74610,
  74640,
  74670,
  74700,
  74730,
  74760,
  74790,
  74820,
  74850,
  74880,
  74910,
  74940,
  74970,
  75000,
  75030,
  75060,
  75090,
  75120,
  75150,
  75180,
  75210,
  75240,
  75270,
  75300,
  75330,
  75360,
  75390,
  75420,
  75450
 ],
 "combat": {
  "version": 1,
  "damage": {
   "defense_constant": 100,
   "level_gap_per_level": 0.02,
   "level_gap_min": 0.6,
   "level_gap_max": 1.4,
   "crit_chance_base": 0.05,
   "crit_multiplier": 1.5,
   "variance": 0,
   "min_damage": 1
  },
  "spirit": {
   "regen_per_s": 2,
   "gain_on_hit": 3,
   "gain_on_hit_taken": 2,
   "gain_on_parry": 15,
   "gain_on_perfect_dodge": 10
  },
  "dodge": {
   "perfect_window_s": 0.15,
   "chain_limit": 3,
   "chain_cooldown_s": 1.2
  },
  "guard": {
   "guard_meter_max": 100,
   "guard_meter_regen_per_s": 25,
   "guard_break_stagger_s": 1.0
  },
  "poise": {
   "player_poise": 60,
   "poise_regen_delay_s": 2,
   "stagger_s": 0.8,
   "stagger_immunity_s": 2.5
  },
  "crowd_control": {
   "max_hard_cc_s": 2,
   "diminishing_window_s": 10,
   "diminishing_multipliers": [
    1,
    0.5,
    0.25
   ],
   "immunity_s": 5
  },
  "readability": {
   "min_telegraph_s": 0.4,
   "min_unblockable_telegraph_s": 0.7,
   "max_attackers_per_player": 2,
   "max_knockback_studs": 20
  },
  "lock_on": {
   "range_studs": 60,
   "break_range_studs": 80
  },
  "feedback": {
   "damage_numbers_default": true,
   "hitstop_s": 0.05,
   "camera_shake_default": 0.6
  },
  "movement": {
   "walk_speed": 16,
   "sprint_speed": 24,
   "guard_walk_speed": 8,
   "jump_power": 50
  },
  "recovery": {
   "out_of_combat_delay_s": 6,
   "regen_fraction_per_s": 0.04,
   "input_buffer_s": 0.25
  }
 },
 "difficulty": {
  "version": 1,
  "default_mode": "normal",
  "switchable_anytime": true,
  "modes": [
   {
    "id": "story",
    "name": "Story",
    "description": "For enjoying the story. Enemies hit softer, wind up longer, and only one attacks at a time.",
    "enemy_damage_mult": 0.5,
    "enemy_hp_mult": 0.7,
    "telegraph_time_mult": 1.3,
    "parry_window_mult": 1.5,
    "dodge_window_mult": 1.5,
    "max_attackers_per_player": 1,
    "optional": false
   },
   {
    "id": "normal",
    "name": "Normal",
    "description": "The intended balance: challenging but fair.",
    "enemy_damage_mult": 1,
    "enemy_hp_mult": 1,
    "telegraph_time_mult": 1,
    "parry_window_mult": 1,
    "dodge_window_mult": 1,
    "max_attackers_per_player": 2,
    "optional": false
   },
   {
    "id": "hard",
    "name": "Hard",
    "description": "Enemies hit harder, last longer and press you more often.",
    "enemy_damage_mult": 1.4,
    "enemy_hp_mult": 1.3,
    "telegraph_time_mult": 0.9,
    "parry_window_mult": 0.85,
    "dodge_window_mult": 0.9,
    "max_attackers_per_player": 3,
    "optional": false
   },
   {
    "id": "challenge",
    "name": "Challenge",
    "description": "Opt-in mastery mode. Never required for anything.",
    "enemy_damage_mult": 1.8,
    "enemy_hp_mult": 1.6,
    "telegraph_time_mult": 0.85,
    "parry_window_mult": 0.75,
    "dodge_window_mult": 0.8,
    "max_attackers_per_player": 3,
    "optional": true,
    "reward_note": "Cosmetic titles only. No extra power."
   }
  ],
  "boss_assist": {
   "always_optional": true,
   "offer_after_failures": {
    "tip": 2,
    "suggested_level": 3,
    "training_challenge": 4,
    "support_buff": 5
   },
   "support_buff_status_id": "sts_resolve"
  },
  "death": {
   "lose_progress": false,
   "lose_items": false,
   "respawn_at": "last_checkpoint",
   "respawn_currency_cost": 0
  }
 },
 "inputActions": {
  "version": 1,
  "actions": [
   {
    "id": "move",
    "label": "Move",
    "context": "gameplay",
    "kind": "axis2d",
    "bindings": {
     "keyboard_mouse": [
      "Composite:WASD"
     ],
     "gamepad": [
      "Thumbstick1"
     ],
     "touch": [
      "TouchStickMove"
     ]
    },
    "remappable": true
   },
   {
    "id": "camera",
    "label": "Camera",
    "context": "gameplay",
    "kind": "axis2d",
    "bindings": {
     "keyboard_mouse": [
      "MouseDelta",
      "Composite:Arrows"
     ],
     "gamepad": [
      "Thumbstick2"
     ],
     "touch": [
      "TouchCameraSwipe"
     ]
    },
    "remappable": false
   },
   {
    "id": "light_attack",
    "label": "Light Attack",
    "context": "gameplay",
    "kind": "button",
    "press": "tap",
    "bindings": {
     "keyboard_mouse": [
      "MouseButton1"
     ],
     "gamepad": [
      "ButtonX"
     ],
     "touch": [
      "TouchButtonAttack"
     ]
    },
    "remappable": true
   },
   {
    "id": "heavy_attack",
    "label": "Heavy Attack",
    "context": "gameplay",
    "kind": "button",
    "press": "tap_or_hold",
    "bindings": {
     "keyboard_mouse": [
      "MouseButton2"
     ],
     "gamepad": [
      "ButtonY"
     ],
     "touch": [
      "TouchButtonHeavy"
     ]
    },
    "remappable": true
   },
   {
    "id": "guard",
    "label": "Guard / Parry",
    "context": "gameplay",
    "kind": "button",
    "press": "hold",
    "bindings": {
     "keyboard_mouse": [
      "C"
     ],
     "gamepad": [
      "ButtonL1"
     ],
     "touch": [
      "TouchButtonGuard"
     ]
    },
    "remappable": true
   },
   {
    "id": "jump",
    "label": "Jump",
    "context": "gameplay",
    "kind": "button",
    "press": "tap",
    "bindings": {
     "keyboard_mouse": [
      "Space"
     ],
     "gamepad": [
      "ButtonA"
     ],
     "touch": [
      "TouchButtonJump"
     ]
    },
    "remappable": true
   },
   {
    "id": "dodge_sprint",
    "label": "Dodge (tap) / Sprint (hold)",
    "context": "gameplay",
    "kind": "button",
    "press": "tap_or_hold",
    "bindings": {
     "keyboard_mouse": [
      "LeftShift"
     ],
     "gamepad": [
      "ButtonB"
     ],
     "touch": [
      "TouchButtonDodge"
     ]
    },
    "remappable": true
   },
   {
    "id": "ability_1",
    "label": "Weapon Special",
    "context": "gameplay",
    "kind": "button",
    "press": "tap",
    "bindings": {
     "keyboard_mouse": [
      "Q"
     ],
     "gamepad": [
      "ButtonR1"
     ],
     "touch": [
      "TouchButtonAbility1"
     ]
    },
    "remappable": true
   },
   {
    "id": "ability_2",
    "label": "Ability 2",
    "context": "gameplay",
    "kind": "button",
    "press": "tap",
    "bindings": {
     "keyboard_mouse": [
      "E"
     ],
     "gamepad": [
      "ButtonR2"
     ],
     "touch": [
      "TouchButtonAbility2"
     ]
    },
    "remappable": true
   },
   {
    "id": "ability_3",
    "label": "Ability 3",
    "context": "gameplay",
    "kind": "button",
    "press": "tap",
    "bindings": {
     "keyboard_mouse": [
      "R"
     ],
     "gamepad": [
      "ButtonL2"
     ],
     "touch": [
      "TouchButtonAbility3"
     ]
    },
    "remappable": true
   },
   {
    "id": "ultimate",
    "label": "Ultimate",
    "context": "gameplay",
    "kind": "button",
    "press": "tap",
    "bindings": {
     "keyboard_mouse": [
      "F"
     ],
     "gamepad": [
      "DPadUp"
     ],
     "touch": [
      "TouchButtonUltimate"
     ]
    },
    "remappable": true
   },
   {
    "id": "lock_on",
    "label": "Lock On",
    "context": "gameplay",
    "kind": "button",
    "press": "tap",
    "bindings": {
     "keyboard_mouse": [
      "Tab"
     ],
     "gamepad": [
      "ButtonR3"
     ],
     "touch": [
      "TouchButtonLockOn"
     ]
    },
    "remappable": true
   },
   {
    "id": "interact",
    "label": "Interact",
    "context": "gameplay",
    "kind": "button",
    "press": "tap",
    "bindings": {
     "keyboard_mouse": [
      "G"
     ],
     "gamepad": [
      "DPadDown"
     ],
     "touch": [
      "TouchButtonInteract"
     ]
    },
    "remappable": true
   },
   {
    "id": "pause",
    "label": "Pause",
    "context": "gameplay",
    "kind": "button",
    "press": "tap",
    "bindings": {
     "keyboard_mouse": [
      "Escape"
     ],
     "gamepad": [
      "ButtonStart"
     ],
     "touch": [
      "TouchButtonPause"
     ]
    },
    "remappable": false,
    "platform_overrides": {
     "roblox": {
      "keyboard_mouse": [
       "P"
      ],
      "gamepad": [
       "ButtonSelect"
      ]
     }
    }
   },
   {
    "id": "menu_navigate",
    "label": "Navigate",
    "context": "menu",
    "kind": "axis2d",
    "bindings": {
     "keyboard_mouse": [
      "Composite:Arrows",
      "Composite:WASD"
     ],
     "gamepad": [
      "Composite:DPad",
      "Thumbstick1"
     ],
     "touch": [
      "TouchTap"
     ]
    },
    "remappable": false
   },
   {
    "id": "menu_confirm",
    "label": "Confirm",
    "context": "menu",
    "kind": "button",
    "press": "tap",
    "bindings": {
     "keyboard_mouse": [
      "Return",
      "Space"
     ],
     "gamepad": [
      "ButtonA"
     ],
     "touch": [
      "TouchTap"
     ]
    },
    "remappable": false
   },
   {
    "id": "menu_back",
    "label": "Back",
    "context": "menu",
    "kind": "button",
    "press": "tap",
    "bindings": {
     "keyboard_mouse": [
      "Escape",
      "Backspace"
     ],
     "gamepad": [
      "ButtonB"
     ],
     "touch": [
      "TouchButtonBack"
     ]
    },
    "remappable": false,
    "platform_overrides": {
     "roblox": {
      "keyboard_mouse": [
       "Backspace",
       "P"
      ],
      "gamepad": [
       "ButtonB",
       "ButtonSelect"
      ]
     }
    }
   },
   {
    "id": "menu_tab_next",
    "label": "Next Tab",
    "context": "menu",
    "kind": "button",
    "press": "tap",
    "bindings": {
     "keyboard_mouse": [
      "E"
     ],
     "gamepad": [
      "ButtonR1"
     ],
     "touch": [
      "TouchTap"
     ]
    },
    "remappable": false
   },
   {
    "id": "menu_tab_prev",
    "label": "Previous Tab",
    "context": "menu",
    "kind": "button",
    "press": "tap",
    "bindings": {
     "keyboard_mouse": [
      "Q"
     ],
     "gamepad": [
      "ButtonL1"
     ],
     "touch": [
      "TouchTap"
     ]
    },
    "remappable": false
   }
  ],
  "presets": [
   {
    "id": "right_click_guard",
    "label": "Right-click guards",
    "description": "Right mouse button guards and parries; heavy attack moves to C.",
    "overrides": [
     {
      "action_id": "guard",
      "device": "keyboard_mouse",
      "bindings": [
       "MouseButton2"
      ]
     },
     {
      "action_id": "heavy_attack",
      "device": "keyboard_mouse",
      "bindings": [
       "C"
      ]
     }
    ]
   }
  ],
  "platform_reserved": {
   "roblox": [
    "Escape",
    "ButtonStart",
    "F9",
    "F11"
   ],
   "pc": []
  },
  "gamepad": {
   "sensitivity_default": 1,
   "sensitivity_min": 0.2,
   "sensitivity_max": 3,
   "vibration_default": true
  },
  "touch": {
   "ui_scale_default": 1,
   "ui_scale_min": 0.75,
   "ui_scale_max": 1.5,
   "layouts": [
    "standard",
    "one_handed_left",
    "one_handed_right"
   ]
  }
 },
 "settings": {
  "version": 1,
  "tabs": [
   {
    "id": "gameplay",
    "label": "Gameplay"
   },
   {
    "id": "graphics",
    "label": "Graphics"
   },
   {
    "id": "controls",
    "label": "Controls"
   },
   {
    "id": "audio",
    "label": "Audio"
   },
   {
    "id": "accessibility",
    "label": "Accessibility"
   },
   {
    "id": "language",
    "label": "Language"
   }
  ],
  "settings": [
   {
    "id": "difficulty",
    "tab": "gameplay",
    "label": "Difficulty",
    "kind": "choice",
    "default": "normal",
    "options": [
     {
      "value": "story",
      "label": "Story"
     },
     {
      "value": "normal",
      "label": "Normal"
     },
     {
      "value": "hard",
      "label": "Hard"
     },
     {
      "value": "challenge",
      "label": "Challenge"
     }
    ],
    "platforms": [
     "roblox",
     "pc"
    ],
    "help": "Change any time. Story mode: softer hits and longer enemy wind-ups."
   },
   {
    "id": "damage_numbers",
    "tab": "gameplay",
    "label": "Damage numbers",
    "kind": "toggle",
    "default": true,
    "platforms": [
     "roblox",
     "pc"
    ]
   },
   {
    "id": "effects_quality",
    "tab": "graphics",
    "label": "Graphics quality",
    "kind": "choice",
    "default": "auto",
    "options": [
     {
      "value": "auto",
      "label": "Auto"
     },
     {
      "value": "low",
      "label": "Low"
     },
     {
      "value": "medium",
      "label": "Medium"
     },
     {
      "value": "high",
      "label": "High"
     },
     {
      "value": "ultra",
      "label": "Ultra"
     }
    ],
    "platforms": [
     "roblox",
     "pc"
    ],
    "help": "Lower it if the game runs slowly. Auto picks a level for your device."
   },
   {
    "id": "camera_sensitivity",
    "tab": "controls",
    "label": "Camera sensitivity",
    "kind": "slider",
    "default": 1,
    "min": 0.2,
    "max": 3,
    "step": 0.1,
    "platforms": [
     "roblox",
     "pc"
    ]
   },
   {
    "id": "invert_camera_y",
    "tab": "controls",
    "label": "Invert camera Y",
    "kind": "toggle",
    "default": false,
    "platforms": [
     "roblox",
     "pc"
    ]
   },
   {
    "id": "gamepad_sensitivity",
    "tab": "controls",
    "label": "Gamepad sensitivity",
    "kind": "slider",
    "default": 1,
    "min": 0.2,
    "max": 3,
    "step": 0.1,
    "platforms": [
     "roblox",
     "pc"
    ]
   },
   {
    "id": "vibration",
    "tab": "controls",
    "label": "Vibration",
    "kind": "toggle",
    "default": true,
    "platforms": [
     "roblox",
     "pc"
    ]
   },
   {
    "id": "right_click",
    "tab": "controls",
    "label": "Right mouse button",
    "kind": "choice",
    "default": "heavy",
    "options": [
     {
      "value": "heavy",
      "label": "Heavy attack"
     },
     {
      "value": "guard",
      "label": "Guard / parry"
     }
    ],
    "platforms": [
     "roblox",
     "pc"
    ],
    "help": "Guard moves to C when right-click is heavy attack, and heavy moves to C otherwise."
   },
   {
    "id": "touch_layout",
    "tab": "controls",
    "label": "Touch layout",
    "kind": "choice",
    "default": "standard",
    "options": [
     {
      "value": "standard",
      "label": "Standard"
     },
     {
      "value": "one_handed_left",
      "label": "One-handed (left)"
     },
     {
      "value": "one_handed_right",
      "label": "One-handed (right)"
     }
    ],
    "platforms": [
     "roblox",
     "pc"
    ]
   },
   {
    "id": "touch_ui_scale",
    "tab": "controls",
    "label": "Touch button size",
    "kind": "slider",
    "default": 1,
    "min": 0.75,
    "max": 1.5,
    "step": 0.05,
    "platforms": [
     "roblox",
     "pc"
    ]
   },
   {
    "id": "master_volume",
    "tab": "audio",
    "label": "Master volume",
    "kind": "slider",
    "default": 1,
    "min": 0,
    "max": 1,
    "step": 0.1,
    "platforms": [
     "roblox",
     "pc"
    ]
   },
   {
    "id": "music_volume",
    "tab": "audio",
    "label": "Music volume",
    "kind": "slider",
    "default": 0.8,
    "min": 0,
    "max": 1,
    "step": 0.1,
    "platforms": [
     "roblox",
     "pc"
    ]
   },
   {
    "id": "sfx_volume",
    "tab": "audio",
    "label": "Effects volume",
    "kind": "slider",
    "default": 1,
    "min": 0,
    "max": 1,
    "step": 0.1,
    "platforms": [
     "roblox",
     "pc"
    ]
   },
   {
    "id": "subtitles",
    "tab": "accessibility",
    "label": "Subtitles",
    "kind": "toggle",
    "default": true,
    "platforms": [
     "roblox",
     "pc"
    ]
   },
   {
    "id": "text_scale",
    "tab": "accessibility",
    "label": "Text size",
    "kind": "slider",
    "default": 1,
    "min": 0.8,
    "max": 1.5,
    "step": 0.1,
    "platforms": [
     "roblox",
     "pc"
    ]
   },
   {
    "id": "camera_shake",
    "tab": "accessibility",
    "label": "Camera shake",
    "kind": "slider",
    "default": 0.6,
    "min": 0,
    "max": 1,
    "step": 0.1,
    "platforms": [
     "roblox",
     "pc"
    ],
    "help": "0 turns camera shake off."
   },
   {
    "id": "flash_intensity",
    "tab": "accessibility",
    "label": "Flash intensity",
    "kind": "slider",
    "default": 1,
    "min": 0,
    "max": 1,
    "step": 0.1,
    "platforms": [
     "roblox",
     "pc"
    ],
    "help": "Hit flashes and bright effects."
   },
   {
    "id": "motion_intensity",
    "tab": "accessibility",
    "label": "Motion intensity",
    "kind": "slider",
    "default": 1,
    "min": 0,
    "max": 1,
    "step": 0.1,
    "platforms": [
     "roblox",
     "pc"
    ],
    "help": "Screen motion such as hit-stop and camera sway."
   },
   {
    "id": "colorblind",
    "tab": "accessibility",
    "label": "Colour-blind mode",
    "kind": "choice",
    "default": "none",
    "options": [
     {
      "value": "none",
      "label": "Off"
     },
     {
      "value": "protanopia",
      "label": "Protanopia"
     },
     {
      "value": "deuteranopia",
      "label": "Deuteranopia"
     },
     {
      "value": "tritanopia",
      "label": "Tritanopia"
     }
    ],
    "platforms": [
     "roblox",
     "pc"
    ],
    "help": "Changes warning colours so attack tells stay easy to see."
   },
   {
    "id": "language",
    "tab": "language",
    "label": "Language",
    "kind": "choice",
    "default": "en",
    "options": [
     {
      "value": "en",
      "label": "English"
     }
    ],
    "platforms": [
     "roblox",
     "pc"
    ],
    "help": "More languages come later."
   }
  ]
 },
 "map": {
  "version": 1,
  "id": "map_akeboshi_harbor",
  "region_id": "reg_akeboshi_city",
  "name": "Akeboshi Harbor District",
  "environment_asset": "ast_env_akeboshi_harbor",
  "units": "studs",
  "bounds": {
   "min": [
    -300,
    -20,
    -300
   ],
   "max": [
    300,
    200,
    300
   ]
  },
  "player_spawn": {
   "position": [
    -150,
    3,
    120
   ],
   "facing_deg": 45
  },
  "hubs": [
   {
    "id": "hub_ferry_terminal",
    "name": "Ferry Terminal Outpost",
    "position": [
     -180,
     2,
     150
    ],
    "radius_studs": 40,
    "services": [
     "shop",
     "upgrade",
     "quest_board",
     "training",
     "fast_travel",
     "save_point",
     "appearance",
     "respec"
    ]
   }
  ],
  "fast_travel": [
   {
    "id": "ftp_ferry_terminal",
    "name": "Ferry Terminal",
    "position": [
     -170,
     2,
     140
    ],
    "unlocked_by": "default"
   },
   {
    "id": "ftp_clocktower_square",
    "name": "Clocktower Square",
    "position": [
     40,
     2,
     20
    ],
    "unlocked_by": "discover"
   }
  ],
  "landmarks": [
   {
    "id": "lmk_harbor_clocktower",
    "name": "Harbor Clocktower",
    "position": [
     40,
     0,
     -10
    ],
    "size": [
     24,
     120,
     24
    ],
    "description": "Stopped at 12:07, the moment the eclipse began. Visible from anywhere in the district."
   },
   {
    "id": "lmk_sunrise_bridge",
    "name": "Sunrise Bridge",
    "position": [
     200,
     10,
     -200
    ],
    "size": [
     40,
     30,
     180
    ],
    "description": "A suspension bridge snapped in half. It points toward something that is not on any map."
   },
   {
    "id": "lmk_lantern_shrine",
    "name": "Lantern Shrine",
    "position": [
     -60,
     0,
     -180
    ],
    "size": [
     30,
     18,
     30
    ],
    "description": "A tiny neighbourhood shrine ringed with stone lanterns, all dark."
   }
  ],
  "routes": [
   {
    "id": "main_street",
    "kind": "street",
    "from": "ftp_ferry_terminal",
    "to": "ftp_clocktower_square",
    "waypoints": [
     [
      -120,
      2,
      100
     ],
     [
      -40,
      2,
      40
     ]
    ],
    "width_studs": 24
   },
   {
    "id": "arcade_alley",
    "kind": "alley",
    "from": "ftp_clocktower_square",
    "to": "lmk_lantern_shrine",
    "waypoints": [
     [
      0,
      2,
      -80
     ],
     [
      -40,
      2,
      -140
     ]
    ],
    "width_studs": 10
   },
   {
    "id": "promenade",
    "kind": "waterfront",
    "from": "ftp_clocktower_square",
    "to": "arn_promenade_plaza",
    "waypoints": [
     [
      120,
      2,
      60
     ],
     [
      170,
      2,
      120
     ]
    ],
    "width_studs": 18
   },
   {
    "id": "rooftop_run",
    "kind": "rooftop",
    "from": "hub_ferry_terminal",
    "to": "lmk_harbor_clocktower",
    "waypoints": [
     [
      -100,
      40,
      60
     ],
     [
      -20,
      46,
      10
     ]
    ],
    "width_studs": 8
   },
   {
    "id": "bridge_road",
    "kind": "street",
    "from": "ftp_clocktower_square",
    "to": "lmk_sunrise_bridge",
    "waypoints": [
     [
      110,
      2,
      -60
     ],
     [
      180,
      4,
      -120
     ]
    ],
    "width_studs": 20
   }
  ],
  "spawn_zones": [
   {
    "id": "spz_main_street",
    "center": [
     -80,
     2,
     70
    ],
    "radius_studs": 40,
    "enemy_ids": [
     "enm_gloamling"
    ],
    "level_range": {
     "min": 1,
     "max": 5
    },
    "max_alive": 4,
    "respawn_s": 45
   },
   {
    "id": "spz_shopping_arcade",
    "center": [
     -20,
     2,
     -110
    ],
    "radius_studs": 35,
    "enemy_ids": [
     "enm_gloamling"
    ],
    "level_range": {
     "min": 4,
     "max": 9
    },
    "max_alive": 5,
    "respawn_s": 45
   },
   {
    "id": "spz_promenade",
    "center": [
     140,
     2,
     90
    ],
    "radius_studs": 45,
    "enemy_ids": [
     "enm_gloamling"
    ],
    "level_range": {
     "min": 8,
     "max": 14
    },
    "max_alive": 6,
    "respawn_s": 60
   }
  ],
  "boss_arenas": [
   {
    "id": "arn_promenade_plaza",
    "boss_id": "enm_lampeater",
    "center": [
     210,
     2,
     170
    ],
    "radius_studs": 55,
    "checkpoint_position": [
     160,
     2,
     130
    ]
   }
  ],
  "secrets": [
   {
    "id": "sec_clocktower_roof",
    "kind": "viewpoint",
    "position": [
     40,
     122,
     -10
    ],
    "hint": "Something glints at the very top of the stopped clocktower.",
    "reward": {
     "xp_base": 150
    }
   },
   {
    "id": "sec_shrine_offering_box",
    "kind": "hidden_chest",
    "position": [
     -70,
     2,
     -200
    ],
    "hint": "Behind the shrine, an offering box is still warm.",
    "reward": {
     "items": [
      {
       "item_id": "mat_wick_thread",
       "qty": 2
      }
     ]
    }
   },
   {
    "id": "sec_ferry_logbook",
    "kind": "lore_note",
    "position": [
     -200,
     4,
     170
    ],
    "hint": "The ferry captain's logbook stops mid-sentence at 12:07."
   }
  ],
  "side_quest_ids": [
   "qst_side_lamplighter"
  ],
  "blockout": [
   {
    "shape": "block",
    "role": "ground",
    "position": [
     0,
     -1,
     -40
    ],
    "size": [
     600,
     2,
     520
    ],
    "label": "District ground"
   },
   {
    "shape": "block",
    "role": "water",
    "position": [
     0,
     -3,
     260
    ],
    "size": [
     600,
     2,
     80
    ],
    "collide": false,
    "label": "Harbor water"
   },
   {
    "shape": "block",
    "role": "platform",
    "position": [
     60,
     0,
     205
    ],
    "size": [
     440,
     2,
     40
    ],
    "label": "Promenade boardwalk"
   },
   {
    "shape": "block",
    "role": "road",
    "position": [
     -80,
     0.1,
     70
    ],
    "size": [
     24,
     0.2,
     200
    ],
    "rotation_deg": [
     0,
     45,
     0
    ],
    "label": "Main street"
   },
   {
    "shape": "block",
    "role": "building",
    "position": [
     -190,
     12,
     175
    ],
    "size": [
     70,
     24,
     50
    ],
    "label": "Ferry terminal"
   },
   {
    "shape": "block",
    "role": "building",
    "position": [
     -120,
     20,
     40
    ],
    "size": [
     40,
     40,
     40
    ],
    "label": "Apartment block A (rooftop route start)"
   },
   {
    "shape": "block",
    "role": "building",
    "position": [
     -40,
     23,
     -20
    ],
    "size": [
     36,
     46,
     36
    ],
    "label": "Office block (rooftop route end)"
   },
   {
    "shape": "block",
    "role": "building",
    "position": [
     -30,
     10,
     -110
    ],
    "size": [
     16,
     20,
     120
    ],
    "label": "Shopping arcade, west row"
   },
   {
    "shape": "block",
    "role": "building",
    "position": [
     10,
     10,
     -110
    ],
    "size": [
     16,
     20,
     120
    ],
    "label": "Shopping arcade, east row"
   },
   {
    "shape": "block",
    "role": "landmark",
    "position": [
     40,
     60,
     -10
    ],
    "size": [
     24,
     120,
     24
    ],
    "label": "Harbor Clocktower"
   },
   {
    "shape": "block",
    "role": "platform",
    "position": [
     40,
     0.5,
     20
    ],
    "size": [
     80,
     1,
     60
    ],
    "label": "Clocktower square"
   },
   {
    "shape": "block",
    "role": "landmark",
    "position": [
     -60,
     4,
     -180
    ],
    "size": [
     30,
     8,
     30
    ],
    "label": "Lantern Shrine base"
   },
   {
    "shape": "cylinder",
    "role": "prop",
    "position": [
     -60,
     3,
     -165
    ],
    "size": [
     3,
     6,
     3
    ],
    "label": "Stone lantern (one of five)"
   },
   {
    "shape": "cylinder",
    "role": "platform",
    "position": [
     210,
     0.5,
     170
    ],
    "size": [
     110,
     1,
     110
    ],
    "label": "Promenade plaza (boss arena floor)"
   },
   {
    "shape": "block",
    "role": "landmark",
    "position": [
     200,
     10,
     -200
    ],
    "size": [
     40,
     4,
     180
    ],
    "label": "Sunrise Bridge deck (broken end)"
   },
   {
    "shape": "block",
    "role": "wall",
    "position": [
     300,
     20,
     0
    ],
    "size": [
     4,
     40,
     600
    ],
    "label": "East boundary wall (placeholder)"
   },
   {
    "shape": "block",
    "role": "wall",
    "position": [
     -300,
     20,
     0
    ],
    "size": [
     4,
     40,
     600
    ],
    "label": "West boundary wall (placeholder)"
   },
   {
    "shape": "block",
    "role": "wall",
    "position": [
     0,
     20,
     -300
    ],
    "size": [
     600,
     40,
     4
    ],
    "label": "North boundary wall (placeholder)"
   }
  ],
  "dev_status": "data_only"
 }
};
