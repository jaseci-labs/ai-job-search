import json;
import subprocess;
import unittest;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

glob TOOL: list[str] = tool("rank_state"),
     DIMENSIONS: tuple[str, ...] = ("technical", "experience", "behavioral", "career"),
     CASES: dict[str, tuple[tuple[int | float, ...], int, str]] = {
         "good": ((31, 55, 51, 96), 60, "Good Fit"),
         "weak": ((31, 31, 57, 13), 30, "Weak Fit"),
         "below": ((31, 55, 51, 95.9), 59, "Moderate Fit"),
         "above": ((31, 55, 51, 96.1), 60, "Good Fit"),
         "fractional": ((72.5, 72.5, 72.5, 72.5), 73, "Good Fit"),
         "zero": ((0, 0, 0, 0), 0, "Poor Fit"),
         "hundred": ((100, 100, 100, 100), 100, "Strong Fit"),
     };

class ExactRankRoundingCLI(unittest.TestCase) {
    def test_half_points_round_up_into_the_right_verdict_band;
}
