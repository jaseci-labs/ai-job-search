import io;
import json;
import subprocess;
import tempfile;
import unittest;
import from contextlib { redirect_stderr }
import from pathlib { Path }

glob PRIVACY_FOOTNOTE: str = "* N/A = Too few employees to publish (privacy)",
     INDEXED: dict[str, any] = {"all_employees": {"index": 105}},
     NORDIC: list[tuple[str, str]] = [
         ("Novo Nordisk A/S", "Bagsværd"),
         ("Ørsted", "Fredericia"),
         ("Vestas Wind Systems", "Aarhus"),
     ],
     UNICODE_NAMES: list[str] = [
         "腾讯",
         "東京 AI",
         "北京 AI",
         "Acme Corp",
         "Café Étoile",
         "Nestlé Danmark A/S",
         "Ørsted A/S",
         "Mærsk A/S",
         "Åland A/S",
         "Þekkingarmiðlun ehf.",
     ];

def corp(categories: any, **extra: any) -> dict[str, any];

class LookupUnits(unittest.TestCase) {
    def test_format_entry_rows_and_privacy_footnote;
    def test_match_score;
    def test_text_helpers;
    def test_search_company_ranks_and_filters_by_city;
    def test_invalid_data_exits_with_the_first_error;
    def test_valid_data_and_duplicate_warnings;
}

class LookupCLI(unittest.TestCase) {
    def setUp;
    def write(data: any, encoding: str = "utf-8") -> None;
    def run_cli(*args: str) -> subprocess.CompletedProcess;
    def found(query: str) -> list[str];
    def test_validate_reports_errors_and_warnings;
    def test_null_categories_and_null_metadata_validate_then_render;
    def test_json_parse_errors_have_no_traceback;
    def test_utf8_with_and_without_bom;
    def test_unusable_metadata_is_rejected;
    def test_baseline_and_optional_metadata_controls;
    def test_explicit_null_index_keeps_the_suppression_marker;
    def test_unicode_and_nordic_spellings_find_the_company;
}
