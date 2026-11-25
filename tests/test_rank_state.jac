import csv;
import json;
import subprocess;
import unittest;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

glob TOOL: list[str] = tool("rank_state"),
     TODAY: str = "2026-09-03",
     DIMENSIONS: tuple[str, ...] = ("technical", "experience", "behavioral", "career"),
     RETRY_FIELDS: tuple[str, ...] = ("fetch_attempts", "first_unreachable", "last_fetch_error"),
     ABSENT: str = "<absent>";

def job(**over: any) -> dict[str, any];

def scored(key: str = "a", score: int | float = 50, **extra: any) -> dict[str, any];

def keys(rows: list[dict[str, any]]) -> list[str];

class RankStateCase(unittest.TestCase) {
    def setUp -> None;
    def write_state(seen: dict[str, any]) -> None;
    def read_state -> dict[str, any];
    def results(payload: any, name: str = "results.json") -> str;
    def start(*args: str) -> any;
    def run_tool(
        *args: str, expect: int = 0, today: str = TODAY, now: str | None = None
    ) -> dict[str, any];
    def candidates(*args: str, today: str = TODAY) -> dict[str, any];
    def apply(
        results: list[any], *flags: str, expect: int = 0, today: str = TODAY, now: str | None = None
    ) -> dict[str, any];
    def fail_fetch(now: str, error: str = "403 after curl retry") -> dict[str, any];
}

class Candidates(RankStateCase) {
    def test_selects_only_new_entries_and_projects_a_compact_row;
    def test_status_and_focus_decide_what_is_selected;
    def test_limit_defers_the_rest_and_reports_the_count;
    def test_tracker_exclusion_handles_utf8_bom_and_reordered_columns;
    def test_tracker_exclusion_preserves_unicode_identity;
    def test_tracker_saved_in_a_legacy_code_page_is_reported_not_a_traceback;
    def test_missing_state_file_exits_nonzero;
}

class Sweep(RankStateCase) {
    def test_only_ranked_entries_past_their_deadline_are_retired;
    def test_non_iso_deadlines_are_reported_not_compared;
}

class Apply(RankStateCase) {
    def test_a_result_changes_exactly_the_fields_it_should;
    def test_scored_keys_keep_past_deadlines_out_of_the_shortlist;
    def test_deadline_apply_boundaries_and_dry_run_keep_existing_semantics;
    def test_past_deadline_does_not_bypass_scoring_errors;
    def test_weights_bands_and_persisted_fields;
    def test_vetoed_rows_are_separated_from_the_ranking;
    def test_a_rejected_result_is_an_error_and_never_half_writes_an_entry;
    def test_invalid_scores_report_errors_without_changing_the_entry;
    def test_score_boundaries_and_fractional_scores_remain_valid;
}

class Unreachable(RankStateCase) {
    def test_a_failed_fetch_is_recorded_as_unreachable_not_expired;
    def test_three_failures_inside_48_hours_keep_retrying;
    def test_gives_up_after_three_failures_48_hours_apart;
    def test_a_failed_fetch_past_the_stored_deadline_still_expires;
    def test_fetch_error_is_stored_as_bounded_plain_text;
    def test_malformed_results_are_errors_not_a_traceback;
    def test_non_object_entry_is_reported_not_a_traceback;
}

with entry:__main__ {
    unittest.main();
}
