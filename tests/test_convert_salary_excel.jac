import builtins;

import io;

import json;

import from pathlib { Path }

import subprocess;

import sys;

import tempfile;

import unittest;

import from contextlib { redirect_stderr }

import from types { SimpleNamespace }

glob openpyxl: any;

with entry {
    try {
        import openpyxl;
    } except ImportError {
        openpyxl = None;
    }
}

obj FakeWorksheet {
    has rows: any;

    static has title: any = "Sheet1";

    def init(rows);

    def iter_rows(min_row=1, max_row=None, values_only=False) -> Generator[any, any, any];

    def __getitem__(row_number) -> any;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

@unittest.skipUnless(openpyxl is not None, "openpyxl is not installed")
class BooleanCellCliTests(unittest.TestCase) {
    def test_excel_logical_cells_are_not_salary_numbers -> any;
}

class DetectColumnTypeTests(unittest.TestCase) {
    def test_index_headers_are_not_misclassified_as_count -> any;

    def test_single_letter_n_only_matches_as_a_token -> any;

    def test_count_headers_still_match_common_labels -> any;

    def test_count_inside_word_does_not_make_count_header -> any;

    def test_danish_compound_headers_still_match -> any;

    def test_compound_patterns_match_as_substring_but_others_do_not -> any;

    def test_parse_sheet_preserves_category_name_with_letter_n -> any;

    def test_parse_sheet_groups_accounting_count_index_pair -> any;

    def test_parse_sheet_normalizes_paired_category_name_with_underscores -> any;

    def test_parse_sheet_detects_company_column_with_token_header -> any;

    def test_parse_sheet_detects_danish_compound_company_header -> any;

    def test_parse_sheet_does_not_split_a_comma_in_a_company_only_column -> any;

    def test_parse_sheet_splits_english_combined_company_and_city_header -> any;

    def test_parse_sheet_splits_on_the_last_comma_when_the_company_contains_one -> any;

    def test_parse_sheet_keeps_a_combined_cell_with_no_comma_as_company_only -> any;

    def test_parse_sheet_detects_city_column_with_token_header -> any;

    def test_parse_sheet_handles_ragged_rows -> any;

    def test_parse_sheet_skips_row_shorter_than_company_column -> any;

    def test_skips_free_text_column -> any;

    def test_skips_numeric_identifier_column -> any;

    def test_keeps_numeric_salary_column -> any;

    def test_parse_sheet_accepts_comma_decimal_string_values -> any;

    def test_parse_sheet_accepts_danish_thousands_and_decimal_string -> any;

    def test_parse_sheet_skips_ambiguous_single_comma_thousands_string -> any;

    def test_parse_sheet_skips_ambiguous_single_dot_thousands_string -> any;

    def test_parse_sheet_pairs_interleaved_count_index_columns_by_name -> any;

    def test_standalone_count_column_is_stored_as_count_not_index -> any;

    def test_parse_sheet_non_adjacent_columns_no_cross_match -> any;

    def test_parse_sheet_ignores_citation_row_mentioning_company_pattern_word -> any;

    def test_parse_sheet_rejects_citation_row_with_count_word_in_same_cell -> any;

    def test_parse_sheet_falls_back_when_no_row_has_cross_cell_corroboration -> any;

    def test_parse_sheet_warns_when_no_salary_columns_detected -> any;
}

with entry:__main__ {
    unittest.main();
}

class ParseNumericCellLocaleTests(unittest.TestCase) {
    def test_us_thousands_and_decimal_string -> any;

    def test_us_multiple_thousands_groups -> any;

    def test_european_thousands_and_decimal_string -> any;

    def test_european_multiple_thousands_groups -> any;
}

"""A count/index pair whose headers carry no category word is still a pair.

    "Count" + "Index" (Danish "Antal" + "Lønindeks") both strip to an empty
    category name, and the pairing loop used to require a non-empty name on
    both sides, so the single-category layout the README describes as
    "auto-pairs count/index columns" came out as two unrelated standalone
    columns. salary_lookup then rendered the count row with "N/A*" for the
    index - "too few employees to publish (privacy)" - about a company whose
    headcount was right there in the file. The literal name is asserted (not
    the module constant) so the cases run, and fail, against the old converter.
    """
class BareCountIndexPairingTests(unittest.TestCase) {
    static has DEFAULT_CATEGORY: any = "all_employees";

    def test_bare_english_pair_is_paired_under_the_default_category -> any;

    def test_bare_danish_pair_is_paired_under_the_default_category -> any;

    def test_bare_pair_does_not_cross_pair_with_a_named_category -> any;

    def test_lookup_renders_the_bare_pair_as_one_row_without_the_privacy_footnote_firing -> any;
}

"""A name header must win over a salary header that also carries the word.

    The detection loop kept the LAST header matching a company pattern, so
    "Company Name | City | Company Count | Company Index" made the index
    column the company column and every row's company read "108.5". #571
    added an exact-match preference, which only helps when a header is
    exactly "Company"; the qualified name header stayed exposed. The Danish
    case below is a constructed header in the same shape, not the IDA
    workbook, whose pairs are headed "Antal" and "Indeks" and already convert.
    """
class QualifiedCompanyHeaderNextToQualifiedSalaryHeader(unittest.TestCase) {
    def test_company_name_wins_over_company_index -> any;

    def test_danish_name_header_wins_over_qualified_index_header -> any;

    def test_exact_header_still_wins_over_a_qualified_name_header -> any;

    def test_city_column_never_aliases_the_company_column -> any;

    def test_combined_header_before_a_real_city_column_keeps_the_city -> any;
}

class CompoundCategoryPairingTests(unittest.TestCase) {
    def test_parse_sheet_pairs_danish_compound_index_with_count -> any;

    def test_parse_sheet_sheet_level_us_locale_value -> any;
}
