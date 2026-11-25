"""Verify that a generated PDF has the expected pages and extractable text.

Text-layer extraction tries pypdf (BSD, fetched by `neojac install`) first,
then Poppler `pdftotext` if pypdf is missing, raises, or returns zero
extractable characters. Poppler remains the fallback.

`--contains` compares after `normalize_text()` has folded both sides: whitespace,
Unicode normalization form (NFC), and the typographic substitutions LaTeX makes to
the source text. The fold is comparison-time only - the `--dump-text` output stays
the raw text layer an ATS parser actually sees.

`--ascii-dates` is the one check that deliberately does NOT fold: it scans the raw
layer for a year joined to a Unicode dash - the en-dash LaTeX makes from `--`, which
a Workday import dropped along with the date (`05-cv-templates.md`, "Date fields
must be ASCII ranges") - and fails naming each hit with its code point.
"""

import os;

import builtins;

import argparse;

import re;

import subprocess;

import sys;

import unicodedata;

import from pathlib { Path }

glob ROOT: any;

glob DUMP_TEXT_DIRS: any;

glob TYPOGRAPHIC_FOLDS: any;

glob NON_ASCII_DASHES: any;

glob _YEAR: any;

glob NON_ASCII_DATE_RANGE: any;

glob _TOKEN_BEFORE: any;

glob _TOKEN_AFTER: any;

glob _BARE_NUMBER: any;

glob _BARE_YEAR: any;

glob _OUTER_PUNCTUATION: any;

glob _TWO_DIGIT_YEAR: any;

with entry {
    ROOT = Path(os.environ.get("JOBSEARCH_ROOT") or Path(__file__).resolve().parent.parent);
    DUMP_TEXT_DIRS = ("cv", "cover_letters");
}

"""Raised when a generated PDF does not satisfy its checks."""
obj VerificationError(Exception) {
    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

glob root_default_: any;

with entry {
    root_default_ = ROOT;
}

"""Return why `--dump-text` may not write to `path`, or None if it may."""
def check_dump_target(path, `root=root_default_) -> any;

def run_tool(command) -> any;

def parse_page_count(pdfinfo_output) -> any;

with entry {
    TYPOGRAPHIC_FOLDS = str.maketrans({
        "‘": "'",
        "’": "'",
        "“": "\"",
        "”": "\"",
        "–": "-",
        "—": "-",
        " ": " ",
    });
}

"""Fold a string for comparison: NFC, typographic punctuation, whitespace.

    NFC covers the pdflatex text layer, which without T1 font encoding stores
    accented letters decomposed (`e` + U+0300) while a user types them
    precomposed (U+00E8); both forms fold to the same string (#384). The fold
    applies to what is compared, never to what is dumped: the date-range rule in
    `05-cv-templates.md` still needs the raw en-dash visible in `--dump-text`.
    """
def normalize_text(text) -> any;

with entry {
    NON_ASCII_DASHES = "‐‑‒–—―−";
    _YEAR = "(?<!\\d)(?:19|20)\\d{2}(?!\\d)";
    NON_ASCII_DATE_RANGE = re.compile(
        f"{_YEAR}[^\\S\\n]*[{NON_ASCII_DASHES}]|[{NON_ASCII_DASHES}][^\\S\\n]*{_YEAR}"
    );
    _TOKEN_BEFORE = re.compile("(\\S+)[^\\S\\n]*$");
    _TOKEN_AFTER = re.compile("^[^\\S\\n]*(\\S+)");
    _BARE_NUMBER = re.compile("\\d+(?:[.,]\\d+)*[kKmM%]?");
    _BARE_YEAR = re.compile("(?:19|20)\\d{2}");
    _OUTER_PUNCTUATION = ".,;:!?()[]{}\"'";
}

"""The token with outer punctuation stripped, if it is a bare number, else None.

    A dotted or comma-separated token whose groups include a year (`01.2016`,
    `31.07.2024`) is a date written numerically, not a quantity, and is left to
    the year rule; `1,234.56` and `2.0M` have no year group and stay numbers.
    """
def _bare_number(token) -> any;

"""A numeric amount with an attached Unicode currency symbol, or None."""
def _currency_amount(token) -> any;

with entry {
    _TWO_DIGIT_YEAR = re.compile("\\d{2}");
}

"""True when both sides of the dash are bare numbers and not a date pair.

    A date pair is two years (`2016-2024`) or a year and a two-digit year
    (`2016-17`, `2019-20`): the short form is how academic years and seasons
    are written, and it was caught before the quantity rule existed. Anything
    else with bare numbers on both sides is a quantity (`1500-2000`,
    `2000-5000`) and is left alone. An attached currency symbol makes a
    numeric pair an amount range, even when both amounts resemble years.
    """
def _quantity_range(line, dash_index) -> any;

"""Return (line, dash) for every year joined to a non-ASCII dash in raw text.

    Works on the raw text layer, never on `normalize_text()` output: the fold
    maps U+2013 back to `-` so `--contains "2016-2024"` can match what the
    template renders, which is exactly why `--contains` cannot see this defect.
    A year on either side of the dash is enough ("Mar 2016 - Jul 2016",
    "2016 - Present"), so the check is locale-agnostic. A range whose two ends
    are both bare numbers is a date only when both are years: "EUR 600k-1M",
    "EUR 1500-2000" and "2000-5000 requests/s" are quantities and are left
    alone, while a numerically formatted date ("03/2016-07/2024", "2016-03-2024-07")
    is not a bare number on either side and is still caught.
    """
def find_non_ascii_date_ranges(text) -> any;

"""Return (text, pages) or None if pypdf is unavailable, raises, or yields no text."""
def _extract_pypdf(pdf_path) -> any;

def _extract_pdftotext(pdf_path) -> any;

"""Extract ATS-readable text. Returns (text, pages, extractor_name)."""
def extract_text_layer(pdf_path) -> any;

def verify_pdf(
    pdf_path, expected_pages=None, min_chars=1, required_text=(), dump_text=None, ascii_dates=False
) -> any;

def build_parser -> any;

"""Write UTF-8 whatever the host's default encoding is.

    A piped stdout on Windows defaults to the ANSI code page (cp1252 on most
    Western installs), so printing a company, title or file name outside it
    raised UnicodeEncodeError before the workflow saw any output.
    """
def _force_utf8_output -> None;

def main(argv=None) -> any;

with entry:__main__ {
    sys.exit(main());
}
