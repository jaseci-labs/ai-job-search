"""Guards for the tracker status vocabulary (issue #298).

The tracker CSV `status` column has a single authoritative definition in
/outcome's "Tracker status vocabulary" block. Every reader that mentions
final or open statuses must defer to that block or explicitly accept both
the canonical underscore spellings and the legacy space spellings on read.

These tests pin the two concrete bugs that opened #298:

1. `offer declined` (space form, written by the old /outcome Step 4) landed
   in no /html-report bucket, silently shrinking the rejection-rate denominator.
2. `interview_only` was listed as a tracker bucket value in /html-report, but
   it belongs to the archive outcome.md Status: enum, never the CSV column.

They also pin the review findings on the fix itself:

3. The space spellings are the same statuses as the underscore forms (equally
   Final), so a reader applying the lists literally cannot land on "not Final,
   not Open, undefined" - which would otherwise misroute a closed application
   in /apply's append-vs-update decision.
4. The vocabulary block must not split Step 1's numbered list: section-scoped
   reads of Step 1 must still see items 2-4.
5. /html-report's bucket map needs a catch-all so no tracker value drops out of
   the stats silently, and /notion-sync must normalise space forms before
   writing Status (Notion auto-creates a select option per unique string).
6. /apply and /interview make status decisions and must anchor them to the
   block, not restate an ad-hoc set.

They follow the CASES-table pattern from test_apply_records_application.py so
that adding a new reader is a one-line addition to READER_CASES.
"""

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

"""Body of one markdown section, up to the next heading of any depth."""
def section(path: Path, heading: builtins.str) -> builtins.str;

"""The canonical definition must live in /outcome and nowhere else."""
class VocabularyBlockExists(unittest.TestCase) {
    def test_outcome_has_vocabulary_block -> any;

    def test_vocabulary_block_lists_underscore_canonical_spellings -> any;

    def test_vocabulary_block_has_read_tolerance_line -> any;

    """The space spellings are the same statuses as the underscore forms, not
        separate values. Without this, a reader applying the Open/Final lists
        literally lands on "not Final, not Open, undefined" for `offer declined`,
        and /apply Step 6b would take the update branch for a closed application
        instead of appending a fresh row - losing the earlier document trail."""
    def test_vocabulary_block_states_equivalence_of_space_forms -> any;

    """Open is derived by exclusion from the one explicit Final list, so a new
        status needs updating in a single place and unknown values stay open until
        declared final."""
    def test_vocabulary_block_defines_open_by_exclusion -> any;

    """The vocabulary block must live as its own section below Step 1's closing
        ---, not between Step 1's numbered items. A block inside the list truncates
        section-scoped reads of Step 1 to item 1, and a future test scoped to Step 1
        would pass against a stub."""
    def test_step1_section_contains_all_items -> any;

    """The writer must use canonical underscore spellings, never space forms."""
    def test_outcome_step4_writes_underscore_forms -> any;
}

"""Each reader that classifies tracker values must handle both spellings
    and must not include archive-only values in tracker buckets."""
class ReadersBucketMap(unittest.TestCase) {
    """Read-tolerance: both spellings must reach the Rejected/Closed bucket."""
    def test_html_report_bucket_includes_space_and_underscore_forms -> any;

    """No tracker value may drop out of the stats silently: unrecognised values
        fall to Rejected/Closed and are named once in the status breakdown."""
    def test_html_report_bucket_map_has_catch_all -> any;

    """`interview_only` is the archive outcome.md Status: enum value,
        never a tracker CSV status. Listing it in the tracker bucket map
        confuses the two enums and would classify archive-only values
        that should not appear in the CSV."""
    def test_html_report_bucket_does_not_contain_interview_only -> any;

    """gmail-sync must defer to /outcome's vocabulary block for the
        open-application set, not hardcode the final-status set with
        space spellings that diverge from the writer."""
    def test_gmail_sync_references_vocabulary_block -> any;

    """Step 4 must map legacy space spellings to canonical before setting
        Status. Notion auto-creates a select option per unique string, so pushing
        a space form would give an existing database two options for one status
        and split closed applications across two filter buckets."""
    def test_notion_sync_normalises_status_before_write -> any;

    """Notion Status select options must match canonical tracker spellings
        so that upserted values are consistent with what /outcome writes."""
    def test_notion_sync_uses_underscore_status_spellings -> any;
}

"""Spot-checks across readers that prove the vocabulary block is reachable
    from each command that makes decisions based on tracker status.

    Format: (path, heading_or_None, needle, failure_message)
    """
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
