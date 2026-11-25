"""Workbook blank rows must not make the generated salary data invalid."""

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

@unittest.skipUnless(openpyxl, "requires optional openpyxl (installed in CI)")
class EmptyCompanyWorkbookCLI(unittest.TestCase) {
    def convert_and_validate(blank) -> any;

    def test_space_only_company_rows_are_skipped -> any;

    def test_truly_empty_company_rows_are_still_skipped -> any;
}
