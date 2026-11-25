"""Verify that a generated PDF has the expected pages and an extractable text layer.

The text layer is read with pypdf, falling back to Poppler's `pdftotext` when pypdf is
missing, raises, or finds no text. `--contains` compares after `normalize_text()` has folded
both sides; `--dump-text` writes the raw layer an ATS parser sees; `--ascii-dates` scans the
raw layer for a year joined to a Unicode dash, which ATS date parsers drop.
"""

import argparse;
import os;
import re;
import subprocess;
import sys;
import unicodedata;
import from pathlib { Path }

glob ROOT: Path = Path(os.environ.get("JOBSEARCH_ROOT") or Path(__file__).resolve().parent.parent),
     DUMP_TEXT_DIRS: tuple[str, str] = ("cv", "cover_letters"),
     TYPOGRAPHIC_FOLDS: dict[int, any] = str.maketrans({
         "‘": "'",
         "’": "'",
         "“": "\"",
         "”": "\"",
         "–": "-",
         "—": "-",
         " ": " ",
     }),
     NON_ASCII_DASHES: str = "‐‑‒–—―−",
     YEAR: str = "(?<!\\d)(?:19|20)\\d{2}(?!\\d)",
     NON_ASCII_DATE_RANGE: re.Pattern = re.compile(
         f"{YEAR}[^\\S\\n]*[{NON_ASCII_DASHES}]|[{NON_ASCII_DASHES}][^\\S\\n]*{YEAR}"
     ),
     TOKEN_BEFORE: re.Pattern = re.compile("(\\S+)[^\\S\\n]*$"),
     TOKEN_AFTER: re.Pattern = re.compile("^[^\\S\\n]*(\\S+)"),
     BARE_NUMBER: re.Pattern = re.compile("\\d+(?:[.,]\\d+)*[kKmM%]?"),
     BARE_YEAR: re.Pattern = re.compile("(?:19|20)\\d{2}"),
     TWO_DIGIT_YEAR: re.Pattern = re.compile("\\d{2}"),
     OUTER_PUNCTUATION: str = ".,;:!?()[]{}\"'";

"""Raised when a generated PDF does not satisfy its checks."""
class VerificationError(Exception) {}

"""Why `--dump-text` may not write to `path`, or None if it may."""
def check_dump_target(path: str | Path, base: Path = ROOT) -> str | None;

def run_tool(command: list[str]) -> str;
def parse_page_count(pdfinfo_output: str) -> int;

"""Fold a string for comparison: NFC, typographic punctuation, whitespace."""
def normalize_text(text: str) -> str;

"""The token without outer punctuation if it is a bare number, else None; a numeric date is not."""
def _bare_number(token: str) -> str | None;

"""A numeric amount with an attached Unicode currency symbol, or None."""
def _currency_amount(token: str) -> str | None;

"""True when both sides of the dash are bare numbers or amounts and not a pair of years."""
def _quantity_range(line: str, dash_index: int) -> bool;

"""(line, dash) for every year joined to a non-ASCII dash in the raw text."""
def find_non_ascii_date_ranges(text: str) -> list[tuple[str, str]];

"""(text, pages), or None if pypdf is unavailable, raises, or yields no text."""
def _extract_pypdf(pdf_path: Path) -> tuple[str, int] | None;

"""The ATS-readable text as (text, pages, extractor name)."""
def extract_text_layer(pdf_path: Path) -> tuple[str, int, str];

"""Check the PDF and return (extractor name, text, pages)."""
def verify_pdf(
    pdf_path: str | Path,
    expected_pages: int | None = None,
    min_chars: int = 1,
    required_text: any = (),
    dump_text: str | Path | None = None,
    ascii_dates: bool = False,
) -> tuple[str, str, int];

def build_parser -> argparse.ArgumentParser;
def _force_utf8_output -> None;
def main(argv: list[str] | None = None) -> int;

with entry:__main__ {
    sys.exit(main());
}
