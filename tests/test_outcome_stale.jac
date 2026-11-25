import re;

import unittest;

import from pathlib { Path }

glob REPO: any;

glob COMMAND: any;

with entry {
    REPO = Path(__file__).resolve().parent.parent;
    COMMAND = REPO / ".claude" / "commands" / "outcome.md";
}

class OutcomeStaleBranchSpecTests(unittest.TestCase) {
    def setUp -> any;

    def test_stale_argument_documented_in_step0 -> any;

    def test_step1_suggests_stale_sweep -> any;

    def test_step2c_section_exists -> any;

    def test_drafted_rows_excluded_from_stale_candidates -> any;

    def test_default_60_day_threshold -> any;

    def test_user_confirmation_options_required -> any;

    def test_resolves_to_canonical_no_response -> any;
}

with entry:__main__ {
    unittest.main();
}
