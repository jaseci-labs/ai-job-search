"""Salary benchmark lookup over a user-provided dataset (salary_data.json).

See tools/README_SALARY_TOOL.md for the expected format and how to convert from Excel.

Usage:
    neojac run jobsearch -- salary_lookup "Company Name"
    neojac run jobsearch -- salary_lookup "Company Name" --city "København"
    neojac run jobsearch -- salary_lookup "Company Name" --json
    neojac run jobsearch -- salary_lookup --list-all
    neojac run jobsearch -- salary_lookup --validate
"""

import argparse;
import json;
import math;
import os;
import re;
import sys;
import unicodedata;
import from pathlib { Path }
import from types { NoneType }

glob DATA_FILE: Path = Path(os.environ.get("JOBSEARCH_ROOT") or Path(__file__).parent)
         / "salary_data.json",
     SPELLING_VARIANTS: dict[str, str] = {
         "ø": "o",
         "æ": "ae",
         "å": "aa",
         "ö": "o",
         "ä": "ae",
         "ü": "u",
         "þ": "th",
         "ð": "d",
     },
     STRIP_PATTERNS: list[str] = [
         *[f"\\b{word}\\b" for word in "a/s aps i/s p/s k/s ivs amba".split()],
         "\\ba\\.m\\.b\\.a\\.?\\b",
         "\\(vg\\)",
         "\\(.*?\\)",
         *[f"\\b{word}\\b" for word in "danmark denmark scandinavia nordic group holding".split()],
         ",\\s*.*$",
     ],
     ENTRY_KEYS: set[str] = {"company", "city", "categories"},
     SETUP_HINT: str = "See tools/README_SALARY_TOOL.md for the expected format.";

def fail_data_error(message: str) -> None;

"""(errors, warnings): errors break lookups, warnings (duplicate names) still work."""
def collect_validation_issues(data: any) -> tuple[list[str], list[str]];

"""The data unchanged, or exit 1 on its first error."""
def validate_data(data: any) -> any;

def read_raw_data -> any;

def load_data -> any;

"""Casefolded name without legal and geographic noise; other punctuation becomes `gap`."""
def squash(s: str, gap: str) -> str;

def normalize(s: str) -> str;

"""Fold Nordic spellings first, then accents, for ASCII-typed queries."""
def anglicize(s: str) -> str;

def extract_core_words(s: str) -> list[str];

"""A query's normalized form, its anglicized form, its core words and their anglicized forms."""
def query_key(query: str) -> tuple[str, str, set[str], set[str]];

"""Whether a short name is too small a fragment of a long one to match on containment alone."""
def fragment(shorter: int, longer: int) -> bool;

"""Match score from 0 to 100 of a company name against a query key."""
def score_entry(key: tuple[str, str, set[str], set[str]], entry_name: str) -> int;

def match_score(query: str, entry_name: str) -> int;

"""Matching entries, most relevant first."""
def search_company(data: any, query: str, city: str | None = None) -> list[any];

def format_entry(company: any, metadata: any) -> str;

"""Print the validation report and return the process exit code."""
def print_validation_report(errors: list[str], warnings: list[str]) -> int;

def _force_utf8_output -> None;

def main -> None;

with entry:__main__ {
    main();
}
