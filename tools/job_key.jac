"""Canonical dedup key for a job posting, and an audit for existing state.

A seen_jobs.json key is a pure function of the posting: "<company slug>_<title slug>", each
half ASCII, length-capped, and disambiguated by a hash of the full slug when it is cut. A
half whose ASCII fold drops letters (a non-Latin script) keeps the surviving fragment as a
readable prefix and takes its identity from the portal's numeric id in the URL, or a hash.

Usage:
  neojac run jobsearch -- job_key --company "Acme Corp" --title "SOC Analyst (L2)"
  neojac run jobsearch -- job_key --audit job_scraper/seen_jobs.json
  neojac run jobsearch -- job_key --audit --migrate

`--audit --migrate` rewrites keys that no longer match the current rule, in place: backup
first, old->new reported, a new key that already exists is reported and left alone, and a
second run changes nothing.

Exit 0 when a key is produced, or when an audit finds nothing. Exit 1 when an audit finds
violations.
"""

import argparse;
import hashlib;
import json;
import os;
import re;
import shutil;
import sys;
import unicodedata;
import from datetime { datetime }
import from pathlib { Path }

glob ROOT: Path = Path(os.environ.get("JOBSEARCH_ROOT") or Path(__file__).resolve().parent.parent),
     STATE: Path = ROOT / "job_scraper" / "seen_jobs.json",
     COMPANY_MAX: int = 40,
     TITLE_MAX: int = 60,
     HASH_LEN: int = 6,
     _NON_SLUG: any = re.compile("[^a-z0-9]+"),
     _JOB_ID: any = re.compile("(\\d{6,})"),
     _SLUG: str = "[a-z0-9][a-z0-9-]*",
     _CANONICAL: any = re.compile(f"^{_SLUG}_{_SLUG}$"),
     _LATIN_FOLD: dict[str, str] = {
         pair[0]: pair[1:]
         for pair in "øo ØO æae ÆAE œoe ŒOE ßss ẞSS þth ÞTH ðd ÐD đd ĐD łl ŁL ıi ħh ĦH ĸk ŋng ŊNG ŧt ŦT".split()
     },
     _LATIN_FOLD_TABLE: dict[int, any] = str.maketrans(_LATIN_FOLD);

"""Lowercase ASCII slug. Non-Latin scripts legitimately reduce to ''."""
def slugify(text: str) -> str;

"""True when the ASCII fold dropped non-Latin letters, so the slug under-identifies."""
def _lost_letters(text: str) -> bool;

def _digest(text: str) -> str;

"""Cap the length, appending a hash of the full slug so truncation stays deterministic."""
def _cap(slug: str, limit: int) -> str;

"""The canonical seen_jobs.json key for one posting."""
def make_key(company: str, title: str, url: str = "") -> str;

"""Structurally safe as a dedup key and as an archive folder name."""
def is_canonical(key: str) -> bool;

"""Old three-part "company_title_location" keys: harmless, but not what make_key produces."""
def is_legacy_shape(key: str) -> bool;

"""Why a decoded state file cannot be audited, or None."""
def _flaw(seen: any) -> str | None;

"""Return (document, seen) or print the reason and return None."""
def _load_seen(path: Path) -> tuple[any, dict[str, any]] | None;

"""Canonical keys that differ from what make_key produces today, with their new key."""
def _drifted(seen: dict[str, any]) -> dict[str, str];

"""One pass: the drifted keys that can move, and those blocked by a key that stays put."""
def _rename_pass(seen: dict[str, any]) -> tuple[dict[str, str], list[dict[str, str]]];

"""Rewrite drifted keys in place, never overwriting an existing key; return the report."""
def migrate(path: Path, doc: any, seen: dict[str, any]) -> dict[str, any];

def audit(path: Path, do_migrate: bool = False) -> int;

def main -> int;

with entry:__main__ {
    sys.exit(main());
}
