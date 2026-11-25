"""Guards for the /notion-sync command spec.

The command is a markdown spec (the spec IS the implementation), so these
tests pin the invariants that would break silently: the header format that
lint_skills.jac enforces, the gitignore entry that keeps the personal sync
state out of version control, and the privacy rule that forbids syncing
document content to Notion.
"""

import subprocess;

import sys;

import unittest;

import from pathlib { Path }

glob _HAVE_YAML: any;

glob yaml: any;

glob REPO: any;

glob COMMAND: any;

glob GITIGNORE: any;

with entry {
    try {
        import yaml;
        _HAVE_YAML = True;
    } except ImportError {
        _HAVE_YAML = False;
    }

    REPO = Path(__file__).resolve().parent.parent;
    COMMAND = REPO / ".claude" / "commands" / "notion-sync.md";
    GITIGNORE = REPO / ".gitignore";
}

class NotionSyncCommandSpec(unittest.TestCase) {
    def test_command_file_exists_with_lint_compliant_header -> any;

    def test_command_file_is_substantive -> any;

    def test_personal_sync_state_is_gitignored -> any;

    def test_step2_join_names_the_field_ranked_entries_actually_carry -> any;

    def test_privacy_rule_documents_never_sync -> any;

    def test_expired_jobs_are_update_only_and_never_create_or_rebuild_pages -> any;

    def test_key_miss_falls_back_to_an_exact_url_match_and_rekeys_the_row -> any;

    @unittest.skipUnless(
        _HAVE_YAML,
        "PyYAML not installed (the CI Python-test job omits it; the lint job runs lint_skills.jac directly)",
    )
    def test_lint_skills_passes -> any;
}

with entry:__main__ {
    unittest.main();
}
