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
class CompanyHeaderCLI(unittest.TestCase) {
    def convert(header) -> any;

    def test_company_prefixed_salary_columns_do_not_replace_the_company -> any;

    def test_existing_named_category_control -> any;

    def test_city_prefixed_salary_columns_do_not_replace_the_city -> any;
}
