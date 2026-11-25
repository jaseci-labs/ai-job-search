"""State helper for /rank: select candidates and write results back.

Keeps seen_jobs.json out of the conversation. `candidates` selects the entries to score and
projects the fields a scoring agent needs, `sweep` expires ranked entries past their stored
deadline, and `apply` writes scoring results back and prints the rows of the report.
Nothing here fetches a posting or judges a fit.

Usage:
  neojac run jobsearch -- rank_state candidates [--all] [--focus TEXT] [--limit N]
  neojac run jobsearch -- rank_state sweep [--write] [--exclude KEY,KEY]
  neojac run jobsearch -- rank_state apply --results results.json [--dry-run] [--now ISO-DATETIME]

Every subcommand prints JSON on stdout. Exit 0 on success, 1 on a usage or state error, or on
`apply` when any result could not be written.
"""

import argparse;
import csv;
import json;
import os;
import re;
import sys;
import tempfile;
import unicodedata;
import from datetime { date, datetime, timedelta, timezone }
import from fractions { Fraction }
import from pathlib { Path }

glob ROOT: Path = Path(os.environ.get("JOBSEARCH_ROOT") or Path(__file__).resolve().parent.parent),
     STATE: Path = ROOT / "job_scraper" / "seen_jobs.json",
     TRACKER: Path = ROOT / "job_search_tracker.csv",
     WEIGHTS: dict[str, float] = {
         "technical": 0.3,
         "experience": 0.25,
         "behavioral": 0.15,
         "career": 0.3,
     },
     BANDS: list[tuple[int, str]] = [
         (75, "Strong Fit"),
         (60, "Good Fit"),
         (45, "Moderate Fit"),
         (30, "Weak Fit"),
     ],
     DEFAULT_LIMIT: int = 10,
     URGENT_DAYS: int = 7,
     ISO: any = re.compile("^\\d{4}-\\d{2}-\\d{2}$"),
     AGENT_STATUSES: tuple[str, ...] = ("scored", "expired", "unreachable"),
     GATE_VERDICTS: tuple[str, ...] = ("PASS", "FAIL", "FLAG"),
     UNREACHABLE_MAX_ATTEMPTS: int = 3,
     UNREACHABLE_MIN_SPAN: timedelta = timedelta(hours=48),
     FETCH_ERROR_MAX: int = 200,
     RETRY_FIELDS: tuple[str, ...] = ("fetch_attempts", "first_unreachable", "last_fetch_error"),
     TIMESTAMP: str = "%Y-%m-%dT%H:%M:%SZ";

"""The (document, seen-map) of a state file; callers mutate the map in place."""
def load_state(path: Path) -> tuple[dict[str, any], dict[str, any]];

"""Replace the state file atomically."""
def save_state(path: Path, doc: dict[str, any]) -> None;

"""A stored UTC timestamp, or None for anything else."""
def parse_timestamp(value: any) -> datetime | None;

"""--now: an ISO 8601 date-time; a naive value is taken as UTC."""
def parse_now(value: str) -> datetime;

"""A YYYY-MM-DD date, or None for anything else: never compared, never guessed at."""
def parse_iso(value: any) -> date | None;

"""Ignore case and separators without discarding non-Latin identity."""
def norm(text: any) -> str;

"""The normalised (company, role) pairs already in the tracker."""
def tracker_pairs(path: Path) -> set[tuple[str, str]];

"""The entry's key with the named fields, as a row of the printed JSON."""
def brief(
    key: str, job: dict[str, any], fields: tuple[str, ...] = ("title", "company", "url")
) -> dict[str, any];

def emit(payload: dict[str, any]) -> None;

def cmd_candidates(args: any) -> int;

def cmd_sweep(args: any) -> int;

def overall_score(scores: any) -> int;

def band(score: int) -> str;

"""Record a failed fetch on the entry; the bucket says whether it is retried or given up on."""
def record_unreachable(
    key: str, job: dict[str, any], result: dict[str, any], now: datetime
) -> tuple[str, dict[str, any]];

"""Write a score onto the entry and return its row of the ranking."""
def record_score(
    key: str,
    job: dict[str, any],
    result: dict[str, any],
    score: int,
    deadline: date | None,
    today: date,
) -> dict[str, any];

"""Apply one scoring result to the seen-map; returns the output bucket and its row."""
def apply_result(
    result: any, seen: dict[str, any], today: date, now: datetime
) -> tuple[str, dict[str, any]];

def cmd_apply(args: any) -> int;

"""Write UTF-8 whatever the host's default encoding is."""
def _force_utf8_output -> None;

def main -> int;

with entry:__main__ {
    sys.exit(main());
}
