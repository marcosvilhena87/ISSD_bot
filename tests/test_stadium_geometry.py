"""Regression check for ISSD radar stadium geometry (stdlib only).

Reads the real Lua profile table; validates geometrical equivalence of all
8 empirical bounds with the dimension-based geometric model.
This does not emulate BizHawk or validate native radar pixel accuracy.
"""
from pathlib import Path
import re
import unittest

RADAR = Path(__file__).resolve().parents[1] / "lua" / "radar.lua"
EXPECTED_DIMENSIONS = {
    0: (1792, 576), 1: (1856, 640), 2: (1984, 704), 3: (2048, 640),
    4: (1920, 640), 5: (1920, 576), 6: (1792, 704), 7: (1856, 640),
}
PATTERN = re.compile(
    r"\[(\d+)\]\s*=\s*\{min_x=(\d+),\s*max_x=(\d+),\s*"
    r"min_y=(\d+),\s*max_y=(\d+),\s*validated=(true|false)\}"
)


class StadiumGeometryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = RADAR.read_text(encoding="utf-8")
        cls.profiles = {}
        for match in PATTERN.finditer(cls.source):
            stadium, min_x, max_x, min_y, max_y, valid = match.groups()
            stadium = int(stadium)
            if stadium in cls.profiles:
                raise AssertionError(f"Duplicate Stadium_ID {stadium}")
            cls.profiles[stadium] = (
                int(min_x), int(max_x), int(min_y), int(max_y), valid == "true"
            )

    def test_all_stadiums_present(self):
        self.assertEqual(set(self.profiles), set(range(8)))

    def test_geometry_matches_profiles(self):
        for stadium, (length, width) in EXPECTED_DIMENSIONS.items():
            with self.subTest(stadium=stadium):
                self.assertEqual(
                    self.profiles[stadium][:4], (4, length - 4, 4, width - 4)
                )
                self.assertFalse(self.profiles[stadium][4])

    def test_model_selector_and_csv_fields(self):
        self.assertIn('PROJECTION_MODEL == "geometric"', self.source)
        self.assertIn('PROJECTION_MODEL == "empirical"', self.source)
        self.assertIn('PROJECTION_MODEL == "field_dimensions"', self.source)
        self.assertIn("geometric_minus_empirical_pixel_x", self.source)
        self.assertIn("geometric_minus_empirical_pixel_y", self.source)


if __name__ == "__main__":
    unittest.main()
