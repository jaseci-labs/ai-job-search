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
class NonFiniteWorkbookCLI(unittest.TestCase) {
    def convert(headers, rows) -> any;

    def test_infinite_paired_count_does_not_abort_the_workbook -> any;

    def test_nonfinite_paired_index_is_skipped_instead_of_emitted_as_nan -> any;

    def test_nonfinite_standalone_count_is_skipped -> any;
}
