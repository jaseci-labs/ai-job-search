"""Triage upstream commits this fork has not picked up yet.

Prints a Markdown report sorting them into "worth reviewing" and "probably skip". It only
reads git history: nothing is merged, and the cherry-pick lines are for a human to run.
A commit is skipped when its patch-id matches a fork-only commit (already cherry-picked),
its subject matches one (verify), it is on the won't-port list, or it touches only files
this fork removed (or only CHANGELOG.md besides them).

Usage: neojac run jobsearch -- upstream_triage [--remote upstream] [--branch master]
Always exits 0; an unavailable upstream ref is a note on stderr.
"""

import argparse;
import shlex;
import subprocess;
import sys;
import from pathlib { Path }

"""Use UTF-8 for piped output even on legacy-console hosts."""
def _force_utf8_output -> None;

def git(*args: str) -> str;
def rev_list(range_spec: str) -> list[str];

"""Stable patch-id for a commit, or None if it has no diff."""
def patch_id(sha: str) -> str | None;

def subject(sha: str) -> str;
def files_touched(sha: str) -> list[str];
def path_exists(path: str, ref: str = "HEAD") -> bool;

"""Whether a path absent from HEAD and base sits in a directory the fork removed.

The nearest ancestor directory that HEAD or the base has decides: HEAD means kept.
"""
def in_removed_dir(path: str, base: str) -> bool;

"""owner/repo for a GitHub remote, or None if it can't be parsed."""
def remote_slug(remote: str) -> str | None;

"""SHA prefixes the fork has decided never to port; missing file -> []."""
def load_wontport(path: str) -> list[str];

def commit_cell(sha: str, slug: str | None) -> str;

"""Whether the commit's path matters to this fork: present, or new upstream rather than removed here."""
def relevant_path(path: str, base: str | None) -> bool;

def main -> int;
def _print_crossref(remote: str, branch: str) -> None;

with entry:__main__ {
    sys.exit(main());
}
