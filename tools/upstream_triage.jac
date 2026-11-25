"""Triage upstream commits this fork has not picked up yet.

Emits a Markdown report that sorts the behind-list into "worth reviewing" vs
"probably skip", so a human decides what to merge/port. It never merges,
pushes, or edits anything - it only reads git history and prints. This is the
deliberate report/act boundary: on a fork "applies cleanly" is not "correct" -
a commit for portals the fork dropped can cherry-pick fine and still be wrong,
and that silent-wrong case is worse than a conflict. So the report stops at
ready-to-run cherry-pick lines; a human runs them.

This is the commit-level companion to check_upstream_updates.jac. That tool
answers "which of my personalized framework files changed" (version stamps);
this one answers "which upstream commits deserve my attention" (commit history).
Two tools, two questions - each cross-references the other in its output.

Two signals drive the sort:

1. Already applied? A cherry-pick lands with a NEW sha but the same patch, so a
   raw sha comparison misreports it as missing. We compute git patch-ids for the
   fork-only commits and treat any upstream commit whose patch-id
   matches as already applied. A matching subject with a different patch may be a
   conflict-resolved port or an unrelated change: keep it as a distinct verify
   reason in the advisory skip list, never as proof of a cherry-pick.

2. Relevant to this fork? A commit that only touches files this fork deleted
   (e.g. removed demo portals) is almost certainly N/A. We check each commit's
   touched paths against HEAD and the shared base: a genuinely new upstream
   path is worth reviewing, rather than a file the fork chose to remove. A new
   file inside a directory the fork removed (a test added to a dropped portal)
   counts as removed too.

Usage: neojac run jobsearch -- upstream_triage [--remote upstream] [--branch master]
Exits 0 always (a report, not a gate). Prints a note to stderr and exits 0 if
the upstream ref is unavailable, so a scheduled job degrades gracefully.
"""

import operator;
import from __future__ { annotations }

import argparse;

import shlex;

import subprocess;

import sys;

"""Write UTF-8 whatever the host's default encoding is.

    A piped stdout on Windows defaults to the ANSI code page (cp1252 on most
    Western installs), so printing a commit subject or author outside it
    raised UnicodeEncodeError before the report could be emitted.
    """
def _force_utf8_output -> None;

def git(*args_: str) -> str;

def rev_list(range_spec: str) -> list[str];

"""Stable patch-id for a commit, or None if it has no diff."""
def patch_id(sha: str) -> str | None;

def subject(sha: str) -> str;

def files_touched(sha: str) -> list[str];

def path_exists(path: str, ref: str = "HEAD") -> bool;

"""Whether a path absent from HEAD and base sits in a directory the fork removed.

    The nearest ancestor directory decides: one HEAD still has means the path is
    new in a directory the fork kept; one only the base has means the fork
    deleted the tree the path would land in. Directories in neither are new
    upstream too, so the walk goes on up to the root.
    """
def in_removed_dir(path: str, base: str) -> bool;

"""owner/repo for a GitHub remote, or None if it can't be parsed."""
def remote_slug(remote: str) -> str | None;

"""SHA prefixes the fork has decided never to port; missing file -> []."""
def load_wontport(path: str) -> list[str];

def commit_cell(short: str, sha: str, slug: str | None) -> str;

def main -> int;

def _print_crossref(remote: str, branch: str) -> None;

with entry:__main__ {
    sys.exit(main());
}
