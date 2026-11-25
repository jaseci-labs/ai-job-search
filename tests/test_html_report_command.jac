import csv;

import datetime;

import json;

import os;

import re;

import subprocess;

import sys;

import tempfile;

import unicodedata;

import unittest;

import from pathlib { Path }

glob _HAVE_YAML: any;

glob yaml: any;

glob REPO_ROOT: any;

glob COMMAND_FILE: any;

glob LINT_SCRIPT: any;

glob GITIGNORE: any;

with entry {
    try {
        import yaml;
        _HAVE_YAML = True;
    } except ImportError {
        _HAVE_YAML = False;
    }

    REPO_ROOT = Path(__file__).resolve().parent.parent;
    COMMAND_FILE = REPO_ROOT / ".claude" / "commands" / "html-report.md";
    LINT_SCRIPT = tool("lint_skills");
    GITIGNORE = REPO_ROOT / ".gitignore";
}

class HtmlReportCommandFileTests(unittest.TestCase) {
    def test_command_file_exists -> any;

    def test_command_file_starts_with_correct_header -> any;

    def test_command_file_is_non_empty -> any;
}

class HtmlReportTrackerFieldTests(unittest.TestCase) {
    static has CANONICAL_HEADER: any = re.search(
        "^\\s*(date,company,[a-z_,]+)$",
        (REPO_ROOT / ".claude" / "commands" / "apply.md").read_text(encoding="utf-8"),
        re.M,
    ).group(1).split(",");

    def test_step1_parses_every_canonical_tracker_column -> any;

    def test_step3_table_columns_include_deadline_after_date -> any;
}

class HtmlReportGitignoreTests(unittest.TestCase) {
    def test_funnel_is_computed_from_stage_history_not_current_status -> any;

    def test_rejection_rate_excludes_declined_offers_and_withdrawals -> any;

    def test_reports_folder_is_gitignored -> any;
}

class HtmlReportScriptTests(unittest.TestCase) {
    static has HEADER: any = HtmlReportTrackerFieldTests.CANONICAL_HEADER;

    def render(rows, archives=None) -> any;

    def row(company, role, status, source="") -> any;

    static has PAYLOAD: any = "x' onmouseover='alert(1)' \" onfocus=\"alert(2)\" <img src=x onerror=alert(3)>";

    def test_fixture_tracker_pins_every_figure -> any;

    def test_empty_cells_do_not_print_none_and_the_rate_reading_is_stated -> any;

    def test_values_are_escaped_and_page_is_offline -> any;

    def test_out_must_be_an_html_file -> any;

    def test_out_expands_a_quoted_home_path -> any;

    def test_settings_and_guards_allow_the_script -> any;

    def test_new_archive_without_outcome_is_not_matched_to_older_same_company_archive -> any;

    def run_raw(tracker_bytes) -> any;

    def csv_text(rows) -> any;

    def assert_clean_exit(result, code, needle) -> any;

    def test_excel_csv_utf8_with_bom_is_read -> any;

    def test_row_with_fewer_fields_than_the_header_is_kept -> any;

    def test_cp1252_tracker_asks_for_a_utf8_resave -> any;

    def test_semicolon_tracker_asks_for_a_comma_separated_resave -> any;

    def test_empty_tracker_exits_with_a_message -> any;

    def test_capitalised_header_is_read -> any;

    def test_missing_tracker_exits_with_a_message -> any;

    def test_sent_rows_dated_in_the_future_render -> any;

    def test_summary_names_hired_and_unrecognised_statuses -> any;

    def dated(date, status="applied", company="Acme") -> any;

    def test_a_finished_search_is_charted_by_month_up_to_its_last_application -> any;

    def test_a_recent_search_is_charted_by_week -> any;

    def test_active_rows_without_a_usable_date_are_counted_in_the_waiting_table -> any;

    def test_a_year_only_date_is_charted_and_waits -> any;

    def test_folders_named_under_the_older_rule_still_match -> any;

    def test_folders_sharing_a_key_merge_their_stages -> any;

    def test_names_with_vowel_signs_match_a_folder_that_keeps_them -> any;

    def test_names_that_differ_only_in_underscores_or_accent_encoding_match_their_own_folder -> any;

    def test_outcome_that_is_not_utf8_asks_for_a_resave -> any;

    def test_typo_years_and_slash_dates_do_not_distort_the_chart -> any;

    def test_rows_of_bare_commas_are_not_applications -> any;

    def test_only_the_stages_checklist_counts_and_uppercase_ticks_count -> any;

    def test_malformed_dates_are_not_charted_and_dates_sort_chronologically -> any;

    def test_uppercase_scheme_links_and_blank_sector_falls_back -> any;

    static def table(html, caption) -> any;

    def test_offer_declined_reached_offer_in_the_funnel_and_the_stopped_chart -> any;

    def test_stopped_chart_agrees_with_the_funnel_on_ticked_stages -> any;

    static def folder(company, role) -> any;

    def past_screen(rows, archives) -> any;

    static has INTERVIEWED: any = "- [x] Phone screen\n- [x] Technical interview\n";

    def test_shorter_role_does_not_match_a_longer_roles_folder -> any;

    def test_company_prefix_does_not_match_another_company -> any;

    def test_non_latin_names_match_their_own_folder -> any;
}

@unittest.skipUnless(
    _HAVE_YAML,
    "PyYAML not installed (the CI Python-test job omits it; the lint job runs lint_skills.jac directly)",
)
class HtmlReportLintIntegrationTests(unittest.TestCase) {
    def test_lint_passes_on_real_repo -> any;
}

with entry:__main__ {
    unittest.main();
}
