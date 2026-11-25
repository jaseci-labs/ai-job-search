"""Guards for /outcome's follow-up branch (Step 2b).

The branch is part of the /outcome markdown spec (the spec IS the
implementation), so these tests pin the invariants that would break
silently: the draft-only rule (the branch must never send anything on the
user's behalf), the no-new-claims rule that keeps follow-ups inside the
framework's never-fabricate boundary, the two-follow-up cap that terminates
into /outcome's own no_response flow, and the deliberate contrast with
/gmail-sync's 30-day staleness flag.
"""

import subprocess;

import sys;

import unittest;

import from pathlib { Path }

glob _HAVE_YAML: any;

glob yaml: any;

glob REPO: any;

glob COMMAND: any;

with entry {
    try {
        import yaml;
        _HAVE_YAML = True;
    } except ImportError {
        _HAVE_YAML = False;
    }

    REPO = Path(__file__).resolve().parent.parent;
    COMMAND = REPO / ".claude" / "commands" / "outcome.md";
}

class OutcomeFollowupBranchSpec(unittest.TestCase) {
    def test_followup_branch_exists -> any;

    def test_followup_argument_documented -> any;

    def test_draft_only_rule_present -> any;

    def test_no_new_claims_rule_present -> any;

    def test_two_followup_cap_present -> any;

    def test_followup_candidates_reuse_the_open_pipeline_quiet_clock -> any;

    def test_threshold_contrast_with_gmail_sync_documented -> any;

    @unittest.skipUnless(
        _HAVE_YAML,
        "PyYAML not installed (the CI Python-test job omits it; the lint job runs lint_skills.jac directly)",
    )
    def test_lint_skills_passes -> any;
}

with entry:__main__ {
    unittest.main();
}
