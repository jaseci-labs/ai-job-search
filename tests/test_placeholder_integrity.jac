"""Guards for CI's placeholder-integrity sentinels.

The job exists to catch personal data committed to the upstream template.
That only works when each sentinel sits IN the data /setup replaces: the
CV's old sentinel was `[YOUR_NAME]`, whose only occurrences were a header
comment and the hyperref pdftitle - /setup's documented edit ("replace
placeholder personal data with their actual name, contact info") touches
neither, so a fully personalized CV with a real name, address, phone and
email passed the check (review finding F28, 2026-08-19; proven
empirically). Same weakness for 01-candidate-profile.md's `<!-- SETUP`
comment sentinel.

These tests pin (a) that ci.yml checks data-located sentinels, (b) that
the sentinels exist in the pristine files, and (c) that simulating the
/setup edit destroys at least one checked sentinel per file - i.e. the
guard actually fires on the failure it exists to catch.
"""

import builtins;

import unittest;

import from pathlib { Path }

glob REPO: any;

glob CI: any;

glob EXAMPLE_CV: any;

glob PROFILE: any;

glob CV_SENTINELS: any;

glob PROFILE_SENTINEL: any;

with entry {
    REPO = Path(__file__).resolve().parent.parent;
    CI = REPO / ".github" / "workflows" / "ci.yml";
    EXAMPLE_CV = REPO / "cv" / "main_example.tex";
    PROFILE = REPO / ".claude" / "skills" / "job-application-assistant" / "01-candidate-profile.md";
    CV_SENTINELS = ["\\name{[First]}{[Last]}", "\\email{[your.email@example.com]}"];
    PROFILE_SENTINEL = "[YOUR_EMAIL]";
}

"""Apply /setup Step 3.8's documented edit: replace placeholder personal
    data with a real name and contact info. Header comments and hyperref
    metadata are not personal data, so they are deliberately left alone -
    that is exactly why a comment-located sentinel guards nothing."""
def personalize_cv(text: builtins.str) -> builtins.str;

@unittest.skipIf(
    not is_upstream_checkout(),
    "placeholder-integrity guards the pristine upstream template; forks personalize these files via /setup",
)
class TestCvSentinelsAreDataLocated(unittest.TestCase) {
    def setUp -> any;

    def test_ci_checks_the_name_and_email_data_lines -> any;

    def test_pristine_cv_carries_both_sentinels -> any;

    def test_setup_edit_destroys_the_sentinels -> any;
}

@unittest.skipIf(
    not is_upstream_checkout(),
    "placeholder-integrity guards the pristine upstream template; forks personalize these files via /setup",
)
class TestProfileSentinelIsDataLocated(unittest.TestCase) {
    def test_ci_checks_a_data_placeholder_not_the_header_comment -> any;

    def test_pristine_profile_carries_the_sentinel -> any;
}

with entry:__main__ {
    unittest.main();
}
