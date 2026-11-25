"""Convert an Excel file of company salary data into the JSON that salary_lookup reads.

Usage:
    neojac run jobsearch -- convert_salary_excel <path-to-excel-file>
    neojac run jobsearch -- convert_salary_excel <path-to-excel-file> --source "My Union Stats 2025"
    neojac run jobsearch -- convert_salary_excel <path-to-excel-file> --baseline 100 --baseline-desc "Index 100 = median salary"

The output (salary_data.json) is written to the repository root unless --output is given.

Expected Excel format:
    - A header row with column names (auto-detected within the first ten rows)
    - A "Company" or "Firma" column (required)
    - An optional "City" or "By" column. A combined header such as "Firmanavn og by" /
      "Company and City" (no separate city column) is split on the last comma.
    - Any number of numeric data columns; a count column and an index column of the
      same category are grouped into one category.
"""

import argparse;
import json;
import math;
import os;
import re;
import sys;
import from pathlib { Path }

glob openpyxl: any = None,
     COMPANY_PATTERNS: set[str] = {"firma", "company", "virksomhed", "employer", "arbejdsgiver"},
     CITY_PATTERNS: set[str] = {"by", "city", "kommune", "location", "lokation", "sted"},
     COUNT_PATTERNS: set[str] = {"antal", "count", "number", "n", "employees", "medarbejdere"},
     INDEX_PATTERNS: set[str] = {
         "indeks",
         "index",
         "idx",
         "salary",
         "løn",
         "median",
         "average",
         "gennemsnit",
     },
     COMPOUND_PATTERNS: set[str] = {
         "firma",
         "antal",
         "indeks",
         "løn",
         "gennemsnit",
         "medarbejdere",
     },
     ID_PATTERNS: set[str] = {"id", "personnummer"},
     DEFAULT_CATEGORY: str = "all_employees",
     WORD_CHAR: str = "[a-zæøåöäü0-9]";

with entry {
    try {
        import openpyxl;
    } except ImportError {}
}

"""A finite number from an Excel cell, including localized strings; ValueError otherwise."""
def parse_numeric_cell(value: any) -> float;

"""(company, city) from a combined cell split on its last comma; no usable split leaves city empty."""
def split_combined_company_city(value: str) -> tuple[str, str];

"""Whether a pattern is a whole token of the header, or a substring if it is a compound pattern."""
def header_matches(header: str, patterns: set[str]) -> bool;

"""The header's category name: the header without its count/index words."""
def strip_type_patterns(header: str, patterns: set[str]) -> str;

def detect_column_type(header: str) -> str | None;

"""Column of the company or city: an exact header, else a matching one that is not a salary column."""
def metadata_column(headers: list[str], patterns: set[str], taken: int | None = None) -> int | None;

def cell_at(row: any, col: int | None) -> any;

"""Categories as (name, {field: column}): count/index pairs first, then lone columns."""
def detect_categories(columns: list[tuple[int, str]]) -> list[tuple[str, dict[str, int]]];

"""Company entries of one worksheet; an empty list when it has no table header."""
def parse_sheet(ws: any) -> list[dict[str, any]];

def _force_utf8_output -> None;

def main -> None;

with entry:__main__ {
    main();
}
