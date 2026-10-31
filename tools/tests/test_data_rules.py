"""Each test breaks a COPY of shared-data in one specific way and checks the validator catches it."""

import unittest

from tests.helpers import DataSandbox, find

from sbe_tools import xp_curve


class RuleTestCase(unittest.TestCase):
    def assert_error(self, report, *parts: str) -> None:
        for error in report.errors:
            if all(part in error for part in parts):
                return
        listing = "\n  ".join(report.errors) or "(no errors)"
        self.fail(f"expected an error containing {parts}, got:\n  {listing}")


class FileAndIdTests(RuleTestCase):
    def test_duplicate_id_across_files_is_caught(self):
        with DataSandbox() as box:
            box.save("items/weapons_extra.json", box.load("items/weapons.json"))
            self.assert_error(box.validate(), "duplicate id 'wpn_hearthwick'", "items/weapons.json")

    def test_duplicate_id_in_one_file_is_caught(self):
        with DataSandbox() as box:
            box.edit("enemies.json", lambda d: d["entries"].append(dict(d["entries"][0])))
            self.assert_error(box.validate(), "duplicate id 'enm_gloamling'")

    def test_unknown_reference_suggests_the_right_id(self):
        with DataSandbox() as box:
            box.edit("items/weapons.json", lambda d: d["entries"][0].update(moveset_id="mvs_lanternblade_katan"))
            self.assert_error(box.validate(), "'mvs_lanternblade_katan' is not the id of any moveset",
                              "did you mean 'mvs_lanternblade_katana'")

    def test_typo_in_field_name_is_caught(self):
        with DataSandbox() as box:
            box.edit("items/weapons.json", lambda d: d["entries"][0].update(rarty="common"))
            self.assert_error(box.validate(), "unknown field 'rarty'", "did you mean 'rarity'")

    def test_file_without_schema_is_caught(self):
        with DataSandbox() as box:
            box.edit("combat.json", lambda d: d.pop("$schema"))
            self.assert_error(box.validate(), "combat.json", 'missing "$schema"')

    def test_schema_outside_the_schema_folder_is_refused(self):
        with DataSandbox() as box:
            box.edit("combat.json", lambda d: d.update({"$schema": "./combat.json"}))
            self.assert_error(box.validate(), "must point into shared-data/schemas/")

    def test_local_ids_cannot_use_global_prefixes(self):
        with DataSandbox() as box:
            box.edit("enemies.json", lambda d: d["entries"][0]["attacks"][0].update(id="abl_swipe"))
            self.assert_error(box.validate(), "attacks[0].id", "does not match the pattern")


