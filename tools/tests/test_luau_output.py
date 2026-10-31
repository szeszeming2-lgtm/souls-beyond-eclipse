import shutil
import tempfile
import unittest
from pathlib import Path

from tests.helpers import SHARED
from tests.luau_reader import LuauReadError, read_module, same_data

from sbe_tools import luau_convert
from sbe_tools.catalog import discover
from sbe_tools.luau_writer import LuauWriteError, luau_key, luau_number, luau_string, to_luau


def module_source(expr: str) -> str:
    return f"--!strict\nlocal freeze = table.freeze\n\nreturn {expr}\n"


class LuauWriterTests(unittest.TestCase):
    def test_strings_escape_only_what_luau_needs(self):
        self.assertEqual(luau_string('say "hi"\\now'), '"say \\"hi\\"\\\\now"')
        self.assertEqual(luau_string("a\nb\tc\r"), '"a\\nb\\tc\\r"')
        self.assertEqual(luau_string("bell\x07"), '"bell\\007"')
        self.assertEqual(luau_string("Tōno 夜"), '"Tōno 夜"')  # UTF-8 kept as-is

    def test_keys_are_bracketed_when_needed(self):
        self.assertEqual(luau_key("damage"), "damage")
        self.assertEqual(luau_key("end"), '["end"]')  # reserved word
        self.assertEqual(luau_key("continue"), '["continue"]')
        self.assertEqual(luau_key("$schema"), '["$schema"]')
        self.assertEqual(luau_key("2x"), '["2x"]')
        self.assertEqual(luau_key("light-attack"), '["light-attack"]')

    def test_numbers(self):
        self.assertEqual(luau_number(5), "5")
        self.assertEqual(luau_number(-5), "-5")
        self.assertEqual(luau_number(0.1), "0.1")
        self.assertEqual(luau_number(1e-05), "1e-05")
        self.assertEqual(luau_number(2.0), "2.0")
        with self.assertRaises(LuauWriteError):
            luau_number(float("nan"))

    def test_null_is_refused_with_its_path(self):
        with self.assertRaisesRegex(LuauWriteError, "entries.notes: null cannot be stored"):
            to_luau({"notes": None}, 0, "entries")

    def test_every_table_is_frozen(self):
        text = to_luau({"a": [1, {"b": []}], "c": {}})
        self.assertEqual(text.count("freeze("), text.count("{"))
        self.assertEqual(read_module(module_source(text)), {"a": [1, {"b": read_module(module_source("freeze({})"))}], "c": read_module(module_source("freeze({})"))})

    def test_tricky_values_round_trip(self):
        value = {
            "end": "quote \" backslash \\ newline \n tab \t",
            "unicode": "Ura-Akeboshi 夜明け",
            "numbers": [0, -3, 2.5, 1e-07, 123456789012],
            "flags": [True, False],
            "nested": [{"x": 1}, {"y": [[]]}],
            "long_list": list(range(500)),
        }
        parsed = read_module(module_source(to_luau(value)))
        self.assertTrue(same_data(parsed, value))

    def test_reader_rejects_unfrozen_tables(self):
        with self.assertRaises(LuauReadError):
            read_module(module_source("{ 1, 2 }"))


class GeneratedModuleTests(unittest.TestCase):
    def test_every_real_data_file_round_trips_exactly(self):
        files, errors = discover(SHARED)
        self.assertEqual(errors, [])
        for data_file in files:
            with self.subTest(file=data_file.rel):
                source = luau_convert.render_module(data_file)
                self.assertTrue(source.startswith("--!nocheck\n-- AUTO-GENERATED"))
                self.assertTrue(source.rstrip().endswith(":: any"))
                expected = {k: v for k, v in data_file.data.items() if k != "$schema"}
                self.assertTrue(same_data(read_module(source), expected))

    def test_output_is_deterministic(self):
        files, _ = discover(SHARED)
        first = luau_convert.plan(files, Path("/nonexistent/out")).expected
        second = luau_convert.plan(files, Path("/nonexistent/out")).expected
        self.assertEqual(first, second)

    def test_module_names(self):
        self.assertEqual(luau_convert.module_parts("items/weapons.json"), ("Items", "Weapons"))
        self.assertEqual(luau_convert.module_parts("maps/map_akeboshi_harbor.json"), ("Maps", "MapAkeboshiHarbor"))
        self.assertEqual(luau_convert.module_parts("input_actions.json"), ("InputActions",))

    def test_index_requires_every_module(self):
        files, _ = discover(SHARED)
        plan = luau_convert.plan(files, Path("/nonexistent/out"))
        index = plan.expected[Path("/nonexistent/out/init.luau")]
        for data_file in files:
            parts = luau_convert.module_parts(data_file.rel)
            self.assertIn(f"require(script.{'.'.join(parts)})", index)


class ConverterSafetyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="sbe-out-"))
        self.files, _ = discover(SHARED)

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_writes_then_reports_up_to_date(self):
        luau_convert.apply(luau_convert.plan(self.files, self.tmp))
        again = luau_convert.plan(self.files, self.tmp)
        self.assertEqual((again.changed, again.stale, again.foreign), ([], [], []))

    def test_stale_generated_files_are_removed(self):
        luau_convert.apply(luau_convert.plan(self.files, self.tmp))
        old = self.tmp / "Removed" / "OldThing.luau"
        old.parent.mkdir()
        old.write_text(f"-- {luau_convert.GENERATED_MARKER}\nreturn 1\n")
        result = luau_convert.plan(self.files, self.tmp)
        self.assertEqual(result.stale, [old])
        luau_convert.apply(result)
        self.assertFalse(old.exists())
        self.assertFalse(old.parent.exists())

    def test_hand_written_files_are_never_deleted(self):
        mine = self.tmp / "MyCode.luau"
        self.tmp.mkdir(exist_ok=True)
        mine.write_text("return 'my precious code'\n")
        result = luau_convert.plan(self.files, self.tmp)
        self.assertEqual(result.foreign, [mine])
        with self.assertRaises(luau_convert.ConvertError):
            luau_convert.apply(result)
        self.assertTrue(mine.exists())

    def test_name_collisions_are_refused(self):
        clone = type(self.files[0])(self.files[0].path, self.files[0].rel.replace("_", "-"), self.files[0].schema_name, self.files[0].data)
        if clone.rel == self.files[0].rel:
            clone.rel = "Abilities.json"
        with self.assertRaises(luau_convert.ConvertError):
            luau_convert.plan([self.files[0], clone], self.tmp)


if __name__ == "__main__":
    unittest.main()
