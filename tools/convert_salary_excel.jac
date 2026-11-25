"""
Convert salary data from Excel to JSON format.

This script converts an Excel file containing company salary data
into the JSON format expected by salary_lookup.jac.

Prerequisites:
    neojac install

Usage:
    neojac run jobsearch -- convert_salary_excel <path-to-excel-file>
    neojac run jobsearch -- convert_salary_excel <path-to-excel-file> --source "My Union Stats 2025"
    neojac run jobsearch -- convert_salary_excel <path-to-excel-file> --baseline 100 --baseline-desc "Index 100 = median salary"

The output file (salary_data.json) will be written to the repository root.

Expected Excel format:
    - A header row with column names
    - A "Company" or "Firma" column (required)
    - An optional "City" or "By" column. A combined header such as
      "Firmanavn og by" / "Company and City" (no separate city column)
      is split on the last comma, and both parts are stripped, into company and city.
    - Any number of numeric data columns (salary index, count, etc.)

The script auto-detects the header row and column layout. For Excel files
with paired count/index columns per category, it groups them automatically.
"""

import os;

import json;

import math;

import sys;

import argparse;

import re;

import from pathlib { Path }

glob openpyxl: any;

glob COMPANY_PATTERNS: any;

glob CITY_PATTERNS: any;

glob COUNT_PATTERNS: any;

glob INDEX_PATTERNS: any;

glob COMPOUND_PATTERNS: any;

glob ID_PATTERNS: any;

glob DEFAULT_CATEGORY: any;

with entry {
    try {
        import openpyxl;
    } except ImportError {
        openpyxl = None;
    }
    COMPANY_PATTERNS = {"firma", "company", "virksomhed", "employer", "arbejdsgiver"};
    CITY_PATTERNS = {"by", "city", "kommune", "location", "lokation", "sted"};
    COUNT_PATTERNS = {"antal", "count", "number", "n", "employees", "medarbejdere"};
    INDEX_PATTERNS = {"indeks", "index", "idx", "salary", "løn", "median", "average", "gennemsnit"};
    COMPOUND_PATTERNS = {"firma", "antal", "indeks", "løn", "gennemsnit", "medarbejdere"};
    ID_PATTERNS = {"id", "personnummer"};
    DEFAULT_CATEGORY = "all_employees";
}

def _finite_float(value) -> any;

"""Parse numeric Excel values, including localized string cells."""
def parse_numeric_cell(value) -> any;

"""Split a combined name-and-city cell on its last comma.

    The IDA demonstration workbook heads its company column "Firmanavn og by"
    and stores "Ørsted A/S,Fredericia" (no space after the comma). salary_lookup's
    --city filter only reads entry["city"], so leaving the city in the company
    string makes the documented
    `neojac run jobsearch -- salary_lookup "Ørsted" --city "Fredericia"` miss. Split on the
    last comma and strip both parts: a city may contain spaces ("Kongens Lyngby")
    and a company may contain ", " ("Rambøll Danmark A/S, Odense,Odense C"
    keeps "Rambøll Danmark A/S, Odense"). A cell with no comma stays the company
    with an empty city.
    """
def split_combined_company_city(value) -> any;

"""Return True when a header contains a meaningful pattern match.

    Patterns match whole tokens; any pattern also listed in
    ``COMPOUND_PATTERNS`` may additionally match as a substring, to handle
    languages that form compound words.
    """
def header_matches(header, patterns) -> any;

"""Remove count/index words from a header to derive a category name.

    Mirrors ``header_matches``: patterns strip as whole tokens, and any
    pattern also listed in ``COMPOUND_PATTERNS`` additionally strips as a
    substring - otherwise a compound header like "Lønindeks alle" keeps the
    type word in its category name and can never pair with "Antal alle".
    """
def strip_type_patterns(header, patterns) -> any;

"""Detect whether a column header refers to count or index data."""
def detect_column_type(header) -> any;

"""Parse a single worksheet into a list of company entries and detected categories."""
def parse_sheet(ws, sheet_label=None) -> any;

"""Write UTF-8 whatever the host's default encoding is.

    A piped stdout on Windows defaults to the ANSI code page (cp1252 on most
    Western installs), so printing a company, title or file name outside it
    raised UnicodeEncodeError before the workflow saw any output.
    """
def _force_utf8_output -> None;

def main -> any;

with entry:__main__ {
    main();
}
