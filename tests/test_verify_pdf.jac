import subprocess;
import tempfile;
import unicodedata;
import unittest;
import from pathlib { Path }
import from unittest.mock { patch }

def poppler(text: str, pages: int = 1) -> any;

class TextHelpers(unittest.TestCase) {
    def test_parse_page_count;
    def test_normalize_text_folds;
}

class FindNonAsciiDateRanges(unittest.TestCase) {
    def test_every_unicode_dash_is_reported_with_its_line;
    def test_date_ranges_are_caught;
    def test_ascii_ranges_quantities_and_line_breaks_are_clean;
    def test_hits_are_reported_in_document_order_one_per_range;
}

class VerifyPdf(unittest.TestCase) {
    def setUp;
    def test_accepts;
    def test_rejects;
    def test_dump_text_is_the_raw_layer_and_is_written_before_a_failure;
    def test_ascii_dates_flag_is_off_by_default_and_parses;
    def test_pypdf_is_preferred_over_poppler;
    def test_falls_back_to_pdftotext;
    def test_run_tool_reports_failures;
}

class DumpTarget(unittest.TestCase) {
    def setUp;
    def test_documented_target_is_allowed;
    def test_targets_outside_the_output_dirs_are_refused;
    def test_symlink_out_of_cv_is_refused;
    def test_cli_refuses_before_extracting_or_writing;
}
