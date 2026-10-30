import json
import shutil
import tempfile
import unittest
from pathlib import Path

from tests.helpers import TOOLS  # noqa: F401

from sbe_tools.schema import SchemaError, SchemaStore, json_equal


def make_store(schemas: dict[str, dict]) -> SchemaStore:
    folder = Path(tempfile.mkdtemp(prefix="sbe-schema-"))
    try:
        for name, schema in schemas.items():
            (folder / name).write_text(json.dumps(schema), encoding="utf-8")
        return SchemaStore(folder)
    finally:
        shutil.rmtree(folder, ignore_errors=True)


def messages(store: SchemaStore, instance, schema="s.schema.json") -> list[str]:
    return [f"{i.path}: {i.message}" for i in store.validate(instance, schema).errors]


class SchemaValidatorTests(unittest.TestCase):
    def test_types_and_required_fields(self):
        store = make_store({"s.schema.json": {
            "type": "object",
            "required": ["id", "count"],
            "properties": {"id": {"type": "string"}, "count": {"type": "integer"}},
        }})
        self.assertEqual(messages(store, {"id": "x", "count": 3}), [])
        errs = messages(store, {"count": "three"})
        self.assertIn("(top level): missing required field 'id'", errs)
        self.assertIn("count: expected integer, got string", errs)

    def test_booleans_are_not_numbers(self):
        store = make_store({"s.schema.json": {"type": "integer"}})
        self.assertTrue(messages(store, True))
        self.assertEqual(messages(store, 2.0), [])  # 2.0 counts as an integer, like JSON Schema says

    def test_unknown_field_suggests_the_closest_name(self):
        store = make_store({"s.schema.json": {
            "type": "object", "additionalProperties": False, "properties": {"damage": {"type": "number"}},
        }})
        self.assertEqual(messages(store, {"damgae": 5}), ["(top level): unknown field 'damgae' (did you mean 'damage'?)"])

    def test_enum_suggests_the_closest_option(self):
        store = make_store({"s.schema.json": {"enum": ["common", "rare", "epic"]}})
        self.assertIn('did you mean "rare"', messages(store, "rar")[0])

    def test_numbers_strings_and_arrays(self):
        store = make_store({"s.schema.json": {
            "type": "object",
            "properties": {
                "n": {"type": "number", "minimum": 0, "exclusiveMaximum": 1},
                "s": {"type": "string", "pattern": "^wpn_[a-z]+$", "maxLength": 8},
                "a": {"type": "array", "minItems": 5, "maxItems": 5, "uniqueItems": True},
            },
        }})
        errs = messages(store, {"n": 1, "s": "wpn_ABCDEFG", "a": [1, 1, 2]})
        self.assertTrue(any("must be less than 1" in e for e in errs))
        self.assertTrue(any("does not match the pattern" in e for e in errs))
        self.assertTrue(any("at most 8 characters" in e for e in errs))
        self.assertTrue(any("needs at least 5 items" in e for e in errs))
        self.assertTrue(any("duplicate of item [0]" in e for e in errs))

    def test_pattern_dollar_does_not_accept_a_trailing_newline(self):
        store = make_store({"s.schema.json": {"type": "string", "pattern": "^abc$"}})
        self.assertEqual(messages(store, "abc"), [])
        self.assertTrue(messages(store, "abc\n"))

    def test_refs_inside_and_across_files(self):
        store = make_store({
            "common.schema.json": {"$defs": {"id": {"type": "string", "pattern": "^x_"}}},
            "s.schema.json": {
                "$defs": {"local": {"$ref": "common.schema.json#/$defs/id"}},
                "type": "array",
                "items": {"$ref": "#/$defs/local"},
            },
        })
        self.assertEqual(messages(store, ["x_a", "x_b"]), [])
        self.assertTrue(messages(store, ["y_a"]))

    def test_if_then_else(self):
        store = make_store({"s.schema.json": {
            "type": "object",
            "if": {"properties": {"rank": {"const": "boss"}}},
            "then": {"required": ["boss"]},
            "else": {"not": {"required": ["boss"]}},
        }})
        self.assertEqual(messages(store, {"rank": "boss", "boss": {}}), [])
        self.assertIn("(top level): missing required field 'boss'", messages(store, {"rank": "boss"}))
        self.assertTrue(messages(store, {"rank": "minion", "boss": {}}))

    def test_any_of_and_one_of(self):
        store = make_store({"s.schema.json": {"oneOf": [{"type": "string"}, {"type": "integer"}]}})
        self.assertEqual(messages(store, "a"), [])
        self.assertTrue(messages(store, 1.5))
        store = make_store({"s.schema.json": {"anyOf": [{"minimum": 0}, {"maximum": 10}]}})
        self.assertEqual(messages(store, 5), [])

    def test_references_are_collected_only_from_matching_branches(self):
        store = make_store({"s.schema.json": {
            "type": "object",
            "properties": {"weapon": {"type": "string", "x-ref": ["wpn"]}},
        }})
        refs = store.validate({"weapon": "wpn_hearthwick"}, "s.schema.json").refs
        self.assertEqual([(r.path, r.value, r.kinds) for r in refs], [("weapon", "wpn_hearthwick", ("wpn",))])

    def test_unknown_schema_keyword_is_refused(self):
        with self.assertRaisesRegex(SchemaError, "unsupported schema keyword 'minimun'"):
            make_store({"s.schema.json": {"type": "number", "minimun": 0}})

    def test_broken_ref_is_refused(self):
        with self.assertRaisesRegex(SchemaError, "points at nothing"):
            make_store({"s.schema.json": {"$ref": "#/$defs/missing"}})
        with self.assertRaisesRegex(SchemaError, "does not exist"):
            make_store({"s.schema.json": {"$ref": "other.schema.json#/$defs/a"}})

    def test_bad_regex_is_refused(self):
        with self.assertRaisesRegex(SchemaError, "bad regex"):
            make_store({"s.schema.json": {"type": "string", "pattern": "([a-z"}})

    def test_json_equality_rules(self):
        self.assertTrue(json_equal(1, 1.0))
        self.assertFalse(json_equal(True, 1))
        self.assertFalse(json_equal([1], [True]))
        self.assertTrue(json_equal({"a": [1, 2]}, {"a": [1.0, 2]}))


if __name__ == "__main__":
    unittest.main()
