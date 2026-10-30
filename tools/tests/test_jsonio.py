import unittest

from tests.helpers import TOOLS  # noqa: F401  (sets up the import path)

from sbe_tools.jsonio import MAX_SAFE_INTEGER, DataFormatError, loads


class StrictJsonTests(unittest.TestCase):
    def test_valid_json_loads(self):
        self.assertEqual(loads('{"a": [1, 2.5, "x", true]}'), {"a": [1, 2.5, "x", True]})

    def test_duplicate_keys_are_rejected(self):
        with self.assertRaisesRegex(DataFormatError, "duplicate key 'id'"):
            loads('{"id": "wpn_a", "id": "wpn_b"}')

    def test_duplicate_keys_in_nested_objects_are_rejected(self):
        with self.assertRaises(DataFormatError):
            loads('{"entries": [{"name": "a", "name": "b"}]}')

    def test_nan_and_infinity_are_rejected(self):
        for text in ('{"x": NaN}', '{"x": Infinity}', '{"x": -Infinity}'):
            with self.subTest(text=text), self.assertRaises(DataFormatError):
                loads(text)

    def test_overflowing_float_is_rejected(self):
        with self.assertRaisesRegex(DataFormatError, "not finite"):
            loads('{"x": 1e400}')

    def test_integers_beyond_double_precision_are_rejected(self):
        self.assertEqual(loads(str(MAX_SAFE_INTEGER)), MAX_SAFE_INTEGER)
        with self.assertRaisesRegex(DataFormatError, "larger than 2\\^53"):
            loads(str(MAX_SAFE_INTEGER + 1))

    def test_syntax_errors_report_line_and_column(self):
        with self.assertRaisesRegex(DataFormatError, "line 2, column"):
            loads('{\n  "a": ,\n}')

    def test_byte_order_mark_is_tolerated(self):
        self.assertEqual(loads('﻿{"a": 1}'), {"a": 1})


if __name__ == "__main__":
    unittest.main()
