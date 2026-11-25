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