class WeaponAndKitTests(RuleTestCase):
    def test_weapon_needs_exactly_five_upgrade_tiers(self):
        with DataSandbox() as box:
            box.edit("items/weapons.json", lambda d: d["entries"][0]["upgrade_tiers"].pop())
            self.assert_error(box.validate(), "upgrade_tiers", "needs at least 5 items, has 4")

    def test_upgrade_tiers_must_be_in_order(self):
        def swap(d):
            tiers = d["entries"][0]["upgrade_tiers"]
            tiers[0]["tier"], tiers[1]["tier"] = 2, 1
        with DataSandbox() as box:
            box.edit("items/weapons.json", swap)
            self.assert_error(box.validate(), "upgrade tiers must be numbered 1, 2, 3, 4, 5")

    def test_weapon_special_must_be_a_special_ability(self):
        with DataSandbox() as box:
            box.edit("items/weapons.json", lambda d: d["entries"][0].update(special_ability_id="abl_kindled_edge"))
            self.assert_error(box.validate(), "special_ability_id", "must be an ability of kind 'special'")

    def test_passive_abilities_have_no_cooldown(self):
        with DataSandbox() as box:
            box.edit("abilities.json", lambda d: find(d["entries"], "abl_kindled_edge").update(cooldown_s=5))
            self.assert_error(box.validate(), "abl_kindled_edge", "passive abilities have no cooldown")

    def test_beyond_concept_archetype_needs_full_kit(self):
        with DataSandbox() as box:
            box.edit("archetypes.json", lambda d: find(d["entries"], "arc_lanternblade").pop("skill_tree_id"))
            self.assert_error(box.validate(), "missing required field 'skill_tree_id'")

    def test_archetype_ultimate_must_be_a_transformation(self):
        with DataSandbox() as box:
            box.edit("abilities.json", lambda d: find(d["entries"], "abl_eclipse_form").pop("transformation"))
            self.assert_error(box.validate(), "must be a transformation")

    def test_faction_and_archetype_must_agree(self):
        with DataSandbox() as box:
            box.edit("factions.json", lambda d: find(d["entries"], "fac_skyreaders")["archetype_ids"].append("arc_lanternblade"))
            self.assert_error(box.validate(), "archetype 'arc_lanternblade' says it belongs to 'fac_lantern_wardens'")

    def test_brief_requires_four_to_six_playable_factions(self):
        def demote(d):
            for ident in ("fac_skyreaders", "fac_omokage_troupe", "fac_paper_court"):
                entry = find(d["entries"], ident)
                entry.update(playable=False)
        with DataSandbox() as box:
            box.edit("factions.json", demote)
            self.assert_error(box.validate(), "4-6 playable factions, found 3")

    def test_skill_tree_loops_are_caught(self):
        with DataSandbox() as box:
            box.edit("skill_trees.json", lambda d: d["entries"][0]["nodes"][0]["requires"].append("warden_resolve"))
            report = box.validate()
            self.assert_error(report, "requirement loop")
            self.assert_error(report, "at least one starting node")


class FairnessTests(RuleTestCase):
    def test_attack_tells_must_stay_readable_on_every_difficulty(self):
        with DataSandbox() as box:
            box.edit("enemies.json", lambda d: d["entries"][0]["attacks"][0]["timing"].update(windup_s=0.45))
            self.assert_error(box.validate(), "attack 'swipe'", "on challenge", "minimum readable tell")

    def test_every_attack_must_be_avoidable(self):
        with DataSandbox() as box:
            box.edit("enemies.json", lambda d: d["entries"][0]["attacks"][0].update(avoidable_by=[]))
            self.assert_error(box.validate(), "avoidable_by", "needs at least 1 items")

    def test_unblockable_attacks_must_be_dodgeable(self):
        with DataSandbox() as box:
            box.edit("enemies.json", lambda d: d["entries"][0]["attacks"][1].update(avoidable_by=["move_out"]))
            self.assert_error(box.validate(), "attack 'pounce'", "must be dodgeable")

    def test_unblockable_attacks_must_show_the_marker(self):
        with DataSandbox() as box:
            box.edit("enemies.json", lambda d: d["entries"][0]["attacks"][1]["tell"].pop("unblockable_marker"))
            self.assert_error(box.validate(), "attack 'pounce'", "unblockable marker")

    def test_hard_crowd_control_cannot_stun_lock(self):
        with DataSandbox() as box:
            box.edit("status_effects.json", lambda d: find(d["entries"], "sts_staggered").update(duration_s=3))
            self.assert_error(box.validate(), "sts_staggered", "no stun-locks")

    def test_boss_phases_must_go_down_in_hp(self):
        def scramble(d):
            phases = find(d["entries"], "enm_lampeater")["boss"]["phases"]
            phases[1]["starts_at_hp"] = 0.2
        with DataSandbox() as box:
            box.edit("enemies.json", scramble)
            self.assert_error(box.validate(), "decreasing HP fractions")

    def test_boss_phase_cannot_use_unknown_attack(self):
        with DataSandbox() as box:
            box.edit("enemies.json", lambda d: find(d["entries"], "enm_lampeater")["boss"]["phases"][0]["attack_ids"].append("tail_whip"))
            self.assert_error(box.validate(), "unknown attack 'tail_whip'")

    def test_boss_rank_needs_a_boss_block_and_minions_cannot_have_one(self):
        with DataSandbox() as box:
            box.edit("enemies.json", lambda d: find(d["entries"], "enm_lampeater").pop("boss"))
            self.assert_error(box.validate(), "missing required field 'boss'")
        with DataSandbox() as box:
            def give_minion_boss(d):
                find(d["entries"], "enm_gloamling")["boss"] = find(d["entries"], "enm_lampeater")["boss"]
            box.edit("enemies.json", give_minion_boss)
            self.assert_error(box.validate(), "entries[0]", "not allowed")

    def test_difficulty_cannot_make_death_take_items(self):
        with DataSandbox() as box:
            box.edit("difficulty.json", lambda d: d["death"].update(lose_items=True))
            self.assert_error(box.validate(), "death.lose_items", "must be exactly false")

    def test_normal_difficulty_is_the_baseline(self):
        with DataSandbox() as box:
            box.edit("difficulty.json", lambda d: find(d["modes"], "normal").update(enemy_damage_mult=1.2))
            self.assert_error(box.validate(), "enemy_damage_mult must be 1")

    def test_cosmetics_cannot_carry_stats(self):
        with DataSandbox() as box:
            box.edit("customization.json", lambda d: d["options"][0].update(stat_modifiers=[]))
            self.assert_error(box.validate(), "unknown field 'stat_modifiers'")

    def test_cosmetics_cannot_be_sold_for_real_money(self):
        with DataSandbox() as box:
            box.edit("customization.json", lambda d: d["options"][1].update(unlock={"type": "robux"}))
            self.assert_error(box.validate(), "unlock.type", "not allowed")


