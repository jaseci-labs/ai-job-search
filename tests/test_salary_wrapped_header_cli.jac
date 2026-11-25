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
class WrappedHeaderCLI(unittest.TestCase) {
    def convert(header) -> any;

    def test_wrapped_headers_pair_like_their_single_line_spelling -> any;

    def test_wrapped_category_name_has_no_line_break -> any;
}

with entry:__main__ {
    unittest.main();
}
