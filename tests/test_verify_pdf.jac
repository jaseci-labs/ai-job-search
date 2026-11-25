import subprocess;

import tempfile;

import unittest;

import from pathlib { Path }

import from unittest.mock { patch }

class ParsePageCountTests(unittest.TestCase) {
    def test_parses_pdfinfo_page_count -> any;

    def test_rejects_output_without_page_count -> any;
}

class NormalizeTextTests(unittest.TestCase) {
    def test_folds_curly_apostrophe_to_ascii -> any;

    def test_folds_curly_double_quotes_to_ascii -> any;

    def test_folds_en_and_em_dashes_to_hyphen -> any;

    def test_folds_no_break_space_to_space -> any;

    def test_folds_decomposed_accents_to_nfc -> any;

    def test_still_collapses_whitespace -> any;

    def test_fold_is_symmetric -> any;
}

class FindNonAsciiDateRangesTests(unittest.TestCase) {
    def test_en_dash_between_years_is_reported_with_its_code_point -> any;

    def test_ascii_hyphen_range_is_clean -> any;

    def test_a_year_on_either_side_of_the_dash_is_enough -> any;

    def test_other_unicode_dashes_and_the_minus_sign_are_caught -> any;

    def test_numeric_range_without_a_year_is_not_a_date -> any;

    def test_year_like_digits_inside_a_longer_number_are_not_a_year -> any;

    def test_numeric_range_with_year_shaped_ends_is_a_quantity_not_a_date -> any;

    def test_attached_currency_symbols_make_numeric_ranges_quantities -> any;

    def test_numerically_formatted_date_ranges_are_still_caught -> any;

    def test_year_and_two_digit_year_is_a_date_range -> any;

    def test_two_digit_number_before_a_year_is_still_a_quantity -> any;

    def test_two_years_joined_by_a_dash_are_still_a_date_range -> any;

    def test_a_standalone_year_next_to_a_longer_number_is_still_caught -> any;

    def test_year_ending_a_line_is_not_joined_to_the_next_lines_dash -> any;

    def test_dash_ending_a_line_is_not_joined_to_the_next_lines_year -> any;

    def test_same_line_spaces_around_the_dash_are_still_caught -> any;

    def test_hits_are_reported_in_document_order_one_per_range -> any;
}

class VerifyPdfTests(unittest.TestCase) {
    def setUp -> any;

    def tearDown -> any;

    @patch("tools.verify_pdf._extract_pypdf", return_value=None)
    @patch("tools.verify_pdf.run_tool")
    def test_accepts_expected_pages_and_text(mock_run_tool, _pypdf) -> any;

    @patch("tools.verify_pdf._extract_pypdf", return_value=None)
    @patch("tools.verify_pdf.run_tool")
    def test_rejects_wrong_page_count(mock_run_tool, _pypdf) -> any;

    @patch("tools.verify_pdf._extract_pypdf", return_value=None)
    @patch("tools.verify_pdf.run_tool")
    def test_rejects_too_little_extractable_text(mock_run_tool, _pypdf) -> any;

    @patch("tools.verify_pdf._extract_pypdf", return_value=None)
    @patch("tools.verify_pdf.run_tool")
    def test_rejects_missing_required_text(mock_run_tool, _pypdf) -> any;

    @patch("tools.verify_pdf._extract_pypdf", return_value=None)
    @patch("tools.verify_pdf.run_tool")
    def test_required_text_matches_latex_typographic_substitutions(mock_run_tool, _pypdf) -> any;

    @patch("tools.verify_pdf._extract_pypdf", return_value=None)
    @patch("tools.verify_pdf.run_tool")
    def test_required_text_matches_decomposed_pdflatex_accents(mock_run_tool, _pypdf) -> any;

    @patch("tools.verify_pdf._extract_pypdf", return_value=None)
    @patch("tools.verify_pdf.run_tool")
    def test_dump_text_keeps_the_raw_layer_unfolded(mock_run_tool, _pypdf) -> any;

    @patch("tools.verify_pdf._extract_pypdf", return_value=None)
    @patch("tools.verify_pdf.run_tool")
    def test_ascii_dates_rejects_the_en_dash_range_that_contains_accepts(
        mock_run_tool, _pypdf
    ) -> any;

    @patch("tools.verify_pdf._extract_pypdf", return_value=None)
    @patch("tools.verify_pdf.run_tool")
    def test_ascii_dates_accepts_hyphen_ranges(mock_run_tool, _pypdf) -> any;

    @patch("tools.verify_pdf._extract_pypdf", return_value=None)
    @patch("tools.verify_pdf.run_tool")
    def test_ascii_dates_still_writes_the_dump_before_failing(mock_run_tool, _pypdf) -> any;

    def test_ascii_dates_flag_is_off_by_default_and_parses -> any;

    def test_rejects_missing_pdf -> any;

    @patch("tools.verify_pdf._extract_pypdf", return_value=("Hello ATS body", 1))
    def test_pypdf_is_preferred_over_poppler(_pypdf) -> any;

    @patch("tools.verify_pdf._extract_pypdf", return_value=None)
    @patch("tools.verify_pdf.run_tool")
    def test_falls_back_to_pdftotext(mock_run_tool, _pypdf) -> any;
}

class RunToolTests(unittest.TestCase) {
    @patch("tools.verify_pdf.subprocess.run", side_effect=FileNotFoundError)
    def test_reports_missing_poppler_command(_mock_run) -> any;

    @patch("tools.verify_pdf.subprocess.run")
    def test_reports_unreadable_pdf(mock_run) -> any;
}

class DumpTargetTests(unittest.TestCase) {
    def setUp -> any;

    def test_documented_target_is_allowed -> any;

    def test_targets_outside_the_output_dirs_are_refused -> any;

    def test_symlink_out_of_cv_is_refused -> any;

    @patch("tools.verify_pdf.verify_pdf")
    def test_cli_refuses_before_extracting_or_writing(mock_verify) -> any;
}

with entry:__main__ {
    unittest.main();
}
