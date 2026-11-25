import json;
import subprocess;
import unittest;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

glob openpyxl: any = None,
     BarChart: any = None,
     Reference: any = None,
     PLAIN: list[any] = ["Company", "Count", "Index"],
     NOTES: list[list[str]] = [
         ["About this data"],
         ["Each row is one company in the 2025 survey."],
         ["Indexes are relative to the national median."],
         ["Categories with fewer than five respondents are suppressed."],
     ];

with entry {
    try {
        import openpyxl;
        import from openpyxl.chart { BarChart, Reference }
    } except ImportError {}
}

def both(count: any, index: any) -> dict[str, any];

def everyone(count: any, index: any) -> dict[str, any];

@unittest.skipUnless(openpyxl, "requires optional openpyxl (installed in CI)")
class SalaryWorkbookCLI(unittest.TestCase) {
    def setUp;
    def build(sheets: dict[str, list[any]]) -> any;
    def convert(book: any, *args: str) -> subprocess.CompletedProcess;
    def converted(sheets: any, *args: str) -> dict[str, any];
    def companies(sheets: any) -> list[tuple[str, str, any]];
    def lookup(*args: str) -> subprocess.CompletedProcess;
    def test_cells_and_headers_convert_to_categories;
    def test_nonfinite_baseline_is_rejected_without_overwriting_output;
    def test_finite_custom_and_zero_baselines_are_preserved;
    def test_data_worksheets_are_kept_with_or_without_a_chart_tab;
    def test_converted_city_is_findable_with_the_city_filter;
    def test_count_only_workbook_does_not_claim_privacy_suppression;
    def test_blank_company_rows_are_skipped_and_the_result_validates;
    def test_notes_tab_sentences_are_not_listed_as_companies;
    def test_workbook_without_a_salary_table_fails_without_writing_output;
    def test_real_workbook_round_trips_multiple_sheets_and_metadata;
}
