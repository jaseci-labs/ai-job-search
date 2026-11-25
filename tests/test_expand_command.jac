import re;

import unittest;

import from pathlib { Path }

glob REPO_ROOT: any;

glob EXPAND_COMMAND_FILE: any;

glob BEHAVIORAL_PROFILE: any;

with entry {
    REPO_ROOT = Path(__file__).resolve().parent.parent;
    EXPAND_COMMAND_FILE = REPO_ROOT / ".claude" / "commands" / "expand.md";
    BEHAVIORAL_PROFILE = REPO_ROOT
        / ".claude"
        / "skills"
        / "job-application-assistant"
        / "02-behavioral-profile.md";
}

class ExpandCommandTests(unittest.TestCase) {
    def test_expand_command_file_exists -> any;

    def test_expand_command_file_starts_with_correct_header -> any;

    def test_expand_covers_all_discovery_sources -> any;

    def test_expand_maps_github_projects_to_independent_projects_section -> any;

    def test_behavioral_additions_name_sections_the_shipped_file_has -> any;

    def test_expand_enforces_additive_and_confirmation_principles -> any;
}

with entry:__main__ {
    unittest.main();
}
