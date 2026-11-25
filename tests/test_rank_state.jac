import operator;

import csv;

import json;

import subprocess;

import sys;

import unittest;

import from pathlib { Path }

import from tempfile { TemporaryDirectory }

glob REPO: any;

glob TOOL: any;

glob TODAY: any;

with entry {
    REPO = Path(__file__).resolve().parent.parent;
    TOOL = tool("rank_state");
    TODAY = "2026-09-03";
}

def `entry(**over) -> any;

glob today_default_: any;

with entry {
    today_default_ = TODAY;
}

class RankStateCase(unittest.TestCase) {
    def setUp -> any;

    def write_state(seen) -> any;

    def run_tool(*args_, expect=0, today=today_default_, now=None) -> any;

    def read_state -> any;
}

class Candidates(RankStateCase) {
    def test_selects_only_new_entries_and_projects_a_compact_row -> any;

    def test_limit_defers_the_rest_and_reports_the_count -> any;

    def test_limit_zero_means_no_cap -> any;

    def test_tracker_pairs_are_excluded -> any;

    def test_tracker_exclusion_handles_utf8_bom_and_reordered_columns -> any;

    def test_tracker_exclusion_preserves_unicode_identity -> any;

    def test_tracker_saved_in_a_legacy_code_page_is_reported_not_a_traceback -> any;

    def test_focus_filters_on_title_company_and_stored_fit_notes -> any;

    def test_all_flag_includes_every_status_but_skipped -> any;

    def test_missing_state_file_exits_nonzero -> any;
}

class Sweep(RankStateCase) {
    def test_retires_past_deadlines_and_flags_the_closing_ones -> any;

    def test_entries_without_a_deadline_are_left_alone -> any;

    def test_non_iso_deadlines_are_reported_not_compared -> any;

    def test_only_ranked_entries_are_swept_and_excluded_keys_are_skipped -> any;

    def test_excluded_keys_tolerate_spaces_after_commas -> any;

    def test_without_write_nothing_is_persisted -> any;
}

class Apply(RankStateCase) {
    def results(payload) -> any;

    def _scored(**extra) -> any;

    def test_apply_persists_guard_verdict -> any;

    def test_apply_without_guard_key_unchanged -> any;

    def test_apply_normalises_the_guard_verdict -> any;

    def test_apply_drops_a_stale_guard_when_rescored_without_one -> any;

    def test_apply_truncates_and_rejects_non_string_guard -> any;

    def test_scored_keys_keep_past_deadlines_out_of_the_shortlist -> any;

    def test_deadline_apply_boundaries_and_dry_run_keep_existing_semantics -> any;

    def test_past_deadline_does_not_bypass_scoring_errors -> any;

    def test_weights_bands_and_persisted_fields -> any;

    def test_expired_status_is_written_through -> any;

    def test_null_deadline_does_not_erase_a_stored_one -> any;

    def test_legacy_verdict_stored_under_location_is_migrated -> any;

    def test_a_real_place_in_location_survives -> any;

    def test_vetoed_rows_are_separated_from_the_ranking -> any;

    def test_language_note_is_dropped_when_gate_passes -> any;

    def test_strengths_and_gaps_are_capped_and_stored_verbatim -> any;

    def test_all_replaces_rather_than_accumulates_arrays -> any;

    def test_unknown_key_is_an_error_not_a_silent_drop -> any;

    def test_missing_score_dimension_is_an_error -> any;

    def test_dry_run_prints_but_never_writes -> any;

    def test_invalid_scores_report_errors_without_changing_the_entry -> any;

    def test_score_boundaries_and_fractional_scores_remain_valid -> any;

    def test_re_scoring_an_already_ranked_job_is_idempotent -> any;
}

class Unreachable(RankStateCase) {
    static has RETRY_FIELDS: any = ("fetch_attempts", "first_unreachable", "last_fetch_error");

    def results(payload) -> any;

    def fail_fetch(now, error="403 after curl retry") -> any;

    def test_a_failed_fetch_is_recorded_as_unreachable_not_expired -> any;

    def test_unreachable_entries_are_selected_again_on_the_next_run -> any;

    def test_three_failures_inside_48_hours_keep_retrying -> any;

    def test_gives_up_after_three_failures_48_hours_apart -> any;

    def test_a_later_successful_fetch_clears_the_retry_fields -> any;

    def test_a_confirmed_closed_posting_still_expires_at_once -> any;

    def test_a_failed_fetch_past_the_stored_deadline_still_expires -> any;

    def test_fetch_error_is_stored_as_bounded_plain_text -> any;

    def test_an_unknown_status_is_an_error_not_a_missing_score -> any;

    def test_malformed_results_are_errors_not_a_traceback -> any;

    def test_an_unknown_gate_verdict_is_an_error_not_a_shortlisted_job -> any;

    def test_non_object_entry_is_reported_not_a_traceback -> any;
}

with entry:__main__ {
    unittest.main();
}
