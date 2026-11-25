"""Run the converter on workbooks with both tabular and chart-only sheets."""

import json;

import from pathlib { Path }

import subprocess;

import sys;

import from tempfile { TemporaryDirectory }

import unittest;

glob openpyxl: any;

glob BarChart: any;

glob Reference: any;

glob TOOL: any;

with entry {
    try {
        import openpyxl;
        import from openpyxl.chart { BarChart, Reference }
    } except ImportError {
        openpyxl = None;
    }

    TOOL = tool("convert_salary_excel");
}

@unittest.skipUnless(openpyxl, "requires optional openpyxl (installed in CI)")
class ChartsheetCLI(unittest.TestCase) {
    def convert(with_chart) -> any;

    def test_chart_only_tab_does_not_abort_salary_conversion -> any;

    def test_all_data_worksheets_are_preserved_without_chart_tabs -> any;
}

with entry:__main__ {
    unittest.main();
}