class ProgressionTests(RuleTestCase):
    def test_level_cap_is_fixed_at_3000(self):
        with DataSandbox() as box:
            box.edit("progression/progression.json", lambda d: d.update(level_cap=3001))
            self.assert_error(box.validate(), "level_cap", "must be exactly 3000")

    def test_level_bands_cannot_have_gaps(self):
        with DataSandbox() as box:
            box.edit("progression/progression.json", lambda d: find(d["level_bands"], "bnd_hidden_capital").update(min=252))
            self.assert_error(box.validate(), "gap or overlap between bands")

    def test_major_milestones_are_required(self):
        with DataSandbox() as box:
            box.edit("progression/progression.json",
                     lambda d: d["milestones"].update(major=[m for m in d["milestones"]["major"] if m["level"] != 1500]))
            self.assert_error(box.validate(), "missing the major milestone at level 1500")

    def test_edited_xp_table_is_caught(self):
        with DataSandbox() as box:
            box.edit("progression/xp_table.json", lambda d: d["xp_to_next"].__setitem__(499, 1))
            self.assert_error(box.validate(), "out of date with progression.json", "level 500")

    def test_xp_wall_is_caught(self):
        def add_wall(d):
            points = d["xp_curve"]["pace_points"]
            index = next(i for i, p in enumerate(points) if p[0] == 1000)
            points.insert(index + 1, [1001, 8.0])
        with DataSandbox() as box:
            box.edit("progression/progression.json", add_wall)
            progression = box.load("progression/progression.json")
            box.edit("progression/xp_table.json",
                     lambda d: d.update(xp_to_next=xp_curve.build_table(progression["xp_curve"], 3000)))
            self.assert_error(box.validate(), "that is a wall")


