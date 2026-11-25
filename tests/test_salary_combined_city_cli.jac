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
class CombinedCityWorkbookCLI(unittest.TestCase) {
    def convert_and_lookup(headers, row, *lookup_args_) -> any;

    def test_ida_firmanavn_og_by_row_is_findable_with_city_filter -> any;

    def test_separate_city_column_is_unchanged -> any;
}
