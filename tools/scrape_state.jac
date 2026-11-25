"""Keep /scrape's growing history out of the agent context.

Pass a JSON array of search hits to `candidates` before fetching details, then
pass the enriched entries to `store`. Both commands deduplicate against the
current history and tracker; `store` writes the history atomically.
"""

import argparse;
import json;
import sys;
import from pathlib { Path }
import from urllib.parse { urlsplit }

glob STORED_FIELDS: tuple[str, ...] = (
    "first_seen",
    "posted_date",
    "deadline",
    "fit",
    "status",
    "portal",
    "source",
);

def read_jobs(path: Path) -> list[any];

"""A hit's normalised URL and (company, title) pair; ValueError when it is not a posting."""
def identity(job: any) -> tuple[str, tuple[str, str]];

"""The hits not in the history, the tracker or earlier in the batch, by key, and the counts."""
def select(
    jobs: list[any], seen: dict[str, any], tracker: set[tuple[str, str]], *, strict: bool = False
) -> tuple[dict[str, any], dict[str, any]];

def on_domain(url: any, domain: str) -> bool;

"""Stored entries from a portal, or from its domain when they predate the portal field."""
def prior_entries(seen: dict[str, any], portal: str, domain: str) -> int;

def check_storable(job: dict[str, any]) -> None;

def run(args: any) -> int;

def main -> int;

with entry:__main__ {
    sys.exit(main());
}
