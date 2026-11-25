"""Guards for the onboarding privacy warnings (issue #345).

The README's quick start walks a new user into creating a public fork
(forks of public repos cannot be private) and then has /setup write
personal data into tracked files, with the only complete warning sitting
in SETUP.md section 8 - a section about pulling updates, downstream of
the decision it should inform. A real user hit exactly this. These tests
pin that the warning lives at the point of decision (adjacent to both
fork commands) and that /setup checks the origin's visibility BEFORE
writing anything, not in its closing notes.
"""

import builtins;

import re;

import unittest;

import from pathlib { Path }

glob REPO: any;

glob README: any;

glob SETUP_GUIDE: any;

glob SETUP_COMMAND: any;

with entry {
    REPO = Path(__file__).resolve().parent.parent;
    README = REPO / "README.md";
    SETUP_GUIDE = REPO / "SETUP.md";
    SETUP_COMMAND = REPO / ".claude" / "commands" / "setup.md";
}

"""Body of a markdown section up to the next heading of the same level."""
def section(text: builtins.str, heading: builtins.str) -> builtins.str;

class TestForkWarningsAtTheDecisionPoint(unittest.TestCase) {
    def assert_warns(body: builtins.str, where: builtins.str) -> any;

    def test_readme_quick_start_warns_next_to_the_fork_command -> any;

    def test_setup_guide_warns_next_to_the_fork_command -> any;
}

class TestSetupChecksOriginBeforeWriting(unittest.TestCase) {
    def test_preflight_exists_and_precedes_profile_generation -> any;
}

with entry:__main__ {
    unittest.main();
}
