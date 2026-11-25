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
