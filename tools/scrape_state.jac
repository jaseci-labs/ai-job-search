"""Keep /scrape's growing history out of the agent context.

Pass a JSON array of search hits to `candidates` before fetching details, then
pass the enriched entries to `store`. Both commands deduplicate against the
current history and tracker; `store` writes the history atomically.
"""

import builtins;

import operator;

import argparse;

import json;

import sys;

import from pathlib { Path }

import from urllib.parse { urlsplit }

def read_jobs(path: Path) -> builtins.list;

def identity(
    job: builtins.dict
) -> builtins.tuple[builtins.str, builtins.tuple[builtins.str, builtins.str]];

def select(
    jobs: builtins.list,
    seen: builtins.dict,
    tracker: builtins.set,
    *,
    strict: builtins.bool = False,
) -> builtins.tuple[builtins.list[builtins.dict], builtins.dict];

def run(args) -> builtins.int;

def main -> builtins.int;

with entry:__main__ {
    sys.exit(main());
}
