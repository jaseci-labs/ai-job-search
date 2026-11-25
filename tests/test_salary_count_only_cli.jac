"""Count-only workbook categories do not imply a suppressed salary index."""

import json;

import shutil;

import subprocess;

import sys;

import unittest;

import from pathlib { Path }

import from tempfile { TemporaryDirectory }

glob openpyxl: any;

glob REPO: any;

with entry {
    try {
        import openpyxl;
    } except ImportError {
        openpyxl = None;
    }

    REPO = Path(__file__).resolve().parent.parent;
}

class CountOnlySalaryCLI(unittest.TestCase) {
    def setUp -> any;

    def lookup -> any;

    def convert(headers, row) -> any;

    @unittest.skipUnless(openpyxl, "requires optional openpyxl (installed in CI)")
    def test_count_only_workbook_does_not_claim_privacy_suppression -> any;

    @unittest.skipUnless(openpyxl, "requires optional openpyxl (installed in CI)")
    def test_paired_numeric_index_control -> any;

    def test_explicit_null_index_keeps_the_existing_suppression_marker -> any;
}
