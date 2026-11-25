import http.server;

import io;

import json;

import os;

import shutil;

import subprocess;

import sys;

import unittest;

import from unittest { mock }

import from pathlib { Path }

import from tempfile { TemporaryDirectory }

glob openpyxl: any;

glob REPO: any;

glob CYRILLIC: any;

glob CJK: any;

glob POLISH: any;

with entry {
    try {
        import openpyxl;
    } except ImportError {
        openpyxl = None;
    }

    REPO = Path(__file__).resolve().parent.parent;
    CYRILLIC = "Яндекс";
    CJK = "腾讯";
    POLISH = "Żabka Łódź";
}

def run_legacy_stdout(argv, cwd=None, `root=None) -> any;

class ToolsWriteUtf8(unittest.TestCase) {
    def setUp -> any;

    def assert_clean_utf8(proc, expect_code, *needles_, stream="stdout") -> any;

    def write_state(seen) -> any;

    static def `entry(company, title) -> any;

    def test_html_report_prints_an_output_path_outside_cp1252 -> any;

    def test_rank_candidates_lists_non_latin_postings -> any;

    def test_rank_apply_prints_the_ranking_for_non_latin_postings -> any;

    def test_scrape_candidates_lists_non_latin_hits -> any;

    def test_job_key_audit_reports_non_latin_entries -> any;

    def test_salary_lookup_prints_a_company_outside_cp1252 -> any;

    def test_verify_pdf_names_a_non_latin_file_in_its_error -> any;

    def test_verify_layout_reports_a_non_latin_cv_line -> any;

    @unittest.skipUnless(openpyxl, "requires optional openpyxl (installed in CI)")
    def test_salary_converter_names_a_non_latin_worksheet -> any;

    def test_upstream_triage_handles_non_latin_commit_subjects -> any;

    def test_fetch_page_prints_non_latin_text -> any;

    def test_robots_check_runs_cleanly -> any;
}

with entry:__main__ {
    unittest.main();
}
