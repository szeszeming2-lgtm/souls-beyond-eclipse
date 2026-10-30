"""The project's real data must be clean, and every generated file must be current."""

import importlib.util
import sys
import unittest

from tests.helpers import REPO, SHARED, TOOLS

from sbe_tools import luau_convert
from sbe_tools.validation import validate_all


def load_tool(name):
    spec = importlib.util.spec_from_file_location(name, TOOLS / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


class RealDataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report = validate_all(SHARED)

    def test_shared_data_has_no_errors(self):
        self.assertEqual(self.report.errors, [])

    def test_shared_data_has_no_warnings(self):
        self.assertEqual(self.report.warnings, [])

    def test_every_check_stage_ran(self):
        self.assertEqual(self.report.stage_reached, "done")

    def test_world_has_8_to_12_regions(self):
        regions = [e for e in self.report.registry.values() if e.kind == "reg"]
        self.assertTrue(8 <= len(regions) <= 12, len(regions))

    def test_generated_luau_is_up_to_date(self):
        plan = luau_convert.plan(self.report.files)
        stale = [str(p.relative_to(REPO)) for p in plan.changed + plan.stale + plan.foreign]
        self.assertEqual(stale, [], "run: python3 tools/convert_to_luau.py")

    def test_asset_docs_are_up_to_date(self):
        tool = load_tool("gen_asset_docs")
        for path, text in tool.render().items():
            with self.subTest(doc=path.name):
                self.assertEqual(path.read_text(encoding="utf-8"), text, "run: python3 tools/gen_asset_docs.py")


if __name__ == "__main__":
    unittest.main()
