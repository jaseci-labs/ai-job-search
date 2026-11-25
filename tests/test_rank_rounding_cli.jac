import json;

import subprocess;

import sys;

import unittest;

import from pathlib { Path }

import from tempfile { TemporaryDirectory }

glob TOOL: any;

glob DIMENSIONS: any;

with entry {
    TOOL = tool("rank_state");
    DIMENSIONS = ("technical", "experience", "behavioral", "career");
}

class ExactRankRoundingCLI(unittest.TestCase) {
    def apply(cases) -> any;

    def test_halfpoint_boundaries_do_not_drop_a_verdict_band -> any;

    def test_fractional_and_endpoint_controls -> any;
}