class WorldTests(RuleTestCase):
    def test_world_must_be_connected(self):
        def cut(d):
            find(d["entries"], "reg_akeboshi_city")["connects_to"] = []
            find(d["entries"], "reg_ura_akeboshi")["connects_to"] = ["reg_amagiri_capital"]
        with DataSandbox() as box:
            box.edit("regions.json", cut)
            self.assert_error(box.validate(), "cannot be reached")

    def test_region_connections_go_both_ways(self):
        with DataSandbox() as box:
            box.edit("regions.json", lambda d: find(d["entries"], "reg_corona_abyss")["connects_to"].append("reg_akeboshi_city"))
            self.assert_error(box.validate(), "reg_corona_abyss", "does not connect back")

    def test_map_points_must_be_inside_bounds(self):
        with DataSandbox() as box:
            box.edit("maps/map_akeboshi_harbor.json", lambda d: d["landmarks"][0].update(position=[400, 0, 0]))
            self.assert_error(box.validate(), "lmk_harbor_clocktower", "outside the map bounds")

    def test_spawn_levels_must_fit_the_region(self):
        with DataSandbox() as box:
            box.edit("maps/map_akeboshi_harbor.json", lambda d: d["spawn_zones"][0].update(level_range={"min": 1, "max": 500}))
            self.assert_error(box.validate(), "spz_main_street", "outside the region's range")

    def test_quest_prerequisite_loops_are_caught(self):
        with DataSandbox() as box:
            box.edit("quests.json", lambda d: find(d["entries"], "qst_main_seven_minutes")["prerequisites"].append("qst_main_promenade_lights"))
            report = box.validate()
            self.assert_error(report, "prerequisite loop")
            self.assert_error(report, "main quest with no prerequisites")

    def test_main_story_cannot_depend_on_side_quests(self):
        with DataSandbox() as box:
            box.edit("quests.json", lambda d: find(d["entries"], "qst_main_promenade_lights")["prerequisites"].append("qst_side_lamplighter"))
            self.assert_error(box.validate(), "main quest requires side content")


class InputTests(RuleTestCase):
    def test_binding_conflicts_are_caught_including_wasd(self):
        with DataSandbox() as box:
            box.edit("input_actions.json", lambda d: find(d["actions"], "ability_1")["bindings"].update(keyboard_mouse=["W"]))
            self.assert_error(box.validate(), "'W' is bound to both 'move' and 'ability_1'")

    def test_every_action_needs_a_touch_binding(self):
        with DataSandbox() as box:
            box.edit("input_actions.json", lambda d: find(d["actions"], "lock_on")["bindings"].pop("touch"))
            self.assert_error(box.validate(), "missing required field 'touch'")

    def test_presets_cannot_create_conflicts(self):
        with DataSandbox() as box:
            box.edit("input_actions.json", lambda d: d["presets"][0]["overrides"][0].update(bindings=["Q"]))
            self.assert_error(box.validate(), "preset 'right_click_guard' creates a binding conflict")

    def test_required_actions_must_exist(self):
        with DataSandbox() as box:
            box.edit("input_actions.json", lambda d: d.update(actions=[a for a in d["actions"] if a["id"] != "lock_on"]))
            self.assert_error(box.validate(), "missing required action 'lock_on'")


class WarningTests(RuleTestCase):
    def test_unused_asset_gives_a_warning_not_an_error(self):
        def add(d):
            extra = dict(d["entries"][0])
            extra["id"] = "ast_unused_thing"
            d["entries"].append(extra)
        with DataSandbox() as box:
            box.edit("assets.json", add)
            report = box.validate()
            self.assertEqual(report.errors, [])
            self.assertTrue(any("ast_unused_thing" in w and "not used" in w for w in report.warnings))


if __name__ == "__main__":
    unittest.main()


class PlatformAndSettingsTests(RuleTestCase):
    def test_roblox_reserved_keys_cannot_be_the_only_binding(self):
        def reserve(d):
            pause = find(d["actions"], "pause")
            pause["platform_overrides"]["roblox"]["keyboard_mouse"] = ["Escape"]
        with DataSandbox() as box:
            box.edit("input_actions.json", reserve)
            self.assert_error(box.validate(), "'pause'", "no usable keyboard_mouse binding on roblox")

    def test_settings_defaults_must_match_the_game_rules(self):
        with DataSandbox() as box:
            box.edit("settings.json", lambda d: find(d["settings"], "damage_numbers").update(default=False))
            self.assert_error(box.validate(), "'damage_numbers'", "combat.json says")

    def test_slider_default_must_sit_on_its_step_grid(self):
        with DataSandbox() as box:
            box.edit("settings.json", lambda d: find(d["settings"], "camera_shake").update(default=0.65))
            report = box.validate()
            self.assert_error(report, "'camera_shake'", "step grid")

    def test_settings_need_a_known_tab(self):
        with DataSandbox() as box:
            box.edit("settings.json", lambda d: find(d["settings"], "language").update(tab="extras"))
            self.assert_error(box.validate(), "unknown tab 'extras'")
