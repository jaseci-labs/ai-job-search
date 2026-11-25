"""Check for framework updates in the upstream repository.

Usage: neojac run jobsearch -- check_upstream_updates [--remote <remote-name>] [--branch <branch-name>]

This script:
1. Identifies the upstream remote (defaults to 'upstream', falls back to 'origin').
2. Fetches the latest commits from the upstream remote.
3. Compares the 'framework_version' in your local files under
   .claude/skills/job-application-assistant/ with those in the upstream remote.
4. Alerts you if a file has been updated upstream with a newer version.
"""

import from __future__ { annotations }

import argparse;

import os;

import re;

import shlex;

import subprocess;

import sys;

import from pathlib { Path }

glob ROOT: any;

glob FRAMEWORK_FILES: any;

glob UPSTREAM_REPO_SLUG: any;

with entry {
    ROOT = Path(os.environ.get("JOBSEARCH_ROOT") or Path(__file__).resolve().parent.parent);
    FRAMEWORK_FILES = [
        ".claude/skills/job-application-assistant/01-candidate-profile.md",
        ".claude/skills/job-application-assistant/02-behavioral-profile.md",
        ".claude/skills/job-application-assistant/03-writing-style.md",
        ".claude/skills/job-application-assistant/04-job-evaluation.md",
        ".claude/skills/job-application-assistant/05-cv-templates.md",
        ".claude/skills/job-application-assistant/06-cover-letter-templates.md",
        ".claude/skills/job-application-assistant/07-interview-prep.md",
        ".claude/skills/job-application-assistant/08-application-forms.md",
        ".claude/skills/job-application-assistant/09-web-research.md",
        ".claude/skills/job-application-assistant/SKILL.md",
        "AGENTS.md",
    ];

    UPSTREAM_REPO_SLUG = "ai-job-search-dev/ai-job-search";
}

def run_git(args: list[str]) -> tuple[int, str, str];

def get_remote_url(remote_name: str) -> str;

def get_framework_version_from_text(text: str) -> str | None;

def parse_semver(version_str: str) -> tuple[int, int, int];

"""Use UTF-8 for piped output even on legacy-console hosts."""
def _force_utf8_output -> None;

def main -> int;

with entry:__main__ {
    sys.exit(main());
}
