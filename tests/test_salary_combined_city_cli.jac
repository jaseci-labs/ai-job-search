"""A combined name-and-city workbook column must feed salary_lookup --city.

The IDA demonstration workbook heads its company column "Firmanavn og by"
and stores "Ørsted A/S,Fredericia" in that one cell (no space after the
comma). convert_salary_excel used to copy the whole cell into company with
city "". The documented
lookup `neojac run jobsearch -- salary_lookup "Ørsted" --city "Fredericia"` then missed,
even though the city was in the converted file - just not in the field
--city reads.
"""

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
