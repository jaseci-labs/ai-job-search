"""Tests for salary_lookup.jac — format_entry, match_score, and search_company."""

import io;

import json;

import shutil;

import subprocess;

import sys;

import tempfile;

import unittest;

import from contextlib { redirect_stderr, redirect_stdout }

import from pathlib { Path }

import from unittest { mock }

class FormatEntryTests(unittest.TestCase) {
    static has PRIVACY_FOOTNOTE: any = "* N/A = Too few employees to publish (privacy)";

    def test_privacy_footnote_is_omitted_when_no_row_is_suppressed -> any;

    def test_privacy_footnote_is_printed_when_a_row_is_suppressed -> any;

    def test_zero_count_is_displayed_as_zero -> any;

    def test_text_index_does_not_crash -> any;

    def test_format_entry_with_zero_baseline -> any;

    def test_format_entry_with_custom_baseline -> any;

    def test_null_categories_with_sibling_dict_does_not_crash -> any;

    def test_null_metadata_does_not_crash -> any;
}

class TestMatchScoreExactMatch(unittest.TestCase) {
    def test_exact_match_returns_100 -> any;

    def test_exact_match_case_insensitive -> any;

    def test_exact_match_after_suffix_stripping -> any;

    def test_exact_match_after_dotted_amba_suffix_stripping -> any;
}

class TestMatchScoreSubstring(unittest.TestCase) {
    def test_query_contained_in_entry_gives_high_score -> any;

    def test_entry_contained_in_query_gives_high_score -> any;
}

class TestMatchScoreShortQuery(unittest.TestCase) {
    def test_short_query_no_word_overlap_returns_zero -> any;

    def test_short_query_with_word_overlap_scores -> any;
}

class TestMatchScoreAnglicize(unittest.TestCase) {
    def test_oe_variant_matches_o_with_slash -> any;

    def test_aa_variant_matches_aa -> any;

    def test_danish_characters_roundtrip -> any;
}

class TestMatchScoreNoOverlap(unittest.TestCase) {
    def test_completely_unrelated_names_return_zero -> any;

    def test_empty_query_returns_zero -> any;

    def test_empty_entry_returns_zero -> any;
}

def _make_data(*entries_) -> any;

def _entry(company, city="") -> any;

class SearchCompanyTests(unittest.TestCase) {
    def test_search_company_with_none_city -> any;
}

class ValidateDataTests(unittest.TestCase) {
    def assert_invalid_data(data, expected_message) -> any;

    def test_valid_minimal_data_is_returned -> any;

    def test_top_level_value_must_be_object -> any;

    def test_companies_must_be_list -> any;

    def test_metadata_must_be_object_when_provided -> any;

    def test_load_data_reports_json_parse_errors_without_traceback -> any;

    def test_company_entry_must_be_object -> any;

    def test_company_name_is_required -> any;

    def test_company_name_must_not_be_blank -> any;

    def test_city_must_be_string_when_provided -> any;

    def test_categories_must_be_object_when_provided -> any;
}

"""Category-shape and duplicate-name checks (reuses assert_invalid_data)."""
class ValidateDataShapeTests(ValidateDataTests) {
    def test_malformed_category_value_rejected -> any;

    def test_non_numeric_count_rejected -> any;

    def test_duplicate_company_name_is_warning -> any;

    def test_valid_categories_have_no_issues -> any;
}

"""End-to-end checks for the --validate pre-flight flow."""
class ValidateFlagTests(unittest.TestCase) {
    def _run_validate(payload) -> any;

    def test_validate_flag_exits_1_on_errors -> any;

    def test_validate_flag_exits_0_on_clean -> any;

    def test_validate_flag_exits_0_on_duplicates_only -> any;
}

"""The disagreement in full: --validate blesses a file with a null
    metadata/categories, then the lookup path must render it, not crash.

    Both payloads pass --validate on master; the second command then dies
    (TypeError in the categories fallback, AttributeError on metadata.get).
    """
class NullShapeEndToEndTests(unittest.TestCase) {
    """Run main() against `payload` with the given argv. Returns
        (exit_code_or_None, stdout). main() returns normally on a successful
        render, so a missing SystemExit is success, not an error."""
    def _run_main(payload, *argv_tail_) -> any;

    def test_null_categories_passes_validate_then_renders -> any;

    def test_null_metadata_passes_validate_then_renders -> any;
}

class UtilityTests(unittest.TestCase) {
    def test_normalize_strips_suffix_and_noise -> any;

    def test_normalize_strips_dotted_amba_suffix_same_as_undotted -> any;

    def test_anglicize_replaces_danish_chars -> any;

    def test_extract_core_words -> any;
}

class MatchScoreTests(unittest.TestCase) {
    def test_exact_match_score -> any;

    def test_partial_match_score -> any;

    def test_anglicized_match_score -> any;

    def test_overlap_match_score -> any;

    def test_no_match_score -> any;
}

class SearchCompanyRefactoredTests(unittest.TestCase) {
    def setUp -> any;

    def test_search_by_name -> any;

    def test_search_with_city_filter -> any;
}

class TestSearchCompanyBasicMatch(unittest.TestCase) {
    def test_exact_name_returns_match -> any;

    def test_no_match_returns_empty_list -> any;

    def test_multiple_candidates_all_returned -> any;
}

class TestSearchCompanyCityFilter(unittest.TestCase) {
    def test_matching_city_is_included -> any;

    def test_non_matching_city_is_excluded -> any;

    def test_no_city_filter_returns_all_cities -> any;

    def test_city_filter_case_insensitive -> any;

    def test_anglicized_city_matches_danish_city -> any;
}

class TestSearchCompanyScoreThreshold(unittest.TestCase) {
    def test_low_score_matches_excluded -> any;

    def test_results_sorted_by_relevance_descending -> any;
}

"""Exercise user-created UTF-8 files through the documented CLI."""
class TestSalaryFileEncoding(unittest.TestCase) {
    def setUp -> any;

    def run_cli(*args_) -> any;

    def test_utf8_with_and_without_bom -> any;

    def test_bom_does_not_hide_invalid_json -> any;
}

with entry:__main__ {
    unittest.main();
}
