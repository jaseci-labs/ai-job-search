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
class BaselineCLI(unittest.TestCase) {
    def setUp -> any;

    def convert(baseline) -> any;

    def test_nonfinite_baseline_is_rejected_without_overwriting_output -> any;

    def test_finite_custom_and_zero_baselines_are_preserved -> any;
}
