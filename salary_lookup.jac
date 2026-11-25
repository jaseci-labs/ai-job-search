"""
Salary Benchmark Lookup Tool

Looks up company salary data from a user-provided dataset.
Supports any salary data source — union statistics, Glassdoor exports,
manually collected benchmarks, etc.

This tool requires a data file (salary_data.json) that you create
from your own salary data. See tools/README_SALARY_TOOL.md for
instructions on the expected format and how to convert from Excel.

Usage:
    neojac run jobsearch -- salary_lookup "Company Name"
    neojac run jobsearch -- salary_lookup "Company Name" --city "København"
    neojac run jobsearch -- salary_lookup "Company Name" --json
    neojac run jobsearch -- salary_lookup --list-all
"""

import os;

import json;

import math;

import sys;

import re;

import argparse;

import unicodedata;

import from pathlib { Path }

glob DATA_FILE: any;

glob SPELLING_VARIANTS: any;

glob STRIP_PATTERNS: any;

with entry {
    DATA_FILE = Path(os.environ.get("JOBSEARCH_ROOT") or Path(__file__).parent)
        / "salary_data.json";
    SPELLING_VARIANTS = {
        "ø": "o",
        "æ": "ae",
        "å": "aa",
        "ö": "o",
        "ä": "ae",
        "ü": "u",
        "þ": "th",
        "ð": "d",
    };
    STRIP_PATTERNS = [
        "\\ba/s\\b",
        "\\baps\\b",
        "\\bi/s\\b",
        "\\bp/s\\b",
        "\\bk/s\\b",
        "\\bivs\\b",
        "\\bamba\\b",
        "\\ba\\.m\\.b\\.a\\.?\\b",
        "\\(vg\\)",
        "\\(.*?\\)",
        "\\bdanmark\\b",
        "\\bdenmark\\b",
        "\\bscandinavia\\b",
        "\\bnordic\\b",
        "\\bgroup\\b",
        "\\bholding\\b",
        ",\\s*.*$",
    ];
}

"""Exit with a user-facing salary data setup error."""
def fail_data_error(message) -> any;

"""Return (errors, warnings) for the salary data shape.

    errors   -> hard problems that make lookups crash or emit wrong output
                (these cause validate_data() to exit(1)).
    warnings -> usability concerns that still work (e.g. duplicate company
                names); --validate reports them but exits 0.
    """
def collect_validation_issues(data) -> any;

"""Validate the salary data shape before lookups use it.

    Preserves historical behavior: exits(1) on the first hard error with the
    same user-facing message, and returns data unchanged when valid.
    """
def validate_data(data) -> any;

"""Load and JSON-parse salary_data.json; exit with a helpful message if missing/invalid."""
def read_raw_data -> any;

"""Load, parse, and validate salary_data.json for lookups."""
def load_data -> any;

"""Normalize string for robust fuzzy matching."""
def normalize(s) -> any;

"""Fold Nordic spellings first, then accents for ASCII-typed queries."""
def anglicize(s) -> any;

"""Extract meaningful words from a company name, ignoring noise."""
def extract_core_words(s) -> any;

"""Compute a match score between 0 and 100 using precalculated query values."""
def match_score_optimized(q_norm, q_ang, q_words_set, q_words_ang_set, query, entry_name) -> any;

"""Compute a match score between 0 and 100 for ranking results."""
def match_score(query, entry_name) -> any;

"""Search for a company by name. Returns matching entries sorted by relevance."""
def search_company(data, query, city=None) -> any;

"""Format a single company entry for display."""
def format_entry(`entry, metadata) -> any;

"""Print an actionable validation report. Returns the process exit code."""
def print_validation_report(errors, warnings) -> any;

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
