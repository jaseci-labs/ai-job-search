"""Preserve space-grouped numbers through the real workbook converter CLI."""

import json;

import from pathlib { Path }

import subprocess;

import sys;

import from tempfile { TemporaryDirectory }

import unittest;

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
class GroupingCLI(unittest.TestCase) {
    def convert(rows) -> any;

    def test_unicode_space_grouping_preserves_count_and_salary -> any;

    def test_existing_space_groups_and_ambiguous_separators_are_unchanged -> any;
}

with entry:__main__ {
    unittest.main();
}
