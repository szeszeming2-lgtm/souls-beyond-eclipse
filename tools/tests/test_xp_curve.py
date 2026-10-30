import contextlib
import importlib.util
import io
import sys
import unittest

from tests.helpers import SHARED, TOOLS

from sbe_tools import jsonio, xp_curve
from sbe_tools.jsonio import MAX_SAFE_INTEGER

PROGRESSION = jsonio.load(SHARED / "progression" / "progression.json")
TABLE = jsonio.load(SHARED / "progression" / "xp_table.json")["xp_to_next"]
CURVE = PROGRESSION["xp_curve"]
CAP = PROGRESSION["level_cap"]


def load_sim():
    spec = importlib.util.spec_from_file_location("xp_sim", TOOLS / "xp_sim" / "xp_sim.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules["xp_sim"] = module  # dataclasses need the module registered
    spec.loader.exec_module(module)
    return module


class XpCurveTests(unittest.TestCase):
    def test_cap_is_3000_and_table_covers_every_level_up(self):
        self.assertEqual(CAP, 3000)
        self.assertEqual(len(TABLE), 2999)

    def test_level_can_never_exceed_the_cap(self):
        total = xp_curve.total_xp_for_level(TABLE, CAP)
        self.assertEqual(xp_curve.level_from_total_xp(TABLE, total), 3000)
        self.assertEqual(xp_curve.level_from_total_xp(TABLE, total * 1000), 3000)
        self.assertEqual(xp_curve.level_from_total_xp(TABLE, MAX_SAFE_INTEGER), 3000)

    def test_level_from_xp_boundaries(self):
        self.assertEqual(xp_curve.level_from_total_xp(TABLE, 0), 1)
        self.assertEqual(xp_curve.level_from_total_xp(TABLE, -50), 1)
        self.assertEqual(xp_curve.level_from_total_xp(TABLE, TABLE[0] - 1), 1)
        self.assertEqual(xp_curve.level_from_total_xp(TABLE, TABLE[0]), 2)
        for level in (2, 50, 100, 1000, 2999):
            total = xp_curve.total_xp_for_level(TABLE, level)
            self.assertEqual(xp_curve.level_from_total_xp(TABLE, total), level)
            self.assertEqual(xp_curve.level_from_total_xp(TABLE, total - 1), level - 1)

    def test_saved_table_matches_the_formula(self):
        self.assertEqual(TABLE, xp_curve.build_table(CURVE, CAP))

    def test_xp_needed_never_goes_down(self):
        self.assertTrue(all(b >= a for a, b in zip(TABLE, TABLE[1:])))

    def test_total_xp_fits_in_a_luau_number(self):
        self.assertLess(xp_curve.total_xp_for_level(TABLE, CAP), MAX_SAFE_INTEGER)

    def test_values_are_rounded_to_the_step(self):
        self.assertTrue(all(v % CURVE["round_to"] == 0 and v > 0 for v in TABLE))

    def test_rounding_is_half_up_not_bankers(self):
        # Python's round(2.5) == 2; the game must use the same rule in every engine, so we use half-up.
        self.assertEqual(xp_curve._round_half_up(12.5, 5), 15)
        self.assertEqual(xp_curve._round_half_up(7.5, 5), 10)
        self.assertEqual(xp_curve._round_half_up(7.49, 5), 5)

    def test_pace_interpolation(self):
        curve = {"pace_points": [[1, 1.0], [11, 3.0]]}
        self.assertEqual(xp_curve.pace_minutes(1, curve), 1.0)
        self.assertAlmostEqual(xp_curve.pace_minutes(6, curve), 2.0)
        self.assertEqual(xp_curve.pace_minutes(11, curve), 3.0)
        self.assertEqual(xp_curve.pace_minutes(50, curve), 3.0)


class XpSimulationTests(unittest.TestCase):
    """The brief's pacing targets, checked through the simulator."""

    @classmethod
    def setUpClass(cls):
        cls.sim = load_sim()
        cls.hours = {s.name: cls.sim.hours_to_levels(s, PROGRESSION, TABLE) for s in cls.sim.PLAY_STYLES}

    def test_level_100_takes_about_five_hours(self):
        self.assertGreaterEqual(self.hours["normal"][99], 4.0)
        self.assertLessEqual(self.hours["normal"][99], 6.0)

    def test_level_cap_takes_at_least_150_hours(self):
        self.assertGreaterEqual(self.hours["normal"][CAP - 1], 150)

    def test_grinding_one_enemy_is_slower_than_varied_play(self):
        self.assertGreater(self.hours["grinder"][CAP - 1], self.hours["normal"][CAP - 1] * 1.5)

    def test_simulator_reports_all_targets_met(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = self.sim.run(write=False, csv_path=None)
        self.assertEqual(code, 0, output.getvalue())
        self.assertIn("PASS: 6 of 6 targets met", output.getvalue())


if __name__ == "__main__":
    unittest.main()
