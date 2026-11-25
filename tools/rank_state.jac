"""State helper for /rank: select candidates and write results back.

/rank reads the whole of seen_jobs.json into the model's context to filter it
by eye (Step 1), then re-emits the whole file to record scores (Step 4). That
cost is paid on every run regardless of how many jobs are actually scored, and
it grows for the life of the workspace, since seen_jobs.json is append-only by
design and most stored entries are `skipped`.

This moves the state-file traffic into code. Three subcommands:

  candidates   select the eligible entries for this run and project only the
               fields a scoring agent needs
  sweep        rule 6's expiry pass over entries this run did not re-score -
               a stored-date comparison, no fetch, no agent
  apply        write scoring results back to seen_jobs.json and print the
               ranked/vetoed/expired/unreachable/gave_up rows Step 5's
               report is built from

Selection and projection follow Step 1's existing rules exactly (status
filter, tracker exclusion, focus filter, `--limit`/`--all`); the write-back
follows Step 4's existing rules exactly (the `location` -> `location_verdict`
legacy migration, the deadline null-is-not-a-correction rule, verbatim
strengths/gaps persistence, idempotent skip of already-ranked entries); the
sweep follows rule 6 exactly (defensive date parsing, an absent deadline left
alone, `--all` making a retired entry revivable).

Nothing here fetches a posting or judges a fit. Scoring stays with the model;
this only removes the state file from the conversation.

Usage:
  neojac run jobsearch -- rank_state candidates [--all] [--focus TEXT] [--limit N]
  neojac run jobsearch -- rank_state sweep [--write] [--exclude KEY,KEY]
  neojac run jobsearch -- rank_state apply --results results.json [--dry-run] [--now ISO-DATETIME]

Both subcommands print JSON on stdout. Exit 0 on success, 1 on a usage or
state error, or on `apply` when any result could not be written.
"""

import builtins;

import operator;

import argparse;

import json;

import os;

import re;

import sys;

import tempfile;

import unicodedata;

import from datetime { date, datetime, timedelta, timezone }

import from fractions { Fraction }

import from pathlib { Path }

glob ROOT: any;

glob STATE: any;

glob TRACKER: any;

glob WEIGHTS: any;

glob BANDS: any;

glob DEFAULT_LIMIT: any;

glob URGENT_DAYS: any;

glob ISO: any;

glob AGENT_STATUSES: any;

glob GATE_VERDICTS: any;

glob UNREACHABLE_MAX_ATTEMPTS: any;

glob UNREACHABLE_MIN_SPAN: any;

glob FETCH_ERROR_MAX: any;

glob RETRY_FIELDS: any;

glob TIMESTAMP: any;

with entry {
    ROOT = Path(os.environ.get("JOBSEARCH_ROOT") or Path(__file__).resolve().parent.parent);
    STATE = ROOT / "job_scraper" / "seen_jobs.json";
    TRACKER = ROOT / "job_search_tracker.csv";
    WEIGHTS = {"technical": 0.3, "experience": 0.25, "behavioral": 0.15, "career": 0.3};
    BANDS = (
        (75, "Strong Fit"),
        (60, "Good Fit"),
        (45, "Moderate Fit"),
        (30, "Weak Fit"),
        (0, "Poor Fit"),
    );

    DEFAULT_LIMIT = 10;
    URGENT_DAYS = 7;
    ISO = re.compile("^\\d{4}-\\d{2}-\\d{2}$");
    AGENT_STATUSES = ("scored", "expired", "unreachable");
    GATE_VERDICTS = ("PASS", "FAIL", "FLAG");
    UNREACHABLE_MAX_ATTEMPTS = 3;
    UNREACHABLE_MIN_SPAN = timedelta(hours=48);
    FETCH_ERROR_MAX = 200;
    RETRY_FIELDS = ("fetch_attempts", "first_unreachable", "last_fetch_error");
    TIMESTAMP = "%Y-%m-%dT%H:%M:%SZ";
}

"""Return (document, seen-map). The map is mutated in place by callers."""
def load_state(path: Path) -> builtins.tuple[builtins.dict, builtins.dict];

"""Atomic replace: a half-written seen_jobs.json loses the scrape history."""
def save_state(path: Path, doc: builtins.dict) -> None;

"""A stored UTC timestamp, or None for anything else (absent, malformed, a
    bare date) - the defensive-parse rule again: never compared, never guessed."""
def parse_timestamp(value) -> datetime | None;

"""--now: an ISO 8601 date-time; a naive value is taken as UTC."""
def parse_now(value: builtins.str) -> datetime;

"""Rule 6's defensive-parse rule: anything that is not YYYY-MM-DD is treated
    exactly like an absent value - never compared, never guessed at."""
def parse_iso(value) -> date | None;

"""Ignore case and separators without discarding non-Latin identity."""
def norm(text) -> builtins.str;

"""company+role pairs already in the tracker - out of scope for ranking."""
def tracker_pairs(path: Path) -> builtins.set[builtins.tuple[builtins.str, builtins.str]];

"""location_verdict, falling back to a legacy verdict stored under `location`
    (Step 4: "an entry ranked before this rename may carry a legacy PASS/FAIL/
    FLAG string in `location`")."""
def entry_location_verdict(`entry: builtins.dict) -> builtins.str | None;

def cmd_candidates(args) -> builtins.int;

def cmd_sweep(args) -> builtins.int;

def overall_score(scores: builtins.dict) -> builtins.int;

def band(score: builtins.int) -> builtins.str;

def cmd_apply(args) -> builtins.int;

"""Write UTF-8 whatever the host's default encoding is.

    A piped stdout on Windows defaults to the ANSI code page (cp1252 on most
    Western installs), so printing a company, title or file name outside it
    raised UnicodeEncodeError before the workflow saw any output.
    """
def _force_utf8_output -> None;

def main -> builtins.int;

with entry:__main__ {
    sys.exit(main());
}
