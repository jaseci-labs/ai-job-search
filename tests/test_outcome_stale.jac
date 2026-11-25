"""Guards for /outcome's stale sweep branch (Step 2c).

Pins the invariants for batch-resolving quiet applications:
- Step 0 documents `stale` / `sweep` and `stale <N>` / `sweep <N>`.
- Step 1.3 offers stale sweep when open rows exceed 60 days quiet.
- Step 2c defines the Stale Sweep Branch.
- Drafted applications are strictly excluded (never submitted).
- The default threshold is 60 days quiet.
- User confirmation (all, select, skip) is strictly required before writing.
- Status is resolved to canonical 'no_response' spelling.
"""

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
