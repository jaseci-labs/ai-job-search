import builtins;

import re;

import unittest;

import from pathlib { Path }

glob REPO: any;

glob COMMANDS: any;

glob OUTCOME: any;

glob GMAIL_SYNC: any;

glob HTML_REPORT: any;

glob NOTION_SYNC: any;

glob APPLY: any;

glob INTERVIEW: any;

glob VOCAB_ANCHOR: any;

with entry {
    REPO = Path(__file__).resolve().parent.parent;
    COMMANDS = REPO / ".claude" / "commands";

    OUTCOME = COMMANDS / "outcome.md";
    GMAIL_SYNC = COMMANDS / "gmail-sync.md";
    HTML_REPORT = COMMANDS / "html-report.md";
    NOTION_SYNC = COMMANDS / "notion-sync.md";
    APPLY = COMMANDS / "apply.md";
    INTERVIEW = COMMANDS / "interview.md";

    VOCAB_ANCHOR = "## Tracker status vocabulary";
}

def section(path: Path, heading: builtins.str) -> builtins.str;

class VocabularyBlockExists(unittest.TestCase) {
    def test_outcome_has_vocabulary_block -> any;

    def test_vocabulary_block_lists_underscore_canonical_spellings -> any;

    def test_vocabulary_block_has_read_tolerance_line -> any;

    def test_vocabulary_block_states_equivalence_of_space_forms -> any;

    def test_vocabulary_block_defines_open_by_exclusion -> any;

    def test_step1_section_contains_all_items -> any;

    def test_outcome_step4_writes_underscore_forms -> any;
}

class ReadersBucketMap(unittest.TestCase) {
    def test_html_report_bucket_includes_space_and_underscore_forms -> any;

    def test_html_report_bucket_map_has_catch_all -> any;

    def test_html_report_bucket_does_not_contain_interview_only -> any;

    def test_gmail_sync_references_vocabulary_block -> any;

    def test_notion_sync_normalises_status_before_write -> any;

    def test_notion_sync_uses_underscore_status_spellings -> any;
}

class ReaderCases(unittest.TestCase) {
    static has CASES: any = [
        (
            OUTCOME,
            VOCAB_ANCHOR,
            "underscores, never spaces",
            "The vocabulary block must state that underscores are canonical and spaces are not to be written",
        ),
        (
            OUTCOME,
            VOCAB_ANCHOR,
            "Final",
            "The vocabulary block must define the final-status set explicitly",
        ),
        (
            HTML_REPORT,
            "## Step 2: Compute Summary Stats",
            "excluded from every statistic below",
            "drafted rows must be excluded from every statistic, not counted as sent",
        ),
        (
            GMAIL_SYNC,
            "## Step 9: Staleness Check",
            "Skip `drafted` rows here",
            "the staleness check must skip drafted rows — nothing was sent, so nobody is late replying",
        ),
        (
            APPLY,
            "### Step 6b: Record the Application",
            "Tracker status vocabulary",
            "apply.md Step 6b must anchor its final-status decision to the /outcome vocabulary block — a closed application must never be treated as open and get its row updated instead of appended",
        ),
        (
            INTERVIEW,
            "## Step 0: Parse Input",
            "Tracker status vocabulary",
            "interview.md Step 0 must anchor its live-process statuses to the /outcome vocabulary block instead of restating an ad-hoc set",
        ),
    ];

    def test_all_reader_cases -> any;
}

with entry:__main__ {
    unittest.main();
}
