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
    4: (1920, 640), 5: (1920, 576), 6: (1792, 704), 7: (2176, 704),
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

    def test_geometry_integrity_contract(self):
        self.assertIn('local function geometry_status(stadium, length, width, game_state)', self.source)
        for status in ("VALID", "ZERO_DIMENSIONS_UNEXPECTED", "PERIOD_ENDED", "DIMENSION_MISMATCH", "UNKNOWN_STADIUM"):
            self.assertIn('"'+status+'"', self.source)
        self.assertIn('local valid_geometry = integrity == "VALID"', self.source)
        self.assertIn('transform(x, y, length, width, stadium, valid_geometry)', self.source)
        self.assertIn('if not geometry_valid then', self.source)
        self.assertIn('SHOW_OVERLAY and valid_geometry', self.source)
        self.assertIn('geometry_status,geometry_valid,expected_field_length,expected_field_width', self.source)

    def test_game_state_context(self):
        self.assertIn('local GAME_STATE, GAMEPLAY_ACTIVE = 0x00BA, 0x0006', self.source)
        self.assertIn('[6]="PERIOD_TIME_UP"', self.source)
        self.assertIn('if game_state == 6 then', self.source)
        self.assertIn('return "PERIOD_ENDED", nil, nil', self.source)
        self.assertIn('return "ZERO_DIMENSIONS_UNEXPECTED", nil, nil', self.source)
        self.assertIn('local gameplay_active = memory.read_u8(GAMEPLAY_ACTIVE, DOMAIN)', self.source)
        self.assertIn('game_state,game_state_kind,gameplay_active', self.source)
        self.assertIn('game_state, game_state_kind, gameplay_active', self.source)

    def test_transition_tracking_contract(self):
        self.assertIn('issd_radar_geometry_transitions.csv', self.source)
        self.assertIn('local function track_geometry(current)', self.source)
        self.assertIn('event = "INITIAL"', self.source)
        self.assertIn('event = "TIMELINE_RESET"', self.source)
        self.assertIn('event = "CHANGE"', self.source)
        self.assertIn('current.frame <= prev.frame', self.source)
        for field in ('stadium_id', 'game_state', 'field_length', 'field_width'):
            self.assertIn('"' + field + '"', self.source)
        self.assertIn('track_geometry({', self.source)
        self.assertIn('transitions:flush()', self.source)
        self.assertIn('previous_geometry = current', self.source)

    def test_transition_classifier_contract(self):
        self.assertIn('local function classify_transition(', self.source)
        self.assertIn('PENDING_MAX_FRAMES = 1200', self.source)
        self.assertIn('PERSISTENT_LIVE_FRAMES = 120', self.source)
        self.assertIn('classification = "STADIUM_CHANGE_PENDING"', self.source)
        self.assertIn('classification = "PERSISTENT_DIMENSION_MISMATCH"', self.source)
        self.assertIn('current.transition_status ~= prev.transition_status', self.source)
        self.assertIn('event = "CLASSIFICATION_CHANGE"', self.source)
        self.assertIn('transition_status,transition_age_frames,pending_from_stadium,pending_to_stadium', self.source)
        self.assertIn('local valid_geometry = integrity == "VALID"', self.source)
        self.assertIn('previous_classification_frame and frame <= previous_classification_frame', self.source)

    def test_variant_discovery_contract(self):
        self.assertIn("STADIUM_VARIANT_CANDIDATES", self.source)
        self.assertIn("[7] = {{length=2176, width=704, validated=false}}", self.source)
        self.assertIn("VARIANT_MIN_LIVE_FRAMES = 120", self.source)
        self.assertIn('issd_radar_geometry_variants.csv', self.source)
        self.assertIn("local function observe_variant(", self.source)
        self.assertIn('game_state == 0 and integrity == "DIMENSION_MISMATCH"', self.source)
        self.assertIn('transition_status ~= "STADIUM_CHANGE_PENDING"', self.source)
        self.assertIn("frame ~= variant_run.last_frame+1", self.source)
        self.assertIn('0, "OBSERVED_UNVALIDATED"', self.source)
        self.assertIn('local valid_geometry = integrity == "VALID"', self.source)

    def test_multivariant_geometry_contract(self):
        self.assertIn('local STADIUM_VARIANT_PROFILES = {', self.source)
        self.assertIn('id="7_2176x704"', self.source)
        self.assertIn('min_x=4, max_x=2172, min_y=4, max_y=700', self.source)
        self.assertIn('geometry_observed=true, projection_validated=false', self.source)
        self.assertIn('local function match_variant_profile(', self.source)
        self.assertIn('local variant_profile = match_variant_profile(', self.source)
        self.assertIn('variant_pixel_x,variant_pixel_y,variant_norm_x,variant_norm_y', self.source)
        self.assertIn('local variant_px, variant_py = project(variant_nx, variant_ny)', self.source)
        self.assertIn('if SHOW_OVERLAY and valid_geometry', self.source)

    def test_corner_visibility_guard(self):
        self.assertIn('local AUTO_HIDE_CORNERS = true', self.source)
        self.assertIn('local CENTER_FIELD_X, CENTER_FIELD_Y = 0x12F2, 0x12D8', self.source)
        self.assertIn('local center_x, center_y = u16(CENTER_FIELD_X), u16(CENTER_FIELD_Y)', self.source)
        self.assertIn('local field_loaded = length > 8 and width > 8', self.source)
        self.assertIn('and center_x > 0 and center_x < length', self.source)
        self.assertIn('and center_y > 0 and center_y < width', self.source)
        self.assertIn('local corners_geometry_known = valid_geometry', self.source)
        self.assertIn('variant_profile.geometry_observed == true', self.source)
        self.assertIn('(field_loaded and corners_geometry_known)', self.source)
        self.assertIn('corners_visible and 1 or 0, "known_geometry"', self.source)
        self.assertNotIn('CORNER_VISIBILITY_MODE', self.source)
        self.assertNotIn('radar_likely_visible', self.source)

    def test_pre_match_coin_toss_guard(self):
        self.assertIn('if stadium == 8 then return "PRE_MATCH_COIN_TOSS", nil, nil end', self.source)
        self.assertIn('and stadium ~= 8', self.source)
        self.assertIn('local valid_geometry = integrity == "VALID"', self.source)
        self.assertEqual(set(self.profiles), set(range(8)))

    def test_expected_dimensions_derived_from_profiles(self):
        for stadium, (length, width) in EXPECTED_DIMENSIONS.items():
            bounds = self.profiles[stadium]
            with self.subTest(stadium=stadium):
                self.assertEqual((bounds[1]-bounds[0]+8, bounds[3]-bounds[2]+8),
                                 (length, width))

    def test_model_selector_and_csv_fields(self):
        self.assertIn('PROJECTION_MODEL == "geometric"', self.source)
        self.assertIn('PROJECTION_MODEL == "empirical"', self.source)
        self.assertIn('PROJECTION_MODEL == "field_dimensions"', self.source)
        self.assertIn("geometric_minus_empirical_pixel_x", self.source)
        self.assertIn("geometric_minus_empirical_pixel_y", self.source)


if __name__ == "__main__":
    unittest.main()
