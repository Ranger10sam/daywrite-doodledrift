"""Negative regressions for the current structural validator, not a game solver."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("campaign_validator", ROOT / "tests/campaign_validator.py")
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)
LEVELS = json.loads((ROOT / "data/levels/campaign.json").read_text())


class CurrentCampaignStructureTests(unittest.TestCase):
    def test_spawn_inside_terrain_is_rejected(self):
        level = copy.deepcopy(LEVELS[0])
        level["start"] = [140, 650]
        with self.assertRaises(AssertionError):
            VALIDATOR.validate(level)

    def test_hazard_over_safe_spawn_is_rejected(self):
        level = copy.deepcopy(LEVELS[0])
        level["hazards"].append({"rect": [130, 590, 20, 20], "type": "spikes"})
        with self.assertRaises(AssertionError):
            VALIDATOR.validate(level)

    def test_forbidden_example_ink_is_rejected(self):
        level = copy.deepcopy(LEVELS[4])
        level["solution_strokes"][0]["ink"] = "solid"
        with self.assertRaises(AssertionError):
            VALIDATOR.validate(level)

    def test_no_build_example_is_rejected(self):
        level = copy.deepcopy(LEVELS[0])
        level["no_build_regions"] = [[450, 590, 170, 40]]
        with self.assertRaises(AssertionError):
            VALIDATOR.validate(level)

    def test_missing_crate_key_is_rejected(self):
        level = copy.deepcopy(LEVELS[3])
        level["gates"][0]["object_id"] = "wrong-parcel"
        with self.assertRaises(AssertionError):
            VALIDATOR.validate(level)

    def test_nonfinite_wind_is_rejected(self):
        level = copy.deepcopy(LEVELS[1])
        level["winds"][0]["force"][0] = float("nan")
        with self.assertRaises(AssertionError):
            VALIDATOR.validate(level)

    def test_self_crossing_terrain_is_rejected(self):
        level = copy.deepcopy(LEVELS[0])
        level["terrain"][0]["points"] = [[0, 620], [620, 900], [620, 620], [0, 900]]
        with self.assertRaises(AssertionError):
            VALIDATOR.validate(level)


if __name__ == "__main__":
    unittest.main()
