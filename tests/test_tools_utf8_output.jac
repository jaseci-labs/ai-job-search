import http.server;
import io;
import json;
import os;
import subprocess;
import sys;
import threading;
import unittest;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest { mock }

glob openpyxl: any;

with entry {
    try {
        import openpyxl;
    } except ImportError {
        openpyxl = None;
    }
}

glob CYRILLIC: str = "Яндекс",
     CJK: str = "腾讯",
     POLISH: str = "Żabka Łódź",
     SCORES: dict[str, int] = {"technical": 80, "experience": 80, "behavioral": 80, "career": 80};

def run_legacy_stdout(argv: list[any], cwd: any = None, path_root: any = None) -> any;

def posting(company: str, title: str) -> dict[str, str];

class PostingServer(http.server.BaseHTTPRequestHandler) {
    def do_GET;
    def log_message(*args: any);
}

class ToolsWriteUtf8(unittest.TestCase) {
    def setUp;
    def write_json(name: str, data: any) -> Path;
    def serve -> int;
    def assert_clean_utf8(
        proc: any, expect_code: int, *needles: str, stream: str = "stdout"
    ) -> str;
    def test_html_report_prints_an_output_path_outside_cp1252;
    def test_rank_state_candidates_and_apply_print_non_latin_postings;
    def test_scrape_candidates_lists_non_latin_hits;
    def test_job_key_audit_reports_non_latin_entries;
    def test_salary_lookup_prints_a_company_outside_cp1252;
    def test_verify_pdf_names_a_non_latin_file_in_its_error;
    def test_verify_layout_reports_a_non_latin_cv_line;

    @unittest.skipUnless(openpyxl, "requires optional openpyxl (installed in CI)")
    def test_salary_converter_names_a_non_latin_worksheet;

    def test_upstream_triage_handles_non_latin_commit_subjects;
    def test_fetch_page_and_robots_check_print_non_latin_text;
}
