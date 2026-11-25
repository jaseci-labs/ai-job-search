"""Exercise the documented Excel -> converter CLI -> salary JSON path."""

import json;

import subprocess;

import sys;

import unittest;

import from pathlib { Path }

import from tempfile { TemporaryDirectory }

glob openpyxl: any;

glob TOOL: any;

with entry {
    try {
        import openpyxl;
    } except ImportError {
        openpyxl = None;
    }

    TOOL = tool("convert_salary_excel");
}

@unittest.skipUnless(openpyxl, "requires optional openpyxl (installed in CI)")
class ConverterCLI(unittest.TestCase) {
    def setUp -> any;

    def run_converter(*args_) -> any;

    def test_real_workbook_round_trips_multiple_sheets_and_metadata -> any;

    def test_workbook_without_salary_headers_fails_without_writing_output -> any;
}

with entry:__main__ {
    unittest.main();
}
